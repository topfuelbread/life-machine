class_name CraneController
extends Node3D

## RailCart + cable joint + ClawAssembly with Unity-style 3× two-segment kinematic arms.

enum PlayState { IDLE, DROP, GRAB, ASCEND, TRANSIT_CHUTE, RELEASE, HOMING }

var current_state: PlayState = PlayState.IDLE

var _profile: ClawProfileDefinition
var _machine: CraneMachineDefinition
var _state_timer: float = 0.0
var _is_payout_win: bool = false
var _had_prize_at_grab: bool = false
var _weak_grip_applied: bool = false
var _current_cable_limit: float = 0.0
var _start_gantry: Vector3 = Vector3.ZERO
var _grip_close_blend: float = 1.0

var _claw_rig: ClawRig
var _landing_indicator: ClawLandingIndicator
var _prize_pin_joint: PinJoint3D
var _pinned_prize: RigidBody3D
var _pin_attempted: bool = false

@onready var rail_cart: Node3D = $RailCart
@onready var joint_anchor: RigidBody3D = $RailCart/JointAnchor
@onready var cable_joint: Generic6DOFJoint3D = $RailCart/HoistCableJoint
@onready var claw_hub: RigidBody3D = $ClawAssembly
@onready var palm_ray: RayCast3D = $ClawAssembly/PalmRaycast
@onready var rope_visual: CSGCylinder3D = $RailCart/RopeVisual
@onready var _grab_zone: Area3D = $ClawAssembly/GrabZone


func _ready() -> void:
	_build_claw_rig()
	_setup_landing_indicator()
	_setup_cable_joint()

	var machine := GameState.get_active_machine()
	if machine:
		configure(machine)
	else:
		_apply_profile(StarterContent.get_claw_profile(StarterContent.CLAW_STANDARD_ID))


func _build_claw_rig() -> void:
	for child in claw_hub.get_children():
		if child.name.begins_with("Claw_") or child.name == "ClawCenter":
			child.queue_free()

	var finger_mat := StandardMaterial3D.new()
	finger_mat.albedo_color = Color(0.82, 0.82, 0.85)
	finger_mat.roughness = 0.45

	_claw_rig = ClawRig.new()
	_claw_rig.build(claw_hub, finger_mat)
	_resize_grab_zone()


func _setup_landing_indicator() -> void:
	_landing_indicator = ClawLandingIndicator.new()
	_landing_indicator.name = "LandingIndicator"
	add_child(_landing_indicator)
	_landing_indicator.setup(claw_hub)


func _resize_grab_zone() -> void:
	var shape_node := _grab_zone.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null or shape_node.shape == null:
		return
	var sphere := shape_node.shape as SphereShape3D
	if sphere:
		sphere.radius = ClawRig.grab_zone_radius()
		shape_node.position = ClawRig.get_grasp_center_offset()
	if palm_ray:
		palm_ray.target_position = Vector3(0.0, -ClawRig.drop_ray_length(), 0.0)
		# Floor stop only — prizes are pierced during drop so the claw can reach pile depth.
		palm_ray.collision_mask = PhysicsLayers.CABINET


func configure(machine: CraneMachineDefinition) -> void:
	_machine = machine
	_apply_profile(StarterContent.get_claw_profile(machine.claw_profile_id))
	_start_gantry = Vector3(
		machine.start_gantry.x,
		machine.gantry_min.y,
		machine.start_gantry.z,
	)
	rail_cart.global_position = _start_gantry
	change_state(PlayState.IDLE)


func _apply_profile(profile: ClawProfileDefinition) -> void:
	_profile = profile if profile else StarterContent.get_claw_profile(StarterContent.CLAW_STANDARD_ID)
	_apply_grip_strength(_profile.grip_torque_weak)
	drive_prongs_open()
	change_state(PlayState.IDLE)


func _setup_cable_joint() -> void:
	_current_cable_limit = 0.0
	cable_joint.set("linear_limit_y/enabled", true)
	cable_joint.set("linear_limit_y/upper_distance", 0.0)
	cable_joint.set("linear_limit_y/lower_distance", 0.0)
	cable_joint.set("linear_limit_y/softness", 0.0)
	cable_joint.set("angular_limit_x/enabled", true)
	cable_joint.set("angular_limit_y/enabled", true)
	cable_joint.set("angular_limit_z/enabled", true)
	cable_joint.set("angular_limit_x/upper_angle", 0.08)
	cable_joint.set("angular_limit_x/lower_angle", -0.08)
	cable_joint.set("angular_limit_z/upper_angle", 0.08)
	cable_joint.set("angular_limit_z/lower_angle", -0.08)


