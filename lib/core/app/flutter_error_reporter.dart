import 'dart:io';

bool shouldReportFatalFlutterError(Object exception) {
  if (exception is HttpException) return false;
  final message = exception.toString().toLowerCase();
  if (message.contains('connection closed before full header was received')) {
    return false;
  }
  return true;
}
