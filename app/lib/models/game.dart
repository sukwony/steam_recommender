import 'package:hive/hive.dart';

part 'game.g.dart';

@HiveType(typeId: 0)
class Game extends HiveObject {
  @HiveField(0)
  String id; // Steam App ID

  @HiveField(1)
  String name;

  @HiveField(2)
  String? headerImageUrl;

  @HiveField(3)
  double steamRating; // 0-100 percentage positive reviews

  @HiveField(4)
  int steamReviewCount;

  @HiveField(5)
  double? metacriticScore; // 0-100

  @HiveField(6)
  double? hltbMainHours; // Main story completion time

  @HiveField(7)
  double? hltbExtraHours; // Main + extras

  @HiveField(8)
  double? hltbCompletionistHours; // 100% completion

  @HiveField(9)
  int playtimeMinutes; // Total playtime in Steam

  @HiveField(10)
  DateTime? lastPlayed;

  @HiveField(11)
  List<String> genres;

  @HiveField(12)
  bool isCompleted;

  @HiveField(13)
  double? userProgress; // 0-100 user-defined progress

  @HiveField(14)
  DateTime addedAt;

  @HiveField(15)
  DateTime? lastSynced;

  @HiveField(16)
  bool isHidden;

  @HiveField(17)
  String? notes;

  @HiveField(18)
  String? hltbId; // HLTB game ID for direct lookups

  Game({
    required this.id,
    required this.name,
    this.headerImageUrl,
    this.steamRating = 0,
    this.steamReviewCount = 0,
    this.metacriticScore,
    this.hltbMainHours,
    this.hltbExtraHours,
    this.hltbCompletionistHours,
    this.playtimeMinutes = 0,
    this.lastPlayed,
    this.genres = const [],
    this.isCompleted = false,
    this.userProgress,
    DateTime? addedAt,
    this.lastSynced,
    this.isHidden = false,
    this.notes,
    this.hltbId,
  }) : addedAt = addedAt ?? DateTime.now();

  // Calculate days since last played
  int get daysSinceLastPlayed {
    if (lastPlayed == null) return 9999;
    return DateTime.now().difference(lastPlayed!).inDays;
  }

  // Get playtime in hours
  double get playtimeHours => playtimeMinutes / 60.0;

  // Estimated completion percentage based on HLTB
  double? get estimatedProgress {
    if (hltbMainHours == null || hltbMainHours == 0) return null;
    final progress = (playtimeHours / hltbMainHours!) * 100;
    return progress.clamp(0, 100);
  }

  // Copy with method for updates
  Game copyWith({
    String? id,
    String? name,
    String? headerImageUrl,
    double? steamRating,
    int? steamReviewCount,
    double? metacriticScore,
    double? hltbMainHours,
    double? hltbExtraHours,
    double? hltbCompletionistHours,
    int? playtimeMinutes,
    DateTime? lastPlayed,
    List<String>? genres,
    bool? isCompleted,
    double? userProgress,
    DateTime? addedAt,
    DateTime? lastSynced,
    bool? isHidden,
    String? notes,
    String? hltbId,
  }) {
    return Game(
      id: id ?? this.id,
      name: name ?? this.name,
      headerImageUrl: headerImageUrl ?? this.headerImageUrl,
      steamRating: steamRating ?? this.steamRating,
      steamReviewCount: steamReviewCount ?? this.steamReviewCount,
      metacriticScore: metacriticScore ?? this.metacriticScore,
      hltbMainHours: hltbMainHours ?? this.hltbMainHours,
      hltbExtraHours: hltbExtraHours ?? this.hltbExtraHours,
      hltbCompletionistHours: hltbCompletionistHours ?? this.hltbCompletionistHours,
      playtimeMinutes: playtimeMinutes ?? this.playtimeMinutes,
      lastPlayed: lastPlayed ?? this.lastPlayed,
      genres: genres ?? this.genres,
      isCompleted: isCompleted ?? this.isCompleted,
      userProgress: userProgress ?? this.userProgress,
      addedAt: addedAt ?? this.addedAt,
      lastSynced: lastSynced ?? this.lastSynced,
      isHidden: isHidden ?? this.isHidden,
      notes: notes ?? this.notes,
      hltbId: hltbId ?? this.hltbId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'headerImageUrl': headerImageUrl,
    'steamRating': steamRating,
    'steamReviewCount': steamReviewCount,
    'metacriticScore': metacriticScore,
    'hltbMainHours': hltbMainHours,
    'hltbExtraHours': hltbExtraHours,
    'hltbCompletionistHours': hltbCompletionistHours,
    'playtimeMinutes': playtimeMinutes,
    'lastPlayed': lastPlayed?.toIso8601String(),
    'genres': genres,
    'isCompleted': isCompleted,
    'userProgress': userProgress,
    'addedAt': addedAt.toIso8601String(),
    'lastSynced': lastSynced?.toIso8601String(),
    'isHidden': isHidden,
    'notes': notes,
    'hltbId': hltbId,
  };

  factory Game.fromJson(Map<String, dynamic> json) => Game(
    id: json['id'] as String,
    name: json['name'] as String,
    headerImageUrl: json['headerImageUrl'] as String?,
    steamRating: (json['steamRating'] as num?)?.toDouble() ?? 0,
    steamReviewCount: json['steamReviewCount'] as int? ?? 0,
    metacriticScore: (json['metacriticScore'] as num?)?.toDouble(),
    hltbMainHours: (json['hltbMainHours'] as num?)?.toDouble(),
    hltbExtraHours: (json['hltbExtraHours'] as num?)?.toDouble(),
    hltbCompletionistHours: (json['hltbCompletionistHours'] as num?)?.toDouble(),
    playtimeMinutes: json['playtimeMinutes'] as int? ?? 0,
    lastPlayed: json['lastPlayed'] != null ? DateTime.parse(json['lastPlayed'] as String) : null,
    genres: (json['genres'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
    isCompleted: json['isCompleted'] as bool? ?? false,
    userProgress: (json['userProgress'] as num?)?.toDouble(),
    addedAt: json['addedAt'] != null ? DateTime.parse(json['addedAt'] as String) : DateTime.now(),
    lastSynced: json['lastSynced'] != null ? DateTime.parse(json['lastSynced'] as String) : null,
    isHidden: json['isHidden'] as bool? ?? false,
    notes: json['notes'] as String?,
    hltbId: json['hltbId'] as String?,
  );
}
