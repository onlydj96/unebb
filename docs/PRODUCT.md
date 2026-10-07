# UnEbb Product Specification

## Product Vision

UnEbb is an AI-powered adaptive vocabulary learning application.

The application helps users retain vocabulary by estimating
their memory state and scheduling reviews before words are forgotten.

The system is inspired by the Ebbinghaus forgetting curve,
but review intervals must adapt to each user's actual performance.

## Core Principle

Do not simply show vocabulary repeatedly.

The system must:

1. estimate understanding
2. estimate memory strength
3. predict forgetting
4. schedule reviews
5. test recall
6. analyze answers
7. update memory state

## Core Learning Loop

Word Registration
→ Learn
→ Recall Test
→ AI Evaluation
→ Memory Update
→ Review Scheduling
→ Recall Test
→ Repeat

## MVP Features

### Vocabulary

Users can:

- add words
- edit words
- delete words
- organize words
- see learning status

### AI Explanation

For each word AI can generate:

- definition
- Korean explanation
- usage
- example sentences
- common mistakes
- synonyms
- collocations

### Recall Test

The app asks:

"Explain this word in your own words."

Users can answer using:

- text
- voice

### AI Evaluation

The AI evaluates:

- meaning understanding
- usage understanding
- example quality
- grammar
- confidence

### Memory Stage

Stage 1 — Well Known

Stage 2 — Mostly Known

Stage 3 — Vaguely Known

Stage 4 — Unknown

### Adaptive Review

Review scheduling should consider:

- memory stage
- previous reviews
- answer quality
- time since last review
- consecutive correct answers
- incorrect answers