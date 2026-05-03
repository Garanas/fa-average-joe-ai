# Lua — Performance Patterns

This doc covers conventions for **any** Lua you write in this engine, sim-side or UI-side. The patterns and pitfalls below were extracted from [`sim/NavGenerator.lua`](sim/NavGenerator.lua), which is a representative example of the codebase's hot-path style — every rule has a citation back to it, both for things to copy and things to avoid. Folder-specific docs ([`ui/CLAUDE.md`](ui/CLAUDE.md), [`ui/game/chat/CLAUDE.md`](ui/game/chat/CLAUDE.md)) extend or specialise these rules.

Annotation conventions live in [`/annotation.md`](../annotation.md). This doc does not duplicate them.

---

## Why this matters

The engine runs an old, **interpreted** Lua VM — no JIT. Every global lookup is a hash probe. Every `{}` allocates and eventually goes through a non-incremental GC pause. Every `LOG` blocks for I/O. A loop that's "obviously fine" in modern Lua (LuaJIT, Python with bytecode caching, JS in V8) can dominate frame budget here.

Hot paths in this codebase typically run:
- **per-tick** for sim entities (10 Hz × N units),
- **per-frame** for UI controls (60+ Hz × every visible widget),
- **per-cell** for one-shot generators like `NavGenerator` (millions of iterations during map load).

The cost of an idiom is per-iteration × iteration count. A 50 ns global lookup is invisible at 10 calls and a 5 ms freeze at 100 000 calls. Optimise *only* in hot paths, but recognise them when you see them.

---

## 1. Upvalue scoping — localise everything you call repeatedly

The single most common idiom in the codebase. Globals (`table.insert`, `math.floor`, `Random`, `IsAlly`) are looked up by name on every call; module-level locals are loaded as upvalues, which are an order of magnitude faster.

Every performance-sensitive file opens with a localisation block:

```lua
-- /lua/sim/NavGenerator.lua:51-56
local TableInsert = table.insert
local TableGetn   = table.getn
local MathFloor   = math.floor
local MathMax     = math.max
local MathAbs     = math.abs
```

