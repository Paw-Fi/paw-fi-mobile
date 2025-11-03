import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/core/core.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/insights/presentation/widgets/charts/charts.dart';
import 'package:moneko/features/insights/presentation/widgets/scenario_result_sheet.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

/// Supported sentence word orders for arranging the scenario inputs
enum _WordOrder { svo, sov, vso, v2 }

Widget buildScenarioPlanningTab(BuildContext context, shadcnui.ColorScheme colorScheme, AnalyticsData analyticsData, {String? selectedCurrency}) {
  return ScenarioPlanningTabContent(context: context, colorScheme: colorScheme, analyticsData: analyticsData, selectedCurrency: selectedCurrency);
}

void _showCategoryGuide(BuildContext context, shadcnui.ColorScheme colorScheme) {
  final slides = _scenarioCategorySlides(context);
  final controller = PageController();
  int currentPage = 0;

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: colorScheme.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.scenarioCategoriesGuide,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.foreground,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: colorScheme.mutedForeground),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.categoryGuideIntro,
                      style: TextStyle(color: colorScheme.mutedForeground, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: PageView.builder(
                        controller: controller,
                        itemCount: slides.length,
                        onPageChanged: (index) => setState(() => currentPage = index),
                        itemBuilder: (context, index) {
                          final slide = slides[index];
                          return _ScenarioHelpSlide(
                            colorScheme: colorScheme,
                            title: slide.title,
                            summary: slide.summary,
                            bullets: slide.points,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(slides.length, (index) {
                        final active = index == currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: active ? 20 : 8,
                          decoration: BoxDecoration(
                            color: active ? colorScheme.primary : colorScheme.muted,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: Text(context.l10n.close),
                        ),
                        const Spacer(),
                        shadcnui.PrimaryButton(
                          onPressed: () {
                            if (currentPage < slides.length - 1) {
                              controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
                              setState(() => currentPage += 1);
                            } else {
                              Navigator.of(dialogContext).pop();
                            }
                          },
                          child: Text(currentPage < slides.length - 1 ? context.l10n.next : context.l10n.done),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _ScenarioSlideData {
  const _ScenarioSlideData({required this.title, required this.summary, required this.points});

  final String title;
  final String summary;
  final List<String> points;
}

List<_ScenarioSlideData> _scenarioCategorySlides(BuildContext context) {
  return [
    _ScenarioSlideData(
      title: context.l10n.readTheBarChartLikeAPro,
      summary: context.l10n.categoryChartDesc,
      points: [
        context.l10n.leftHandChamps,
        context.l10n.smallButFrequent,
        context.l10n.colorMatches,
      ],
    ),
    _ScenarioSlideData(
      title: context.l10n.whyThisViewIsHelpful,
      summary: context.l10n.categoryWhyHelpfulDesc,
      points: [
        context.l10n.planningNewGoal,
        context.l10n.eyeingTreatYourself,
        context.l10n.doubleCheckTagging,
      ],
    ),
    _ScenarioSlideData(
      title: context.l10n.whatToDoWithTheInsight,
      summary: context.l10n.categoryWhatToDoDesc,
      points: [
        context.l10n.slideHighBar,
        context.l10n.nonNegotiable,
        context.l10n.revisitAfterScenario,
      ],
    ),
  ];
}

class _ScenarioHelpSlide extends StatelessWidget {
  const _ScenarioHelpSlide({
    required this.colorScheme,
    required this.title,
    required this.summary,
    required this.bullets,
  });

  final shadcnui.ColorScheme colorScheme;
  final String title;
  final String summary;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colorScheme.foreground),
          ),
          const SizedBox(height: 12),
          Text(
            summary,
            style: TextStyle(fontSize: 14, height: 1.4, color: colorScheme.mutedForeground),
          ),
          const SizedBox(height: 16),
          ...bullets.map(
            (bullet) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.pie_chart, size: 18, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bullet,
                      style: TextStyle(fontSize: 14, height: 1.4, color: colorScheme.foreground),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScenarioPlanningTabContent extends ConsumerStatefulWidget {
  final BuildContext context;
  final shadcnui.ColorScheme colorScheme;
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
  ConsumerState<ScenarioPlanningTabContent> createState() => _ScenarioPlanningTabContentState();
}

class _Affixes {
  final String prefix;
  final String suffix;
  const _Affixes(this.prefix, this.suffix);
}

class _ScenarioPlanningTabContentState extends ConsumerState<ScenarioPlanningTabContent> {
  final TextEditingController _scenarioQuestionController = TextEditingController();
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
          final bg = widget.colorScheme.background;
          final fg = widget.colorScheme.foreground;
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
                            child: Text(context.l10n.close, style: TextStyle(color: widget.colorScheme.mutedForeground)),
                          ),
                          const Spacer(),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              setState(() {
                                _scenarioDate = DateTime(temp.year, temp.month, temp.day);
                              });
                              Navigator.of(ctx).pop();
                            },
                            child: Text(context.l10n.done, style: TextStyle(color: widget.colorScheme.primary, fontWeight: FontWeight.w600)),
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
    const svo = {
      'en', 'nl', 'sv', 'th', 'vi', 'id', 'ms', 'fi', 'da', 'nb', 'no'
    };
    const sov = {
      'zh', 'ja', 'ko', 'hi', 'ur', 'tr', 'fa'
    };
    const vso = {
      'es', 'fr', 'ar'
    };
    const v2 = {
      'de'
    };

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

  void _showToast(String message, {Widget? trailing}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Expanded(child: Text(message)),
            if (trailing != null) trailing,
          ],
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.colorScheme.background == AppTheme.darkBackground;
    final user = ref.watch(authProvider);
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scenario Planning Input
          Container(
            decoration: BoxDecoration(
              color: widget.colorScheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: widget.colorScheme.border, width: 1),
            ),
            padding: const EdgeInsets.all(16),
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
                          style: TextStyle(color: widget.colorScheme.foreground, fontWeight: FontWeight.w600),
                        ),
                      );

                      final actionField = Expanded(
                        child: TextField(
                          controller: _scenarioQuestionController,
                          decoration: InputDecoration(
                            hintText: context.l10n.buyALaptop,
                            hintStyle: TextStyle(color: widget.colorScheme.mutedForeground),
                            filled: true,
                            fillColor: isDark ? AppTheme.darkInputBg : AppTheme.lightInputBg,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: widget.colorScheme.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: widget.colorScheme.primary),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          style: TextStyle(color: widget.colorScheme.foreground),
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
                            style: TextStyle(color: widget.colorScheme.foreground, fontWeight: FontWeight.w600),
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
                            style: TextStyle(color: widget.colorScheme.foreground, fontWeight: FontWeight.w600),
                          ),
                        );
                      }();

                      final dateButton = shadcnui.OutlineButton(
                        onPressed: () => _pickTargetDate(context),
                        child: Text(_scenarioDate == null ? context.l10n.pickDate : _formatLocalizedDate(_scenarioDate!)),
                      );

                      Widget buildPrimaryButton({bool expand = true}) {
                        final btn = SizedBox(
                          height: 40,
                          child: shadcnui.PrimaryButton(
                            onPressed: _scenarioLoading
                                ? null
                                : () async {
                                    final q = _scenarioQuestionController.text.trim();
                                    final d = _scenarioDate == null ? '' : _formatLocalizedDate(_scenarioDate!);
                                    if (q.isEmpty || d.isEmpty) {
                                      _showToast(context.l10n.enterQuestionAndPickDate);
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
                                              color: colorScheme.background,
                                              borderRadius: BorderRadius.circular(12),
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
                                                  context.l10n.analyzingScenario,
                                                  style: TextStyle(
                                                    color: colorScheme.foreground,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  context.l10n.thisMightTakeAWhile,
                                                  style: TextStyle(
                                                    color: colorScheme.mutedForeground,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );

                                    try {
                                      final response = await supabase.functions.invoke(
                                        'ai-scenario-planner',
                                        body: {
                                          'question': context.l10n.scenarioQuestionTemplate(
                                            q,
                                            d,
                                          ),
                                          'targetDate': d,
                                          'userId': user.uid, // Not trusted by BE, just for logs
                                          'language': Localizations.localeOf(context).languageCode,
                                        },
                                      );

                                      if (!mounted) return;

                                      // Close loading modal
                                      Navigator.of(context, rootNavigator: true).pop();

                                      if (response.data != null && response.data['success'] == true) {
                                        final advice = response.data['advice'] ?? 'No analysis available';
                                        final meta = response.data['meta'] ?? {};

                                        setState(() {
                                          _scenarioLoading = false;
                                        });

                                        // Auto-show the result sheet
                                        showScenarioResultSheet(context, advice, meta, selectedCurrency: widget.selectedCurrency);
                                      } else {
                                        final error = response.data?['error'] ?? 'Failed to analyze scenario';
                                        throw Exception(error);
                                      }
                                    } catch (e) {
                                      if (!mounted) return;

                                      // Close loading modal
                                      Navigator.of(context, rootNavigator: true).pop();

                                      setState(() {
                                        _scenarioLoading = false;
                                      });
                                      _showToast(context.l10n.analysisFailed(e.toString()));
                                    }
                                  },
                            child: Text(
                              context.l10n.check,
                              style: TextStyle(color: colorScheme.buttonText, fontWeight: FontWeight.bold),
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
                        default:
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

          // Where the Money Went
          Container(
            decoration: BoxDecoration(
              color: widget.colorScheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: widget.colorScheme.border, width: 1),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      context.l10n.whereTheMoneyWent,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: widget.colorScheme.foreground,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Builder(
                      builder: (context) {
                        return IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            Icons.help_outline,
                            size: 18,
                            color: widget.colorScheme.mutedForeground,
                          ),
                          onPressed: () => _showCategoryGuide(context, widget.colorScheme),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.categoryTotalsForSelectedRange,
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 24),
                Builder(
                  builder: (context) {
                    // Filter expenses by selected currency if applicable
                    var expenses = widget.analyticsData.allExpenses;
                    if (widget.selectedCurrency != null) {
                      final currency = widget.selectedCurrency!.toUpperCase();
                      expenses = expenses.where((e) => e.currency?.toUpperCase() == currency).toList();
                    }
                    return buildCategoryBarChart(context, widget.colorScheme, expenses);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
