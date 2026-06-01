extends Node

var _save: UserSaveData
var _dirty := false
var _persist_pending := false


func _ready() -> void:
	_save = UserSaveData.load_or_create()
	_migrate_legacy_save()
	_process_login_bonus()
	_reset_daily_quests_if_needed()
	GameEvents.user_data_loaded.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_flush_persist()


func get_save() -> UserSaveData:
	return _save


func is_claw_landing_indicator_enabled() -> bool:
	return _save.claw_landing_indicator_enabled


func set_claw_landing_indicator_enabled(enabled: bool) -> void:
	if _save.claw_landing_indicator_enabled == enabled:
		return
	_save.claw_landing_indicator_enabled = enabled
	GameEvents.claw_landing_indicator_changed.emit(enabled)
	_mark_dirty()


# --- Packs ---

func get_active_pack() -> PackDefinition:
	return PrizeCatalog.get_pack(_save.active_pack_id)


func set_active_pack(pack_id: String) -> void:
	if pack_id in _save.owned_pack_ids:
		_save.active_pack_id = pack_id
		_mark_dirty()


func get_active_machine() -> CraneMachineDefinition:
	var pack := get_active_pack()
	if pack == null:
		return StarterContent.get_machine(StarterContent.STARTER_MACHINE_ID)
	return pack.get_machine()


func get_claw_profile() -> ClawProfileDefinition:
	var machine := get_active_machine()
	if machine == null:
		return StarterContent.get_claw_profile(StarterContent.CLAW_STANDARD_ID)
	return StarterContent.get_claw_profile(machine.claw_profile_id)


func get_pack(pack_id: String) -> PackDefinition:
	return PrizeCatalog.get_pack(pack_id)


func get_prize(prize_id: String) -> PrizeDefinition:
	return PrizeCatalog.get_prize(prize_id)


func get_container(container_id: String) -> ContainerDefinition:
	return PrizeCatalog.get_container(container_id)


func purchase_pack(pack_id: String) -> bool:
	var entry := StoreCatalog.get_store_pack_entry(pack_id)
	if entry.is_empty():
		return false
	if pack_id in _save.owned_pack_ids:
		return false
	var price := int(entry.get("price_coins", 0))
	if not spend_coins(price):
		return false
	_save.owned_pack_ids.append(pack_id)
	_save._ensure_pack_stats(pack_id)
	GameEvents.pack_purchased.emit(pack_id)
	_mark_dirty()
	return true


# --- Pack stats ---

func get_pack_plays(pack_id: String) -> int:
	_save._ensure_pack_stats(pack_id)
	return int(_save.pack_stats[pack_id].get("plays", 0))


func get_prizes_earned(pack_id: String) -> int:
	_save._ensure_pack_stats(pack_id)
	return int(_save.pack_stats[pack_id].prizes_earned)


func get_prizes_remaining(pack_id: String) -> int:
	_save._ensure_pack_stats(pack_id)
	return int(_save.pack_stats[pack_id].prizes_remaining)


func record_pack_container_won(pack_id: String, container: ContainerDefinition) -> void:
	if container == null:
		return
	record_pack_prize_won(pack_id, container.get_prize())


func record_pack_prize_won(pack_id: String, prize: PrizeDefinition) -> void:
	if prize == null:
		return
	_save._ensure_pack_stats(pack_id)
	var stats: Dictionary = _save.pack_stats[pack_id]
	stats.prizes_earned = int(stats.prizes_earned) + 1
	stats.prizes_remaining = maxi(int(stats.prizes_remaining) - 1, 0)
	GameEvents.pack_prize_won.emit(pack_id, prize, stats.prizes_earned, stats.prizes_remaining)
	GameEvents.machine_prize_won.emit(pack_id, prize, stats.prizes_earned, stats.prizes_remaining)
	if not _save.first_win_today:
		_save.first_win_today = true
		add_coins(3)
	_mark_dirty()


func refill_pack_for_coins(pack_id: String, cost: int = 50) -> bool:
	if not spend_coins(cost):
		return false
	refill_pack_stock(pack_id)
	return true


