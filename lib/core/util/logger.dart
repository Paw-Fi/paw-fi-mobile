import 'dart:developer' as developer;

void appLog(
  String message, {
  String name = 'Moneko',
  Object? error,
  StackTrace? stackTrace,
}) {
  developer.log(message, name: name, error: error, stackTrace: stackTrace);
}
