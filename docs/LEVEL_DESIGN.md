# Project Ascent — 25-Level Master Campaign Design

Authoritative level design document. Every level must be implemented from this
specification. Do not deviate without updating this document first.

**Total levels:** 25  
**Estimated playtime:** 2.5–4 hours first playthrough  
**Checkpoint milestones:** 5, 10, 15, 20, 25  

---

## Campaign Arc Overview

The player begins as a small figure at the base of an enormous vertical
structure and climbs toward the sky. Each level represents a higher section
of the ascent, with increasing danger, complexity, and visual intensity.

**Act I — Foundation (Levels 1–5):** Learn the movement language. Simple
platforming introduces jump, dash, wall-slide, and wall-jump. Level 5 is
the first boss chase — the player escapes a pursuing entity.

**Act II — Mastery (Levels 6–10):** Demand more of the player. Introduce
multi-step platform sequences, tighter precision, and environmental hazards
that require all movement tools. Level 10 is a faster boss chase with a
more aggressive pursuer.

**Act III — Challenge (Levels 11–15):** Complex route combinations. Risk/reward
shortcuts. Longer levels with meaningful middle sections. Level 15 is a
vertical boss chase with environmental traps.

**Act IV — Ordeal (Levels 16–20):** High difficulty. Demanding combinations of
all mechanics. Environmental pressure. Level 20 is a multi-phase boss chase
through a collapsing environment.

**Act V — Apex (Levels 21–25):** Endgame mastery. Long, memorable sequences.
Strongest visual escalation. Level 25 is the final boss — an endurance chase
that tests everything the player has learned.

---

## Per-Level Specifications

---

### LEVEL 1 — FIRST STEPS
- **Purpose:** Teach basic movement — run, jump, variable height
- **Playtime:** 25–40 seconds
- **Difficulty:** ★☆☆☆☆ (Gentle)
- **Primary mechanic:** Jump
- **Secondary mechanic:** Variable jump height
- **New mechanic:** None (first exposure)
- **Structure:** 5–6 platforms ascending gently right-to-right
- **Sections:** Ground → gentle rightward steps → goal on a wide final platform
- **Hazards:** Kill depth only (forgiving)
- **Vertical/horizontal:** Mostly horizontal, gentle upward trend
- **Checkpoint:** Starting level (checkpoint = 2 after completion)
- **Visual theme:** Warm blue-grey sky, friendly lighting, readable platforms
- **Audio/mood:** Calm music, no urgency
- **Boss:** None
- **Structure:** Intro → 4 easy jumps → wide goal platform → completion
- **Skill learned:** Basic jump timing
- **Different from:** Nothing (this IS the introduction)
- **Prepares for:** Level 2's slightly wider gaps

---

### LEVEL 2 — GAINING HEIGHT
- **Purpose:** Reinforce jumping, introduce slightly longer gaps
- **Playtime:** 30–50 seconds
- **Difficulty:** ★☆☆☆☆ (Gentle)
- **Primary mechanic:** Jump
- **Secondary mechanic:** Coyote time, jump buffering
- **New mechanic:** None (reinforces existing)
- **Structure:** 8–10 platforms with wider gaps than Level 1
- **Sections:** Ground → rightward steps (wider) → first real gap → ascending finish
- **Hazards:** Kill depth only
- **Vertical/horizontal:** Rightward with clear upward trend
- **Checkpoint:** After Level 1 completion
- **Visual theme:** Same sky as Level 1, slightly darker lower areas
- **Audio/mood:** Still calm, hint of elevation
- **Boss:** None
- **Structure:** Ground → step-up intro → gap → ascending section → goal
- **Skill learned:** Comfortable with variable gap widths
- **Different from:** Level 1 — gaps are 20–40% wider, timing matters more
- **Prepares for:** Level 3's vertical sections

---