func refill_pack_stock(pack_id: String) -> void:
	_save._ensure_pack_stats(pack_id)
	var pack := get_pack(pack_id)
	if pack == null:
		return
	var machine := pack.get_machine()
	if machine == null:
		return
	_save.pack_stats[pack_id].prizes_remaining = machine.initial_prize_stock
	_mark_dirty()


# --- Unopened ---

func add_unopened(container: ContainerDefinition, pack_id: String) -> UnopenedItem:
	if container == null:
		return null
	var item := UnopenedItem.create(container.id, pack_id)
	_save.unopened_queue.append(item)
	GameEvents.unopened_added.emit(item)
	_mark_dirty()
	return item


func get_unopened_items() -> Array[UnopenedItem]:
	return _save.unopened_queue


func get_unopened_count() -> int:
	return _save.unopened_queue.size()


func reveal_unopened(instance_id: String) -> bool:
	for i in _save.unopened_queue.size():
		var item: UnopenedItem = _save.unopened_queue[i]
		if item.instance_id != instance_id:
			continue
		var container := get_container(item.container_id)
		if container == null:
			return false
		var prize := container.get_prize()
		_save.unopened_queue.remove_at(i)
		add_container_to_storage(container, 1)
		if prize:
			if prize.container_id.is_empty():
				prize.container_id = container.id
			add_prize(prize, 1, false)
		GameEvents.unopened_revealed.emit(item, container, prize)
		_advance_daily_quest("unbox_one")
		_mark_dirty()
		return true
	return false


# --- Inventory ---

func get_owned_container_count(container_id: String) -> int:
	return int(_save.container_inventory.get(container_id, 0))


func add_container_to_storage(container: ContainerDefinition, amount: int = 1) -> void:
	if container == null or container.id.is_empty() or amount <= 0:
		return
	_save.container_inventory[container.id] = get_owned_container_count(container.id) + amount
	_save.total_containers_earned += amount
	GameEvents.container_storage_changed.emit(container, get_container_storage_stats())
	_mark_dirty()


func get_container_storage_stats() -> Dictionary:
	var stats := {"total": 0, "common": 0, "rare": 0, "super_rare": 0}
	for container_id in _save.container_inventory.keys():
		var count := get_owned_container_count(container_id)
		if count <= 0:
			continue
		var container := get_container(container_id)
		if container == null:
			continue
		stats.total += count
		var key: String = ContainerDefinition.rarity_stat_key(container.rarity)
		stats[key] = int(stats.get(key, 0)) + count
	return stats


func get_owned_container_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for container_id in _save.container_inventory.keys():
		var container := get_container(container_id)
		if container == null:
			continue
		entries.append({
			"container": container,
			"owned_count": get_owned_container_count(container_id),
			"placed_count": get_placed_container_count(container_id),
			"available_count": get_available_container_count(container_id),
			"prize": container.get_prize(),
		})
	return entries


func get_owned_count(prize_id: String) -> int:
	return int(_save.prize_inventory.get(prize_id, 0))


func get_owned_prize_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for prize_id in _save.prize_inventory.keys():
		var prize := get_prize(prize_id)
		if prize == null:
			continue
		entries.append({
			"prize": prize,
			"owned_count": get_owned_count(prize_id),
			"placed_count": get_placed_prize_count(prize_id),
			"available_count": get_available_prize_count(prize_id),
		})
	return entries


func get_placed_prize_count(prize_id: String) -> int:
	return _count_placements(DisplayPlacement.Kind.PRIZE, prize_id)


func get_placed_container_count(container_id: String) -> int:
	return _count_placements(DisplayPlacement.Kind.CONTAINER, container_id)


func get_available_prize_count(prize_id: String) -> int:
	return maxi(get_owned_count(prize_id) - get_placed_prize_count(prize_id), 0)


func get_available_container_count(container_id: String) -> int:
	return maxi(get_owned_container_count(container_id) - get_placed_container_count(container_id), 0)


