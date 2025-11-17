/// Stub implementation for non-web platforms
/// Web3 authentication is only available on Flutter Web
Future<Map<String, dynamic>?> web3SignIn({
  required String chain,
  required String statement,
  required String projectUrl,
  required String anonKey,
}) async {
  throw UnsupportedError(
    'Web3 authentication is only available on Flutter Web. '
    'This platform does not support browser wallet extensions.',
  );
}
