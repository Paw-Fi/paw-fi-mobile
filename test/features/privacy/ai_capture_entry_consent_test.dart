import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
// Test-only fake uses image_picker's existing transitive platform interface.
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:moneko/core/app/app_user_context_provider.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/features/home/presentation/widgets/ai_input_target.dart';
import 'package:moneko/features/home/presentation/widgets/home_ai_fab.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/privacy/presentation/ai_processing_consent_dialog.dart';
import 'package:moneko/features/privacy/presentation/ai_processing_consent_provider.dart';
import 'package:moneko/l10n/app_localizations_en.dart';

import 'ai_processing_consent_test.dart'
    show FakeConsentRepository, TestConsentAuth, consent;
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/privacy/data/ai_processing_consent_repository.dart';

class _PendingImagePicker extends ImagePickerPlatform {
  late Completer<XFile?> result;
  int calls = 0;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) {
    expect(source, ImageSource.gallery);
    calls++;
    result = Completer<XFile?>();
    return result.future;
  }
}

void main() {
  late ImagePickerPlatform originalPicker;
  late _PendingImagePicker picker;
  setUp(() {
    originalPicker = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = picker = _PendingImagePicker();
  });
  tearDown(() {
    if (picker.calls > 0 && !picker.result.isCompleted) {
      picker.result.complete(null);
    }
    ImagePickerPlatform.instance = originalPicker;
  });

  for (final actorChanged in [true, false]) {
    testWidgets(
        actorChanged
            ? 'pending gallery result cannot process after actor A changes to B'
            : 'pending gallery result refreshes local revocation before processing',
        (tester) async {
      var actor = 'A';
      var granted = true;
      var reads = 0;
      var databaseReads = 0;
      var processingReads = 0;
      var completed = false;
      final repository = FakeConsentRepository()
        ..read = () async {
          reads++;
          return consent(granted, owner: actor);
        };
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authProvider.overrideWith(TestConsentAuth.new),
          aiProcessingConsentRepositoryProvider.overrideWithValue(repository),
          localDatabaseProvider.overrideWith((ref) async {
            databaseReads++;
            throw StateError('AI capture must not access SQLite');
          }),
          appUserContactProvider.overrideWith((ref) {
            processingReads++;
            return null;
          }),
        ],
        child: MaterialApp(home: Consumer(builder: (context, ref, _) {
          return Scaffold(
            body: TextButton(
              onPressed: () async {
                await handleAiLibraryCapture(context, ref,
                    inputTarget: const AiInputTarget(
                      accountType: ActiveWalletType.personal,
                      householdId: null,
                      isPortfolio: false,
                      accountId: null,
                      accountCurrency: 'USD',
                    ));
                completed = true;
              },
              child: const Text('Select gallery'),
            ),
          );
        })),
      ));
      await tester.tap(find.text('Select gallery'));
      await tester.pumpAndSettle();
      expect(picker.calls, 1);
      expect(completed, isFalse);
      final container = ProviderScope.containerOf(
          tester.element(find.text('Select gallery')));
      expect(container.read(aiProcessingConsentProvider).mayProcess, isTrue);
      if (actorChanged) {
        actor = 'B';
        (container.read(authProvider.notifier) as TestConsentAuth)
            .setUser(actor);
        await tester.pumpAndSettle();
        await container.read(aiProcessingConsentProvider.notifier).refresh();
        expect(container.read(aiProcessingConsentProvider).mayProcess, isTrue);
      } else {
        // Simulate another local settings surface revoking the stored choice.
        granted = false;
      }
      final readsBeforeReturn = reads;
      picker.result.complete(XFile('/unused-receipt.jpg'));
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(reads, readsBeforeReturn + (actorChanged ? 0 : 1));
      expect(
          container.read(aiProcessingConsentProvider).mayProcess, actorChanged);
      expect(processingReads, 0);
      expect(databaseReads, 0);
      expect(find.text(AppLocalizationsEn().analyzingReceipt), findsNothing);
      expect(find.byType(AiProcessingConsentDialog), findsNothing);
      expect(repository.writes, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('duplicate gallery handlers approve once and launch one picker',
      (tester) async {
    final repository = FakeConsentRepository();
    final actions = <Future<void>>[];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith(TestConsentAuth.new),
        aiProcessingConsentRepositoryProvider.overrideWithValue(repository),
        aiConsentSavingDelayProvider.overrideWithValue(() async {}),
      ],
      child: MaterialApp(home: Consumer(builder: (context, ref, _) {
        return Scaffold(
          body: TextButton(
            onPressed: () {
              actions.add(handleAiLibraryCapture(context, ref));
              actions.add(handleAiLibraryCapture(context, ref));
            },
            child: const Text('Select gallery twice'),
          ),
        );
      })),
    ));
    await tester.tap(find.text('Select gallery twice'));
    await tester.pumpAndSettle();
    expect(find.byType(AiProcessingConsentDialog), findsOneWidget);
    expect(picker.calls, 0);
    expect(repository.writes, 0);
    await tester.ensureVisible(find.text('Allow AI processing'));
    await tester.tap(find.text('Allow AI processing'));
    await tester.pumpAndSettle();
    expect(find.byType(AiProcessingConsentDialog), findsNothing);
    expect(repository.writes, 1);
    expect(picker.calls, 1);
    picker.result.complete(null);
    await tester.pumpAndSettle();
    await Future.wait(actions);
    expect(tester.takeException(), isNull);
  });

  test('automatic rating entry points contain no review request or scheduling',
      () {
    for (final path in [
      'lib/features/onboarding/presentation/pages/onboarding_post_auth_flow_page.dart',
      'lib/features/home/presentation/widgets/home_ai_fab.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('requestReview')));
      expect(source, isNot(contains('in_app_review')));
      expect(source, isNot(contains('review_prompt')));
    }
    for (final path in [
      'lib/features/profile/presentation/pages/settings_page.dart',
      'lib/features/insights/presentation/pages/browse_page.dart',
    ]) {
      expect(File(path).readAsStringSync(), contains('requestReview'));
    }
  });

  final methods = <String, Future<void> Function(BuildContext, WidgetRef)>{
    'Text / audio': (context, ref) => handleAiFreeFormText(context, ref),
    'Camera': (context, ref) => handleAiCameraCapture(context, ref),
    'Gallery': (context, ref) => handleAiLibraryCapture(context, ref),
    'File': (context, ref) => handleAiFileUpload(context, ref),
    'Files selector': (context, ref) => handleAiFileOrGallery(context, ref),
  };
  for (final entry in methods.entries) {
    testWidgets('${entry.key} asks before input and decline cancels',
        (tester) async {
      final repository = FakeConsentRepository();
      var completed = false;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authProvider.overrideWith(TestConsentAuth.new),
          aiProcessingConsentRepositoryProvider.overrideWithValue(repository),
          aiConsentSavingDelayProvider.overrideWithValue(() async {}),
        ],
        child: MaterialApp(home: Consumer(builder: (context, ref, _) {
          return Scaffold(
              body: TextButton(
            onPressed: () async {
              await entry.value(context, ref);
              completed = true;
            },
            child: const Text('Select method'),
          ));
        })),
      ));
      expect(find.byType(AiProcessingConsentDialog), findsNothing);
      await tester.tap(find.text('Select method'));
      await tester.pumpAndSettle();
      expect(find.byType(AiProcessingConsentDialog), findsOneWidget);
      expect(completed, isFalse);
      await tester.ensureVisible(find.text('Not now'));
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(repository.writes, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'accepting Files selection continues to its original source selector',
      (tester) async {
    final repository = FakeConsentRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith(TestConsentAuth.new),
        aiProcessingConsentRepositoryProvider.overrideWithValue(repository),
        aiConsentSavingDelayProvider.overrideWithValue(() async {}),
      ],
      child: MaterialApp(home: Consumer(builder: (context, ref, _) {
        return Scaffold(
            body: TextButton(
          onPressed: () => handleAiFileOrGallery(context, ref),
          child: const Text('Select files'),
        ));
      })),
    ));
    await tester.tap(find.text('Select files'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Allow AI processing'));
    await tester.tap(find.text('Allow AI processing'));
    await tester.pumpAndSettle();
    expect(find.byType(AiProcessingConsentDialog), findsNothing);
    expect(find.text('Gallery'), findsOneWidget);
    expect(repository.writes, 1);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
}
