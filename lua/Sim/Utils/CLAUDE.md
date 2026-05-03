# Utils

Pure-function modules. Each util here is **callable from anywhere** with no setup, no instances to construct, no global state to wire up. The bar for inclusion: the function should be useful in a wide variety of situations and not coupled to any specific subsystem (no base/brain/behavior knowledge).

If a helper is reclaim-specific, build-specific, behavior-specific, etc. — it doesn't belong here. It belongs alongside the subsystem that owns it.

## Files in this tree

- [`DebugUtils.lua`](DebugUtils.lua) — drawing helpers that hide engine-level boilerplate. `DrawCircleXZ`, `DrawLineXZ`, `DrawSquareXZ`, `DrawLinePopXZ`, `DrawUnits`, plus `GetOrientedBoundingBox(unit, inset)` for unit-rotated rectangles. Also hosts `DebugSelectionThread` — the global draw thread that gates per-platoon/-base `Draw` calls on selection state.
- [`EntityUtils.lua`](EntityUtils.lua) — entity ordering. `SortInPlaceByDistance(entities, origin)` and `SortInPlaceByDistanceXZ(entities, ox, oz)`.
- [`MapUtils.lua`](MapUtils.lua) — map-area arithmetic. `GetPlayableArea()` / `GetBuildableArea()` return `x0, z0, x1, z1` in world coordinates. `IsBuildSiteInArea(px, pz, sx, sz)` checks whether a footprint fits inside the buildable region.
- [`UnitUtils.lua`](UnitUtils.lua) — unit-shaped helpers. `GetUniqueUnitIds(units, cache?)` collapses to a deduped UnitId list. `GetRestrictingNavigationalLayer(units)` finds the most-restrictive layer over a mixed group. `IssueFormMoveToWaypoint(...)` wraps the engine's `IssueFormMove` with auto-computed orientation. `ValidateBuildSite(brain, location, unitId)` does the full "can I build here?" check including overlap detection that `CanBuildStructureAt` misses.
- [`Orders.lua`](Orders.lua) — order-issuing helpers. `IssueClearArea(army, lx, lz, sideLength)` shoos away friendly idle mobiles from a future build site.

## Conventions

1. **No state.** Modules export functions, not classes. If you find yourself adding a `__init` here, the helper has grown a personality and should move out.
2. **No silent dependence on caller-side context.** Functions take everything they need via parameters. The one borderline case is `ValidateBuildSite(brain, …)` which takes a brain — that's still a parameter, not a global.
3. **Allocation-conscious where it matters.** `GetUniqueUnitIds` accepts an optional `cache` to reuse storage; per the [`Sim/CLAUDE.md`](../CLAUDE.md) hot-path conventions, caller-provided scratch tables are preferred over allocating fresh ones inside utils that may be called per-tick.
4. **Module-top localization.** Hot-path utils localize `table.getn` / `math.floor` / `string.format` etc. at module top, matching the rest of the codebase.

## Pitfalls

1. **`DebugSelectionThread` is global** — it runs once per game and dispatches per-tick `Draw` calls to anything selected. If you add a new debug visualization, hook into that thread rather than spawning a parallel draw loop.
2. **`GetPlayableArea` falls back to map size** when `ScenarioInfo.MapData.PlayableRect` is nil. Most maps set it; a few don't. Don't rely on the playable rect being present for non-playable areas to be consistent — use the function, never `ScenarioInfo` directly.
3. **`ValidateBuildSite` returns false defensively.** It runs a manual overlap pass to catch cases `CanBuildStructureAt` misses (notably support factories). If a build that "should" work is being rejected, check this function before blaming the engine.
