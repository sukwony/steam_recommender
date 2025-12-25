import 'package:flutter/material.dart';
import '../models/game_with_priority.dart';
import '../utils/app_theme.dart';

class GameCard extends StatelessWidget {
  final GameWithPriority gameWithPriority;
  final int rank;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const GameCard({
    super.key,
    required this.gameWithPriority,
    required this.rank,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final tierColor = AppTheme.getTierColor(gameWithPriority.tier);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: AppTheme.cardGradient,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Rank badge
                _buildRankBadge(tierColor),
                const SizedBox(width: 12),
                
                // Game image
                _buildGameImage(),
                const SizedBox(width: 12),
                
                // Game info
                Expanded(
                  child: _buildGameInfo(context),
                ),
                
                // Priority score
                _buildPriorityScore(tierColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRankBadge(Color tierColor) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: tierColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tierColor, width: 2),
      ),
      child: Center(
        child: Text(
          '#$rank',
          style: TextStyle(
            color: tierColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildGameImage() {
    final game = gameWithPriority.game;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 80,
        height: 45,
        color: AppTheme.cardColor,
        child: game.headerImageUrl != null
            ? Image.network(
                game.headerImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _buildPlaceholder(),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildPlaceholder();
                },
              )
            : _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppTheme.cardColor,
      child: const Icon(
        Icons.videogame_asset,
        color: AppTheme.textMuted,
        size: 24,
      ),
    );
  }

  Widget _buildGameInfo(BuildContext context) {
    final game = gameWithPriority.game;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Game name
        Text(
          game.name,
          style: Theme.of(context).textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        
        // Stats row
        Row(
          children: [
            // Steam rating
            _buildStatChip(
              Icons.thumb_up_outlined,
              '${game.steamRating.toStringAsFixed(0)}%',
              AppTheme.secondaryColor,
            ),
            const SizedBox(width: 8),
            
            // HLTB time
            if (game.hltbMainHours != null)
              _buildStatChip(
                Icons.timer_outlined,
                '${game.hltbMainHours!.toStringAsFixed(0)}h',
                AppTheme.accentColor,
              ),
            
            // Playtime
            if (game.playtimeMinutes > 0) ...[
              const SizedBox(width: 8),
              _buildStatChip(
                Icons.play_arrow,
                '${game.playtimeHours.toStringAsFixed(0)}h',
                AppTheme.textMuted,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildStatChip(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityScore(Color tierColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            tierColor.withValues(alpha: 0.3),
            tierColor.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            gameWithPriority.priorityScore.toStringAsFixed(0),
            style: TextStyle(
              color: tierColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'pts',
            style: TextStyle(
              color: tierColor.withValues(alpha: 0.7),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
