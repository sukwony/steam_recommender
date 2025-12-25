# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter application called "Game Prioritizer" that helps users decide which Steam game to play next by calculating priority scores based on multiple factors. The app syncs with the Steam API and HowLongToBeat to fetch game data and applies weighted scoring algorithms.

## Development Commands

### Running the App
```bash
flutter run
```

### Building
```bash
# Android
flutter build apk

# iOS
flutter build ios

# macOS
flutter build macos
```

### Code Generation
The app uses Hive for local storage and requires code generation for TypeAdapters:
```bash
dart run build_runner build
# Or for watch mode during development:
dart run build_runner watch --delete-conflicting-outputs
```

### Testing
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart
```

### Linting
```bash
flutter analyze
```

### Dependencies
```bash
# Get dependencies
flutter pub get

# Upgrade dependencies
flutter pub upgrade
```

## Architecture Overview

### State Management
The app uses **Provider** for state management with a single primary provider:
- `GameProvider` (lib/providers/game_provider.dart) - Central state manager for games, settings, filtering, and sync operations

### Data Layer

**Models** (lib/models/):
- `Game` - Core game entity with Steam data, HLTB data, user preferences (completed, progress, notes). Uses Hive for persistence
- `PrioritySettings` - User configuration for priority weights, filters, Steam credentials. Uses Hive for persistence
- `GameWithPriority` - Computed model combining a Game with its calculated priority score and tier

**Services** (lib/services/):
- `DatabaseService` - Hive database wrapper for games and settings CRUD operations
- `SteamApiService` - Fetches owned games, game details, reviews, and Metacritic scores from Steam Web API
- `HltbService` - Searches HowLongToBeat for completion time data (uses unofficial API)
- `SyncService` - Orchestrates three sync types:
  - Full sync: Fetch library + enrich with Steam details + HLTB data
  - Quick sync: Update playtime and last played only
  - HLTB refresh: Fetch HLTB data for games missing it
- `PriorityCalculator` - Core algorithm that calculates priority scores based on weighted factors

### Priority Calculation Algorithm

The priority system (lib/services/priority_calculator.dart) normalizes multiple factors to 0-100 scores, then applies user-defined weights:

**Factors**:
- Steam Rating: Higher rating = higher score
- HLTB Time: Shorter games = higher score (inverted normalization). Games exceeding `maxHltbHours` get 50% penalty
- Last Played: Longer ago = higher score. Never played = 100
- Progress: Games in progress (0-100%) get 50-100 score. Completed = 0
- Metacritic: Higher score = higher priority
- Genre Preference: Matching preferred genres get bonus (50-100)

Final score = sum of (factor_score × factor_weight) for all factors.

Games are then sorted by score and assigned to priority tiers.

### UI Structure

**Screens** (lib/screens/):
- `HomeScreen` - Main game list with filtering, search, and sync controls
- `GameDetailScreen` - Individual game view with Steam link, completion toggle, progress slider
- `SettingsScreen` - Configure priority weights, Steam credentials, preferences

**Widgets** (lib/widgets/):
- `GameCard` - Displays game with header image, title, rating, playtime
- `FilterChipsRow` - Genre and tier filtering chips
- `SyncProgressWidget` - Shows sync status and progress

### Data Flow

1. User triggers sync → `GameProvider.fullSync()`
2. `SyncService` fetches from Steam API → enriches with HLTB → saves to DatabaseService
3. `GameProvider` loads games → `PriorityCalculator` computes scores → UI updates via `notifyListeners()`
4. User filters/searches → `GameProvider._getFilteredGames()` → UI shows filtered list

### External APIs

**Steam Web API**:
- Requires Steam API key (get from https://steamcommunity.com/dev/apikey)
- Requires Steam64 ID (17-digit ID starting with 7656)
- Endpoints used: GetOwnedGames, appdetails, appreviews
- Note: In production, API keys should be proxied through a backend

**HowLongToBeat API**:
- Uses unofficial POST endpoint at howlongtobeat.com/api/search
- No authentication required
- Rate limited to 300-500ms between requests
- Game name matching uses fuzzy logic in `_findBestMatch()`

### Hive Database

Local storage uses Hive boxes:
- `games` box: Stores Game objects with typeId 0
- `settings` box: Stores PrioritySettings with typeId 1

Generated adapters (*.g.dart files) are created via build_runner.

## Important Implementation Notes

- Always preserve user data (isCompleted, userProgress, isHidden, notes) when syncing games from Steam
- The sync service includes rate limiting (200ms for Steam, 300-500ms for HLTB) to avoid being blocked
- Game names are cleaned before HLTB search (removing ™, ®, edition suffixes) for better matching
- Priority weights should sum to 1.0 for normalized scoring - use `PrioritySettings.normalizeWeights()`
- Filters in GameProvider are reactive - changes trigger notifyListeners() immediately
