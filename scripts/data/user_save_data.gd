class_name UserSaveData
extends RefCounted

const CURRENT_VERSION := 7
const SAVE_PATH := "user://save.json"

var version: int = CURRENT_VERSION
var coins: int = 20
var last_income_tick_unix: int = 0
var upgrade_levels: Dictionary = {}
var completed_collections: Array[String] = []
var owned_pack_ids: Array[String] = StarterContent.DEFAULT_OWNED_PACK_IDS.duplicate()
var active_pack_id: String = StarterContent.STARTER_PACK_ID
var unopened_queue: Array[UnopenedItem] = []
var prize_inventory: Dictionary = {}
var container_inventory: Dictionary = {}
var display_rooms: Array[DisplayRoomInstance] = []
var active_display_room_index: int = 0
var pack_stats: Dictionary = {}

var total_crane_plays: int = 0
var total_containers_earned: int = 0
var total_prizes_earned: int = 0

var daily_quest_day: String = ""
var daily_quest_progress: Dictionary = {}
var daily_quests_claimed: Array[String] = []
var login_streak: int = 0
var last_login_day: String = ""
var first_win_today: bool = false
var recycle_tokens: int = 0
var coins_earned_today: int = 0
var claw_landing_indicator_enabled: bool = true


static func load_or_create() -> UserSaveData:
	if not FileAccess.file_exists(SAVE_PATH):
		return create_new()
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return create_new()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed == null or not parsed is Dictionary:
		return create_new()
	return from_dict(parsed)


static func create_new() -> UserSaveData:
	var data := UserSaveData.new()
	data.display_rooms = [
		DisplayRoomInstance.create("room_1", "Room 1"),
		DisplayRoomInstance.create("room_2", "Room 2"),
	]
	data._init_pack_stats()
	data.last_income_tick_unix = int(Time.get_unix_time_from_system())
	return data


func to_dict() -> Dictionary:
	var rooms: Array = []
	for room in display_rooms:
		var placements: Array = []
		for placement in room.placements:
			placements.append(_placement_to_dict(placement))
		rooms.append({
			"room_id": room.room_id,
			"display_name": room.display_name,
			"placements": placements,
		})

	var unopened: Array = []
	for item in unopened_queue:
		unopened.append({
			"instance_id": item.instance_id,
			"container_id": item.container_id,
			"pack_id": item.pack_id,
			"won_at": item.won_at,
		})

	return {
		"version": version,
		"coins": coins,
		"last_income_tick_unix": last_income_tick_unix,
		"upgrade_levels": upgrade_levels.duplicate(),
		"completed_collections": completed_collections.duplicate(),
		"owned_pack_ids": owned_pack_ids.duplicate(),
		"active_pack_id": active_pack_id,
		"unopened_queue": unopened,
		"prize_inventory": prize_inventory.duplicate(),
		"container_inventory": container_inventory.duplicate(),
		"display_rooms": rooms,
		"active_display_room_index": active_display_room_index,
		"pack_stats": pack_stats.duplicate(true),
		"total_crane_plays": total_crane_plays,
		"total_containers_earned": total_containers_earned,
		"total_prizes_earned": total_prizes_earned,
		"daily_quest_day": daily_quest_day,
		"daily_quest_progress": daily_quest_progress.duplicate(),
		"daily_quests_claimed": daily_quests_claimed.duplicate(),
		"login_streak": login_streak,
		"last_login_day": last_login_day,
		"first_win_today": first_win_today,
		"recycle_tokens": recycle_tokens,
		"coins_earned_today": coins_earned_today,
		"claw_landing_indicator_enabled": claw_landing_indicator_enabled,
	}


static func from_dict(data: Dictionary) -> UserSaveData:
	var save := UserSaveData.new()
	save.version = int(data.get("version", 1))
	save.coins = int(data.get("coins", 20))
	if save.version < CURRENT_VERSION:
		var legacy_coins: Variant = data.get("coins_by_currency", {})
		if legacy_coins is Dictionary and legacy_coins.has("default"):
			save.coins = int(legacy_coins["default"])
	save.last_income_tick_unix = int(data.get("last_income_tick_unix", 0))
	save.upgrade_levels = _string_int_dict(data.get("upgrade_levels", {}))
	save.completed_collections = _string_array(data.get("completed_collections", []))
	save.owned_pack_ids = _string_array(data.get("owned_pack_ids", []))
	if save.owned_pack_ids.is_empty():
		var legacy_machines := _string_array(data.get("owned_machine_ids", [StarterContent.STARTER_PACK_ID]))
		for mid in legacy_machines:
			if mid == StarterContent.STARTER_MACHINE_ID or mid == "starter_capsules":
				save.owned_pack_ids.append(StarterContent.STARTER_PACK_ID)
			else:
				save.owned_pack_ids.append(mid)
	if save.owned_pack_ids.is_empty():
		save.owned_pack_ids = StarterContent.DEFAULT_OWNED_PACK_IDS.duplicate()
	save.active_pack_id = str(data.get("active_pack_id", data.get("active_machine_id", StarterContent.STARTER_PACK_ID)))
	if save.active_pack_id == StarterContent.STARTER_MACHINE_ID or save.active_pack_id == "starter_capsules":
		save.active_pack_id = StarterContent.STARTER_PACK_ID
	save.prize_inventory = _string_int_dict(data.get("prize_inventory", {}))
	var containers: Variant = data.get("container_inventory", data.get("capsule_inventory", {}))
	save.container_inventory = _string_int_dict(containers)
	save.active_display_room_index = int(data.get("active_display_room_index", 0))
	save.pack_stats = data.get("pack_stats", data.get("machine_stats", {}))
	if save.pack_stats.has(StarterContent.STARTER_MACHINE_ID):
		save.pack_stats[StarterContent.STARTER_PACK_ID] = save.pack_stats[StarterContent.STARTER_MACHINE_ID]
		save.pack_stats.erase(StarterContent.STARTER_MACHINE_ID)
	save.total_crane_plays = int(data.get("total_crane_plays", 0))
	save.total_containers_earned = int(data.get("total_containers_earned", data.get("total_capsules_earned", 0)))
	save.total_prizes_earned = int(data.get("total_prizes_earned", 0))
	save.daily_quest_day = str(data.get("daily_quest_day", ""))
	save.daily_quest_progress = data.get("daily_quest_progress", {})
	save.daily_quests_claimed = _string_array(data.get("daily_quests_claimed", []))
	save.login_streak = int(data.get("login_streak", 0))
	save.last_login_day = str(data.get("last_login_day", ""))
	save.first_win_today = bool(data.get("first_win_today", false))
	save.recycle_tokens = int(data.get("recycle_tokens", 0))
	save.coins_earned_today = int(data.get("coins_earned_today", 0))
	save.claw_landing_indicator_enabled = bool(data.get("claw_landing_indicator_enabled", true))

	save.unopened_queue = _unopened_from_array(data.get("unopened_queue", []))

	if data.has("display_rooms"):
		save.display_rooms = _rooms_from_array(data.get("display_rooms", []))
	else:
		save.display_rooms = [
			DisplayRoomInstance.create("room_1", "Room 1"),
			DisplayRoomInstance.create("room_2", "Room 2"),
		]
		var legacy_placements := _placements_from_array(data.get("display_placements", []))
		if not legacy_placements.is_empty() and save.display_rooms.size() > 0:
			save.display_rooms[0].placements = legacy_placements

	save._init_pack_stats()
	return save


