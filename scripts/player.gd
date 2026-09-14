extends CharacterBody3D

## Armored Core-like locomotion prototype.
##
## Controls (keyboard only, no mouse):
##   W / A / S / D : move (forward / strafe left / back / strafe right)
##   Left / Right   : turn body (yaw)
##   Up / Down      : look camera up / down (pitch)
##   Space          : the single "boost" button, overloaded as follows:
##     - hold while moving on the ground -> boost dash (drains gauge)
##     - press while standing still      -> jump fires instantly (free,
##       no gauge cost); keep holding boost (or press it again once
##       airborne) to keep boosting
##     - whenever airborne, holding boost applies both vertical thrust
##       and horizontal thrust toward your movement input at the same
##       time -- boost dash and boost jump combined into one air boost
##     - release boost mid ground-dash, then press it again within a
##       short window, to launch off the ground into an air boost

enum State { NORMAL, BOOST_DASH, AIR_BOOST }

const GRAVITY := 20.0

const WALK_ACCEL := 18.0
const WALK_MAX_SPEED := 7.0
const AIR_DAMPING := 1.5

const BOOST_ACCEL := 40.0
const BOOST_MAX_SPEED := 22.0
const BOOST_DAMPING_AFTER_RELEASE := 2.0

const JUMP_VELOCITY := 8.5

const AIR_BOOST_VERTICAL_ACCEL := 26.0
const AIR_BOOST_VERTICAL_MAX_SPEED := 15.0

const BOOST_GAUGE_MAX := 100.0
const BOOST_DASH_DRAIN := 28.0
const AIR_BOOST_DRAIN := 36.0
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

	var was_on_floor := is_on_floor()
	var h_velocity := Vector3(velocity.x, 0.0, velocity.z)

	# Free jump: a press while standing still on the ground always fires
	# immediately, no gauge cost. Whatever happens with boost afterward
	# (held through, or released and pressed again once airborne) is
	# handled uniformly by the airborne air-boost rule below.
	if was_on_floor and not has_move_input and boost_just_pressed:
		velocity.y = JUMP_VELOCITY

	# Re-boost window: release boost mid ground-dash, then press it again
	# quickly to launch off the ground into an air boost.
	if awaiting_reboost:
		if boost_just_pressed:
			awaiting_reboost = false
			if _t <= reboost_deadline and boost_gauge > 0.0 and was_on_floor:
				velocity.y = JUMP_VELOCITY
		elif _t > reboost_deadline:
			awaiting_reboost = false

	# Resolve this frame's state fresh from grounded-ness, input and the
	# boost button -- boosting works the same regardless of how you ended
	# up airborne (jumped, dashed off a ledge, fell, pressed boost again
	# after already letting go of it once).
	if was_on_floor:
		if has_move_input and boost_held and boost_gauge > 0.0:
			state = State.BOOST_DASH
		else:
			if state == State.BOOST_DASH and boost_just_released:
				awaiting_reboost = true
				reboost_deadline = _t + REBOOST_WINDOW
			state = State.NORMAL
	else:
		if boost_held and boost_gauge > 0.0:
			state = State.AIR_BOOST
		else:
			state = State.NORMAL

	match state:
		State.NORMAL:
			if was_on_floor:
				if has_move_input:
					h_velocity = h_velocity.move_toward(move_dir * WALK_MAX_SPEED, WALK_ACCEL * delta)
				elif boost_regen_timer > 0.0:
					# Still bleeding off momentum from a boost dash that
					# just ended on the ground -- an ordinary walking stop
					# (below) is instant, but boost momentum eases out.
					h_velocity = h_velocity.move_toward(Vector3.ZERO, BOOST_DAMPING_AFTER_RELEASE * delta)
				else:
					h_velocity = Vector3.ZERO
			else:
				if has_move_input:
					h_velocity = h_velocity.move_toward(move_dir * WALK_MAX_SPEED, WALK_ACCEL * 0.5 * delta)
				else:
					h_velocity = h_velocity.move_toward(Vector3.ZERO, AIR_DAMPING * delta)

		State.BOOST_DASH:
			h_velocity = h_velocity.move_toward(move_dir * BOOST_MAX_SPEED, BOOST_ACCEL * delta)
			boost_gauge = maxf(0.0, boost_gauge - BOOST_DASH_DRAIN * delta)
			boost_regen_timer = BOOST_REGEN_DELAY

		State.AIR_BOOST:
			# Boost dash and boost jump combined: always thrust upward,
			# and also thrust toward the movement input if there is any.
			velocity.y = minf(velocity.y + AIR_BOOST_VERTICAL_ACCEL * delta, AIR_BOOST_VERTICAL_MAX_SPEED)
			var h_target := move_dir * BOOST_MAX_SPEED if has_move_input else Vector3.ZERO
			h_velocity = h_velocity.move_toward(h_target, BOOST_ACCEL * delta)
			boost_gauge = maxf(0.0, boost_gauge - AIR_BOOST_DRAIN * delta)
			boost_regen_timer = BOOST_REGEN_DELAY

	velocity.x = h_velocity.x
	velocity.z = h_velocity.z

	if not was_on_floor:
		velocity.y -= GRAVITY * delta
	elif velocity.y < 0.0:
		velocity.y = -1.0

	move_and_slide()

	if is_on_floor() and not was_on_floor and state == State.NORMAL:
		# Not boosting: momentum is arrested the instant the legs touch
		# down, instead of bleeding off gradually.
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
			State.AIR_BOOST:
				state_label.text = "AIR BOOST"
