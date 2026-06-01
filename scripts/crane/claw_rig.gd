class_name ClawRig
extends Node3D

## 3-prong claw sized by ClawGeometry so open ring admits sphere R and closed ring traps it.

const CAPSULE_RADIUS := ClawGeometry.CAPSULE_RADIUS

var _arm_controllers: Array[ClawArmController] = []
var _physics_body: RigidBody3D
var _sync_colliders: Array[Dictionary] = []
var _collider_serial: int = 0
var _dims: Dictionary = {}
var _grasp_cage: CollisionShape3D
var _close_blend: float = 0.0


static func grab_zone_radius() -> float:
	var d := ClawGeometry.solve(ClawGeometry.prize_radius())
	return d.get("grab_zone_radius", CAPSULE_RADIUS * 1.55)


static func drop_ray_length() -> float:
	var d := ClawGeometry.solve(ClawGeometry.prize_radius())
	return d.get("drop_ray_length", CAPSULE_RADIUS * 3.2)


static func get_grasp_center_offset() -> Vector3:
	var d := ClawGeometry.solve(ClawGeometry.prize_radius())
	return d.get("grasp_center", Vector3(0.0, -CAPSULE_RADIUS * 0.72, 0.0))


func build(parent_body: RigidBody3D, finger_material: StandardMaterial3D) -> void:
	name = "ClawCenter"
	_physics_body = parent_body
	_dims = ClawGeometry.solve(ClawGeometry.prize_radius())
	_clear_physics_colliders()

	for child in get_children():
		if child is ClawArmController or child.name.begins_with("Claw_"):
			child.queue_free()
	_arm_controllers.clear()
	_sync_colliders.clear()
	_collider_serial = 0
	_grasp_cage = null

	for i in ClawGeometry.ARM_COUNT:
		var yaw_deg := ClawGeometry.ARM_SPREAD_DEG * float(i)
		var arm_root := _build_arm(i + 1, yaw_deg, finger_material, parent_body)
		add_child(arm_root)

	parent_body.add_child(self)
	position = Vector3(0.0, -0.025, 0.0)

	parent_body.collision_layer = PhysicsLayers.CLAW
	parent_body.collision_mask = PhysicsLayers.CLAW_COLLIDE_WITH
	parent_body.continuous_cd = true
	parent_body.contact_monitor = true
	parent_body.max_contacts_reported = 12
	var claw_mat := PhysicsMaterial.new()
	claw_mat.friction = 1.0
	claw_mat.rough = true
	claw_mat.bounce = 0.02
	parent_body.physics_material_override = claw_mat

	_add_palm_collider(parent_body)
	_add_grasp_cage(parent_body)
	_tune_hub_visual(parent_body)
	process_physics_priority = -10
	open_all()
	set_physics_process(true)


func _tune_hub_visual(parent_body: RigidBody3D) -> void:
	var hub_mesh := parent_body.get_node_or_null("HubMesh") as MeshInstance3D
	if hub_mesh:
		hub_mesh.scale = Vector3(0.7, 0.55, 0.7)
		hub_mesh.position = Vector3(0.0, 0.04, 0.0)


func _clear_physics_colliders() -> void:
	if _physics_body == null:
		return
	for child in _physics_body.get_children():
		if child is CollisionShape3D and child.name.begins_with("PhysCol_"):
			child.queue_free()


func _physics_process(_delta: float) -> void:
	if _physics_body == null:
		return
	var inv := _physics_body.global_transform.affine_inverse()
	for entry in _sync_colliders:
		var col: CollisionShape3D = entry.get("shape")
		var follow: Node3D = entry.get("follow")
		if col == null or follow == null or not is_instance_valid(col) or not is_instance_valid(follow):
			continue
		col.transform = inv * follow.global_transform
	for controller in _arm_controllers:
		controller.apply_prize_pushes(_delta)
	_update_grasp_cage()


func _update_grasp_cage() -> void:
	# Fingers + contact flex handle encapsulation; cage caused clipping through prizes.
	if _grasp_cage:
		_grasp_cage.disabled = true


func _dim_f(key: String, fallback: float = 0.0) -> float:
	return float(_dims.get(key, fallback))


