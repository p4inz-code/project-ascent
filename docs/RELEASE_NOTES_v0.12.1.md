# v0.12.1 — release notes

Replaces v0.12.0, which shipped with a Level 1 that failed to compile and is
kept only as a pre-release. If you are on v0.12.0, update.

## Fixed

**Level 1 would not load.** The level-extension pass emitted colour shorthands
into the one level that still referenced `theme.*` inline, so `LevelData`
failed to compile and the game opened to a broken first level. The gate that
should have caught this now forces a full script rescan before any suite runs
— a stale script cache meant every suite had been testing an older compile.

**Boss levels could become unwinnable.** When the boss timer expired the chase
went berserk by multiplying boss and minion speeds in place, and nothing ever
restored them. Dying and retrying cleared the berserk *flag* but not the
speeds, so a third expiry left the chase running at 3.7x its intended ceiling.
Speeds are now restored at the start of every chase.

**The player spawned inside the ground on 24 of 25 levels** — between 78 and
178px below the surface. The physics engine pushed them out on the first
frames, so it never looked broken, but the game began each level by ejecting
the player from solid rock. Level 1 was the only one authored correctly; the
rest now match it.

**Six ragebait platforms sat on the only route.** A platform that vanishes
when you land on it is a trap when there is a way around it and a wall when
there is not. Those six are now solid. The seven that are genuinely optional
are unchanged.

**The left boundary wall was being drawn.** It is a 3200px-tall collider that
exists to stop you leaving the level, and it appeared as a full-height column
standing in open sky beside the spawn.

**Grapple timing.** The cooldown was charged when the hook fired and ticked
away during the reel, so a long grapple kept almost none of it; the latch
frame moved at falling speed before the pull engaged; and the momentum meant
to carry you off the end of a reel was recomputed away in the same frame.

## Added

**Death feedback.** Past 25 deaths on a level the game starts talking to you;
past 50 the tone turns supportive. Respawn stays instant at every tier —
nothing here delays a retry.

**Mid-level checkpoints in Acts IV and V.** One flag per level in 16–25,
in-memory only: they make a long level survivable within a session without
turning it into saved progress. Acts I–III remain pure full-level runs.

**Boss timers.** A visible countdown on levels 5, 10, 15, 20 and 25. Expiry
speeds the chase up rather than killing you.

## Security

The auto-updater had three real holes, all closed and each covered by a test
that feeds the guard exactly the input it exists to reject:

- Path traversal used a prefix check, which a sibling directory sharing the
  destination's name defeats (`/staging-evil` starts with `/staging`).
- Checksum verification was skipped when a release published no checksum, so
  updates installed unverified. It now refuses.
- Downloads accepted any URL scheme, including a redirect to plain HTTP.
  HTTPS is now required.

## Testing

Two new suites, both negative-controlled — broken on purpose to confirm they
can actually fail:

- `test_geometry` — pure-shape hygiene across all 25 levels: no degenerate
  sizes, no interpenetrating solids, checkpoints planted on a surface, pickups
  not buried, spawn and goal in open space, nothing below the kill plane. This
  is the suite that found the buried spawns.
- `test_death_feedback` — asserts the tiers by reading the label a player
  would see, and loads a real level to prove the system is wired at all. The
  class had shipped compiling-but-never-instantiated.
