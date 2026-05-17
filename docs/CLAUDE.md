# docs

Angular 21 documentation site for the fa-joe-ai mod. Dev server runs on http://localhost:4200 (`npm start`). Full validation pipeline: `npm run validate` (format check, lint, tests, build).

## Verifying UI changes with Playwright

UI changes must be verified in a real browser before being marked done. Use the Playwright MCP server tools, not screenshots alone.

One-time machine setup — the MCP defaults to the stable Google Chrome channel, not bundled Chromium:

```
npx playwright install chrome
```

The MCP server itself (`@playwright/mcp`) is fetched on demand by npx — see [.mcp.json](../.mcp.json) — so no project-level install is required.

- Start the dev server with `npm start` and wait for it to report a successful build before navigating.
- Use `browser_snapshot` to locate elements and obtain refs. `browser_take_screenshot` is for visual checks only — don't try to read it to find elements.
- Snapshots and screenshots write to [`.playwright-mcp/`](.playwright-mcp/) (gitignored). Always pass `filename: "images/<name>.png"` to `browser_take_screenshot` so screenshots collect under [`.playwright-mcp/images/`](.playwright-mcp/images/) instead of mixing with snapshot YAML at the root. Use relative paths only — absolute paths escape the gitignored area.
- After a route change or any DOM-altering action, snapshot again. Refs from the prior page are stale.
- For forms with more than one field, call `browser_fill_form` once instead of chaining `browser_type` calls.
- For dynamic content, use `browser_wait_for` (text appearing or disappearing) rather than retrying interactions.
- Inspect `browser_console_messages` before declaring a feature working. A runtime Angular error there is a failure, even if the page looks right.
- `browser_close` when verification is done.

## Angular MCP server

The angular-cli MCP server auto-loads its core workflow (list_projects → get_best_practices → search_documentation/find_examples). These notes only cover project-specifics:

- Workspace path: this directory ([docs/](.)). Pass it as `workspacePath` to `get_best_practices`.
- This is Angular 21 with standalone components, SSR (`@angular/ssr`), Vitest (not Karma), Tailwind v4, Angular Material 21. Don't suggest NgModule-era patterns or Karma test setups.
- Call `get_best_practices` before any non-trivial change (new component/service/route, forms, signals vs RxJS choice). A one-line edit doesn't need it; a new feature does.
