import 'dart:io';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/app/flutter_error_reporter.dart';

void main() {
  test('shouldReportFatalFlutterError returns false for HttpException', () {
    final result = shouldReportFatalFlutterError(
      const HttpException('Connection closed before full header was received'),
    );

    expect(result, isFalse);
  });

  test('shouldReportFatalFlutterError returns false for TimeoutException', () {
    final result = shouldReportFatalFlutterError(
      TimeoutException('Future not completed'),
    );

    expect(result, isFalse);
  });

  test('shouldReportFatalFlutterError returns false for SocketException', () {
    final result = shouldReportFatalFlutterError(
      const SocketException('Connection reset by peer'),
    );

    expect(result, isFalse);
  });

  test(
      'shouldReportFatalFlutterError returns false for transient Supabase failures',
      () {
    final result = shouldReportFatalFlutterError(
      Exception(
        'FunctionException(status: 503, details: {code: SUPABASE_EDGE_RUNTIME_ERROR, message: Service is temporarily unavailable})',
      ),
    );

    expect(result, isFalse);
  });

  test(
      'shouldReportFatalFlutterError returns false for reply already submitted',
      () {
    final result = shouldReportFatalFlutterError(
      StateError('java.lang.IllegalStateException: Reply already submitted'),
    );

    expect(result, isFalse);
  });

  test('shouldReportFatalFlutterError returns true for non-network errors', () {
    final result = shouldReportFatalFlutterError(StateError('bad state'));

    expect(result, isTrue);
  });
}
