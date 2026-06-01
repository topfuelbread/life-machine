extends Node

## Registry for prizes, containers, packs, and sticker art from prize_manifest.json.

const PRIZE_RESOURCE_DIR := "res://resources/prizes/"
const PRIZE_MANIFEST_PATH := "res://resources/prizes/prize_manifest.json"

var _prizes: Dictionary = {}
var _containers: Dictionary = {}
var _packs: Dictionary = {}
var _prize_to_container: Dictionary = {}
var _sticker_cache: Dictionary = {}


func _ready() -> void:
	_load_manifest()


func get_prize(prize_id: String) -> PrizeDefinition:
	return _prizes.get(prize_id)


func get_container(container_id: String) -> ContainerDefinition:
	return _containers.get(container_id)


func get_pack(pack_id: String) -> PackDefinition:
	return _packs.get(pack_id)


func get_all_pack_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in _packs.keys():
		ids.append(str(key))
	return ids


func get_all_prize_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in _prizes.keys():
		ids.append(str(key))
	return ids


func get_container_id_for_prize(prize_id: String) -> String:
	return str(_prize_to_container.get(prize_id, ""))


func get_sticker_texture(prize: PrizeDefinition) -> Texture2D:
	var data := get_sticker_data(prize)
	return data.get("texture")


func get_sticker_data(prize: PrizeDefinition) -> Dictionary:
	if prize == null:
		return {}
	if not prize.sprite_path.is_empty():
		return _load_sticker_data(prize.sprite_path, prize)
	return _fallback_sticker_data(prize)


func _load_manifest() -> void:
	if not FileAccess.file_exists(PRIZE_MANIFEST_PATH):
		push_warning("PrizeCatalog: missing prize_manifest.json")
		return
	var file := FileAccess.open(PRIZE_MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed == null or not parsed is Dictionary:
		push_warning("PrizeCatalog: invalid prize_manifest.json")
		return
	var data: Dictionary = parsed

	for entry in data.get("prizes", []):
		if entry is Dictionary:
			var prize := _prize_from_dict(entry)
			if prize:
				_prizes[prize.id] = prize

	for entry in data.get("containers", []):
		if entry is Dictionary:
			var container := _container_from_dict(entry)
			if container:
				_containers[container.id] = container
				if not container.prize_id.is_empty():
					_prize_to_container[container.prize_id] = container.id

	for prize: PrizeDefinition in _prizes.values():
		if _prize_to_container.has(prize.id):
			prize.container_id = str(_prize_to_container[prize.id])

	for entry in data.get("packs", []):
		if entry is Dictionary:
			var pack := _pack_from_dict(entry)
			if pack:
				_packs[pack.id] = pack

	_load_resource_prizes()


func _load_resource_prizes() -> void:
	var dir := DirAccess.open(PRIZE_RESOURCE_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var prize: PrizeDefinition = load(PRIZE_RESOURCE_DIR + file_name)
			if prize and not prize.id.is_empty():
				_prizes[prize.id] = prize
		file_name = dir.get_next()
	dir.list_dir_end()


func _load_sticker_data(path: String, prize: PrizeDefinition) -> Dictionary:
	if _sticker_cache.has(path):
		return _sticker_cache[path]
	if not ResourceLoader.exists(path):
		push_warning("PrizeCatalog: missing sprite '%s' for prize '%s'." % [path, prize.id])
		return _fallback_sticker_data(prize)
	var texture: Texture2D = load(path)
	if texture == null:
		return _fallback_sticker_data(prize)
	var prepared := StickerShapeUtils.build_shape_from_texture(texture)
	_sticker_cache[path] = prepared
	return prepared


func _fallback_sticker_data(prize: PrizeDefinition) -> Dictionary:
	var cache_key := "fallback:%s" % prize.id
	if _sticker_cache.has(cache_key):
		return _sticker_cache[cache_key]
	var image := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(48, 48)
	var radius := 40.0
	for x in 96:
		for y in 96:
			if Vector2(x, y).distance_to(center) <= radius:
				image.set_pixel(x, y, prize.albedo_color)
	var prepared := StickerShapeUtils.build_shape(image)
	_sticker_cache[cache_key] = prepared
	return prepared


func _prize_from_dict(data: Dictionary) -> PrizeDefinition:
	var prize_id := str(data.get("id", ""))
	if prize_id.is_empty():
		return null
	var prize := PrizeDefinition.new()
	prize.id = prize_id
	prize.pack_id = str(data.get("pack_id", ""))
	prize.group_name = str(data.get("group_name", ""))
	prize.display_name = str(data.get("display_name", prize_id))
	prize.rarity = PrizeDefinition.rarity_from_string(str(data.get("rarity", "common")))
	prize.category = PrizeDefinition.category_from_string(str(data.get("category", "collectible")))
	prize.weight = float(data.get("weight", 1.0))
	prize.recycle_value = int(data.get("recycle_value", 1))
	prize.sprite_path = str(data.get("sprite_path", ""))
	if data.has("albedo_color"):
		var color_raw: Variant = data.get("albedo_color")
		if color_raw is Array and color_raw.size() >= 3:
			prize.albedo_color = Color(float(color_raw[0]), float(color_raw[1]), float(color_raw[2]), 1.0)
	return prize


func _container_from_dict(data: Dictionary) -> ContainerDefinition:
	var container_id := str(data.get("id", ""))
	if container_id.is_empty():
		return null
	var container := ContainerDefinition.new()
	container.id = container_id
	container.pack_id = str(data.get("pack_id", ""))
	container.prize_id = str(data.get("prize_id", ""))
	container.display_name = str(data.get("display_name", container_id))
	container.container_type = ContainerDefinition.ContainerType.CAPSULE
	if str(data.get("container_type", "capsule")).to_lower() == "box":
		container.container_type = ContainerDefinition.ContainerType.BOX
	container.rarity = ContainerDefinition.Rarity.COMMON
	match str(data.get("rarity", "common")).to_lower():
		"rare":
			container.rarity = ContainerDefinition.Rarity.RARE
		"super_rare":
			container.rarity = ContainerDefinition.Rarity.SUPER_RARE
	container.mass = float(data.get("mass", 0.4))
	container.spawn_weight = float(data.get("spawn_weight", 1.0))
	container.shell_opacity = float(data.get("shell_opacity", 0.28))
	if data.has("shell_color"):
		var color_raw: Variant = data.get("shell_color")
		if color_raw is Array and color_raw.size() >= 3:
			container.shell_color = Color(float(color_raw[0]), float(color_raw[1]), float(color_raw[2]), 1.0)
	return container


func _pack_from_dict(data: Dictionary) -> PackDefinition:
	var pack_id := str(data.get("id", ""))
	if pack_id.is_empty():
		return null
	var pack := PackDefinition.new()
	pack.id = pack_id
	pack.display_name = str(data.get("display_name", pack_id))
	pack.machine_id = str(data.get("machine_id", ""))
	pack.cover_art_path = str(data.get("cover_art_path", ""))
	var cids: Variant = data.get("container_ids", [])
	if cids is Array:
		for cid in cids:
			pack.container_ids.append(str(cid))
	var pids: Variant = data.get("prize_ids", [])
	if pids is Array:
		for pid in pids:
			pack.prize_ids.append(str(pid))
	return pack
