extends Node

const STORE_CATALOG_PATH := "res://resources/store/store_catalog.json"

var _income_config: Dictionary = {}
var _upgrades: Dictionary = {}
var _store_packs: Array = []
var _collections: Dictionary = {}
var _daily_quest_defs: Array = []


func _ready() -> void:
	_load()


func get_income_config() -> Dictionary:
	return _income_config.duplicate()


func get_upgrade(upgrade_id: String) -> UpgradeDefinition:
	return _upgrades.get(upgrade_id)


func get_all_upgrades() -> Array[UpgradeDefinition]:
	var result: Array[UpgradeDefinition] = []
	for u: UpgradeDefinition in _upgrades.values():
		result.append(u)
	return result


func get_store_packs() -> Array:
	return _store_packs.duplicate()


func get_store_pack_entry(pack_id: String) -> Dictionary:
	for entry in _store_packs:
		if entry is Dictionary and str(entry.get("pack_id", "")) == pack_id:
			return entry
	return {}


func get_collection(collection_id: String) -> CollectionDefinition:
	return _collections.get(collection_id)


func get_all_collections() -> Array[CollectionDefinition]:
	var result: Array[CollectionDefinition] = []
	for c: CollectionDefinition in _collections.values():
		result.append(c)
	return result


func get_daily_quest_defs() -> Array:
	return _daily_quest_defs.duplicate()


func _load() -> void:
	if not FileAccess.file_exists(STORE_CATALOG_PATH):
		return
	var file := FileAccess.open(STORE_CATALOG_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed == null or not parsed is Dictionary:
		return
	var data: Dictionary = parsed
	_income_config = data.get("income", {})
	_store_packs = data.get("store_packs", [])
	_daily_quest_defs = data.get("daily_quests", [])

	for entry in data.get("upgrades", []):
		if not entry is Dictionary:
			continue
		var upgrade := _upgrade_from_dict(entry)
		if upgrade:
			_upgrades[upgrade.id] = upgrade

	for entry in data.get("collections", []):
		if not entry is Dictionary:
			continue
		var collection := _collection_from_dict(entry)
		if collection:
			_collections[collection.id] = collection


func _upgrade_from_dict(data: Dictionary) -> UpgradeDefinition:
	var uid := str(data.get("id", ""))
	if uid.is_empty():
		return null
	var u := UpgradeDefinition.new()
	u.id = uid
	u.display_name = str(data.get("display_name", uid))
	u.description = str(data.get("description", ""))
	u.effect_type = UpgradeDefinition.effect_type_from_string(str(data.get("effect_type", "")))
	u.base_cost = int(data.get("base_cost", 10))
	u.cost_growth = float(data.get("cost_growth", 1.15))
	u.effect_per_level = float(data.get("effect_per_level", 1.0))
	u.max_level = int(data.get("max_level", 100))
	return u


func _collection_from_dict(data: Dictionary) -> CollectionDefinition:
	var cid := str(data.get("id", ""))
	if cid.is_empty():
		return null
	var c := CollectionDefinition.new()
	c.id = cid
	c.display_name = str(data.get("display_name", cid))
	c.reward_coins = int(data.get("reward_coins", 0))
	for slot in data.get("slots", []):
		if slot is Dictionary:
			c.slot_prize_ids.append(str(slot.get("prize_id", "")))
	return c