### LEVEL 3 — THE FIRST WALLS
- **Purpose:** Introduce wall-slide and wall-jump naturally
- **Playtime:** 40–70 seconds
- **Difficulty:** ★★☆☆☆ (Easy)
- **Primary mechanic:** Wall-slide, wall-jump
- **Secondary mechanic:** Jump precision
- **New mechanic:** Wall-slide + wall-jump
- **Structure:** Rightward intro → wall-jump shaft → exit → goal
- **Sections:** Easy intro → enclosed shaft with walls on both sides → recovery platform → ascending exit → goal
- **Hazards:** Kill depth (falling in the shaft)
- **Vertical/horizontal:** Horizontal intro, then strong vertical shaft
- **Checkpoint:** After Level 2 completion
- **Visual theme:** Introduction of darker wall textures, vertical emphasis
- **Audio/mood:** Slightly more tension, wall-slide sound introduced
- **Boss:** None
- **Structure:** Intro → wall shaft (3–4 alternating wall jumps) → exit platform → goal
- **Skill learned:** Wall interaction as a tool
- **Different from:** Level 2 — first enclosed vertical space
- **Prepares for:** Level 4's dash requirement

---

### LEVEL 4 — THE FIRST DASH
- **Purpose:** Introduce air dash as essential traversal
- **Playtime:** 45–80 seconds
- **Difficulty:** ★★☆☆☆ (Easy-Moderate)
- **Primary mechanic:** Air dash
- **Secondary mechanic:** Dash + jump combination
- **New mechanic:** Air dash
- **Structure:** Intro → small gap → dash-required gap → recovery → wall section → goal
- **Sections:** Easy start → teach dash with a safe gap → require dash for a wider gap → wall-jump recovery → goal
- **Hazards:** Kill depth (falling between dash platforms)
- **Vertical/horizontal:** Rightward with moderate vertical
- **Checkpoint:** After Level 3 completion
- **Visual theme:** Warmer tones, dash-gate platforms visually distinct
- **Audio/mood:** Energy building, dash sound introduced
- **Boss:** None
- **Structure:** Intro → safe dash practice → required dash → recovery → goal
- **Skill learned:** Dash as a traversal necessity
- **Different from:** Level 3 — dash is now essential, not optional
- **Prepares for:** Level 5 boss chase (dash will be critical for escape)

---

### LEVEL 5 — ESCAPE ★ FIRST BOSS CHASE ★
- **Purpose:** First major milestone — survive a pursuing boss
- **Playtime:** 60–120 seconds
- **Difficulty:** ★★★☆☆ (Moderate)
- **Primary mechanic:** All movement under pressure
- **Secondary mechanic:** Dash-jump combos while being chased
- **New mechanic:** Boss/minion pursuit
- **Structure:** Pre-chase intro → trigger zone → chase section (increasing difficulty) → goal
- **Sections:**
  1. Intro area (safe, teaches layout)
  2. Chase trigger — boss + 4 minions appear behind the player
  3. Chase section 1 — easy jumps while being pursued
  4. Chase section 2 — wall-jump corridor
  5. Chase section 3 — dash platforms, boss speeds up
  6. Final escape → goal
- **Hazards:** Boss/minions (catch = death), kill depth
- **Vertical/horizontal:** Strong upward + rightward movement under pressure
- **Checkpoint:** After Level 5 completion (MAJOR MILESTONE)
- **Visual theme:** Danger-tinted atmosphere, red accents, dramatic lighting
- **Audio/mood:** Music intensifies (1.15x pitch), chase audio
- **Boss:** Red entity, follows player horizontally, jumps to reach platforms
  - Speed: 170 → 320 px/s (accelerates)
  - Catch distance: 48px
- **Minions:** 4 smaller entities, flanking routes
  - Speed: 195 px/s
  - Catch distance: 36px
- **Structure:** Safe → Warning (1.5s) → Chase → Escape → Goal
- **Skill learned:** Movement under pressure, all tools combined
- **Different from:** Levels 1–4 — this is the first chase
- **Prepares for:** Level 6's longer, more complex levels

---

