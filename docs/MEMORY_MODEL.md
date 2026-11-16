# Memory Model

## Purpose

Estimate how likely a user is to remember a vocabulary item.

## Memory Strength

Range:

0.0 - 1.0

Example:

0.9 = strongly remembered
0.5 = unstable memory
0.2 = likely forgotten

## Memory Stage

Stage 1
memoryStrength >= 0.80

Stage 2
0.60 <= memoryStrength < 0.80

Stage 3
0.30 <= memoryStrength < 0.60

Stage 4
memoryStrength < 0.30

## Current Implementation (SM-2)

Pass/fail is decided by the meaning step alone. A recalled meaning is
always a pass; the translation step only sets the SM-2 grade (3–5), i.e.
how long the next interval is. See `ReviewNotifier._finalizeWord`.

Display strength comes from the SM-2 streak and interval
(`MemoryService.strengthFor`):

```text
sm2_repetitions = 0 → 0.0   (never recalled / last answer wrong)
otherwise           → 0.30 + 0.70 × ln(interval) / ln(60), max 1.0
```

| Recall in a row | Interval | Strength | Stage |
|---|---|---|---|
| 1 | 1 day | 0.30 | 3 (weak) |
| 2 | 6 days | 0.61 | 2 (good) |
| 3 | ~15 days | ~0.76 | 2 (good) |
| 4 | ~40 days | ~0.93 | 1 (strong) |

## Memory Update

Memory strength must be updated after every review.

Inputs:

- previous memory strength
- AI evaluation score
- response correctness
- elapsed time
- consecutive correct answers
- previous review count

## Initial MVP Scheduling

Stage 4:
review after 10 minutes

Stage 3:
review after 1 day

Stage 2:
review after 3 days

Stage 1:
review after 7 days

Successful reviews should progressively increase intervals.

Failed reviews should shorten intervals.

## Important

Do NOT treat the Ebbinghaus forgetting curve as a universal fixed curve.

The long-term goal is to estimate a personalized forgetting rate
for each user and vocabulary item.