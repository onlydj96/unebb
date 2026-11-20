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

### Scheduling (`MemoryService.applySmTwo`)

| Answer | Word | Effect |
|---|---|---|
| wrong | any | repetitions 0, interval 1 day. The ease factor drops only on a **lapse** (the word had been recalled); a miss while the word is still learnt (new, or last answer wrong) leaves it |
| correct | still learning (repetitions 0) | first recall: repetitions 1, interval 1 day — even before its due day, so a word missed in the morning and recalled in the evening is learnt |
| correct | due | repetitions + 1; interval 6 days after the first recall, then round(interval × EF) |
| correct | recalled, not due yet | counted, schedule unchanged: repeated "review all" sessions on one day cannot push a word up |

EF = max(1.3, EF + (0.1 − (5 − grade)(0.08 + (5 − grade) × 0.02))).

Intervals count **learning days**: a word is due from 04:00 local time of
its due day (`MemoryService.dueAfter`), so reviewing a little earlier than
yesterday still finds it due, and a review just after midnight belongs to
the evening before.

### What the learner sees (`MemoryService.readingOf`)

| Level | When | Strength |
|---|---|---|
| learning (학습 중) | reviewed, never recalled — nothing to forget yet | none (0) |
| critical (위험) | recalled before, last answer wrong — or faded far past due | 0 – 0.30 |
| weak (약함) | recalled, overdue and fading | 0.30 – 0.60 |
| good (양호) | recalled, interval under 21 days, not long overdue | 0.60 – 0.80 |
| strong (강함) | recalled, interval 21 days or more, not long overdue | 0.80 – 1.0 |

A correct answer always leaves a word good or strong. Right after a recall
the strength is `peakStrength(interval)` (log scale, so every recall moves
it):

| Recall on schedule | Interval | Strength | Level |
|---|---|---|---|
| 1 | 1 day | 0.70 | good |
| 2 | 6 days | 0.76 | good |
| 3 | ~15 days | 0.79 | good |
| 4 | ~40 days | 0.85 | strong |
| … | 1 year+ | 1.0 | strong |

21 days is the usual "mature" threshold of spaced repetition. The
strength holds through the end of the due day (reviewing any time that
day is on time), then decays along the forgetting curve SM-2 schedules
by, R(t) = 0.9^(t / interval): ×0.9 per interval overdue, ×0.59 after
five, ×0.35 after ten. A word recalled once becomes weak about two days
after its due day and critical after about nine; a strong word takes
months. The strength depends on the current time, so it is computed on
the client (`clockProvider` ticks every minute) and never stored;
`memory_strength` / `stage` hold the value right after the last review.
Percentages are shown rounded down, so a word at 0.799 reads 79% (good),
never 80%.

The review queue orders reviewed words by this current strength (plus
miss ratio and overdue days), not by the stored one.

A review whose save fails (offline, server error) is kept in a local
queue, shown in place of the server's copy, and saved by the next
memory-state sync (app start, resume, reconnect, review start,
pull-to-refresh). It is only written if the server has no newer review of
that word (`last_reviewed_at`), so it never overwrites another device.

### Taking back an answer (`ReviewNotifier.undo`)

The review screen's undo button (↶, app bar) takes back the learner's last
choice: a wrong button, a typo, a misheard voice answer, "next" tapped too
early.

| From | Back to |
|---|---|
| meaning input | "Do you know this word?" (nothing graded yet) |
| translation input | meaning input, answer kept; the same exercise follows |
| result / explanation / "not quite" / writing practice | the step the answer was given on, with the answer in the field |
| next word, before it is answered | the previous word, same as above |

A taken-back review restores the word's memory state from before it (and
the session's correct count). Saves of one word are chained, so the undo
never overtakes the review it takes back; a review waiting in the offline
queue is removed from it. If the undo itself cannot be saved, the server
keeps the review until the word is answered again — the learner is on it.

Only the last graded answer can be taken back: answering the next word
makes it final. Its `review_results` row and detected error patterns are
recorded only then (or when the session ends, the app goes to the
background or the screen closes), so a slip never reaches the history.
Taken back after the app went to the background, its row stays.

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