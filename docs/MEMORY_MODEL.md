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