### LEVEL 6 — LONGER PATHS
- **Purpose:** First truly long level — demand sustained traversal
- **Playtime:** 90–150 seconds
- **Difficulty:** ★★★☆☆ (Moderate)
- **Primary mechanic:** Extended platforming sequences
- **Secondary mechanic:** Multiple recovery points
- **New mechanic:** Multi-section level structure
- **Structure:** 3 distinct sections with safe areas between them
- **Sections:** Section A (intro) → Section B (ascending) → Section C (final push to goal)
- **Hazards:** Kill depth, longer falls = more punishment
- **Vertical/horizontal:** Extended rightward with 3 ascents
- **Checkpoint:** After Level 5 completion
- **Visual theme:** Transitioning to darker, more atmospheric tones
- **Audio/mood:** Building intensity
- **Boss:** None
- **Skill learned:** Endurance, pacing
- **Different from:** Level 5 — no chase pressure, but much longer traversal
- **Prepares for:** Level 7's tighter precision

---

### LEVEL 7 — PRECISION GAPS
- **Purpose:** Demand precise landing on smaller platforms
- **Playtime:** 90–150 seconds
- **Difficulty:** ★★★☆☆ (Moderate)
- **Primary mechanic:** Precision platforming
- **Secondary mechanic:** Wall-jump recovery
- **New mechanic:** Narrow platforms
- **Structure:** Mixed wide/narrow platforms with intentional precision sections
- **Sections:** Easy intro → precision stepping → recovery → dash section → goal
- **Hazards:** Kill depth, precision failure = long fall
- **Vertical/horizontal:** Rightward with vertical zigzag
- **Checkpoint:** After Level 6 completion
- **Visual theme:** Contraction — spaces feel tighter
- **Audio/mood:** Tension without chase
- **Boss:** None
- **Skill learned:** Precision on narrow targets
- **Different from:** Level 6 — platforms are smaller and gaps more intentional
- **Prepares for:** Level 8's dash-wall-jump combos

---

### LEVEL 8 — COMBO TRAVERAL
- **Purpose:** Combine dash + wall-jump in sequence
- **Playtime:** 100–160 seconds
- **Difficulty:** ★★★☆☆ (Moderate-Hard)
- **Primary mechanic:** Dash → wall-jump chains
- **Secondary mechanic:** Air control during sequences
- **New mechanic:** Dash-wall-jump combo chains
- **Structure:** Teach combo → require combo → test combo under pressure
- **Sections:** Combo tutorial section → application section → extended combo chain → goal
- **Hazards:** Kill depth, missing a wall-jump = long fall
- **Vertical/horizontal:** Strong vertical with horizontal dashes
- **Checkpoint:** After Level 7 completion
- **Visual theme:** Industrial/structural emphasis
- **Audio/mood:** Rhythmic — dash → wall → dash → wall
- **Boss:** None
- **Skill learned:** Chaining movement abilities fluidly
- **Different from:** Level 7 — wall-jump and dash must work together
- **Prepares for:** Level 9's environmental pressure

---

### LEVEL 9 — RISING DANGER
- **Purpose:** Environmental pressure + tighter platforms
- **Playtime:** 100–180 seconds
- **Difficulty:** ★★★★☆ (Hard)
- **Primary mechanic:** Precision + speed
- **Secondary mechanic:** All mechanics under time pressure
- **New mechanic:** Tighter timing windows
- **Structure:** Speed-sensitive sections where hesitation is punished
- **Sections:** Quick intro → time-sensitive gap sequence → precision climb → wall-jump escape → goal
- **Hazards:** Kill depth, fall resets significant progress
- **Vertical/horizontal:** Steep vertical with horizontal dashes
- **Checkpoint:** After Level 8 completion
- **Visual theme:** Darker, more oppressive atmosphere
- **Audio/mood:** Music feels more urgent
- **Boss:** None
- **Skill learned:** Maintaining momentum through difficult sections
- **Different from:** Level 8 — timing matters, not just execution
- **Prepares for:** Level 10's faster boss chase

