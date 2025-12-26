# WNTP (What Next To Play) - Flutter App

Cross-platform mobile application for prioritizing your Steam game backlog.

Part of the WNTP project - see [main README](../README.md) for full project documentation.

## Quick Start

### Prerequisites
- Flutter SDK 3.0+
- Android Studio / Xcode (for mobile development)

### Installation

```bash
# Install dependencies
flutter pub get

# Generate Hive adapters
dart run build_runner build --delete-conflicting-outputs

# Run app
flutter run
```

## Features

- ✅ Steam OAuth login (no manual API key required)
- ✅ Automatic library sync
- ✅ Smart game prioritization algorithm
- ✅ Customizable priority weights
- ✅ Filter by genre, tier, search
- ✅ Progress tracking
- ✅ Dark gaming theme

## Project Structure

```
lib/
├── main.dart              # App entry point
├── models/               # Data models (Hive)
│   ├── game.dart
│   ├── priority_settings.dart
│   └── game_with_priority.dart
├── providers/            # State management (Provider)
│   └── game_provider.dart
├── screens/              # UI screens
│   ├── home_screen.dart
│   ├── game_detail_screen.dart
│   └── settings_screen.dart
├── services/             # Business logic
│   ├── backend_api_service.dart
│   ├── steam_auth_service.dart
│   ├── sync_service.dart
│   ├── hltb_service.dart
│   ├── priority_calculator.dart
│   └── database_service.dart
├── widgets/              # Reusable components
│   ├── game_card.dart
│   ├── filter_chips_row.dart
│   └── sync_progress_widget.dart
└── utils/
    └── app_theme.dart
```

## State Management

Uses **Provider** pattern:
- Single `GameProvider` manages entire app state
- Notifies UI on data changes
- Handles sync, filtering, settings

## Local Storage

Uses **Hive** (NoSQL):
- Fast, lightweight
- Type-safe with code generation
- Two boxes: `games` and `settings`

## Development

### Code Generation

After modifying `@HiveType` models:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Adding Dependencies

```bash
flutter pub add package_name
```

### Running on Devices

```bash
# List devices
flutter devices

# Run on specific device
flutter run -d <device_id>

# Run in release mode
flutter run --release
```

### Platform-Specific Setup

**Android:**
- Minimum SDK: 21 (Android 5.0)
- Custom URL scheme: `wntp://` (for OAuth callback)

**iOS:**
- Minimum version: iOS 12.0
- Custom URL scheme: `wntp://`
- May require provisioning profile for physical devices

**macOS:**
- Minimum version: macOS 10.14
- Custom URL scheme: `wntp://`

## Building

### Android APK

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### iOS IPA

```bash
flutter build ios --release
```

Then archive in Xcode.

### macOS App

```bash
flutter build macos --release
```

Output: `build/macos/Build/Products/Release/wntp.app`

## Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
```

## Troubleshooting

**Build errors after model changes:**
```bash
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

**Authentication not working:**
- Check backend URL in `lib/services/backend_api_service.dart`
- Verify URL scheme setup in AndroidManifest.xml / Info.plist
- Check Vercel environment variables

**Hive errors:**
```bash
# Delete app data and reinstall
flutter clean
# Uninstall from device
# Reinstall
```

## License

Part of the WNTP project - MIT License