func _dim_v3(key: String, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	var v: Variant = _dims.get(key, fallback)
	return v as Vector3 if v is Vector3 else fallback


func _make_close_probe(parent: Node3D, local_target: Vector3, r: float) -> RayCast3D:
	var ray := RayCast3D.new()
	ray.name = "CloseProbe"
	ray.target_position = local_target
	ray.collision_mask = PhysicsLayers.PRIZES
	ray.hit_from_inside = true
	parent.add_child(ray)
	return ray


func _build_arm(index: int, yaw_deg: float, mat: StandardMaterial3D, body: RigidBody3D) -> Node3D:
	var L1: float = _dim_f("upper_arm_len")
	var L2: float = _dim_f("lower_arm_len")
	var hub_r: float = _dim_f("hub_mount_r")
	var finger_w: float = _dim_f("finger_width")
	var tip_h: float = _dim_f("tip_cone_h")
	var r: float = _dim_f("r", CAPSULE_RADIUS)

	var arm_center := Node3D.new()
	arm_center.name = "Claw_%02d_center" % index
	arm_center.rotation_degrees.y = yaw_deg

	# Upper segment: hub ring → outward on +Z, then down -Y.
	var seg_a := Node3D.new()
	seg_a.name = "Claw_%02d_01" % index
	seg_a.position = Vector3(0.0, 0.0, hub_r)
	seg_a.rotation_degrees.x = ClawGeometry.UPPER_SPLAY_DEG
	arm_center.add_child(seg_a)

	var upper_mesh := _add_segment_bar(seg_a, finger_w, L1, Vector3(0.0, -L1 * 0.5, 0.0), mat)
	_register_body_collider(body, upper_mesh, finger_w, L1)

	# Lower segment: hinged at end of upper arm.
	var seg_b := Node3D.new()
	seg_b.name = "Claw_%02d_02" % index
	seg_b.position = Vector3(0.0, -L1, 0.0)
	seg_a.add_child(seg_b)

	var lower_w := finger_w * 0.95
	var lower_mesh := _add_segment_bar(seg_b, lower_w, L2, Vector3(0.0, -L2 * 0.5, 0.0), mat)
	_register_body_collider(body, lower_mesh, lower_w, L2)

	var mid_probe := _make_close_probe(seg_b, Vector3(0.0, -L2 * 0.35, L2 * 0.05), r)

	var tip_anchor := Node3D.new()
	tip_anchor.name = "TipAnchor"
	tip_anchor.position = Vector3(0.0, -L2, L2 * ClawGeometry.TIP_LOCAL.z)
	seg_b.add_child(tip_anchor)

	var flex_pivot := Node3D.new()
	flex_pivot.name = "FlexPivot"
	tip_anchor.add_child(flex_pivot)

	var tip_probe := _make_close_probe(
		flex_pivot,
		Vector3(0.0, -tip_h * 0.35, -r * 0.55),
		r,
	)
	var tip_mesh := _add_hook_tip(flex_pivot, mat, tip_h, finger_w)
	_register_tip_collider(body, tip_mesh, finger_w)

	var controller := ClawArmController.new()
	controller.name = "ArmController%d" % index
	controller.segment_b = seg_b
	controller.flex_pivot = flex_pivot
	controller.open_angle_b_deg = _dim_f("open_angle_deg")
	controller.close_angle_b_deg = _dim_f("close_angle_deg")
	controller.configure([tip_probe, mid_probe], flex_pivot, body, tip_mesh)
	seg_b.add_child(controller)
	_arm_controllers.append(controller)

	return arm_center


func _add_palm_collider(body: RigidBody3D) -> void:
	var col := CollisionShape3D.new()
	col.name = "PhysCol_Palm"
	var shape := BoxShape3D.new()
	var half_w: float = _dim_f("palm_half_width")
	shape.size = Vector3(half_w * 2.0, _dim_f("palm_depth"), half_w * 2.0)
	col.shape = shape
	col.position = Vector3(0.0, _dim_f("palm_y"), 0.0)
	body.add_child(col)


func _add_grasp_cage(body: RigidBody3D) -> void:
	_grasp_cage = CollisionShape3D.new()
	_grasp_cage.name = "PhysCol_GraspCage"
	var shape := SphereShape3D.new()
	shape.radius = _dim_f("cage_radius")
	_grasp_cage.shape = shape
	_grasp_cage.position = _dim_v3("grasp_center")
	_grasp_cage.disabled = true
	body.add_child(_grasp_cage)


func _add_segment_bar(
	parent: Node3D,
	width: float,
	length: float,
	center: Vector3,
	mat: StandardMaterial3D,
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, length, width * 0.85)
	mesh_instance.mesh = box
	mesh_instance.material_override = mat
	mesh_instance.position = center
	parent.add_child(mesh_instance)
	return mesh_instance


func _register_body_collider(
	body: RigidBody3D,
	follow: Node3D,
	width: float,
	length: float,
) -> void:
	_collider_serial += 1
	var col := CollisionShape3D.new()
	col.name = "PhysCol_%d" % _collider_serial
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, length, width * 0.85)
	col.shape = shape
	body.add_child(col)
	_sync_colliders.append({"shape": col, "follow": follow})


func _register_tip_collider(body: RigidBody3D, follow: Node3D, finger_w: float) -> void:
	var r: float = _dim_f("r", CAPSULE_RADIUS)
	_collider_serial += 1
	var col := CollisionShape3D.new()
	col.name = "PhysCol_%d" % _collider_serial
	var shape := SphereShape3D.new()
	shape.radius = maxf(finger_w * 0.85, r * 0.15)
	col.shape = shape
	body.add_child(col)
	_sync_colliders.append({"shape": col, "follow": follow})


func _add_hook_tip(anchor: Node3D, mat: StandardMaterial3D, tip_h: float, finger_w: float) -> MeshInstance3D:
	var tip := MeshInstance3D.new()
	tip.name = "TipHook"
	var cone := CylinderMesh.new()
	cone.top_radius = finger_w * 0.15
	cone.bottom_radius = finger_w * 0.75
	cone.height = tip_h
	cone.radial_segments = 10
	tip.mesh = cone
	tip.material_override = mat
	tip.position = Vector3(0.0, -tip_h * 0.45, 0.0)
	tip.rotation_degrees.x = 180.0
	anchor.add_child(tip)
	return tip


func set_all_closed(closed: bool, close_blend: float = 1.0) -> void:
	_close_blend = close_blend if closed else 0.0
	for controller in _arm_controllers:
		controller.set_closed(closed, close_blend)
	_update_grasp_cage()


func open_all() -> void:
	_close_blend = 0.0
	for controller in _arm_controllers:
		controller.open_immediate()
	_update_grasp_cage()


func get_controllers() -> Array[ClawArmController]:
	return _arm_controllers


func any_finger_blocked() -> bool:
	for controller in _arm_controllers:
		if controller.is_blocked():
			return true
	return false


func get_grasp_center() -> Vector3:
	return _dim_v3("grasp_center")
