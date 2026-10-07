# AGENT.md

# UnEbb Development Rules

## Mission

Build an AI-powered adaptive vocabulary learning application.

The core product value is personalized memory retention,
not simply vocabulary storage.

---

## Before Starting Any Task

Read:

1. docs/PRODUCT.md
2. docs/ARCHITECTURE.md
3. docs/DOMAIN.md

When working on memory logic also read:

docs/MEMORY_MODEL.md

When working on AI features also read:

docs/AI_EVALUATION.md

Then read:

tasks/PLAN.md
tasks/PROGRESS.md

Inspect existing implementation before creating new code.

---

## Development Loop

For every task:

OBSERVE
→ PLAN
→ IMPLEMENT
→ FORMAT
→ ANALYZE
→ TEST
→ VERIFY
→ UPDATE PROGRESS

Never skip verification.

---

## Flutter Rules

Use Dart null safety.

Prefer immutable models.

Do not place business logic inside Widgets.

Widgets should primarily handle rendering and user interaction.

Use Riverpod for application state.

Use GoRouter for navigation.

Avoid unnecessary global state.

Prefer small reusable widgets.

Do not create duplicate models.

---

## Architecture Rules

Dependencies must flow:

Presentation
↓
Domain
↓
Data

Presentation must not directly access external APIs.

Repositories abstract external data sources.

Memory algorithms belong in domain services.

AI communication belongs in the AI evaluation data layer.

---

## AI Rules

LLM responses must use structured output.

Never rely on parsing free-form LLM text for application logic.

LLM evaluates understanding.

LLM does NOT determine review schedules.

Review scheduling must be deterministic and testable.

Never expose API keys in Flutter source code.

Production LLM calls must go through a backend service.

---

## Testing Rules

Every domain algorithm requires unit tests.

Memory scheduling tests must cover:

- correct answer
- incorrect answer
- repeated correct answers
- long inactivity
- new vocabulary
- boundary memory scores

AI response parsing requires tests.

Repository implementations require tests where practical.

---

## Verification

Before completing a task run:

flutter format .
flutter analyze
flutter test

If verification fails:

1. inspect the actual error
2. identify root cause
3. fix the implementation
4. rerun verification

Do not suppress analyzer errors merely to make verification pass.

---

## Security

Never commit:

- OpenAI API keys
- database secrets
- service role keys
- private credentials

Secrets must be stored server-side.

---

## Completion Definition

A task is complete only when:

- implementation matches requirements
- architecture rules are followed
- tests pass
- flutter analyze passes
- relevant documentation is updated
- tasks/PROGRESS.md is updated


## Design Rules

Before implementing or modifying UI, read:

`docs/DESIGN_SYSTEM.md`

Follow the shared design system.

Do not hardcode visual values inside feature screens when an existing design token is available.

Prefer existing shared components before creating new ones.

Do not duplicate visually equivalent components.

New reusable visual patterns should be added to the design system.

Feature-specific UI may remain inside its feature when it is not reusable.

Visual changes must not introduce business logic into widgets.

Maintain clear separation between:

Design Tokens
→ Shared Components
→ Feature Components
→ Screens

The application should maintain a modern consumer-app visual style while preserving architectural consistency and maintainability.


## Supabase Rules

Supabase is the backend platform for UnEbb.

Use Supabase for:

- Authentication
- PostgreSQL database
- Row Level Security
- Storage
- Edge Functions

All user-owned tables must use Row Level Security.

Flutter may directly access normal user-owned data through the Supabase client when protected by RLS.

Sensitive operations must use Supabase Edge Functions.

OpenAI API calls must always go through Edge Functions.

Never expose OpenAI API keys or Supabase service role keys in Flutter.

Keep Supabase implementation details behind repository abstractions whenever practical.

Database schema changes must be implemented through migrations.

Do not manually change production database structure without a corresponding migration.