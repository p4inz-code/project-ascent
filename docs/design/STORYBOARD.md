# Opening cutscene — storyboard (v2)

**Runtime:** 45 s · **Skippable:** any key/click/button at any time, with a visible
SKIP prompt and a progress bar · **Plays:** once on first PLAY, replayable from
the title's STORY page · **Format:** pixel art on a 320×180 logical canvas
(1 art px = 6 screen px at 1080p), nearest-filtered, dithered, drawn by
`scripts/cutscene.gd` from generated sprites.

## Premise (kept deliberately small)

Trevor Hale flies survey runs in the research ship **Dawnchaser**, with **PIP**,
the AI built into his suit, riding along. A rift opens, the ship is lost, and
Trevor falls into **THE SPIRE**: a tower-station that sits outside time and has
no sky above it and no ground below it. A single gate waits at the very top and
needs **100 cores** to open. The Spire keeps the cores. That is the whole game:
climb, collect, get out.

**Voice.** PIP is dry, warm and a little too calm. Humour is how it handles
fear. It is the player's guide through the game, so the cutscene is also its
introduction. Lines are short: they are read over action, not instead of it.

**Tone rule.** Every scene must make sense with the sound off and the text
hidden. If a beat only works as dialogue, redraw the beat.

## Palette

Space/void: `#050818 #0b1230 #1b2a5c` · Rift: `#2a1060 #6b3fd6 #c9a8ff #ffffff`
· Ship: `#e8eef8 #9aa6c0 #e04048` · Spire: `#2a2f4a #4a5280 #8a96d0` ·
Accent (amber, the "goal" colour used everywhere): `#ffd378`.

## Scenes

| # | Time | Name | Beat |
|---|------|------|------|
| 1 | 0–5 | ORBIT | Calm before. A world below, a small ship crossing. |
| 2 | 5–10 | COCKPIT | Trevor and PIP. Something is wrong. |
| 3 | 10–16 | THE RIFT | The sky tears open. |
| 4 | 16–21 | THE FALL | The ship breaks; Trevor is alone. |
| 5 | 21–28 | THE SPIRE | Reveal of the tower. |
| 6 | 28–33 | LANDING | He lands. He is alive. |
| 7 | 33–40 | THE GATE | What he has to do, and what it costs. |
| 8 | 40–45 | FIRST STEP | Title slam, into level 1. |

---

### 1 · ORBIT (0–5 s)

- **Picture.** Black fades to a deep-blue star field (90 stars, 3 sizes, slow
  twinkle). A dithered planet limb fills the bottom third (3-colour band, amber
  terminator glow). **Dawnchaser** (the rocket sprite, turned horizontal) drifts
  right→left along a shallow arc, engine flicker on 2 frames.
- **Camera.** Locked. Parallax: stars 0.2×, planet 0.5×, ship 1×.
- **Text (PIP).** `SURVEY RUN 417. ALL SYSTEMS NOMINAL.`
- **Sound.** Low ambient pad fades in; faint radio static.
- **Why.** Establishes scale, calm, and the ship we are about to lose.

### 2 · COCKPIT (5–10 s)

- **Picture.** Hard cut to a cockpit interior: dark console, a round window
  showing stars, **Trevor** (astronaut bust, 2-frame blink, one arm on the
  stick). A PIP icon (small amber diamond) pulses on the dash. Console lights
  blink green… then one flips to amber, then red.
- **Camera.** Slow 2-px push-in over 5 s.
- **Text (PIP).** `TREVOR. SOMETHING IS… OPENING.`
- **Sound.** Beeps; a rising warning tone.
- **Why.** Gives Trevor a face and PIP a voice before anything breaks.

### 3 · THE RIFT (10–16 s)

- **Picture.** Exterior. The ship, tiny, centre-left. Ahead, a vertical crack of
  white-violet splits the stars and widens into the dithered rift (the existing
  `rift.png` rings, now expanding with a shard field). Screen shake builds; at
  the peak, a 2-frame white flash.
- **Camera.** Shake amplitude ramps 0→6 px, then snaps to 0 on the flash.
- **Text (PIP).** `TREVOR — BRACE.`
- **Sound.** Alarm klaxon; sub-bass swell; cut to silence on the flash.
- **Why.** The inciting incident. Must feel big and fast.

### 4 · THE FALL (16–21 s)

- **Picture.** Silence. The ship splits into 3 pieces that tumble away
  (rocket sprite cut into hull/fin/nose). **Trevor** (full body, falling pose)
  tumbles out of the wreck, rotating slowly, tiny against a violet void streaked
  with falling light. A thin amber PIP diamond hovers by his helmet.
