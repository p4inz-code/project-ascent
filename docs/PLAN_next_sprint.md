# Next sprint — plan

Written at the owner's request at the end of the variety sprint. Nothing here
is built yet.

## 1. The death plane (do this first)

> "one platform when player falls out it takes seconds to die so make it quick
> — a plain one or ground or water or lava depending on act, once player dips
> in he dies instant"

Today a fall is dead time: the player is already out of the run but keeps
falling until they pass `kill_depth`, which on the taller levels is over a
second of nothing. In a game built on instant retries, that is the single
worst-feeling second in it.

**The fix is a floor, not a faster timer.** Every level gets a full-width
surface just below the lowest real platform, themed per act:

| Act | Surface | Why |
|-----|---------|-----|
| I — Dawn | ground | a plain miss, no drama |
| II — Ridge | water | the first act where falling has texture |
| III — Frost | ice water | reads colder without new mechanics |
| IV — Storm | lava | stakes visibly rise |
| V — Apex | lava | the whole floor is hostile |

Touching it kills instantly — an `Area2D` on the player layer, exactly like
`lava.gd` already does, so this reuses a hazard path that is already tested.

Two things to get right:
- It must sit **below every reachable platform**, or it becomes an accidental
  wall. `test_geometry` already knows every platform's extents, so it can
  assert the clearance.
- `kill_depth` stays as the backstop for anything that somehow gets past it.

This also kills the falling-forever case for free, so it is worth doing before
the obstacle catalogue rather than after.

## 2. Water: swimming and diving

Water stops being only lethal in the acts where it is the floor, and becomes a
place you can be:

- Buoyancy: gravity inverts toward a surface line, capped rise speed.
- Reduced horizontal accel and top speed (the `_surface_speed_scale` hook from
  the ice/sticky work already exists and applies cleanly).
- Diving: hold down to sink faster; a jump from just under the surface pops you
  out with extra height, which is the one trick that makes water fun rather
  than slow.
- **Breath is deliberately out of scope.** A drowning timer in a precision
  platformer adds a failure that is not about movement.

Depends on the death plane existing first, since that is what introduces water
as a surface at all.

## 3. Currency

Only worth adding once there is enough obstacle variety for a route to have
optional branches — otherwise coins sit on the one path you already walk and
collect themselves.

- Coins on **optional** routes: the risky line pays, the safe line does not.
- Persisted per level in `SaveSystem`, alongside the existing completion data.
- Spend on cosmetics only — trails, colours, player shapes. **Never on
  difficulty.** A precision platformer that lets you buy your way past a jump
  stops being one.

## 4. Remaining obstacle catalogue

Ordered by how much each changes a route, most first:

- Lava variants: checkerboard, rising-chase, dripping
- Timed platforms on a fixed on/off cycle; chain-reaction collapse
- Moving wall gaps; crumbling wall holds
- Pressure plates and timed gates
- Rail-mounted moving hazards; shooter traps
- Tightropes and narrow beams

Each needs the same four things the existing ones have: a script, a
`PlatformDef.kind` or hazard def, placement chosen from measured geometry, and
a test asserting an observable effect rather than existence.

## 5. Act V troll routes

Still open from two sprints ago. All eleven ragebait platforms turned out to be
on the mandatory route, so they were made solid and the mechanic currently does
not exist.

The design is settled: a decoy is by definition **off** the route, so
`_landable_route()` should skip `Decoy_*` names the way it already skips walls,
and `test_geometry` must then assert every decoy is reachable from the route
AND never the only surface in its span — otherwise "Decoy" becomes a way to
hide unreachable geometry from the sweep.

## 6. Still the owner's call

- **Camera zoom.** The player is 33px in a 1080p frame — 3.1% of screen height,
  against roughly 8% for Celeste. It is the highest-impact visual change
  available and the reason the character detail is hard to see. It changes
  level framing and difficulty, so it is not mine to make; the reachability
  sweep should re-run after.
- **Rotating panel repositioning** — noted as needing a move, but I have not
  seen which panel or where it should go.