func add_prize(prize: PrizeDefinition, amount: int = 1, count_lifetime: bool = true) -> void:
	if prize == null or prize.id.is_empty() or amount <= 0:
		return
	_save.prize_inventory[prize.id] = get_owned_count(prize.id) + amount
	if count_lifetime:
		_save.total_prizes_earned += amount
	GameEvents.prize_collected.emit(prize, get_owned_count(prize.id))
	_mark_dirty()


func recycle_prize(prize_id: String, amount: int = 1) -> bool:
	if amount <= 0 or get_available_prize_count(prize_id) < amount:
		return false
	var prize := get_prize(prize_id)
	if prize == null:
		return false
	var remaining := get_owned_count(prize_id) - amount
	if remaining <= 0:
		_save.prize_inventory.erase(prize_id)
	else:
		_save.prize_inventory[prize_id] = remaining
	_save.recycle_tokens += amount * maxi(prize.recycle_value, 1)
	GameEvents.prize_recycled.emit(prize_id, amount)
	_mark_dirty()
	return true


# --- Display rooms ---

func get_display_rooms() -> Array[DisplayRoomInstance]:
	return _save.display_rooms


func get_active_display_room() -> DisplayRoomInstance:
	if _save.display_rooms.is_empty():
		return null
	var idx := clampi(_save.active_display_room_index, 0, _save.display_rooms.size() - 1)
	return _save.display_rooms[idx]


func set_active_display_room_index(index: int) -> void:
	if _save.display_rooms.is_empty():
		return
	_save.active_display_room_index = posmod(index, _save.display_rooms.size())
	GameEvents.display_room_changed.emit(get_active_display_room())
	_mark_dirty()


func cycle_display_room(delta: int) -> void:
	set_active_display_room_index(_save.active_display_room_index + delta)


func get_placements_for_active_room() -> Array[DisplayPlacement]:
	var room := get_active_display_room()
	if room == null:
		return []
	return room.placements


func place_prize(prize_id: String, position: Vector2, room_id: String = "") -> DisplayPlacement:
	if get_available_prize_count(prize_id) <= 0:
		return null
	var room := _get_room_by_id(room_id)
	if room == null:
		return null
	var placement := DisplayPlacement.create_prize(prize_id, position)
	placement.z_index = _next_placement_z_index(room)
	room.placements.append(placement)
	GameEvents.display_sticker_placed.emit(placement)
	_mark_dirty()
	return placement


func place_container(container_id: String, position: Vector2, room_id: String = "") -> DisplayPlacement:
	if get_available_container_count(container_id) <= 0:
		return null
	var room := _get_room_by_id(room_id)
	if room == null:
		return null
	var placement := DisplayPlacement.create_container(container_id, position)
	placement.z_index = _next_placement_z_index(room)
	room.placements.append(placement)
	GameEvents.display_sticker_placed.emit(placement)
	_mark_dirty()
	return placement


func remove_sticker(instance_id: String, room_id: String = "") -> void:
	var room := _get_room_by_id(room_id)
	if room == null:
		return
	for i in room.placements.size():
		if room.placements[i].instance_id == instance_id:
			room.placements.remove_at(i)
			GameEvents.display_sticker_removed.emit(instance_id)
			_mark_dirty()
			return


func update_sticker_transform(
	instance_id: String,
	position: Vector2,
	rotation_degrees: float,
	scale: float,
	flip_h: bool = false,
	flip_v: bool = false,
	room_id: String = "",
) -> void:
	var room := _get_room_by_id(room_id)
	if room == null:
		return
	for placement in room.placements:
		if placement.instance_id != instance_id:
			continue
		placement.position = position
		placement.rotation_degrees = rotation_degrees
		placement.scale = scale
		placement.flip_h = flip_h
		placement.flip_v = flip_v
		GameEvents.display_sticker_moved.emit(placement)
		_mark_dirty()
		return


