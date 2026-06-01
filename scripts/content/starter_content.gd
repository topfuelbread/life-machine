class_name StarterContent
extends RefCounted

const STARTER_MACHINE_ID := "starter_claw"
const STARTER_PACK_ID := "starter_pack"
const VAULT_MACHINE_ID := "vault_claw"
const VAULT_PACK_ID := "vault_arcade_pack"
const ARCHITECTURE_MACHINE_ID := "architecture_lab_claw"
const ARCHITECTURE_PACK_ID := "architecture_lab_pack"
const CATFISH_MACHINE_ID := "catfish_claw"
const CATFISH_PACK_ID := "catfish_pack"
const PETS_MACHINE_ID := "pets_claw"
const PETS_PACK_ID := "pets_pack"
const UNNIE_MACHINE_ID := "unnie_claw"
const UNNIE_PACK_ID := "unnie_pack"

const RED_CAPSULE_ID := "red_capsule"
const BLUE_CAPSULE_ID := "blue_capsule"
const FLUFFY_CAT_PRIZE_ID := "fluffy_white_cat"
const CLASSY_MUSTACHE_PRIZE_ID := "classy_mustache"

const CLAW_STANDARD_ID := "standard_rigged"
const CLAW_LOOSE_ID := "loose_arcade"
const CLAW_SNAP_ID := "snap_grip"

## Pack IDs granted to new players and migrated saves.
const DEFAULT_OWNED_PACK_IDS: Array[String] = [
	STARTER_PACK_ID,
	VAULT_PACK_ID,
	ARCHITECTURE_PACK_ID,
	CATFISH_PACK_ID,
	PETS_PACK_ID,
	UNNIE_PACK_ID,
]


static func get_claw_profile(profile_id: String) -> ClawProfileDefinition:
	match profile_id:
		CLAW_STANDARD_ID:
			return _build_standard_claw()
		CLAW_LOOSE_ID:
			return _build_loose_arcade_claw()
		CLAW_SNAP_ID:
			return _build_snap_grip_claw()
	return _build_standard_claw()


static func _build_standard_claw() -> ClawProfileDefinition:
	var p := ClawProfileDefinition.new()
	p.id = CLAW_STANDARD_ID
	p.display_name = "Standard 3-prong"
	p.payout_probability = 1.0
	p.grip_torque_strong = 18.0
	p.grip_torque_weak = 2.5
	p.weak_grip_delay = 0.3
	p.grab_close_duration = 1.05
	p.hoist_drop_speed = 1.5
	p.hoist_ascend_speed = 1.4
	return p


static func _build_loose_arcade_claw() -> ClawProfileDefinition:
	var p := ClawProfileDefinition.new()
	p.id = CLAW_LOOSE_ID
	p.display_name = "Loose arcade (3-prong)"
	p.payout_probability = 0.50
	p.grip_torque_strong = 18.0
	p.grip_torque_weak = 3.2
	p.weak_grip_delay = 0.60
	p.grab_close_duration = 0.95
	p.hoist_drop_speed = 1.7
	p.hoist_ascend_speed = 1.6
	return p


static func _build_snap_grip_claw() -> ClawProfileDefinition:
	var p := ClawProfileDefinition.new()
	p.id = CLAW_SNAP_ID
	p.display_name = "Snap grip (balloon pop)"
	p.payout_probability = 0.22
	p.grip_torque_strong = 20.0
	p.grip_torque_weak = 2.2
	p.weak_grip_delay = 0.18
	p.grab_close_duration = 0.72
	p.release_open_duration = 0.65
	p.hoist_drop_speed = 1.85
	p.hoist_ascend_speed = 1.75
	p.gantry_move_speed = 2.2
	p.min_grab_overlap_seconds = 0.12
	return p


static func create_starter_machine() -> CraneMachineDefinition:
	var machine := CraneMachineDefinition.new()
	machine.id = STARTER_MACHINE_ID
	machine.display_name = "Neon Corner Claw"
	machine.rarity = PrizeDefinition.Rarity.COMMON
	machine.claw_profile_id = CLAW_STANDARD_ID
	var profile := get_claw_profile(CLAW_STANDARD_ID)
	machine.claw_type = profile.display_name if profile else CLAW_STANDARD_ID
	machine.difficulty = CraneMachineDefinition.Difficulty.NONE
	machine.scene_path = "res://main.tscn"
	machine.play_cost = 1
	machine.initial_prize_stock = 36
	return machine


