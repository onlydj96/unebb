# UnEbb Progress

## Current Status

**Phase**: Phases 2–8, 10–11 complete — App ready for deployment

**Last updated**: 2026-10-06

---

## Completed

- [x] All specification documents written (PRODUCT, ARCHITECTURE, DOMAIN, MEMORY_MODEL, AI_EVALUATION, DESIGN_SYSTEM, DATABASE)
- [x] ARCHITECTURE.md updated with Flutter directory structure
- [x] AGENT.md header corrected
- [x] DESIGN_SYSTEM.md filename corrected (was double underscore)
- [x] .gitignore created (protects .env)
- [x] tasks/PLAN.md created
- [x] tasks/BACKLOG.md created
- [x] All BACKLOG decisions resolved (DECISION-1 through DECISION-8)

### Phase 0 — Bootstrap

- [x] `flutter create unebb` (org: com.unebb, project: unebb)
- [x] Core dependencies added to pubspec.yaml
- [x] Dev dependencies added
- [x] Directory structure created per ARCHITECTURE.md
- [x] lib/core/constants.dart created
- [x] lib/main.dart cleaned up
- [x] `dart format` + `flutter analyze` + `flutter test` — all pass

### Phase 1 — Core Infrastructure

- [x] Supabase.initialize() in main.dart (publishableKey)
- [x] ProviderScope + ConsumerWidget (Riverpod)
- [x] core/theme/ — AppColors, AppSpacing, AppRadius, AppTypography, AppTheme.light
- [x] features/auth/providers/auth_provider.dart — authStateChangesProvider + currentUserProvider
- [x] core/router/app_router.dart — GoRouter with _RouterNotifier auth guard
- [x] Placeholder screens: LoginScreen, VocabularyListScreen, ReviewScreen
- [x] `dart format` + `flutter analyze` + `flutter test` (3/3) — all pass

### Phase 2 — Database Migrations

- [x] supabase/migrations/20260929000001_create_profiles.sql
- [x] supabase/migrations/20260929000002_create_vocabulary_items.sql (AI fields)
- [x] supabase/migrations/20260929000003_create_memory_states.sql
- [x] supabase/migrations/20260929000004_create_review_sessions.sql
- [x] supabase/migrations/20260929000005_create_review_results.sql (append-only)
- [x] All tables have RLS enabled + user-scoped policies

### Phase 3 — Domain Layer

- [x] build.yaml — field_rename: snake (json_serializable)
- [x] domain/models/vocabulary_item.dart (Freezed)
- [x] domain/models/ai_evaluation.dart (Freezed, no stage field — DECISION-3)
- [x] domain/models/memory_state.dart (Freezed)
- [x] domain/models/review_result.dart (Freezed, nested AiEvaluation)
- [x] domain/models/review_session.dart (Freezed, List<VocabularyItem> — DECISION-8)
- [x] domain/repositories/ — VocabularyRepository, MemoryStateRepository, ReviewRepository interfaces
- [x] domain/services/memory_service.dart — target-based formula (DECISION-1)
- [x] build_runner — 108 outputs generated
- [x] test/domain/services/memory_service_test.dart — 25/25 tests pass

### Phase 4 — Data Layer

- [x] data/repositories/supabase_vocabulary_repository.dart
- [x] data/repositories/supabase_memory_state_repository.dart
- [x] data/repositories/supabase_review_repository.dart (flattens AiEvaluation into row)
- [x] data/repositories/providers.dart — all Riverpod providers
- [x] data/services/ai_explanation_service.dart — calls generate-explanation Edge Function
- [x] data/services/ai_evaluation_service.dart — calls evaluate-answer Edge Function

### Phase 5 — Auth Feature

- [x] features/auth/providers/auth_provider.dart — signInWithEmail, signUpWithEmail, signOut, upsertProfile
- [x] features/auth/screens/login_screen.dart — full sign-in form
- [x] features/auth/screens/signup_screen.dart — full sign-up form
- [x] features/auth/screens/profile_setup_screen.dart — display name + language selection
- [x] Router updated: /login, /signup, /profile-setup routes
- [x] Auth guard updated: /signup and /profile-setup are public routes

### Phase 6 — Vocabulary Feature