func persist() -> bool:
	var json := JSON.stringify(to_dict(), "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(json)
	return true


func _init_pack_stats() -> void:
	for pack_id in owned_pack_ids:
		_ensure_pack_stats(pack_id)


func _ensure_pack_stats(pack_id: String) -> void:
	if pack_stats.has(pack_id):
		return
	var pack := PrizeCatalog.get_pack(pack_id)
	var stock := 24
	if pack:
		var machine := pack.get_machine()
		if machine:
			stock = machine.initial_prize_stock
	pack_stats[pack_id] = {
		"prizes_earned": 0,
		"prizes_remaining": stock,
		"plays": 0,
	}


static func _placement_to_dict(placement: DisplayPlacement) -> Dictionary:
	return {
		"instance_id": placement.instance_id,
		"kind": placement.kind,
		"prize_id": placement.prize_id,
		"container_id": placement.container_id,
		"position": {"x": placement.position.x, "y": placement.position.y},
		"rotation_degrees": placement.rotation_degrees,
		"scale": placement.scale,
		"flip_h": placement.flip_h,
		"flip_v": placement.flip_v,
		"z_index": placement.z_index,
		"locked": placement.locked,
	}


static func _string_int_dict(raw: Variant) -> Dictionary:
	var result: Dictionary = {}
	if raw is Dictionary:
		for key in raw.keys():
			result[str(key)] = int(raw[key])
	return result


static func _string_array(raw: Variant) -> Array[String]:
	var result: Array[String] = []
	if raw is Array:
		for item in raw:
			result.append(str(item))
	return result


static func _placements_from_array(raw: Variant) -> Array[DisplayPlacement]:
	var result: Array[DisplayPlacement] = []
	if not raw is Array:
		return result
	for entry in raw:
		if entry is Dictionary:
			result.append(_placement_from_dict(entry))
	return result


static func _placement_from_dict(entry: Dictionary) -> DisplayPlacement:
	var placement := DisplayPlacement.new()
	placement.instance_id = str(entry.get("instance_id", ""))
	placement.kind = int(entry.get("kind", DisplayPlacement.Kind.PRIZE))
	placement.prize_id = str(entry.get("prize_id", ""))
	placement.container_id = str(entry.get("container_id", ""))
	var pos: Variant = entry.get("position", {})
	if pos is Dictionary:
		placement.position = Vector2(float(pos.get("x", 0.0)), float(pos.get("y", 0.0)))
	placement.rotation_degrees = float(entry.get("rotation_degrees", 0.0))
	placement.scale = float(entry.get("scale", 1.0))
	placement.flip_h = bool(entry.get("flip_h", false))
	placement.flip_v = bool(entry.get("flip_v", false))
	placement.z_index = int(entry.get("z_index", 0))
	placement.locked = bool(entry.get("locked", false))
	return placement


static func _rooms_from_array(raw: Variant) -> Array[DisplayRoomInstance]:
	var result: Array[DisplayRoomInstance] = []
	if not raw is Array:
		return result
	for entry in raw:
		if not entry is Dictionary:
			continue
		var room := DisplayRoomInstance.create(
			str(entry.get("room_id", "")),
			str(entry.get("display_name", "Room")),
		)
		room.placements = _placements_from_array(entry.get("placements", []))
		result.append(room)
	return result


static func _unopened_from_array(raw: Variant) -> Array[UnopenedItem]:
	var result: Array[UnopenedItem] = []
	if not raw is Array:
		return result
	for entry in raw:
		if not entry is Dictionary:
			continue
		var item := UnopenedItem.new()
		item.instance_id = str(entry.get("instance_id", ""))
		item.container_id = str(entry.get("container_id", ""))
		item.pack_id = str(entry.get("pack_id", ""))
		item.won_at = int(entry.get("won_at", 0))
		result.append(item)
	return result
