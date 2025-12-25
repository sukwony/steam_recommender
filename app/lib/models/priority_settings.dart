import 'package:hive/hive.dart';

part 'priority_settings.g.dart';

@HiveType(typeId: 1)
class PrioritySettings extends HiveObject {
  // Weight factors (0.0 to 1.0, sum should be 1.0 for pure normalization)
  @HiveField(0)
  double steamRatingWeight;

  @HiveField(1)
  double hltbTimeWeight; // Shorter = higher priority

  @HiveField(2)
  double lastPlayedWeight; // Longer ago = higher priority

  @HiveField(3)
  double progressWeight; // Started games = higher priority

  @HiveField(4)
  double metacriticWeight;

  @HiveField(5)
  double genreWeight; // Preferred genres bonus

  // Preferred genres list
  @HiveField(6)
  List<String> preferredGenres;

  // HLTB completion type preference
  @HiveField(7)
  int hltbType; // 0: Main, 1: Main+Extra, 2: Completionist

  // Max HLTB hours filter (games longer than this get penalty)
  @HiveField(8)
  double maxHltbHours;

  // Whether to include games without HLTB data
  @HiveField(9)
  bool includeNoHltbGames;

  // Whether to show completed games
  @HiveField(10)
  bool showCompletedGames;

  // Whether to show hidden games
  @HiveField(11)
  bool showHiddenGames;

  // Steam ID for API calls
  @HiveField(12)
  String? steamId;

  // Steam API Key
  @HiveField(13)
  String? steamApiKey;

  PrioritySettings({
    this.steamRatingWeight = 0.25,
    this.hltbTimeWeight = 0.25,
    this.lastPlayedWeight = 0.15,
    this.progressWeight = 0.15,
    this.metacriticWeight = 0.10,
    this.genreWeight = 0.10,
    this.preferredGenres = const [],
    this.hltbType = 0,
    this.maxHltbHours = 100,
    this.includeNoHltbGames = true,
    this.showCompletedGames = false,
    this.showHiddenGames = false,
    this.steamId,
    this.steamApiKey,
  });

  // Normalize weights to sum to 1.0
  void normalizeWeights() {
    final total = steamRatingWeight + 
                  hltbTimeWeight + 
                  lastPlayedWeight + 
                  progressWeight + 
                  metacriticWeight + 
                  genreWeight;
    
    if (total > 0) {
      steamRatingWeight /= total;
      hltbTimeWeight /= total;
      lastPlayedWeight /= total;
      progressWeight /= total;
      metacriticWeight /= total;
      genreWeight /= total;
    }
  }

  PrioritySettings copyWith({
    double? steamRatingWeight,
    double? hltbTimeWeight,
    double? lastPlayedWeight,
    double? progressWeight,
    double? metacriticWeight,
    double? genreWeight,
    List<String>? preferredGenres,
    int? hltbType,
    double? maxHltbHours,
    bool? includeNoHltbGames,
    bool? showCompletedGames,
    bool? showHiddenGames,
    String? steamId,
    String? steamApiKey,
  }) {
    return PrioritySettings(
      steamRatingWeight: steamRatingWeight ?? this.steamRatingWeight,
      hltbTimeWeight: hltbTimeWeight ?? this.hltbTimeWeight,
      lastPlayedWeight: lastPlayedWeight ?? this.lastPlayedWeight,
      progressWeight: progressWeight ?? this.progressWeight,
      metacriticWeight: metacriticWeight ?? this.metacriticWeight,
      genreWeight: genreWeight ?? this.genreWeight,
      preferredGenres: preferredGenres ?? this.preferredGenres,
      hltbType: hltbType ?? this.hltbType,
      maxHltbHours: maxHltbHours ?? this.maxHltbHours,
      includeNoHltbGames: includeNoHltbGames ?? this.includeNoHltbGames,
      showCompletedGames: showCompletedGames ?? this.showCompletedGames,
      showHiddenGames: showHiddenGames ?? this.showHiddenGames,
      steamId: steamId ?? this.steamId,
      steamApiKey: steamApiKey ?? this.steamApiKey,
    );
  }
}
