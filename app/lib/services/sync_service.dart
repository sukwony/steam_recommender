import 'package:flutter/foundation.dart';
import '../models/game.dart';
import 'database_service.dart';
import 'backend_api_service.dart';
import 'hltb_service.dart';

enum SyncStatus {
  idle,
  fetchingLibrary,
  enrichingSteam,
  enrichingHltb,
  saving,
  completed,
  error,
}

class SyncProgress {
  final SyncStatus status;
  final int current;
  final int total;
  final String? message;
  final String? error;

  SyncProgress({
    required this.status,
    this.current = 0,
    this.total = 0,
    this.message,
    this.error,
  });

  double get progress {
    if (total == 0) return 0;
    return current / total;
  }
}

class SyncService {
  final DatabaseService _database;
  final BackendApiService _backendApi;
  final HltbService _hltbService;

  SyncService(this._database, this._backendApi)
      : _hltbService = HltbService();

  /// Full sync: fetch library and enrich with all data
  Stream<SyncProgress> fullSync() async* {
    // Check authentication
    if (!await _backendApi.isAuthenticated()) {
      yield SyncProgress(
        status: SyncStatus.error,
        error: 'Please sign in with Steam',
      );
      return;
    }

    try {
      // Step 1: Fetch Steam library from backend
      yield SyncProgress(
        status: SyncStatus.fetchingLibrary,
        message: 'Fetching Steam library...',
      );

      List<Game> games;
      try {
        final response = await _backendApi.fetchOwnedGames();
        games = _parseGamesFromBackend(response);
      } catch (e) {
        yield SyncProgress(
          status: SyncStatus.error,
          error: 'Failed to fetch Steam library: $e',
        );
        return;
      }

      if (games.isEmpty) {
        yield SyncProgress(
          status: SyncStatus.error,
          error: 'No games found in library. Make sure your profile is public.',
        );
        return;
      }

      // Merge with existing games (preserve user data)
      final existingGames = {for (var g in _database.getAllGames()) g.id: g};
      games = games.map((newGame) {
        final existing = existingGames[newGame.id];
        if (existing != null) {
          return newGame.copyWith(
            isCompleted: existing.isCompleted,
            userProgress: existing.userProgress,
            isHidden: existing.isHidden,
            notes: existing.notes,
            hltbMainHours: existing.hltbMainHours,
            hltbExtraHours: existing.hltbExtraHours,
            hltbCompletionistHours: existing.hltbCompletionistHours,
            steamRating: existing.steamRating > 0 ? existing.steamRating : null,
            metacriticScore: existing.metacriticScore,
            genres: existing.genres.isNotEmpty ? existing.genres : null,
          );
        }
        return newGame;
      }).toList();

      // Step 2: Enrich with Steam details (ratings, metacritic, genres)
      yield SyncProgress(
        status: SyncStatus.enrichingSteam,
        current: 0,
        total: games.length,
        message: 'Fetching game details...',
      );

      for (int i = 0; i < games.length; i++) {
        final game = games[i];

        // Only enrich if missing data
        if (game.steamRating == 0 || game.genres.isEmpty) {
          try {
            games[i] = await _enrichGameWithBackend(game);
          } catch (e) {
            // Continue on error for individual games
          }
        }

        yield SyncProgress(
          status: SyncStatus.enrichingSteam,
          current: i + 1,
          total: games.length,
          message: 'Fetching details: ${game.name}',
        );

        // Rate limiting
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Step 3: Enrich with HLTB data
      yield SyncProgress(
        status: SyncStatus.enrichingHltb,
        current: 0,
        total: games.length,
        message: 'Fetching completion times...',
      );

      int hltbSuccessCount = 0;
      int hltbFailCount = 0;

      for (int i = 0; i < games.length; i++) {
        final game = games[i];

        // Only enrich if missing HLTB data
        if (game.hltbMainHours == null) {
          debugPrint('[SYNC] 🎮 Fetching HLTB for: ${game.name} (${i + 1}/${games.length})');
          try {
            final enriched = await _hltbService.enrichWithHltbData(game);
            games[i] = enriched;

            if (enriched.hltbMainHours != null) {
              hltbSuccessCount++;
              debugPrint('[SYNC] ✅ HLTB success: ${game.name} -> ${enriched.hltbMainHours}h');
            } else {
              hltbFailCount++;
              debugPrint('[SYNC] ⚠️  HLTB no data found: ${game.name}');
            }
          } catch (e) {
            hltbFailCount++;
            debugPrint('[SYNC] ❌ HLTB error for ${game.name}: $e');
          }
        } else {
          debugPrint('[SYNC] ⏭️  Skipping ${game.name} - already has HLTB data (${game.hltbMainHours}h)');
        }

        yield SyncProgress(
          status: SyncStatus.enrichingHltb,
          current: i + 1,
          total: games.length,
          message: 'Fetching HLTB: ${game.name}',
        );

        // Rate limiting for HLTB WebView scraping (increased to avoid detection)
        // 1.5-2.5s with random jitter to mimic human behavior
        await Future.delayed(Duration(milliseconds: 1500 + (DateTime.now().millisecond % 1000)));
      }

      debugPrint('[SYNC] 📊 HLTB Summary - Success: $hltbSuccessCount, Failed: $hltbFailCount, Total: ${games.length}');

      // Step 4: Save to database
      yield SyncProgress(
        status: SyncStatus.saving,
        message: 'Saving games...',
      );

      await _database.saveGames(games);

      yield SyncProgress(
        status: SyncStatus.completed,
        current: games.length,
        total: games.length,
        message: 'Synced ${games.length} games',
      );
    } catch (e) {
      yield SyncProgress(
        status: SyncStatus.error,
        error: 'Sync failed: $e',
      );
    }
  }

  /// Quick sync: only update playtime and last played
  Stream<SyncProgress> quickSync() async* {
    if (!await _backendApi.isAuthenticated()) {
      yield SyncProgress(
        status: SyncStatus.error,
        error: 'Please sign in with Steam',
      );
      return;
    }

    try {
      yield SyncProgress(
        status: SyncStatus.fetchingLibrary,
        message: 'Fetching playtime data...',
      );

      final response = await _backendApi.fetchOwnedGames();
      final freshGames = _parseGamesFromBackend(response);

      final existingGames = _database.getAllGames();
      final updates = <Game>[];

      for (final fresh in freshGames) {
        final existing = existingGames.firstWhere(
          (e) => e.id == fresh.id,
          orElse: () => fresh,
        );

        updates.add(existing.copyWith(
          playtimeMinutes: fresh.playtimeMinutes,
          lastPlayed: fresh.lastPlayed,
          lastSynced: DateTime.now(),
        ));
      }

      yield SyncProgress(
        status: SyncStatus.saving,
        message: 'Updating ${updates.length} games...',
      );

      await _database.saveGames(updates);

      yield SyncProgress(
        status: SyncStatus.completed,
        message: 'Updated playtime for ${updates.length} games',
      );
    } catch (e) {
      yield SyncProgress(
        status: SyncStatus.error,
        error: 'Quick sync failed: $e',
      );
    }
  }

  /// Refresh HLTB data for games missing it
  Stream<SyncProgress> refreshHltb() async* {
    final games = _database.getAllGames()
        .where((g) => g.hltbMainHours == null)
        .toList();

    if (games.isEmpty) {
      yield SyncProgress(
        status: SyncStatus.completed,
        message: 'All games have HLTB data',
      );
      return;
    }

    yield SyncProgress(
      status: SyncStatus.enrichingHltb,
      current: 0,
      total: games.length,
      message: 'Fetching HLTB data...',
    );

    for (int i = 0; i < games.length; i++) {
      final game = games[i];
      final enriched = await _hltbService.enrichWithHltbData(game);
      await _database.saveGame(enriched);

      yield SyncProgress(
        status: SyncStatus.enrichingHltb,
        current: i + 1,
        total: games.length,
        message: 'Fetching: ${game.name}',
      );

      // Rate limiting for HLTB WebView scraping
      await Future.delayed(Duration(milliseconds: 1500 + (DateTime.now().millisecond % 1000)));
    }

    yield SyncProgress(
      status: SyncStatus.completed,
      message: 'Updated HLTB for ${games.length} games',
    );
  }

  /// Parse games from backend API response
  List<Game> _parseGamesFromBackend(Map<String, dynamic> response) {
    final gamesData = response['response']?['games'] as List<dynamic>?;
    if (gamesData == null) return [];

    return gamesData.map((gameJson) {
      final appId = gameJson['appid'].toString();
      final name = gameJson['name'] as String? ?? 'Unknown';
      final playtimeMinutes = gameJson['playtime_forever'] as int? ?? 0;
      final lastPlayedTimestamp = gameJson['rtime_last_played'] as int? ?? 0;

      final headerImage = gameJson['img_icon_url'] != null
          ? 'https://steamcdn-a.akamaihd.net/steamcommunity/public/images/apps/$appId/${gameJson['img_icon_url']}.jpg'
          : null;

      return Game(
        id: appId,
        name: name,
        playtimeMinutes: playtimeMinutes,
        lastPlayed: lastPlayedTimestamp > 0
            ? DateTime.fromMillisecondsSinceEpoch(lastPlayedTimestamp * 1000)
            : null,
        headerImageUrl: headerImage,
        lastSynced: DateTime.now(),
      );
    }).toList();
  }

  /// Enrich game with Steam data from backend
  Future<Game> _enrichGameWithBackend(Game game) async {
    final details = await _backendApi.fetchGameDetails(game.id);
    final reviews = await _backendApi.fetchGameReviews(game.id);

    double steamRating = game.steamRating;
    int reviewCount = game.steamReviewCount;
    double? metacritic = game.metacriticScore;
    List<String> genres = game.genres;

    // Parse reviews
    if (reviews['success'] == 1) {
      final summary = reviews['query_summary'];
      final total = summary['total_reviews'] as int? ?? 0;
      final positive = summary['total_positive'] as int? ?? 0;
      if (total > 0) {
        steamRating = (positive / total * 100);
        reviewCount = total;
      }
    }

    // Parse details
    final gameData = details[game.id];
    if (gameData != null && gameData['success'] == true) {
      final data = gameData['data'];
      if (data != null) {
        if (data['metacritic'] != null) {
          metacritic = (data['metacritic']['score'] as num?)?.toDouble();
        }
        if (data['genres'] != null) {
          genres = (data['genres'] as List<dynamic>)
              .map((g) => g['description'] as String)
              .toList();
        }
      }
    }

    return game.copyWith(
      steamRating: steamRating,
      steamReviewCount: reviewCount,
      metacriticScore: metacritic,
      genres: genres,
    );
  }
}
