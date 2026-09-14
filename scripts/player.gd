extends CharacterBody3D

## Armored Core-like locomotion prototype.
##
## Controls (keyboard only, no mouse):
##   W / A / S / D : move (forward / strafe left / back / strafe right)
##   Left / Right   : turn body (yaw)
##   Up / Down      : look camera up / down (pitch)
##   Space          : the single "boost" button, overloaded as follows:
##     - hold while moving      -> boost dash (drains gauge while held)
##     - release during a dash, -> boost jump (also holdable; drains gauge)
##       then press again within
##       a short window
##     - press while standing still -> jump fires instantly (no gauge cost);
##       keep holding and it turns into a boost jump (drains gauge)

enum State { NORMAL, BOOST_DASH, BOOST_JUMP }

const GRAVITY := 20.0

const WALK_ACCEL := 18.0
const WALK_MAX_SPEED := 7.0
const WALK_DAMPING := 10.0
const AIR_DAMPING := 1.5

const BOOST_ACCEL := 40.0
const BOOST_MAX_SPEED := 22.0
const BOOST_DAMPING_AFTER_RELEASE := 2.0

const JUMP_VELOCITY := 8.5

const BOOST_JUMP_ACCEL := 26.0
const BOOST_JUMP_MAX_SPEED := 15.0

const BOOST_GAUGE_MAX := 100.0
const BOOST_DASH_DRAIN := 28.0
const BOOST_JUMP_DRAIN := 36.0
const BOOST_REGEN := 22.0
const BOOST_REGEN_DELAY := 0.4

const REBOOST_WINDOW := 0.35

const TURN_SPEED := 2.6
const PITCH_SPEED := 1.8
const PITCH_MIN := -1.05 # ~ -60 deg
const PITCH_MAX := 0.87 # ~ 50 deg

@onready var camera_pivot: Node3D = $CameraPivot
@onready var boost_bar: ProgressBar = get_node_or_null("%BoostBar")
@onready var state_label: Label = get_node_or_null("%StateLabel")

var state: int = State.NORMAL
var boost_gauge: float = BOOST_GAUGE_MAX
var boost_regen_timer: float = 0.0

var awaiting_reboost: bool = false
var reboost_deadline: float = -1.0

var cam_pitch: float = 0.0

var _t: float = 0.0
var _boost_prev_held: bool = false


