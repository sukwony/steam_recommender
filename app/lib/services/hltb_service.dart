import 'package:flutter/foundation.dart';
import '../models/game.dart';
import '../models/hltb_game_data.dart';
import 'hltb_webview_service.dart';

class HltbService {
  // HowLongToBeat scraping via hidden WebView
  // Uses flutter_inappwebview to avoid bot detection by acting like a real browser

  /// Search for a game on HowLongToBeat using WebView scraping
  Future<HltbGameData?> searchGame(String gameName) async {
    try {
      // Clean the game name for better search results
      final cleanName = _cleanGameName(gameName);

      // Use WebView service to search (avoids bot detection)
      final result = await HltbWebViewService.instance.searchGame(cleanName);

      if (result != null) {
        debugPrint('[HLTB] ✅ "$gameName" → ${result.name}: ${result.mainHours ?? "-"}h / ${result.mainExtraHours ?? "-"}h / ${result.completionistHours ?? "-"}h');
      }

      return result;
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
      
      // Rate limiting: wait between requests with jitter to avoid detection
      // Increased from 500ms to 1.5-2.5s for WebView scraping
      await Future.delayed(Duration(milliseconds: 1500 + (DateTime.now().millisecond % 1000)));
    }
    
    return enrichedGames;
  }
}
