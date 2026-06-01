class_name DisplaySticker
extends Control

signal drag_started(sticker: DisplaySticker)
signal drag_ended(sticker: DisplaySticker)
signal hover_started(sticker: DisplaySticker)
signal hover_ended(sticker: DisplaySticker)
signal put_away_requested(sticker: DisplaySticker)
signal sticker_selected(sticker: DisplaySticker)

const MAX_STICKER_DIM := 128.0
const MIN_CONTAINER_DIM := 112.0

var placement: DisplayPlacement
var prize: PrizeDefinition
var container: ContainerDefinition
var is_selected: bool = false

var _dragging := false
var _drag_offset := Vector2.ZERO
var _shell_radius := 0.0
var _display_scale := 1.0
var _sticker_texture: Texture2D
var _hit_polygons: Array[PackedVector2Array] = []
var _visual_root: Node2D
var _sprite: Sprite2D


func setup(p_placement: DisplayPlacement) -> void:
	placement = p_placement
	_resolve_content()
	_apply_visuals()
	apply_state_transform()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	set_process_input(false)
	_update_rarity_animation()
	_anchor_to_placement_center()


func _anchor_to_placement_center() -> void:
	if placement == null or not is_inside_tree():
		return
	var center := placement.position
	position += center - (get_transform() * pivot_offset)


func set_selected(selected: bool) -> void:
	is_selected = selected


func _resolve_content() -> void:
	container = null
	prize = null
	if placement == null:
		return
	if placement.kind == DisplayPlacement.Kind.CONTAINER and not placement.container_id.is_empty():
		container = PrizeCatalog.get_container(placement.container_id)
	elif not placement.prize_id.is_empty():
		prize = PrizeCatalog.get_prize(placement.prize_id)


func get_info_text() -> String:
	if prize == null and container == null:
		return ""
	var lines := PackedStringArray()
	if container:
		lines.append(container.display_name)
		lines.append("Type: %s" % ContainerDefinition.type_label(container.container_type))
		lines.append("Rarity: %s" % ContainerDefinition.rarity_label(container.rarity))
		if prize:
			lines.append("Contains: %s" % prize.display_name)
	elif prize:
		lines.append(prize.display_name)
		lines.append("Rarity: %s" % PrizeDefinition.rarity_label(prize.rarity))
		lines.append("Category: %s" % PrizeDefinition.category_label(prize.category))
	return "\n".join(lines)


func get_tooltip_anchor() -> Vector2:
	return global_position + pivot_offset + Vector2(0.0, -size.y * 0.5 - 12.0)


func _apply_visuals() -> void:
	_sticker_texture = null
	_hit_polygons.clear()
	_shell_radius = 0.0
	_display_scale = 1.0

	if _visual_root != null:
		_visual_root.queue_free()
		_visual_root = null
	_sprite = null

	if prize != null:
		var shape_data := PrizeCatalog.get_sticker_data(prize)
		_sticker_texture = shape_data.get("texture")
		var polygons: Array = shape_data.get("polygons", [])
		for polygon in polygons:
			if polygon is PackedVector2Array:
				_hit_polygons.append(polygon)
		var pixel_size: Vector2 = shape_data.get("pixel_size", Vector2.ZERO)
		_display_scale = StickerShapeUtils.scaled_factor(pixel_size, MAX_STICKER_DIM)

	if container != null:
		_shell_radius = _compute_shell_radius()
		if prize != null and _sticker_texture:
			var inner_size := _shell_radius * 1.75
			_display_scale = minf(
				_display_scale,
				inner_size / maxf(_sticker_texture.get_size().x, _sticker_texture.get_size().y),
			)
		size = Vector2(_shell_radius * 2.0 + 8.0, _shell_radius * 2.0 + 8.0)
	elif _sticker_texture != null:
		size = Vector2(_sticker_texture.get_size()) * _display_scale
	else:
		size = Vector2(MIN_CONTAINER_DIM, MIN_CONTAINER_DIM)

	custom_minimum_size = size
	pivot_offset = size * 0.5

	_visual_root = Node2D.new()
	_visual_root.name = "VisualRoot"
	_visual_root.position = pivot_offset
	add_child(_visual_root)

	if _sticker_texture != null:
		_sprite = Sprite2D.new()
		_sprite.texture = _sticker_texture
		_sprite.centered = true
		_visual_root.add_child(_sprite)

	_apply_flip_and_scale()
	_update_rarity_animation()
	queue_redraw()


func _effect_tier() -> RarityVisual.EffectTier:
	if prize != null:
		return RarityVisual.tier_for_prize(prize)
	if container != null:
		return RarityVisual.tier_for_container(container)
	return RarityVisual.EffectTier.NONE


func _aura_radius() -> float:
	if container != null:
		return _shell_radius + 6.0
	if _sticker_texture != null:
		return maxf(size.x, size.y) * 0.52
	return MIN_CONTAINER_DIM * 0.5


