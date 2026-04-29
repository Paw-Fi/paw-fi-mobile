import 'dart:async';
import 'dart:io';

bool shouldReportFatalFlutterError(Object exception) {
  if (exception is HttpException) return false;
  if (exception is SocketException) return false;
  if (exception is HandshakeException) return false;
  if (exception is TimeoutException) return false;
  final message = exception.toString().toLowerCase();
  if (_looksLikeTransientInfrastructureFailure(message)) {
    return false;
  }
  // Known Flutter engine bug on Android - platform channel reply sent twice.
  // Not caused by app code; does not affect functionality.
  if (message.contains('reply already submitted')) {
    return false;
  }
  return true;
}

bool _looksLikeTransientInfrastructureFailure(String message) {
  return message.contains('authretryablefetchexception') ||
      message.contains('socketexception') ||
      message.contains('failed host lookup') ||
      message.contains('connection reset') ||
      message.contains('connection terminated') ||
      message.contains('connection abort') ||
      message.contains('connection closed before full header was received') ||
      message.contains('bad file descriptor') ||
      message.contains('service is temporarily unavailable') ||
      message.contains('supabase_edge_runtime_error') ||
      message.contains('status: 503') ||
      message.contains('statuscode: null');
}