func reorder_sticker_layer(instance_id: String, delta: int, room_id: String = "") -> void:
	if delta == 0:
		return
	var room := _get_room_by_id(room_id)
	if room == null or room.placements.size() < 2:
		return
	var target: DisplayPlacement = null
	for placement in room.placements:
		if placement.instance_id == instance_id:
			target = placement
			break
	if target == null or target.locked:
		return
	var sorted: Array[DisplayPlacement] = room.placements.duplicate()
	sorted.sort_custom(func(a: DisplayPlacement, b: DisplayPlacement) -> bool:
		if a.z_index != b.z_index:
			return a.z_index < b.z_index
		return a.instance_id < b.instance_id
	)
	var idx := -1
	for i in sorted.size():
		if sorted[i].instance_id == instance_id:
			idx = i
			break
	if idx < 0:
		return
	var new_idx := clampi(idx + delta, 0, sorted.size() - 1)
	if new_idx == idx:
		return
	var swapped := sorted[idx]
	sorted[idx] = sorted[new_idx]
	sorted[new_idx] = swapped
	for i in sorted.size():
		sorted[i].z_index = i
	GameEvents.display_sticker_moved.emit(target)
	_mark_dirty()


func _next_placement_z_index(room: DisplayRoomInstance) -> int:
	var next_z := 0
	for placement in room.placements:
		next_z = maxi(next_z, placement.z_index + 1)
	return next_z


# --- Coins ---

func get_coins() -> int:
	return _save.coins


func add_coins(amount: int, count_daily: bool = true) -> void:
	if amount <= 0:
		return
	_save.coins += amount
	if count_daily:
		_save.coins_earned_today += amount
		_advance_daily_quest("earn_coins", amount)
	GameEvents.coins_changed.emit(_save.coins)
	_mark_dirty()


func spend_coins(amount: int) -> bool:
	if amount <= 0:
		return true
	if _save.coins < amount:
		return false
	_save.coins -= amount
	GameEvents.coins_changed.emit(_save.coins)
	_mark_dirty()
	return true


func can_play(pack: PackDefinition = null) -> bool:
	if pack == null:
		pack = get_active_pack()
	if pack == null:
		return false
	var machine := pack.get_machine()
	if machine == null:
		return false
	return get_coins() >= machine.play_cost


func consume_play(pack: PackDefinition = null) -> bool:
	if pack == null:
		pack = get_active_pack()
	if pack == null or not can_play(pack):
		GameEvents.play_denied.emit(pack.id if pack else "", "not_enough_coins")
		return false
	var machine := pack.get_machine()
	if machine == null:
		return false
	spend_coins(machine.play_cost)
	_save.total_crane_plays += 1
	_save._ensure_pack_stats(pack.id)
	_save.pack_stats[pack.id].plays = get_pack_plays(pack.id) + 1
	GameEvents.play_consumed.emit(pack.id, _save.coins)
	GameEvents.crane_play_recorded.emit(pack.id, _save.total_crane_plays)
	_advance_daily_quest("play_once")
	_persist()
	return true


# --- Upgrades ---

func get_upgrade_level(upgrade_id: String) -> int:
	return int(_save.upgrade_levels.get(upgrade_id, 0))


func purchase_upgrade(upgrade_id: String) -> bool:
	var upgrade := StoreCatalog.get_upgrade(upgrade_id)
	if upgrade == null:
		return false
	var level := get_upgrade_level(upgrade_id)
	if level >= upgrade.max_level:
		return false
	var cost := upgrade.get_cost_at_level(level)
	if not spend_coins(cost):
		return false
	_save.upgrade_levels[upgrade_id] = level + 1
	GameEvents.upgrade_purchased.emit(upgrade_id)
	_mark_dirty()
	return true


# --- Collections ---

