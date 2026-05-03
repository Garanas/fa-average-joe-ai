---
name: author-uef-chunk
description: Use when authoring a UEF base chunk for the fa-joe-ai mod (a file under lua/Shared/BaseChunks/UEF/). Captures UEF placement philosophy — parallel and orthogonal lines, strong symmetry, factory grids, power adjacency packing, inner-buffer walls, defense-in-gap, onion-ring high-value protection, and a high defense ratio. Combine with the author-base-chunk skill, which covers the file format and validation rules.
---

# Authoring a UEF base chunk

UEF base chunks express **parallel and orthogonal lines**. Buildings sit on integer grids, walls run in straight axis-aligned segments, factories pair or quad-mirror across chunk axes. The visual feel is rectilinear and load-bearing — engineering by ruler, not by curve.

**Always invoke the [author-base-chunk](../author-base-chunk/SKILL.md) skill first** for the file format, coordinate convention, footprint rules, tier progression, validation, and loader registration. This skill only adds UEF-specific style on top.

## The core theme

Every UEF chunk should be reducible to a small set of parallel and orthogonal lines. If you cannot describe the layout as "factories on a horizontal line, power on a parallel line, walls on the perimeter," the chunk is probably not UEF-shaped. No diagonals, no offsets, no rotated buildings (orientation is always `0`).

## Symmetry

Pick one symmetry mode per chunk and commit:

- **Mirror symmetry** across the vertical axis is the default. See [land_32x32_01.lua](../../../lua/Shared/BaseChunks/UEF/land_32x32_01.lua): six factories arranged 2-wide × 3-tall, mirrored left/right; AA cluster on the centerline; PGens in two horizontal rows that span the mirror.
- **4-corner radial symmetry** for chunks dominated by 4 factory slots. See [land_32x32_02.lua](../../../lua/Shared/BaseChunks/UEF/land_32x32_02.lua): factories at the four corners, T2 shield in the centre, T2 PGens on the centerline.
- **Diagonal pair symmetry** for chunks with two high-value structures. See [power_16x16_02.lua](../../../lua/Shared/BaseChunks/UEF/power_16x16_02.lua): T2 PGens at `(5,5)` and `(11,11)`, with shield and AA filling the opposite diagonal at `(11,5)` and `(5,11)`.

Asymmetric layouts are only acceptable for small (`Size = 16`) chunks that hold a single primary building and cannot be cleanly mirrored — e.g. [land_16x16_01.lua](../../../lua/Shared/BaseChunks/UEF/land_16x16_01.lua) with a single T1 factory off-centre. Even then, the supporting power array, wall, and defense should be placed on a clean axis-aligned line.

## Power: pack for adjacency

T1 PGens (2×2 skirt) belong in tight rows or columns at exactly **2 cells apart** (skirt-touching) so each PGen sits adjacent to its neighbours and to factories or mass extractors for the engine's adjacency-bonus calculation. **Do not pack T1 PGens around T2/T3 PGens — that gives no engine bonus** (see the adjacency-reality section in author-base-chunk). Instead:

- **T1 PGens belong adjacent to factories**, where they grant factory build-rate bonus. Pack T1 rows or columns along the factory sides where walls are not placed (see the wall-direction section below).
- **For T2/T3 PGen output bonus, use one or two `EnergyStorage` adjacent to it**, not a ring of T1 PGens. Energy storages are volatile (they detonate on death), so place them sparsely — never more than two per T2 PGen.
- A pure T1 power chunk is a rectangular grid of PGens for compactness. [power_08x08_01.lua](../../../lua/Shared/BaseChunks/UEF/power_08x08_01.lua) is a 2×2 pack: PGens at `(2,2)`, `(5,2)`, `(2,4)`, `(5,4)`.
- Power supporting a T2 building shows the storage adjacency. [power_16x16_01.lua](../../../lua/Shared/BaseChunks/UEF/power_16x16_01.lua) places one EnergyStorage at `(9,5)` next to the T2 power slot.
- Power supporting factories runs in a horizontal strip *next to* the factory line, not interleaved with it. See [land_32x32_01.lua](../../../lua/Shared/BaseChunks/UEF/land_32x32_01.lua) — PGen rows at `y=11` and `y=21`, factory rows at `y=6/10` and `y=22/26`.

