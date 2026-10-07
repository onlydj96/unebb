# UnEbb Backlog — Open Decisions & Future Work

---

## CRITICAL — Must Resolve Before Implementation

These are specification gaps or conflicts that block implementation.

---

### [DECISION-1] Memory Strength Update Formula

**RESOLVED 2026-09-29** — Option D (custom formula):

```
target = isCorrect ? (0.5 + overallScore × 0.5) : (overallScore × 0.25)
strength = prev + (target − prev) × 0.35
if isCorrect && consecutiveCorrect > 1:
  strength += clamp((consecutiveCorrect − 1) × 0.02, 0.0, 0.08)
strength = clamp(strength, 0.0, 1.0)
```

Correct answer pulls strength toward [0.5, 1.0]; incorrect toward [0.0, 0.25].
Correctness threshold: overallScore >= 0.6.
MEMORY_MODEL.md updated.

---

### [DECISION-1-original] Memory Strength Update Formula

**Blocks**: Phase 3 (Domain Layer), specifically `MemoryService.updateMemoryStrength()`

**Problem**: `docs/MEMORY_MODEL.md` lists the inputs to the update function but provides no algorithm.

Inputs defined:
- previous memory strength
- AI evaluation score (overallScore)
- response correctness (correct / incorrect)
- elapsed time since last review
- consecutive correct answers
- previous review count

**Question**: What formula produces the new memory strength from these inputs?

**Options to consider**:
- A) Simple weighted average: `new = prev * decay + overall_score * weight`
- B) Additive correction: correct → `strength + delta`, incorrect → `strength - delta` (scaled by score)
- C) SM-2-style interval multiplier applied to strength
- D) Custom formula defined by the team

**Action required**: Define and document the formula in `docs/MEMORY_MODEL.md` before Phase 3 begins.

---

### [DECISION-2] `recall_probability` Purpose and Calculation

**RESOLVED 2026-09-29** — Option A (MVP): `recall_probability` is set equal to `memory_strength` at update time. Column is retained in DB to enable future Ebbinghaus time-decay (Phase 11+). Domain model keeps the field but it mirrors memory_strength for now.

---

### [DECISION-2-original] `recall_probability` Purpose and Calculation

**Blocks**: Phase 2 (migrations) and Phase 3 (domain model)

**Problem**: `docs/DATABASE.md` has a `recall_probability` column in `memory_states`, but `docs/MEMORY_MODEL.md` has no mention of it. It is unclear if this is distinct from `memory_strength` or how it is calculated.

**Question**: What is `recall_probability`?

**Options**:
- A) Alias for `memory_strength` — remove duplicate column
- B) A time-decayed probability calculated from `memory_strength` and `last_reviewed_at` (e.g. Ebbinghaus decay applied at query time)
- C) A separate stored value updated at each review

**Action required**: Define in `docs/MEMORY_MODEL.md` and align with `docs/DATABASE.md`.

---

### [DECISION-3] `AiEvaluation.stage` Field Conflict

**RESOLVED 2026-09-29** — Option A: `stage` removed from `AiEvaluation`. Stage is always derived by `MemoryService.stageFromStrength()`. DOMAIN.md updated.

---

### [DECISION-3-original] `AiEvaluation.stage` Field Conflict

**Blocks**: Phase 3 (domain model), Phase 8 (review feature)

**Problem**: `docs/DOMAIN.md` lists `stage` as a field on `AiEvaluation`. `docs/AI_EVALUATION.md` explicitly states:

> "The LLM must NOT determine review schedules" and "The LLM should NOT determine the user's final memory stage."

The structured output example in `docs/AI_EVALUATION.md` has no `stage` field.

**Question**: Should `AiEvaluation` have a `stage` field?

**Options**:
- A) Remove `stage` from `AiEvaluation` domain model — stage is always derived by `MemoryService` from the score (consistent with AI_EVALUATION.md)
- B) Keep `stage` as a computed field on the Flutter side after evaluation is received — not from the LLM
- C) Add a `suggestedStage` that the LLM proposes but the app may override

**Recommendation**: Option A — remove `stage` from `AiEvaluation`. Stage is calculated by `MemoryService`. `AiEvaluation` should only carry scores and feedback.

**Action required**: Update `docs/DOMAIN.md` to remove `stage` from `AiEvaluation`, or document explicitly what it represents.

