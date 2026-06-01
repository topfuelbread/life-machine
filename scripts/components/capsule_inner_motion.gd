class_name CapsuleInnerMotion
extends Node3D

## Sticker rattles freely inside the capsule shell, confined to an inner sphere.

@export var inertia_scale := 1.25
@export var spin_coupling := 0.55
@export var gravity_scale := 0.42
@export var damping := 3.5
@export var wall_bounce := 0.38
@export var inner_margin := 0.012

var _velocity := Vector3.ZERO
var _max_radius := 0.0
var _last_capsule_vel := Vector3.ZERO
var _last_capsule_pos := Vector3.ZERO
var _configured := false


func _ready() -> void:
	set_physics_process(true)


func configure(shell_radius: float, sticker_half_extent: float) -> void:
	_max_radius = maxf(shell_radius - sticker_half_extent - inner_margin, shell_radius * 0.08)
	_configured = true
	_last_capsule_pos = global_position


func _physics_process(delta: float) -> void:
	if not _configured:
		return
	var body := get_parent() as RigidBody3D
	if body == null:
		return

	var dt := maxf(delta, 0.0001)
	var capsule_vel := body.linear_velocity
	if capsule_vel.length_squared() < 0.0004:
		var pos_delta := body.global_position - _last_capsule_pos
		if pos_delta.length_squared() > 0.000001:
			capsule_vel = pos_delta / dt

	var capsule_accel := (capsule_vel - _last_capsule_vel) / dt
	_last_capsule_vel = capsule_vel
	_last_capsule_pos = body.global_position

	# Inertia: sticker resists capsule acceleration and spin.
	_velocity -= body.global_transform.basis.inverse() * capsule_accel * inertia_scale * dt
	_velocity += body.angular_velocity.cross(position) * spin_coupling * dt

	var local_gravity := body.global_transform.basis.inverse() * Vector3(0.0, -9.8, 0.0)
	_velocity += local_gravity * gravity_scale * dt

	_velocity *= exp(-damping * dt)
	position += _velocity * dt
	_constrain_to_sphere()


func _constrain_to_sphere() -> void:
	var dist := position.length()
	if dist <= _max_radius or dist <= 0.0001:
		return
	var normal := position / dist
	position = normal * _max_radius
	var normal_speed := _velocity.dot(normal)
	if normal_speed > 0.0:
		_velocity -= normal * normal_speed * (1.0 + wall_bounce)
