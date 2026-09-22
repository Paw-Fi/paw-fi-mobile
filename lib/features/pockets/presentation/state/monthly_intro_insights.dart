import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/app/locale_provider.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/core/utils/intl_locale.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/recurring/domain/models/recurring_read_models.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/domain/recurring_month_summary.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/l10n/app_localizations_en.dart';

enum MonthlyInsightType {
  rolloverCarry,
  pocketAdjustment,
  budgetPerformance,
  spendingImprovement,
  upcomingRecurring,
  longevityMilestone,
  freshStart,
}

enum MonthlyInsightSentiment {
  positive,
  neutral,
  supportive,
}

@immutable
class MonthlyIntroInsight {
  const MonthlyIntroInsight({
    required this.type,
    required this.priority,
    required this.badge,
    required this.headline,
    required this.description,
    this.metric,
    this.metricLabel,
    this.sentiment = MonthlyInsightSentiment.positive,
  });

  final MonthlyInsightType type;
  final int priority;
  final String badge;
  final String headline;
  final String description;
  final String? metric;
  final String? metricLabel;
  final MonthlyInsightSentiment sentiment;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthlyIntroInsight &&
          type == other.type &&
          priority == other.priority &&
          badge == other.badge &&
          headline == other.headline &&
          description == other.description &&
          metric == other.metric &&
          metricLabel == other.metricLabel &&
          sentiment == other.sentiment;

  @override
  int get hashCode => Object.hash(
        type,
        priority,
        badge,
        headline,
        description,
        metric,
        metricLabel,
        sentiment,
      );
}

@immutable
class MonthlyIntroState {
  const MonthlyIntroState({
    required this.primaryInsight,
    this.secondaryInsight,
    this.milestoneText,
    required this.currentMonth,
    required this.previousMonth,
    required this.currentMonthName,
    required this.previousMonthName,
    this.monthsUsingMoneko,
    this.isLoading = false,
  });

  final MonthlyIntroInsight primaryInsight;
  final MonthlyIntroInsight? secondaryInsight;
  final String? milestoneText;
  final DateTime currentMonth;
  final DateTime previousMonth;
  final String currentMonthName;
  final String previousMonthName;
  final int? monthsUsingMoneko;
  final bool isLoading;

  static MonthlyIntroState loading({
    required DateTime currentMonth,
    required String currency,
    AppLocalizations? l10n,
    String? localeName,
  }) {
    final strings = l10n ?? AppLocalizationsEn('en');
    final previousMonth = DateTime(
      currentMonth.year,
      currentMonth.month - 1,
      1,
    );
    final currentMonthName =
        DateFormat('MMMM', localeName).format(currentMonth);
    final previousMonthName =
        DateFormat('MMMM', localeName).format(previousMonth);
    return MonthlyIntroState(
      primaryInsight: MonthlyIntroInsight(
        type: MonthlyInsightType.freshStart,
        priority: 10,
        badge: strings.welcome.toUpperCase(),
        headline: strings.helloMonthName(currentMonthName),
        description: strings.introFreshStartDescription,
        sentiment: MonthlyInsightSentiment.positive,
      ),
      currentMonth: currentMonth,
      previousMonth: previousMonth,
      currentMonthName: currentMonthName,
      previousMonthName: previousMonthName,
      isLoading: true,
    );
  }
}

@immutable
class MonthlyIntroInsightsParams {
  const MonthlyIntroInsightsParams({
    required this.scopeParams,
    required this.currency,
  });

  final PocketsScopeParams scopeParams;
  final String currency;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthlyIntroInsightsParams &&
          scopeParams == other.scopeParams &&
          currency.toUpperCase() == other.currency.toUpperCase();

  @override
  int get hashCode => Object.hash(scopeParams, currency.toUpperCase());
}

String _toOrdinal(int n) {
  if (n >= 11 && n <= 13) return '${n}th';
  switch (n % 10) {
    case 1:
      return '${n}st';
    case 2:
      return '${n}nd';
    case 3:
      return '${n}rd';
    default:
      return '${n}th';
  }
}

