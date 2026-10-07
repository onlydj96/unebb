# AI Evaluation Specification

## Purpose

OpenAI API is used to evaluate how well a user understands a vocabulary item and to generate learning feedback.

UnEbb is NOT an AI agent system.

The LLM is used only for specific inference tasks and does not control application behavior.

---

## LLM Responsibilities

The LLM may:

- evaluate semantic understanding of a word
- evaluate usage understanding
- evaluate user-created examples
- identify misunderstandings
- identify weak points
- generate concise learning feedback
- generate example sentences
- explain vocabulary usage

The LLM must NOT:

- determine review schedules
- calculate memory strength
- modify memory state
- control application state
- execute autonomous actions
- operate an agent loop

---

## Evaluation Input

The backend provides:

- vocabulary word
- reference definition
- reference usage
- user answer
- answer type
- previous weak points when available

Example:

```json
{
  "word": "ambiguous",
  "definition": "having more than one possible meaning",
  "user_answer": "Something that is unclear or can mean different things.",
  "answer_type": "text"
}
```

Voice answers must first be converted to text before evaluation.

---

## Evaluation Dimensions

The LLM evaluates:

### meaningScore

Does the user understand the core meaning?

Range:

0.0 - 1.0

### usageScore

Does the user understand when and how the word is used?

Range:

0.0 - 1.0

### exampleScore

If an example is provided, is it semantically appropriate?

Range:

0.0 - 1.0

### grammarScore

Is the user's usage grammatically valid?

Range:

0.0 - 1.0

### overallScore

Overall semantic understanding.

Range:

0.0 - 1.0

---

## Required Structured Output

All evaluation responses must use structured output.

Example:

```json
{
  "meaning_score": 0.90,
  "usage_score": 0.80,
  "example_score": 0.70,
  "grammar_score": 0.85,
  "overall_score": 0.84,
  "feedback": "You understand the core meaning well.",
  "weak_point": "collocation"
}
```

Do NOT rely on parsing arbitrary natural-language responses.

---

## Stage Responsibility

The LLM should NOT determine the user's final memory stage.

Instead:

```text
OpenAI API
    ↓
Evaluation Scores
    ↓
Application Logic
    ↓
Memory Model
    ↓
Memory Strength
    ↓
Stage
    ↓
Next Review
```

Stage calculation belongs to the Memory Model.

---

## Learning Feedback

Feedback should be:

- concise
- educational
- specific to the user's mistake
- focused on understanding rather than translation matching

Example:

User answer:

> "Ambiguous means difficult."

Feedback:

> "Ambiguous does not mean difficult. It describes something unclear or open to more than one interpretation."

---

## Evaluation Principle

Evaluation must focus on semantic understanding.

Do NOT require the user to reproduce the dictionary definition exactly.

For example:

Reference:

> having more than one possible meaning

User:

> Something that can be understood in different ways.

This should be considered strong understanding.

---

## Architecture

```text
Flutter
   ↓
Backend API
   ↓
Prompt Builder
   ↓
OpenAI API
   ↓
Structured Evaluation
   ↓
Backend Validation
   ↓
Memory Model
   ↓
Database
   ↓
Flutter
```

OpenAI API keys must never be stored in the Flutter application.

All production OpenAI API requests must be made through the backend.

---

## Core Principle

The LLM evaluates learning.

The application controls learning state.

The Memory Model controls review scheduling.