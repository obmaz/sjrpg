# Resource meter

`ResourceMeter(session, height: 15)` owns the resource label, current/max accessibility
label and a separate clipped fluid paint layer. It is a visual view of `Progress`:
it never writes energy, health, cooldowns, random state or world state.

`height` is a minimum, not a command to shrink the label. Reserve at least
`ResourceMeter.minimumHeight(MediaQuery.textScalerOf(context))` in the surrounding
HUD. The 12px label keeps its text scale and 1.2 line height with 2px vertical
padding: 17px at normal scale and 21px at 130%. A 22px resource row accommodates
both. Nearby experience and status rows must use that actual height. The visible
label floors current energy, while its single semantics node includes current
and maximum energy.

Rage uses amber/red fluid currents and rising embers; mana uses cyan/blue currents
and traveling glints. Their paths deform even when the resource value is constant.
Every current, highlight and particle is clipped to the rounded vessel and the
actual horizontal fill. Zero energy draws only the empty vessel and label.

A private ticker repaints only the localized fluid layer. Shared `HudMotionClock`
samples actual `Adventure.elapsed` at intervals of at least 1/30 second, returns
the accumulated simulation delta up to 0.1 second and discards any overshoot. It
never substitutes wall time or applies engine time scale twice. A legitimate
10Hz simulation therefore retains its real effect timing, while long gaps never
become an animation backlog. Session pause, direct engine pause, zero engine time scale, background
lifecycle, disabled ticker mode and reduced motion freeze the phase. The first
frame after resuming establishes a new time baseline. Value changes still update
the fill and label while the phase is frozen. A session without a game renders a
static meter. Replacing the session detaches the old listener and resets phase;
disposal removes lifecycle/listener/ticker ownership and releases cached shaders.
Engine pause/scale gates have no notifier: tickers keep polling them without
repainting so a direct engine resume also works after a paused HUD refresh.
`allowReducedMotion` lets the health view use shared elapsed only to expire a brief
static damage cue; resource motion never opts into that exception.

The focused native tests check full, half and empty meters for both classes,
constant-value motion, fill clipping, resource-state preservation, large labels,
30Hz cadence, bounded long-frame behavior, pause/hitstop/background/reduced motion,
static initialization and session replacement. Optional `RESOURCE_PROOF_DIR`
exports actual Flutter raster frames; these images do not claim device FPS.
