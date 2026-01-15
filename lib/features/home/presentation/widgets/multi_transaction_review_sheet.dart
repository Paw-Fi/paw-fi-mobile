import 'dart:io';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/ui/widgets/transaction_currency_picker.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/models/parsed_expense.dart';
import 'package:moneko/features/home/presentation/state/expense_save_providers.dart';
import 'package:moneko/features/home/presentation/widgets/category_picker_bottom_sheet.dart';
import 'package:moneko/features/home/presentation/widgets/custom_split_sheet.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/income/presentation/providers/income_providers.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/datetime.dart';
import 'package:moneko/shared/widgets/moneko_switch.dart';
import 'package:moneko/shared/widgets/plain_adaptive_button.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

String _formatRelativeDate(DateTime date, BuildContext context) {
  final now = DateTime.now();
  final localDate = toLocalTime(date);
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final dateOnly = DateTime(localDate.year, localDate.month, localDate.day);

  if (dateOnly == today) {
    return context.l10n.today;
  } else if (dateOnly == yesterday) {
    return context.l10n.yesterday;
  } else if (dateOnly.isAfter(today.subtract(const Duration(days: 7)))) {
    return DateFormat.EEEE(Localizations.localeOf(context).toString())
        .format(localDate);
  } else {
    return DateFormat.yMMMMd(Localizations.localeOf(context).toString())
        .format(localDate);
  }
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String _normalizeNumberInput(String input) {
  final raw = input.trim().replaceAll(' ', '');
  if (raw.isEmpty) return raw;

  final hasDot = raw.contains('.');
  final hasComma = raw.contains(',');

  if (hasDot && hasComma) {
    final lastDot = raw.lastIndexOf('.');
    final lastComma = raw.lastIndexOf(',');
    final decimalSeparator = lastDot > lastComma ? '.' : ',';
    final thousandsSeparator = decimalSeparator == '.' ? ',' : '.';
    var cleaned = raw.replaceAll(thousandsSeparator, '');
    if (decimalSeparator == ',') cleaned = cleaned.replaceAll(',', '.');
    return cleaned;
  }

  if (hasComma && !hasDot) {
    return raw.replaceAll(',', '.');
  }

  return raw;
}

String _formatSaveError(Object error) {
  final message = error.toString();
  final colon = message.indexOf(':');
  if (colon != -1 && colon + 1 < message.length) {
    return message.substring(colon + 1).trim();
  }
  return message;
}

Future<void> showMultiTransactionReviewSheet(
  BuildContext context, {
  required List<ParsedExpense> transactions,
  String? localImagePath,
}) {
  if (transactions.isEmpty) return Future.value();

  final hasIncome = transactions.any((t) => t.isIncome);
  final hasExpense = transactions.any((t) => !t.isIncome);
  if (hasIncome && hasExpense) {
    AppToast.info(
      context,
      'Mixed income and expenses detected. Please submit separately.',
    );
    return Future.value();
  }

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor:
        Theme.of(context).colorScheme.surface.withValues(alpha: 0.0),
    isScrollControlled: true,
    isDismissible: true,
    builder: (context) => _MultiTransactionReviewSheet(
      transactions: transactions,
      localImagePath: localImagePath,
    ),
  );
}

class _TransactionDraft {
  _TransactionDraft({required this.value});

  ParsedExpense value;
  bool selected = true;
  String? error;
  SplitType? splitType;
  List<MemberSplit>? splits;
  String? payerUserId;
}

class _MultiTransactionReviewSheet extends ConsumerStatefulWidget {
  final List<ParsedExpense> transactions;
  final String? localImagePath;

  const _MultiTransactionReviewSheet({
    required this.transactions,
    required this.localImagePath,
  });

  @override
  ConsumerState<_MultiTransactionReviewSheet> createState() =>
      _MultiTransactionReviewSheetState();
}