Never scatter PGens. If they cannot form an adjacency line or block adjacent to a factory or mass extractor, place fewer of them.

## Factories

T1 factory skirt is 8×8. UEF factory placements always sit on an 8-cell grid. Two binding rules govern *how* multiple factories sit together:

1. **Group same-type factories together — never alternate L/A.** A row of `Land, Air, Land, Air` looks chaotic. Instead place all of one type first, then a deliberate gap, then the other type: `Land, Land, Land`, gap, `Air, Air, Air`. The chunk reads as two distinct sub-formations rather than a checkerboard.
2. **Leave breathing room between factories of the same type.** Skirt-touching is allowed by the engine but visually cramped. Add at least 4 cells of empty space between adjacent same-type factory skirts. So two land factories on the same row sit at saved-x diff of `12` (skirt-touching at `8` plus 4-cell buffer) rather than `8`.

Layout patterns:

- **Pairs** for small chunks. [air_16x16_01.lua](../../../lua/Shared/BaseChunks/UEF/air_16x16_01.lua): two T1 air factories at `(4,4)` and `(14,4)`, 10 cells apart with breathing room for surrounding structures.
- **Four corners** for `32×32` chunks dominated by factory production. [land_32x32_02.lua](../../../lua/Shared/BaseChunks/UEF/land_32x32_02.lua): factories at `(7,5)`, `(25,5)`, `(7,26)`, `(25,26)`. (All four are the same type — no alternation.)
- **Six in a 2×3 mirror** for high-density factory chunks. [land_32x32_01.lua](../../../lua/Shared/BaseChunks/UEF/land_32x32_01.lua) is the canonical example.
- **Stacks of same-type with a buffer between groups** for chunks holding both types. e.g. three land factories along the top row at `(3, 3)`, `(15, 3)`, `(27, 3)`, then three air factories along the bottom row at `(3, 27)`, `(15, 27)`, `(27, 27)`. Top row reads as "land complex"; bottom row reads as "air complex".

Factories never sit at the chunk edge — leave at least 4 cells between the factory's skirt and the chunk boundary so neighbouring chunks have room.

## Walls: outward-pointing, never inward

Walls are 1×1 single-cell structures that form straight axis-aligned runs, 4–10+ cells long, single-cell-thick. Five binding rules:

