import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/import/presentation/pages/import_wizard_page.dart';
import 'package:moneko/features/import/presentation/state/import_wizard_notifier.dart';
import 'package:moneko/features/import/presentation/state/import_wizard_state.dart';
import 'package:moneko/features/import/presentation/widgets/import_preview_step.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockImportWizardNotifier extends StateNotifier<ImportWizardState>
    with Mock
    implements ImportWizardNotifier {
  MockImportWizardNotifier() : super(const ImportWizardState());
}

class _FakeAuthNotifier extends Auth {
  @override
  AppUser build() {
    return const AppUser(uid: 'u1', email: 'u1@example.com');
  }
}

const _defaultWallet = WalletEntity(
  id: 'wallet_default',
  userId: 'u1',
  householdId: null,
  name: 'Spending',
  icon: 'wallet',
  color: '#6B7280',
  openingBalanceCents: 0,
  goalAmountCents: null,
  isDefault: true,
  isSystem: false,
  isArchived: false,
  currentBalanceCents: 0,
);

void main() {
  Widget createWidgetUnderTest(MockImportWizardNotifier mockNotifier) {
    return ProviderScope(
      overrides: [
        importWizardProvider.overrideWith((ref) => mockNotifier),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: ImportWizardPage(),
      ),
    );
  }

  Widget createPreviewUnderTest(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              final state = ref.watch(importWizardProvider);
              return PreviewStep(
                state: state,
                lockPersonalTarget: true,
              );
            },
          ),
        ),
      ),
    );
  }

  testWidgets('ImportWizardPage renders initial step correctly',
      (WidgetTester tester) async {
    final mockNotifier = MockImportWizardNotifier();
    await tester.pumpWidget(createWidgetUnderTest(mockNotifier));
    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('Import data'), findsOneWidget);

    // Verify Stepper
    expect(find.text('Select'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);

    // Verify Initial Step Content (Select File)
    expect(find.text('Select File'), findsOneWidget); // Instruction Card Title
    expect(find.text('FILE'), findsOneWidget); // Section Title
    expect(find.text('No file selected'), findsOneWidget);
  });

  testWidgets('ImportWizardPage disposes cleanly', (WidgetTester tester) async {
    final mockNotifier = MockImportWizardNotifier();

    await tester.pumpWidget(createWidgetUnderTest(mockNotifier));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'PreviewStep keeps an explicit wallet selection while wallets refresh',
      (WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_FakeAuthNotifier.new),
        householdScopeProvider.overrideWith(
          (ref) => const HouseholdScope(
            viewMode: ViewMode.personal,
            selected: SelectedHouseholdState(),
            portfolioHouseholdIds: <String>{},
          ),
        ),
        walletsByHouseholdIdProvider(null).overrideWith(
          (ref) async => const [_defaultWallet],
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(importWizardProvider.notifier);
    notifier.state = notifier.state.copyWith(
      step: ImportStep.preview,
      targetAccountId: 'wallet_new',
    );

    await tester.pumpWidget(createPreviewUnderTest(container));
    await tester.pump();

    expect(
      container.read(importWizardProvider).targetAccountId,
      'wallet_new',
    );
  });

  testWidgets('PreviewStep auto-selects a default wallet when none is chosen',
      (WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_FakeAuthNotifier.new),
        householdScopeProvider.overrideWith(
          (ref) => const HouseholdScope(
            viewMode: ViewMode.personal,
            selected: SelectedHouseholdState(),
            portfolioHouseholdIds: <String>{},
          ),
        ),
        walletsByHouseholdIdProvider(null).overrideWith(
          (ref) async => const [_defaultWallet],
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(importWizardProvider.notifier);
    notifier.state = notifier.state.copyWith(step: ImportStep.preview);

    await tester.pumpWidget(createPreviewUnderTest(container));
    await tester.pump();

    expect(
      container.read(importWizardProvider).targetAccountId,
      _defaultWallet.id,
    );
  });
}
