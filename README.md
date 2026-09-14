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

- **Boost dash**: hold Space while moving. Can be held indefinitely (drains
  the boost gauge while active).
- **Boost jump**: while boost-dashing, release Space, then press it again
  within a short window. Also holdable — keeps accelerating upward for as
  long as it's held, draining the gauge.
- **Jump**: pressing Space while standing still jumps instantly — it doesn't
  wait to see how long you hold it. That initial hop costs no gauge. Keep
  Space held past the jump and it turns into a boost jump (drains gauge,
  holdable, same as above).
- **Inertia**: horizontal velocity is only ever eased toward a target speed
  (`Vector3.move_toward`), never set directly, and while airborne or right
  after a dash it bleeds off slowly — momentum carries through jumps and
  keeps sliding once you let off the boost. The one exception: touching
  the ground while *not* boosting instantly zeroes horizontal velocity
  (legs arrest the momentum), whereas landing mid boost-dash keeps sliding.

All logic lives in `scripts/player.gd`; tunable constants (accel, top
speeds, gauge drain/regen, timing windows) are at the top of the file.

This is scoped to movement/inertia/boost only for now — no weapons, enemies,
or stages yet.
