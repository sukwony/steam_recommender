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

  /// Initialize HLTB service (must be called before first use)
  Future<void> initialize() async {
    await _hltbService.initialize();
  }

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

      // Step 2: Parallel enrichment with safe merge
      yield SyncProgress(
        status: SyncStatus.enrichingSteam,
        current: 0,
        total: games.length * 2,  // Steam + HLTB operations
        message: 'Enriching games (parallel)...',
      );

      // Create separate lists for parallel processing
      final steamList = List<Game>.from(games);
      final hltbList = List<Game>.from(games);

      debugPrint('[SYNC] 🚀 Starting parallel enrichment for ${games.length} games');

      // Track progress
      int steamCompleted = 0;
      int hltbCompleted = 0;
      bool isComplete = false;

      // Start both enrichment processes without awaiting
      final steamFuture = _enrichAllWithSteam(steamList, onProgress: (index, game) {
        steamList[index] = game;
        steamCompleted++;
        if (steamCompleted % 5 == 0 || steamCompleted == games.length) {
          debugPrint('[SYNC] 🎮 Steam progress: $steamCompleted/${games.length}');
        }
      });

      final hltbFuture = _enrichAllWithHltb(hltbList, onProgress: (index, game) {
        hltbList[index] = game;
        hltbCompleted++;
        if (hltbCompleted % 5 == 0 || hltbCompleted == games.length) {
          debugPrint('[SYNC] ⏱️  HLTB progress: $hltbCompleted/${games.length}');
        }
      });

      // Monitor both futures and report progress
      Future.wait([steamFuture, hltbFuture]).then((_) {
        isComplete = true;
      });

      // Report progress periodically while waiting
      while (!isComplete) {
        await Future.delayed(const Duration(milliseconds: 500));
        final totalCompleted = steamCompleted + hltbCompleted;
        yield SyncProgress(
          status: SyncStatus.enrichingSteam,
          current: totalCompleted,
          total: games.length * 2,
          message: 'Steam: $steamCompleted/${games.length} | HLTB: $hltbCompleted/${games.length}',
        );
      }

      // Wait for completion to ensure everything is done
      await Future.wait([steamFuture, hltbFuture]);

      debugPrint('[SYNC] ✅ Parallel enrichment completed - Steam: $steamCompleted, HLTB: $hltbCompleted');

      // Report final completion
      yield SyncProgress(
        status: SyncStatus.enrichingSteam,
        current: games.length * 2,
        total: games.length * 2,
        message: 'Completed - Steam: $steamCompleted/${games.length} | HLTB: $hltbCompleted/${games.length}',
      );

      // Step 3: Merge results (preserve all data)
      for (int i = 0; i < games.length; i++) {
        games[i] = steamList[i].copyWith(
          hltbMainHours: hltbList[i].hltbMainHours,
          hltbExtraHours: hltbList[i].hltbExtraHours,
          hltbCompletionistHours: hltbList[i].hltbCompletionistHours,
          hltbId: hltbList[i].hltbId,
        );
      }

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
  /// Only fetches games that haven't been tried before (hltbId == null)
  /// This prevents re-fetching games that:
  /// - Exist in HLTB but have no time data (hltbId = valid ID)
  /// - Were already attempted but not found (hltbId = "")
  Stream<SyncProgress> refreshHltb() async* {
    final games = _database.getAllGames()
        .where((g) => g.hltbMainHours == null && g.hltbId == null)
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

      try {
        final enriched = await _hltbService.enrichWithHltbData(game);
        await _database.saveGame(enriched);
      } catch (e) {
        // Network error - skip this game and retry next sync
        debugPrint('[SYNC] ❌ HLTB network error for ${game.name}: $e (will retry next sync)');
      }

      yield SyncProgress(
        status: SyncStatus.enrichingHltb,
        current: i + 1,
        total: games.length,
        message: 'Fetching: ${game.name}',
      );

      // Rate limiting for HLTB API calls
      await Future.delayed(const Duration(milliseconds: 500));
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

  /// Enrich all games with Steam data
  /// Runs independently on its own list copy
  Future<void> _enrichAllWithSteam(
    List<Game> games,
    {required void Function(int index, Game game) onProgress}
  ) async {
    for (int i = 0; i < games.length; i++) {
      final game = games[i];

      // Only enrich if missing data
      if (game.steamRating == 0 || game.genres.isEmpty) {
        try {
          final enriched = await _enrichGameWithBackend(game);
          onProgress(i, enriched);
        } catch (e) {
          // Continue on error for individual games
          debugPrint('[SYNC] ❌ Steam enrichment error for ${game.name}: $e');
          onProgress(i, game); // Keep original
        }
      } else {
        onProgress(i, game); // Already enriched
      }

      // Rate limiting (same as original: 200ms)
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  /// Enrich all games with HLTB data
  /// Runs independently on its own list copy
  Future<void> _enrichAllWithHltb(
    List<Game> games,
    {required void Function(int index, Game game) onProgress}
  ) async {
    int hltbSuccessCount = 0;
    int hltbFailCount = 0;

    for (int i = 0; i < games.length; i++) {
      final game = games[i];

      // Only enrich if missing HLTB data
      if (game.hltbMainHours == null) {
        try {
          final enriched = await _hltbService.enrichWithHltbData(game);

          if (enriched.hltbMainHours != null) {
            hltbSuccessCount++;
          } else {
            hltbFailCount++;
          }

          onProgress(i, enriched);
        } catch (e) {
          // Network error or other exception - skip this game and retry next sync
          hltbFailCount++;
          debugPrint('[SYNC] ❌ HLTB network error for ${game.name}: $e (will retry next sync)');
          onProgress(i, game); // Keep original
        }
      } else {
        onProgress(i, game); // Already has HLTB data
      }

      // Rate limiting (same as original: 500ms)
      await Future.delayed(const Duration(milliseconds: 500));
    }

    debugPrint('[SYNC] 📊 HLTB Summary - Success: $hltbSuccessCount, Failed: $hltbFailCount, Total: ${games.length}');
  }
}
