import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/expense_save_providers.dart';
import 'package:moneko/features/home/presentation/state/transaction_edit_notifier.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/home/presentation/widgets/transaction_receipt_image.dart';
import 'package:moneko/features/home/presentation/widgets/unified_transaction_sheet.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/shared/widgets/moneko_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Auth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'owner', email: 'owner@example.com');
}

class _ReceiptSave extends ExpenseSaveNotifier {
  _ReceiptSave(super.ref);

  final uploads = <String>[];
  Completer<String?> upload = Completer<String?>();

  @override
  Future<String?> uploadReceiptImage(File imageFile, String userId) {
    uploads.add(imageFile.path);
    return upload.future;
  }
}

class _Edit extends TransactionEditNotifier {
  _Edit(super.ref);

  final patches = <Map<String, dynamic>>[];

  @override
  Future<bool> updateExpense(
    String expenseId,
    Map<String, dynamic> updates, {
    Map<String, dynamic>? extraBody,
    ExpenseEntry? originalExpense,
    String? optimisticMerchantDomain,
  }) async {
    patches.add(Map.of(updates));
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pickerChannel = MethodChannel('plugins.flutter.io/image_picker');
  final receiptPath =
      File('lib/assets/images/category/coffee.png').absolute.path;
  final date = DateTime(2026, 11, 5, 10, 30);
  final expense = ExpenseEntry(
    id: '11111111-1111-4111-8111-111111111111',
    userId: 'owner',
    amountCents: 1200,
    currency: 'USD',
    category: 'coffee',
    date: date,
    createdAt: date,
    type: 'expense',
  );
  late Completer<String?> pickedPhoto;
  late List<MethodCall> pickerCalls;
  late _ReceiptSave save;
  late _Edit edit;
  late bool sheetClosed;
  PlatformException? pickerError;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost',
      anonKey: 'anon',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
      httpClient: MockClient((_) async => http.Response('[]', 200,
          headers: {'content-type': 'application/json'})),
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    pickedPhoto = Completer<String?>();
    pickerCalls = [];
    sheetClosed = false;
    pickerError = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pickerChannel, (call) async {
      pickerCalls.add(call);
      final path = await pickedPhoto.future;
      if (pickerError != null) throw pickerError!;
      return path;
    });
  });

  tearDown(() async {
    if (!pickedPhoto.isCompleted) {
      pickedPhoto.complete(null);
      await Future<void>.delayed(Duration.zero);
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pickerChannel, null);
  });

  Future<void> openCamera(WidgetTester tester) async {
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_Auth.new),
      sharedPreferencesProvider.overrideWithValue(preferences),
      preloadedUserHouseholdsProvider('owner').overrideWith((ref) => []),
      householdScopeProvider.overrideWithValue(const HouseholdScope(
        viewMode: ViewMode.personal,
        selected: SelectedHouseholdState(),
        portfolioHouseholdIds: {},
      )),
      walletsByCurrencyProvider.overrideWith((ref, query) async => []),
      expenseSaveNotifierProvider
          .overrideWith((ref) => save = _ReceiptSave(ref)),
      transactionEditProvider.overrideWith((ref) => edit = _Edit(ref)),
    ]);
    addTearDown(container.dispose);
    save = container.read(expenseSaveNotifierProvider.notifier) as _ReceiptSave;
    edit = container.read(transactionEditProvider.notifier) as _Edit;
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
            builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      await showUnifiedTransactionSheet(context,
                          existingExpense: expense);
                      sheetClosed = true;
                    },
                    child: const Text('Open'),
                  ),
                )),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add Receipt Photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Receipt Photo'));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.text('Open')))!;
    await tester.tap(find.text(l10n.takePhotoWithCamera));
    await tester.pumpAndSettle();
    expect(pickerCalls.single.method, 'pickImage');
    expect((pickerCalls.single.arguments as Map)['source'], 0);
  }

  Future<void> confirmPhoto(WidgetTester tester) async {
    pickedPhoto.complete(receiptPath);
    await tester.pumpAndSettle();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(sheetClosed, isFalse);
    expect(
        tester
            .widget<TransactionReceiptImage>(
                find.byType(TransactionReceiptImage))
            .localImagePath,
        receiptPath);
    expect(save.uploads, isEmpty);
    expect(edit.patches, isEmpty);
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> saveSheet(WidgetTester tester) async {
    final confirm = find.descendant(
      of: find.byType(MonekoSheetConfirmButton),
      matching: find.byType(IconButton),
    );
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('camera confirmation retains receipt until explicit sheet save',
      (tester) async {
    await openCamera(tester);
    await confirmPhoto(tester);
    await saveSheet(tester);
    expect(save.uploads, [receiptPath]);
    expect(sheetClosed, isFalse);
    const receiptUrl = 'https://example.test/receipt.jpg';
    save.upload.complete(receiptUrl);
    await tester.pumpAndSettle();
    expect(edit.patches.single['receipt_image_url'], receiptUrl);
    expect(sheetClosed, isTrue);
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('canceling camera leaves the transaction sheet open',
      (tester) async {
    await openCamera(tester);
    pickedPhoto.complete(null);
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(sheetClosed, isFalse);
    expect(find.byType(TransactionReceiptImage), findsNothing);
    expect(save.uploads, isEmpty);
    expect(edit.patches, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(sheetClosed, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('camera confirmation touch cannot dismiss the underlying sheet',
      (tester) async {
    await openCamera(tester);
    // iOS can forward the native Use Photo tap to the Flutter modal barrier.
    await tester.tapAt(const Offset(4, 4));
    await tester.pump();
    await confirmPhoto(tester);
    expect(sheetClosed, isFalse);
    expect(edit.patches, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('camera confirmation touch cannot trigger transaction save',
      (tester) async {
    await openCamera(tester);
    final confirm = find.descendant(
        of: find.byType(MonekoSheetConfirmButton),
        matching: find.byType(IconButton));
    await tester.tapAt(tester.getCenter(confirm));
    await tester.pump();
    expect(sheetClosed, isFalse);
    expect(save.uploads, isEmpty);
    expect(edit.patches, isEmpty);
    await confirmPhoto(tester);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('camera error releases touch shield and retains the sheet',
      (tester) async {
    await openCamera(tester);
    pickerError = PlatformException(code: 'camera_access_denied');
    pickedPhoto.complete(null);
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(sheetClosed, isFalse);
    expect(save.uploads, isEmpty);
    // Let the error toast leave the top edge before testing backdrop input.
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(sheetClosed, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpWidget(const SizedBox());
  });
}
