# filename: main.gd
extends Node3D

const HUD_SCENE := preload("res://scripts/crane/crane_session_hud.tscn")
const PRIZE_WIN_FLASH_SCENE := preload("res://scripts/ui/prize_win_flash.tscn")

var _scored_bodies: Dictionary = {}
var _prize_win_flash: PrizeWinFlash


func _ready() -> void:
	add_child(HUD_SCENE.instantiate())
	_prize_win_flash = PRIZE_WIN_FLASH_SCENE.instantiate() as PrizeWinFlash
	add_child(_prize_win_flash)
	var machine := GameState.get_active_machine()
	var pack := GameState.get_active_pack()
	var crane: CraneController = $CraneSystem as CraneController
	if machine and crane:
		var chute := $ChuteArea as Node3D
		if chute:
			machine.chute_position = Vector3(
				chute.global_position.x,
				machine.gantry_min.y,
				chute.global_position.z,
			)
		crane.configure(machine)
		var pack_name := pack.display_name if pack else machine.display_name
		print("🕹️ Cabinet online: %s · Claw: %s" % [pack_name, crane.get_profile_display_name()])
	else:
		print("🕹️ Cabinet online (no machine definition).")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/display_room/display_room.tscn")


func _on_chute_area_body_entered(body: Node) -> void:
	if not body is RigidBody3D or is_part_of_crane(body):
		return
	if _scored_bodies.has(body.get_instance_id()):
		return
	_scored_bodies[body.get_instance_id()] = true

	var pickup := PrizePickup.from_body(body)
	var pack_id := GameState.active_pack_id
	if pickup and pickup.container:
		GameState.add_unopened(pickup.container, pack_id)
		GameState.record_pack_container_won(pack_id, pickup.container)
		_prize_win_flash.show_container(pickup.container)
		print(
			"🎉 UNOPENED: %s (%s) · queue: %d" % [
				pickup.container.display_name,
				ContainerDefinition.rarity_label(pickup.container.rarity),
				GameState.get_unopened_count(),
			]
		)
	elif pickup and pickup.definition:
		GameState.add_prize(pickup.definition, 1)
		GameState.record_pack_prize_won(pack_id, pickup.definition)
		_prize_win_flash.show_prize(pickup.definition)
		print(
			"🎉 STICKER WON: %s · owned: %d" % [
				pickup.definition.display_name,
				GameState.get_owned_count(pickup.definition.id),
			]
		)
	else:
		print("🎉 PRIZE DETECTED (unregistered).")

	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(body):
		body.queue_free()


func is_part_of_crane(node: Node) -> bool:
	if node.name == "CraneSystem" or node.name == "ClawAssembly" or node.name.begins_with("Prong"):
		return true
	if node is CraneController:
		return true
	var parent := node.get_parent()
	return parent != null and is_part_of_crane(parent)
