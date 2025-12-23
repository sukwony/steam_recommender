import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/game.dart';

class HltbService {
  // HowLongToBeat doesn't have an official API, so we use web scraping approach
  // For production, consider using a backend service or unofficial APIs
  
  static const String _searchUrl = 'https://howlongtobeat.com/api/search';
  
  /// Search for a game on HowLongToBeat
  Future<HltbGameData?> searchGame(String gameName) async {
    try {
      // Clean the game name for better search results
      final cleanName = _cleanGameName(gameName);
      
      final response = await http.post(
        Uri.parse(_searchUrl),
        headers: {
          'Content-Type': 'application/json',
          'Referer': 'https://howlongtobeat.com',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
        body: json.encode({
          'searchType': 'games',
          'searchTerms': cleanName.split(' '),
          'searchPage': 1,
          'size': 5,
          'searchOptions': {
            'games': {
              'userId': 0,
              'platform': '',
              'sortCategory': 'popular',
              'rangeCategory': 'main',
              'rangeTime': {'min': 0, 'max': 0},
              'gameplay': {'perspective': '', 'flow': '', 'genre': ''},
              'modifier': '',
            },
            'users': {'sortCategory': 'postcount'},
            'filter': '',
            'sort': 0,
            'randomizer': 0,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final games = data['data'] as List<dynamic>? ?? [];
        
        if (games.isNotEmpty) {
          // Find best match
          final match = _findBestMatch(games, cleanName);
          if (match != null) {
            return HltbGameData(
              id: match['game_id']?.toString() ?? '',
              name: match['game_name'] ?? '',
              mainHours: _parseHours(match['comp_main']),
              mainExtraHours: _parseHours(match['comp_plus']),
              completionistHours: _parseHours(match['comp_100']),
              imageUrl: match['game_image'] != null 
                  ? 'https://howlongtobeat.com/games/${match['game_image']}'
                  : null,
            );
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Clean game name for better search results
  String _cleanGameName(String name) {
    // Remove common suffixes and special characters
    return name
        .replaceAll(RegExp(r'™|®|©'), '')
        .replaceAll(RegExp(r'\s*[-:]\s*(Definitive|Complete|GOTY|Game of the Year|Edition|Remastered|Enhanced|Ultimate).*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Find the best matching game from search results
  Map<String, dynamic>? _findBestMatch(List<dynamic> games, String searchName) {
    final normalizedSearch = searchName.toLowerCase();
    
    // First try exact match
    for (final game in games) {
      final gameName = (game['game_name'] as String? ?? '').toLowerCase();
      if (gameName == normalizedSearch) {
        return game as Map<String, dynamic>;
      }
    }
    
    // Then try contains match
    for (final game in games) {
      final gameName = (game['game_name'] as String? ?? '').toLowerCase();
      if (gameName.contains(normalizedSearch) || normalizedSearch.contains(gameName)) {
        return game as Map<String, dynamic>;
      }
    }
    
    // Return first result if no better match
    return games.isNotEmpty ? games.first as Map<String, dynamic> : null;
  }

  /// Parse hours from HLTB response (seconds to hours)
  double? _parseHours(dynamic value) {
    if (value == null || value == 0) return null;
    // HLTB returns time in seconds
    return (value as num).toDouble() / 3600;
  }

  /// Enrich a game with HLTB data
  Future<Game> enrichWithHltbData(Game game) async {
    final hltbData = await searchGame(game.name);
    
    if (hltbData != null) {
      return game.copyWith(
        hltbMainHours: hltbData.mainHours,
        hltbExtraHours: hltbData.mainExtraHours,
        hltbCompletionistHours: hltbData.completionistHours,
        lastSynced: DateTime.now(),
      );
    }
    
    return game;
  }

  /// Batch enrich multiple games (with rate limiting)
  Future<List<Game>> enrichGamesWithHltb(
    List<Game> games, {
    void Function(int current, int total)? onProgress,
  }) async {
    final enrichedGames = <Game>[];
    
    for (int i = 0; i < games.length; i++) {
      final game = games[i];
      
      // Skip if already has HLTB data
      if (game.hltbMainHours != null) {
        enrichedGames.add(game);
        continue;
      }
      
      final enriched = await enrichWithHltbData(game);
      enrichedGames.add(enriched);
      
      onProgress?.call(i + 1, games.length);
      
      // Rate limiting: wait between requests
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    return enrichedGames;
  }
}

class HltbGameData {
  final String id;
  final String name;
  final double? mainHours;
  final double? mainExtraHours;
  final double? completionistHours;
  final String? imageUrl;

  HltbGameData({
    required this.id,
    required this.name,
    this.mainHours,
    this.mainExtraHours,
    this.completionistHours,
    this.imageUrl,
  });
}
