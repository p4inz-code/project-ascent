# Project Ascent — Movement System Design

## Current Movement (Locked, Do Not Change)

| Mechanic | Input | Behavior |
|---|---|---|
| Run | A/D or ←/→ | 320 px/s max, ground accel 0.08s, decel 0.06s |
| Jump | Space/W | 96px height, asymmetric gravity, variable height on release |
| Coyote time | — | 0.10s grace after leaving ledge |
| Jump buffer | — | 0.10s pre-landing press remembered |
| Wall slide | Move into wall (airborne) | Clamps fall to 130 px/s |
| Wall jump | Jump while wall-sliding | 340 px/s push away, full jump height |
| Air dash | Shift/J | 640 px/s for 0.14s, one per grounding |
| Air control | A/D in air | 0.12s accel, 0.16s decel (slower than ground) |

## Proposed Future Mechanics (Deferred — Not for Levels 1-5)

### Sprint / Run Boost
- **What**: Hold a button to run faster (e.g., 400 px/s)
- **Controls**: Hold Shift (replaces dash when grounded?)
- **Problem**: Conflicts with dash binding. Adds complexity without clear level design benefit for L1-5.
- **Verdict**: DEFERRED. Current run speed is sufficient for L1-5.

### Double Jump
- **What**: Second jump in air
- **Controls**: Jump again while airborne
- **Problem**: Removes the tension of commitment. Wall-jump already provides air mobility.
- **Verdict**: DEFERRED. Would trivialize many precision sections.

### Wall Run
- **What**: Run vertically up walls for a short duration
- **Controls**: Move toward wall while airborne
- **Problem**: Overlaps with wall-slide + wall-jump. Adds input complexity.
- **Verdict**: DEFERRED. Wall-jump chain already provides vertical wall traversal.

### Slide / Roll
- **What**: Ground-level speed boost with low profile
- **Controls**: Down + dash while grounded
- **Problem**: Requires new collision state. Not needed for vertical platforming.
- **Verdict**: DEFERRED. Better suited for horizontal-heavy levels (future).

### Momentum Boost
- **What**: Carrying speed from one surface to another
- **Controls**: Natural (already partially implemented via air control)
- **Problem**: Already exists implicitly through air decel being slower than ground.
- **Verdict**: ALREADY EXISTS in subtle form. No new mechanic needed.

## Recommended Future Additions (When Needed)

### Level 10+: Speed Gate
- **What**: Temporary speed boost pads on the ground
- **Controls**: Walk over them
- **Purpose**: Enables longer jumps for specific sections
- **When**: When level design requires gaps >300px without dash

### Level 15+: Ceiling Jump
- **What**: Jump off ceilings (reverse wall-jump)
- **Controls**: Jump while touching ceiling
- **Purpose**: New traversal dimension for enclosed spaces
- **When**: When levels need upside-down navigation

### Level 20+: Phase Dash
- **What**: Short-range teleport through thin walls
- **Controls**: Dash + direction
- **Purpose**: Puzzle-like traversal for complex level geometry
- **When**: When levels need wall-phasing sections

## Movement Interaction Matrix

| | Run | Jump | Coyote | Buffer | Wall Slide | Wall Jump | Dash |
|---|---|---|---|---|---|---|---|
| **Run** | — | ✅ | ✅ | ✅ | — | — | ✅ |
| **Jump** | ✅ | — | ✅ | ✅ | ✅ | ✅ | — |
| **Coyote** | ✅ | ✅ | — | ✅ | — | — | — |
| **Buffer** | ✅ | ✅ | ✅ | — | — | — | ✅ |
| **Wall Slide** | — | ✅ | — | — | — | ✅ | — |
| **Wall Jump** | ✅ | — | — | — | — | — | — |
| **Dash** | — | — | — | ✅ | — | — | — |

## Current System Strengths

1. **Small input set**: Only 4 buttons (move, jump, dash, restart)
2. **High skill ceiling**: Wall-jump chains, dash-jump combos
3. **Fair difficulty**: Coyote + buffer prevent cheap deaths
4. **Readable**: Every mechanic has clear visual feedback
5. **Tested**: 28 movement tests, 7 feel tests, all passing

## What NOT to Add

- No double jump (trivializes wall-jump)
- No sprint (conflicts with dash)
- No grapple (too complex for current scope)
- No glide (removes fall commitment)
- No climb (overlaps with wall-jump)
- No swim (no water in the game)
- No mount (no vehicles in the game)
