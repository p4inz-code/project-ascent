# Character art spec — for Illustrator

You're drawing vector with named layers; I rig the skeleton and animate every
part in code. This is what I need for that to work first time.

## Canvas and scale

| | Value |
|---|---|
| Artboard | **64 × 96 px** |
| Character height | **~88px** of that (leave ~4px padding top and bottom) |
| Facing | **Right.** I mirror for left — don't draw both |
| Origin | Character's **feet centred on the bottom edge**, horizontally centred |

The in-game collider is 28×52 and the current character is 52px tall. Drawing
at 88px gives headroom for the camera-zoom decision that's still open, and
scales down cleanly. **Don't** draw at 52px — I can scale down, not up.

## Layers — these exact names

Each must be its own top-level layer, drawn in its **neutral rest pose**
(standing, arms down, facing right). I rotate them around their joints, so a
part drawn mid-swing will look wrong in every other frame.

```
head          includes helmet/hood — NOT the visor
visor         separate: it glows and changes colour
torso
arm_back      the arm further from camera
arm_front
leg_back
leg_front
scarf         optional; if present I sim it with physics
accent        anything that should take the player's chosen colour
```

**Pivot rule:** draw each limb so its **joint end** is where it attaches — arms
pivot at the shoulder, legs at the hip. I place the rotation point at the
top-centre of each limb layer's bounding box, so keep the joint at that corner.

## Colour

Draw in **flat fills, no gradients or strokes**. Anything on the `accent` layer
and the `visor` get recoloured at runtime from the player's chosen colour, so
draw those in **pure white** — I tint them. Everything else keep as-is.

Two hard constraints from the game's readability rules:

- The character must stay legible against **near-black backgrounds** — it's
  currently 4.6:1 against terrain and that's what keeps it findable mid-run.
- **No outline stroke.** Platforms use a lit top edge as the game's single most
  load-bearing cue, and an outlined character competes with it.

## Delivery

One **SVG** (preferred) or **AI** file, layers named exactly as above. If SVG,
export with "Preserve Illustrator Editing Capabilities" off and layer names
preserved as `id` attributes.

If you'd rather send PNGs: one PNG per layer, same 64×96 canvas, transparent
background, named `head.png`, `visor.png`, etc. Same result, slightly more
files.

## What I do with it

Rig it as a `Skeleton2D` and drive every animation in code — run cycle, jump,
fall, dash lean, land squash, wall slide, the spin, and the scarf. You don't
draw a single frame of animation.

## Monsters, later

Same canvas rules. Layer names per monster are up to you, but keep the pattern:
one layer per part that should move independently, drawn in rest pose, joint at
the top-centre of its bounds.

## Still open

You said you have the backstory — how and why. **Send that before I lock the
design.** You picked the sleek astronaut/runner direction, and whether that
stays right depends entirely on what the story says the character *is*. A
scavenger, a prisoner and an explorer are the same silhouette budget and three
different characters.
