import 'package:flutter/foundation.dart';
import '../models/game.dart';
import '../models/priority_settings.dart';
import '../models/game_with_priority.dart';
import '../services/database_service.dart';
import '../services/backend_api_service.dart';
import '../services/priority_calculator.dart';
import '../services/sync_service.dart';

class GameProvider extends ChangeNotifier {
  final DatabaseService _database;
  final BackendApiService _backendApi;
  late SyncService _syncService;

  List<Game> _games = [];
  List<GameWithPriority> _prioritizedGames = [];
  PrioritySettings _settings = PrioritySettings();
  SyncProgress? _syncProgress;
  bool _isLoading = false;
  String? _error;

  // Filter state
  String _searchQuery = '';
  List<String> _selectedGenres = [];
  PriorityTier? _selectedTier;

  GameProvider(this._database, this._backendApi) {
    _syncService = SyncService(_database, _backendApi);
  }

  // Getters
  List<Game> get games => _games;
  List<GameWithPriority> get prioritizedGames => _getFilteredGames();
  PrioritySettings get settings => _settings;
  SyncProgress? get syncProgress => _syncProgress;
  bool get isLoading => _isLoading;
  bool get isSyncing => _syncProgress != null && 
      _syncProgress!.status != SyncStatus.completed && 
      _syncProgress!.status != SyncStatus.error &&
      _syncProgress!.status != SyncStatus.idle;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  List<String> get selectedGenres => _selectedGenres;
  PriorityTier? get selectedTier => _selectedTier;
  List<String> get allGenres => _database.getAllGenres();
  BackendApiService get backendApi => _backendApi;

