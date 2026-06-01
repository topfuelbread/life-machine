class_name StickerHoverTooltip
extends PanelContainer

@onready var info_label: Label = %InfoLabel

var _tracked_sticker: DisplaySticker
var _show_generation: int = 0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func show_sticker(sticker: DisplaySticker) -> void:
	if not _is_sticker_valid(sticker):
		hide_tooltip()
		return
	if sticker.prize == null and sticker.container == null:
		hide_tooltip()
		return
	_show_generation += 1
	var generation := _show_generation
	_tracked_sticker = sticker
	info_label.text = sticker.get_info_text()
	visible = true
	set_process(true)
	_position_after_layout(generation)


func hide_tooltip() -> void:
	_show_generation += 1
	_tracked_sticker = null
	visible = false
	set_process(false)


func _position_after_layout(generation: int) -> void:
	await get_tree().process_frame
	if generation != _show_generation:
		return
	if not _is_sticker_valid(_tracked_sticker):
		hide_tooltip()
		return
	_position_near_sticker()


func _process(_delta: float) -> void:
	if not visible or not _is_sticker_valid(_tracked_sticker):
		hide_tooltip()
		return
	_position_near_sticker()


func _position_near_sticker() -> void:
	var sticker := _tracked_sticker
	if not _is_sticker_valid(sticker):
		hide_tooltip()
		return
	var anchor := sticker.get_tooltip_anchor()
	global_position = anchor - Vector2(size.x * 0.5, size.y)

	var viewport_size := get_viewport_rect().size
	global_position.x = clampf(global_position.x, 8.0, viewport_size.x - size.x - 8.0)
	global_position.y = clampf(global_position.y, 8.0, viewport_size.y - size.y - 8.0)


func _is_sticker_valid(sticker: DisplaySticker) -> bool:
	return sticker != null and is_instance_valid(sticker)