func get_collection_progress(collection_id: String) -> Dictionary:
	var collection := StoreCatalog.get_collection(collection_id)
	if collection == null:
		return {"filled": 0, "total": 0, "slots": []}
	var slots_filled: Array[bool] = []
	var owned_pool: Dictionary = {}
	for prize_id in _save.prize_inventory.keys():
		owned_pool[str(prize_id)] = int(_save.prize_inventory[prize_id])
	var filled := 0
	for prize_id in collection.slot_prize_ids:
		var available := int(owned_pool.get(prize_id, 0))
		if available > 0:
			owned_pool[prize_id] = available - 1
			slots_filled.append(true)
			filled += 1
		else:
			slots_filled.append(false)
	return {
		"filled": filled,
		"total": collection.slot_prize_ids.size(),
		"slots": slots_filled,
		"collection": collection,
	}


func is_collection_complete(collection_id: String) -> bool:
	var p := get_collection_progress(collection_id)
	return p.filled >= p.total and p.total > 0


func claim_collection_reward(collection_id: String) -> bool:
	if collection_id in _save.completed_collections:
		return false
	if not is_collection_complete(collection_id):
		return false
	var collection := StoreCatalog.get_collection(collection_id)
	if collection == null:
		return false
	_save.completed_collections.append(collection_id)
	add_coins(collection.reward_coins)
	GameEvents.collection_claimed.emit(collection_id)
	_mark_dirty()
	return true


func get_nearest_collection_progress() -> Dictionary:
	var best: Dictionary = {"filled": 0, "total": 0, "collection": null}
	for collection: CollectionDefinition in StoreCatalog.get_all_collections():
		if collection.id in _save.completed_collections:
			continue
		var p := get_collection_progress(collection.id)
		if p.total <= 0:
			continue
		if p.filled > best.filled or best.collection == null:
			best = p
	return best


func get_pack_completion_percent(pack_id: String) -> float:
	var pack := get_pack(pack_id)
	if pack == null:
		return 0.0
	var prizes := pack.get_containing_prizes()
	if prizes.is_empty():
		return 0.0
	var owned := 0
	for prize in prizes:
		if get_owned_count(prize.id) > 0:
			owned += 1
	return float(owned) / float(prizes.size()) * 100.0


# --- Daily quests ---

func get_daily_quest_progress() -> Dictionary:
	return {
		"day": _save.daily_quest_day,
		"progress": _save.daily_quest_progress.duplicate(),
		"claimed": _save.daily_quests_claimed.duplicate(),
	}


func claim_daily_quest(quest_id: String) -> bool:
	if quest_id in _save.daily_quests_claimed:
		return false
	for def in StoreCatalog.get_daily_quest_defs():
		if def is Dictionary and str(def.get("id", "")) == quest_id:
			var target := int(def.get("target", 1))
			if int(_save.daily_quest_progress.get(quest_id, 0)) < target:
				return false
			_save.daily_quests_claimed.append(quest_id)
			add_coins(int(def.get("reward_coins", 0)))
			GameEvents.daily_quest_claimed.emit(quest_id)
			_mark_dirty()
			return true
	return false


func get_daily_quests_completed_count() -> int:
	return _save.daily_quests_claimed.size()


# --- Getters for compatibility ---

var owned_pack_ids: Array[String]:
	get:
		return _save.owned_pack_ids

var active_pack_id: String:
	get:
		return _save.active_pack_id

var inventory: Dictionary:
	get:
		return _save.prize_inventory

var display_placements: Array[DisplayPlacement]:
	get:
		return get_placements_for_active_room()


func get_total_crane_plays() -> int:
	return _save.total_crane_plays


func get_total_containers_earned() -> int:
	return _save.total_containers_earned


func get_total_prizes_earned() -> int:
	return _save.total_prizes_earned


func get_machine_plays(_machine_id: String) -> int:
	return get_pack_plays(_save.active_pack_id)


func get_containing_prizes(pack_id: String) -> Array[PrizeDefinition]:
	var pack := get_pack(pack_id)
	if pack == null:
		return []
	return pack.get_containing_prizes()


func defer_persist() -> void:
	_persist_pending = true
	_dirty = true


func flush_persist() -> void:
	_flush_persist()


