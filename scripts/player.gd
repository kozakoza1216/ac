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
##   B              : Overed Boost (OB) -- only with an OB-type core
##     equipped. Press once to start a 1s charge (a charge effect shows
##     on the HUD during that window; you can still move normally, but
##     boosting while charging generates heat as though OB and boost
##     were already running together). Once charged, OB is active: it
##     multiplies whatever movement you're doing, requires you to keep
##     giving movement input the whole time (it stops the moment you
##     don't), and drains its own EN and generates its own heat,
##     tracked separately from the normal boost dash/air-boost cost.
##     Press B again (or stop moving) to end it -- on the ground this
##     brakes to a stop (no input accepted until the brake finishes,
##     faster with better leg brake performance) rather than snapping
##     to zero; in the air it just ends.

enum State { NORMAL, BOOST_DASH, AIR_BOOST }
enum ObState { INACTIVE, CHARGING, ACTIVE, BRAKING }

const GRAVITY := 32.0

const WALK_ACCEL := 26.0
const WALK_MAX_SPEED := 10.0
const AIR_DAMPING := 6.0

# Non-boosted air control (falling, or airborne with boost not held) tops
# out at the same speed as walking -- no gauge needed either way.
const AIR_CONTROL_ACCEL := 40.0
const AIR_CONTROL_MAX_SPEED := WALK_MAX_SPEED

const BOOST_ACCEL := 75.0
const BOOST_MAX_SPEED := 24.0
const BOOST_DAMPING_AFTER_RELEASE := 30.0

const JUMP_VELOCITY := 9.0

const AIR_BOOST_VERTICAL_ACCEL := 40.0
const AIR_BOOST_VERTICAL_MAX_SPEED := 16.0

const BOOST_GAUGE_MAX := 100.0

# Generator model: the gauge is a buffer between a constant generator
# supply and whatever the boosters (and OB, see below) are actively
# drawing. Supply is always being added; when total draw is higher than
# the supply, the gauge nets down, and the moment draw drops (partially
# or to zero) it nets back up again -- no separate "regen delay" state
# needed. Overheating (see below) suspends the supply term entirely.
const BOOST_SUPPLY := 24.0
const BOOST_DASH_DRAIN := 52.0
const AIR_BOOST_DRAIN := 60.0

const REBOOST_WINDOW := 0.35

# Hard landings are judged by actual impact speed -- the vertical velocity
# at the instant you touch down -- not how long you were falling. That way
# a slow, boost-cushioned descent never staggers even after a long fall,
# while dropping in fast (whether boosting or not) always does.
const HARD_LANDING_IMPACT_SPEED := 14.0
const HARD_LANDING_STAGGER_DURATION := 0.5

const TURN_SPEED := 2.6
const PITCH_SPEED := 1.8
const PITCH_MIN := -1.05 # ~ -60 deg
const PITCH_MAX := 0.87 # ~ 50 deg

# Overed Boost: charge time is fixed regardless of parts; the speed/accel
# multipliers stack on top of whatever movement mode is currently active
# (walk/air-control/boost-dash/air-boost) rather than replacing it.
const OB_CHARGE_TIME := 1.0
const OB_SPEED_MULTIPLIER := 2.5
const OB_ACCEL_MULTIPLIER := 1.8

# Temperature: heat generation in excess of what the radiator can shed
# (see is_overheating below) converts to a °C/s rise via this divisor;
# below that threshold it drains back toward 0 at the same rate. Hitting
# MELTDOWN_TEMPERATURE forces an emergency shutdown.
const TEMP_SCALE := 18.0
const MELTDOWN_TEMPERATURE := 1000.0
const MELTDOWN_LOCKOUT_DURATION := 1.5
const MELTDOWN_TEMPERATURE_RESET := 700.0

@export var core_part: CorePart
@export var legs_part: LegsPart
@export var booster_part: BoosterPart
@export var radiator_part: RadiatorPart

