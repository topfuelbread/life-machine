class_name ClawRig
extends Node3D

## Unity-style claw: ClawCenter → Claw_XX_center → Claw_XX_01 → Claw_XX_02 (+ tip cols).
## Lower segment (02) rotates +X: low angle = wide trap ring, high angle = inward pinch.

const ARM_COUNT := 3
const ARM_SPREAD_DEG := 120.0

const CAPSULE_RADIUS := 0.22

# Open pose must clear prize diameter (0.44 m); upper splay + low B angle sets tip ring ~0.62 m.
const HUB_MOUNT_R := CAPSULE_RADIUS * 0.92
const FINGER_WIDTH := CAPSULE_RADIUS * 0.11
const UPPER_ARM_LEN := CAPSULE_RADIUS * 1.1
const LOWER_ARM_LEN := CAPSULE_RADIUS * 1.3
const TIP_CONE_H := CAPSULE_RADIUS * 0.32

const UPPER_SPLAY_X_DEG := -14.0
const OPEN_ANGLE_B_DEG := 16.0
const CLOSE_ANGLE_B_DEG := 108.0

var _arm_controllers: Array[ClawArmController] = []


static func grab_zone_radius() -> float:
	return CAPSULE_RADIUS * 1.5


func build(parent_body: RigidBody3D, finger_material: StandardMaterial3D) -> void:
	name = "ClawCenter"
	for child in get_children():
		child.queue_free()
	_arm_controllers.clear()

	for i in ARM_COUNT:
		var yaw_deg := ARM_SPREAD_DEG * float(i)
		var arm_root := _build_arm(i + 1, yaw_deg, finger_material)
		add_child(arm_root)

	parent_body.add_child(self)
	position = Vector3(0.0, -0.025, 0.0)

	parent_body.collision_layer = PhysicsLayers.CLAW
	parent_body.collision_mask = PhysicsLayers.CLAW_COLLIDE_WITH
	var claw_mat := PhysicsMaterial.new()
	claw_mat.friction = 0.95
	claw_mat.rough = true
	parent_body.physics_material_override = claw_mat

	open_all()


func _build_arm(index: int, yaw_deg: float, mat: StandardMaterial3D) -> Node3D:
	var arm_center := Node3D.new()
	arm_center.name = "Claw_%02d_center" % index
	arm_center.rotation_degrees.y = yaw_deg

	# Upper segment — fixed outward splay; extends down and out from hub rim.
	var seg_a := Node3D.new()
	seg_a.name = "Claw_%02d_01" % index
	seg_a.position = Vector3(0.0, -0.01, HUB_MOUNT_R)
	seg_a.rotation_degrees.x = UPPER_SPLAY_X_DEG
	arm_center.add_child(seg_a)
	_add_bar_mesh(
		seg_a,
		FINGER_WIDTH,
		UPPER_ARM_LEN,
		Vector3(0.0, -UPPER_ARM_LEN * 0.46, UPPER_ARM_LEN * 0.38),
		mat,
	)
	_add_bar_collider(
		seg_a,
		FINGER_WIDTH,
		UPPER_ARM_LEN,
		Vector3(0.0, -UPPER_ARM_LEN * 0.46, UPPER_ARM_LEN * 0.38),
		index,
		"01",
	)

	# Lower segment — rotates on X; small angle = wide open, large angle = pinch.
	var seg_b := Node3D.new()
	seg_b.name = "Claw_%02d_02" % index
	seg_b.position = Vector3(0.0, -UPPER_ARM_LEN * 0.88, UPPER_ARM_LEN * 0.62)
	seg_a.add_child(seg_b)
	_add_bar_mesh(
		seg_b,
		FINGER_WIDTH * 0.9,
		LOWER_ARM_LEN,
		Vector3(0.0, -LOWER_ARM_LEN * 0.46, LOWER_ARM_LEN * 0.28),
		mat,
	)
	_add_bar_collider(
		seg_b,
		FINGER_WIDTH * 0.9,
		LOWER_ARM_LEN,
		Vector3(0.0, -LOWER_ARM_LEN * 0.46, LOWER_ARM_LEN * 0.28),
		index,
		"02",
	)
	_add_hook_tip(seg_b, mat)
	_add_tip_colliders(seg_b, index)

	var controller := ClawArmController.new()
	controller.name = "ArmController%d" % index
	controller.segment_b = seg_b
	controller.open_angle_b_deg = OPEN_ANGLE_B_DEG
	controller.close_angle_b_deg = CLOSE_ANGLE_B_DEG
	seg_b.add_child(controller)
	_arm_controllers.append(controller)

	return arm_center


func _add_bar_mesh(
	parent: Node3D,
	width: float,
	length: float,
	center: Vector3,
	mat: StandardMaterial3D,
) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, length, width * 0.75)
	mesh_instance.mesh = box
	mesh_instance.material_override = mat
	mesh_instance.position = center
	parent.add_child(mesh_instance)


func _add_bar_collider(
	parent: Node3D,
	width: float,
	length: float,
	center: Vector3,
	index: int,
	segment: String,
) -> void:
	var col := CollisionShape3D.new()
	col.name = "Claw_%02d_%s_col" % [index, segment]
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, length, width * 0.75)
	col.shape = shape
	col.position = center
	parent.add_child(col)


func _add_hook_tip(parent: Node3D, mat: StandardMaterial3D) -> void:
	var tip := MeshInstance3D.new()
	tip.name = "TipHook"
	var cone := CylinderMesh.new()
	cone.top_radius = FINGER_WIDTH * 0.12
	cone.bottom_radius = FINGER_WIDTH * 0.65
	cone.height = TIP_CONE_H
	cone.radial_segments = 8
	tip.mesh = cone
	tip.material_override = mat
	# Cone axis along -Y in segment space; +X rotation on parent hooks it inward.
	tip.position = Vector3(0.0, -LOWER_ARM_LEN * 0.94, LOWER_ARM_LEN * 0.26)
	tip.rotation_degrees.x = 180.0
	parent.add_child(tip)


func _add_tip_colliders(seg_b: Node3D, index: int) -> void:
	var w := FINGER_WIDTH

	var col_positions: Array[Vector3] = [
		Vector3(0.0, -LOWER_ARM_LEN * 0.55, LOWER_ARM_LEN * 0.22),
		Vector3(-w * 0.9, -LOWER_ARM_LEN * 0.72, LOWER_ARM_LEN * 0.32),
		Vector3(w * 0.9, -LOWER_ARM_LEN * 0.72, LOWER_ARM_LEN * 0.32),
	]

	for j in col_positions.size():
		var col := CollisionShape3D.new()
		col.name = "Claw_%02d_02_col_%02d" % [index, j + 1]
		var shape := SphereShape3D.new()
		shape.radius = maxf(w * 0.65, CAPSULE_RADIUS * 0.08)
		col.shape = shape
		col.position = col_positions[j]
		seg_b.add_child(col)


func set_all_closed(closed: bool, close_blend: float = 1.0) -> void:
	for controller in _arm_controllers:
		controller.set_closed(closed, close_blend)


func open_all() -> void:
	for controller in _arm_controllers:
		controller.open_immediate()


func get_controllers() -> Array[ClawArmController]:
	return _arm_controllers
