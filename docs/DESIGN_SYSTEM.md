# UnEbb Design System

## Design Direction

UnEbb should feel modern, intelligent, calm and lightweight.

The product should look like a modern consumer application rather than a traditional educational application.

Avoid overly academic, childish, or gamified visual styles.

The design should emphasize:

- clarity
- focus
- memory
- progress
- intelligence
- subtle motion
- minimal interaction cost

---

## Visual Style

Use a modern minimal interface with:

- generous whitespace
- clear visual hierarchy
- large readable typography
- rounded surfaces
- subtle depth
- restrained gradients
- smooth micro-interactions
- minimal visual clutter

Avoid excessive borders and unnecessary containers.

Prefer spacing and typography for hierarchy.

---

## Design Tokens

All visual values must be defined as reusable tokens.

### Colors

Define semantic colors rather than using raw colors directly.

Examples:

```text
primary
secondary

surface
surfaceElevated

textPrimary
textSecondary
textMuted

success
warning
error

memoryStrong
memoryMedium
memoryWeak
memoryCritical
```

Do not directly use hex values inside feature screens.

---

## Typography

Typography should emphasize readability and hierarchy.

Define reusable styles such as:

```text
displayLarge
displayMedium

headingLarge
headingMedium
headingSmall

bodyLarge
bodyMedium
bodySmall

labelLarge
labelMedium
```

Vocabulary words may use larger typography than standard application content.

---

## Spacing

Use a consistent spacing scale.

Example:

```text
xs
sm
md
lg
xl
xxl
```

Feature screens should not introduce arbitrary spacing values unless necessary.

---

## Radius

Use a limited radius system.

Example:

```text
small
medium
large
xLarge
full
```

---

## Components

Prefer reusable design-system components.

Examples:

```text
AppButton
AppCard
AppTextField
AppBottomSheet
AppDialog
AppChip
AppProgressIndicator

VocabularyCard
MemoryIndicator
ReviewAnswerCard
FeedbackCard
```

Generic components belong to the design system.

Domain-specific reusable components may belong to their relevant feature.

---

## Motion

Motion should communicate state changes rather than exist only for decoration.

Use animation for:

- flash card transitions
- answer reveal
- memory strength changes
- progress updates
- review completion
- navigation transitions

Animations should remain subtle and responsive.

---

## Review Experience

The Review screen is the primary experience of UnEbb.

It should minimize distraction and focus attention on one vocabulary item at a time.

Example:

```text
          ubiquitous

     Explain this word
      in your own words


     ┌──────────────────┐
     │                  │
     │   Your answer    │
     │                  │
     └──────────────────┘

        🎙 Speak

        Check answer
```

After evaluation:

```text
          ubiquitous

          84%

       Strong recall

 ┌────────────────────────┐
 │ You understand the     │
 │ meaning well.          │
 │                        │
 │ Weak point             │
 │ → usage / collocation  │
 └────────────────────────┘

       Continue →
```

---

## Maintainability

Visual trends will change.

Therefore the implementation must allow the visual language of UnEbb to evolve without rewriting feature logic.

Changing:

- primary color
- typography
- radius
- spacing
- card style
- animations

should primarily require changes inside the design system rather than individual feature screens.

## Core Principle

Trendiness belongs to the visual layer.

Stability belongs to the architecture.

The two should evolve independently.