  /// Initialize provider
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _database.initialize();
      await _syncService.initialize();
      _games = _database.getAllGames();
      _settings = _database.getSettings();
      _recalculatePriorities();
      _error = null;
    } catch (e) {
      _error = 'Failed to initialize: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Recalculate priorities
  void _recalculatePriorities() {
    final calculator = PriorityCalculator(_settings);
    _prioritizedGames = calculator.calculatePriorities(_games);
  }

  /// Get filtered games based on current filters
  List<GameWithPriority> _getFilteredGames() {
    var filtered = _prioritizedGames;

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((g) =>
          g.game.name.toLowerCase().contains(query)
      ).toList();
    }

    // Genre filter
    if (_selectedGenres.isNotEmpty) {
      filtered = filtered.where((g) =>
          g.game.genres.any((genre) => _selectedGenres.contains(genre))
      ).toList();
    }

    // Tier filter
    if (_selectedTier != null) {
      filtered = filtered.where((g) => g.tier == _selectedTier).toList();
    }

    return filtered;
  }

  /// Update search query
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Update genre filter
  void setSelectedGenres(List<String> genres) {
    _selectedGenres = genres;
    notifyListeners();
  }

  /// Toggle genre filter
  void toggleGenre(String genre) {
    if (_selectedGenres.contains(genre)) {
      _selectedGenres.remove(genre);
    } else {
      _selectedGenres.add(genre);
    }
    notifyListeners();
  }

  /// Update tier filter
  void setSelectedTier(PriorityTier? tier) {
    _selectedTier = tier;
    notifyListeners();
  }

  /// Clear all filters
  void clearFilters() {
    _searchQuery = '';
    _selectedGenres = [];
    _selectedTier = null;
    notifyListeners();
  }

  /// Check if user is authenticated with Steam
  Future<bool> isAuthenticated() async {
    return await _backendApi.isAuthenticated();
  }

  /// Get current Steam ID
  Future<String?> getSteamId() async {
    return await _backendApi.getSteamId();
  }

  /// Full sync from Steam
  Future<void> fullSync() async {
    // Check authentication
    if (!await _backendApi.isAuthenticated()) {
      _error = 'Please sign in with Steam';
      notifyListeners();
      return;
    }

    await for (final progress in _syncService.fullSync()) {
      _syncProgress = progress;

      if (progress.status == SyncStatus.completed) {
        _games = _database.getAllGames();
        _recalculatePriorities();
        _error = null;
      } else if (progress.status == SyncStatus.error) {
        _error = progress.error;
      }

      notifyListeners();
    }

    // Reset sync progress after a delay
    await Future.delayed(const Duration(seconds: 2));
    _syncProgress = SyncProgress(status: SyncStatus.idle);
    notifyListeners();
  }

  /// Quick sync (playtime only)
  Future<void> quickSync() async {
    if (!await _backendApi.isAuthenticated()) {
      _error = 'Please sign in with Steam';
      notifyListeners();
      return;
    }

    await for (final progress in _syncService.quickSync()) {
      _syncProgress = progress;

      if (progress.status == SyncStatus.completed) {
        _games = _database.getAllGames();
        _recalculatePriorities();
      } else if (progress.status == SyncStatus.error) {
        _error = progress.error;
      }

      notifyListeners();
    }

    await Future.delayed(const Duration(seconds: 2));
    _syncProgress = SyncProgress(status: SyncStatus.idle);
    notifyListeners();
  }

  /// Refresh HLTB data
  Future<void> refreshHltb() async {
    await for (final progress in _syncService.refreshHltb()) {
      _syncProgress = progress;
      
      if (progress.status == SyncStatus.completed) {
        _games = _database.getAllGames();
        _recalculatePriorities();
      }
      
      notifyListeners();
    }

    await Future.delayed(const Duration(seconds: 2));
    _syncProgress = SyncProgress(status: SyncStatus.idle);
    notifyListeners();
  }

  /// Update settings
  Future<void> updateSettings(PrioritySettings newSettings) async {
    _settings = newSettings;
    await _database.saveSettings(newSettings);
    _recalculatePriorities();
    notifyListeners();
  }

  /// Update a single game
  Future<void> updateGame(Game game) async {
    await _database.saveGame(game);
    _games = _database.getAllGames();
    _recalculatePriorities();
    notifyListeners();
  }

  /// Toggle game completed status
  Future<void> toggleCompleted(String gameId) async {
    final game = _database.getGame(gameId);
    if (game != null) {
      await updateGame(game.copyWith(isCompleted: !game.isCompleted));
    }
  }

  /// Toggle game hidden status
  Future<void> toggleHidden(String gameId) async {
    final game = _database.getGame(gameId);
    if (game != null) {
      await updateGame(game.copyWith(isHidden: !game.isHidden));
    }
  }

  /// Update game progress
  Future<void> setGameProgress(String gameId, double progress) async {
    final game = _database.getGame(gameId);
    if (game != null) {
      await updateGame(game.copyWith(userProgress: progress));
    }
  }

  /// Delete a game
  Future<void> deleteGame(String gameId) async {
    await _database.deleteGame(gameId);
    _games = _database.getAllGames();
    _recalculatePriorities();
    notifyListeners();
  }

  /// Clear all data
  Future<void> clearAllData() async {
    await _database.clearAllGames();
    _games = [];
    _prioritizedGames = [];
    notifyListeners();
  }

  /// Get statistics
  Map<String, dynamic> getStatistics() {
    final completed = _games.where((g) => g.isCompleted).length;
    final totalPlaytime = _games.fold<int>(0, (sum, g) => sum + g.playtimeMinutes);
    final withHltb = _games.where((g) => g.hltbMainHours != null).length;
    final avgRating = _games.isNotEmpty
        ? _games.fold<double>(0, (sum, g) => sum + g.steamRating) / _games.length
        : 0.0;

    return {
      'totalGames': _games.length,
      'completedGames': completed,
      'totalPlaytimeHours': totalPlaytime / 60,
      'gamesWithHltb': withHltb,
      'averageRating': avgRating,
      'tierCounts': {
        for (var tier in PriorityTier.values)
          tier: _prioritizedGames.where((g) => g.tier == tier).length,
      },
    };
  }
}
