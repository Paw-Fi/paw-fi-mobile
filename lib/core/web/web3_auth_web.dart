/// Web implementation of Web3 authentication using JS interop
/// Connects to browser wallet extensions (MetaMask, Phantom, etc.)
/// and uses Supabase JS SDK for authentication

// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'dart:async';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Performs Web3 sign-in using browser wallet extensions
/// 
/// This function:
/// 1. Detects the appropriate wallet provider (ethereum/solana)
/// 2. Requests wallet connection and accounts
/// 3. Calls Supabase JS SDK's signInWithWeb3() method
/// 4. Returns session tokens for Flutter Supabase client
///
/// Throws:
/// - Exception if Supabase JS SDK is not loaded
/// - Exception if no wallet is detected
/// - Exception if user rejects the signature
/// - Exception if Supabase auth fails
Future<Map<String, dynamic>?> web3SignIn({
  required String chain,
  required String statement,
  required String projectUrl,
  required String anonKey,
}) async {
  try {
    FirebaseCrashlytics.instance.log('[Web3Auth] Starting authentication for chain: $chain');
    
    // Use external helpers to access window properties
    if (!_hasSupabase()) {
      throw Exception(
        'Supabase JS SDK is not available. '
        'Ensure <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script> '
        'is included in index.html',
      );
    }
    
    FirebaseCrashlytics.instance.log('[Web3Auth] Supabase JS SDK detected');
    
    final chainLower = chain.toLowerCase();
    
    // Connect to wallet based on chain
    if (chainLower == 'ethereum') {
      await _connectEthereumWallet();
    } else if (chainLower == 'solana') {
      await _connectSolanaWallet();
    } else {
      throw Exception('Unsupported chain: $chain. Use "ethereum" or "solana"');
    }
    
    FirebaseCrashlytics.instance.log('[Web3Auth] Wallet connected, calling signInWithWeb3');
    
    // Call external JS function that handles the Supabase auth
    final jsResult = await _callSupabaseWeb3SignIn(
      projectUrl,
      anonKey,
      chainLower,
      statement,
    ).toDart;
    
    // Convert JSObject to Dart Map
    final sessionData = _jsObjectToDart(jsResult);
    
    FirebaseCrashlytics.instance.log('[Web3Auth] Authentication successful');
    
    return sessionData;
  } catch (e) {
    FirebaseCrashlytics.instance.log('[Web3Auth] Error: $e');
    rethrow;
  }
}

// External JS functions defined in index.html
@JS('monekoWeb3Helper.hasSupabase')
external bool _hasSupabase();

@JS('monekoWeb3Helper.connectEthereumWallet')
external JSPromise<JSAny?> _connectEthereum();

@JS('monekoWeb3Helper.connectSolanaWallet')
external JSPromise<JSAny?> _connectSolana();

@JS('monekoWeb3Helper.callSupabaseWeb3SignIn')
external JSPromise<JSAny?> _callSupabaseWeb3SignIn(
  String projectUrl,
  String anonKey,
  String chain,
  String statement,
);

/// Convert JS object to Dart Map
Map<String, dynamic> _jsObjectToDart(JSAny? jsObj) {
  if (jsObj == null) {
    throw Exception('Received null JS object');
  }
  
  // Use dart:convert to safely convert
  final jsonString = _jsObjectToJsonString(jsObj);
  return _parseJsonString(jsonString);
}

@JS('JSON.stringify')
external String _jsObjectToJsonString(JSAny obj);


Map<String, dynamic> _parseJsonString(String jsonString) {
  // We'll manually extract the values since JSON.parse returns JSAny
  // This is a simpler approach that works with the current API

  // Parse the JSON string manually
  final map = <String, dynamic>{};

  // Extract values using regex patterns (simple but reliable for our use case)
  final accessTokenMatch =
      RegExp(r'"access_token"\s*:\s*"([^"]+)"').firstMatch(jsonString);
  final refreshTokenMatch =
      RegExp(r'"refresh_token"\s*:\s*"([^"]+)"').firstMatch(jsonString);
  final expiresInMatch =
      RegExp(r'"expires_in"\s*:\s*(\d+)').firstMatch(jsonString);
  final tokenTypeMatch =
      RegExp(r'"token_type"\s*:\s*"([^"]+)"').firstMatch(jsonString);
  final walletAddressMatch =
      RegExp(r'"wallet_address"\s*:\s*"([^"]+)"').firstMatch(jsonString);
  final chainMatch = RegExp(r'"chain"\s*:\s*"([^"]+)"').firstMatch(jsonString);

  if (accessTokenMatch != null) {
    map['access_token'] = accessTokenMatch.group(1);
  }
  if (refreshTokenMatch != null) {
    map['refresh_token'] = refreshTokenMatch.group(1);
  }
  if (expiresInMatch != null) {
    map['expires_in'] = int.parse(expiresInMatch.group(1)!);
  }
  if (tokenTypeMatch != null) {
    map['token_type'] = tokenTypeMatch.group(1);
  }
  if (walletAddressMatch != null) {
    map['wallet_address'] = walletAddressMatch.group(1);
  }
  if (chainMatch != null) {
    map['chain'] = chainMatch.group(1);
  }

  // Validate required fields
  if (!map.containsKey('access_token') || !map.containsKey('refresh_token')) {
    throw Exception('Missing required session tokens in response');
  }

  return map;
}

/// Connects to Ethereum wallet (MetaMask, etc.)
Future<void> _connectEthereumWallet() async {
  FirebaseCrashlytics.instance.log('[Web3Auth] Connecting to Ethereum wallet');
  try {
    await _connectEthereum().toDart;
    FirebaseCrashlytics.instance.log('[Web3Auth] Ethereum wallet connected');
  } catch (e) {
    if (e.toString().contains('rejected') || e.toString().contains('denied')) {
      throw Exception('You rejected the wallet connection request');
    }
    throw Exception(e.toString());
  }
}

/// Connects to Solana wallet (Phantom, etc.)
Future<void> _connectSolanaWallet() async {
  FirebaseCrashlytics.instance.log('[Web3Auth] Connecting to Solana wallet');
  try {
    await _connectSolana().toDart;
    FirebaseCrashlytics.instance.log('[Web3Auth] Solana wallet connected');
  } catch (e) {
    if (e.toString().contains('rejected') || e.toString().contains('denied')) {
      throw Exception('You rejected the wallet connection request');
    }
    throw Exception(e.toString());
  }
}
