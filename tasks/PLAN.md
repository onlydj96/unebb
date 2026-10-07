# UnEbb Implementation Plan

## Guiding Principles

- Domain layer must be free of Flutter and Supabase imports.
- Memory algorithm logic lives in `domain/services/` and must be fully unit-tested.
- AI evaluation always goes through Edge Functions — never direct OpenAI from Flutter.
- Every schema change must be a migration file in `supabase/migrations/`.
- `flutter analyze` and `flutter test` must pass at each phase end.

---

## Phase 0 — Project Bootstrap

Goal: A Flutter project exists with the correct structure, dependencies, and conventions.

Tasks:
- [ ] `flutter create unebb` with package name `com.unebb.app`
- [ ] Add core dependencies to `pubspec.yaml`:
  - `supabase_flutter`
  - `flutter_riverpod` / `riverpod_annotation`
  - `go_router`
  - `freezed` / `freezed_annotation`
  - `json_serializable`
  - `build_runner` (dev)
  - `riverpod_generator` (dev)
  - `custom_lint` / `riverpod_lint` (dev)
- [ ] Create directory structure per `docs/ARCHITECTURE.md`
- [ ] Create `supabase/migrations/` directory
- [ ] Verify `flutter analyze` passes on empty scaffold

---

## Phase 1 — Core Infrastructure

Goal: App boots, Supabase is initialized, auth state is observable, navigation routes exist.

Tasks:
- [ ] Initialize Supabase client in `main.dart` (URL + anon key from env/config)
- [ ] Create `core/router/` with GoRouter and auth guard shell
- [ ] Create `core/theme/` with design token skeleton (colors, typography, spacing, radius)
- [ ] Create Riverpod auth state provider watching `supabase.auth.onAuthStateChange`
- [ ] Create placeholder screens: Login, Home, Review
- [ ] Verify navigation transitions between screens

---

## Phase 2 — Database Migrations

Goal: All tables exist in Supabase with correct schema and RLS policies.

Tasks:
- [ ] Write migration: `profiles`
- [ ] Write migration: `vocabulary_items` (with indexes on `user_id`, `(user_id, word)`)
- [ ] Write migration: `memory_states` (with constraints: strength 0.0–1.0, stage 1–4)
- [ ] Write migration: `review_sessions`
- [ ] Write migration: `review_results`
- [ ] Write RLS policies for all tables (`auth.uid() = user_id`)
- [ ] Review migrations with Supabase MCP before applying
- [ ] Apply migrations to Supabase project

---

## Phase 3 — Domain Layer

Goal: All domain models, repository interfaces, and the memory service exist with tests.

Tasks:
- [ ] Create Freezed models: `VocabularyItem`, `MemoryState`, `ReviewSession`, `ReviewResult`, `AiEvaluation`
- [ ] Create abstract repository interfaces: `VocabularyRepository`, `MemoryStateRepository`, `ReviewRepository`
- [ ] Create `MemoryService` with:
  - `updateMemoryStrength(...)` — update algorithm
  - `calculateNextReview(stage)` — scheduling
  - `stageFromStrength(strength)` — stage derivation
- [ ] Write unit tests for `MemoryService` covering all AGENT.md test cases
- [ ] Verify `flutter test` passes

---

## Phase 4 — Data Layer

Goal: Supabase repository implementations behind domain interfaces.

Tasks:
- [ ] Implement `SupabaseVocabularyRepository`
- [ ] Implement `SupabaseMemoryStateRepository`
- [ ] Implement `SupabaseReviewRepository`
- [ ] Register repositories as Riverpod providers
- [ ] Verify basic CRUD operations work against live Supabase

---

## Phase 5 — Auth Feature

Goal: Users can sign up, log in, and log out.

Tasks:
- [ ] Login screen (email + password)
- [ ] Sign-up screen
- [ ] Profile setup screen (display name, native language, learning language)
- [ ] GoRouter auth guard: redirect to login when unauthenticated
- [ ] On successful auth: create `profiles` row if not exists

---

## Phase 6 — Vocabulary Feature

Goal: Users can add, view, edit, and delete vocabulary words.

Tasks:
- [ ] Vocabulary list screen (shows words with memory stage indicator)
- [ ] Add word screen (word + language; triggers AI explanation generation)
- [ ] Word detail screen (shows AI-generated definition, explanation, examples)
- [ ] Edit word screen
- [ ] Delete word (with confirmation)
- [ ] On add: create `vocabulary_items` row + initial `memory_states` row (stage 4, strength 0.0)

---

## Phase 7 — AI Explanation Feature

Goal: AI generates explanation when a word is added.

Tasks:
- [ ] Create Supabase Edge Function: `generate-explanation`
  - Input: `{ word, language }`
  - Output: `{ definition, explanation, usage, examples, synonyms, collocations, common_mistakes }`
- [ ] Create `AiExplanationService` in `data/services/`
- [ ] Connect Add Word screen to Edge Function
- [ ] Handle loading and error states in UI

---

## Phase 8 — Review Feature

Goal: Users can complete a review session with AI evaluation.

Tasks:
- [ ] Review session screen (shows one word at a time)
- [ ] Text answer input
- [ ] Create Supabase Edge Function: `evaluate-answer`
  - Input: `{ word, definition, user_answer, answer_type, previous_weak_points? }`
  - Output: `{ meaning_score, usage_score, example_score, grammar_score, overall_score, feedback, weak_point }`
- [ ] Create `AiEvaluationService` in `data/services/`
- [ ] Evaluation result screen (score, feedback, weak point)
- [ ] Call `MemoryService.updateMemoryStrength()` with evaluation result
- [ ] Persist updated `memory_states` + new `review_results` row
- [ ] Review session completion screen

---

## Phase 9 — Voice Input (Deferred)

Goal: Users can answer using voice.

Status: Deferred until STT service decision is made. See `tasks/BACKLOG.md`.

---

## Phase 10 — Design System Polish

Goal: Full design token implementation, shared components, motion.

Tasks:
- [ ] Complete `AppTheme` with all tokens from `docs/DESIGN_SYSTEM.md`
- [ ] Build shared widgets: `AppButton`, `AppCard`, `AppTextField`, `AppBottomSheet`
- [ ] Build domain widgets: `VocabularyCard`, `MemoryIndicator`, `FeedbackCard`
- [ ] Add review screen animations (answer reveal, memory strength change)
- [ ] Audit all screens for hardcoded values — replace with tokens

---

## Phase 11 — Testing & Hardening

Tasks:
- [ ] Full unit test coverage for `MemoryService`
- [ ] Widget tests for critical screens
- [ ] Error handling review (network failures, Edge Function errors, auth expiry)
- [ ] Final `flutter analyze` clean pass
