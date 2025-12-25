import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../models/priority_settings.dart';
import '../services/steam_auth_service.dart';
import '../utils/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late PrioritySettings _settings;

  @override
  void initState() {
    super.initState();
    final provider = context.read<GameProvider>();
    _settings = provider.settings.copyWith();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSteamSection(),
          const SizedBox(height: 24),
          _buildWeightsSection(),
          const SizedBox(height: 24),
          _buildPreferencesSection(),
          const SizedBox(height: 24),
          _buildFiltersSection(),
          const SizedBox(height: 24),
          _buildDataSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSteamSection() {
    final provider = context.read<GameProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Steam Authentication', icon: Icons.games),
        const SizedBox(height: 16),
        FutureBuilder<bool>(
          future: provider.isAuthenticated(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final isAuthenticated = snapshot.data ?? false;

            if (isAuthenticated) {
              return _buildAuthenticatedView(provider);
            } else {
              return _buildSignInView(provider);
            }
          },
        ),
      ],
    );
  }

  Widget _buildAuthenticatedView(GameProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Steam Connected',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<String?>(
            future: provider.getSteamId(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                return Text(
                  'Steam ID: ${snapshot.data}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 14,
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _handleSignOut(provider),
              icon: const Icon(Icons.logout),
              label: const Text('Disconnect'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInView(GameProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sign in with your Steam account to sync your game library.',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _handleSteamSignIn(provider),
              icon: const Icon(Icons.login),
              label: const Text('Sign in with Steam'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF171A21), // Steam dark color
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSteamSignIn(GameProvider provider) async {
    try {
      final authService = SteamAuthService(provider.backendApi);
      final steamId = await authService.authenticateWithSteam();

      if (steamId != null && mounted) {
        setState(() {}); // Refresh UI
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Steam account connected successfully!'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in failed: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _handleSignOut(GameProvider provider) async {
    try {
      final authService = SteamAuthService(provider.backendApi);
      await authService.signOut();

      if (mounted) {
        setState(() {}); // Refresh UI
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Steam account disconnected'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign out failed: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Widget _buildWeightsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Priority Weights', icon: Icons.tune),
        const SizedBox(height: 8),
        const Text(
          'Adjust how much each factor affects the priority score',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),
        _buildWeightSlider(
          'Steam Rating',
          _settings.steamRatingWeight,
          AppTheme.secondaryColor,
          (v) => setState(() => _settings = _settings.copyWith(steamRatingWeight: v)),
        ),
        _buildWeightSlider(
          'Short Completion Time',
          _settings.hltbTimeWeight,
          AppTheme.accentColor,
          (v) => setState(() => _settings = _settings.copyWith(hltbTimeWeight: v)),
        ),
        _buildWeightSlider(
          'Time Since Last Played',
          _settings.lastPlayedWeight,
          AppTheme.primaryColor,
          (v) => setState(() => _settings = _settings.copyWith(lastPlayedWeight: v)),
        ),
        _buildWeightSlider(
          'In Progress Bonus',
          _settings.progressWeight,
          Colors.orange,
          (v) => setState(() => _settings = _settings.copyWith(progressWeight: v)),
        ),
        _buildWeightSlider(
          'Metacritic Score',
          _settings.metacriticWeight,
          Colors.green,
          (v) => setState(() => _settings = _settings.copyWith(metacriticWeight: v)),
        ),
        _buildWeightSlider(
          'Genre Preference',
          _settings.genreWeight,
          Colors.purple,
          (v) => setState(() => _settings = _settings.copyWith(genreWeight: v)),
        ),
      ],
    );
  }

  Widget _buildWeightSlider(String label, double value, Color color, Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(value * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              thumbColor: color,
              inactiveTrackColor: color.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 1,
              divisions: 20,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('HLTB Preferences', icon: Icons.timer),
        const SizedBox(height: 16),
        const Text(
          'Completion time type',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Main')),
            ButtonSegment(value: 1, label: Text('Main+')),
            ButtonSegment(value: 2, label: Text('100%')),
          ],
          selected: {_settings.hltbType},
          onSelectionChanged: (selected) {
            setState(() => _settings = _settings.copyWith(hltbType: selected.first));
          },
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return AppTheme.primaryColor;
              }
              return AppTheme.textSecondary;
            }),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Max completion time filter',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            Text(
              '${_settings.maxHltbHours.toStringAsFixed(0)}h',
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: _settings.maxHltbHours,
          min: 10,
          max: 200,
          divisions: 19,
          label: '${_settings.maxHltbHours.toStringAsFixed(0)}h',
          onChanged: (v) => setState(() => _settings = _settings.copyWith(maxHltbHours: v)),
        ),
        const Text(
          'Games longer than this will get a lower priority',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildFiltersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Display Filters', icon: Icons.filter_list),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Include games without HLTB data', 
            style: TextStyle(color: AppTheme.textPrimary)),
          subtitle: const Text('Show games even if completion time is unknown',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          value: _settings.includeNoHltbGames,
          onChanged: (v) => setState(() => _settings = _settings.copyWith(includeNoHltbGames: v)),
          activeTrackColor: AppTheme.primaryColor,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show completed games',
            style: TextStyle(color: AppTheme.textPrimary)),
          subtitle: const Text('Include games you\'ve marked as completed',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          value: _settings.showCompletedGames,
          onChanged: (v) => setState(() => _settings = _settings.copyWith(showCompletedGames: v)),
          activeTrackColor: AppTheme.primaryColor,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show hidden games',
            style: TextStyle(color: AppTheme.textPrimary)),
          subtitle: const Text('Include games you\'ve hidden',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          value: _settings.showHiddenGames,
          onChanged: (v) => setState(() => _settings = _settings.copyWith(showHiddenGames: v)),
          activeTrackColor: AppTheme.primaryColor,
        ),
      ],
    );
  }

  Widget _buildDataSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Data Management', icon: Icons.storage),
        const SizedBox(height: 16),
        Consumer<GameProvider>(
          builder: (context, provider, _) {
            final stats = provider.getStatistics();
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildStatRow('Total Games', stats['totalGames'].toString()),
                  _buildStatRow('Completed', stats['completedGames'].toString()),
                  _buildStatRow('Total Playtime', '${(stats['totalPlaytimeHours'] as double).toStringAsFixed(0)}h'),
                  _buildStatRow('With HLTB Data', stats['gamesWithHltb'].toString()),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showClearDataDialog(),
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text('Clear All Data', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _saveSettings() {
    _settings.normalizeWeights();
    
    context.read<GameProvider>().updateSettings(_settings);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
    
    Navigator.pop(context);
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Clear All Data?', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'This will delete all your games and reset settings. This action cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<GameProvider>().clearAllData();
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
