# Trevor, and the orbs

## The story (kept deliberately thin)

Trevor was aboard a rocket. Something went wrong and he came out the other side
somewhere that isn't a place — a rift, a trial, a gap in time. Whatever runs it
doesn't explain itself. It just puts doors in front of him and charges to open
them.

The currency is **orbs**. He needs **100** to reach the last door and buy his
way out.

That's the whole story, and it's meant to be. It exists to answer "why am I
climbing" and "why am I collecting these", and it does. Anything more would be
cutscenes in a game whose subject is instant retries � so there is exactly one,
at the start, and you can skip it.

## The 40-level campaign (updated 2026-11-15)

The Spire now has eight acts. I-V (levels 1-25) climb it: Cinder, Scrapyard, Freezer, Storm, Summit Forge,
ending at DAWN. VI-VIII go DOWN and IN: Underworks (26-30, the pipes under the roof, boss THE HIVE), Rift
(31-35, the crack in the sky, boss THE RIFT WARDEN, a black hole that eats the slow) and Core (36-40, the
heart of the Spire, boss THE CORE, an exam that remixes every earlier act). The story stays thin on purpose:
PIP speaks on the first level of each act and on each boss (GameScene.act_intro_line), there is one cutscene
at the start, and the ending plays after level 40. Taunts make fun of the play, never the player, and every
clear is celebrated.

DECIDED (default, 2026-11-15, owner may change): three cores per level, 108 available and 100 needed, so the OPEN ending is reachable (SaveSystem.ORBS_PER_LEVEL = 3; CoreSpawner builds them; machine levels roll three nooks, the Tempest, Warden and Compactor place theirs). It was an open decision: the gate wants 100 cores (SaveSystem.ORB_GOAL) but one core per level over
levels 5-40 gives 36, so the OPEN ending is out of reach as built. Recommended fix: three cores per level
(108 available, 100 needed) with the rolled nooks and the boss-level perches carrying indices 0-2; the
alternative is to lower the goal to every core (36) and change the "ONE HUNDRED" lines.

## How orbs work

**Introduced at Level 5** — the first boss level, so it lands at a moment the
player already knows is different.

| | |
|---|---|
| Levels with orbs | 5 – 25 |
| Orbs per level | **1** |
| Available today | **21** |
| Eventual target | **100** |

One per level is the number that works at both sizes. The game is planned at
100 levels — 25 built, 75 to come — so one orb per level reaches 100 exactly
when the game is finished.

### The door is NOT gated yet, deliberately

25 levels cannot produce 100 orbs. Checking for 100 today would make the game
**unfinishable**, so the final door opens regardless of your orb count, and a
test asserts that it does. Charging for the last door is a v2 decision, to be
taken when the level count can actually support it.

Until then orbs persist, count, and display — they just don't block anything.

### The one orb is optional, not on the route

With a single orb per level there's no room for a freebie. It sits above the
walking line at 96px — inside the measured jump envelope so it's always
reachable, but high enough that nobody collects it by accident.

An orb sitting on the path you have to walk anyway collects itself, and a
collectible that collects itself is not a decision. That's the whole failure
mode this avoids.

### Never a soft-lock

Orbs save **per level and per index**, so replaying a level to collect what you
missed works and can't double-count. Level Select already exists, so a
shortfall is always a reason to go back, never a dead end. This matters more
once the door does gate.

### What orbs are NOT

They don't buy difficulty. No skips, no extra lives, no easier jumps. A
precision platformer that lets you pay your way past a jump stops being one.

## Naming

Going with **Trevor**. The owner offered Trevor or Jim; it's a constant in the
code, so changing it is a one-line edit.

## Deferred to v2

- The final door actually charging for orbs
- Cosmetics as a second sink
- The story being told to the player at all — right now it exists only here
