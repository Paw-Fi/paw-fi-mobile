import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/shared/widgets/modal_sheet_handle.dart';
import 'package:moneko/shared/widgets/moneko_tab_bar_view.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/shared/widgets/transaction_edit_handlers.dart';

Future<TransactionExportRequest?> showTransactionExportOptionsSheet({
  required BuildContext context,
  required List<Household> spaces,
  required String personalLabel,
}) {
  return showModalBottomSheet<TransactionExportRequest>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface.withValues(
          alpha: 0.0,
        ),
    builder: (context) => TransactionExportOptionsSheet(
      spaces: spaces,
      personalLabel: personalLabel,
    ),
  );
}

enum TransactionExportFormat { excel, receiptsZip }

enum TransactionExportSpaceType { all, personal, household }

class TransactionExportSpaceOption {
  const TransactionExportSpaceOption._({
    required this.type,
    required this.label,
    this.householdId,
  });

  const TransactionExportSpaceOption.all(String label)
      : this._(
          type: TransactionExportSpaceType.all,
          label: label,
        );

  const TransactionExportSpaceOption.personal(String label)
      : this._(
          type: TransactionExportSpaceType.personal,
          label: label,
        );

  const TransactionExportSpaceOption.household({
    required String householdId,
    required String label,
  }) : this._(
          type: TransactionExportSpaceType.household,
          householdId: householdId,
          label: label,
        );

  final TransactionExportSpaceType type;
  final String label;
  final String? householdId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TransactionExportSpaceOption &&
            other.type == type &&
            other.householdId == householdId;
  }

  @override
  int get hashCode => Object.hash(type, householdId);
}

class TransactionExportRequest {
  const TransactionExportRequest({
    required this.format,
    required this.space,
    required this.dateRange,
  });

  final TransactionExportFormat format;
  final TransactionExportSpaceOption space;
  final DateTimeRange dateRange;
}

class TransactionExportOptionsSheet extends StatefulWidget {
  const TransactionExportOptionsSheet({
    super.key,
    required this.spaces,
    required this.personalLabel,
  });

  final List<Household> spaces;
  final String personalLabel;

  @override
  State<TransactionExportOptionsSheet> createState() =>
      _TransactionExportOptionsSheetState();
}

class _TransactionExportOptionsSheetState
    extends State<TransactionExportOptionsSheet> {
  late TransactionExportFormat _format;
  late TransactionExportSpaceOption _space;
  late DateTime _fromDate;
  late DateTime _toDate;
  var _spaceInitialized = false;

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    _format = TransactionExportFormat.excel;
    _fromDate = DateTime(today.year, today.month, 1);
    _toDate = today;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_spaceInitialized) return;
    _space = TransactionExportSpaceOption.all(context.l10n.all);
    _spaceInitialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.sheetBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ModalSheetHandle(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.l10n.exportTransactions,
                          style: textTheme.titleLarge?.copyWith(
                            color: scheme.foreground,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close_rounded,
                          color: scheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 8, bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          MonekoSegmentedControl(
                            labels: [
                              context.l10n.exportExcel,
                              context.l10n.exportReceiptsZip,
                            ],
                            selectedIndex:
                                _format == TransactionExportFormat.excel
                                    ? 0
                                    : 1,
                            height: 52,
                            onValueChanged: (index) {
                              setState(() {
                                _format = index == 0
                                    ? TransactionExportFormat.excel
                                    : TransactionExportFormat.receiptsZip;
                              });
                            },
                          ),
                          const SizedBox(height: 24),
                          _SpaceSelectionTile(
                            value: _space,
                            options: _spaceOptions(context),
                            onChanged: (value) =>
                                setState(() => _space = value),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            decoration: BoxDecoration(
                              color: scheme.cardSurface,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: scheme.shadow.withValues(
                                    alpha: scheme.brightness == Brightness.dark
                                        ? 0.15
                                        : 0.05,
                                  ),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                _DateSelectionRow(
                                  label: context.l10n.from,
                                  date: _fromDate,
                                  onTap: _pickFromDate,
                                ),
                                _DateSelectionRow(
                                  label: context.l10n.to,
                                  date: _toDate,
                                  onTap: _pickToDate,
                                ),
                              ],
                            ),
                          ),                        
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  PrimaryAdaptiveButton(
                    onPressed: _submit,
                    child:  Text(context.l10n.exportTransactions),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<TransactionExportSpaceOption> _spaceOptions(BuildContext context) {
    return [
      TransactionExportSpaceOption.all(context.l10n.all),
      TransactionExportSpaceOption.personal(
        widget.personalLabel.trim().isEmpty
            ? context.l10n.personalScope
            : widget.personalLabel.trim(),
      ),
      ...widget.spaces.map(
        (space) => TransactionExportSpaceOption.household(
          householdId: space.id,
          label: space.name,
        ),
      ),
    ];
  }

  Future<void> _pickFromDate() async {
    final picked = await TransactionEditHandlers.editDate(
      context,
      currentDate: _fromDate,
      firstDate: DateTime(2000),
      lastDate: _toDate,
    );
    if (picked == null || !mounted) return;
    setState(() => _fromDate = _dateOnly(picked));
  }

  Future<void> _pickToDate() async {
    final picked = await TransactionEditHandlers.editDate(
      context,
      currentDate: _toDate,
      firstDate: _fromDate,
      lastDate: _dateOnly(DateTime.now()),
    );
    if (picked == null || !mounted) return;
    setState(() => _toDate = _dateOnly(picked));
  }

  void _submit() {
    Navigator.of(context).pop(
      TransactionExportRequest(
        format: _format,
        space: _space,
        dateRange: DateTimeRange(start: _fromDate, end: _toDate),
      ),
    );
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

class _SpaceSelectionTile extends StatelessWidget {
  const _SpaceSelectionTile({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final TransactionExportSpaceOption value;
  final List<TransactionExportSpaceOption> options;
  final ValueChanged<TransactionExportSpaceOption> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AdaptivePopupMenuButton.widget<TransactionExportSpaceOption>(
      items: options.map((option) {
        return AdaptivePopupMenuItem(
          label: option.label,
          icon: option.type == TransactionExportSpaceType.all
              ? (PlatformInfo.isIOS26OrHigher() ? 'chart.pie.fill' : Icons.pie_chart)
              : option.type == TransactionExportSpaceType.personal
                  ? (PlatformInfo.isIOS26OrHigher()
                      ? 'person.crop.circle.fill'
                      : Icons.account_circle)
                  : (PlatformInfo.isIOS26OrHigher() ? 'person.2.fill' : Icons.group),
          value: option,
        );
      }).toList(),
      onSelected: (index, item) {
        if (item.value != null) {
          onChanged(item.value!);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: scheme.cardSurface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(
                alpha: scheme.brightness == Brightness.dark ? 0.15 : 0.05,
              ),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                size: 20,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.space,
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.mutedForeground,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value.label,
                    style: textTheme.titleMedium?.copyWith(
                      color: scheme.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 24,
              color: scheme.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }
}

class _DateSelectionRow extends StatelessWidget {
  const _DateSelectionRow({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final dateLabel = DateFormat('MMM d, yyyy').format(date);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: textTheme.bodyLarge?.copyWith(
                  color: scheme.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.muted.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                dateLabel,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.foreground,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
