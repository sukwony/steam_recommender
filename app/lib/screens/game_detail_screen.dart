import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/game_with_priority.dart';
import '../providers/game_provider.dart';
import '../utils/app_theme.dart';

class GameDetailScreen extends StatelessWidget {
  final GameWithPriority gameWithPriority;
  final int rank;

  const GameDetailScreen({
    super.key,
    required this.gameWithPriority,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final tierColor = AppTheme.getTierColor(gameWithPriority.tier);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, tierColor),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPrioritySection(tierColor),
                  const SizedBox(height: 24),
                  _buildFactorBreakdown(),
                  const SizedBox(height: 24),
                  _buildStatsSection(),
                  const SizedBox(height: 24),
                  _buildGenresSection(),
                  const SizedBox(height: 24),
                  _buildActionsSection(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, Color tierColor) {
    final game = gameWithPriority.game;
    
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppTheme.backgroundColor,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (game.headerImageUrl != null)
              Image.network(
                game.headerImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: AppTheme.cardColor,
                  child: const Icon(Icons.videogame_asset, size: 64, color: AppTheme.textMuted),
                ),
              )
            else
              Container(
                color: AppTheme.cardColor,
                child: const Icon(Icons.videogame_asset, size: 64, color: AppTheme.textMuted),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: tierColor.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '#$rank ${gameWithPriority.tier.displayName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    game.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrioritySection(Color tierColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            tierColor.withValues(alpha: 0.2),
            tierColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tierColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Priority Score',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    gameWithPriority.priorityScore.toStringAsFixed(1),
                    style: TextStyle(
                      color: tierColor,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8, left: 4),
                    child: Text(
                      '/ 100',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tierColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Text(
              gameWithPriority.tier.emoji,
              style: const TextStyle(fontSize: 32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactorBreakdown() {
    final factors = gameWithPriority.factorScores;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Score Breakdown',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        _buildFactorBar('Steam Rating', factors['steamRating'] ?? 0, AppTheme.secondaryColor),
        _buildFactorBar('Short Completion', factors['hltbTime'] ?? 0, AppTheme.accentColor),
        _buildFactorBar('Time Since Played', factors['lastPlayed'] ?? 0, AppTheme.primaryColor),
        _buildFactorBar('In Progress Bonus', factors['progress'] ?? 0, Colors.orange),
        _buildFactorBar('Metacritic', factors['metacritic'] ?? 0, Colors.green),
        _buildFactorBar('Genre Match', factors['genre'] ?? 0, Colors.purple),
      ],
    );
  }

  Widget _buildFactorBar(String label, double score, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              Text(
                score.toStringAsFixed(0),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: AppTheme.cardColor,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    final game = gameWithPriority.game;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Game Stats',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildStatCard(
              'Steam Rating',
              '${game.steamRating.toStringAsFixed(0)}%',
              Icons.thumb_up,
              AppTheme.secondaryColor,
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard(
              'Reviews',
              _formatNumber(game.steamReviewCount),
              Icons.rate_review,
              AppTheme.textMuted,
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCard(
              'Main Story',
              game.hltbMainHours != null ? '${game.hltbMainHours!.toStringAsFixed(0)}h' : 'N/A',
              Icons.timer,
              AppTheme.accentColor,
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard(
              'Your Playtime',
              '${game.playtimeHours.toStringAsFixed(1)}h',
              Icons.play_arrow,
              AppTheme.primaryColor,
            )),
          ],
        ),
        if (game.metacriticScore != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard(
                'Metacritic',
                game.metacriticScore!.toStringAsFixed(0),
                Icons.star,
                Colors.green,
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(
                'Last Played',
                game.lastPlayed != null 
                    ? '${game.daysSinceLastPlayed}d ago'
                    : 'Never',
                Icons.calendar_today,
                AppTheme.textMuted,
              )),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenresSection() {
    final game = gameWithPriority.game;
    
    if (game.genres.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Genres',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: game.genres.map((genre) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              genre,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildActionsSection(BuildContext context) {
    final game = gameWithPriority.game;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.open_in_new,
                label: 'Steam Store',
                color: AppTheme.secondaryColor,
                onTap: () => _openSteamStore(game.id),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: Icons.play_arrow,
                label: 'Play Game',
                color: AppTheme.primaryColor,
                onTap: () => _launchGame(game.id),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Consumer<GameProvider>(
                builder: (context, provider, _) => _buildActionButton(
                  icon: game.isCompleted ? Icons.replay : Icons.check_circle,
                  label: game.isCompleted ? 'Uncomplete' : 'Complete',
                  color: game.isCompleted ? AppTheme.textMuted : Colors.green,
                  onTap: () {
                    provider.toggleCompleted(game.id);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Consumer<GameProvider>(
                builder: (context, provider, _) => _buildActionButton(
                  icon: game.isHidden ? Icons.visibility : Icons.visibility_off,
                  label: game.isHidden ? 'Show' : 'Hide',
                  color: AppTheme.textMuted,
                  onTap: () {
                    provider.toggleHidden(game.id);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatNumber(int num) {
    if (num >= 1000000) {
      return '${(num / 1000000).toStringAsFixed(1)}M';
    } else if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(1)}K';
    }
    return num.toString();
  }

  Future<void> _openSteamStore(String appId) async {
    final url = Uri.parse('https://store.steampowered.com/app/$appId');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchGame(String appId) async {
    final url = Uri.parse('steam://run/$appId');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }
}