---

### LEVEL 10 — HUNTED ★ SECOND BOSS CHASE ★
- **Purpose:** Faster boss, more minions, tighter escape route
- **Playtime:** 80–150 seconds
- **Difficulty:** ★★★★☆ (Hard)
- **Primary mechanic:** Escape under pressure
- **Secondary mechanic:** Precision while being chased
- **New mechanic:** Faster boss (220→400 px/s), 5 minions
- **Structure:** Pre-chase → trigger → escalating chase → final escape → goal
- **Sections:**
  1. Pre-chase area (medium difficulty)
  2. Chase trigger — boss + 5 minions
  3. Chase section — tighter platforms than Level 5
  4. Wall-jump corridor — boss catches up
  5. Dash escape — boss at near-max speed
  6. Final sprint → goal
- **Hazards:** Boss/minions (faster), kill depth
- **Vertical/horizontal:** Strong upward under pressure
- **Checkpoint:** After Level 10 completion (MAJOR MILESTONE)
- **Visual theme:** Intensified danger, deeper reds
- **Audio/mood:** Music at 1.2x pitch, more aggressive
- **Boss:** Faster than Level 5, 5 minions instead of 4
  - Speed: 220 → 400 px/s
  - More aggressive pursuit
- **Structure:** More demanding than Level 5 in every dimension
- **Skill learned:** Speed under extreme pressure
- **Different from:** Level 5 — faster boss, more minions, tighter route
- **Prepares for:** Level 11's advanced traversal

---

### LEVEL 11 — VERTICAL MAZE
- **Purpose:** Complex vertical routing with multiple paths
- **Playtime:** 120–200 seconds
- **Difficulty:** ★★★★☆ (Hard)
- **Primary mechanic:** Vertical navigation
- **Secondary mechanic:** Route choice
- **New mechanic:** Non-linear vertical level
- **Structure:** Branching vertical paths, some easier, some faster
- **Sections:** Base → fork (left/easy, right/hard) → reconverge → vertical shaft → goal
- **Hazards:** Kill depth, wrong path = dead end + backtracking
- **Vertical/horizontal:** Primarily vertical
- **Checkpoint:** After Level 10 completion
- **Visual theme:** Complex structural architecture
- **Audio/mood:** Exploration-focused
- **Boss:** None
- **Skill learned:** Reading level layout, choosing routes
- **Different from:** Levels 1–10 — non-linear pathfinding
- **Prepares for:** Level 12's risk/reward shortcuts

---

### LEVEL 12 — RISK AND REWARD
- **Purpose:** Optional shortcuts that reward skilled play
- **Playtime:** 120–200 seconds
- **Difficulty:** ★★★★☆ (Hard)
- **Primary mechanic:** Risk assessment
- **Secondary mechanic:** Shortcuts vs safe paths
- **New mechanic:** Reward shortcuts (skip sections with harder platforming)
- **Structure:** Main path + optional shortcut paths at key decision points
- **Sections:** Decision point 1 → Decision point 2 → Decision point 3 → convergence → goal
- **Hazards:** Kill depth, shortcut failure = fall to main path (not death)
- **Vertical/horizontal:** Mixed
- **Checkpoint:** After Level 11 completion
- **Visual theme:** Split visual language — safe vs dangerous routes
- **Audio/mood:** Tension at decision points
- **Boss:** None
- **Skill learned:** Risk assessment, map awareness
- **Different from:** Level 11 — choice matters
- **Prepares for:** Level 13's complex combinations

---

