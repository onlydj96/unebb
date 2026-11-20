# UnEbb

AI-powered adaptive vocabulary learning application built with Flutter and Supabase.

## Features

- 🧠 Adaptive learning with SM-2 spaced repetition algorithm
- 🤖 AI-powered answer evaluation and feedback
- 📚 Deck-based vocabulary organization
- 🌐 Multi-language support (English, Korean)
- 📊 Progress tracking and memory strength indicators
- 🎯 Personalized error pattern detection

## Prerequisites

- Flutter 3.47.9 (Dart 3.13) — pinned in `.fvmrc`. With [FVM](https://fvm.app):
  `fvm install`, then prefix commands with `fvm` (e.g. `fvm flutter pub get`).
  Older SDKs fail at `flutter pub get` (the locked `build_runner`/`analyzer`
  versions need Dart 3.13).
- Deno 2 (only for checking the Supabase Edge Functions)
- Supabase account (for backend services)

## Getting Started

### Windows

1. **Setup development environment**
   ```bash
   scripts\setup.bat
   ```

2. **Run the app**
   ```bash
   flutter run
   ```

### macOS/Linux

1. **Install dependencies**
   ```bash
   make get
   # or
   flutter pub get
   ```

2. **Generate code**
   ```bash
   make codegen
   # or
   dart run build_runner build
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

## Development

### Code Generation

This project uses code generation for:
- `freezed` - Immutable data classes
- `json_serializable` - JSON serialization

**Generate code once:**

Windows:
```bash
scripts\codegen.bat
```

macOS/Linux:
```bash
make codegen
```

**Watch mode (auto-regenerate on file changes):**

Windows:
```bash
scripts\watch.bat
```

macOS/Linux:
```bash
make watch
```

### Available Commands (Makefile)

```bash
make help        # Show all available commands
make get         # Install dependencies
make codegen     # Generate code
make watch       # Watch mode for code generation
make clean       # Remove build artifacts (run `make dev` afterwards)
make analyze     # Run static analysis
make test        # Run Flutter tests
make format      # Format code
make format-check    # Fail if any Dart file is not formatted
make functions-check # Type-check, lint and test the Edge Functions (Deno)
make check       # Everything CI runs (format-check + analyze + test + functions-check)
make l10n        # Generate localization files
make outdated    # Check outdated dependencies
make dev         # Setup dev environment (get + l10n + codegen)
make all         # clean + dev + check
```

### Continuous Integration

`.github/workflows/ci.yml` runs on every pull request and on pushes to `main`:

- **Flutter** (version from `.fvmrc`): `dart format --set-exit-if-changed`,
  `build_runner`, `flutter analyze`, `flutter test`
- **Edge Functions**: `deno check`, `deno lint`, `deno test`
```

### Project Structure

```
lib/
├── core/               # Core utilities and configuration
│   ├── constants.dart
│   ├── router/        # Navigation routing
│   ├── theme/         # App theming
│   └── utils/         # Utility classes (logger, etc.)
├── data/              # Data layer
│   ├── repositories/  # Data repositories
│   └── services/      # External services (AI, Supabase)
├── domain/            # Business logic layer
│   ├── models/        # Domain models
│   ├── repositories/  # Repository interfaces
│   └── services/      # Business services
├── features/          # Feature modules
│   ├── auth/         # Authentication
│   ├── decks/        # Deck management
│   ├── home/         # Home dashboard
│   ├── review/       # Review/practice
│   ├── settings/     # App settings
│   └── vocabulary/   # Vocabulary management
├── l10n/             # Localization files
└── shared/           # Shared widgets
```

## Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/widget_test.dart

# Edge Function tests (Deno)
deno test --allow-env supabase/functions
```

## Localization

The app supports multiple languages. Localization files are in `lib/l10n/`.

Generate localization files:
```bash
flutter gen-l10n
# or
make l10n
```

Supported languages:
- English (en)
- Korean (ko)

## Code Quality

### Static Analysis

```bash
flutter analyze
# or
make analyze
```

### Code Formatting

```bash
dart format lib test
# or
make format
```

## Architecture

This project follows Clean Architecture principles:

- **Presentation Layer**: UI components and state management (Riverpod)
- **Domain Layer**: Business logic and entities
- **Data Layer**: Repositories and external data sources (Supabase)

### State Management

Uses [Riverpod](https://riverpod.dev/) for state management with code generation for type-safe providers.

### Navigation

Uses [go_router](https://pub.dev/packages/go_router) for declarative routing with deep linking support.

### Backend

Backend services powered by [Supabase](https://supabase.com/):
- Authentication
- PostgreSQL database
- Edge Functions (AI evaluation, question generation)
- Real-time subscriptions

## Contributing

1. Create a feature branch
2. Make your changes
3. Run tests and analysis
4. Format code
5. Submit a pull request

## License

This project is private and not licensed for public use.
