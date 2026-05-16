---
paths:
  - "R/*.R"
  - "tests/**/*.R"
  - "DESCRIPTION"
  - "NAMESPACE"
  - "app.R"
  - "data-raw/**/*.R"
  - "inst/app/www/**/*.css"
  - "inst/app/www/**/*.js"
  - "inst/extdata/i18n.json"
---

# Karpathy Guidelines

Apply these guidelines when writing, reviewing, or refactoring code. They bias
toward caution, simplicity, and verifiable changes.

## Think Before Coding

- State assumptions before implementation when they materially affect the
  change.
- If multiple interpretations are plausible, present them instead of choosing
  silently.
- If a simpler approach solves the request, use it or name the tradeoff.
- If the task is unclear, stop and ask rather than hiding confusion in code.

## Simplicity First

- Write the minimum code that solves the requested problem.
- Do not add speculative features, abstractions, configurability, or error
  handling for impossible scenarios.
- Prefer existing local patterns over new frameworks or helper layers.
- If the change grows large, reassess whether a smaller implementation would
  satisfy the same goal.

## Surgical Changes

- Touch only files and lines that trace directly to the user's request.
- Do not refactor adjacent code, comments, or formatting just because it is
  nearby.
- Match the repository style even when another style would also work.
- Do not "improve" unrelated code while passing through it. If unrelated dead
  code or cleanup is noticed, mention it instead of deleting it.
- Remove imports, variables, functions, or docs only when the current change
  made them unused.
- Do not remove pre-existing dead code unless the user explicitly asks.
- Test every changed line mentally: it should have a direct reason tied to the
  request.

## Goal-Driven Execution

- Translate the task into verifiable success criteria before coding.
- Loop until the stated criteria are verified or until a real blocker is found.
- Turn vague requests into checks:
  - "Add validation" means cover invalid inputs, then make those tests pass.
  - "Fix the bug" means reproduce it with a targeted test/check, then make it
    pass.
  - "Refactor X" means preserve behavior and run an appropriate before/after
    check when feasible.
- For multi-step code tasks, state a brief plan in this shape:
  1. Step -> verify: check
  2. Step -> verify: check
  3. Step -> verify: check
- Strong success criteria allow independent progress. Weak criteria like "make
  it work" require clarification before implementation.
