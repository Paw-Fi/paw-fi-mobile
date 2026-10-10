import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/utils/error_handler.dart';

void main() {
  group('ErrorHandler.getUserFriendlyMessage', () {
    test('preserves safe clarification failure and keeps it retryable', () {
      const message =
          "We couldn't check the transaction details. Please try again.";
      final error = {
        'success': false,
        'code': 'AI_CLARIFICATION_FAILED',
        'status': 503,
        'error': message,
      };
      expect(
        ErrorHandler.getUserFriendlyMessage(error,
            context: BackendErrorContext.analyzeExpense),
        message,
      );
      expect(ErrorHandler.isRetryable(error), isTrue);
    });

    test('maps validation amount limit to short user message', () {
      final message = ErrorHandler.getUserFriendlyMessage(
        {
          'success': false,
          'error':
              'amount_cents must be less than 100,000,000, code: VALIDATION_ERROR',
          'code': 'VALIDATION_ERROR',
          'status': 400,
        },
        context: BackendErrorContext.updateExpense,
      );

      expect(
        message,
        'Amount is too large. Please enter a smaller value.',
      );
    });

    test('maps analyze timeout to concise action message', () {
      final message = ErrorHandler.getUserFriendlyMessage(
        {'error': 'Analysis timed out after 140 seconds', 'status': 504},
        context: BackendErrorContext.analyzeExpense,
      );

      expect(message, 'This took too long. Try a smaller file.');
    });

    test('does not leak FunctionException dump text', () {
      const rawError =
          'FunctionException(status: 400, details: {success: false, error: amount_cents must be less than 100,000,000, code: VALIDATION_ERROR}, reasonPhrase: Bad Request)';

      final message = ErrorHandler.getUserFriendlyMessage(
        rawError,
        context: BackendErrorContext.updateExpense,
      );

      expect(message.toLowerCase(), isNot(contains('functionexception')));
      expect(message.toLowerCase(), isNot(contains('details:')));
      expect(message, 'Amount is too large. Please enter a smaller value.');
    });
  });
}