- [x] features/vocabulary/providers/vocabulary_providers.dart — VocabularyNotifier (AsyncNotifier), vocabularyItemProvider (FutureProvider.family)
- [x] VocabularyNotifier.addWord() — creates item + memory state + fires AI explanation
- [x] features/vocabulary/screens/vocabulary_list_screen.dart — real data, pull-to-refresh, loading/empty states
- [x] features/vocabulary/screens/add_word_screen.dart — word + language form
- [x] features/vocabulary/screens/word_detail_screen.dart — full AI content display, delete confirmation
- [x] Router updated: /words/:id, /add-word routes

### Phase 7 — AI Explanation Edge Functions

- [x] supabase/functions/generate-explanation/index.ts — OpenAI gpt-4o-mini, json_object mode, writes to DB via service role
- [x] supabase/functions/evaluate-answer/index.ts — OpenAI gpt-4o-mini, json_object mode, score clamping + validation
- [x] data/repositories/providers.dart updated — aiExplanationServiceProvider, aiEvaluationServiceProvider

### Phase 8 — Review Feature

- [x] features/review/providers/review_providers.dart — ReviewUiState, ReviewPhase enum, ReviewNotifier (StateNotifier)
- [x] ReviewNotifier: startSession() → load due words → create session → filter AI-ready items
- [x] ReviewNotifier: submitAnswer() → AI evaluation → MemoryService → update MemoryState → save ReviewResult
- [x] ReviewNotifier: nextWord() → advance or complete session
- [x] features/review/screens/review_screen.dart — full 7-phase UI (loading, empty, answering, evaluating, showResult, complete, error)
- [x] Score breakdown display + memory strength delta indicator

### Phase 10 — Design System Polish

- [x] app_theme.dart — FilledButton, OutlinedButton, ListTile, PopupMenu 전역 테마 추가
- [x] shared/widgets/memory_indicator.dart — MemoryIndicator (색상 막대) + MemoryStrengthDelta (이전→이후)
- [x] shared/widgets/vocabulary_card.dart — VocabularyCard (MemoryIndicator 통합, AI 로딩 스피너)
- [x] shared/widgets/feedback_card.dart — FeedbackCard (피드백 + weakPoint 하이라이트)
- [x] MemoryStateRepository.getAll() — 인터페이스 + Supabase 구현 추가
- [x] memoryStatesMapProvider — vocabulary_providers.dart에 Map<String, MemoryState> 프로바이더 추가
- [x] VocabularyListScreen — VocabularyCard 통합, memoryStrength 연동, _WordTile 제거
- [x] ReviewScreen — AnimatedSwitcher (250ms) 페이즈 전환, FeedbackCard + MemoryStrengthDelta 공유 위젯 사용
- [x] WordDetailScreen — BorderRadius.circular(12) → AppRadius.mediumBorder 토큰 적용

### Phase 11 — Testing & Hardening

- [x] widget_test.dart — 5개 테스트 추가 (AddWordScreen 2개, VocabularyListScreen 1개, WordDetailScreen 2개)
- [x] AddWordScreen: 폼 필드 렌더링 + 빈 입력 시 유효성 검사 오류 표시
- [x] VocabularyListScreen: 단어 카드 렌더링 (memoryStatesMapProvider 오버라이드)
- [x] WordDetailScreen: AI 콘텐츠 표시 + "Word not found" 케이스
- [x] 에러 핸들링 검토:
  - Repository 예외 → Riverpod AsyncError / ReviewPhase.error / SnackBar ✓
  - AI 서비스 non-200 응답 → 명시적 Exception 발생 ✓
  - generateExplanation 실패 → fire-and-forget `.ignore()` (단어는 저장됨) ✓
  - Auth 만료 → Supabase 자동 갱신 + GoRouter auth guard 리다이렉트 ✓
  - completeSession 실패 → 의도적으로 무시 (비중요) ✓

---

## Verification (2026-10-06)

```
dart format lib/ test/       → 48 files formatted, no changes
flutter analyze              → No issues found
flutter test                 → 33/33 tests passed
  - 25 unit tests (MemoryService)
  - 8 widget tests (Login, VocabularyList×2, AddWord×2, WordDetail×2, Review)
```

---

## Phase Log

| Phase | Status | Notes |
|-------|--------|-------|
| 0 — Bootstrap | **Complete** | |
| 1 — Core Infrastructure | **Complete** | |
| 2 — Database Migrations | **Complete** | 5 migration files, all with RLS |
| 3 — Domain Layer | **Complete** | 25/25 tests pass |
| 4 — Data Layer | **Complete** | |
| 5 — Auth Feature | **Complete** | Login, signup, profile setup |
| 6 — Vocabulary Feature | **Complete** | List, add, detail, delete |
| 7 — AI Explanation | **Complete** | 2 Edge Functions + 2 Flutter services |
| 8 — Review Feature | **Complete** | Full session lifecycle + memory update |
| 9 — Voice Input | Deferred | STT service not decided |
| 10 — Design Polish | **Complete** | Shared widgets, AnimatedSwitcher, design tokens |
| 11 — Testing | **Complete** | 33/33 tests, error handling review |
| 12 — Stabilization pass | **Complete** | 2026-11-09, see below |

