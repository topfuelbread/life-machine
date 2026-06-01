class_name CraneMachineDefinition
extends Resource

enum Difficulty { NONE = 0, EASY = 1, NORMAL = 2, HARD = 3 }

@export var id: String = ""
@export var display_name: String = ""
@export var rarity: PrizeDefinition.Rarity = PrizeDefinition.Rarity.COMMON
@export var claw_type: String = ""
@export var claw_profile_id: String = "standard_rigged"
@export var difficulty: Difficulty = Difficulty.NORMAL
@export var initial_prize_stock: int = 24
@export var scene_path: String = "res://main.tscn"
@export var play_cost: int = 1

@export_group("Cabinet Layout")
@export var gantry_min: Vector3 = Vector3(-2.1, 3.4, -2.1)
@export var gantry_max: Vector3 = Vector3(2.1, 3.4, 2.1)
@export var chute_position: Vector3 = Vector3(-1.8, 3.4, -1.8)
@export var start_gantry: Vector3 = Vector3.ZERO


func get_claw_type_label() -> String:
	if not claw_type.is_empty():
		return claw_type
	var profile := StarterContent.get_claw_profile(claw_profile_id)
	return profile.display_name if profile else claw_profile_id


static func difficulty_label(level: Difficulty) -> String:
	match level:
		Difficulty.NONE:
			return "None"
		Difficulty.EASY:
			return "Easy"
		Difficulty.HARD:
			return "Hard"
	return "Normal"
