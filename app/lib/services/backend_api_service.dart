import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for communicating with WNTP backend API
/// Handles authentication, session management, and API calls
class BackendApiService {
  static const String _baseUrl = 'https://wntp-backend.vercel.app';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _tokenKey = 'jwt_token';
  static const String _steamIdKey = 'steam_id';

  /// Get the backend base URL
  String get baseUrl => _baseUrl;

  /// Save session token and Steam ID to secure storage
  Future<void> saveSession(String token, String steamId) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _steamIdKey, value: steamId);
  }

  /// Get the current session token
  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// Get the current Steam ID
  Future<String?> getSteamId() async {
    return await _storage.read(key: _steamIdKey);
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Sign out (clear session)
  Future<void> signOut() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _steamIdKey);
  }

  /// Fetch owned games from Steam (requires authentication)
  Future<Map<String, dynamic>> fetchOwnedGames() async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/games/owned'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        // Token expired or invalid
        await signOut();
        throw Exception('Session expired. Please sign in again.');
      } else {
        throw Exception('Failed to fetch owned games: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching owned games: $e');
    }
  }

  /// Fetch game details from Steam Store (direct API call)
  Future<Map<String, dynamic>> fetchGameDetails(String appId) async {
    try {
      final response = await http.get(
        Uri.parse('https://store.steampowered.com/api/appdetails?appids=$appId'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to fetch game details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching game details: $e');
    }
  }

  /// Fetch game reviews from Steam Store (direct API call)
  Future<Map<String, dynamic>> fetchGameReviews(String appId) async {
    try {
      final response = await http.get(
        Uri.parse('https://store.steampowered.com/appreviews/$appId?json=1&num_per_page=0'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to fetch game reviews: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching game reviews: $e');
    }
  }
}
