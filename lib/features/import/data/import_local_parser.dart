import 'package:flutter/foundation.dart';

import 'package:moneko/features/import/data/import_excel_parser.dart';
import 'package:moneko/features/import/data/import_parser.dart';
import 'package:moneko/features/import/domain/import_models.dart';

const Duration _defaultLocalImportParseTimeout = Duration(seconds: 12);

class LocalImportParseRequest {
  const LocalImportParseRequest({
    required this.bytes,
    required this.extension,
  });

  final Uint8List bytes;
  final String? extension;
}

Future<ImportTable> parseLocalImportTable(
  LocalImportParseRequest request, {
  Duration timeout = _defaultLocalImportParseTimeout,
}) {
  return compute(_parseLocalImportTableSync, request).timeout(
    timeout,
    onTimeout: () {
      throw Exception(
        'File parsing timed out. Please verify the file format and try again.',
      );
    },
  );
}

ImportTable _parseLocalImportTableSync(LocalImportParseRequest request) {
  final extension = request.extension?.toLowerCase();
  if (extension == 'xlsx' || extension == 'xls') {
    return parseImportExcelTable(request.bytes);
  }

  final content = decodeImportTextFromBytes(request.bytes);
  return parseImportTable(content);
}
