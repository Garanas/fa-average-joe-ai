# ADR 0004: Theme tokens live in TypeScript

## Status

Accepted — 2026-04-22.

## Context

The docs site needs faction-specific theming at runtime: the `ThemeSwitcher` reads the active faction, and the `HeroBanner` reads its hero copy. Both need typed access to the faction's identity. The colour values themselves also need to be applied to the DOM as CSS custom properties so Material's M3 tokens and our Tailwind utilities pick them up.

There are two places this could live:

1. **CSS as the source of truth** — colours in `:root.theme-uef { ... }` blocks, TypeScript reads them via `getComputedStyle`.
2. **TypeScript as the source of truth** — colours and copy in a const, with a parallel CSS block emitted by the same author.

## Decision

TypeScript is canonical. The CSS block is a small parallel declaration.

| Concern              | Source                                                         |
| -------------------- | -------------------------------------------------------------- |
| Faction id / label   | `FACTIONS` in `faction-theme.ts`                               |
| Icon paths           | `FACTIONS[i].iconPath`                                         |
| Hero copy            | `FACTIONS[i].hero`                                             |
| Colour values        | `:root.theme-<id>` blocks in `styles.css` (hand-mirrored)      |

## Consequences

- **Drift risk on colour values only.** The colour numbers exist in two places. We accept it because the alternative (`getComputedStyle` reads on every render) is slow, async-feeling, and harder to unit-test.
- **Programmatic theming stays simple.** A component that wants to know "is the user on Cybran?" just reads `ThemeService.current()`. No DOM round-trip.
- **The theme service is the gatekeeper.** Every CSS class change goes through it, so the CSS-side state cannot be set without first updating the TS-side state.

If we ever grow past four factions or add per-faction palette ramps (50/100/200/…/900 shades), revisit this — a generator script that emits the CSS from the TS const becomes worthwhile around the time you stop being able to keep both files in your head at once.