func _get_room_by_id(room_id: String) -> DisplayRoomInstance:
	if room_id.is_empty():
		return get_active_display_room()
	for room in _save.display_rooms:
		if room.room_id == room_id:
			return room
	return null


func _count_placements(kind: DisplayPlacement.Kind, item_id: String) -> int:
	var count := 0
	for room in _save.display_rooms:
		for placement in room.placements:
			if placement.kind != kind:
				continue
			if kind == DisplayPlacement.Kind.CONTAINER and placement.container_id == item_id:
				count += 1
			elif kind == DisplayPlacement.Kind.PRIZE and placement.prize_id == item_id:
				count += 1
	return count


func _advance_daily_quest(quest_id: String, amount: int = 1) -> void:
	_reset_daily_quests_if_needed()
	var current := int(_save.daily_quest_progress.get(quest_id, 0))
	_save.daily_quest_progress[quest_id] = current + amount
	GameEvents.daily_quest_progress.emit(quest_id, current + amount)


func _reset_daily_quests_if_needed() -> void:
	var today := Time.get_date_string_from_system()
	if _save.daily_quest_day == today:
		return
	_save.daily_quest_day = today
	_save.daily_quest_progress = {}
	_save.daily_quests_claimed = []
	_save.first_win_today = false
	_save.coins_earned_today = 0


func _process_login_bonus() -> void:
	var today := Time.get_date_string_from_system()
	if _save.last_login_day == today:
		return
	_save.last_login_day = today
	_save.login_streak += 1
	add_coins(2)
	if _save.login_streak % 7 == 0:
		add_coins(8)
	_save.login_streak = _save.login_streak % 7
	_mark_dirty()


func _migrate_legacy_save() -> void:
	var migrated := false

	if _save.version < 6:
		if _save.owned_pack_ids.is_empty():
			_save.owned_pack_ids = [StarterContent.STARTER_PACK_ID]
			migrated = true
		if _save.active_pack_id.is_empty() or _save.active_pack_id == StarterContent.STARTER_MACHINE_ID:
			_save.active_pack_id = StarterContent.STARTER_PACK_ID
			migrated = true
		if _save.active_pack_id == "starter_capsules":
			_save.active_pack_id = StarterContent.STARTER_PACK_ID
			migrated = true

		if _save.pack_stats.is_empty() and _save.version >= 1:
			var legacy_stats: Variant = _save.pack_stats
			if legacy_stats is Dictionary:
				for key in legacy_stats.keys():
					var mapped := StarterContent.STARTER_PACK_ID if str(key) == StarterContent.STARTER_MACHINE_ID else str(key)
					_save.pack_stats[mapped] = legacy_stats[key]
					migrated = true

		if _save.display_rooms.size() < 2:
			while _save.display_rooms.size() < 2:
				var n := _save.display_rooms.size() + 1
				_save.display_rooms.append(DisplayRoomInstance.create("room_%d" % n, "Room %d" % n))
			migrated = true

	for default_pack_id in StarterContent.DEFAULT_OWNED_PACK_IDS:
		if default_pack_id not in _save.owned_pack_ids:
			_save.owned_pack_ids.append(default_pack_id)
			_save._ensure_pack_stats(default_pack_id)
			migrated = true

	for container_id in _save.container_inventory.keys().duplicate():
		if get_container(str(container_id)) == null:
			_save.container_inventory.erase(container_id)
			migrated = true

	for prize_id in _save.prize_inventory.keys().duplicate():
		if get_prize(str(prize_id)) == null:
			_save.prize_inventory.erase(prize_id)
			migrated = true

	if migrated or _save.version < UserSaveData.CURRENT_VERSION:
		_save.version = UserSaveData.CURRENT_VERSION
		_persist()


func _mark_dirty() -> void:
	_dirty = true
	GameEvents.user_data_changed.emit()
	if not _persist_pending:
		_persist()


func _flush_persist() -> void:
	if _dirty:
		_persist()
		_persist_pending = false


func _persist() -> void:
	if _save.persist():
		GameEvents.user_data_saved.emit()
		_dirty = false
