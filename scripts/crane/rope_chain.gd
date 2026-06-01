class_name RopeChain
extends Node3D

## Segmented rope between hoist anchor (A) and claw (C).
## Segments inside the freeze volume stay frozen (no swing through the carriage).

@export var segment_count: int = 7
@export var segment_length: float = 0.14
@export var segment_radius: float = 0.018
@export var segment_mass: float = 0.05

var segments: Array[RigidBody3D] = []
var _freeze_zone: Area3D
var _anchor: RigidBody3D
var _claw: RigidBody3D


func setup(anchor: RigidBody3D, claw: RigidBody3D, freeze_zone: Area3D) -> void:
	_anchor = anchor
	_claw = claw
	_freeze_zone = freeze_zone
	call_deferred("_rebuild")


func _rebuild() -> void:
	_clear_segments()
	if _anchor == null or _claw == null:
		return

	var prev_body: PhysicsBody3D = _anchor
	var start := _anchor.global_position
	var end := _claw.global_position
	var total_len := maxf(start.distance_to(end), segment_length * 2.0)
	var count := maxi(segment_count, 2)
	var step := total_len / float(count + 1)

	for i in count:
		var t := step * float(i + 1)
		var pos := start.lerp(end, t / total_len) if total_len > 0.01 else start + Vector3.DOWN * t
		var seg := _create_segment(pos)
		add_child(seg)
		segments.append(seg)
		_pin_bodies(prev_body, seg)
		prev_body = seg

	_pin_bodies(prev_body, _claw)


func _create_segment(world_pos: Vector3) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = "RopeSeg_%d" % segments.size()
	body.mass = segment_mass
	body.linear_damp = 0.8
	body.angular_damp = 1.2
	body.continuous_cd = true
	body.collision_layer = 0
	body.collision_mask = 0

	var mesh_instance := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = segment_radius
	cyl.bottom_radius = segment_radius
	cyl.height = segment_length
	mesh_instance.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.08, 0.1)
	mesh_instance.material_override = mat
	body.add_child(mesh_instance)

	body.global_position = world_pos
	return body


func _pin_bodies(a: PhysicsBody3D, b: PhysicsBody3D) -> void:
	var pin := PinJoint3D.new()
	add_child(pin)
	pin.node_a = pin.get_path_to(a)
	pin.node_b = pin.get_path_to(b)
	pin.global_position = a.global_position.lerp(b.global_position, 0.5)


func _physics_process(_delta: float) -> void:
	if _freeze_zone == null:
		return
	for seg in segments:
		if not is_instance_valid(seg):
			continue
		var frozen := _freeze_zone.overlaps_body(seg)
		seg.freeze = frozen
		if frozen:
			seg.linear_velocity = Vector3.ZERO
			seg.angular_velocity = Vector3.ZERO


func refresh_layout() -> void:
	if segments.is_empty():
		return
	var start := _anchor.global_position
	var end := _claw.global_position
	var total_len := maxf(start.distance_to(end), segment_length)
	var count := segments.size()
	for i in count:
		var t := float(i + 1) / float(count + 1)
		segments[i].global_position = start.lerp(end, t)


func _clear_segments() -> void:
	for child in get_children():
		if child is PinJoint3D:
			child.queue_free()
	for seg in segments:
		if is_instance_valid(seg):
			seg.queue_free()
	segments.clear()
