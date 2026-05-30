# Contributing to Memact

Memact is an open-source user-controlled context layer. Apps propose context. Users decide what stays.

## Quick start

1. Fork the repo.
2. Create a branch like `feature/your-thing`.
3. Make one focused change.
4. Open a PR with a clear description.

Small clean PRs are welcome.

## How Memact works

```text
Apps send approved context
-> Access checks consent, scopes, and API keys
-> Schema gives context a readable shape
-> Memory stores accepted user context
-> Apps use permitted context to personalize better
-> Users can review, edit, reject, delete, or revoke access
```

Apps only get context the user allowed.

## Where to contribute

### Category schemas

Best for beginners.

Pick a category and define how app context becomes readable user context.

Good categories:

- music
- fitness
- food delivery
- shopping
- learning
- travel
- news
- productivity
- gaming

A good schema explains:

- raw app context
- readable Wiki output
- editable fields
- confidence rules
- privacy defaults
- examples
- tests

Example:

```text
Raw context:
User replayed Brazilian phonk playlists 18 times this month.

Wiki output:
Prefers high-energy Brazilian phonk.

User edit:
I like Brazilian phonk mostly while working out.
```

User-edited context is stronger than app-proposed context.

### SDK examples

Best for intermediate contributors.

Build small examples that show this loop:

1. App asks for permission.
2. App writes approved context.
3. User sees it in their Wiki.
4. Another permitted app reads useful context.

### Access layer

Best for backend contributors.

Access is the gateway. It checks apps, API keys, consent, scopes, categories, feature access, capture event ingestion, and usage logs.

Good tasks:

- improve consent checks
- improve scope validation
- improve API key handling
- improve errors
- add tests
- improve usage logs

### Memory and Wiki behavior

Good tasks:

- improve accepted context shape
- improve edit history examples
- improve delete and revoke docs
- define app-safe summaries
- improve user-facing copy

## Rules

- Default visibility should be private.
- Do not write fake certainty.
- Keep user-facing copy simple.
- Important app writes should require user approval.
- Apps should only get relevant category context with permission.
- Avoid AI-first wording unless the feature actually needs AI.

## PR checklist

- [ ] The change is small enough to review.
- [ ] The user-facing text is clear.
- [ ] Privacy defaults are safe.
- [ ] Examples are included where needed.
- [ ] Tests or sample cases are added where possible.
- [ ] The PR explains what changed and why.

## Best explanation

Memact is a playground for user-controlled app context.

Apps bring context. Categories organize it. Wiki keeps the user in charge.
