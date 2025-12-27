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
  Future<HltbGameData?> searchGame(String gameName) async {
    try {
      // Clean the game name for better search results
      final cleanName = _cleanGameName(gameName);

      debugPrint('[HLTB] 🔍 Searching for "$gameName" via API...');

      // Call search API directly
      final results = await _httpClient.searchGames(cleanName);

      if (results.isEmpty) {
        debugPrint('[HLTB] ❌ No results for "$gameName"');
        return null;
      }

      // Return first result (most relevant)
      final firstResult = results.first;

      // Validate result matches search query (fuzzy matching)
      if (!_isGoodMatch(cleanName, firstResult.name)) {
        debugPrint('[HLTB] ⚠️ "$gameName" → Rejected mismatch: ${firstResult.name}');
        return null;
      }

      debugPrint('[HLTB] ✅ "$gameName" → ${firstResult.name}: ${firstResult.mainHours ?? "-"}h / ${firstResult.mainExtraHours ?? "-"}h / ${firstResult.completionistHours ?? "-"}h');
      return firstResult;
    } catch (e) {
      debugPrint('[HLTB] ❌ Error: $e');
      return null;
    }
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
  String _cleanGameName(String name) {
    // Remove common suffixes and special characters
    return name
        // Replace trademark symbols with space (not empty string!)
        // This prevents "COMBAT™7" from becoming "COMBAT7" instead of "COMBAT 7"
        .replaceAll(RegExp(r'™|®|©'), ' ')
        // Remove edition suffixes (with or without separator)
        // Handle multi-word editions like "Special Edition", "Collector's Edition"
        .replaceAll(RegExp(r'\s*[-:]?\s*(Special|Collectors?|Legendary|Standard|Premium)?\s*(Definitive|Complete|GOTY|Game of the Year|Edition|Remastered|Enhanced|Ultimate|Deluxe|Digital).*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }


  /// Enrich a game with HLTB data using three-tier lookup
  /// Tier 1: Use stored game.hltbId (fastest)
  /// Tier 2: Query Wikidata for Steam AppID → HLTB ID mapping (reliable)
  /// Tier 3: Fallback to name-based search with exact matching (accurate)
  Future<Game> enrichWithHltbData(Game game) async {
    // Tier 1: Use stored HLTB ID (fastest path)
    if (game.hltbId != null && game.hltbId!.isNotEmpty) {
      debugPrint('[HLTB] 🎯 Tier 1: Using stored ID ${game.hltbId} for "${game.name}"');
      final data = await _httpClient.fetchByGameId(game.hltbId!);
      if (data != null) {
        debugPrint('[HLTB] ✅ Tier 1 success: ${data.name}');
        return _applyHltbData(game, data);
      }
      // If direct fetch fails, continue to other tiers
      debugPrint('[HLTB] ⚠️ Tier 1 failed, trying other methods');
    }

    // Tier 2: Wikidata mapping lookup
    try {
      final hltbId = await _wikidataService.getHltbId(game.id);
      if (hltbId != null && hltbId.isNotEmpty) {
        debugPrint('[HLTB] 🌐 Tier 2: Wikidata mapping: ${game.id} → $hltbId');
        final data = await _httpClient.fetchByGameId(hltbId);
        if (data != null) {
          debugPrint('[HLTB] ✅ Tier 2 success: ${data.name}');
          // Store hltbId for future syncs (Tier 1 path)
          return _applyHltbData(game, data).copyWith(hltbId: hltbId);
        }
      }
    } catch (e) {
      debugPrint('[HLTB] ⚠️ Tier 2 error for ${game.id}: $e');
      // Continue to Tier 3 fallback
    }

    // Tier 3: Name-based search fallback (exact match only)
    debugPrint('[HLTB] 🔍 Tier 3: Falling back to name search for "${game.name}"');
    final data = await searchGame(game.name);
    if (data != null) {
      // searchGame() already validates with _isGoodMatch() (exact match only)
      debugPrint('[HLTB] ✅ Tier 3 success: "${game.name}" → "${data.name}"');
      // Store hltbId for future syncs
      return _applyHltbData(game, data).copyWith(hltbId: data.id);
    }

    debugPrint('[HLTB] ⚠️ All tiers failed - leaving HLTB data empty for "${game.name}"');
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