---

## Phase 12 — Stabilization pass (2026-11-09)

Bugs were reproduced with tests first (9 of 10 new review-flow tests failed
on the old code), then fixed.

### Data integrity / security
- [x] Sign-out or account switch no longer shows the previous user's cached
      words/decks/progress (`CacheService.bindToUser`, `currentUserIdProvider`;
      user-scoped notifiers rebuild; stale background syncs are discarded via
      `BuildGeneration`)
- [x] Migration `20261109000001`: `review_results.question_type` accepted
      neither `meaning` (leftover `question_type_valid` constraint) nor
      `knowledge` ("I don't know")
- [x] Edge Functions resolve the real user (`_shared/auth.ts`);
      `generate-explanation` only reads/writes the caller's own row (it used
      the service role on any `vocabulary_id`) and validates the AI output

### Review flow
- [x] Phase guards: double taps no longer skip words or trigger duplicate AI
      evaluations; fading-out views ignore taps
- [x] History inserts are best-effort; a DB rejection no longer kills the
      session; failed AI steps can be retried or skipped instead of
      restarting the whole session
- [x] Words without AI content get it generated before evaluation
      (previously `evaluate-answer` returned 400)
- [x] Dashboard/deck memory data is updated after every review
- [x] Resume: correct totals, graded word not asked again, progress actually
      saved on close (`ref` was used in `dispose`, which always threw)
- [x] Review order: weakest words were sent to the low-priority tier
      (`1 - strength`); ordering moved to `ReviewQueueBuilder` (domain, tested)
- [x] Voice mode: "don't know" looped forever; outgoing views wiped the new
      view's callbacks; know/don't-know buttons threw a layout exception
- [x] Result screen shows a meaningful breakdown (meaning, translation, word
      usage, grammar, naturalness) and the score actually used for scheduling
- [x] Translation exercise is prefetched while the learner types the meaning;
      memory state + history are saved in parallel

### Vocabulary / decks
- [x] AI content status (generating/failed) is tracked per word with retry
      buttons instead of endless spinners; concurrent requests are deduplicated
- [x] Editing a word's spelling/language regenerates its explanation;
      edit screen no longer crashes on languages outside the list
- [x] Duplicate words/decks give friendly messages (DB unique violations were
      shown raw); words added to a deck default to the deck's language
- [x] Background sync replaces stale cached data; deck word counts and
      "recent" ordering are derived locally (the deck list no longer downloads
      the whole review history)
- [x] Deleting a deck removes its (cascade-deleted) words locally

### UX
- [x] All screens localized (en/ko); no more Korean-only dialogs in the
      English UI or English-only dashboard in the Korean UI
- [x] Friendly error messages everywhere (`friendlyErrorMessage`)
- [x] Login/sign-up validation; accounts without a profile are routed to
      profile setup; "Edit profile" works; sign-out always confirms
- [x] "All words" screen (`/words`) so words outside decks are reachable
- [x] l10n now generated into `lib/l10n` (`synthetic-package: false`)

### Verification (2026-11-09)

```
dart format lib test   → formatted
flutter analyze        → No issues found
flutter test           → 94/94 passed (was 40/42)
tsc --strict (Edge Functions, Deno shim) → OK
```

### Follow-ups (need project access)
- `supabase db push` for migration `20261109000001`
- `supabase functions deploy generate-explanation evaluate-answer generate-question`
- Confirm the `evaluate-answer` model id (`gpt-5.6-luna`) exists for the account

## Phase 14 — App logo (2026-11-12)

New logo from `assets/logo/logo.svg` + `assets/logo/icon.png`.

- [x] Launcher icons (Android + iOS) regenerated from `icon.png`: corners
      filled (source had black corners and edge specks), Android adaptive
      foreground fitted to the 66/108 safe zone with no extra inset, themed
      (monochrome) icon added; adaptive background `#FDFAFA` (icon's own
      background)
- [x] In-app `BrandMark` now draws the book symbol from the SVG paths;
      `BrandWordmark` / new `BrandLockup` use the logotype (Nunito Black,
      bundled, SIL OFL); `BrandPulse` animates the recall arc
