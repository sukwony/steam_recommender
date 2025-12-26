import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'backend_api_service.dart';

/// Service for handling Steam OAuth authentication flow
/// Uses flutter_web_auth_2 to open browser and handle callback
class SteamAuthService {
  final BackendApiService _backendApi;

  SteamAuthService(this._backendApi);

  /// Authenticate user with Steam via backend OAuth flow
  ///
  /// Returns Steam ID on success, null on failure/cancellation
  Future<String?> authenticateWithSteam() async {
    try {
      // Step 1: Build Steam OpenID authentication URL
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

      // Step 2: Open browser for Steam authentication
      // The backend will redirect to wntp://auth/success?token=xxx&steamId=yyy
      final result = await FlutterWebAuth2.authenticate(
        url: authUrl,
        callbackUrlScheme: 'wntp',
      );

      // Step 3: Parse callback URL
      final uri = Uri.parse(result);
      final token = uri.queryParameters['token'];
      final steamId = uri.queryParameters['steamId'];

      if (token == null || steamId == null) {
        throw Exception('Invalid callback: missing token or steamId');
      }

      // Step 4: Save session to secure storage
      await _backendApi.saveSession(token, steamId);

      return steamId;
    } catch (e) {
      // User cancelled or other errors
      if (e.toString().contains('CANCELED') || e.toString().contains('User cancelled')) {
        return null;
      }
      // Other errors (network, backend, etc.)
      rethrow;
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
