import 'dart:async';

Future<T> runStartupStep<T>({
  required String label,
  required Future<T> Function() action,
  Duration timeout = const Duration(seconds: 10),
  Future<T> Function()? fallback,
  void Function(Object, StackTrace)? onError,
}) async {
  try {
    return await action().timeout(timeout);
  } on TimeoutException catch (error, stackTrace) {
    final timeoutError = TimeoutException(
      'Startup step "$label" timed out after ${timeout.inSeconds}s',
    );
    onError?.call(timeoutError, stackTrace);
    if (fallback != null) {
      return await fallback();
    }
    throw timeoutError;
  } catch (error, stackTrace) {
    onError?.call(error, stackTrace);
    if (fallback != null) {
      return await fallback();
    }
    rethrow;
  }
}
