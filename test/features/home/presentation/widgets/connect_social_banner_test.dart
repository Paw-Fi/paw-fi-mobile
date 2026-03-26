import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/analytics_data.dart';
import 'package:moneko/features/home/presentation/state/analytics_notifier.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/widgets/connect_social_banner.dart';
import 'package:moneko/features/profile/data/providers/telegram_binding_provider.dart';
import 'package:moneko/features/profile/data/providers/whatsapp_binding_provider.dart';
import 'package:moneko/l10n/app_localizations.dart';

class _TestAuth extends Auth {
  _TestAuth(this._user);

  final AppUser _user;

  @override
  AppUser build() => _user;
}

class _FakeAnalyticsNotifier extends AnalyticsNotifier {
  _FakeAnalyticsNotifier(super.ref, this.initialExpenses) {
    state = AnalyticsData(allExpenses: initialExpenses);
  }

  final List<ExpenseEntry> initialExpenses;

  @override
  Future<void> loadData(
    String userId, {
    int retryCount = 0,
    bool forceReload = false,
  }) async {}
}

class _FakeWhatsAppBinding extends WhatsAppBinding {
  _FakeWhatsAppBinding(this.value);

  final bool value;

  @override
  Future<bool> build() async => value;
}

class _FakeTelegramBinding extends TelegramBinding {
  _FakeTelegramBinding(this.value);

  final bool value;

  @override
  Future<bool> build() async => value;
}

void main() {
  Future<void> pumpBanner(
    WidgetTester tester, {
    required AppUser user,
    required List<ExpenseEntry> expenses,
    required bool whatsappConnected,
    required bool telegramConnected,
    required bool walletCaptureEnabled,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _TestAuth(user)),
          analyticsProvider.overrideWith((ref) {
            final notifier = _FakeAnalyticsNotifier(ref, expenses);
            return notifier;
          }),
          whatsAppBindingProvider.overrideWith(
            () => _FakeWhatsAppBinding(whatsappConnected),
          ),
          telegramBindingProvider.overrideWith(
            () => _FakeTelegramBinding(telegramConnected),
          ),
          walletCaptureEnabledProvider.overrideWith(
            (ref) async => walletCaptureEnabled,
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ConnectSocialBanner(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('sorts incomplete steps before completed steps', (
    tester,
  ) async {
    final expenses = [
      ExpenseEntry(
        id: 'expense-2',
        userId: 'user-1',
        householdId: null,
        amountCents: 1200,
        currency: 'USD',
        category: 'subscriptions',
        date: DateTime(2026, 1, 2),
        type: 'expense',
        isRecurring: true,
        createdAt: DateTime(2026, 1, 2),
        rawText: 'Monthly plan',
      ),
    ];

    await pumpBanner(
      tester,
      user: const AppUser(uid: 'user-1', email: 'user@test.com'),
      expenses: expenses,
      whatsappConnected: false,
      telegramConnected: false,
      walletCaptureEnabled: true,
    );

    final context = tester.element(find.byType(Scaffold));
    final l10n = AppLocalizations.of(context)!;
    final captureTitle = defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS
        ? l10n.applePayIntegration
        : l10n.autoCapture;

    expect(find.text('Finish your profile'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text(l10n.homeFabTourTitle)).dx,
      lessThan(tester.getTopLeft(find.text(l10n.createAccount)).dx),
    );
    expect(
      tester.getTopLeft(find.text(l10n.connectSocialBannerTitle)).dx,
      lessThan(tester.getTopLeft(find.text(l10n.createAccount)).dx),
    );
    expect(
      tester.getTopLeft(find.text(l10n.createAccount)).dx,
      lessThan(tester.getTopLeft(find.text(l10n.recurringTourFabTitle)).dx),
    );
    expect(
      tester.getTopLeft(find.text(l10n.recurringTourFabTitle)).dx,
      lessThan(tester.getTopLeft(find.text(captureTitle)).dx),
    );

    final firstCardSize = tester.getSize(
      find.byKey(ValueKey('connect-social-card-${l10n.createAccount}')),
    );
    final secondCardSize = tester.getSize(
      find.byKey(ValueKey('connect-social-card-${l10n.homeFabTourTitle}')),
    );
    expect(firstCardSize, secondCardSize);
  });

  testWidgets(
      'hides when all checklist items are complete and treats either app as connected',
      (
    tester,
  ) async {
    final expenses = [
      ExpenseEntry(
        id: 'expense-1',
        userId: 'user-1',
        householdId: null,
        amountCents: 2500,
        currency: 'USD',
        category: 'food',
        date: DateTime(2026, 1, 1),
        type: 'expense',
        isRecurring: false,
        createdAt: DateTime(2026, 1, 1),
        rawText: 'Lunch',
      ),
      ExpenseEntry(
        id: 'expense-2',
        userId: 'user-1',
        householdId: null,
        amountCents: 1200,
        currency: 'USD',
        category: 'subscriptions',
        date: DateTime(2026, 1, 2),
        type: 'expense',
        isRecurring: true,
        createdAt: DateTime(2026, 1, 2),
        rawText: 'Monthly plan',
      ),
    ];

    await pumpBanner(
      tester,
      user: const AppUser(uid: 'user-1', email: 'user@test.com'),
      expenses: expenses,
      whatsappConnected: false,
      telegramConnected: true,
      walletCaptureEnabled: true,
    );

    expect(find.text('Finish your profile'), findsNothing);
    expect(find.byType(ConnectSocialBanner), findsOneWidget);
  });
}
