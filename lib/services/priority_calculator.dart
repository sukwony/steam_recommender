import '../models/game.dart';
import '../models/priority_settings.dart';
import '../models/game_with_priority.dart';

class PriorityCalculator {
  final PrioritySettings settings;

  PriorityCalculator(this.settings);

  List<GameWithPriority> calculatePriorities(List<Game> games) {
    // Filter games based on settings
    var filteredGames = games.where((game) {
      if (!settings.showCompletedGames && game.isCompleted) return false;
      if (!settings.showHiddenGames && game.isHidden) return false;
      if (!settings.includeNoHltbGames && game.hltbMainHours == null) return false;
      return true;
    }).toList();

    if (filteredGames.isEmpty) return [];

    // Calculate min/max values for normalization
    final stats = _calculateStats(filteredGames);

    // Calculate priority for each game
    final prioritizedGames = filteredGames.map((game) {
      final factorScores = _calculateFactorScores(game, stats);
      final priorityScore = _calculateTotalScore(factorScores);
      return GameWithPriority(
        game: game,
        priorityScore: priorityScore,
        factorScores: factorScores,
      );
    }).toList();

    // Sort by priority score (descending)
    prioritizedGames.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));

    return prioritizedGames;
  }

  _GameStats _calculateStats(List<Game> games) {
    double minRating = 100, maxRating = 0;
    double minHltb = double.infinity, maxHltb = 0;
    int minDaysSince = 0, maxDaysSince = 0;
    double minProgress = 0, maxProgress = 100;
    double minMetacritic = 100, maxMetacritic = 0;

    for (final game in games) {
      // Steam rating
      if (game.steamRating < minRating) minRating = game.steamRating;
      if (game.steamRating > maxRating) maxRating = game.steamRating;

      // HLTB time
      final hltbHours = _getHltbHours(game);
      if (hltbHours != null) {
        if (hltbHours < minHltb) minHltb = hltbHours;
        if (hltbHours > maxHltb) maxHltb = hltbHours;
      }

      // Days since last played
      final days = game.daysSinceLastPlayed;
      if (days < 9999) {
        if (days > maxDaysSince) maxDaysSince = days;
      }

      // Metacritic
      if (game.metacriticScore != null) {
        if (game.metacriticScore! < minMetacritic) minMetacritic = game.metacriticScore!;
        if (game.metacriticScore! > maxMetacritic) maxMetacritic = game.metacriticScore!;
      }
    }

    return _GameStats(
      minRating: minRating,
      maxRating: maxRating,
      minHltb: minHltb == double.infinity ? 0 : minHltb,
      maxHltb: maxHltb,
      minDaysSince: minDaysSince,
      maxDaysSince: maxDaysSince,
      minProgress: minProgress,
      maxProgress: maxProgress,
      minMetacritic: minMetacritic,
      maxMetacritic: maxMetacritic,
    );
  }

  double? _getHltbHours(Game game) {
    switch (settings.hltbType) {
      case 0:
        return game.hltbMainHours;
      case 1:
        return game.hltbExtraHours ?? game.hltbMainHours;
      case 2:
        return game.hltbCompletionistHours ?? game.hltbExtraHours ?? game.hltbMainHours;
      default:
        return game.hltbMainHours;
    }
  }

  Map<String, double> _calculateFactorScores(Game game, _GameStats stats) {
    final scores = <String, double>{};

    // Steam Rating Score (higher = better) - 0 to 100
    scores['steamRating'] = _normalize(
      game.steamRating,
      stats.minRating,
      stats.maxRating,
    );

    // HLTB Time Score (lower time = higher score) - 0 to 100
    final hltbHours = _getHltbHours(game);
    if (hltbHours != null && stats.maxHltb > stats.minHltb) {
      // Invert: shorter games get higher scores
      final normalizedTime = _normalize(hltbHours, stats.minHltb, stats.maxHltb);
      scores['hltbTime'] = 100 - normalizedTime;
      
      // Apply penalty for games exceeding max hours preference
      if (hltbHours > settings.maxHltbHours) {
        scores['hltbTime'] = scores['hltbTime']! * 0.5;
      }
    } else {
      scores['hltbTime'] = 50; // Default for unknown HLTB
    }

    // Last Played Score (longer ago = higher) - 0 to 100
    final days = game.daysSinceLastPlayed;
    if (days < 9999 && stats.maxDaysSince > 0) {
      scores['lastPlayed'] = _normalize(
        days.toDouble(),
        stats.minDaysSince.toDouble(),
        stats.maxDaysSince.toDouble(),
      );
    } else {
      scores['lastPlayed'] = 100; // Never played = highest priority
    }

    // Progress Score (started games = higher) - 0 to 100
    final progress = game.userProgress ?? game.estimatedProgress ?? 0;
    if (progress > 0 && progress < 100) {
      // Games in progress get bonus (50-100 based on how far along)
      scores['progress'] = 50 + (progress / 2);
    } else if (progress >= 100) {
      scores['progress'] = 0; // Completed games get lowest
    } else {
      scores['progress'] = 50; // Not started = neutral
    }

    // Metacritic Score (higher = better) - 0 to 100
    if (game.metacriticScore != null) {
      scores['metacritic'] = _normalize(
        game.metacriticScore!,
        stats.minMetacritic,
        stats.maxMetacritic,
      );
    } else {
      scores['metacritic'] = 50; // Default for unknown
    }

    // Genre Preference Score - 0 to 100
    if (settings.preferredGenres.isEmpty) {
      scores['genre'] = 50; // Neutral if no preferences
    } else {
      final matchingGenres = game.genres
          .where((g) => settings.preferredGenres.contains(g))
          .length;
      if (matchingGenres > 0) {
        scores['genre'] = 50 + (50 * matchingGenres / settings.preferredGenres.length);
      } else {
        scores['genre'] = 25; // Lower score for non-preferred genres
      }
    }

    return scores;
  }

  double _calculateTotalScore(Map<String, double> factorScores) {
    return factorScores['steamRating']! * settings.steamRatingWeight +
           factorScores['hltbTime']! * settings.hltbTimeWeight +
           factorScores['lastPlayed']! * settings.lastPlayedWeight +
           factorScores['progress']! * settings.progressWeight +
           factorScores['metacritic']! * settings.metacriticWeight +
           factorScores['genre']! * settings.genreWeight;
  }

  double _normalize(double value, double min, double max) {
    if (max == min) return 50;
    return ((value - min) / (max - min) * 100).clamp(0, 100);
  }
}

class _GameStats {
  final double minRating, maxRating;
  final double minHltb, maxHltb;
  final int minDaysSince, maxDaysSince;
  final double minProgress, maxProgress;
  final double minMetacritic, maxMetacritic;

  _GameStats({
    required this.minRating,
    required this.maxRating,
    required this.minHltb,
    required this.maxHltb,
    required this.minDaysSince,
    required this.maxDaysSince,
    required this.minProgress,
    required this.maxProgress,
    required this.minMetacritic,
    required this.maxMetacritic,
  });
}