### LEVEL 13 — COMBINATION LOCK
- **Purpose:** Require all mechanics in sequence
- **Playtime:** 120–200 seconds
- **Difficulty:** ★★★★☆ (Hard)
- **Primary mechanic:** Full moveset in sequence
- **Secondary mechanic:** Sequential mastery
- **New mechanic:** None (tests everything learned)
- **Structure:** Sections that each require a specific mechanic, chained together
- **Sections:** Jump section → wall section → dash section → combo section → goal
- **Hazards:** Kill depth, missing any mechanic = fall
- **Vertical/horizontal:** Full range
- **Checkpoint:** After Level 12 completion
- **Visual theme:** Diverse — each section has distinct visual character
- **Audio/mood:** Building to climax
- **Boss:** None
- **Skill learned:** Fluid use of entire moveset
- **Different from:** Level 12 — no shortcuts, must use everything
- **Prepares for:** Level 14's endurance

---

### LEVEL 14 — ENDURANCE
- **Purpose:** Longest level yet — sustained difficulty
- **Playtime:** 150–240 seconds
- **Difficulty:** ★★★★☆ (Hard)
- **Primary mechanic:** Endurance + consistency
- **Secondary mechanic:** Recovery management
- **New mechanic:** Extended level with safe recovery areas
- **Structure:** 5+ sections with recovery platforms between them
- **Sections:** Section A → recovery → Section B → recovery → Section C → recovery → Section D → recovery → Section E → goal
- **Hazards:** Kill depth, long falls reset many sections
- **Vertical/horizontal:** Extended horizontal with vertical sections
- **Checkpoint:** After Level 13 completion
- **Visual theme:** Environmental storytelling — climbing through different zones
- **Audio/mood:** Sustained intensity
- **Boss:** None
- **Skill learned:** Consistency over long sequences
- **Different from:** Level 13 — endurance, not just combination
- **Prepares for:** Level 15's environmental boss

---

### LEVEL 15 — TRAPPED ★ THIRD BOSS CHASE ★
- **Purpose:** Boss chase through a level with environmental traps
- **Playtime:** 90–160 seconds
- **Difficulty:** ★★★★★ (Very Hard)
- **Primary mechanic:** Escape + environmental awareness
- **Secondary mechanic:** Avoiding static hazards during chase
- **New mechanic:** Environmental traps during chase (narrow passages, hazard zones)
- **Structure:** Pre-chase → trigger → chase through trapped corridors → escape → goal
- **Sections:**
  1. Pre-chase (medium difficulty with trap preview)
  2. Chase trigger — boss + 5 minions
  3. Chase through narrow corridors (boss + minion + tight spaces)
  4. Vertical escape section
  5. Final dash sequence → goal
- **Hazards:** Boss/minions + environmental traps + kill depth
- **Vertical/horizontal:** Strong vertical
- **Checkpoint:** After Level 15 completion (MAJOR MILESTONE)
- **Visual theme:** Trap-lit, mechanical danger, red hazard indicators
- **Audio/mood:** Music at 1.25x, trap sounds, chase tension
- **Boss:** Same speed as Level 10 but in tighter spaces
  - Speed: 230 → 420 px/s
  - 5 minions
  - Environmental traps add pressure
- **Structure:** Boss + environment = maximum pressure
- **Skill learned:** Spatial awareness under multi-source pressure
- **Different from:** Level 10 — environment is also dangerous
- **Prepares for:** Level 16's high difficulty

---

### LEVEL 16 — THE GAUNTLET
- **Purpose:** Test precision endurance
- **Playtime:** 150–240 seconds
- **Difficulty:** ★★★★★ (Very Hard)
- **Primary mechanic:** Sustained precision
- **Secondary mechanic:** Recovery from mistakes
- **New mechanic:** None (pure skill test)
- **Structure:** Continuous precision platforming with few safe areas
- **Sections:** 6+ precision sections with minimal recovery
- **Hazards:** Kill depth, precision failure = significant progress loss
- **Vertical/horizontal:** Extended rightward with vertical precision
- **Checkpoint:** After Level 15 completion
- **Visual theme:** Stark, minimal, focused
- **Audio/mood:** Intense focus
- **Boss:** None
- **Skill learned:** Precision endurance
- **Different from:** Level 14 — no recovery areas, pure precision
- **Prepares for:** Level 17's complex routing

---

