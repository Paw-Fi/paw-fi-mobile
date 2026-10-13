import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/widgets/transaction_receipt_image.dart';

void main() {
  late Directory directory;
  setUp(
      () async => directory = await Directory.systemTemp.createTemp('receipt'));
  tearDown(() async => directory.delete(recursive: true));

  Future<void> pumpReceipt(
    WidgetTester tester, {
    String? path,
    String? url,
    BoxFit fit = BoxFit.cover,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: SizedBox(
          width: 320,
          height: 200,
          child: TransactionReceiptImage(
            localImagePath: path,
            imageUrl: url,
            width: 320,
            height: 200,
            fit: fit,
            placeholder: (_) => const Text('Loading receipt'),
            unavailable: (_) =>
                const Center(child: Text('Receipt unavailable')),
          ),
        ),
      ),
    ));
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      if (find.text('Receipt unavailable').evaluate().isNotEmpty ||
          find.byType(CachedNetworkImage).evaluate().isNotEmpty ||
          tester
              .widgetList<RawImage>(find.byType(RawImage))
              .any((image) => image.image != null)) {
        break;
      }
    }
  }

  for (final fit in [BoxFit.cover, BoxFit.contain]) {
    testWidgets('retired local receipt is handled in $fit view',
        (tester) async {
      final path = '${directory.path}/retired.bin';
      await tester.runAsync(() async {
        await File(path).writeAsBytes([1, 2, 3]);
        await File(path).delete();
      });
      await pumpReceipt(tester, path: path, fit: fit);
      expect(find.text('Receipt unavailable'), findsOneWidget);
      expect(tester.getSize(find.byType(TransactionReceiptImage)),
          const Size(320, 200));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('missing local receipt falls back to its exact remote URL',
      (tester) async {
    const url = 'https://example.test/confirmed-receipt.jpg';
    await pumpReceipt(tester, path: '${directory.path}/retired.bin', url: url);
    final remote =
        tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
    expect(remote.imageUrl, url);
    expect(remote.fit, BoxFit.cover);
    expect(remote.width, 320);
    expect(remote.height, 200);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a corrupt local file cannot escape through the image stream',
      (tester) async {
    final file = (await tester.runAsync(
        () => File('${directory.path}/corrupt.bin').writeAsBytes([1, 2, 3])))!;
    await pumpReceipt(tester, path: file.path);
    expect(find.text('Receipt unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('valid local receipt still renders without a remote request',
      (tester) async {
    final file = (await tester.runAsync(() =>
        File('lib/assets/images/category/coffee.png')
            .copy('${directory.path}/receipt.png')))!;
    await pumpReceipt(tester,
        path: file.path, url: 'https://example.test/unused.jpg');
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.text('Receipt unavailable'), findsNothing);
    expect(tester.widget<Image>(find.byType(Image)).image, isA<FileImage>());
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