- [x] Sign-in leads with the stacked logo; sign-up / profile setup show the
      mark above the title; dashboard app bar and hero, settings footer and
      session-complete screen use the new mark
- [x] Verified with rendered previews; `flutter analyze` clean,
      `flutter test` 132/132

### Follow-ups
- Android/iOS native splash is still white (consider flutter_native_splash
  with the mark on `#FDFAFA`)
- Web / Windows / macOS icons are still the Flutter defaults

## Phase 13 — Visual redesign: "brand intersection" (2026-11-09)

Whole-app UI/UX redesign on the huemint palette
`#FFFDFC · #4E3029 · #B23B40 · #73C09C` (see docs/DESIGN_SYSTEM.md).

- [x] Tokens: paper/cocoa/crimson/mint + derived surfaces, text, tones
      (`AppTone`), memory scale crimson → ochre → lichen → mint
- [x] Typography: bundled Fraunces serif for words/numerals; component
      themes derive text styles from the merged text theme
- [x] Full component theme (pill buttons, filled inputs, nav bar, chips,
      sheets, dialogs, snackbars, slider, radio, tooltips)
- [x] New shared components: BrandMark/BrandPulse, AppEmptyState, AppNotice,
      ScoreRing, SectionLabel, TagPill, word-content widgets
- [x] Login/sign-up/profile setup on a shared `AuthScaffold` with the brand
      mark; dashboard cocoa hero with due count, serif stats and a
      "memory health" distribution bar; deck/word lists as sand cards with
      language-coded avatars; extended FABs hidden while lists are empty
- [x] Review: progress bar in the app bar, centred flash card, "know / don't
      know" as mint / crimson tiles, pinned primary actions, animated score
      ring with verdict, brand-mark loading state
- [x] Review options moved from a dialog to a bottom sheet
- [x] New strings (en/ko): greetingName, dueNowLabel, memoryHealth,
      addFirstWord, addWordHelper, answerIncorrect, verdictPass, verdictFail

### Verification (2026-11-09)

```
dart format lib test   → formatted
flutter analyze        → No issues found
flutter test           → 132/132 passed (after concurrent behavioural fixes)
```

Rendered previews of every main screen with the real theme and fonts were
reviewed (fixed: button/app-bar text losing the font family, collapsed
memory-health bar, missing IPA glyphs in the serif, invisible hero icon).

### Follow-ups
- ~~Regenerate launcher icons~~ — done in Phase 14
- Android/iOS native splash still white

## Phase 12b — Fixes from an independent review (2026-11-09)

An independent read-only review of Phase 12 found 12 issues; each was
verified against the code (and library sources) and fixed with a regression
test.

- [x] An offline token-refresh failure (gotrue emits it as a stream *error*
      while keeping the session) was read as "signed out": the cache was
      wiped and the user sent to first-run profile setup. `currentUserProvider`
      now reads gotrue's `currentUser`.
- [x] Router: a failed or reloading profile fetch (which still carries the
      signed-out `null`) no longer counts as "missing profile";
      `/profile-setup` requires a session.
- [x] Review screen: outgoing views are no longer remounted on every
      transition (voice views re-spoke words, fields re-grabbed focus) —
      shared `PhaseSwitcher` layout; also used by the word-added screen.
- [x] Voice yes/no: "I don't know", "모르겠어요", "不知道", "no sé" were read as
      "yes" (substring match) → `parseKnowsWordAnswer` checks negations first.
- [x] Voice: the previous step's transcript could be submitted as the next
      answer (cleared when a new prompt is spoken).
- [x] Renaming a word while its explanation was generating kept the old
      word's content (forced regeneration now runs after the pending one;
      the Edge Function skips the write if the word changed).
- [x] A single failed profile fetch broke reviews and AI generation until
      restart (`readNativeLanguage` falls back to the default and retries).
- [x] Saving the edit screen could wipe AI content that arrived after it
      opened; its delete button stayed disabled on first load; deleting left
      a lone page outside the tab shell.
- [x] Closing the review screen while AI content was generating threw
      "used after dispose"; dismissing the resume dialog with Back deleted
      the saved progress; a double tap on "Practice now" requested two
      exercises.

### Verification (2026-11-09, after Phase 12b and Phase 13)

```
flutter analyze        → No issues found
flutter test           → 132/132 passed
tsc --strict (Edge Functions, Deno shim) → OK
```
