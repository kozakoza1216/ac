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
| B | Overed Boost, OB-type core only (see below) |

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
- **Hard landings stagger you**: judged by actual impact speed — the
  vertical velocity at the instant you touch down — not how long you were
  falling. If that's at or past `HARD_LANDING_IMPACT_SPEED` (14), all
  input locks out for `HARD_LANDING_STAGGER_DURATION` (0.5s) — no
  movement, turning, camera, or boost, just gravity settling you —
  regardless of whether boost happened to be active at touchdown. A
  normal jump's landing speed stays under the threshold, so it doesn't
  trigger this, and neither does a slow, boost-cushioned descent even
  after a long fall.

- **Overed Boost (B, OB-core only)**: a separate, far stronger speed
  multiplier on top of whatever you're currently doing (walking,
  air-control, boost dash, air boost), gated on the equipped core being
  an OB type (`CorePart.is_ob_type`). Press B to start a fixed 1s charge
  (`OB_CHARGE_TIME`) — an "OB CHARGE" bar shows on the HUD, and you can
  move normally during it, but boosting (Space) while charging generates
  heat as if OB and boost were already running together (see heat,
  below), even though the speed boost itself hasn't kicked in yet. Once
  charged, OB multiplies your current move speed and accel
  (`OB_SPEED_MULTIPLIER` / `OB_ACCEL_MULTIPLIER`) and requires you to
  keep giving movement input the entire time — no input, or running out
  of EN, ends it exactly like pressing B again would. Ending it in the
  air just stops; ending it on the ground brakes to a stop first (no
  input accepted until the brake finishes), at a rate set by the
  equipped legs' `brake_performance`.
- **Heat**: OB (and boosting while OB is charging) generates heat,
  tracked apart from — but drawing on the same underlying gauge as —
  the normal boost dash/air-boost EN cost, per how much was asked for
  each. Heat above half the equipped radiator's `cooling_performance`
  accumulates; at or below it, stored heat drains back down. If heat
  reaches the radiator's full cooling value, the build is overheating —
  the boost gauge's generator supply stops entirely (draw still applies)
  until it cools back off, mirroring the source material's own
  documented heat rule (`(generator heat + booster heat) * 2 <=
  cooling`, generalized here to also include OB's heat).

All logic lives in `scripts/player.gd`; tunable constants (accel, top
speeds, gauge supply/draw, timing windows) are at the top of the file.

## Parts system

A first pass at frame parts. The player now references a `CorePart`,
`LegsPart`, `BoosterPart` and `RadiatorPart` directly (set on the `Player`
node in `scenes/Main.tscn`, defaulting to RAKAN/CR-LH69S/CR-B69/CR-R92) to
drive Overed Boost, its heat, and ground braking — but the parts don't
affect ordinary walking/boost-dash/air-boost speed yet, that's still the
hardcoded constants above.

- `scripts/parts/*.gd`: one `Resource` subclass per part category --
  `HeadPart`, `CorePart`, `ArmsPart`, `LegsPart` (with a `LegType` enum:
  biped/reverse-joint/quad/tank), `FcsPart`, `BoosterPart`,
  `GeneratorPart`, `RadiatorPart`. Fields match the stat columns from the
  source reference (Armored Core Last Raven's part data); where the
  source lists a paired NX/LR value, the first figure is used.
- `resources/parts/<category>/*.tres`: a handful of real parts per
  category (3-4 each, one of every leg type) transcribed from that
  reference, enough to exercise the system without transcribing the
  entire multi-hundred-part list up front.
- `scripts/ac_build.gd` (`ACBuild`): one of each part assembled into a
  machine, plus the derived totals: `total_ap()`, `carried_weight()` /
  `load_ratio()` (everything except the legs, checked against the legs'
  load capacity), `total_en_consumption()` / `en_balance()` (against the
  generator's output), and `total_heat()` / `is_overheating()` (generator
  heat + booster heat, doubled, checked against the radiator's cooling --
  the source material's own documented rule of thumb). `validate()`
  returns a list of problems (missing part, overweight, EN deficit,
  overheating), or an empty array if the build is viable.
- `resources/builds/*.tres`: two example `ACBuild`s. `starter_loadout`
  (the cheapest part in each category) deliberately fails `validate()`
  with an overheat warning; `balanced_cruiser` swaps in a
  higher-cooling radiator and passes clean, showing the same check
  catching a real problem and then confirming the fix.
- `scenes/PartsDebug.tscn`: open and run it (F6) to print both builds'
  computed stats to the console and an on-screen label.

This is scoped to movement/inertia/boost/OB + the parts data model for
now — no weapons, enemies, stages, or an equip UI yet, and most parts
(head/arms/FCS/generator, and non-OB stats on the rest) still don't
affect player movement in-game.