func _physics_process(delta: float) -> void:
	_t += delta
	_update_look(delta)

	var move_input := _get_move_input()
	var has_move_input := move_input.length() > 0.01
	var move_dir := Vector3.ZERO
	if has_move_input:
		move_dir = (global_transform.basis * move_input).normalized()

	var boost_held := Input.is_key_pressed(KEY_SPACE)
	var boost_just_pressed := boost_held and not _boost_prev_held
	var boost_just_released := (not boost_held) and _boost_prev_held

	# Re-boost window: pressing boost again shortly after releasing it during
	# a dash triggers a boost jump instead of re-entering the dash. This is
	# checked before the state machine below so it takes priority over a
	# fresh dash starting on the same frame.
	if awaiting_reboost:
		if boost_just_pressed:
			awaiting_reboost = false
			if _t <= reboost_deadline and boost_gauge > 0.0:
				state = State.BOOST_JUMP
		elif _t > reboost_deadline:
			awaiting_reboost = false

	var was_on_floor := is_on_floor()
	var h_velocity := Vector3(velocity.x, 0.0, velocity.z)

	match state:
		State.NORMAL:
			if has_move_input:
				h_velocity = h_velocity.move_toward(move_dir * WALK_MAX_SPEED, WALK_ACCEL * delta)
			else:
				h_velocity = h_velocity.move_toward(Vector3.ZERO, WALK_DAMPING * delta)

			if boost_held and has_move_input and boost_gauge > 0.0:
				state = State.BOOST_DASH
			elif boost_just_pressed and not has_move_input and was_on_floor:
				# Jump fires the instant the button is pressed, no waiting to
				# see how long it's held. If boost is still held on later
				# frames, the BOOST_JUMP branch below keeps it going as a
				# boost jump; a quick tap just leaves this one free impulse.
				velocity.y = JUMP_VELOCITY
				state = State.BOOST_JUMP

		State.BOOST_DASH:
			if boost_held and has_move_input and boost_gauge > 0.0:
				h_velocity = h_velocity.move_toward(move_dir * BOOST_MAX_SPEED, BOOST_ACCEL * delta)
				boost_gauge = maxf(0.0, boost_gauge - BOOST_DASH_DRAIN * delta)
				boost_regen_timer = BOOST_REGEN_DELAY
			else:
				if boost_just_released:
					awaiting_reboost = true
					reboost_deadline = _t + REBOOST_WINDOW
				# Boost released (or gauge ran out, or player stopped giving
				# direction): keep sliding on the momentum built up, only
				# bleeding off slowly, then hand back to normal movement.
				h_velocity = h_velocity.move_toward(Vector3.ZERO, BOOST_DAMPING_AFTER_RELEASE * delta)
				state = State.NORMAL

		State.BOOST_JUMP:
			if boost_held and boost_gauge > 0.0:
				velocity.y = minf(velocity.y + BOOST_JUMP_ACCEL * delta, BOOST_JUMP_MAX_SPEED)
				boost_gauge = maxf(0.0, boost_gauge - BOOST_JUMP_DRAIN * delta)
				boost_regen_timer = BOOST_REGEN_DELAY
			else:
				state = State.NORMAL

			if has_move_input:
				h_velocity = h_velocity.move_toward(move_dir * WALK_MAX_SPEED, WALK_ACCEL * 0.5 * delta)
			else:
				h_velocity = h_velocity.move_toward(Vector3.ZERO, AIR_DAMPING * delta)

	velocity.x = h_velocity.x
	velocity.z = h_velocity.z

	if not was_on_floor:
		velocity.y -= GRAVITY * delta
	elif velocity.y < 0.0:
		velocity.y = -1.0

	move_and_slide()

	if is_on_floor() and not was_on_floor and state == State.NORMAL:
		# Not boosting: momentum is arrested the instant the legs touch
		# down, instead of bleeding off gradually like WALK_DAMPING would.
		velocity.x = 0.0
		velocity.z = 0.0

	if boost_regen_timer > 0.0:
		boost_regen_timer = maxf(0.0, boost_regen_timer - delta)
	elif state == State.NORMAL:
		boost_gauge = minf(BOOST_GAUGE_MAX, boost_gauge + BOOST_REGEN * delta)

	_boost_prev_held = boost_held
	_update_hud()


func _get_move_input() -> Vector3:
	var input_vec := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		input_vec.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_vec.z += 1.0
	if Input.is_key_pressed(KEY_A):
		input_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_vec.x += 1.0
	if input_vec.length() > 0.0:
		return input_vec.normalized()
	return input_vec


func _update_look(delta: float) -> void:
	if Input.is_key_pressed(KEY_LEFT):
		rotate_y(TURN_SPEED * delta)
	if Input.is_key_pressed(KEY_RIGHT):
		rotate_y(-TURN_SPEED * delta)
	if Input.is_key_pressed(KEY_UP):
		cam_pitch = clampf(cam_pitch + PITCH_SPEED * delta, PITCH_MIN, PITCH_MAX)
	if Input.is_key_pressed(KEY_DOWN):
		cam_pitch = clampf(cam_pitch - PITCH_SPEED * delta, PITCH_MIN, PITCH_MAX)
	camera_pivot.rotation.x = cam_pitch


func _update_hud() -> void:
	if boost_bar:
		boost_bar.value = boost_gauge
	if state_label:
		match state:
			State.NORMAL:
				state_label.text = "-"
			State.BOOST_DASH:
				state_label.text = "BOOST DASH"
			State.BOOST_JUMP:
				state_label.text = "BOOST JUMP"
