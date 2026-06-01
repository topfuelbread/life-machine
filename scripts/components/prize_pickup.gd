class_name PrizePickup
extends Node

@export var container: ContainerDefinition
@export var definition: PrizeDefinition


static func attach(body: RigidBody3D, container_def: ContainerDefinition) -> PrizePickup:
	var pickup := PrizePickup.new()
	pickup.container = container_def
	pickup.definition = container_def.get_prize()
	pickup.name = "PrizePickup"
	body.add_child(pickup)
	body.set_meta("container_id", container_def.id)
	if pickup.definition:
		body.set_meta("prize_id", pickup.definition.id)
	return pickup


static func attach_loose(body: RigidBody3D, prize_def: PrizeDefinition) -> PrizePickup:
	var pickup := PrizePickup.new()
	pickup.definition = prize_def
	pickup.name = "PrizePickup"
	body.add_child(pickup)
	if prize_def:
		body.set_meta("prize_id", prize_def.id)
	return pickup


static func from_body(body: Node) -> PrizePickup:
	for child in body.get_children():
		if child is PrizePickup:
			return child
	return null
