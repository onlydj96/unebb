# Domain Model

## VocabularyItem

Represents one vocabulary item owned by a user.

Fields:

- id
- userId
- word
- language
- definition (nullable — AI generated)
- explanation (nullable — AI generated, Korean)
- usage (nullable — AI generated)
- examples (nullable — AI generated, list)
- synonyms (nullable — AI generated, list)
- collocations (nullable — AI generated, list)
- commonMistakes (nullable — AI generated, list)
- createdAt
- updatedAt

Note: User provides `word` and `language` only. All other fields are populated by the `generate-explanation` Edge Function.

## MemoryState

Represents the user's current memory state for a vocabulary item.

Fields:

- vocabularyId
- stage
- memoryStrength
- recallProbability
- lastReviewedAt
- nextReviewAt
- reviewCount
- correctCount
- incorrectCount
- consecutiveCorrect

## ReviewSession

Represents one learning session.

Fields:

- id
- startedAt
- completedAt
- vocabularyItems
- results

## ReviewResult

Represents one recall attempt.

Fields:

- vocabularyId
- userAnswer
- answerType
- aiEvaluation
- previousMemoryStrength
- updatedMemoryStrength
- reviewedAt

## AiEvaluation

Fields:

- meaningScore
- usageScore
- exampleScore
- grammarScore
- overallScore
- feedback
- weakPoint (nullable)

Note: `stage` is NOT a field on AiEvaluation (DECISION-3). The LLM does not determine stage.
Stage is always derived by `MemoryService.stageFromStrength(memoryStrength)` after the evaluation.