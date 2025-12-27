import 'package:hive_flutter/hive_flutter.dart';
import '../models/game.dart';
import '../models/priority_settings.dart';
import '../models/wikidata_mapping.dart';

class DatabaseService {
  static const String _gamesBoxName = 'games';
  static const String _settingsBoxName = 'settings';
  static const String _settingsKey = 'priority_settings';

  late Box<Game> _gamesBox;
  late Box<PrioritySettings> _settingsBox;

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    await Hive.initFlutter();
    
    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(GameAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(PrioritySettingsAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(WikidataMappingAdapter());
    }

    // Open boxes
    _gamesBox = await Hive.openBox<Game>(_gamesBoxName);
    _settingsBox = await Hive.openBox<PrioritySettings>(_settingsBoxName);

    _isInitialized = true;
  }

  // Games CRUD operations
  List<Game> getAllGames() {
    return _gamesBox.values.toList();
  }

  Game? getGame(String id) {
    return _gamesBox.get(id);
  }

  Future<void> saveGame(Game game) async {
    await _gamesBox.put(game.id, game);
  }

  Future<void> saveGames(List<Game> games) async {
    final Map<String, Game> gamesMap = {
      for (var game in games) game.id: game
    };
    await _gamesBox.putAll(gamesMap);
  }

  Future<void> deleteGame(String id) async {
    await _gamesBox.delete(id);
  }

  Future<void> clearAllGames() async {
    await _gamesBox.clear();
  }

  // Settings operations
  PrioritySettings getSettings() {
    return _settingsBox.get(_settingsKey) ?? PrioritySettings();
  }

  Future<void> saveSettings(PrioritySettings settings) async {
    await _settingsBox.put(_settingsKey, settings);
  }

  // Utility methods
  int get gamesCount => _gamesBox.length;

  Stream<BoxEvent> watchGames() {
    return _gamesBox.watch();
  }

  Stream<BoxEvent> watchSettings() {
    return _settingsBox.watch(key: _settingsKey);
  }

  // Get all unique genres from games
  List<String> getAllGenres() {
    final genres = <String>{};
    for (final game in _gamesBox.values) {
      genres.addAll(game.genres);
    }
    return genres.toList()..sort();
  }

  // Close boxes
  Future<void> close() async {
    await _gamesBox.close();
    await _settingsBox.close();
  }
}
