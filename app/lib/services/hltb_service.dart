import 'package:flutter/foundation.dart';
import '../models/game.dart';
import '../models/hltb_game_data.dart';
import 'hltb_http_client.dart';
import 'wikidata_service.dart';

class HltbService {
  // Three-tier HLTB data fetching strategy:
  // 1. Tier 1 (Fast): Use stored game.hltbId for direct fetch
  // 2. Tier 2 (Reliable): Query Wikidata for Steam AppID → HLTB ID mapping
  // 3. Tier 3 (Fallback): Name-based search with exact matching only

  final HltbHttpClient _httpClient = HltbHttpClient();
  final WikidataService _wikidataService = WikidataService();

  /// Initialize the service and Wikidata cache
  Future<void> initialize() async {
    await _wikidataService.initialize();
  }

  /// Search for a game on HowLongToBeat using direct API access
  ///
  /// Throws for retryable errors (caller should retry):
  /// - TimeoutException: Network timeout
  /// - SocketException: Network connection failed
  /// - HltbRetryableException: Auth expired or server error
  Future<HltbGameData?> _searchGame(String gameName) async {
    // Clean the game name for better search results
    final cleanName = _cleanGameName(gameName);

    // Call search API directly (may throw network exceptions)
    final results = await _httpClient.searchGames(cleanName);

    if (results.isEmpty) return null;

    // Return first result (most relevant)
    final firstResult = results.first;

    // Validate result matches search query (exact matching)
    if (!_isGoodMatch(cleanName, firstResult.name)) {
      debugPrint('[HLTB] ⚠️ "$gameName" → Rejected mismatch: ${firstResult.name}');
      return null;
    }

    return firstResult;
  }

  /// Check if search result is a good match for the query
  /// Uses EXACT matching only (after normalization) - no fuzzy logic
  /// This ensures high accuracy by rejecting false positives
  bool _isGoodMatch(String query, String result) {
    return _normalize(query) == _normalize(result);
  }

  /// Normalize string for exact matching
  /// Removes special characters and normalizes whitespace
  String _normalize(String s) {
    return s
        .toLowerCase()
        // CRITICAL: Replace special chars with space BEFORE removing them
        // This ensures "NieR:Automata" and "NieR: Automata" both become "nier automata"
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ') // Replace special chars with space
        .replaceAll(RegExp(r'\s+'), ' ')          // Normalize whitespace
        .trim();
  }

  /// Clean up resources
  void dispose() {
    _httpClient.dispose();
  }

  /// Clean game name for better search results
  /// Converts Steam game names to HLTB-compatible format
  /// Only removes special characters - keeps edition names for better exact matching
  String _cleanGameName(String name) {
    return name
        // Replace trademark symbols with space (not empty string!)
        // This prevents "COMBAT™7" from becoming "COMBAT7" instead of "COMBAT 7"
        .replaceAll(RegExp(r'™|®|©'), ' ')
        // Replace colons with space (HLTB uses spaces instead of colons)
        // "F.E.A.R.: Extraction" → "F.E.A.R. Extraction"
        .replaceAll(':', ' ')
        // Normalize whitespace
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }


  /// Enrich a game with HLTB data using three-tier lookup
  /// Tier 1: Use stored game.hltbId (fastest)
  /// Tier 2: Query Wikidata for Steam AppID → HLTB ID mapping (reliable)
  /// Tier 3: Fallback to name-based search with exact matching (accurate)
  ///
  /// Throws for retryable errors (caller should retry):
  /// - TimeoutException: Network timeout
  /// - SocketException: Network connection failed
  /// - HltbRetryableException: Auth expired or server error
  Future<Game> enrichWithHltbData(Game game) async {
    // Tier 1: Use stored HLTB ID (fastest path)
    // May throw network exception - caller will retry
    if (game.hltbId != null && game.hltbId!.isNotEmpty) {
      final data = await _httpClient.fetchByGameId(game.hltbId!);
      if (data != null) {
        return _applyHltbData(game, data);
      }
      // data is null = game not found or parsing error, try other tiers
    }

    // Tier 2: Wikidata mapping lookup
    // May throw network exception - caller will retry
    try {
      final hltbId = await _wikidataService.getHltbId(game.id);
      if (hltbId != null && hltbId.isNotEmpty) {
        final data = await _httpClient.fetchByGameId(hltbId);
        if (data != null) {
          // Store hltbId for future syncs (Tier 1 path)
          return _applyHltbData(game, data).copyWith(hltbId: hltbId);
        }
      }
      // hltbId is null = no mapping in Wikidata, continue to Tier 3
    } catch (e) {
      // Network error or other exception - rethrow to abort and retry later
      debugPrint('[HLTB] ❌ Wikidata network error for ${game.id}: $e');
      rethrow;
    }

    // Tier 3: Name-based search fallback (exact match only)
    try {
      final data = await _searchGame(game.name);
      if (data != null) {
        // _searchGame() already validates with _isGoodMatch() (exact match only)
        // Store hltbId for future syncs
        return _applyHltbData(game, data).copyWith(hltbId: data.id);
      }
      // data is null = no match found in name search, mark as not found
    } catch (e) {
      // Network error or other exception - rethrow to abort and retry later
      debugPrint('[HLTB] ❌ Name search network error for "${game.name}": $e');
      rethrow;
    }

    // Mark as attempted but not found (empty string) to avoid re-fetching
    return game.copyWith(hltbId: ""); // No HLTB data (better empty than wrong)
  }

  /// Apply HLTB data to a game and update lastSynced
  Game _applyHltbData(Game game, HltbGameData data) {
    return game.copyWith(
      hltbMainHours: data.mainHours,
      hltbExtraHours: data.mainExtraHours,
      hltbCompletionistHours: data.completionistHours,
      lastSynced: DateTime.now(),
    );
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
      
      // Rate limiting: wait between requests with jitter to avoid detection
      // Increased from 500ms to 1.5-2.5s for WebView scraping
      await Future.delayed(Duration(milliseconds: 1500 + (DateTime.now().millisecond % 1000)));
    }
    
    return enrichedGames;
  }
}
