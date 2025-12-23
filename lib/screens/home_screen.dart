import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../models/game_with_priority.dart';
import '../widgets/game_card.dart';
import '../widgets/sync_progress_widget.dart';
import '../widgets/filter_chips_row.dart';
import '../utils/app_theme.dart';
import 'game_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<GameProvider>(
          builder: (context, provider, child) {
            return Column(
              children: [
                _buildAppBar(context, provider),
                if (provider.syncProgress != null)
                  SyncProgressWidget(progress: provider.syncProgress!),
                _buildFilters(provider),
                Expanded(
                  child: _buildGameList(provider),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: _buildFab(context),
    );
  }

  Widget _buildAppBar(BuildContext context, GameProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _showSearch
                    ? _buildSearchField(provider)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Game Prioritizer',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            '${provider.prioritizedGames.length} games to play',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
              ),
              IconButton(
                icon: Icon(
                  _showSearch ? Icons.close : Icons.search,
                  color: AppTheme.textPrimary,
                ),
                onPressed: () {
                  setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) {
                      _searchController.clear();
                      provider.setSearchQuery('');
                    }
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.settings, color: AppTheme.textPrimary),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(GameProvider provider) {
    return TextField(
      controller: _searchController,
      autofocus: true,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search games...',
        prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: AppTheme.textMuted),
                onPressed: () {
                  _searchController.clear();
                  provider.setSearchQuery('');
                },
              )
            : null,
      ),
      onChanged: (value) {
        provider.setSearchQuery(value);
      },
    );
  }

  Widget _buildFilters(GameProvider provider) {
    final stats = provider.getStatistics();
    final tierCounts = stats['tierCounts'] as Map<PriorityTier, int>;

    return FilterChipsRow(
      selectedTier: provider.selectedTier,
      onTierChanged: (tier) => provider.setSelectedTier(tier),
      tierCounts: tierCounts,
    );
  }

  Widget _buildGameList(GameProvider provider) {
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    if (provider.error != null && provider.games.isEmpty) {
      return _buildErrorState(provider);
    }

    if (provider.games.isEmpty) {
      return _buildEmptyState(provider);
    }

    final games = provider.prioritizedGames;

    if (games.isEmpty) {
      return _buildNoResultsState(provider);
    }

    return RefreshIndicator(
      onRefresh: () => provider.quickSync(),
      color: AppTheme.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: games.length,
        itemBuilder: (context, index) {
          final gameWithPriority = games[index];
          return GameCard(
            gameWithPriority: gameWithPriority,
            rank: index + 1,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GameDetailScreen(
                    gameWithPriority: gameWithPriority,
                    rank: index + 1,
                  ),
                ),
              );
            },
            onLongPress: () {
              _showGameOptions(context, provider, gameWithPriority);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(GameProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.videogame_asset,
                size: 64,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Games Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sync your Steam library to get started',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.settings),
              label: const Text('Configure Steam API'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(GameProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            Text(
              provider.error ?? 'An error occurred',
              style: const TextStyle(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => provider.initialize(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState(GameProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              size: 64,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 16),
            const Text(
              'No games match your filters',
              style: TextStyle(
                fontSize: 18,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => provider.clearFilters(),
              child: const Text('Clear Filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, provider, _) {
        return FloatingActionButton.extended(
          onPressed: provider.isSyncing ? null : () => _showSyncOptions(context, provider),
          icon: provider.isSyncing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.sync),
          label: Text(provider.isSyncing ? 'Syncing...' : 'Sync'),
          backgroundColor: provider.isSyncing
              ? AppTheme.primaryColor.withValues(alpha: 0.5)
              : AppTheme.primaryColor,
        );
      },
    );
  }

  void _showSyncOptions(BuildContext context, GameProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sync Options',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.sync, color: AppTheme.primaryColor),
              title: const Text('Full Sync', style: TextStyle(color: AppTheme.textPrimary)),
              subtitle: const Text(
                'Fetch all game data including ratings & HLTB times',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                provider.fullSync();
              },
            ),
            ListTile(
              leading: const Icon(Icons.speed, color: AppTheme.accentColor),
              title: const Text('Quick Sync', style: TextStyle(color: AppTheme.textPrimary)),
              subtitle: const Text(
                'Update playtime only (faster)',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                provider.quickSync();
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer, color: AppTheme.secondaryColor),
              title: const Text('Refresh HLTB', style: TextStyle(color: AppTheme.textPrimary)),
              subtitle: const Text(
                'Fetch missing HowLongToBeat data',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                provider.refreshHltb();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showGameOptions(BuildContext context, GameProvider provider, GameWithPriority gameWithPriority) {
    final game = gameWithPriority.game;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              game.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                game.isCompleted ? Icons.replay : Icons.check_circle,
                color: game.isCompleted ? AppTheme.textMuted : Colors.green,
              ),
              title: Text(
                game.isCompleted ? 'Mark as Not Completed' : 'Mark as Completed',
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                provider.toggleCompleted(game.id);
              },
            ),
            ListTile(
              leading: Icon(
                game.isHidden ? Icons.visibility : Icons.visibility_off,
                color: AppTheme.textMuted,
              ),
              title: Text(
                game.isHidden ? 'Show Game' : 'Hide Game',
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                provider.toggleHidden(game.id);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