class _MultiTransactionReviewSheetState
    extends ConsumerState<_MultiTransactionReviewSheet> {
  final ScrollController _scrollController = ScrollController();

  late List<_TransactionDraft> _drafts;

  bool _isSaving = false;
  bool _shareWithHousehold = false;
  String? _selectedHouseholdId;
  bool _userSelectedHousehold = false;
  bool _isLoadingMembers = false;
  String? _membersError;
  List<HouseholdMember>? _householdMembers;

  bool get _isIncomeMode => _drafts.isNotEmpty && _drafts.first.value.isIncome;

  @override
  void initState() {
    super.initState();

    _drafts = widget.transactions.map((t) => _TransactionDraft(value: t)).toList();

    final scope = ref.read(householdScopeProvider);
    _shareWithHousehold = scope.isHouseholdView;

    final selectedState = ref.read(selectedHouseholdProvider);
    _selectedHouseholdId =
        selectedState.householdId ?? selectedState.household?.id;

    if (_shareWithHousehold &&
        _selectedHouseholdId != null &&
        _selectedHouseholdId!.isNotEmpty) {
      _loadMembers(_selectedHouseholdId!);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _resetDraftSplits({bool clearPayers = false}) {
    for (final draft in _drafts) {
      draft.splitType = null;
      draft.splits = null;
      if (clearPayers) {
        draft.payerUserId = null;
      }
    }
  }

  String? _resolveDefaultPayerId(List<HouseholdMember> members) {
    if (members.isEmpty) return null;
    final currentUserId = ref.read(authProvider).uid;
    if (!members.any((member) => member.userId == currentUserId)) {
      return null;
    }
    final hasCurrentUser =
        members.any((member) => member.userId == currentUserId);
    return hasCurrentUser ? currentUserId : members.first.userId;
  }

  void _ensureDraftPayers(List<HouseholdMember> members) {
    final fallback = _resolveDefaultPayerId(members);
    if (fallback == null) return;
    for (final draft in _drafts) {
      final current = draft.payerUserId;
      final exists =
          current != null && members.any((member) => member.userId == current);
      if (!exists) {
        draft.payerUserId = fallback;
      }
    }
  }

  void _setHouseholdSelection(String householdId, {bool userInitiated = false}) {
    setState(() {
      _selectedHouseholdId = householdId;
      if (userInitiated) _userSelectedHousehold = true;
      _membersError = null;
      _householdMembers = null;
      _resetDraftSplits(clearPayers: true);
    });
    _loadMembers(householdId);
  }

  Future<void> _loadMembers(String householdId) async {
    setState(() {
      _isLoadingMembers = true;
      _membersError = null;
      _householdMembers = null;
    });

    try {
      final repository = ref.read(householdRepositoryProvider);
      final members = await repository.getHouseholdMembers(householdId);
      if (!mounted) return;
      setState(() {
        _householdMembers = members;
        if (_shareWithHousehold && !_isIncomeMode && members.isNotEmpty) {
          _ensureDraftPayers(members);
          for (final draft in _drafts) {
            if (draft.splitType == null ||
                draft.splits == null ||
                draft.splits!.isEmpty) {
              draft.splitType = SplitType.amount;
              draft.splits = buildDefaultMemberSplits(
                members: members,
                totalAmount: draft.value.amount,
              );
            }
          }
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _membersError = '${context.l10n.errorLoadingMembers}: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMembers = false;
        });
      }
    }
  }

  void _reconcileDraftSplitsAfterEdit(
    _TransactionDraft draft,
    ParsedExpense previous,
    ParsedExpense updated,
  ) {
    if (draft.splitType == null || draft.splits == null) return;
    if (draft.splitType != SplitType.amount) return;

    final oldTotal = previous.amount;
    final newTotal = updated.amount;
    if (oldTotal <= 0 || newTotal <= 0) {
      draft.splitType = null;
      draft.splits = null;
      return;
    }

    if ((oldTotal - newTotal).abs() < 0.005) return;

    final ratio = newTotal / oldTotal;
    draft.splits = draft.splits!
        .map((split) => split.copyWith(
              amount: (split.amount ?? 0) * ratio,
            ))
        .toList();
  }

  int get _selectedCount => _drafts.where((d) => d.selected).length;

  Map<String, double> get _selectedTotalsByCurrency {
    final totals = <String, double>{};
    for (final draft in _drafts.where((d) => d.selected)) {
      final currency = draft.value.currency.toUpperCase();
      totals[currency] = (totals[currency] ?? 0) + draft.value.amount;
    }
    return totals;
  }

  String? _buildOwedLabel({
    required _TransactionDraft draft,
    required String currentUserId,
    required List<HouseholdMember> members,
  }) {
    if (_isIncomeMode || !_shareWithHousehold) return null;
    if (members.isEmpty) return null;
    final total = draft.value.amount;
    if (total <= 0) return null;

    final splitType = draft.splitType ?? SplitType.amount;
    final splits = (draft.splits != null && draft.splits!.isNotEmpty)
        ? draft.splits!
        : buildDefaultMemberSplits(
            members: members,
            totalAmount: total,
          );

    double userShare = 0;
    if (splitType == SplitType.equal) {
      final memberCount = members.length;
      if (memberCount == 0) return null;
      userShare = total / memberCount;
    } else {
      final userSplitIndex =
          splits.indexWhere((s) => s.member.userId == currentUserId);
      if (userSplitIndex == -1) return null;
      final userSplit = splits[userSplitIndex];
      switch (splitType) {
        case SplitType.amount:
          userShare = userSplit.amount ?? 0;
          break;
        case SplitType.percentage:
          userShare = total * (userSplit.percentage ?? 0) / 100;
          break;
        case SplitType.shares:
          final totalShares =
              splits.fold<int>(0, (sum, s) => sum + (s.shares ?? 0));
          if (totalShares <= 0) return null;
          userShare = total * (userSplit.shares ?? 0) / totalShares;
          break;
        case SplitType.equal:
          break;
      }
    }

    if (userShare <= 0.01) return null;

    final payerId = draft.payerUserId ?? currentUserId;
    if (payerId == currentUserId) {
      final owed = total - userShare;
      if (owed <= 0.01) return null;
      return '${context.l10n.youAreOwed} ${draft.value.currencySymbol}${owed.toStringAsFixed(2)}';
    }

    return '${context.l10n.youOwe} ${draft.value.currencySymbol}${userShare.toStringAsFixed(2)}';
  }

  void _selectAll() {
    setState(() {
      for (final draft in _drafts) {
        draft.selected = true;
      }
    });
  }

  void _clearAll() {
    setState(() {
      for (final draft in _drafts) {
        draft.selected = false;
      }
    });
  }

  String? _validateDraft(ParsedExpense tx) {
    if (!tx.amount.isFinite || tx.amount <= 0) {
      return context.l10n.invalidAmount;
    }

    final today = _dateOnly(DateTime.now());
    final txDate = _dateOnly(toLocalTime(tx.date));
    if (txDate.isAfter(today)) {
      return 'Date cannot be in the future';
    }

    if (tx.currency.trim().isEmpty) {
      return context.l10n.pleaseSelectValidCurrency;
    }

    if (tx.category.trim().isEmpty) {
      return context.l10n.pleaseSelectCategory;
    }

    return null;
  }

  Future<void> _handleEditTransaction(int index) async {
    final original = _drafts[index].value;
    final allowSplitEditor = _shareWithHousehold && !_isIncomeMode;
    final members = allowSplitEditor ? _householdMembers : null;
    final initialPayerUserId = _drafts[index].payerUserId;
    final currentUserId = ref.read(authProvider).uid;

    final result = await showModalBottomSheet<_EditTransactionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Theme.of(context).colorScheme.surface.withValues(alpha: 0.0),
      builder: (sheetContext) {
        return _EditTransactionSheet(
          transaction: original,
          members: members,
          enableSplitEditor: allowSplitEditor,
          initialSplitType: _drafts[index].splitType,
          initialSplits: _drafts[index].splits,
          initialPayerUserId: initialPayerUserId,
          currentUserId: currentUserId,
          onCancel: () => Navigator.of(sheetContext).pop(),
          onSave: (updated) => Navigator.of(sheetContext).pop(updated),
        );
      },
    );

    if (!mounted || result == null) return;

    setState(() {
      final draft = _drafts[index];
      if (result.splitConfigProvided) {
        draft.splitType = result.splitType;
        draft.splits = result.splits;
        draft.payerUserId = result.payerUserId;
      } else {
        _reconcileDraftSplitsAfterEdit(draft, original, result.transaction);
      }
      draft
        ..value = result.transaction
        ..error = null;
    });
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;

    final selectedIndexes = <int>[];
    for (var i = 0; i < _drafts.length; i++) {
      if (_drafts[i].selected) selectedIndexes.add(i);
    }

    if (selectedIndexes.isEmpty) {
      AppToast.info(context, 'Select at least one transaction');
      return;
    }

    if (_shareWithHousehold &&
        (_selectedHouseholdId == null || _selectedHouseholdId!.isEmpty)) {
      AppToast.error(context, context.l10n.pleaseSelectHouseholdFirst);
      return;
    }
    if (_shareWithHousehold && !_isIncomeMode) {
      if (_isLoadingMembers) {
        AppToast.info(context, 'Loading group members...');
        return;
      }
      if (_householdMembers == null || _householdMembers!.isEmpty) {
        AppToast.error(
          context,
          _membersError ?? context.l10n.errorLoadingMembers,
        );
        return;
      }
    }

    final validationErrors = <int, String>{};
    for (final index in selectedIndexes) {
      final error = _validateDraft(_drafts[index].value);
      if (error != null) validationErrors[index] = error;
    }

    if (validationErrors.isNotEmpty) {
      setState(() {
        for (final entry in validationErrors.entries) {
          _drafts[entry.key].error = entry.value;
        }
      });
      AppToast.error(context, 'Please fix the highlighted items');
      final firstIndex = validationErrors.keys.reduce((a, b) => a < b ? a : b);
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          (firstIndex * 88).toDouble(),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final user = ref.read(authProvider);
    final householdId = _shareWithHousehold ? _selectedHouseholdId : null;

    final now = DateTime.now();

    int successCount = 0;
    final saveErrors = <int, String>{};

    try {
      String? receiptUrl;
      if (!_isIncomeMode) {
        final imagePath =
            widget.localImagePath ?? _drafts.first.value.localImagePath;
        if (imagePath != null && imagePath.isNotEmpty) {
          receiptUrl = await ref
              .read(expenseSaveNotifierProvider.notifier)
              .uploadReceiptImage(File(imagePath), user.uid);
        }
      }

      for (final index in selectedIndexes) {
        final draft = _drafts[index];
        final tx = draft.value;
        final baseDate = _dateOnly(toLocalTime(tx.date));
        final dateWithTime = DateTime(
          baseDate.year,
          baseDate.month,
          baseDate.day,
          now.hour,
          now.minute,
        );
        final updatedTx = tx.copyWith(date: dateWithTime);
        final hasSplits =
            draft.splits != null && draft.splits!.isNotEmpty;
        final splitType = (!_isIncomeMode && _shareWithHousehold && hasSplits)
            ? (draft.splitType ?? SplitType.amount)
            : null;
        final splits = splitType != null ? draft.splits : null;
        final payerUserId = (!_isIncomeMode && _shareWithHousehold)
            ? (draft.payerUserId ?? user.uid)
            : null;

        try {
          if (_isIncomeMode) {
            final saved = await ref.read(incomeSaveProvider.notifier).saveIncome(
                  userId: user.uid,
                  amount: updatedTx.amount,
                  category:
                      updatedTx.category.isNotEmpty ? updatedTx.category : 'income',
                  currency: updatedTx.currency,
                  date: updatedTx.date,
                  description: updatedTx.description,
                  householdId: householdId,
                );
            if (saved == null) {
              final state = ref.read(incomeSaveProvider);
              final err = state.whenOrNull(error: (e, _) => e);
              throw Exception(err ?? 'Failed to save income');
            }
          } else {
            await ref.read(expenseSaveNotifierProvider.notifier).saveExpense(
                  expense: updatedTx,
                  householdId: householdId,
                  receiptImageUrl: receiptUrl,
                  customSplitType: splitType,
                  customSplits: splits,
                  payerUserId: payerUserId,
                  invalidateProviders: false,
                );
          }
          successCount += 1;
        } catch (error) {
          saveErrors[index] = _formatSaveError(error);
        }
      }

      if (!_isIncomeMode && successCount > 0) {
        await ref
            .read(expenseSaveNotifierProvider.notifier)
            .invalidateAfterBatch(userId: user.uid, householdId: householdId);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          for (final entry in saveErrors.entries) {
            _drafts[entry.key].error = entry.value;
          }
        });
      }
    }

    if (!mounted) return;

    if (saveErrors.isEmpty) {
      Navigator.of(context).pop();
      AppToast.success(
        context,
        _isIncomeMode ? context.l10n.incomeSaved : context.l10n.expenseSaved,
      );
      return;
    }

    if (successCount == 0) {
      AppToast.error(context, 'Nothing was saved. Please review and try again.');
      return;
    }

    AppToast.info(
      context,
      'Saved $successCount, failed ${saveErrors.length}. Tap items to fix.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = ref.watch(authProvider);
    final householdsAsync = ref.watch(userHouseholdsProvider(user.uid));
    final selectedHouseholdState = ref.watch(selectedHouseholdProvider);

    final totals = _selectedTotalsByCurrency;
    final totalsLabel = totals.entries
        .map((e) => '${e.key} ${e.value.toStringAsFixed(2)}')
        .join(' • ');
    final allSelected =
        _drafts.isNotEmpty && _selectedCount == _drafts.length;
    final selectionLabel =
        allSelected ? context.l10n.deselectAll : context.l10n.selectAll;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: PopScope(
        canPop: !_isSaving,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.only(left: 8, top: 4, bottom: 8, right: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left,
                        color: colorScheme.foreground, size: 28),
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                  Expanded(
                    child: Text(
                      '${context.l10n.confirm} ${context.l10n.transactions}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.foreground,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: _isSaving
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colorScheme.foreground,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.check_rounded,
                            color: colorScheme.foreground,
                            size: 28,
                          ),
                    onPressed: _isSaving ? null : _handleSave,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$_selectedCount / ${_drafts.length} ${context.l10n.items} • ${context.l10n.totalAmount}: $totalsLabel',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.mutedForeground,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            householdsAsync.when(
              data: (List<Household> households) {
                if (households.isEmpty) return const SizedBox();

                final headerSelectedId =
                    selectedHouseholdState.householdId ??
                        selectedHouseholdState.household?.id;
                final headerInList = headerSelectedId != null &&
                    households.any((h) => h.id == headerSelectedId);
                final preferredId =
                    headerInList ? headerSelectedId : households.first.id;
                final selectedIsValid = _selectedHouseholdId != null &&
                    _selectedHouseholdId!.isNotEmpty &&
                    households.any((h) => h.id == _selectedHouseholdId);

                if (_shareWithHousehold && households.isNotEmpty) {
                  final shouldAutoSelect = !selectedIsValid ||
                      (!_userSelectedHousehold &&
                          _selectedHouseholdId != preferredId);
                  if (shouldAutoSelect && _selectedHouseholdId != preferredId) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      _setHouseholdSelection(preferredId);
                    });
                  }
                }

                final dropdownValue =
                    selectedIsValid ? _selectedHouseholdId : preferredId;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.muted.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                context.l10n.shareWithHousehold,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.foreground,
                                ),
                              ),
                            ),
                            MonekoSwitch(
                              value: _shareWithHousehold,
                              onChanged: _isSaving
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _shareWithHousehold = value;
                                        if (!value) {
                                          _membersError = null;
                                          _householdMembers = null;
                                          _isLoadingMembers = false;
                                          _resetDraftSplits(clearPayers: true);
                                        }
                                      });
                                      if (value) {
                                        final nextId = selectedIsValid
                                            ? _selectedHouseholdId
                                            : preferredId;
                                        if (nextId != null &&
                                            nextId.isNotEmpty) {
                                          _setHouseholdSelection(nextId);
                                        }
                                      }
                                    },
                            ),
                          ],
                        ),
                        if (_shareWithHousehold) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  context.l10n.household,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colorScheme.mutedForeground,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: dropdownValue,
                                  items: households
                                      .map(
                                        (h) => DropdownMenuItem<String>(
                                          value: h.id,
                                          child: Text(
                                            h.name,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: _isSaving
                                      ? null
                                      : (value) {
                                          if (value == null) return;
                                          _setHouseholdSelection(
                                            value,
                                            userInitiated: true,
                                          );
                                        },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                      ],
                    ),
                  ),
                );
              },
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _isSaving
                      ? null
                      : (allSelected ? _clearAll : _selectAll),
                  child: Text(
                    selectionLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _isSaving
                          ? colorScheme.mutedForeground
                          : colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                itemCount: _drafts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final draft = _drafts[index];
                  final tx = draft.value;
                  final dateLabel = _formatRelativeDate(tx.date, context);
                  final categoryLabel = getCategoryTranslation(context, tx.category);
                  final owedLabel = (_shareWithHousehold &&
                          !_isIncomeMode &&
                          _householdMembers != null)
                      ? _buildOwedLabel(
                          draft: draft,
                          currentUserId: user.uid,
                          members: _householdMembers!,
                        )
                      : null;

                  final error = draft.error;
                  final borderColor = error != null
                      ? colorScheme.error.withValues(alpha: 0.6)
                      : colorScheme.border.withValues(alpha: 0.6);

                  return Container(
                    decoration: BoxDecoration(
                      color: colorScheme.muted.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: ListTile(
                      onTap: _isSaving ? null : () => _handleEditTransaction(index),
                      leading: Checkbox(
                        value: draft.selected,
                        onChanged: _isSaving
                            ? null
                            : (value) {
                                setState(() {
                                  draft.selected = value ?? false;
                                });
                              },
                      ),
                      title: Text(
                        '${_isIncomeMode ? '+' : '-'}${tx.currencySymbol}${tx.amount.toStringAsFixed(2)}  •  $categoryLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            '$dateLabel • ${tx.currency.toUpperCase()}',
                            style: TextStyle(
                              color: colorScheme.mutedForeground,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if ((tx.description ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              tx.description!.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colorScheme.mutedForeground,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          if (owedLabel != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              owedLabel,
                              style: TextStyle(
                                color: colorScheme.mutedForeground,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (error != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              error,
                              style: TextStyle(
                                color: colorScheme.error,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: Icon(
                        PlatformInfo.isIOS ? CupertinoIcons.pencil : Icons.edit,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                  );
                },
              ),
            ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: PrimaryAdaptiveButton(
                    onPressed: _isSaving ? null : _handleSave,
                    child: _isSaving
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context)
                                    .colorScheme
                                    .primaryForeground,
                              ),
                            ),
                          )
                        : Text(
                            _isIncomeMode
                                ? '${context.l10n.save} $_selectedCount ${context.l10n.items}'
                                : '${context.l10n.save} $_selectedCount ${context.l10n.items}',
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditTransactionResult {
  final ParsedExpense transaction;
  final SplitType? splitType;
  final List<MemberSplit>? splits;
  final String? payerUserId;
  final bool splitConfigProvided;

  const _EditTransactionResult({
    required this.transaction,
    this.splitType,
    this.splits,
    this.payerUserId,
    this.splitConfigProvided = false,
  });
}

class _EditTransactionSheet extends StatefulWidget {
  final ParsedExpense transaction;
  final VoidCallback onCancel;
  final ValueChanged<_EditTransactionResult> onSave;
  final bool enableSplitEditor;
  final List<HouseholdMember>? members;
  final SplitType? initialSplitType;
  final List<MemberSplit>? initialSplits;
  final String? initialPayerUserId;
  final String currentUserId;

  const _EditTransactionSheet({
    required this.transaction,
    required this.onCancel,
    required this.onSave,
    required this.enableSplitEditor,
    required this.members,
    required this.initialSplitType,
    required this.initialSplits,
    required this.initialPayerUserId,
    required this.currentUserId,
  });

  @override
  State<_EditTransactionSheet> createState() => _EditTransactionSheetState();
}

class _EditTransactionSheetState extends State<_EditTransactionSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;

  late DateTime _date;
  late String _currency;
  late String _currencySymbol;
  late String _category;
  late double _amountValue;

  String? _error;
  String? _splitError;
  SplitType? _splitType;
  List<MemberSplit>? _splits;
  String? _selectedPayerUserId;

  bool get _isIncomeMode => widget.transaction.isIncome;
  bool get _showSplitEditor => widget.enableSplitEditor && !_isIncomeMode;
  bool get _hasMembers => widget.members != null && widget.members!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _amountController =
        TextEditingController(text: widget.transaction.amount.toStringAsFixed(2));
    _descriptionController =
        TextEditingController(text: widget.transaction.description ?? '');
    _date = _dateOnly(toLocalTime(widget.transaction.date));
    _currency = widget.transaction.currency.toUpperCase();
    _currencySymbol = widget.transaction.currencySymbol;
    _category = widget.transaction.category;
    _amountValue = widget.transaction.amount;

    if (_showSplitEditor && _hasMembers) {
      _selectedPayerUserId =
          _resolveDefaultPayerId(widget.members!, widget.initialPayerUserId);
      if (widget.initialSplits != null && widget.initialSplits!.isNotEmpty) {
        _splitType = widget.initialSplitType ?? SplitType.amount;
        _splits = widget.initialSplits;
      } else {
        _splitType = widget.initialSplitType ?? SplitType.amount;
        _splits = buildDefaultMemberSplits(
          members: widget.members!,
          totalAmount: _amountValue,
        );
      }
    }
  }

  String? _resolveDefaultPayerId(
    List<HouseholdMember> members,
    String? preferredId,
  ) {
    if (members.isEmpty) return null;
    if (preferredId != null &&
        members.any((member) => member.userId == preferredId)) {
      return preferredId;
    }
    final hasCurrentUser =
        members.any((member) => member.userId == widget.currentUserId);
    return hasCurrentUser ? widget.currentUserId : members.first.userId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    DateTime? result;
    final currentDate = toLocalTime(_date);

    if (PlatformInfo.isIOS) {
      DateTime temp = currentDate;
      result = await showCupertinoModalPopup<DateTime>(
        context: context,
        builder: (context) {
          return Container(
            height: 300,
            color: CupertinoColors.systemBackground.resolveFrom(context),
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: CupertinoColors.separator.resolveFrom(context),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(context),
                        child: Text(context.l10n.cancel),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(context, temp),
                        child: Text(context.l10n.done),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: currentDate,
                    minimumDate: DateTime(2020),
                    maximumDate: DateTime.now(),
                    onDateTimeChanged: (value) => temp = value,
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else {
      result = await showDatePicker(
        context: context,
        initialDate: currentDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
      );
    }

    if (result != null) {
      setState(() {
        _date = result!;
      });
    }
  }

  Future<void> _pickCurrency() async {
    final selected = await showCurrencyPicker(
      context: context,
      currentCurrency: _currency,
    );

    if (selected == null) return;
    setState(() {
      _currency = selected.toUpperCase();
      _currencySymbol = resolveCurrencySymbol(_currency);
    });
  }

  Future<void> _pickCategory() async {
    final baseCategories =
        _isIncomeMode ? getIncomeCategories() : getExpenseCategories();
    final normalizedCurrent = _category.toLowerCase();
    final categories = () {
      if (!baseCategories.contains(normalizedCurrent)) {
        return [...baseCategories, normalizedCurrent];
      }
      return baseCategories;
    }();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Theme.of(context).colorScheme.surface.withValues(alpha: 0.0),
      builder: (sheetContext) {
        return CategoryPickerBottomSheet(
          allCategories: categories,
          selectedCategories: <String>[normalizedCurrent],
          isSingleSelect: true,
          onChanged: (value) {
            final next = value.isNotEmpty ? value.first : null;
            if (next == null) return;
            setState(() {
              _category = next;
            });
            Navigator.of(sheetContext).pop();
          },
        );
      },
    );
  }

  void _handleAmountChanged(String text) {
    final normalized = _normalizeNumberInput(text);
    final parsed = double.tryParse(normalized);
    if (parsed == null || !parsed.isFinite || parsed <= 0) return;
    if ((parsed - _amountValue).abs() < 0.005) return;
    setState(() {
      _amountValue = parsed;
      _splitError = null;
    });
  }

  String? _validateSplitForSave() {
    if (!_showSplitEditor || !_hasMembers) return null;

    final type = _splitType ?? SplitType.amount;
    final splits = _splits ??
        buildDefaultMemberSplits(
          members: widget.members!,
          totalAmount: _amountValue,
        );

    switch (type) {
      case SplitType.amount:
        final includedCount =
            splits.where((s) => s.includedInAmount).length;
        if (includedCount == 0) {
          return context.l10n.atLeastOneMember;
        }
        final totalSplit = splits.fold<double>(
          0,
          (sum, split) => sum + (split.amount ?? 0),
        );
        if ((totalSplit - _amountValue).abs() > 0.01) {
          return context.l10n.splitAmountsMustEqual(
            _currencySymbol,
            _amountValue.toStringAsFixed(2),
            _currencySymbol,
          );
        }
        break;
      case SplitType.percentage:
        final includedCount =
            splits.where((s) => s.includedInPercentage).length;
        if (includedCount == 0) {
          return context.l10n.atLeastOneMember;
        }
        final totalPercent = splits.fold<double>(
          0,
          (sum, split) => sum + (split.percentage ?? 0),
        );
        if ((totalPercent - 100).abs() > 0.01) {
          return context.l10n.percentagesMustTotal100;
        }
        break;
      case SplitType.shares:
        final totalShares =
            splits.fold<int>(0, (sum, split) => sum + (split.shares ?? 0));
        if (totalShares <= 0) {
          return context.l10n.memberMustHaveShare;
        }
        break;
      case SplitType.equal:
        break;
    }

    return null;
  }

  void _save() {
    setState(() {
      _error = null;
      _splitError = null;
    });

    final normalized = _normalizeNumberInput(_amountController.text);
    final parsed = double.tryParse(normalized);
    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      setState(() {
        _error = context.l10n.invalidAmount;
      });
      return;
    }

    final today = _dateOnly(DateTime.now());
    final txDate = _dateOnly(toLocalTime(_date));
    if (txDate.isAfter(today)) {
      setState(() {
        _error = 'Date cannot be in the future';
      });
      return;
    }

    final splitError = _validateSplitForSave();
    if (splitError != null) {
      setState(() {
        _splitError = splitError;
      });
      return;
    }

    final splitConfigProvided = _showSplitEditor && _hasMembers;
    final effectiveSplitType =
        splitConfigProvided ? (_splitType ?? SplitType.amount) : null;
    List<MemberSplit>? effectiveSplits;
    String? effectivePayerUserId;
    if (splitConfigProvided) {
      effectiveSplits = _splits;
      if (effectiveSplits == null || effectiveSplits.isEmpty) {
        effectiveSplits = buildDefaultMemberSplits(
          members: widget.members!,
          totalAmount: _amountValue,
        );
      }
      effectivePayerUserId = _selectedPayerUserId ?? widget.currentUserId;
    }

    final updated = widget.transaction.copyWith(
      amount: parsed,
      currency: _currency,
      currencySymbol: _currencySymbol,
      category: _category,
      date: _date,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
    );

    widget.onSave(_EditTransactionResult(
      transaction: updated,
      splitType: effectiveSplitType,
      splits: effectiveSplits,
      payerUserId: effectivePayerUserId,
      splitConfigProvided: splitConfigProvided,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateLabel = DateFormat.yMMMMd(Localizations.localeOf(context).toString())
        .format(toLocalTime(_date));
    final categoryLabel = getCategoryTranslation(context, _category);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.details,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.foreground,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: _handleAmountChanged,
                      decoration: InputDecoration(
                        labelText: context.l10n.amount,
                        prefixText: _currencySymbol,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _EditRow(
                      label: context.l10n.currency,
                      value: _currency,
                      onTap: _pickCurrency,
                    ),
                    const SizedBox(height: 8),
                    _EditRow(
                      label: context.l10n.category,
                      value: categoryLabel,
                      onTap: _pickCategory,
                    ),
                    const SizedBox(height: 8),
                    _EditRow(
                      label: context.l10n.date,
                      value: dateLabel,
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: context.l10n.notes,
                        border: const OutlineInputBorder(),
                      ),
                      minLines: 1,
                      maxLines: 3,
                    ),
                    if (_showSplitEditor) ...[
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          context.l10n.splitExpense,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.foreground,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (!_hasMembers)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.muted.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.border.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            context.l10n.selectHouseholdToConfigureSplit,
                            style:
                                TextStyle(color: colorScheme.mutedForeground),
                          ),
                        )
                      else
                        GroupSplitEditorSection(
                          members: widget.members!,
                          selectedPayerUserId: _selectedPayerUserId,
                          onPayerChanged: (value) {
                            setState(() {
                              _selectedPayerUserId = value;
                            });
                          },
                          totalAmount: _amountValue,
                          currencySymbol: _currencySymbol,
                          initialSplitType: _splitType,
                          initialSplits: _splits,
                          onSplitChanged: (splitType, splits) {
                            setState(() {
                              _splitType = splitType;
                              _splits = splits;
                              _splitError = null;
                            });
                          },
                        ),
                      if (_splitError != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _splitError!,
                          style: TextStyle(
                            color: colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: PlainAdaptiveButton(
                      onPressed: widget.onCancel,
                      child: Text(context.l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryAdaptiveButton(
                      onPressed: _save,
                      child: Text(context.l10n.save),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _EditRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.muted.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.mutedForeground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: colorScheme.mutedForeground,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
