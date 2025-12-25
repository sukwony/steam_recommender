import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/game.dart';

class SteamApiService {
  // Note: For production, use a backend proxy to protect API key
  // Steam Web API: https://steamcommunity.com/dev/apikey
  
  static const String _baseUrl = 'https://api.steampowered.com';
  static const String _storeUrl = 'https://store.steampowered.com/api';

  /// Fetch owned games for a Steam user
  /// Requires Steam API key and Steam ID (64-bit)
  Future<List<Game>> fetchOwnedGames(String steamId, String apiKey) async {
    final url = '$_baseUrl/IPlayerService/GetOwnedGames/v1/'
        '?key=$apiKey'
        '&steamid=$steamId'
        '&include_appinfo=1'
        '&include_played_free_games=1'
        '&format=json';

    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final gamesData = data['response']['games'] as List<dynamic>? ?? [];
        
        return gamesData.map((gameJson) {
          final appId = gameJson['appid'].toString();
          return Game(
            id: appId,
            name: gameJson['name'] ?? 'Unknown Game',
            headerImageUrl: 'https://cdn.cloudflare.steamstatic.com/steam/apps/$appId/header.jpg',
            playtimeMinutes: gameJson['playtime_forever'] ?? 0,
            lastPlayed: gameJson['rtime_last_played'] != null && gameJson['rtime_last_played'] > 0
                ? DateTime.fromMillisecondsSinceEpoch(gameJson['rtime_last_played'] * 1000)
                : null,
          );
        }).toList();
      } else {
        throw SteamApiException('Failed to fetch games: ${response.statusCode}');
      }
    } catch (e) {
      if (e is SteamApiException) rethrow;
      throw SteamApiException('Network error: $e');
    }
  }

  /// Fetch detailed game info from Steam Store API
  Future<Map<String, dynamic>?> fetchGameDetails(String appId) async {
    final url = '$_storeUrl/appdetails?appids=$appId';

    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data[appId]['success'] == true) {
          return data[appId]['data'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Fetch game reviews/ratings
  Future<Map<String, dynamic>?> fetchGameReviews(String appId) async {
    final url = 'https://store.steampowered.com/appreviews/$appId?json=1&language=all&purchase_type=all';

    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == 1) {
          final summary = data['query_summary'];
          return {
            'total_positive': summary['total_positive'],
            'total_negative': summary['total_negative'],
            'total_reviews': summary['total_reviews'],
            'review_score': summary['review_score'],
            'review_score_desc': summary['review_score_desc'],
          };
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Enrich a game with detailed information
  Future<Game> enrichGameData(Game game) async {
    final details = await fetchGameDetails(game.id);
    final reviews = await fetchGameReviews(game.id);

    double steamRating = game.steamRating;
    int reviewCount = game.steamReviewCount;
    double? metacritic = game.metacriticScore;
    List<String> genres = game.genres;

    if (reviews != null) {
      final total = reviews['total_reviews'] as int? ?? 0;
      final positive = reviews['total_positive'] as int? ?? 0;
      if (total > 0) {
        steamRating = (positive / total * 100);
        reviewCount = total;
      }
    }

    if (details != null) {
      if (details['metacritic'] != null) {
        metacritic = (details['metacritic']['score'] as num?)?.toDouble();
      }
      if (details['genres'] != null) {
        genres = (details['genres'] as List<dynamic>)
            .map((g) => g['description'] as String)
            .toList();
      }
    }

    return game.copyWith(
      steamRating: steamRating,
      steamReviewCount: reviewCount,
      metacriticScore: metacritic,
      genres: genres,
      lastSynced: DateTime.now(),
    );
  }

  /// Validate Steam ID format
  static bool isValidSteamId(String steamId) {
    // Steam64 ID should be 17 digits starting with 7656
    return RegExp(r'^7656\d{13}$').hasMatch(steamId);
  }

  /// Convert vanity URL to Steam ID
  Future<String?> resolveVanityUrl(String vanityUrl, String apiKey) async {
    final url = '$_baseUrl/ISteamUser/ResolveVanityURL/v1/'
        '?key=$apiKey'
        '&vanityurl=$vanityUrl';

    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['response']['success'] == 1) {
          return data['response']['steamid'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

class SteamApiException implements Exception {
  final String message;
  SteamApiException(this.message);
  
  @override
  String toString() => 'SteamApiException: $message';
}