`Projectile.lua` shows the fully-elaborated form for a per-tick file: localised globals, localised engine methods, and even cached method-table lookups ([`sim/Projectile.lua:17-49`](sim/Projectile.lua#L17-L49)).

### Three layers of localisation

| Scope | When to use | Example |
|------|-------------|---------|
| **Module top** | Anything called from any function in the file | [`NavGenerator.lua:51-56`](sim/NavGenerator.lua#L51-L56) |
| **Function top** | Engine globals only used in this function, or method-table reads (`grid.FindLeafXZ`) | [`NavGenerator.lua:651-655`](sim/NavGenerator.lua#L651-L655) |
| **Loop body / hoist** | A `t[z]` row read every iteration of an inner loop | [`NavGenerator.lua:1170-1171`](sim/NavGenerator.lua#L1170-L1171) |

The third layer — the "pre-compute GETTABLE" pattern — is worth calling out explicitly. Inside a nested `z, x` loop, hoist the row read so the inner loop indexes a local instead of doing two table reads per access:

```lua
-- /lua/sim/NavGenerator.lua:1186-1190
for z = 1, c + 1 do
    -- local scope to pre-compute `GETTABLE`
    local pc = pxCache[z]                                    -- one read per row
    for x = 1, c do
        pc[x] = MathAbs(tCache[z][x] - tCache[z][x + 1]) ... -- one read per cell
    end
end
```

### Be consistent

When `TableInsert`, `TableGetn` etc. are localised at the module top, **use them everywhere**. Mixing localised and raw forms is sloppy and looks like an oversight on review:

```lua
-- /lua/sim/NavGenerator.lua:1568, 1585, 1636, 1643, 1701, 1788
table.insert(navLabels[label].ExtractorMarkers, extractor)   -- raw, despite TableInsert existing
table.sort(section.Leaves, SortLeaves)                       -- ditto
```

Same applies to `type` — if you re-localise it inside three functions ([`NavGenerator.lua:651`](sim/NavGenerator.lua#L651), [`823`](sim/NavGenerator.lua#L823), [`1001`](sim/NavGenerator.lua#L1001)), promote it to the module top once instead.

---

## 2. Iteration — numeric `for` for arrays, generic `for` for hashes

Sequential arrays use `for k = 1, TableGetn(t) do`. Hash tables use `for k, v in t do` (the engine has an implicit `pairs` so the iterator function is omitted). Mixing them up costs performance and sometimes correctness — `pairs` order is undefined and `#` on sparse arrays is undefined.

```lua
-- Array-like — /lua/sim/NavGenerator.lua:825-828
for k = 1, TableGetn(self) do
    local instance = self[k]
    ...
end

-- Hash-like — /lua/sim/NavGenerator.lua:1516
for k, _ in navLabels do
    local metadata = navLabels[k]
    ...
end
```

### The numeric-`for` loop-variable gotcha

**Reassigning the loop variable inside `for k = a, b do … end` does nothing.** Lua re-derives the counter each iteration from the original step. If you need a variable step or skip-ahead, use `while`.

The four neighbour-scan loops in `GenerateDirectNeighbors` get this wrong ([`NavGenerator.lua:684-749`](sim/NavGenerator.lua#L684-L749)):

```lua
for k = x1, x2 - 1 do
    ...
    k = k + neighbor.Size - 1   -- intent: skip past the neighbour we just found
    ...
end
-- Lua ignores the reassignment. The "skip" is silently a no-op,
-- and FindLeafXZ runs Size times per neighbour.
```

The correct shape is:

```lua
local k = x1
while k <= x2 - 1 do
    ...
    k = k + step
end
```

When you read a `for` loop and see the body writing to its counter, treat it as a bug until proven otherwise.

---

## 3. Hot-path discipline

These are the small things that compound. Each one is cheap to apply at write-time; each one is painful to retrofit later.

### 3.1 Hoist invariants out of inner loops

Any subexpression that doesn't change inside the loop should be computed once before it.

```lua
-- /lua/sim/NavGenerator.lua:666-673 — "0.5 * size" recomputed four times
local x1 = px - 0.5 * size
local z1 = pz - 0.5 * size
local x2 = px + 0.5 * size
local z2 = pz + 0.5 * size

-- Better:
local hs = 0.5 * size
local x1, z1 = px - hs, pz - hs
local x2, z2 = px + hs, pz + hs
```

Watch for the doubly-multiplied area pattern too:

```lua
-- /lua/sim/NavGenerator.lua:852, 876, 1741, 1756
metadata.Area = metadata.Area + ((0.01 * leaf.Size) * (0.01 * leaf.Size))
-- Collapses to:
metadata.Area = metadata.Area + 0.0001 * leaf.Size * leaf.Size
```

One multiplication saved per leaf. Negligible on its own, real over a 20×20 map.

### 3.2 Reuse tables instead of allocating

`{}` allocates and eventually pressures the GC. In hot paths, allocate once at module scope and overwrite:

```lua
-- /lua/sim/NavGenerator.lua:145-160 — DrawSquare reuses four corner tables
local tl = { 0, 0, 0 }
local tr = { 0, 0, 0 }
local bl = { 0, 0, 0 }
local br = { 0, 0, 0 }

function DrawSquare(px, pz, c, color, inset)
    tl[1], tl[2], tl[3] = px + inset, GetSurfaceHeight(px + inset, pz + inset), pz + inset
    ...
end
```

Same idea, different shape: use a single module-level scratch table as a hash-set and clear it between uses. The `HashCache` pattern at [`NavGenerator.lua:58`](sim/NavGenerator.lua#L58) is reused across every leaf in `GenerateDirectNeighbors`.

The trade-off: shared scratch state is **not re-entrant**. If `DrawSquare` ever called itself transitively, the inner call would clobber the outer's `tl`. Keep these locals tightly scoped to the file that owns them.

#### Variant: caller-supplied cache

When a function returns a list and is called repeatedly across different call sites, neither module-scope nor instance-scope scratch fits — different callers want their own buffers, and the function shouldn't dictate where the cache lives. Take the cache as the last (optional) parameter:

```lua
-- /mods/fa-joe-ai/lua/Sim/Bases/Components/JoeBaseBuildSiteComponent.lua
---@param cache? JoeBuildSite[]
---@return JoeBuildSite[]
CollectFreeFor = function(self, identifier, cache)
    cache = cache or {}
    TableSetn(cache, 0)

    local sites = self.Sites
    for k = 1, TableGetn(sites) do
        local site = sites[k]
        if site.Identifier == identifier and site:IsFree() then
            TableInsert(cache, site)
        end
    end

    return cache
end
```

Three rules of the contract:

1. **The function clears the cache, then refills it.** `TableSetn(cache, 0)` resets the length so subsequent `TableInsert` calls overwrite from index 1.
2. **If the caller doesn't pass one, the function allocates a fresh table** (`cache = cache or {}`). The signature stays optional from the caller's perspective.
3. **The function always returns the cache.** This lets calls chain — `cache = obj:CollectFreeFor(id, cache)` — and promotes a `cache?` (optional) into a non-optional return type.

The caller allocates once at the outer scope and hands the same table back every call:

```lua
local sitesCache = {}
while running do
    local sites = base:AcquireBuildSitesForIdentifier(id, sitesCache)
    -- use sites — next iteration's call refills the same table in place
end
```

**Pitfall.** `TableSetn(cache, 0)` declares the length zero but does *not* nil out leftover indices. They linger as references and can keep otherwise-dead objects alive. Acceptable when subsequent calls have similar payloads; otherwise iterate `for i = 1, oldLen do cache[i] = nil end` before refilling.

**Style: prefer `TableInsert` over `head/head+1` accounting.** Both compile to roughly the same work, but `TableInsert` keeps the length tracking implicit and the loop body short. Reserve manual head pointers for cases where you also need to skip indices or write to non-contiguous slots.

### 3.3 Structure-of-arrays for stack-style buffers

`Compress` uses four parallel arrays (`cox`, `coz`, `csize`, `cindex`) instead of an array of `{ox, oz, size, index}` tables ([`NavGenerator.lua:505-508`](sim/NavGenerator.lua#L505-L508)). Rationale:

- One allocation per push instead of one allocation per element-table per push.
- Smaller GC pressure under deep stacks.
- Reads/writes are scalar table accesses, not table-of-tables.

Use this when the stack can grow large and the element shape is a fixed handful of numbers.

### 3.4 Identifier-based pooling

Cells are stored in a flat `NavLeaves[identifier]` table and referred to by integer id ([`NavGenerator.lua:88, 479`](sim/NavGenerator.lua#L88)) rather than by direct table reference. This makes `NavLabels`, `NavLeaves`, `NavTrees`, `NavSections` introspectable, serialisable for debug dumps, and cheap to clear.

Use it when you have a finite set of long-lived objects that need to reference each other and you'd otherwise be storing a lot of cross-pointers.

### 3.5 Iterate, don't recurse

The Lua stack in this engine is shallow and the call overhead is real. Both `Compress` and `GenerateLabels` use explicit stacks instead of recursion ([`NavGenerator.lua:516-626`](sim/NavGenerator.lua#L516-L626), [`NavGenerator.lua:835-886`](sim/NavGenerator.lua#L835-L886)) — comment in the latter says it explicitly: *"we can hit a stack overflow if we do this recursively, therefore we do a depth first search using a stack that we re-use for better performance"*.

Recursion is fine for tree traversal at small depth. For algorithms over the whole map, write the iterative form.

### 3.6 Don't mutate a numeric `for` loop's counter

(Already covered in §2; restated here so this section reads top-to-bottom as a checklist.)

---

## 4. Logging is expensive — keep it out of inner loops

`LOG`, `SPEW`, `WARN`, and `print` route through the engine to disk and the console. They are fine at the boundary of a generator pass; they are catastrophic inside its inner loop.

```lua
-- /lua/sim/NavGenerator.lua:547 — fires once per uniform quadrant during compression
LOG("Heh!")
```

This single line, left from debugging, runs thousands of times during map load. Treat any `LOG`/`SPEW`/`print` inside an inner loop as a bug.

The acceptable patterns are:

- **Per-stage timing** at the top of `Generate()`: each `SPEW` runs once per phase, not per cell ([`NavGenerator.lua:1865-1900`](sim/NavGenerator.lua#L1865-L1900)).
- **Debug-gated drawing**: a module-level `local Debug = false` flag that callers flip when they need overlay output. UI files use this convention extensively (see [`ui/CLAUDE.md § 7.1`](ui/CLAUDE.md)).

`WARN("Something fishy happened")` ([`NavGenerator.lua:863`](sim/NavGenerator.lua#L863)) inside a per-leaf neighbour scan is exactly the wrong place — if the invariant ever fires, the message floods. Either elevate it to a single post-pass check, or remove it.

---

## 5. Profiling

Two engine helpers are worth knowing:

| Function | What it returns | Use for |
|----------|-----------------|---------|
| `GetSystemTimeSecondsOnlyForProfileUse()` | Wall-clock seconds | Bracketing a stage and `SPEW`-ing the delta — see [`NavGenerator.lua:1865-1889`](sim/NavGenerator.lua#L1865-L1889) |
| `debug.allocatedrsize(t [, exclusions])` | Recursive bytes allocated by a table | One-shot memory accounting at the end of a generator — see [`NavGenerator.lua:1893-1894`](sim/NavGenerator.lua#L1893-L1894) |

The `OnlyForProfileUse` suffix is a load-bearing warning, not a stylistic flourish: this clock is **not deterministic across clients**, so it cannot drive sim logic without desyncing. Use it for measurement, never for decisions.

---

## 6. Common pitfalls

A grab-bag of things that cause bugs in this style of code, ordered roughly by how often they show up in code review.

### 6.1 `self` vs the loop variable in stack-DFS

Easy to typo. In [`NavGenerator.lua:851`](sim/NavGenerator.lua#L851):

```lua
for k = 1, TableGetn(self) do
    local instance = self[k]
    ...
    if instance.Label == 0 then
        ...
        self.Label = label    -- bug: should be instance.Label = label
```

The outer scope is named `self` (the tree); the loop variable `instance` is the leaf. Setting the wrong one means the leaf is never marked, so the next iteration re-enters and allocates a fresh label. Read every `self.Foo = …` inside a loop and check whether you meant the iteration variable.

### 6.2 Misleading aliases

Don't introduce a local that's a duplicate of another with a name that suggests it isn't:

```lua
-- /lua/sim/NavGenerator.lua:1208-1211
local pxc  = pxCache[z]
local pzc  = pzCache[z]
local pxc1 = pxCache[z + 1]
local pzc1 = pzCache[z]      -- looks like pzCache[z+1], is actually pzCache[z]
```

Either delete the alias and inline the read, or fix the index. The current code happens to work because the only use is `pzc1[x + 1]` (the right-edge cell), but reading it makes everyone reach for `git blame`.

### 6.3 Dead `--` lines in hot loops

Commented-out `DrawCircle` calls cluster around debug code that was once useful and is now visual clutter ([`NavGenerator.lua:686, 703, 720, 737, 758, 772, 785, 799`](sim/NavGenerator.lua#L686)). They're zero-cost at runtime but they make the hot section harder to scan. Either delete them, or gate the live form behind a `Debug` flag and keep both.

### 6.4 Half-finished functions

`FindLeafOfLabel` references undeclared `cache` and `head` ([`NavGenerator.lua:956-973`](sim/NavGenerator.lua#L956-L973)) — it'd error if called. A function that doesn't compile shouldn't sit in the file with a `---` doc block; either finish it or delete it. The annotation gives it false credibility on hover.

### 6.5 Multiple `local index` declarations

```lua
-- /lua/sim/NavGenerator.lua:557, 574
local index
...
local index = next + 1   -- shadows the outer with the same name
```

Cosmetic, but it's a sign the function has grown beyond what one author can hold in their head. Either reuse the existing `index` or rename one of them.

---

## 7. When to apply these rules

Not everywhere. These idioms have a cost: they make code denser and harder for newcomers to read. Apply them where they pay off.

| Code is… | Apply |
|----------|-------|
| Called per-tick or per-frame, or runs millions of times in a generator pass | All rules |
| One-shot init, called once at game start outside a hot loop | §1 (localise), §6 (correctness) |
| One-shot UI handler called on user click | §6 only |
| A debug or telemetry function | None — readability beats performance |

If you're not sure, search for the function's callers (`Grep` the function name). If it's invoked from `OnFrame`, an `OnTick`-style sim hook, or any nested loop, you're in hot-path territory.

---

## Don'ts

- **Don't put `LOG`/`SPEW`/`WARN`/`print` inside an inner loop.** Stage-level timing is fine; per-cell logging is a frame-budget bomb.
- **Don't reassign a numeric `for` loop variable** expecting it to take effect. Use `while`.
- **Don't allocate `{}` inside an inner loop.** Reuse a module-level scratch table or accept the GC cost knowingly.
- **Don't mix localised and raw forms** of the same function in the same file (`TableInsert` and `table.insert` both used).
- **Don't mutate a LazyVar's held table in place** (UI side; full rationale in [`ui/CLAUDE.md § 2`](ui/CLAUDE.md)).
- **Don't optimise outside hot paths.** The rules above make code denser; cold paths should stay readable.
