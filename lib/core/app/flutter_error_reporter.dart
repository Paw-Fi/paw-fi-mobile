import 'dart:async';
import 'dart:io';

bool shouldReportFatalFlutterError(Object exception) {
  if (exception is HttpException) return false;
  if (exception is TimeoutException) return false;
  final message = exception.toString().toLowerCase();
  if (message.contains('connection closed before full header was received')) {
    return false;
  }
  // Known Flutter engine bug on Android - platform channel reply sent twice.
  // Not caused by app code; does not affect functionality.
  if (message.contains('reply already submitted')) {
    return false;
  }
  return true;
}
