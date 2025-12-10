import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'package:moneko/core/core.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/insights/presentation/widgets/insights_ui.dart';
import 'package:moneko/features/insights/presentation/widgets/scenario_result_sheet.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/shared/widgets/subtle_adaptive_button.dart';

/// Supported sentence word orders for arranging the scenario inputs
enum _WordOrder { svo, sov, vso, v2 }

Widget buildScenarioPlanningTab(
    BuildContext context, ColorScheme colorScheme, AnalyticsData analyticsData,
    {String? selectedCurrency}) {
  return ScenarioPlanningTabContent(
      context: context,
      colorScheme: colorScheme,
      analyticsData: analyticsData,
      selectedCurrency: selectedCurrency);
}

class ScenarioPlanningTabContent extends ConsumerStatefulWidget {
  final BuildContext context;
  final ColorScheme colorScheme;
  final AnalyticsData analyticsData;
  final String? selectedCurrency;

  const ScenarioPlanningTabContent({
    super.key,
    required this.context,
    required this.colorScheme,
    required this.analyticsData,
    this.selectedCurrency,
  });

  @override
  ConsumerState<ScenarioPlanningTabContent> createState() =>
      _ScenarioPlanningTabContentState();
}

class _Affixes {
  final String prefix;
  final String suffix;
  const _Affixes(this.prefix, this.suffix);
}