String _formatWholeAmount(double amount, String currencySymbol) {
  final rounded = amount.round();
  return '$currencySymbol$rounded';
}

/// Evaluates and scores candidates deterministically based on available financial facts.
MonthlyIntroState evaluateMonthlyIntroInsights({
  required DateTime currentMonth,
  required String currency,
  PocketsState? currentPocketsState,
  PocketsState? previousPocketsState,
  List<RecurringTransaction> recurringExpenses = const [],
  int? monthsUsingMoneko,
  double? twoMonthsAgoSpend,
  AppLocalizations? l10n,
  String? localeName,
}) {
  final strings = l10n ?? AppLocalizationsEn('en');
  final previousMonth = DateTime(
    currentMonth.year,
    currentMonth.month - 1,
    1,
  );
  final currentMonthName = DateFormat('MMMM', localeName).format(currentMonth);
  final previousMonthName =
      DateFormat('MMMM', localeName).format(previousMonth);
  final twoMonthsAgoName = DateFormat('MMMM', localeName).format(
    DateTime(currentMonth.year, currentMonth.month - 2, 1),
  );
  final effectiveCurrency =
      currency.trim().isNotEmpty ? currency.trim() : 'USD';
  final currencySymbol = resolveCurrencySymbol(effectiveCurrency);

  final candidates = <MonthlyIntroInsight>[];

  if (previousPocketsState != null && !previousPocketsState.isLoading) {
    // 1. Rollover Carry-In (Priority 100)
    double totalIncomingRollover = 0.0;
    for (final pocket in previousPocketsState.saved) {
      if (pocket.rolloverEnabled) {
        final rem = pocket.remaining;
        if (rem > 0) {
          final cap = pocket.rolloverCapCents != null
              ? pocket.rolloverCapCents! / 100.0
              : null;
          totalIncomingRollover += (cap != null && rem > cap) ? cap : rem;
        }
      }
    }
    if (totalIncomingRollover >= 5.0) {
      final formattedRollover =
          _formatWholeAmount(totalIncomingRollover, currencySymbol);
      candidates.add(
        MonthlyIntroInsight(
          type: MonthlyInsightType.rolloverCarry,
          priority: 100,
          badge: strings.pocketRolloverLabel.toUpperCase(),
          headline: strings.startingMonthWithExtra(
            currentMonthName,
            formattedRollover,
          ),
          description: strings.introRolloverDescription(previousMonthName),
          metric: '+$formattedRollover',
          metricLabel: strings.carriedForward,
          sentiment: MonthlyInsightSentiment.positive,
        ),
      );
    }

    // 2. Pocket Adjustment Opportunity (Priority 90)
    PocketEnvelope? maxOverspendPocket;
    double maxOverspend = 0.0;
    for (final pocket in previousPocketsState.saved) {
      final overspend = pocket.spent - pocket.availableBudget;
      if (overspend > maxOverspend) {
        maxOverspend = overspend;
        maxOverspendPocket = pocket;
      }
    }
    if (maxOverspendPocket != null && maxOverspend >= 15.0) {
      final formattedOverspent =
          _formatWholeAmount(maxOverspend, currencySymbol);
      final pocketName = maxOverspendPocket.name;
      candidates.add(
        MonthlyIntroInsight(
          type: MonthlyInsightType.pocketAdjustment,
          priority: 90,
          badge: strings.freshStart.toUpperCase(),
          headline: strings.newMonthFreshBalance,
          description: strings.introPocketAdjustmentDescription(
            pocketName,
            formattedOverspent,
            currentMonthName,
          ),
          metric: '+$formattedOverspent',
          metricLabel: strings.abovePlanInMonth(previousMonthName),
          sentiment: MonthlyInsightSentiment.supportive,
        ),
      );
    }

    // 3. Budget Performance Win (Priority 80)
    final prevBudget = previousPocketsState.totalBudget;
    final prevSpent = previousPocketsState.totalSpent > 0
        ? previousPocketsState.totalSpent
        : previousPocketsState.saved.fold<double>(0, (sum, p) => sum + p.spent);
    final onTrackCount = previousPocketsState.saved
        .where((p) => p.spent <= p.availableBudget)
        .length;
    final totalPocketCount = previousPocketsState.saved.length;

    if (prevBudget > 0 && prevSpent <= prevBudget && prevSpent > 0) {
      candidates.add(
        MonthlyIntroInsight(
          type: MonthlyInsightType.budgetPerformance,
          priority: 80,
          badge: strings.onTrack.toUpperCase(),
          headline: strings.youFinishedMonthOnPlan(previousMonthName),
          description: strings.introOnTrackDescription(currentMonthName),
          metric: totalPocketCount > 0
              ? strings.onTrackOfTotal(onTrackCount, totalPocketCount)
              : null,
          metricLabel: totalPocketCount > 0 ? strings.pocketsOnBudget : null,
          sentiment: MonthlyInsightSentiment.positive,
        ),
      );
    }

    // 4. Spending Improvement MoM (Priority 70)
    if (twoMonthsAgoSpend != null && twoMonthsAgoSpend > 0) {
      final decrease = twoMonthsAgoSpend - prevSpent;
      if (decrease >= 20.0) {
        final formattedDecrease = _formatWholeAmount(decrease, currencySymbol);
        candidates.add(
          MonthlyIntroInsight(
            type: MonthlyInsightType.spendingImprovement,
            priority: 70,
            badge: strings.progress.toUpperCase(),
            headline: strings.greatProgressLastMonth,
            description: strings.introProgressDescription(
              formattedDecrease,
              currentMonthName,
            ),
            metric: '-$formattedDecrease',
            metricLabel: strings.spentVsMonth(twoMonthsAgoName),
            sentiment: MonthlyInsightSentiment.positive,
          ),
        );
      }
    }
  }

  // 5. Upcoming Recurring Commitments (Priority 60)
  if (recurringExpenses.isNotEmpty) {
    double totalUpcoming = 0.0;
    for (final recurring in recurringExpenses) {
      final summary = RecurringSeriesSummary(
        transaction: recurring,
        nextOccurrenceDate: null,
        latestActionableOccurrenceDate: null,
      );
      totalUpcoming += calculateRecurringMonthlyCommittedAmount(summary);
    }
    if (totalUpcoming >= 50.0) {
      final formattedRecurring =
          _formatWholeAmount(totalUpcoming, currencySymbol);
      candidates.add(
        MonthlyIntroInsight(
          type: MonthlyInsightType.upcomingRecurring,
          priority: 60,
          badge: strings.upcoming.toUpperCase(),
          headline: strings.monthIsLookingBusy(currentMonthName),
          description: strings.introUpcomingDescription(formattedRecurring),
          metric: formattedRecurring,
          metricLabel: strings.scheduledBills,
          sentiment: MonthlyInsightSentiment.neutral,
        ),
      );
    }
  }

  // 6. Longevity Milestone (Priority 50)
  if (monthsUsingMoneko != null && monthsUsingMoneko >= 2) {
    final ordinal = _toOrdinal(monthsUsingMoneko);
    candidates.add(
      MonthlyIntroInsight(
        type: MonthlyInsightType.longevityMilestone,
        priority: 50,
        badge: strings.milestone.toUpperCase(),
        headline: strings.yourOrdinalMonthWithMoneko(ordinal),
        description: strings.introMilestoneDescription(currentMonthName),
        metric: strings.monthsAbbreviation(monthsUsingMoneko),
        metricLabel: strings.withMoneko,
        sentiment: MonthlyInsightSentiment.positive,
      ),
    );
  }

  // 7. Clean Slate Fallback (Priority 10)
  candidates.add(
    MonthlyIntroInsight(
      type: MonthlyInsightType.freshStart,
      priority: 10,
      badge: strings.welcome.toUpperCase(),
      headline: strings.helloMonthName(currentMonthName),
      description: strings.introFreshStartDescription,
      sentiment: MonthlyInsightSentiment.positive,
    ),
  );

  // Sort candidates by priority descending
  candidates.sort((a, b) => b.priority.compareTo(a.priority));

  final primary = candidates.first;
  MonthlyIntroInsight? secondary;
  String? milestoneText;

  // Derive secondary milestone text
  if (monthsUsingMoneko != null && monthsUsingMoneko >= 2) {
    milestoneText = strings.monthsWithMoneko(monthsUsingMoneko);
  }

  // Pick secondary insight if available and different
  if (candidates.length > 1) {
    for (var i = 1; i < candidates.length; i++) {
      final candidate = candidates[i];
      if (candidate.type != primary.type &&
          candidate.type != MonthlyInsightType.freshStart &&
          candidate.type != MonthlyInsightType.longevityMilestone) {
        secondary = candidate;
        break;
      }
    }
  }

  return MonthlyIntroState(
    primaryInsight: primary,
    secondaryInsight: secondary,
    milestoneText: milestoneText,
    currentMonth: currentMonth,
    previousMonth: previousMonth,
    currentMonthName: currentMonthName,
    previousMonthName: previousMonthName,
    monthsUsingMoneko: monthsUsingMoneko,
    isLoading: false,
  );
}

