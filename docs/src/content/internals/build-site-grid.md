# Build site grid

Every base maintains a small spatial index of *build sites* — positions where a building of a given footprint could legally be placed. The grid is built once when the base settles and updated only when sites are reserved, blocked, or released.

## A build site is a record

```lua
---@class JoeBuildSite
---@field Position { [1]: number, [2]: number }
---@field Footprint integer            -- e.g. 1, 2, 4, 6 leaves on each side
---@field IsReserved boolean           -- claimed for a queued job
---@field IsBlocked  boolean           -- a building or wreck sits on it
---@field BlockedSince integer | nil   -- game tick when blocked, for retry logic
```

It is *only* a record. There is no behaviour attached. A site does not know who is building on it; the *build job* knows which site it targets.

## Why it's grid-shaped

Supreme Commander's economy rewards adjacency: pgens around a factory, mass storage around extractors. To make adjacency decisions cheap, sites are stored on a regular grid where the cell size equals the smallest footprint we care about (one leaf = one mesh quad).

A T2 power generator wants a 2x2 site. To find all 2x2 sites in a base, we walk a 2-stride window across the grid. The full base on a typical 10km map is around 800 cells — small enough that linear walks beat any kd-tree.

## Reservation lifecycle

| Transition | Trigger | Owner |
| --- | --- | --- |
| free → reserved | A job is queued that targets this site | The job |
| reserved → free | The job is cancelled | The job |
| reserved → blocked | The job started building and the foundation is laid | The base tick |
| blocked → free | The structure was destroyed or reclaimed | The base tick |

`BlockedSince` lets the base wait a configurable number of ticks before considering a blocked site reusable — there's a brief window after destruction where the wreck still occupies the cells.
