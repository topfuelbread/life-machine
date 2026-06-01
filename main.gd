# filename: main.gd
extends Node3D

const HUD_SCENE := preload("res://scripts/crane/crane_session_hud.tscn")

var internal_win_score: int = 0
var _scored_bodies: Dictionary = {}

func _ready() -> void:
	add_child(HUD_SCENE.instantiate())
	var machine := GameState.get_active_machine()
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
		print(
			"🕹️ Cabinet online: %s · Claw: %s" % [
				machine.display_name,
				crane.get_profile_display_name(),
			]
		)
	else:
		print("🕹️ Cabinet online (no machine definition).")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/game_root.tscn")

func _on_chute_area_body_entered(body: Node) -> void:
	if not body is RigidBody3D or is_part_of_crane(body):
		return
	if _scored_bodies.has(body.get_instance_id()):
		return
	_scored_bodies[body.get_instance_id()] = true

	var pickup := PrizePickup.from_body(body)
	if pickup and pickup.definition:
		GameState.add_prize(pickup.definition)
		internal_win_score += 1
		print(
			"🎉 PRIZE WON: %s (owned: %d)" % [
				pickup.definition.display_name,
				GameState.get_owned_count(pickup.definition.id),
			]
		)
	else:
		internal_win_score += 1
		print("🎉 PRIZE DETECTED (unregistered). Total: ", internal_win_score)

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