---

### [DECISION-4] `VocabularyItem.definition` and `.explanation` Origin

**RESOLVED 2026-09-29**: All AI fields stored on `vocabulary_items` row as nullable columns. User provides only `word` + `language`; AI fills definition, explanation, usage, examples, synonyms, collocations, common_mistakes. No manual override in MVP. DOMAIN.md and DATABASE.md updated.

---

### [DECISION-4-original] `VocabularyItem.definition` and `.explanation` Origin

**Blocks**: Phase 6 (Vocabulary Feature), Phase 7 (AI Explanation)

**Problem**: `docs/DOMAIN.md` has `definition` and `explanation` as fields on `VocabularyItem`. It is unclear if these are:

- User-provided at word creation
- AI-generated when a word is added
- A mix (user types word, AI fills the rest)

**PRODUCT.md** says: "For each word AI can generate: definition, Korean explanation, usage, example sentences..."

**Questions**:
1. Are `definition` and `explanation` the only fields stored on `vocabulary_items`? Or are `usage`, `examples`, `synonyms`, `collocations`, `common_mistakes` also stored?
2. If AI generates them, are they stored on the `vocabulary_items` row or in a separate table?
3. Can a user manually override the AI-generated content?

**Action required**: Decide what AI-generated content is persisted and update `docs/DOMAIN.md` and `docs/DATABASE.md` accordingly.

---

### [DECISION-5] Edge Function API Contracts

**RESOLVED 2026-09-29**: Contracts finalised as in PLAN.md with error handling: `{ error: string }` on 400/500. Both functions validate input and return structured JSON.

---

### [DECISION-5-original] Edge Function API Contracts

**Blocks**: Phase 7 (AI Explanation), Phase 8 (Review Feature)

**Problem**: `docs/ARCHITECTURE.md` and `docs/AI_EVALUATION.md` specify that OpenAI calls go through Edge Functions, but no Edge Function signatures are defined.

**Functions needed**:

**`generate-explanation`**
- Request: `{ word: string, language: string }`
- Response: `{ definition, explanation, usage, examples[], synonyms[], collocations[], common_mistakes[] }`
- Error handling: ?

**`evaluate-answer`**
- Request: `{ word, definition, user_answer, answer_type, previous_weak_points? }`
- Response: `{ meaning_score, usage_score, example_score, grammar_score, overall_score, feedback, weak_point }`
- Error handling: ?

**Action required**: Define full request/response schemas and error codes before implementation.

---

## IMPORTANT — Should Resolve Before Related Phase

---

### [DECISION-6] Auth Methods

**RESOLVED 2026-09-29**: Email + password for MVP.

---

### [DECISION-6-original] Auth Methods

**Blocks**: Phase 5 (Auth Feature)

**Question**: What authentication methods does UnEbb support at MVP?

**Options**: Email + password, Magic link, Google OAuth, Apple Sign-In

**Action required**: Decide before implementing auth screens.

---

### [DECISION-7] Voice STT Service

**Blocks**: Phase 9 (Voice Input)

**Question**: Which STT service is used for voice answers?

**Options**:
- A) OpenAI Whisper via Edge Function (consistent with existing OpenAI usage)
- B) Device-native STT (Flutter `speech_to_text` package — free, offline, no extra backend)
- C) Third-party service

**Note**: Phase 9 is already deferred. Decision not urgent.

---

### [DECISION-8] `ReviewSession.vocabularyItems` Field Type

**RESOLVED 2026-09-29**: `List<VocabularyItem>` — full objects loaded at session start.

---

### [DECISION-8-original] `ReviewSession.vocabularyItems` Field Type

**Blocks**: Phase 3 (domain model)

**Question**: In the `ReviewSession` domain model, is `vocabularyItems` a `List<VocabularyItem>` (full objects loaded at session start) or `List<String>` (IDs fetched on demand)?

**Recommendation**: `List<VocabularyItem>` — load the session batch upfront for offline resilience.

---

## FUTURE — Post-MVP

These items are acknowledged but intentionally deferred.

- Personalized forgetting rate estimation (per MEMORY_MODEL.md "Important" note)
- Word difficulty estimation per user
- Learning statistics dashboard
- Export / import vocabulary
- Shared word lists
- Multiple languages per session
- Push notification review reminders