func _physics_process(delta: float) -> void:
	_update_rope_visual()
	_state_timer += delta

	match current_state:
		PlayState.IDLE:
			_process_idle(delta)
		PlayState.DROP:
			_process_drop(delta)
		PlayState.GRAB:
			_process_grab(delta)
		PlayState.ASCEND:
			_process_ascend(delta)
		PlayState.TRANSIT_CHUTE:
			_process_transit(_machine.chute_position, _profile.transit_move_speed, delta)
		PlayState.RELEASE:
			drive_prongs_open()
			if _state_timer >= _profile.release_open_duration:
				change_state(PlayState.HOMING)
		PlayState.HOMING:
			_process_transit(_start_gantry, _profile.gantry_move_speed, delta)


func change_state(new_state: PlayState) -> void:
	current_state = new_state
	_state_timer = 0.0
	claw_hub.sleeping = false
	joint_anchor.sleeping = false

	match current_state:
		PlayState.IDLE:
			_weak_grip_applied = false
			_is_payout_win = false
			_had_prize_at_grab = false
			_release_pinned_prize()
			claw_hub.mass = 1.5
			_apply_grip_strength(_profile.grip_torque_weak)
			drive_prongs_open()
			_current_cable_limit = 0.0
			cable_joint.set("linear_limit_y/lower_distance", 0.0)
		PlayState.DROP:
			_release_pinned_prize()
			_is_payout_win = randf() <= _profile.payout_probability
			_had_prize_at_grab = false
			_weak_grip_applied = false
			_apply_grip_strength(_profile.grip_torque_weak)
			drive_prongs_open()
		PlayState.GRAB:
			_pin_attempted = false
			_apply_grip_strength(_profile.grip_torque_strong)
			drive_prongs_close()
			claw_hub.mass = 3.5
		PlayState.ASCEND:
			_pin_attempted = false
			_apply_grip_strength(_profile.grip_torque_strong)
			claw_hub.mass = 3.5
		PlayState.RELEASE:
			_release_pinned_prize()
			_apply_grip_strength(_profile.grip_torque_weak)
			drive_prongs_open()


func _apply_grip_strength(torque: float) -> void:
	var strong := _profile.grip_torque_strong if _profile else 18.0
	var weak := _profile.grip_torque_weak if _profile else 2.8
	_grip_close_blend = clampf(inverse_lerp(weak, strong, torque), 0.25, 1.0)
	if _claw_rig and current_state in [PlayState.GRAB, PlayState.ASCEND, PlayState.TRANSIT_CHUTE]:
		_claw_rig.set_all_closed(true, _grip_close_blend)


func _process_idle(delta: float) -> void:
	var move_vec := Vector3.ZERO
	if Input.is_action_pressed("ui_left"):
		move_vec.x -= 1.0
	if Input.is_action_pressed("ui_right"):
		move_vec.x += 1.0
	if Input.is_action_pressed("ui_up"):
		move_vec.z -= 1.0
	if Input.is_action_pressed("ui_down"):
		move_vec.z += 1.0

	if move_vec != Vector3.ZERO:
		rail_cart.global_position += move_vec.normalized() * _profile.gantry_move_speed * delta
		claw_hub.sleeping = false

	_clamp_rail_cart()

	if Input.is_action_just_pressed("ui_accept"):
		if not GameState.consume_play(GameState.get_active_pack()):
			return
		change_state(PlayState.DROP)


func _process_drop(delta: float) -> void:
	claw_hub.sleeping = false
	_current_cable_limit = move_toward(
		_current_cable_limit,
		_profile.max_drop_depth,
		_profile.hoist_drop_speed * delta,
	)
	cable_joint.set("linear_limit_y/lower_distance", _current_cable_limit)

	if _should_stop_drop():
		change_state(PlayState.GRAB)


func _should_stop_drop() -> bool:
	if _state_timer >= _profile.max_drop_seconds:
		return true
	if _current_cable_limit <= _profile.max_drop_depth + 0.02:
		return true
	if palm_ray.is_colliding():
		var collider: Object = palm_ray.get_collider()
		if collider and not _is_crane_node(collider as Node):
			return _is_cabinet_collider(collider)
	return false


func _is_cabinet_collider(collider: Object) -> bool:
	if collider is CollisionObject3D:
		return (collider.collision_layer & PhysicsLayers.CABINET) != 0
	return false


func _process_grab(_delta: float) -> void:
	drive_prongs_close()
	claw_hub.sleeping = false
	if _state_timer >= _profile.min_grab_overlap_seconds and _is_holding_prize():
		_had_prize_at_grab = true
	if _state_timer >= _profile.grab_close_duration:
		change_state(PlayState.ASCEND)