final monthlyIntroInsightsProvider =
    Provider.family<MonthlyIntroState, MonthlyIntroInsightsParams>(
        (ref, params) {
  final appLocale = resolveSupportedAppLocale(ref.watch(localeProvider));
  final l10n = lookupAppLocalizations(appLocale);
  final localeName = intlSafeLocaleName(appLocale);
  final scopeParams = params.scopeParams;
  final currentMonth = scopeParams.periodMonth ?? DateTime.now();
  final previousMonth = DateTime(
    currentMonth.year,
    currentMonth.month - 1,
    1,
  );
  final previousScopeParams = scopeParams.copyWith(periodMonth: previousMonth);

  final currentPocketsState = ref.watch(pocketsProvider(scopeParams));
  final previousPocketsState = ref.watch(pocketsProvider(previousScopeParams));

  // If previous pockets state is still loading, emit loading state
  if (previousPocketsState.isLoading) {
    return MonthlyIntroState.loading(
      currentMonth: currentMonth,
      currency: params.currency,
      l10n: l10n,
      localeName: localeName,
    );
  }

  // Active recurring expenses
  final recurringExpenses = ref
          .watch(recurringExpensesProvider(scopeParams.householdId))
          .valueOrNull ??
      const <RecurringTransaction>[];

  // User longevity in months
  int? monthsUsingMoneko;
  try {
    final userCreatedAt = supabase.auth.currentUser?.createdAt;
    if (userCreatedAt != null) {
      final created = DateTime.tryParse(userCreatedAt);
      if (created != null) {
        monthsUsingMoneko = (currentMonth.year - created.year) * 12 +
            (currentMonth.month - created.month) +
            1;
      }
    }
  } catch (_) {}

  // Two months ago spending from local SQLite if available
  double? twoMonthsAgoSpend;
  try {
    final database = ref.watch(localDatabaseProvider).valueOrNull;
    if (database != null) {
      final twoMonthsAgo = DateTime(
        currentMonth.year,
        currentMonth.month - 2,
        1,
      );
      final userId = supabase.auth.currentUser?.id ?? '';
      final scopeKey = localScopeKey(
        userId: userId,
        householdId: scopeParams.householdId,
      );
      final summary = database.getMonthlySummarySync(
        scopeKey: scopeKey,
        month: twoMonthsAgo,
        currency: params.currency,
      );
      if (summary != null && summary.expenseCents > 0) {
        twoMonthsAgoSpend = summary.expenseCents / 100.0;
      }
    }
  } catch (_) {}

  return evaluateMonthlyIntroInsights(
    currentMonth: currentMonth,
    currency: params.currency,
    currentPocketsState: currentPocketsState,
    previousPocketsState: previousPocketsState,
    recurringExpenses: recurringExpenses,
    monthsUsingMoneko: monthsUsingMoneko,
    twoMonthsAgoSpend: twoMonthsAgoSpend,
    l10n: l10n,
    localeName: localeName,
  );
});
