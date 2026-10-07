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
