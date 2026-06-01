class_name CraneMachineDefinition
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var scene_path: String = "res://main.tscn"
@export var claw_profile_id: String = "standard_rigged"
@export var pack_ids: Array[String] = []
@export var play_cost: int = 1
@export var coin_currency_id: String = "default"

@export_group("Cabinet Layout")
@export var gantry_min: Vector3 = Vector3(-2.1, 3.4, -2.1)
@export var gantry_max: Vector3 = Vector3(2.1, 3.4, 2.1)
@export var chute_position: Vector3 = Vector3(-1.8, 3.4, -1.8)
@export var start_gantry: Vector3 = Vector3.ZERO