@onready var camera_pivot: Node3D = $CameraPivot
@onready var boost_bar: ProgressBar = get_node_or_null("%BoostBar")
@onready var heat_bar: ProgressBar = get_node_or_null("%HeatBar")
@onready var heat_label: Label = get_node_or_null("%HeatLabel")
@onready var ob_charge_bar: ProgressBar = get_node_or_null("%ObChargeBar")
@onready var state_label: Label = get_node_or_null("%StateLabel")

var state: int = State.NORMAL
var ob_state: int = ObState.INACTIVE
var boost_gauge: float = BOOST_GAUGE_MAX
var temperature: float = 0.0
var is_overheating: bool = false

var awaiting_reboost: bool = false
var reboost_deadline: float = -1.0

# True right after leaving a boost dash on the ground, while its leftover
# momentum is still easing out; distinguishes that from an ordinary walk
# stop (which halts instantly).
var _coasting_from_dash: bool = false

var cam_pitch: float = 0.0
var ob_charge_timer: float = 0.0

var _t: float = 0.0
var _boost_prev_held: bool = false
var _ob_prev_held: bool = false
var _stagger_timer: float = 0.0
var _meltdown_timer: float = 0.0


func _physics_process(delta: float) -> void:
	_t += delta

	if _meltdown_timer > 0.0:
		# Thermal runaway: emergency shutdown, takes priority over
		# everything else -- no input, EN already dumped, just settle.
		_meltdown_timer = maxf(0.0, _meltdown_timer - delta)
		state = State.NORMAL
		ob_state = ObState.INACTIVE
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_boost_prev_held = Input.is_key_pressed(KEY_SPACE)
		_ob_prev_held = Input.is_key_pressed(KEY_B)
		_update_hud()
		return

	if _stagger_timer > 0.0:
		# Hard-landing stagger: no input of any kind, just let gravity
		# keep settling the body until it wears off. OB is cancelled
		# outright rather than left charging/active through a stagger.
		_stagger_timer = maxf(0.0, _stagger_timer - delta)
		state = State.NORMAL
		ob_state = ObState.INACTIVE
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_boost_prev_held = Input.is_key_pressed(KEY_SPACE)
		_ob_prev_held = Input.is_key_pressed(KEY_B)
		_update_hud()
		return

	if ob_state == ObState.BRAKING:
		# Grounded-only: no input accepted until the brake finishes.
		var brake_rate: float = legs_part.brake_performance if legs_part else 20.0
		var braking_h := Vector3(velocity.x, 0.0, velocity.z)
		braking_h = braking_h.move_toward(Vector3.ZERO, brake_rate * delta)
		velocity.x = braking_h.x
		velocity.z = braking_h.z
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		elif velocity.y < 0.0:
			velocity.y = -1.0
		move_and_slide()
		if braking_h.length() < 0.05:
			ob_state = ObState.INACTIVE
		state = State.NORMAL
		_boost_prev_held = Input.is_key_pressed(KEY_SPACE)
		_ob_prev_held = Input.is_key_pressed(KEY_B)
		_update_hud()
		return

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

	# --- Overed Boost: trigger, charge, and the "must keep moving" rule ---
	var ob_pressed := Input.is_key_pressed(KEY_B)
	var ob_just_pressed := ob_pressed and not _ob_prev_held
	var ob_available := core_part != null and core_part.is_ob_type

	if ob_just_pressed:
		match ob_state:
			ObState.INACTIVE:
				if ob_available:
					ob_state = ObState.CHARGING
					ob_charge_timer = 0.0
			ObState.CHARGING:
				ob_state = ObState.INACTIVE
			ObState.ACTIVE:
				ob_state = ObState.BRAKING if was_on_floor else ObState.INACTIVE
			ObState.BRAKING:
				pass

	if ob_state == ObState.CHARGING:
		ob_charge_timer += delta
		if ob_charge_timer >= OB_CHARGE_TIME:
			ob_state = ObState.ACTIVE
	elif ob_state == ObState.ACTIVE and (not has_move_input or boost_gauge <= 0.0):
		# OB demands continuous movement and running out of EN ends it
		# the same way pressing the button again would.
		ob_state = ObState.BRAKING if was_on_floor else ObState.INACTIVE

	var ob_active := ob_state == ObState.ACTIVE
	var ob_speed_mult := OB_SPEED_MULTIPLIER if ob_active else 1.0
	var ob_accel_mult := OB_ACCEL_MULTIPLIER if ob_active else 1.0

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
			if state == State.BOOST_DASH:
				if boost_just_released:
					awaiting_reboost = true
					reboost_deadline = _t + REBOOST_WINDOW
				_coasting_from_dash = true
			state = State.NORMAL
	else:
		if boost_held and boost_gauge > 0.0:
			state = State.AIR_BOOST
		else:
			state = State.NORMAL

	var boost_draw := 0.0

	match state:
		State.NORMAL:
			if was_on_floor:
				if has_move_input:
					h_velocity = h_velocity.move_toward(move_dir * WALK_MAX_SPEED * ob_speed_mult, WALK_ACCEL * ob_accel_mult * delta)
					_coasting_from_dash = false
				elif _coasting_from_dash:
					# Still bleeding off momentum from a boost dash that
					# just ended on the ground -- an ordinary walking stop
					# (below) is instant, but boost momentum eases out.
					h_velocity = h_velocity.move_toward(Vector3.ZERO, BOOST_DAMPING_AFTER_RELEASE * delta)
					if h_velocity.length() < 0.05:
						_coasting_from_dash = false
				else:
					h_velocity = Vector3.ZERO
			else:
				if has_move_input:
					h_velocity = h_velocity.move_toward(move_dir * AIR_CONTROL_MAX_SPEED * ob_speed_mult, AIR_CONTROL_ACCEL * ob_accel_mult * delta)
				else:
					h_velocity = h_velocity.move_toward(Vector3.ZERO, AIR_DAMPING * delta)

		State.BOOST_DASH:
			h_velocity = h_velocity.move_toward(move_dir * BOOST_MAX_SPEED * ob_speed_mult, BOOST_ACCEL * ob_accel_mult * delta)
			boost_draw = BOOST_DASH_DRAIN

		State.AIR_BOOST:
			# Boost dash and boost jump combined: always thrust upward,
			# and also thrust toward the movement input if there is any.
			velocity.y = minf(velocity.y + AIR_BOOST_VERTICAL_ACCEL * delta, AIR_BOOST_VERTICAL_MAX_SPEED)
			var h_target := move_dir * BOOST_MAX_SPEED * ob_speed_mult if has_move_input else Vector3.ZERO
			h_velocity = h_velocity.move_toward(h_target, BOOST_ACCEL * ob_accel_mult * delta)
			boost_draw = AIR_BOOST_DRAIN

	# --- Overed Boost EN draw and heat, tracked apart from the booster's ---
	var boost_heat_rate := 0.0
	if (state == State.BOOST_DASH or state == State.AIR_BOOST) and booster_part:
		boost_heat_rate = booster_part.boost_heat

	var ob_heat_rate := 0.0
	var ob_en_draw := 0.0
	if ob_available:
		if ob_state == ObState.ACTIVE:
			ob_heat_rate = core_part.ob_heat
			ob_en_draw = core_part.ob_en_drain
		elif ob_state == ObState.CHARGING and boost_heat_rate > 0.0:
			# Charging while boosting generates heat as though OB were
			# already fully active alongside the boost (no EN cost yet,
			# only heat -- OB's own EN only drains once truly active).
			ob_heat_rate = core_part.ob_heat

	# is_overheating is instantaneous -- generating more heat right now
	# than the radiator can shed -- per the source rule that exceeding
	# (generator heat + booster heat) * 2 <= cooling suspends EN
	# recovery. Whether or not that's currently true, temperature itself
	# is a separate accumulated total in degrees C: it climbs while
	# overheating and drains back toward 0 otherwise.
	var cooling := radiator_part.cooling_performance if radiator_part else 0.0
	var heat_threshold := cooling / 2.0
	var heat_generation := boost_heat_rate + ob_heat_rate
	is_overheating = heat_generation > heat_threshold
	if is_overheating:
		temperature += (heat_generation - heat_threshold) / TEMP_SCALE * delta
	else:
		temperature = maxf(0.0, temperature - (heat_threshold - heat_generation) / TEMP_SCALE * delta)

	# Generator supply vs. total draw (booster + OB, summed here but
	# computed above as separate named rates). Overheating suspends the
	# supply term entirely -- draw still applies, nothing regenerates.
	var total_draw := boost_draw + ob_en_draw
	if is_overheating:
		boost_gauge = clampf(boost_gauge - total_draw * delta, 0.0, BOOST_GAUGE_MAX)
	else:
		boost_gauge = clampf(boost_gauge + (BOOST_SUPPLY - total_draw) * delta, 0.0, BOOST_GAUGE_MAX)

	if temperature >= MELTDOWN_TEMPERATURE:
		# Thermal runaway: emergency shutdown starting next frame (see
		# the _meltdown_timer check at the top of this function).
		_meltdown_timer = MELTDOWN_LOCKOUT_DURATION
		temperature = MELTDOWN_TEMPERATURE_RESET
		boost_gauge = 0.0
		ob_state = ObState.INACTIVE
		h_velocity = Vector3.ZERO

	velocity.x = h_velocity.x
	velocity.z = h_velocity.z

	if not was_on_floor:
		velocity.y -= GRAVITY * delta
	elif velocity.y < 0.0:
		velocity.y = -1.0

	# Sampled just before the move that might land us, so it reflects the
	# actual impact speed rather than whatever move_and_slide leaves behind.
	var impact_velocity_y := velocity.y

	move_and_slide()

	if is_on_floor() and not was_on_floor:
		if state == State.NORMAL:
			# Not boosting: momentum is arrested the instant the legs touch
			# down, instead of bleeding off gradually. If you're already
			# holding a direction at that instant, skip the inertia
			# ramp-up entirely and snap straight to walking speed.
			if has_move_input:
				velocity.x = move_dir.x * WALK_MAX_SPEED
				velocity.z = move_dir.z * WALK_MAX_SPEED
			else:
				velocity.x = 0.0
				velocity.z = 0.0

		# Coming in fast enough staggers the landing regardless of whether
		# boost happened to be active at touchdown; a slow, cushioned
		# descent (even after a long fall) never does.
		if impact_velocity_y <= -HARD_LANDING_IMPACT_SPEED:
			_stagger_timer = HARD_LANDING_STAGGER_DURATION
			velocity.x = 0.0
			velocity.z = 0.0

	_boost_prev_held = boost_held
	_ob_prev_held = ob_pressed
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
	if heat_bar:
		heat_bar.max_value = MELTDOWN_TEMPERATURE
		heat_bar.value = temperature
	if heat_label:
		heat_label.text = "TEMP: %d°C" % int(temperature)
	if ob_charge_bar:
		ob_charge_bar.visible = ob_state == ObState.CHARGING
		if ob_charge_bar.visible:
			ob_charge_bar.value = clampf(ob_charge_timer / OB_CHARGE_TIME, 0.0, 1.0) * 100.0
	if state_label:
		if _meltdown_timer > 0.0:
			state_label.text = "MELTDOWN (%d°C)" % int(temperature)
			return
		if _stagger_timer > 0.0:
			state_label.text = "LANDING STAGGER"
			return
		var text := ""
		match state:
			State.NORMAL:
				text = "-"
			State.BOOST_DASH:
				text = "BOOST DASH"
			State.AIR_BOOST:
				text = "AIR BOOST"
		match ob_state:
			ObState.CHARGING:
				text += " | OB CHARGING"
			ObState.ACTIVE:
				text += " | OB ACTIVE"
			ObState.BRAKING:
				text += " | OB BRAKING"
		if is_overheating:
			text += " | OVERHEAT"
		state_label.text = text
