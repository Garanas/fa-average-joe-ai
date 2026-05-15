# ADR 0001: Comment style

## Status

Accepted — 2026-05-15.

## Context

Comments add visual weight to source files. Excessive or low-value comments make code harder to scan for the average reader, even when each individual comment is technically correct. The mod already uses EmmyLua annotations for typing, and CLAUDE.md covers type annotations and naming, but not when or how to write prose comments. A reproducible rule keeps comment density sparse and the style uniform across human contributors and AI assistants.

## Decision

### Density

Sparse. Every comment must earn its place for the average reader.

### Voice and style

Comments use the declarative mood. They state what the code is or does as a fact, not as an instruction to the reader or a description of "this function".

- Good: `Pops the next ready job from the queue.`
- Avoid: `Pop the next ready job from the queue.` (imperative)
- Avoid: `This function pops the next ready job from the queue.` (meta)

Comments use simple sentences with minimal punctuation. Prefer two short sentences over one sentence joined by a dash, semicolon, or parenthetical.

- Good: `Pops the next ready job. Returns nil when none are ready.`
- Avoid: `Pops the next ready job - returns nil when none are ready.`

At most two sentences per description. If more is needed, the code likely wants restructuring or an in-body comment.

### Function documentation

Every function gets an EmmyLua block, including internal and private helpers.

- One or two sentences describing the function's purpose, following the voice rules above.
- `---@param` annotations, one line each. Type is required. Prose is optional and single-line.
- Optional parameters are marked with `?` on the name: `---@param tick? number`.
- `---@return` annotations, one line each.

No `@usage`, `@example`, `@see`, or other extended blocks.

```lua
--- Pops the next ready job from the queue. Returns nil when none are ready.
---@param self JoeBaseProductionQueueComponent
---@param tick number  current sim tick used to gate time-based jobs
---@param filter? function optional predicate to skip jobs
---@return JoeProductionJob?
function ProductionQueueComponent:PopNextReady(self, tick, filter)
    ...
end
```

### Implementation details

Non-obvious implementation notes go inside the function body, in the first few lines. They never appear in the docblock. This keeps the public surface clean and co-locates the explanation with the code it explains.

Triggers for an in-body comment:

- A hidden constraint.
- A workaround for an engine quirk or upstream bug.
- An invariant the type system cannot express.
- A non-obvious algorithmic choice.

The same voice rules apply. Declarative, simple, at most two sentences.

### Section banners

Section banners are allowed in long files. They must use editor-foldable markers and always come in pairs:

```lua
--#region Build site management

...code...

--#endregion
```

No decorative banners. No unpaired `#region` or `#endregion`.

### Forbidden comment shapes

- Restate-comments that paraphrase what the code does.
- History-comments referencing tickets, prior versions, or other callers.
- Multi-paragraph descriptions of any kind.
- Bare TODOs without enough context to act on.

### Edge case: when unsure

If a comment is borderline, leave it out. If the code genuinely needs explaining and the voice rules cannot accommodate it, the code itself likely wants restructuring.

## Consequences

- Public API surface stays terse and scannable.
- Non-obvious detail lives next to the code it explains.
- Editors that support `#region` folding can collapse long files cleanly.
- Borderline comments are skipped by default. This occasionally drops a comment that would have helped, accepted as a tradeoff against visual noise.
- Existing files predate this rule. They are updated opportunistically when otherwise touched, not in a sweeping pass.
