# Armored Core-like Prototype

Godot 4 (4.3+) project. Open `project.godot` in the Godot editor and run
`scenes/Main.tscn` (F6) to try it.

## Controls (keyboard only, no mouse)

| Key | Action |
| --- | --- |
| W / A / S / D | Move forward / strafe left / back / strafe right |
| Left / Right | Turn body (yaw) |
| Up / Down | Look camera up / down (pitch) |
| Space | Boost button (see below) |

The boost button is overloaded, the same way it is in the reference games:

- **Boost dash** (ground only): hold Space while moving. Can be held
  indefinitely (drains the boost gauge while active).
- **Air boost**: whenever you're airborne — jumped, dashed off a ledge,
  mid-fall, doesn't matter how you got there — holding Space thrusts you
  both upward *and* toward whatever direction you're moving, at the same
  time. It's boost dash and boost jump combined into one move. No input
  held means it just boosts straight up. This also means boost works after
  a jump even if you let go of Space and pressed it again later, not only
  if you held it through continuously.
- **Jump**: pressing Space while standing still jumps instantly — it
  doesn't wait to see how long you hold it. That initial hop costs no
  gauge; holding (or re-pressing) Space afterward rolls into the air boost
  above.
- **Ground-dash liftoff**: release Space mid boost-dash, then press it
  again within a short window, to launch off the ground straight into an
  air boost.
- **Air control**: even without spending any boost gauge, W/A/S/D still
  move you around while airborne (falling, or between boosts) — this is
  a separate, more modest top speed from walking or boosting, so it
  doesn't need gauge and doesn't feel like full flight.
- **Inertia**: horizontal velocity is only ever eased toward a target speed
  (`Vector3.move_toward`), never set directly, and while airborne it
  bleeds off slowly — momentum carries through jumps and falls. On the
  ground, letting go of the movement keys stops you instantly (legs have
  active control) *unless* you just came out of a boost dash, in which
  case the leftover momentum eases out instead of snapping to zero.
  Touching the ground while not boosting also kills horizontal velocity
  instantly — if you're already holding a direction at that exact instant
  it snaps straight to walking speed instead of ramping up, otherwise it
  goes to zero. Landing mid air-boost is the one case that keeps the
  momentum, instead of getting arrested.
- **Boost gauge**: modeled as a generator, not a simple meter. The
  generator supplies energy at a constant rate at all times; the boosters
  draw from it whenever boost-dashing or air-boosting. Draw above supply
  nets the gauge down, draw below supply (including zero, whenever you're
  not boosting) nets it back up — there's no separate regen delay/cooldown,
  it's just supply minus draw, continuously.
- **Hard landings stagger you**: a timer starts counting the moment
  vertical velocity goes negative (you start actually falling) and resets
  whenever you're grounded or moving upward again. If that timer is past
  a threshold (`HARD_LANDING_FALL_TIME`) when you touch down, all input
  locks out for `HARD_LANDING_STAGGER_DURATION` (0.5s) — no movement,
  turning, camera, or boost, just gravity settling you — regardless of
  whether boost happened to be active at the moment of touchdown. A
  normal jump's hang time is short enough to stay under the threshold, so
  it doesn't trigger this.

All logic lives in `scripts/player.gd`; tunable constants (accel, top
speeds, gauge supply/draw, timing windows) are at the top of the file.

This is scoped to movement/inertia/boost only for now — no weapons, enemies,
or stages yet.
