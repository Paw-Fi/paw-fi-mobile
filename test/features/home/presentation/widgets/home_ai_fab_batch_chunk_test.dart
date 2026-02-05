import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/widgets/home_ai_fab.dart';

void main() {
  test('chunkList splits items into batches of max size', () {
    final items = List<int>.generate(501, (index) => index);
    final chunks = chunkList(items, 500);

    expect(chunks.length, 2);
    expect(chunks[0].length, 500);
    expect(chunks[1].length, 1);
  });

  test('chunkList returns empty list when input is empty', () {
    final chunks = chunkList(<int>[], 500);

    expect(chunks, isEmpty);
  });
}
