# filename: prize_spawner.gd
extends Marker3D

@export var pile_count: int = 18


func _ready() -> void:
	await get_tree().create_timer(0.2).timeout
	var pack := GameState.get_active_pack()
	if pack == null:
		push_warning("PrizeSpawner: no pack configured; skipping spawn.")
		return
	if not pack.uses_containers() and pack.get_prizes().is_empty():
		push_warning("PrizeSpawner: pack has no spawn pool; skipping spawn.")
		return
	if pack.uses_containers() and pack.get_containers().is_empty():
		push_warning("PrizeSpawner: pack has no containers; skipping spawn.")
		return
	var pack_id := pack.id
	var remaining := GameState.get_prizes_remaining(pack_id)
	var spawn_count := mini(pile_count, remaining)
	if spawn_count <= 0:
		push_warning("PrizeSpawner: pack stock empty.")
		return
	if pack.uses_containers():
		build_capsule_pile(spawn_count, pack)
	else:
		build_loose_pile(spawn_count, pack)


func build_capsule_pile(count: int, pack: PackDefinition) -> void:
	var high_friction_mat := PhysicsMaterial.new()
	high_friction_mat.friction = 1.0
	high_friction_mat.bounce = 0.04
	high_friction_mat.rough = true

	for i in range(count):
		var container_def := pack.pick_random_container()
		if container_def == null:
			continue
		var body := _spawn_capsule_body(container_def, high_friction_mat)
		body.collision_layer = PhysicsLayers.PRIZES
		body.collision_mask = PhysicsLayers.PRIZE_COLLIDE_WITH
		body.add_to_group("prize")
		var random_stagger := Vector3(
			randf_range(-0.75, 0.75),
			randf_range(0.0, 1.35),
			randf_range(-0.75, 0.75),
		)
		body.position = global_position + random_stagger
		get_parent().add_child(body)


func _spawn_capsule_body(container_def: ContainerDefinition, physics_mat: PhysicsMaterial) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.physics_material_override = physics_mat
	body.mass = container_def.mass
	body.continuous_cd = true

	var collision_shape := CollisionShape3D.new()
	if container_def.container_type == ContainerDefinition.ContainerType.BOX:
		var box_r := ClawRig.CAPSULE_RADIUS * 0.95
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(box_r * 2.1, box_r * 1.6, box_r * 2.1)
		collision_shape.shape = box_shape
	else:
		var sphere_shape := SphereShape3D.new()
		sphere_shape.radius = ClawRig.CAPSULE_RADIUS
		collision_shape.shape = sphere_shape
	body.add_child(collision_shape)

	CapsuleVisual.attach(body, container_def)
	PrizePickup.attach(body, container_def)
	return body


func build_loose_pile(count: int, pack: PackDefinition) -> void:
	var high_friction_mat := PhysicsMaterial.new()
	high_friction_mat.friction = 1.0
	high_friction_mat.bounce = 0.02
	high_friction_mat.rough = true

	for i in range(count):
		var prize_def := pack.pick_random_prize()
		if prize_def == null:
			continue
		var body := _spawn_loose_body(prize_def, high_friction_mat)
		body.collision_layer = PhysicsLayers.PRIZES
		body.collision_mask = PhysicsLayers.PRIZE_COLLIDE_WITH
		body.add_to_group("prize")
		var random_stagger := Vector3(
			randf_range(-0.75, 0.75),
			randf_range(0.0, 1.35),
			randf_range(-0.75, 0.75),
		)
		body.position = global_position + random_stagger
		get_parent().add_child(body)


func _spawn_loose_body(prize_def: PrizeDefinition, physics_mat: PhysicsMaterial) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.physics_material_override = physics_mat
	body.mass = 0.18
	body.continuous_cd = true

	var capsule_r := ClawRig.CAPSULE_RADIUS * 0.72
	var collision_shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = capsule_r
	collision_shape.shape = sphere_shape
	body.add_child(collision_shape)

	CapsuleVisual.attach_loose(body, prize_def)
	PrizePickup.attach_loose(body, prize_def)
	return body
