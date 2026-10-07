# UnEbb Database Specification

## Database

PostgreSQL via Supabase.

All user-owned tables must use Row Level Security.

---

# Profiles

Extends Supabase Auth user information.

```text
profiles

id                  uuid PK
display_name        text
native_language     text
learning_language   text
created_at          timestamptz
updated_at          timestamptz
```

`id` references `auth.users.id`.

---

# Vocabulary Items

Stores vocabulary registered by users.

```text
vocabulary_items

id                  uuid PK
user_id             uuid FK
word                text
language            text

definition           text
explanation          text

created_at           timestamptz
updated_at           timestamptz
```

Index:

```text
(user_id)
(user_id, word)
```

---

# Memory States

Stores the current memory state for each vocabulary item.

```text
memory_states

id                    uuid PK
user_id               uuid FK
vocabulary_id         uuid FK UNIQUE

memory_strength       double precision
recall_probability    double precision

stage                  integer

last_reviewed_at       timestamptz
next_review_at         timestamptz

review_count           integer
correct_count          integer
incorrect_count        integer
consecutive_correct    integer

created_at             timestamptz
updated_at             timestamptz
```

Constraints:

```text
memory_strength:
0.0 <= value <= 1.0

recall_probability:
0.0 <= value <= 1.0

stage:
1 <= value <= 4
```

---

# Review Sessions

Represents a learning session.

```text
review_sessions

id
user_id

started_at
completed_at

total_items
completed_items
```

---

# Review Results

Every recall attempt must be stored.

This table represents the historical learning log.

```text
review_results

id
user_id
session_id
vocabulary_id

answer_type
user_answer

meaning_score
usage_score
example_score
grammar_score
overall_score

feedback
weak_point

previous_memory_strength
updated_memory_strength

reviewed_at
```

`answer_type`:

```text
text
voice
```

---

# Important Data Principle

`memory_states` represents:

CURRENT STATE

while:

`review_results` represents:

HISTORY

Never overwrite historical review results.

Example:

```text
Vocabulary
    │
    ├──── MemoryState
    │
    │     current memory
    │
    └──── ReviewResults
          │
          ├── Review #1
          ├── Review #2
          ├── Review #3
          └── Review #4
```

This historical data will later be used for personalized memory modeling.

---

# Row Level Security

Users may only access records where:

```sql
auth.uid() = user_id
```

Apply appropriate RLS policies to all user-owned tables.

Users must never be able to read or modify another user's learning data.

---

# AI Data Flow

```text
User Answer
     ↓
Flutter
     ↓
Supabase Edge Function
     ↓
OpenAI API
     ↓
Structured Evaluation
     ↓
Validate Response
     ↓
Memory Model
     ↓
Update memory_states
     +
Insert review_results
```

The evaluation result must be validated before database persistence.

---

# Future Personalization

Review history must be retained because future versions may estimate:

- personalized forgetting rate
- word difficulty
- user-specific memory decay
- optimal review intervals
- learning patterns

Therefore historical learning data must not be discarded even when the current MemoryState changes.