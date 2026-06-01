class_name StarterContent
extends RefCounted

const STARTER_MACHINE_ID := "starter_claw"
const LOOSE_MACHINE_ID := "loose_claw"
const SPEED_MACHINE_ID := "speed_claw"
const STARTER_PACK_ID := "starter_capsules"
const PLUSH_PACK_ID := "plush_capsules"

const CLAW_STANDARD_ID := "standard_rigged"
const CLAW_LOOSE_ID := "loose_arcade"
const CLAW_SNAP_ID := "snap_grip"


static func get_claw_profile(profile_id: String) -> ClawProfileDefinition:
	match profile_id:
		CLAW_STANDARD_ID:
			return _build_standard_claw()
		CLAW_LOOSE_ID:
			return _build_loose_claw()
		CLAW_SNAP_ID:
			return _build_snap_claw()
	return _build_standard_claw()


static func _build_standard_claw() -> ClawProfileDefinition:
	var p := ClawProfileDefinition.new()
	p.id = CLAW_STANDARD_ID
	p.display_name = "Standard rigged (3-prong)"
	p.payout_probability = 0.33
	p.grip_torque_strong = 18.0
	p.grip_torque_weak = 2.5
	p.weak_grip_delay = 0.3
	p.grab_close_duration = 1.05
	p.hoist_drop_speed = 1.5
	p.hoist_ascend_speed = 1.4
	return p


static func _build_loose_claw() -> ClawProfileDefinition:
	var p := ClawProfileDefinition.new()
	p.id = CLAW_LOOSE_ID
	p.display_name = "Loose arcade (forgiving)"
	p.payout_probability = 0.62
	p.grip_torque_strong = 14.0
	p.grip_torque_weak = 6.0
	p.weak_grip_delay = 0.85
	p.grab_close_duration = 1.2
	p.prong_close_speed = 1.8
	p.hoist_ascend_speed = 1.2
	return p


static func _build_snap_claw() -> ClawProfileDefinition:
	var p := ClawProfileDefinition.new()
	p.id = CLAW_SNAP_ID
	p.display_name = "Snap grip (fast, harsh)"
	p.payout_probability = 0.22
	p.grip_torque_strong = 22.0
	p.grip_torque_weak = 1.5
	p.weak_grip_delay = 0.15
	p.grab_close_duration = 0.65
	p.prong_close_speed = 3.5
	p.prong_open_speed = 2.8
	p.hoist_drop_speed = 2.0
	p.max_drop_seconds = 2.5
	return p


static func create_starter_pack() -> PackDefinition:
	var pack := PackDefinition.new()
	pack.id = STARTER_PACK_ID
	pack.display_name = "Starter Capsules"

	var palette: Array[Color] = [
		Color(0.95, 0.45, 0.55),
		Color(0.55, 0.75, 0.95),
		Color(0.65, 0.9, 0.55),
		Color(0.95, 0.85, 0.45),
		Color(0.75, 0.55, 0.95),
		Color(0.5, 0.85, 0.85),
	]

	for i in palette.size():
		var prize := PrizeDefinition.new()
		prize.id = "capsule_%02d" % (i + 1)
		prize.pack_id = STARTER_PACK_ID
		prize.display_name = "Capsule %02d" % (i + 1)
		prize.physical_shape = PrizeDefinition.PhysicalShape.CAPSULE
		prize.rarity = PrizeDefinition.Rarity.COMMON if i < 4 else PrizeDefinition.Rarity.UNCOMMON
		prize.category = PrizeDefinition.PrizeCategory.COLLECTIBLE
		prize.albedo_color = palette[i]
		prize.mass = 0.4
		pack.prizes.append(prize)

	return pack


static func create_plush_pack() -> PackDefinition:
	var pack := PackDefinition.new()
	pack.id = PLUSH_PACK_ID
	pack.display_name = "Soft Plush Capsules"

	var colors: Array[Color] = [
		Color(0.98, 0.72, 0.78),
		Color(0.72, 0.86, 0.98),
		Color(0.88, 0.78, 0.98),
	]

	for i in colors.size():
		var prize := PrizeDefinition.new()
		prize.id = "plush_%02d" % (i + 1)
		prize.pack_id = PLUSH_PACK_ID
		prize.display_name = "Plush %02d" % (i + 1)
		prize.physical_shape = PrizeDefinition.PhysicalShape.CAPSULE
		prize.mass = 0.55
		prize.albedo_color = colors[i]
		pack.prizes.append(prize)

	return pack


static func create_starter_machine() -> CraneMachineDefinition:
	return _machine(
		STARTER_MACHINE_ID,
		"Neon Corner Claw",
		CLAW_STANDARD_ID,
		[STARTER_PACK_ID],
		1,
	)

static func create_loose_machine() -> CraneMachineDefinition:
	return _machine(
		LOOSE_MACHINE_ID,
		"Soft Plush Loft",
		CLAW_LOOSE_ID,
		[PLUSH_PACK_ID],
		2,
	)


static func create_speed_machine() -> CraneMachineDefinition:
	return _machine(
		SPEED_MACHINE_ID,
		"Speed Pit",
		CLAW_SNAP_ID,
		[STARTER_PACK_ID],
		1,
	)


static func _machine(
	machine_id: String,
	display_name: String,
	claw_id: String,
	packs: Array[String],
	play_cost: int,
) -> CraneMachineDefinition:
	var machine := CraneMachineDefinition.new()
	machine.id = machine_id
	machine.display_name = display_name
	machine.scene_path = "res://main.tscn"
	machine.claw_profile_id = claw_id
	machine.pack_ids = packs
	machine.play_cost = play_cost
	return machine


static func get_machine(machine_id: String) -> CraneMachineDefinition:
	match machine_id:
		STARTER_MACHINE_ID:
			return create_starter_machine()
		LOOSE_MACHINE_ID:
			return create_loose_machine()
		SPEED_MACHINE_ID:
			return create_speed_machine()
	return null


static func get_all_machine_ids() -> Array[String]:
	return [STARTER_MACHINE_ID, LOOSE_MACHINE_ID, SPEED_MACHINE_ID]


static func get_pack(pack_id: String) -> PackDefinition:
	match pack_id:
		STARTER_PACK_ID:
			return create_starter_pack()
		PLUSH_PACK_ID:
			return create_plush_pack()
	return null
