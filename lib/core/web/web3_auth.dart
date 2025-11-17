/// Conditional export for Web3 authentication
/// Exports web implementation for Flutter Web, stub for other platforms

export 'web3_auth_stub.dart'
    if (dart.library.js_interop) 'web3_auth_web.dart';