func _process_ascend(delta: float) -> void:
	claw_hub.sleeping = false
	if not _pin_attempted:
		_pin_attempted = true
		if _had_prize_at_grab or _is_holding_prize():
			_try_pin_nearest_prize()
	if not _weak_grip_applied and _profile.rigged_weak_grip and _state_timer >= _profile.weak_grip_delay:
		_weak_grip_applied = true
		if not (_is_payout_win and _profile.strong_grip_on_payout):
			_apply_grip_strength(_profile.grip_torque_weak)
			_release_pinned_prize()

	_current_cable_limit = move_toward(
		_current_cable_limit,
		0.0,
		_profile.hoist_ascend_speed * delta,
	)
	cable_joint.set("linear_limit_y/lower_distance", _current_cable_limit)

	var reeled_in := _current_cable_limit >= -0.05
	var timed_out := _state_timer >= _profile.max_ascend_seconds
	if not reeled_in and not timed_out:
		return

	_current_cable_limit = 0.0
	cable_joint.set("linear_limit_y/lower_distance", 0.0)

	if _should_visit_chute():
		change_state(PlayState.TRANSIT_CHUTE)
	else:
		change_state(PlayState.HOMING)


func _should_visit_chute() -> bool:
	if _profile.always_deliver_to_chute:
		return true
	return _is_holding_prize() or _had_prize_at_grab


func _process_transit(target_xz: Vector3, speed: float, delta: float) -> void:
	var target := Vector3(target_xz.x, rail_cart.global_position.y, target_xz.z)
	if rail_cart.global_position.distance_to(target) > 0.04:
		var dir := rail_cart.global_position.direction_to(target)
		rail_cart.global_position += dir * speed * delta
		_clamp_rail_cart()
		return

	rail_cart.global_position = target
	if current_state == PlayState.TRANSIT_CHUTE:
		change_state(PlayState.RELEASE)
	elif current_state == PlayState.HOMING:
		change_state(PlayState.IDLE)


func _update_rope_visual() -> void:
	var delta_pos := claw_hub.global_position - joint_anchor.global_position
	var length := maxf(delta_pos.length(), 0.05)
	rope_visual.height = length
	rope_visual.global_position = joint_anchor.global_position + delta_pos * 0.5
	if length > 0.01:
		rope_visual.look_at(claw_hub.global_position, Vector3.UP)
		rope_visual.rotate_object_local(Vector3.RIGHT, PI / 2.0)


func _is_holding_prize() -> bool:
	if _grab_zone == null:
		return false
	for body in _grab_zone.get_overlapping_bodies():
		if body is RigidBody3D and body.has_meta("prize_id") and not _is_crane_node(body):
			return true
	return false


func _is_crane_node(node: Node) -> bool:
	if node == null:
		return false
	if node == claw_hub or node.name == "ClawAssembly" or node.name.begins_with("Claw_"):
		return true
	if node.name in ["ClawCenter", "SegmentA", "SegmentB"]:
		return true
	var parent := node.get_parent()
	return parent != null and _is_crane_node(parent)


func _clamp_rail_cart() -> void:
	if _machine == null:
		return
	rail_cart.global_position.x = clampf(
		rail_cart.global_position.x,
		_machine.gantry_min.x,
		_machine.gantry_max.x,
	)
	rail_cart.global_position.z = clampf(
		rail_cart.global_position.z,
		_machine.gantry_min.z,
		_machine.gantry_max.z,
	)
	rail_cart.global_position.y = _machine.gantry_min.y


func drive_prongs_close() -> void:
	if _claw_rig:
		_claw_rig.set_all_closed(true, _grip_close_blend)


func drive_prongs_open() -> void:
	if _claw_rig:
		_claw_rig.set_all_closed(false)


func get_profile_display_name() -> String:
	return _profile.display_name if _profile else ""


func _try_pin_nearest_prize() -> void:
	if _pinned_prize != null and is_instance_valid(_pinned_prize):
		return
	var best: RigidBody3D = null
	var best_dist := INF
	for body in _grab_zone.get_overlapping_bodies():
		if not body is RigidBody3D or _is_crane_node(body):
			continue
		if not body.has_meta("prize_id"):
			continue
		var dist := claw_hub.global_position.distance_squared_to(body.global_position)
		if dist < best_dist:
			best_dist = dist
			best = body
	if best == null:
		return
	_release_pinned_prize()
	var pin := PinJoint3D.new()
	pin.name = "PrizePinJoint"
	add_child(pin)
	pin.node_a = claw_hub.get_path()
	pin.node_b = pin.get_path_to(best)
	pin.global_position = best.global_position
	# Joint3D default: exclude_nodes_from_collision = true (claw + prize don't fight the pin).
	_prize_pin_joint = pin
	_pinned_prize = best
	best.sleeping = false
	best.apply_central_impulse(Vector3.ZERO)
	claw_hub.sleeping = false


func _release_pinned_prize() -> void:
	if _prize_pin_joint != null and is_instance_valid(_prize_pin_joint):
		_prize_pin_joint.queue_free()
	_prize_pin_joint = null
	_pinned_prize = null