class _ScenarioPlanningTabContentState
    extends ConsumerState<ScenarioPlanningTabContent> {
  final TextEditingController _scenarioQuestionController =
      TextEditingController();
  DateTime? _scenarioDate;
  bool _scenarioLoading = false;

  /// Format date according to locale-specific pattern with comprehensive fallback support
  String _formatLocalizedDate(DateTime date) {
    final locale = Localizations.localeOf(context);
    final dateFormat = context.l10n.scenarioDateFormat;

    try {
      // Try locale-specific formatting first
      return DateFormat(dateFormat, locale.languageCode).format(date);
    } catch (e) {
      debugPrint('Locale-specific date formatting failed: $e');

      try {
        // Fallback to locale without country code
        return DateFormat(dateFormat).format(date);
      } catch (e2) {
        debugPrint('Generic date formatting failed: $e2');

        // Ultimate fallback based on language family
        return _formatDateByLanguageFamily(date, locale.languageCode);
      }
    }
  }

  /// Check if the current language is right-to-left
  bool _isRTL() {
    final locale = Localizations.localeOf(context);
    final rtlLanguages = ['ar', 'he', 'fa', 'ur', 'ps', 'sd', 'ku', 'yi'];
    return rtlLanguages.contains(locale.languageCode);
  }

  /// Get text direction for the current locale
  ui.TextDirection getTextDirection() {
    return _isRTL() ? ui.TextDirection.rtl : ui.TextDirection.ltr;
  }

  _Affixes _beforeAffixes() {
    final raw = context.l10n.before.trim();
    const marker = '...';
    if (raw.contains(marker)) {
      final idx = raw.indexOf(marker);
      final pre = raw.substring(0, idx).trim();
      final suf = raw.substring(idx + marker.length).trim();
      return _Affixes(pre, suf);
    }
    // default: entire token is the prefix (e.g., "before")
    return _Affixes(raw, '');
  }

  /// Show a platform-specific date picker (Cupertino for iOS, Material otherwise)
  Future<void> _pickTargetDate(BuildContext context) async {
    final now = DateTime.now();
    final initial = _scenarioDate ?? now;

    final platform = Theme.of(context).platform;
    final useCupertino = platform == TargetPlatform.iOS;

    if (useCupertino) {
      DateTime temp = DateTime(initial.year, initial.month, initial.day);
      await showCupertinoModalPopup<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) {
          final bg = widget.colorScheme.appBackground;
          return Material(
            color: Colors.transparent,
            child: Container(
              height: 320,
              color: bg,
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: Text(context.l10n.close,
                                style: TextStyle(
                                    color: widget.colorScheme.mutedForeground)),
                          ),
                          const Spacer(),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              setState(() {
                                _scenarioDate =
                                    DateTime(temp.year, temp.month, temp.day);
                              });
                              Navigator.of(ctx).pop();
                            },
                            child: Text(context.l10n.done,
                                style: TextStyle(
                                    color: widget.colorScheme.primary,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.date,
                        initialDateTime: initial.isBefore(now) ? now : initial,
                        minimumDate: DateTime(now.year, now.month, now.day),
                        maximumDate: DateTime(now.year + 2, now.month, now.day),
                        onDateTimeChanged: (dt) {
                          temp = DateTime(dt.year, dt.month, dt.day);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } else {
      final picked = await showDatePicker(
        context: context,
        initialDate: initial.isBefore(now) ? now : initial,
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: DateTime(now.year + 2, now.month, now.day),
        helpText: context.l10n.selectTargetDate,
      );
      if (picked != null) {
        setState(() {
          _scenarioDate = DateTime(picked.year, picked.month, picked.day);
        });
      }
    }
  }

  /// Detect preferred sentence word order by device language to arrange inputs
  _WordOrder _detectWordOrder() {
    final lang = Localizations.localeOf(context).languageCode.toLowerCase();

    // Families based on user's specification and common grammatical tendencies
    const sov = {'zh', 'ja', 'ko', 'hi', 'ur', 'tr', 'fa'};
    const vso = {'es', 'fr', 'ar'};
    const v2 = {'de'};

    if (sov.contains(lang)) return _WordOrder.sov;
    if (vso.contains(lang)) return _WordOrder.vso;
    if (v2.contains(lang)) return _WordOrder.v2;
    return _WordOrder.svo; // default/fallback
  }

  /// Ultimate fallback date formatting by language family
  String _formatDateByLanguageFamily(DateTime date, String languageCode) {
    switch (languageCode.toLowerCase()) {
      // Chinese family - uses YYYY/MM/DD
      case 'zh':
      case 'ja':
      case 'ko':
        return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

      // Germanic family - uses DD.MM.YYYY
      case 'de':
      case 'nl':
      case 'sv':
      case 'no':
      case 'da':
      case 'is':
        return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

      // Romance family - uses DD/MM/YYYY
      case 'es':
      case 'fr':
      case 'it':
      case 'pt':
      case 'ro':
      case 'ca':
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

      // Slavic family - uses DD.MM.YYYY
      case 'ru':
      case 'pl':
      case 'cs':
      case 'sk':
      case 'uk':
      case 'bg':
      case 'hr':
      case 'sr':
      case 'sl':
        return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

      // Arabic family - uses DD/MM/YYYY
      case 'ar':
      case 'he':
      case 'fa':
      case 'ur':
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

      // Indian family - uses DD-MM-YYYY
      case 'hi':
      case 'bn':
      case 'ta':
      case 'te':
      case 'ml':
      case 'kn':
      case 'gu':
      case 'pa':
        return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';

      // Southeast Asian family - uses DD/MM/YYYY
      case 'th':
      case 'vi':
      case 'id':
      case 'ms':
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

      // Turkic family - uses DD.MM.YYYY
      case 'tr':
      case 'az':
      case 'kk':
      case 'ky':
      case 'uz':
        return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

      // Default to ISO format for unknown languages
      default:
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  void dispose() {
    _scenarioQuestionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark =
        widget.colorScheme.appBackground == AppTheme.darkBackground;
    final user = ref.watch(authProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final viewMode = ref.watch(viewModeProvider);
    final selectedHousehold = ref.watch(selectedHouseholdProvider);
    final bool isHousehold = viewMode.mode == ViewMode.household;
    final String? householdId =
        isHousehold ? selectedHousehold.householdId : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scenario Planning Input
          InsightsSectionCard(
            colorScheme: widget.colorScheme,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.aiScenarioPlanning,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: widget.colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.askAiFinancialAdvisor,
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 16),
                Directionality(
                  textDirection: getTextDirection(),
                  child: Builder(
                    builder: (context) {
                      final order = _detectWordOrder();

                      // Common parts
                      final canI = Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(
                          context.l10n.canI,
                          style: TextStyle(
                              color: widget.colorScheme.foreground,
                              fontWeight: FontWeight.w600),
                        ),
                      );

                      final actionField = Expanded(
                        child: TextField(
                          controller: _scenarioQuestionController,
                          decoration: InputDecoration(
                            hintText: context.l10n.buyALaptop,
                            hintStyle: TextStyle(
                                color: widget.colorScheme.mutedForeground),
                            filled: true,
                            fillColor: isDark
                                ? AppTheme.darkInputBg
                                : AppTheme.lightInputBg,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: widget.colorScheme.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: widget.colorScheme.primary),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          style:
                              TextStyle(color: widget.colorScheme.foreground),
                          keyboardType: TextInputType.text,
                        ),
                      );

                      final beforePrefixLabel = () {
                        final t = _beforeAffixes().prefix;
                        if (t.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            t,
                            style: TextStyle(
                                color: widget.colorScheme.foreground,
                                fontWeight: FontWeight.w600),
                          ),
                        );
                      }();

                      final beforeSuffixLabel = () {
                        final t = _beforeAffixes().suffix;
                        if (t.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                          child: Text(
                            t,
                            style: TextStyle(
                                color: widget.colorScheme.foreground,
                                fontWeight: FontWeight.w600),
                          ),
                        );
                      }();

                      final dateButton = SubtleAdaptiveButton(
                        onPressed: () => _pickTargetDate(context),
                        child: Text(_scenarioDate == null
                            ? context.l10n.pickDate
                            : _formatLocalizedDate(_scenarioDate!)),
                      );

                      Widget buildPrimaryButton({bool expand = true}) {
                        final btn = SizedBox(
                          height: 40,
                          child: PrimaryAdaptiveButton(
                            onPressed: _scenarioLoading
                                ? null
                                : () async {
                                    final q =
                                        _scenarioQuestionController.text.trim();
                                    final d = _scenarioDate == null
                                        ? ''
                                        : _formatLocalizedDate(_scenarioDate!);
                                    if (q.isEmpty || d.isEmpty) {
                                      AppToast.info(
                                          context,
                                          context
                                              .l10n.enterQuestionAndPickDate);
                                      return;
                                    }

                                    setState(() {
                                      _scenarioLoading = true;
                                    });

                                    // Show loading modal
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (dialogContext) => PopScope(
                                        canPop: false,
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.all(32),
                                            decoration: BoxDecoration(
                                              color: colorScheme.appBackground,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Image.asset(
                                                  'lib/assets/gifs/loading-anim.gif',
                                                  width: 80,
                                                  height: 80,
                                                ),
                                                const SizedBox(height: 16),
                                                Text(
                                                  context
                                                      .l10n.analyzingScenario,
                                                  style: TextStyle(
                                                    color:
                                                        colorScheme.foreground,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  context
                                                      .l10n.thisMightTakeAWhile,
                                                  style: TextStyle(
                                                    color: colorScheme
                                                        .mutedForeground,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );

                                    bool sheetOpened = false;

                                    try {
                                      final payload = <String, dynamic>{
                                        'question': context.l10n
                                            .scenarioQuestionTemplate(
                                          q,
                                          d,
                                        ),
                                        'targetDate': d,
                                        'userId': user
                                            .uid, // Not trusted by BE, just for logs
                                        'language':
                                            Localizations.localeOf(context)
                                                .languageCode,
                                        'currency':
                                            widget.selectedCurrency ?? 'USD',
                                        'mode': isHousehold
                                            ? 'household'
                                            : 'personal',
                                      };

                                      if (householdId != null) {
                                        payload['householdId'] = householdId;
                                      }

                                      // Stream the AI scenario planner response (NDJSON)
                                      final client = supabase; // SupabaseClient from core/resources/lib/supabase.dart
                                      final uri = Uri.parse(
                                        '${Constants.supabaseUrl}/functions/v1/ai-scenario-planner',
                                      );

                                      final accessToken =
                                          client.auth.currentSession?.accessToken;
                                      if (accessToken == null ||
                                          accessToken.isEmpty) {
                                        throw Exception(
                                            'Missing access token for scenario planner');
                                      }

                                      final headers = <String, String>{
                                        'Content-Type': 'application/json',
                                        'Accept':
                                            'application/x-ndjson, application/json',
                                        'Authorization': 'Bearer $accessToken',
                                        // Use the public anon key so Supabase can authorize the function call
                                        'apikey': Constants.supabaseAnon,
                                      };

                                      final request = http.Request('POST', uri)
                                        ..headers.addAll(headers)
                                        ..body = jsonEncode(payload);

                                      final streamedResponse =
                                          await http.Client().send(request);

                                      if (streamedResponse.statusCode != 200) {
                                        final bodyText = await streamedResponse
                                            .stream
                                            .bytesToString();
                                        throw Exception(
                                          'Failed to analyze scenario (HTTP ${streamedResponse.statusCode}): $bodyText',
                                        );
                                      }

                                      final lineStream = streamedResponse.stream
                                          .transform(utf8.decoder)
                                          .transform(const LineSplitter());

                                      final adviceNotifier =
                                          ValueNotifier<String>('');
                                      final isCompleteNotifier =
                                          ValueNotifier<bool>(false);
                                      Map<String, dynamic> meta = {};
                                      bool done = false;
                                      bool gotMeta = false;

                                      await for (final line in lineStream) {
                                        if (line.trim().isEmpty) continue;
                                        final obj = jsonDecode(line)
                                            as Map<String, dynamic>;
                                        final type = obj['type'] as String?;
                                        switch (type) {
                                          case 'meta':
                                            final rawMeta = obj['meta'];
                                            if (rawMeta is Map) {
                                              meta = rawMeta
                                                  .cast<String, dynamic>();
                                            }
                                            gotMeta = true;
                                            break;
                                          case 'chunk':
                                            final chunkText =
                                                obj['text'] as String? ?? '';
                                            adviceNotifier.value =
                                                '${adviceNotifier.value}$chunkText';

                                            if (gotMeta &&
                                                !sheetOpened &&
                                                context.mounted) {
                                              // Close loading modal and show
                                              // the result sheet that listens
                                              // to live updates.
                                              Navigator.of(context,
                                                      rootNavigator: true)
                                                  .pop();

                                              setState(() {
                                                _scenarioLoading = false;
                                              });

                                              showScenarioResultSheet(
                                                context,
                                                adviceNotifier.value,
                                                meta,
                                                isCompleteNotifier:
                                                    isCompleteNotifier,
                                                liveAdvice: adviceNotifier,
                                                selectedCurrency:
                                                    widget.selectedCurrency,
                                                question: context.l10n
                                                    .scenarioQuestionTemplate(
                                                  q,
                                                  d,
                                                ),
                                                userId: user.uid,
                                                mode: isHousehold
                                                    ? 'household'
                                                    : 'personal',
                                                householdId: householdId,
                                                onSaved: () {
                                                  setState(() {});
                                                },
                                                onDeleted: () {
                                                  setState(() {});
                                                },
                                              );
                                              sheetOpened = true;
                                            }
                                            break;
                                          case 'error':
                                            final msg = obj['error'] ??
                                                'Unknown error';
                                            throw Exception('$msg');
                                          case 'done':
                                            isCompleteNotifier.value = true;
                                            done = true;
                                            break;
                                          default:
                                            break;
                                        }
                                        if (done) break;
                                      }

                                      if (!sheetOpened) {
                                        final advice =
                                            adviceNotifier.value.isEmpty
                                                ? 'No analysis available'
                                                : adviceNotifier.value;

                                        if (!context.mounted) return;

                                        // Close loading modal
                                        Navigator.of(context,
                                                rootNavigator: true)
                                            .pop();

                                        setState(() {
                                          _scenarioLoading = false;
                                        });

                                        // Auto-show the result sheet and pass
                                        // required fields so the Save button
                                        // is enabled.
                                        isCompleteNotifier.value = true;

                                        showScenarioResultSheet(
                                          context,
                                          advice,
                                          meta,
                                          isCompleteNotifier:
                                              isCompleteNotifier,
                                          selectedCurrency:
                                              widget.selectedCurrency,
                                          question: context.l10n
                                              .scenarioQuestionTemplate(
                                            q,
                                            d,
                                          ),
                                          userId: user.uid,
                                          mode: isHousehold
                                              ? 'household'
                                              : 'personal',
                                          householdId: householdId,
                                          onSaved: () {
                                            setState(() {});
                                          },
                                          onDeleted: () {
                                            setState(() {});
                                          },
                                        );
                                      }
                                    } catch (e) {
                                      if (!context.mounted) return;

                                      if (!sheetOpened) {
                                        // Close loading modal only if it is
                                        // still showing.
                                        Navigator.of(context,
                                                rootNavigator: true)
                                            .pop();

                                        setState(() {
                                          _scenarioLoading = false;
                                        });
                                      }
                                      AppToast.info(
                                          context,
                                          context.l10n
                                              .analysisFailed(e.toString()));
                                    }
                                  },
                            child: Text(
                              context.l10n.check,
                              style: TextStyle(
                                  color: colorScheme.buttonText,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        );

                        if (expand) {
                          return Expanded(child: btn);
                        } else {
                          return btn;
                        }
                      }

                      late final List<Widget> row1;
                      late final List<Widget> row2;
                      late final List<Widget> row3;

                      switch (order) {
                        case _WordOrder.sov:
                          // zh/ja/ko/hi/ur/tr: 我能 在 [date] 之前 \n [action]
                          row1 = [
                            canI,
                            beforePrefixLabel,
                            Expanded(child: dateButton),
                            beforeSuffixLabel,
                          ];
                          // Place action input on its own full-width row for mobile
                          row2 = [
                            actionField,
                          ];
                          // Keep button on its own row
                          row3 = [
                            buildPrimaryButton(expand: true),
                          ];
                          break;
                        case _WordOrder.vso:
                        case _WordOrder.v2:
                        case _WordOrder.svo:
                          // Default: "Can I" + action, then pre/suffix around date; button in its own row
                          row1 = [
                            canI,
                            actionField,
                          ];
                          row2 = [
                            beforePrefixLabel,
                            Expanded(child: dateButton),
                            beforeSuffixLabel,
                            const SizedBox(width: 8),
                          ];
                          row3 = [
                            buildPrimaryButton(expand: true),
                          ];
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: row1),
                          const SizedBox(height: 8),
                          if (row2.isNotEmpty) Row(children: row2),
                          const SizedBox(height: 8),
                          Row(children: row3),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          InsightsSectionCard(
            colorScheme: widget.colorScheme,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadScenarioHistory(
                user.uid,
                isHousehold ? householdId : null,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final items = snapshot.data ?? const [];
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'No saved scenarios yet',
                      style: TextStyle(
                        color: widget.colorScheme.mutedForeground,
                        fontSize: 13,
                      ),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.history,
                      size: 18,
                    ),
                    const SizedBox(height: 12),
                    ...items.map((row) {
                      final id = row['id'] as String?;
                      final q = row['question'] as String? ?? '';
                      final a = row['answer'] as String? ?? '';
                      final createdAtRaw = row['created_at'] as String?;

                      String? createdAtLabel;
                      if (createdAtRaw != null) {
                        try {
                          final parsed = DateTime.parse(createdAtRaw);
                          createdAtLabel = _formatLocalizedDate(parsed);
                        } catch (_) {
                          createdAtLabel = createdAtRaw;
                        }
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: InkWell(
                          onTap: () {
                            showScenarioResultSheet(
                              context,
                              a,
                              const {},
                              selectedCurrency: widget.selectedCurrency,
                              question: q,
                              userId: user.uid,
                              mode: isHousehold ? 'household' : 'personal',
                              householdId: householdId,
                              scenarioId: id,
                              onSaved: () {
                                setState(() {});
                              },
                              onDeleted: () {
                                setState(() {});
                              },
                            );
                          },
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 2, horizontal: 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    if (createdAtLabel != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: widget.colorScheme.primary
                                              .withOpacity(0.06),
                                          borderRadius:
                                              BorderRadius.circular(100),
                                        ),
                                        child: Text(
                                          createdAtLabel,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: widget.colorScheme.primary,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                      ),
                                    Icon(
                                      CupertinoIcons.arrow_up_right,
                                      size: 16,
                                      color: widget.colorScheme.mutedForeground,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  q,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.6,
                                    height: 1.3,
                                    color: widget.colorScheme.foreground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Future<List<Map<String, dynamic>>> _loadScenarioHistory(
  String userId,
  String? householdId,
) async {
  List<dynamic> response;

  if (householdId != null) {
    response = await supabase
        .from('ai_scenario_history')
        .select('id,question,answer,created_at,household_id,mode,currency')
        .eq('user_id', userId)
        .eq('household_id', householdId)
        .order('created_at', ascending: false)
        .limit(10);
  } else {
    response = await supabase
        .from('ai_scenario_history')
        .select('id,question,answer,created_at,household_id,mode,currency')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(10);
  }

  return response.cast<Map<String, dynamic>>();
}
