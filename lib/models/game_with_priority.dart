import 'game.dart';

class GameWithPriority {
  final Game game;
  final double priorityScore; // 0-100 normalized score
  final Map<String, double> factorScores; // Individual factor contributions

  GameWithPriority({
    required this.game,
    required this.priorityScore,
    required this.factorScores,
  });

  // Get rank display (1st, 2nd, 3rd, etc.)
  String getRankDisplay(int rank) {
    if (rank == 1) return '1st';
    if (rank == 2) return '2nd';
    if (rank == 3) return '3rd';
    return '${rank}th';
  }

  // Get priority tier based on score
  PriorityTier get tier {
    if (priorityScore >= 80) return PriorityTier.mustPlay;
    if (priorityScore >= 60) return PriorityTier.highPriority;
    if (priorityScore >= 40) return PriorityTier.medium;
    if (priorityScore >= 20) return PriorityTier.low;
    return PriorityTier.backlog;
  }
}

enum PriorityTier {
  mustPlay,
  highPriority,
  medium,
  low,
  backlog,
}

extension PriorityTierExtension on PriorityTier {
  String get displayName {
    switch (this) {
      case PriorityTier.mustPlay:
        return 'Must Play';
      case PriorityTier.highPriority:
        return 'High Priority';
      case PriorityTier.medium:
        return 'Medium';
      case PriorityTier.low:
        return 'Low Priority';
      case PriorityTier.backlog:
        return 'Backlog';
    }
  }

  String get emoji {
    switch (this) {
      case PriorityTier.mustPlay:
        return '🔥';
      case PriorityTier.highPriority:
        return '⭐';
      case PriorityTier.medium:
        return '📋';
      case PriorityTier.low:
        return '📦';
      case PriorityTier.backlog:
        return '🗄️';
    }
  }
}
