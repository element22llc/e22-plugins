---
type: llm
focus: last_message
weight: 4
---

The glossary defines a Cart as the shopper's selected line items **before
payment**. The ask uses "cart" for something already paid ("cart history", "a
cart they paid for"), which conflicts with that definition.

Pass if the response calls out that conflict: it says the glossary defines a
cart as unpaid (or before payment), points out that a paid cart contradicts
it, and asks which is meant or proposes a distinct term for the paid thing
(such as Order or Purchase) for the human to confirm. Asking this alongside
other questions is fine; drafting an intent is fine as long as the paid thing
is not settled as a "cart" without the question.

A closing `## Recommended next actions` block naming another skill is normal;
do not fail the response for it.

Fail it if it adopts "cart history" or a paid cart as if the glossary allowed
it, silently redefines Cart, or never mentions the conflict.