1. **Walls do not sit on the chunk edge** (`x=0`, `z=0`, `x=Size-1`, or `z=Size-1`). Two abutting chunks would otherwise produce a doubled wall on the seam. Sit walls one or more cells inboard. [land_32x32_02.lua](../../../lua/Shared/BaseChunks/UEF/land_32x32_02.lua) demonstrates the convention — walls at `x=4` and `x=27` (not `x=0` or `x=31`).
2. **Walls always point outward, never inward.** The wall ring sits between a factory and the chunk's nearest perimeter edge. Walls are never placed between a factory and the chunk interior — that would shield the factory from its own base.
3. **Wall-permitted factory sides depend on the factory type:**
   - **Land factory** — walls allowed only on the `±Z` faces (top and bottom of the factory's skirt). Never on the `±X` faces — those are the unit rolloff sides.
   - **Air factory** — walls allowed only on the `-Z` (top) or `-X` (left) face. Never on `+Z` or `+X`.
   
   When a wall run reaches a factory, it must touch a permitted face. If the factory's perimeter-facing side is not permitted, the wall run breaks before reaching that factory and resumes on the other side.
4. **T1 ground defense (`T1GroundDefense`) is always wall-connected.** A T1 point defense placed alone takes hits directly and dies fast; with walls flanking it, damage is shared between turret and walls. Whenever you place a T1 ground defense, place at least one wall directly adjacent to it (skirt-touching at any of the four sides). The classic UEF "defense-gated gap" pattern is a wall run interrupted by a single `T1GroundDefense` cell, with walls re-attaching on both sides — the turret is sandwiched between wall segments.
5. **Walled gaps are gated by defenses, not left open.** When a wall run breaks to allow access, fill the gap with a defensive structure (T1/T2 ground defense, AA, missile defense). [land_32x32_01.lua](../../../lua/Shared/BaseChunks/UEF/land_32x32_01.lua) shows this — the top wall opens at `x=19` with a T1 ground defense planted in the gap; same on the bottom.

For chunks that occupy the actual map edge, the planner is responsible for overriding wall placement. The chunk file itself never assumes it is on the map edge.

## Layering: defenses → factories → fragile core

A UEF chunk is composed of three concentric layers. Read from the chunk edge inward:

1. **Outermost — defenses and walls.** Walls (inboard of the chunk edge — see the wall section), AA, ground defense, missile defense.
2. **Middle — factories.** Land, air, and naval factories. Their armoured shells absorb damage that gets past the outer defenses.
3. **Innermost — fragile structures.** PGens, EnergyStorage, MassStorage, intel (radar, jammers), shield generators, T2/T3 power, strategic missile silos.

Place factories **on the perimeter side of the chunk** so they shield the fragile interior. Defenses are the only thing that should sit *outboard* of factories — they are the first thing an attacker hits.

In small chunks (`Size = 16`) where there is no real "interior" to speak of, interpret the rule loosely: factories occupy half (or more) of the chunk along one edge or two opposite edges; PGens and intel pack into the remaining strip; defenses tuck against the chunk-edge buffer between the factories.

## Density and sub-formations

UEF chunks are **dense**. Sparse outer edges in larger chunks (32×32+) feel un-UEF — the perimeter strips should be filled with walls, defenses, T1 PGen rows, and storage clusters, not left empty.

For larger chunks (32×32 and especially 64×64), build the layout from **sub-formations** rather than one monolithic structure:

- A *factory complex* is a 12–16-cell sub-formation: 1–3 same-type factories grouped together with a wall ring on their permitted side, an AA piece flanking, a T1 PGen row adjacent to the rolloff side, and a T1 ground defense at the corner with walls connecting.
- A *power complex* is a tight rectangular grid of T1 PGens, possibly with one storage at the corner, surrounded by short wall stubs.
- A *defense complex* is a wall run with multiple `T1GroundDefense` cells spaced along it, each sandwiched by walls; T1 AA at the corners; T2 missile defense behind it for high-value chunks.
- A *high-value core* is the central T2/T3 building (shield, jammer, SMD, T3 PGen, T3 artillery) with concentric rings: the building, then T2 missile defense, then walls, then defenses outside the wall ring.

Compose the chunk by placing 3–6 sub-formations and tying them together with the wall ring. The result reads as a coherent UEF base rather than a sparse arrangement of buildings.

Avoid the failure mode of "evenly distributing buildings across the chunk." UEF density comes from clustering, not even spread.

## Defenses: high ratio, layered onion-rings around high-value targets

UEF chunks are **defense-heavy**. There is no fixed ratio — place "whatever fits" — but err on the side of more defense, not less. A T2 power chunk should always include shield + AA + missile defense; a factory chunk should always include perimeter AA and at least one ground defense.

For high-value structures (SMD, T2 PGens, radars, T3 anything), nest protection in concentric rings:

```
[ wall ] → [ T1/T2 ground defense ] → [ T2 missile defense ] → [ T2 shield ] → [ high-value building ]
```

[special_16x16_01.lua](../../../lua/Shared/BaseChunks/UEF/special_16x16_01.lua) is the worked example: T3 SMD at `(12.5, 4.5)`, T2 missile defense at `(7, 5)`, T2 ground defense at `(3, 5)`, T2 shield at `(11, 11)`, walls forming the outer skin.

For lower-value support structures (factories, T1 power), one or two AA pieces on the threat-facing side are usually enough.

## Intel placement

Radar and other intel structures (`T1Radar`, `T2Radar`, `T2RadarJammer`, sonar) go to **corners or perimeter**, never the chunk centre. The centre is reserved for high-value buildings or the symmetry pivot. See `(11, 11)` in [land_16x16_01.lua](../../../lua/Shared/BaseChunks/UEF/land_16x16_01.lua), `(5, 15)` in [air_16x16_01.lua](../../../lua/Shared/BaseChunks/UEF/air_16x16_01.lua), `(16, 5)` in [land_32x32_02.lua](../../../lua/Shared/BaseChunks/UEF/land_32x32_02.lua).

## Tier progression (UEF specifics)

The base-chunk skill mandates: T1 always; T2 at `Size ≥ 32`; T3 at `Size ≥ 64`. UEF flavours this as follows:

- T2 representation in 32×32 chunks should usually be T2 PGen, T2 shield, or T2 missile defense — UEF excels at static defense and the visual signature of a UEF T2+ chunk is a shield bubble with PGens packed under it.
- T3 representation in 64×64+ chunks is typically T3 PGen, T3 shield, or T3 artillery, plus a T3 strategic missile silo for chunks intended as the army backbone.
- UEF T2 PGens (8×8 skirt) are large; budget the space accordingly when designing 32×32 chunks.

## Reference chunks (always re-read before authoring)

The 11 existing UEF chunks are the visual ground-truth. Skim them before producing a new one — they encode style decisions that this document only summarises.

| File | Style notes |
|------|-------------|
| [power_08x08_01.lua](../../../lua/Shared/BaseChunks/UEF/power_08x08_01.lua) | Pure T1 power array, 2×2 PGen pack, minimal walls |
| [power_16x16_01.lua](../../../lua/Shared/BaseChunks/UEF/power_16x16_01.lua) | T1 power + storage; two columns + one row pattern |
| [power_16x16_02.lua](../../../lua/Shared/BaseChunks/UEF/power_16x16_02.lua) | T2 power + diagonal-pair shield/AA protection |
| [land_16x16_01.lua](../../../lua/Shared/BaseChunks/UEF/land_16x16_01.lua) | Single T1 factory, asymmetric, axis-aligned support |
| [land_16x16_02.lua](../../../lua/Shared/BaseChunks/UEF/land_16x16_02.lua) | Single T1 factory, alternate axis orientation, EnergyStorage tucked in for adjacency |
| [land_32x32_01.lua](../../../lua/Shared/BaseChunks/UEF/land_32x32_01.lua) | 6-factory 2×3 mirror; vertical-axis symmetry; defense-in-gap walls |
| [land_32x32_02.lua](../../../lua/Shared/BaseChunks/UEF/land_32x32_02.lua) | 4-corner factory layout; T2 shield centre; double-mirror symmetry |
| [air_16x16_01.lua](../../../lua/Shared/BaseChunks/UEF/air_16x16_01.lua) | T1 air pair + radar in corner |
| [special_08x08_01.lua](../../../lua/Shared/BaseChunks/UEF/special_08x08_01.lua) | Single T2 air staging — minimal special-purpose |
| [special_08x08_02.lua](../../../lua/Shared/BaseChunks/UEF/special_08x08_02.lua) | T1 radar with flanking PGens and a forward T1 ground defense |
| [special_16x16_01.lua](../../../lua/Shared/BaseChunks/UEF/special_16x16_01.lua) | T3 SMD with full onion-ring defense |
| [random_32x32_01.lua](../../../lua/Shared/BaseChunks/UEF/random_32x32_01.lua) | Mixed land + air starter chunk; diagonal symmetry; T2 shield centre |

## Authoring procedure

When asked to author a new UEF chunk:

1. **Apply the mechanics from the [author-base-chunk](../author-base-chunk/SKILL.md) skill** — file location, format, coordinate convention, tier rule, validation, loader registration.
2. **Open units.md** and note the skirt sizes for every identifier you intend to place, specifically for `Faction = "UEF"` rows.
3. **Pick a symmetry mode** (mirror / 4-corner / diagonal-pair) and a primary structure layout that fits the chunk's role and size.
4. **Place the primary structures** first on the chosen symmetry. Verify they fit within the chunk bounds and do not overlap.
5. **Pack power** into adjacent rows or columns near the primary structures (2-cell skirt-touching spacing for T1).
6. **Place defenses** layered around high-value targets. Skew toward more, not less.
7. **Run walls** as straight axis-aligned segments inboard of the chunk edge. Gate any gaps with a defensive structure.
8. **Drop intel** at corners or perimeter only.
9. **Verify against the validation checklist** from author-base-chunk.
10. **Register the file** in `JoeBaseChunkLoader.lua` and instruct the user to preview it in-game.

If at any point the layout starts to feel curved, diagonal, or asymmetric without a deliberate reason, restart from the symmetry mode — UEF does not curve.