### LEVEL 17 — TWISTED PATHS
- **Purpose:** Complex routing with misleading visual cues
- **Playtime:** 150–250 seconds
- **Difficulty:** ★★★★★ (Very Hard)
- **Primary mechanic:** Route reading
- **Secondary mechanic:** Platform identification
- **New mechanic:** Visually deceptive platforming (platforms that look reachable but aren't, and vice versa)
- **Structure:** Route that requires reading the level, not just reacting
- **Sections:** Misleading section → correct route section → challenging correct section → goal
- **Hazards:** Kill depth, wrong route = death
- **Vertical/horizontal:** Complex routing
- **Checkpoint:** After Level 16 completion
- **Visual theme:** Disorienting architecture, visual complexity
- **Audio/mood:** Unsettling
- **Boss:** None
- **Skill learned:** Level reading, patience
- **Different from:** Level 16 — mental challenge, not just mechanical
- **Prepares for:** Level 18's speed pressure

---

### LEVEL 18 — SPEED TRIAL
- **Purpose:** Speed-sensitive sections requiring momentum
- **Playtime:** 120–200 seconds
- **Difficulty:** ★★★★★ (Very Hard)
- **Primary mechanic:** Maintaining momentum
- **Secondary mechanic:** Speed chains
- **New mechanic:** Sections where stopping = falling (conveyor-like or crumbling)
- **Structure:** Speed-sensitive sequences where hesitation is death
- **Sections:** Momentum start → speed chain 1 → recovery → speed chain 2 → speed chain 3 → goal
- **Hazards:** Kill depth, momentum loss = death
- **Vertical/horizontal:** Fast rightward with vertical momentum sections
- **Checkpoint:** After Level 17 completion
- **Visual theme:** Motion blur feel, speed lines, dynamic
- **Audio/mood:** Fast-paced, rhythmic
- **Boss:** None
- **Skill learned:** Momentum maintenance
- **Different from:** Level 17 — speed, not patience
- **Prepares for:** Level 19's complex combinations

---

### LEVEL 19 — THE CRUCIBLE
- **Purpose:** Combine everything learned — the ultimate skill test before endgame
- **Playtime:** 180–300 seconds
- **Difficulty:** ★★★★★ (Very Hard)
- **Primary mechanic:** Everything
- **Secondary mechanic:** Adaptability
- **New mechanic:** Dynamic section transitions (sections that change characteristics)
- **Structure:** Multi-phase level with different mechanical demands per section
- **Sections:** Precision → speed → wall-jump → dash combo → endurance → goal
- **Hazards:** All types
- **Vertical/horizontal:** Full range
- **Checkpoint:** After Level 18 completion
- **Visual theme:** Intensity building toward climax
- **Audio/mood:** Building toward endgame
- **Boss:** None
- **Skill learned:** Total mastery
- **Different from:** All previous — tests everything at once
- **Prepares for:** Level 20's massive boss

---

### LEVEL 20 — DOMINATION ★ FOURTH BOSS CHASE ★
- **Purpose:** Multi-phase boss through collapsing environment
- **Playtime:** 120–200 seconds
- **Difficulty:** ★★★★★★ (Extreme)
- **Primary mechanic:** Escape + adaptability
- **Secondary mechanic:** Multi-phase boss behavior
- **New mechanic:** Boss with 2 chase phases, 6 minions
- **Structure:** Phase 1 chase → brief respite → Phase 2 chase (faster, more dangerous) → goal
- **Sections:**
  1. Pre-chase intro
  2. Phase 1 — boss + 6 minions, moderate speed
  3. Brief recovery area (5 seconds)
  4. Phase 2 — boss faster, 6 minions, narrower route
  5. Final escape → goal
- **Hazards:** Boss (2 phases) + 6 minions + kill depth
- **Vertical/horizontal:** Strong vertical
- **Checkpoint:** After Level 20 completion (MAJOR MILESTONE)
- **Visual theme:** Destruction, intensity, dramatic lighting
- **Audio/mood:** Music at 1.3x, dramatic boss theme variation
- **Boss:** 2-phase, faster than Level 15
  - Phase 1: 250 → 450 px/s
  - Phase 2: 300 → 500 px/s
  - 6 minions
- **Structure:** The most intense chase yet
- **Skill learned:** Adaptation to changing conditions
- **Different from:** Level 15 — 2 phases, more minions, faster
- **Prepares for:** Level 21's endgame

---

### LEVEL 21 — THE ASCENT CONTINUES
- **Purpose:** Endgame introduction — long, demanding level
- **Playtime:** 180–300 seconds
- **Difficulty:** ★★★★★★ (Extreme)
- **Primary mechanic:** Endurance + precision
- **Secondary mechanic:** All mechanics at endgame level
- **New mechanic:** None (pure endgame challenge)
- **Structure:** 7+ sections of increasing difficulty
- **Sections:** Progressive difficulty curve from hard to extreme
- **Hazards:** All types, long falls = massive progress loss
- **Vertical/horizontal:** Extended vertical
- **Checkpoint:** After Level 20 completion
- **Visual theme:** Approaching the apex — sky getting brighter
- **Audio/mood:** Epic, building
- **Boss:** None
- **Skill learned:** Endgame endurance
- **Different from:** Level 19 — longer, harder, more sustained
- **Prepares for:** Level 22's complexity

---

### LEVEL 22 — CRYSTAL MAZE
- **Purpose:** Complex internal routing with tight spaces
- **Playtime:** 180–300 seconds
- **Difficulty:** ★★★★★★ (Extreme)
- **Primary mechanic:** Complex routing in tight spaces
- **Secondary mechanic:** Wall-jump mastery
- **New mechanic:** Multi-room internal navigation
- **Structure:** Connected tight sections requiring wall-jump mastery
- **Sections:** Room 1 → Room 2 → Room 3 → Room 4 → Room 5 → exit → goal
- **Hazards:** All types, tight spaces = easy death
- **Vertical/horizontal:** Internal vertical + horizontal
- **Checkpoint:** After Level 21 completion
- **Visual theme:** Crystalline, angular, complex internal geometry
- **Audio/mood:** Echo-y, enclosed
- **Boss:** None
- **Skill learned:** Navigation in constrained spaces
- **Different from:** Level 21 — enclosed, not open
- **Prepares for:** Level 23's speed

---

### LEVEL 23 — APEX SPEED
- **Purpose:** Maximum speed challenge at endgame difficulty
- **Playtime:** 150–250 seconds
- **Difficulty:** ★★★★★★ (Extreme)
- **Primary mechanic:** Speed + precision at endgame level
- **Secondary mechanic:** Momentum chains
- **New mechanic:** None (peak speed challenge)
- **Structure:** Fast, flowing level where momentum is everything
- **Sections:** Speed start → momentum chain 1 → brief recovery → momentum chain 2 → momentum chain 3 → goal
- **Hazards:** Kill depth, momentum loss = death
- **Vertical/horizontal:** Fast rightward with vertical momentum
- **Checkpoint:** After Level 22 completion
- **Visual theme:** Blur, speed, energy
- **Audio/mood:** Fastest music, maximum energy
- **Boss:** None
- **Skill learned:** Maximum speed mastery
- **Different from:** Level 18 — endgame speed, not mid-game speed
- **Prepares for:** Level 24's endurance

---

### LEVEL 24 — THE FINAL WALL
- **Purpose:** Endurance test before the final boss
- **Playtime:** 240–360 seconds (longest level)
- **Difficulty:** ★★★★★★ (Extreme)
- **Primary mechanic:** Ultimate endurance
- **Secondary mechanic:** Everything at maximum difficulty
- **New mechanic:** None (the ultimate test)
- **Structure:** 8+ sections, each harder than the last, with recovery between
- **Sections:** Progressive sections of extreme difficulty with safe recovery areas
- **Hazards:** All types, death resets the most progress of any level
- **Vertical/horizontal:** Extended in all directions
- **Checkpoint:** After Level 23 completion
- **Visual theme:** Approaching the summit — dramatic sky, dramatic lighting
- **Audio/mood:** Epic, climactic
- **Boss:** None
- **Skill learned:** Total endurance
- **Different from:** Level 21 — longer, harder, the final test before Level 25
- **Prepares for:** Level 25's final boss

---

### LEVEL 25 — SUMMIT ★ FINAL BOSS CHASE ★
- **Purpose:** The climax — survive the ultimate chase to reach the top
- **Playtime:** 150–250 seconds
- **Difficulty:** ★★★★★★★ (Legendary)
- **Primary mechanic:** Everything under maximum pressure
- **Secondary mechanic:** Endurance chase
- **New mechanic:** 3-phase boss, 6 minions, environmental destruction
- **Structure:** 3-phase chase through a collapsing environment
- **Sections:**
  1. Pre-chase summit intro (brief, atmospheric)
  2. Phase 1 — boss + 6 minions, full speed from start
  3. Phase 2 — environment narrows, boss faster
  4. Phase 3 — final escape through the tightest section yet
  5. Summit goal — completion
- **Hazards:** Boss (3 phases) + 6 minions + environment + kill depth
- **Vertical/horizontal:** Strong upward — the final ascent
- **Checkpoint:** GAME COMPLETE after Level 25
- **Visual theme:** Summit — bright sky above, dramatic lighting, the apex
- **Audio/mood:** Music at 1.35x, triumphant, climactic
- **Boss:** 3-phase ultimate boss
  - Phase 1: 300 → 500 px/s
  - Phase 2: 350 → 550 px/s
  - Phase 3: 400 → 600 px/s
  - 6 minions
- **Structure:** The ultimate challenge
- **Skill learned:** Everything — this is the final exam
- **Different from:** Level 20 — 3 phases, maximum speed, the climax
- **Prepares for:** Nothing — this is the end

---

## Boss Escalation Summary

| Level | Boss Speed | Minions | Phases | Catch Distance | Key Difference |
|---|---|---|---|---|---|
| 5 | 170→320 | 4 | 1 | 48px | Introduction |
| 10 | 220→400 | 5 | 1 | 48px | Faster, more minions |
| 15 | 230→420 | 5 | 1 | 48px | Environmental traps |
| 20 | 250→500 | 6 | 2 | 44px | Two phases |
| 25 | 300→600 | 6 | 3 | 40px | Three phases, finale |

## Difficulty Curve

```
Level:  1  2  3  4  5  6  7  8  9  10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25
Diff:   1  1  2  2  3  3  3  3  4  4  4  4  4  4  5  5  5  5  5  6  6  6  6  6  7
        ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔
        Foundation    Mastery      Challenge      Ordeal        Apex
```

## Skill Introduction Order

| Level | New Skill |
|---|---|
| 1 | Jump |
| 3 | Wall-slide, wall-jump |
| 4 | Air dash |
| 5 | Boss/minion pursuit |
| 6 | Multi-section levels |
| 7 | Narrow platforms |
| 8 | Dash-wall-jump chains |
| 11 | Non-linear routing |
| 12 | Risk/reward shortcuts |
| 15 | Environmental traps |
| 17 | Visual deception |
| 18 | Momentum chains |
| 20 | Multi-phase boss |
| 25 | Environmental destruction |

## Visual Theme Progression

| Levels | Theme | Sky | Atmosphere |
|---|---|---|---|
| 1–3 | Dawn | Warm blue-grey | Welcoming |
| 4–5 | Morning | Cooler, more contrast | Building tension |
| 6–9 | Midday | Bright, clear | Open, exposed |
| 10–14 | Dusk | Orange-purple | Dramatic |
| 15–19 | Night | Deep indigo | Ominous |
| 20–24 | Storm | Dark with lightning | Intense |
| 25 | Dawn again | Bright golden | Triumphant |
