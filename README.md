# WNTP (What Next To Play)

A Flutter application that helps you decide which Steam game to play next by calculating priority scores based on multiple factors including ratings, completion time, playtime, and personal preferences.

## Features

- **Steam OAuth Integration**: Sign in with Steam - no manual API key required
- **Smart Prioritization**: AI-powered algorithm considers multiple factors:
  - Steam user ratings
  - HowLongToBeat completion times
  - Last played date
  - User progress
  - Metacritic scores
  - Genre preferences
- **Customizable Weights**: Adjust priority factors to match your preferences
- **Library Sync**: Automatic sync with your Steam library
- **Filtering & Search**: Filter by genre, priority tier, or search by name
- **Progress Tracking**: Mark games as completed, track progress
- **Dark Theme**: Gaming-focused UI with purple/blue accents

## Tech Stack

### Frontend (Flutter)
- **State Management**: Provider
- **Local Storage**: Hive (NoSQL)
- **Authentication**: flutter_web_auth_2 + flutter_secure_storage
- **HTTP Client**: http package
- **Platforms**: Android, iOS, macOS (Windows/Linux support planned)

### Backend (Vercel Serverless)
- **Runtime**: Node.js + TypeScript
- **Authentication**: JWT (jsonwebtoken)
- **Steam Integration**: OpenID 2.0 + Steam Web API
- **Deployment**: Vercel

## Project Structure

```
wntp/
├── app/                    # Flutter application
│   ├── lib/
│   │   ├── models/        # Data models (Game, PrioritySettings, etc.)
│   │   ├── providers/     # State management (GameProvider)
│   │   ├── screens/       # UI screens
│   │   ├── services/      # Business logic & API clients
│   │   ├── widgets/       # Reusable UI components
│   │   └── utils/         # Utilities & theme
│   ├── android/           # Android platform code
│   ├── ios/               # iOS platform code
│   └── macos/             # macOS platform code
│
└── backend/               # Vercel backend
    ├── api/
    │   ├── auth/         # Steam OAuth endpoints
    │   ├── games/        # Game data endpoints
    │   └── utils/        # JWT & OpenID utilities
    ├── package.json
    └── vercel.json       # Vercel configuration
```

## Getting Started

### Prerequisites

- Flutter SDK (3.0+)
- Node.js (18+) - for backend development
- Steam account

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/wntp.git
cd wntp
```

### 2. Flutter App Setup

```bash
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

### 3. Backend Setup (Optional - for local development)

```bash
cd backend
npm install
vercel dev  # Requires Vercel CLI
```

## Backend Deployment

### 1. Get Steam API Key

Visit https://steamcommunity.com/dev/apikey and register for an API key.

### 2. Deploy to Vercel

```bash
cd backend
npm install -g vercel  # If not already installed
vercel login
vercel deploy --prod
```

### 3. Configure Environment Variables

In Vercel dashboard, set:

```
STEAM_API_KEY=<your_steam_api_key>
JWT_SECRET=<random_secret_string>
APP_CALLBACK_SCHEME=wntp://auth/success
```

Generate JWT secret:
```bash
openssl rand -base64 32
```

### 4. Update Flutter App

Update the backend URL in `app/lib/services/backend_api_service.dart`:

```dart
static const String _baseUrl = 'https://your-deployment.vercel.app';
```

## Architecture

### Authentication Flow

```
1. User clicks "Sign in with Steam"
2. Flutter opens Steam OpenID login page
3. User authenticates with Steam
4. Steam redirects to Vercel callback
5. Backend verifies OpenID response
6. Backend creates JWT token
7. Backend redirects to wntp://auth/success?token=xxx
8. Flutter saves token to secure storage
9. Authenticated!
```

### API Architecture (Hybrid)

```
┌─────────────┐
│ Flutter App │
└──────┬──────┘
       │
       ├─── /api/games/owned ────────┐
       │                             │
       │                     ┌───────▼────────┐
       │                     │ Vercel Backend │
       │                     │  (JWT Auth)    │
       │                     └───────┬────────┘
       │                             │
       ├─────────────────────────────┼────────────┐
       │                             │            │
       ▼                             ▼            ▼
Steam appdetails API        Steam GetOwnedGames   HowLongToBeat
  (Public)                     (Authenticated)       (Public)
```

**Why Hybrid?**
- `owned` endpoint requires Steam API key → Backend proxy (secure)
- `details` and `reviews` are public APIs → Direct call (faster, cheaper)

### Data Flow

```
1. User triggers sync
   └─> GameProvider.fullSync()

2. Fetch owned games
   └─> BackendApiService.fetchOwnedGames() (via Vercel)

3. Enrich with Steam details
   └─> BackendApiService.fetchGameDetails() (direct)
   └─> BackendApiService.fetchGameReviews() (direct)

4. Enrich with HLTB data
   └─> HltbService.enrichWithHltbData()

5. Calculate priorities
   └─> PriorityCalculator.calculatePriorities()

6. Save to local database
   └─> DatabaseService.saveGames()

7. Update UI
   └─> notifyListeners()
```

## Priority Algorithm

The app calculates a weighted score (0-100) for each game:

```dart
final_score =
  (steam_rating_score × steam_rating_weight) +
  (hltb_time_score × hltb_time_weight) +
  (last_played_score × last_played_weight) +
  (progress_score × progress_weight) +
  (metacritic_score × metacritic_weight) +
  (genre_score × genre_weight)
```

**Factors:**
- **Steam Rating**: Higher rating = higher priority
- **HLTB Time**: Shorter games = higher priority (inverted)
- **Last Played**: Longer ago = higher priority
- **Progress**: In-progress games = higher priority
- **Metacritic**: Higher score = higher priority
- **Genre**: Preferred genres get bonus score

Games are then sorted by score and assigned to tiers:
- **Must Play** (Top 10%)
- **High Priority** (10-30%)
- **Medium** (30-60%)
- **Low** (60-90%)
- **Backlog** (Bottom 10%)

## Development

### Code Generation (Hive)

After modifying models with `@HiveType`:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Running Tests

```bash
flutter test
```

### Linting

```bash
flutter analyze
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see LICENSE file for details

## Acknowledgments

- [Steam Web API](https://steamcommunity.com/dev)
- [HowLongToBeat](https://howlongtobeat.com)
- Flutter and Dart teams
- Vercel for serverless hosting