- **Camera.** Follows Trevor downward (parallax streaks, 3 depths).
- **Text (PIP).** `SUIT SEALED. SHIP… LOST. I AM SO SORRY, TREVOR.`
- **Sound.** Muffled, underwater feel; a single low note.
- **Why.** The emotional low point. Quiet after loud.

### 5 · THE SPIRE (21–28 s)

- **Picture.** Out of the void, a **vertical tower** emerges: dark stepped
  silhouette, lit windows, ledges, drifting platforms, rising out of frame in
  both directions. No sky, no ground. Trevor, now small, falls toward a
  glowing dock far below. The camera tilts from the base up to reveal height.
- **Camera.** Tilt-up over 4 s, then settle on Trevor.
- **Text (PIP).** `SCANNING… STRUCTURE NOT IN ANY CHART. NO SKY ABOVE IT. NO
  GROUND BELOW.`
- **Sound.** Choir-like synth rises; the world sound returns.
- **Why.** The reveal. This is the game's visual identity in one image.

### 6 · LANDING (28–33 s)

- **Picture.** Trevor drops onto the dock platform using his in-game `land`
  frame, a dust puff (3 particles), then `idle`. A short beat of him looking at
  his gloves.
- **Camera.** Locked, ground-level.
- **Text (PIP).** `GOOD NEWS: YOU ARE ALIVE. BAD NEWS: I HAVE NO BAD NEWS. YET.`
- **Sound.** Thud, relief exhale, gentle melody enters.
- **Why.** A laugh, and the first time the player sees the character they will
  control. Uses the real gameplay sprite on purpose.

### 7 · THE GATE (33–40 s)

- **Picture.** A long vertical pan up the Spire past ledges, a hazard (blade),
  a lava glow, to a **gate** at the very top: tall door, amber keyhole, an
  empty socket ring. A counter materialises beside it: `0 / 100` with the orb
  icon. Small glowing **cores** are visible in alcoves along the way.
- **Camera.** Smooth tilt-up over 6 s, ease in/out.
- **Text (PIP).** `THAT GATE IS THE ONLY WAY OUT. IT NEEDS ONE HUNDRED CORES. THE
  SPIRE KEEPS THEM.`
- **Sound.** The melody swells; a faint heartbeat-like pulse from the gate.
- **Why.** States the whole game in one image: climb, collect, escape.

### 8 · FIRST STEP (40–45 s)

- **Picture.** Back to Trevor. He looks up (head-tilt frame). Zoom to a close
  portrait. PIP's diamond sparks. Hard cut to black, then the **logo slams in**
  (the existing wordmark + peak glyph), with a 1-frame white flash and a 2-px
  shake, over level 1's first screen fading up.
- **Text (PIP).** `I'LL NAVIGATE. YOU DO THE… JUMPING.`
- **Sound.** Drum hit on the slam; music resolves into the level-1 loop.
- **Why.** Hands control to the player with a joke and a title.

## Skip and replay

- A `SKIP ▸ ENTER` prompt is shown from 0 s (dim), brightens on any input;
  holding for 0.4 s skips (so a stray keypress doesn't).
- A thin progress bar runs along the bottom edge.
- Skipping jumps straight to the logo slam frame, not to a hard cut.
- The STORY page in the title menu replays it without altering save state.

## Assets to produce (all generated placeholders, same pipeline as ART.md)

| Asset | Size (art px) | Used in |
|---|---|---|
| Planet limb (dithered) | 320×60 | 1 |
| Dawnchaser, side view | 40×16 | 1 |
| Cockpit interior + window | 320×180 | 2 |
| Trevor bust, 2-frame blink | 48×64 | 2, 8 |
| PIP diamond, 3-frame pulse | 8×8 | 2, 4, 8 |
| Rift expanding frames + shards | 96×96 | 3 |
| Ship break-up pieces ×3 | 20×12 | 4 |
| Trevor falling pose | 18×20 | 4, 5 |
| Spire strip (tileable vertical) | 128×360 | 5, 7 |
| Dock platform + dust | 96×24 | 6 |
| Gate + socket ring + counter | 40×64 | 7 |
| Logo + peak glyph | existing | 8 |

## Acceptance

- Total runtime 45 s ±2 s; every scene ≤ 7 s.
- Readable with sound off and text hidden.
- Skip works from every scene and never leaves a stuck tween or a stray node.
- Runs correctly while the SceneTree is paused (title menu pauses it).
- No frame uses a non-integer sprite scale.
