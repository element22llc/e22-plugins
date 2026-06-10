# Build status — [Product name]

> `/e22-build` flow state. Claude updates this at every step transition and
> commits it with the work. A fresh session reads this **first** and resumes
> from **Current step** — never restart the interview or re-ask settled
> questions.

## Current step

[N — step name from `/e22-build`, e.g. "6 — building feature by feature"]

## Features

| Feature | Intent (step 4)  | Built (step 6) | Demo validated (step 9) |
| ------- | ---------------- | -------------- | ----------------------- |
| [id]    | draft / approved | no / yes       | no / yes (date)         |

## Handoff gate

- [ ] All approved intents built and demoed to the PO
- [ ] PO explicitly confirmed the app does what they wanted (step 9 gate)
- [ ] Definition of Done holds (tests, contracts, high-risk choices recorded)
- [ ] `PRODUCTIONIZATION.md` written — stubs, provisional high-risk choices, and what the dev must harden
- [ ] PR proposed/opened: [link]

## Notes / blockers

- [Work in flight, awaiting PO answers, known gaps]