func _update_rarity_animation() -> void:
	set_process(RarityVisual.needs_animation(_effect_tier()))


func _process(_delta: float) -> void:
	if _dragging:
		global_position = get_global_mouse_position() - _drag_offset
	if RarityVisual.needs_animation(_effect_tier()):
		queue_redraw()


func _apply_flip_and_scale() -> void:
	if placement == null:
		return
	var center_in_parent := placement.position
	if is_inside_tree():
		center_in_parent = get_transform() * pivot_offset
	if _sprite:
		var sx := _display_scale * placement.scale * (-1.0 if placement.flip_h else 1.0)
		var sy := _display_scale * placement.scale * (-1.0 if placement.flip_v else 1.0)
		_sprite.scale = Vector2(sx, sy)
	scale = Vector2.ONE
	rotation_degrees = placement.rotation_degrees
	if is_inside_tree():
		position += center_in_parent - (get_transform() * pivot_offset)
		placement.position = get_transform() * pivot_offset
	else:
		position = placement.position - pivot_offset


func _compute_shell_radius() -> float:
	if prize == null or _sticker_texture == null:
		return MIN_CONTAINER_DIM * 0.44
	var tex_size := _sticker_texture.get_size()
	var sticker_scale := StickerShapeUtils.scaled_factor(tex_size, MAX_STICKER_DIM)
	return maxf(Vector2(tex_size).length() * sticker_scale * 0.42, MIN_CONTAINER_DIM * 0.44)


func _draw() -> void:
	var center := pivot_offset
	var tier := _effect_tier()
	if tier != RarityVisual.EffectTier.NONE:
		RarityVisual.draw_aura(self, center, _aura_radius(), tier, Time.get_ticks_msec() / 1000.0)
	if container == null:
		return
	var shell_color := container.shell_color
	var shell_alpha := container.get_display_shell_opacity()
	if container.container_type == ContainerDefinition.ContainerType.BOX:
		var half := Vector2(_shell_radius, _shell_radius)
		var rect := Rect2(center - half, half * 2.0)
		draw_rect(rect.grow(3.0), Color(0.05, 0.05, 0.08, 0.35))
		draw_rect(rect, Color(shell_color.r, shell_color.g, shell_color.b, shell_alpha))
		return
	draw_circle(center, _shell_radius + 3.0, Color(0.05, 0.05, 0.08, 0.35))
	draw_circle(center, _shell_radius, Color(shell_color.r, shell_color.g, shell_color.b, shell_alpha))
	draw_arc(center, _shell_radius, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.22), 2.0, true)


func _has_point(point: Vector2) -> bool:
	var center := pivot_offset
	if container != null:
		if container.container_type == ContainerDefinition.ContainerType.BOX:
			var half := Vector2(_shell_radius, _shell_radius)
			if Rect2(center - half, half * 2.0).has_point(point):
				return true
		elif point.distance_to(center) <= _shell_radius + 3.0:
			return true
	if _hit_polygons.is_empty():
		return false
	var scale_mul := placement.scale if placement else 1.0
	var local := (point - center) / maxf(_display_scale * scale_mul, 0.001)
	for polygon in _hit_polygons:
		if Geometry2D.is_point_in_polygon(local, polygon):
			return true
	return false


func _on_mouse_entered() -> void:
	if not _dragging:
		hover_started.emit(self)


func _on_mouse_exited() -> void:
	if not _dragging:
		hover_ended.emit(self)


func _gui_input(event: InputEvent) -> void:
	if placement != null and placement.locked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not _has_point(event.position):
				return
			if not is_selected:
				sticker_selected.emit(self)
				accept_event()
				return
			_dragging = true
			_drag_offset = get_global_mouse_position() - global_position
			set_process(true)
			set_process_input(true)
			hover_ended.emit(self)
			drag_started.emit(self)
			accept_event()
		elif _dragging:
			_stop_drag()
			accept_event()


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_stop_drag()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		global_position = get_global_mouse_position() - _drag_offset
		get_viewport().set_input_as_handled()


func _stop_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	set_process_input(false)
	_update_rarity_animation()
	drag_ended.emit(self)


func sync_to_state() -> void:
	if placement == null:
		return
	placement.position = get_transform() * pivot_offset


func apply_state_transform() -> void:
	if placement == null:
		return
	_apply_flip_and_scale()


func adjust_scale(delta: float) -> void:
	if placement == null:
		return
	placement.scale = clampf(placement.scale + delta, 0.25, 3.0)
	_apply_flip_and_scale()


func adjust_rotation(delta: float) -> void:
	if placement == null:
		return
	placement.rotation_degrees += delta
	_apply_flip_and_scale()


func toggle_flip_h() -> void:
	if placement:
		placement.flip_h = not placement.flip_h
		_apply_flip_and_scale()


func toggle_flip_v() -> void:
	if placement:
		placement.flip_v = not placement.flip_v
		_apply_flip_and_scale()
