import '../models/game.dart';
import '../models/priority_settings.dart';
import 'database_service.dart';
import 'steam_api_service.dart';
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
  final SteamApiService _steamApi;
  final HltbService _hltbService;

  SyncService(this._database)
      : _steamApi = SteamApiService(),
        _hltbService = HltbService();

  /// Full sync: fetch library and enrich with all data
  Stream<SyncProgress> fullSync(PrioritySettings settings) async* {
    if (settings.steamId == null || settings.steamApiKey == null) {
      yield SyncProgress(
        status: SyncStatus.error,
        error: 'Steam ID and API Key are required',
      );
      return;
    }

    try {
      // Step 1: Fetch Steam library
      yield SyncProgress(
        status: SyncStatus.fetchingLibrary,
        message: 'Fetching Steam library...',
      );

      List<Game> games;
      try {
        games = await _steamApi.fetchOwnedGames(
          settings.steamId!,
          settings.steamApiKey!,
        );
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
            games[i] = await _steamApi.enrichGameData(game);
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

      for (int i = 0; i < games.length; i++) {
        final game = games[i];
        
        // Only enrich if missing HLTB data
        if (game.hltbMainHours == null) {
          try {
            games[i] = await _hltbService.enrichWithHltbData(game);
          } catch (e) {
            // Continue on error
          }
        }

        yield SyncProgress(
          status: SyncStatus.enrichingHltb,
          current: i + 1,
          total: games.length,
          message: 'Fetching HLTB: ${game.name}',
        );

        // Rate limiting for HLTB
        await Future.delayed(const Duration(milliseconds: 300));
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
  Stream<SyncProgress> quickSync(PrioritySettings settings) async* {
    if (settings.steamId == null || settings.steamApiKey == null) {
      yield SyncProgress(
        status: SyncStatus.error,
        error: 'Steam ID and API Key are required',
      );
      return;
    }

    try {
      yield SyncProgress(
        status: SyncStatus.fetchingLibrary,
        message: 'Fetching playtime data...',
      );

      final freshGames = await _steamApi.fetchOwnedGames(
        settings.steamId!,
        settings.steamApiKey!,
      );

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

      await Future.delayed(const Duration(milliseconds: 500));
    }

    yield SyncProgress(
      status: SyncStatus.completed,
      message: 'Updated HLTB for ${games.length} games',
    );
  }
}
