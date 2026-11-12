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

### Palette — "brand intersection"

Source: huemint brand-intersection palette
(`#FFFDFC · #4E3029 · #B23B40 · #73C09C`). Every brand colour has one job:

| Token     | Hex       | Role |
|-----------|-----------|------|
| `paper`   | `#FFFDFC` | Page background |
| `cocoa`   | `#4E3029` | Ink: text, primary buttons, selected nav, dark hero surfaces |
| `crimson` | `#B23B40` | The *ebb*: forgetting, mistakes, errors, "I don't know" |
| `mint`    | `#73C09C` | The *flow*: recall, success, strong memory, "I know it" |

Derived tokens (all in `lib/core/theme/app_colors.dart`):

- Surfaces: `surface` (sand `#F7F1EE`, cards), `surfaceElevated`
  (`#EFE6E2`, tracks/pills), `outline`, `outlineStrong`
- Text: `textPrimary` = cocoa (11.7:1 on paper), `textSecondary`
  (`#806964`, 5.0:1), `textMuted` (`#9A8580`, incidental text only)
- Soft tints for tone backgrounds: `crimsonSoft`, `mintSoft`, `ochreSoft`
- Text-safe accents: `mintDeep` (`#2F7D5A`) — mint itself is only 2.1:1 on
  paper, so never use `mint` for text; put cocoa on mint fills instead
- `ochre` (`#D08A3C`) is the single hue added to the palette, for
  "needs attention" (warnings, weak memory); `ochreDeep` carries text
- Memory stages run ebb → flow: critical `crimson` → weak `ochre` →
  good `lichen` (`#A3B46B`) → strong `mint`

Semantic tones (`AppTone`: neutral / success / warning / error) map to a
soft background, a strong fill and a readable foreground. Use them for
notices, badges and status visuals instead of picking colours ad hoc.

### Brand mark

Source artwork: `assets/logo/logo.svg` (vector) and `assets/logo/icon.png`
(the designer's raster). An open book with a cocoa cover: the crimson page carries ✕
(forgetting), the mint page ✓ (recall), and an arc fading crimson → mint
joins them — memory moving from ebb to flow. The logotype "UnEbb" is set in
Nunito Black: "Un" in cocoa, "Ebb" in crimson.

In the app (`lib/shared/widgets/brand_mark.dart`):

- `BrandMark` — the symbol, drawn from the SVG paths (no SVG dependency).
  `onDark: true` gives a paper cover with the rim knocked out to cocoa.
- `BrandWordmark` — optional mark + logotype (light crimson "Ebb" on dark).
- `BrandLockup` — mark stacked above the logotype, as in `logo.svg`.
- `BrandPulse` — loading state: the arc lights up segment by segment,
  ebb → flow; static under reduced motion.

Never crop the logo or recolour its pages. Logo-only colours live in
`AppColors.logoArcEbb`, `logoArcMid` and `logoCheck`.

The dashboard app bar shows the logotype alone (`showMark: false`).

The app icon is the symbol only, with no logotype: the name is already shown
under the icon on the home screen. `tool/generate_app_icons.py` renders
`assets/logo/app_icon*.png` from `logo.svg` without its tile and wordmark:
the mark on paper (`#FFFDFC`) for iOS/legacy Android, a transparent Android
adaptive foreground fitted inside the 66dp safe zone, and a monochrome layer
(paper parts knocked out) for themed icons. Then
`dart run flutter_launcher_icons` writes the platform icons.

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

Two voices:

- **Serif — Fraunces** (bundled, SIL OFL, `assets/fonts`): the things you
  learn. Vocabulary words and big numerals

  fall back to the platform font.
- **Platform sans**: the interface — headings, labels, body copy, and IPA
  pronunciation (Fraunces has no IPA glyphs). Keeps Hangul and Latin
  consistent in every locale.

Section kickers use `eyebrow` (small, tracked, uppercased via
`SectionLabel`).

Component themes (buttons, app bar, dialogs…) must take their text styles
from the merged `ThemeData.textTheme`, not raw `AppTypography` constants:
those components replace the inherited style, so a raw constant loses the
platform font family.

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

Implemented shared components (`lib/shared/widgets`): `BrandMark`,
`AppEmptyState` / `ToneBadge`, `AppNotice`, `ScoreRing`, `SectionLabel`,
`TagPill`, `MemoryIndicator` / `MemoryStrengthDelta`, `VocabularyCard`,
`FeedbackCard`, `QuoteList` / `WordChips` / `MistakeList` (word content).

Shape: interactive controls are pills (`StadiumBorder`); cards use
`AppRadius.large` (20); the review flash card uses `xLarge` (28). Surfaces
are flat — colour and spacing carry hierarchy, not shadows or borders.

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