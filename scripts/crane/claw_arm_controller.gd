class_name ClawArmController
extends Node3D

## Lower segment curls on +X. Contact stops the hinge; flex + motion shove prizes (arcade push).

@export var segment_b: Node3D
@export var open_angle_b_deg: float = 16.0
@export var close_angle_b_deg: float = 108.0
@export var rotation_speed_deg: float = 120.0
@export var flex_pivot: Node3D
@export var close_probe: RayCast3D
@export var mid_probe: RayCast3D

const FLEX_MAX_DEG := 38.0
const FLEX_SPEED_DEG := 240.0
const PUSH_IMPULSE_SCALE := 1.35
const MAX_PUSH_IMPULSE := 2.8

var _claw_body: RigidBody3D
var _tip_node: Node3D
var _angle_b_deg: float = 16.0
var _flex_deg: float = 0.0
var _target_close: bool = false
var _close_blend: float = 1.0
var _blocked: bool = false
var _pending_flex_delta_deg: float = 0.0
var _pending_close_attempt_deg: float = 0.0


func _ready() -> void:
	process_physics_priority = -20
	open_immediate()


func configure(
	probes: Array[RayCast3D],
	flex: Node3D,
	claw_body: RigidBody3D,
	tip_node: Node3D,
) -> void:
	flex_pivot = flex
	_claw_body = claw_body
	_tip_node = tip_node
	if probes.size() > 0:
		close_probe = probes[0]
	if probes.size() > 1:
		mid_probe = probes[1]
	for ray in probes:
		if ray:
			ray.collision_mask = PhysicsLayers.PRIZES
			ray.hit_from_inside = true
			ray.enabled = true


func open_immediate() -> void:
	_target_close = false
	_close_blend = 1.0
	_blocked = false
	_angle_b_deg = open_angle_b_deg
	_flex_deg = 0.0
	_pending_flex_delta_deg = 0.0
	_pending_close_attempt_deg = 0.0
	_apply_pose()


func set_closed(closed: bool, close_blend: float = 1.0) -> void:
	_target_close = closed
	_close_blend = clampf(close_blend, 0.0, 1.0)
	if not closed:
		_blocked = false


func _target_angle_b() -> float:
	if _target_close:
		return lerpf(open_angle_b_deg, close_angle_b_deg, _close_blend)
	return open_angle_b_deg


func _physics_process(delta: float) -> void:
	var prev_flex := _flex_deg
	var prev_angle := _angle_b_deg
	var target := _target_angle_b()
	var step := minf(rotation_speed_deg * delta, 45.0 * delta)
	var next_angle := move_toward(_angle_b_deg, target, step)
	_pending_close_attempt_deg = 0.0

	if _target_close and next_angle > _angle_b_deg + 0.01:
		if _probe_hits_prize():
			_blocked = true
			_pending_close_attempt_deg = next_angle - _angle_b_deg
			next_angle = _angle_b_deg
			_flex_deg = move_toward(_flex_deg, FLEX_MAX_DEG * _close_blend, FLEX_SPEED_DEG * delta)
		else:
			_blocked = false
			if not _probe_hits_prize_at_angle(next_angle):
				_flex_deg = move_toward(_flex_deg, 0.0, FLEX_SPEED_DEG * delta * 1.5)
			else:
				_blocked = true
				_pending_close_attempt_deg = next_angle - _angle_b_deg
				next_angle = _angle_b_deg
				_flex_deg = move_toward(_flex_deg, FLEX_MAX_DEG * _close_blend, FLEX_SPEED_DEG * delta)
	else:
		_blocked = false
		_flex_deg = move_toward(_flex_deg, 0.0, FLEX_SPEED_DEG * delta * 2.0)

	_angle_b_deg = next_angle
	_pending_flex_delta_deg = _flex_deg - prev_flex
	if _blocked and _pending_close_attempt_deg <= 0.0:
		_pending_close_attempt_deg = maxf(target - prev_angle, 0.0)
	_apply_pose()


## Called from ClawRig after finger colliders are synced — pushes prizes from hook motion.
func apply_prize_pushes(delta: float) -> void:
	if not _target_close or delta <= 0.0:
		return
	var tip_vel := Vector3.ZERO
	if absf(_pending_flex_delta_deg) > 0.05:
		tip_vel += _tip_velocity_from_rotation(
			flex_pivot,
			_pending_flex_delta_deg,
			delta,
		)
	if _pending_close_attempt_deg > 0.05:
		tip_vel += _tip_velocity_from_rotation(
			segment_b,
			_pending_close_attempt_deg,
			delta,
		)
	if tip_vel.length_squared() < 0.0004:
		return
	_push_from_ray(close_probe, tip_vel, 1.0)
	_push_from_ray(mid_probe, tip_vel, 0.55)


func _tip_velocity_from_rotation(pivot: Node3D, delta_deg: float, delta: float) -> Vector3:
	if pivot == null or _tip_node == null:
		return Vector3.ZERO
	var omega_axis := pivot.global_transform.basis.x
	var lever := _tip_node.global_position - pivot.global_position
	var omega := omega_axis * deg_to_rad(delta_deg / delta)
	return omega.cross(lever)


func _push_from_ray(ray: RayCast3D, tip_velocity: Vector3, weight: float) -> void:
	if ray == null or not ray.enabled:
		return
	ray.force_raycast_update()
	if not ray.is_colliding():
		return
	var prize := _prize_body_from(ray.get_collider())
	if prize == null:
		return
	var hit := ray.get_collision_point()
	var push_dir := tip_velocity
	if push_dir.length_squared() < 0.0001:
		push_dir = -ray.get_collision_normal()
	else:
		push_dir = push_dir.normalized()
	var impulse_mag := minf(
		tip_velocity.length() * prize.mass * PUSH_IMPULSE_SCALE * weight * _close_blend,
		MAX_PUSH_IMPULSE * weight,
	)
	if impulse_mag < 0.02:
		return
	var impulse := push_dir * impulse_mag
	var offset := hit - prize.global_position
	prize.apply_impulse(impulse, offset)
	prize.sleeping = false
	if _claw_body:
		_claw_body.sleeping = false
		_claw_body.apply_central_impulse(-impulse * 0.12)


func _probe_hits_prize() -> bool:
	return _ray_hits_prize(close_probe) or _ray_hits_prize(mid_probe)


func _probe_hits_prize_at_angle(angle_deg: float) -> bool:
	if segment_b == null:
		return false
	var saved := _angle_b_deg
	var saved_flex := _flex_deg
	_angle_b_deg = angle_deg
	_apply_pose()
	var hit := _probe_hits_prize()
	_angle_b_deg = saved
	_flex_deg = saved_flex
	_apply_pose()
	return hit


func _ray_hits_prize(ray: RayCast3D) -> bool:
	if ray == null or not ray.enabled:
		return false
	ray.force_raycast_update()
	if not ray.is_colliding():
		return false
	return _prize_body_from(ray.get_collider()) != null


func _prize_body_from(collider: Object) -> RigidBody3D:
	if collider == null:
		return null
	if collider is RigidBody3D and collider.has_meta("prize_id"):
		return collider
	var node := collider as Node
	if node == null:
		return null
	var body := node.get_parent()
	if body is RigidBody3D and body.has_meta("prize_id"):
		return body
	return null


func is_blocked() -> bool:
	return _blocked or _flex_deg > 4.0


func _apply_pose() -> void:
	if segment_b:
		segment_b.rotation_degrees.x = _angle_b_deg
	if flex_pivot:
		flex_pivot.rotation_degrees.x = _flex_deg
