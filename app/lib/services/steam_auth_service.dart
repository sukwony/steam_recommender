import 'dart:async';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'backend_api_service.dart';

/// Service for handling Steam OAuth authentication flow
/// Uses url_launcher to open browser and MethodChannel to handle callback
class SteamAuthService {
  final BackendApiService _backendApi;
  static const platform = MethodChannel('com.wntp/deep_link');
  static Completer<String>? _authCompleter;

  SteamAuthService(this._backendApi) {
    // Set up deep link handler
    platform.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onDeepLink') {
      final String url = call.arguments as String;
      if (_authCompleter != null && !_authCompleter!.isCompleted) {
        _authCompleter!.complete(url);
      }
    }
  }

  /// Authenticate user with Steam via backend OAuth flow
  ///
  /// Returns Steam ID on success, null on failure/cancellation
  Future<String?> authenticateWithSteam() async {
    try {
      // Build Steam OpenID authentication URL
      final backendUrl = _backendApi.baseUrl;
      final returnTo = Uri.encodeComponent('$backendUrl/api/auth/steam-callback');
      final realm = Uri.encodeComponent(backendUrl);

      final authUrl = 'https://steamcommunity.com/openid/login'
          '?openid.ns=http://specs.openid.net/auth/2.0'
          '&openid.mode=checkid_setup'
          '&openid.return_to=$returnTo'
          '&openid.realm=$realm'
          '&openid.identity=http://specs.openid.net/auth/2.0/identifier_select'
          '&openid.claimed_id=http://specs.openid.net/auth/2.0/identifier_select';

      // Create completer to wait for deep link callback
      _authCompleter = Completer<String>();

      // Open browser for Steam authentication
      // The actual callback comes through MethodChannel
      final uri = Uri.parse(authUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch Steam login URL');
      }

      // Wait for MethodChannel callback with timeout
      final result = await _authCompleter!.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw Exception('Authentication timeout'),
      );

      // Parse callback URL
      final uri = Uri.parse(result);
      final token = uri.queryParameters['token'];
      final steamId = uri.queryParameters['steamId'];

      if (token == null || steamId == null) {
        throw Exception('Invalid callback: missing token or steamId');
      }

      // Save session to secure storage
      await _backendApi.saveSession(token, steamId);

      return steamId;
    } catch (e) {
      _authCompleter = null;

      // Timeout = user cancelled
      if (e.toString().contains('timeout') || e.toString().contains('Authentication timeout')) {
        return null;
      }
      rethrow;
    } finally {
      _authCompleter = null;
    }
  }

  /// Sign out (clear session)
  Future<void> signOut() async {
    await _backendApi.signOut();
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    return await _backendApi.isAuthenticated();
  }

  /// Get current Steam ID
  Future<String?> getSteamId() async {
    return await _backendApi.getSteamId();
  }
}
