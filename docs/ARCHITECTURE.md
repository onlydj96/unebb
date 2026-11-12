## Backend Architecture

UnEbb uses Supabase as its backend platform.

### Technology Stack

Frontend:
- Flutter
- Dart
- Riverpod
- GoRouter

Backend:
- Supabase

Backend services:
- Supabase Authentication
- PostgreSQL Database
- Row Level Security
- Supabase Storage
- Supabase Edge Functions

AI:
- OpenAI API

---

## System Architecture

```text
Flutter Application
        │
        ├───────────────┐
        │               │
        ▼               ▼
Supabase Auth      Supabase Database
                        │
                        │
Flutter                  │
   │                     │
   ▼                     │
Edge Functions           │
   │                     │
   ▼                     │
OpenAI API               │
   │                     │
   ▼                     │
Structured Output        │
   │                     │
   ▼                     │
Validation               │
   │                     │
   └──────────────→ PostgreSQL
```

---

## Data Access

Flutter may directly access Supabase for normal user-owned application data when protected by Row Level Security.

Examples:

- vocabulary
- review history
- user profile
- learning statistics

Sensitive operations must use Edge Functions.

Examples:

- OpenAI API requests
- server-side validation
- privileged operations
- operations requiring secret keys

---

## Repository Architecture

Flutter UI must not directly depend on Supabase implementation details.

```text
Presentation
     ↓
Controller / Provider
     ↓
Repository Interface
     ↓
Repository Implementation
     ↓
Supabase
```

This allows backend implementation details to change without affecting feature UI.

---

## Flutter Directory Structure

```text
lib/
├── core/
│   ├── router/           # GoRouter configuration and route guards
│   ├── theme/            # AppTheme, design tokens (colors, typography, spacing, radius)
│   └── constants.dart    # App-wide constants
│
├── domain/               # Pure Dart — no Flutter, no Supabase imports
│   ├── models/           # Immutable domain models (Freezed)
│   ├── repositories/     # Abstract repository interfaces
│   └── services/         # Domain services (e.g. MemoryService — algorithm only)
│
├── data/                 # External dependencies
│   ├── repositories/     # Supabase implementations of domain repository interfaces
│   └── services/         # External adapters (e.g. AiEvaluationService — Edge Function calls)
│
├── features/             # Screen + provider layer per feature
│   ├── auth/
│   │   ├── screens/
│   │   └── providers/
│   ├── vocabulary/
│   │   ├── screens/
│   │   └── providers/
│   └── review/
│       ├── screens/
│       └── providers/
│
├── shared/
│   └── widgets/          # Design system components (AppButton, AppCard, etc.)
│
└── main.dart
```

Dependency direction: `features/` → `domain/` ← `data/`

`domain/` must never import from `data/` or `features/`.

`data/` implements interfaces defined in `domain/repositories/`.

`features/` accesses data only through Riverpod providers that wrap domain repositories.

---

## Supabase Directory Structure

```text
supabase/
├── functions/
│   ├── _shared/          # Shared helpers (auth.ts: resolve the signed-in user)
│   ├── evaluate-answer/
│   ├── generate-explanation/
│   └── generate-question/
└── migrations/           # SQL migration files (timestamped)
```

Every Edge Function resolves the signed-in user with `requireUser()` before
spending OpenAI credit. Functions that write with the service role must scope
every query to that user (`user_id=eq.<caller>`), because the service role
bypasses Row Level Security.

---

## Client State & Caching

- User-scoped providers watch `currentUserIdProvider`, so they rebuild when the
  account changes. `CacheService.bindToUser` wipes cached data that belongs to
  another account (or to nobody after sign-out) before anything reads it.
- Lists (vocabulary, memory states, decks) are cache-first: cached data renders
  immediately and a background sync replaces it when the server copy differs.
- Derived data (deck word counts, "recently studied" order, due counts) is
  computed from those lists by pure domain helpers (`DeckOverview`) instead of
  extra queries.
- Review ordering lives in the domain service `ReviewQueueBuilder`.

All database schema changes must be expressed as migration files.

---

## Security

Never expose:

- OpenAI API keys
- Supabase service role keys
- backend secrets

inside the Flutter application.

The Flutter application may contain the Supabase public client configuration intended for client-side use.

All database tables containing user data must use Row Level Security.

OpenAI API calls must go through Supabase Edge Functions.