import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/utils/image_compressor.dart';

void main() {
  group('ImageCompressConfig.logo', () {
    test('uses a small square-friendly preset for tiny logos', () {
      expect(ImageCompressConfig.logo.maxDimension, 160);
      expect(ImageCompressConfig.logo.quality, 75);
      expect(ImageCompressConfig.logo.preferredFormat, CompressFormat.jpeg);
    });
  });
}
