# filename: prize_spawner.gd
extends Marker3D

@export var pile_count: int = 18

func _ready() -> void:
	await get_tree().create_timer(0.2).timeout
	var pack := _resolve_pack()
	if pack == null or pack.prizes.is_empty():
		push_warning("PrizeSpawner: no pack configured; skipping spawn.")
		return
	build_capsule_pile(pile_count, pack)

func _resolve_pack() -> PackDefinition:
	var machine := GameState.get_active_machine()
	if machine and not machine.pack_ids.is_empty():
		return GameState.get_pack(machine.pack_ids[0])
	return StarterContent.create_starter_pack()

func build_capsule_pile(count: int, pack: PackDefinition) -> void:
	var high_friction_mat := PhysicsMaterial.new()
	high_friction_mat.friction = 0.65
	high_friction_mat.bounce = 0.15

	for i in range(count):
		var prize_def := pack.pick_random()
		if prize_def == null:
			continue
		var body := _spawn_prize_body(prize_def, high_friction_mat)
		body.collision_layer = PhysicsLayers.PRIZES
		body.collision_mask = PhysicsLayers.PRIZE_COLLIDE_WITH
		body.add_to_group("prize")
		var random_stagger := Vector3(
			randf_range(-0.6, 0.6),
			randf_range(0.0, 1.2),
			randf_range(-0.6, 0.6),
		)
		body.position = global_position + random_stagger
		get_parent().add_child(body)

func _spawn_prize_body(prize_def: PrizeDefinition, physics_mat: PhysicsMaterial) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.physics_material_override = physics_mat
	body.mass = prize_def.mass
	body.continuous_cd = true

	var mesh_instance := MeshInstance3D.new()
	var collision_shape := CollisionShape3D.new()
	var visual_material := StandardMaterial3D.new()
	visual_material.albedo_color = prize_def.albedo_color
	visual_material.roughness = 0.3
	mesh_instance.material_override = visual_material

	match prize_def.physical_shape:
		PrizeDefinition.PhysicalShape.BOX:
			var box_mesh := BoxMesh.new()
			box_mesh.size = Vector3(0.4, 0.4, 0.4)
			mesh_instance.mesh = box_mesh
			var box_shape := BoxShape3D.new()
			box_shape.size = Vector3(0.4, 0.4, 0.4)
			collision_shape.shape = box_shape
		_:
			var capsule_r := ClawRig.CAPSULE_RADIUS
			var sphere_mesh := SphereMesh.new()
			sphere_mesh.radius = capsule_r
			sphere_mesh.height = capsule_r * 2.0
			mesh_instance.mesh = sphere_mesh
			var sphere_shape := SphereShape3D.new()
			sphere_shape.radius = capsule_r
			collision_shape.shape = sphere_shape

	body.add_child(mesh_instance)
	body.add_child(collision_shape)
	PrizePickup.attach(body, prize_def)
	return body