static func create_vault_machine() -> CraneMachineDefinition:
	var machine := CraneMachineDefinition.new()
	machine.id = VAULT_MACHINE_ID
	machine.display_name = "Golden Vault Claw"
	machine.rarity = PrizeDefinition.Rarity.UNCOMMON
	machine.claw_profile_id = CLAW_LOOSE_ID
	var profile := get_claw_profile(CLAW_LOOSE_ID)
	machine.claw_type = profile.display_name if profile else CLAW_LOOSE_ID
	machine.difficulty = CraneMachineDefinition.Difficulty.EASY
	machine.scene_path = "res://scenes/machines/vault_claw.tscn"
	machine.play_cost = 2
	machine.initial_prize_stock = 24
	return machine


static func create_pets_machine() -> CraneMachineDefinition:
	var machine := CraneMachineDefinition.new()
	machine.id = PETS_MACHINE_ID
	machine.display_name = "Pets Claw"
	machine.rarity = PrizeDefinition.Rarity.COMMON
	machine.claw_profile_id = CLAW_STANDARD_ID
	var profile := get_claw_profile(CLAW_STANDARD_ID)
	machine.claw_type = profile.display_name if profile else CLAW_STANDARD_ID
	machine.difficulty = CraneMachineDefinition.Difficulty.NONE
	machine.scene_path = "res://main.tscn"
	machine.play_cost = 1
	machine.initial_prize_stock = 27
	return machine


static func create_unnie_machine() -> CraneMachineDefinition:
	var machine := CraneMachineDefinition.new()
	machine.id = UNNIE_MACHINE_ID
	machine.display_name = "Unnie Claw"
	machine.rarity = PrizeDefinition.Rarity.UNCOMMON
	machine.claw_profile_id = CLAW_STANDARD_ID
	var profile := get_claw_profile(CLAW_STANDARD_ID)
	machine.claw_type = profile.display_name if profile else CLAW_STANDARD_ID
	machine.difficulty = CraneMachineDefinition.Difficulty.NONE
	machine.scene_path = "res://main.tscn"
	machine.play_cost = 1
	machine.initial_prize_stock = 32
	return machine


static func create_catfish_machine() -> CraneMachineDefinition:
	var machine := CraneMachineDefinition.new()
	machine.id = CATFISH_MACHINE_ID
	machine.display_name = "Catfish Claw"
	machine.rarity = PrizeDefinition.Rarity.COMMON
	machine.claw_profile_id = CLAW_STANDARD_ID
	var profile := get_claw_profile(CLAW_STANDARD_ID)
	machine.claw_type = profile.display_name if profile else CLAW_STANDARD_ID
	machine.difficulty = CraneMachineDefinition.Difficulty.NONE
	machine.scene_path = "res://main.tscn"
	machine.play_cost = 1
	machine.initial_prize_stock = 30
	return machine


static func create_architecture_lab_machine() -> CraneMachineDefinition:
	var machine := CraneMachineDefinition.new()
	machine.id = ARCHITECTURE_MACHINE_ID
	machine.display_name = "Architecture Lab Claw"
	machine.rarity = PrizeDefinition.Rarity.RARE
	machine.claw_profile_id = CLAW_SNAP_ID
	var profile := get_claw_profile(CLAW_SNAP_ID)
	machine.claw_type = profile.display_name if profile else CLAW_SNAP_ID
	machine.difficulty = CraneMachineDefinition.Difficulty.HARD
	machine.scene_path = "res://scenes/machines/architecture_lab_claw.tscn"
	machine.play_cost = 3
	machine.initial_prize_stock = 20
	# Thin "ant farm" cabinet — single-axis feel, downward claw over shallow pit.
	machine.gantry_min = Vector3(-1.6, 3.4, -1.6)
	machine.gantry_max = Vector3(1.6, 3.4, 1.6)
	machine.chute_position = Vector3(0.0, 3.4, -1.8)
	machine.start_gantry = Vector3.ZERO
	return machine


static func get_machine(machine_id: String) -> CraneMachineDefinition:
	match machine_id:
		STARTER_MACHINE_ID:
			return create_starter_machine()
		VAULT_MACHINE_ID:
			return create_vault_machine()
		ARCHITECTURE_MACHINE_ID:
			return create_architecture_lab_machine()
		CATFISH_MACHINE_ID:
			return create_catfish_machine()
		PETS_MACHINE_ID:
			return create_pets_machine()
		UNNIE_MACHINE_ID:
			return create_unnie_machine()
	return null


static func get_all_machine_ids() -> Array[String]:
	return [
		STARTER_MACHINE_ID,
		VAULT_MACHINE_ID,
		ARCHITECTURE_MACHINE_ID,
		CATFISH_MACHINE_ID,
		PETS_MACHINE_ID,
		UNNIE_MACHINE_ID,
	]


static func get_all_pack_ids() -> Array[String]:
	return PrizeCatalog.get_all_pack_ids()
