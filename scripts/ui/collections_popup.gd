class_name CollectionsPopup
extends PanelContainer

signal closed

@onready var rows_container: VBoxContainer = %RowsContainer
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	GameEvents.prize_collected.connect(func(_p, _t): refresh())
	GameEvents.collection_claimed.connect(func(_id): refresh())
	visible = false


func open() -> void:
	refresh()
	visible = true


func close_popup() -> void:
	visible = false
	closed.emit()


func refresh() -> void:
	for child in rows_container.get_children():
		child.queue_free()
	for collection in StoreCatalog.get_all_collections():
		rows_container.add_child(_make_row(collection))


func _make_row(collection: CollectionDefinition) -> Control:
	var progress := GameState.get_collection_progress(collection.id)
	var filled: int = progress.filled
	var total: int = progress.total
	var claimed := collection.id in GameState.get_save().completed_collections

	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 6)

	var header := HBoxContainer.new()
	var title := Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text = "%s  (%d/%d)" % [collection.display_name, filled, total]
	header.add_child(title)
	panel.add_child(header)

	var slots_row := HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", 4)
	var slot_states: Array = progress.get("slots", [])
	for i in collection.slot_prize_ids.size():
		var prize_id := collection.slot_prize_ids[i]
		var prize := GameState.get_prize(prize_id)
		var slot := _PreviewControl.new()
		slot.custom_minimum_size = Vector2(48, 48)
		if prize:
			slot.texture = PrizeCatalog.get_sticker_texture(prize)
		slot.greyed = i >= slot_states.size() or not slot_states[i]
		slots_row.add_child(slot)
	panel.add_child(slots_row)

	var claim := Button.new()
	if claimed:
		claim.text = "Claimed"
		claim.disabled = true
	elif filled >= total and total > 0:
		claim.text = "Claim %d coins" % collection.reward_coins
		var cid := collection.id
		claim.pressed.connect(func(): GameState.claim_collection_reward(cid))
	else:
		claim.text = "In progress…"
		claim.disabled = true
	panel.add_child(claim)
	return panel


func _on_close_pressed() -> void:
	close_popup()


class _PreviewControl extends Control:
	var texture: Texture2D
	var greyed := false

	func _ready() -> void:
		queue_redraw()

	func _draw() -> void:
		if texture == null:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.3, 0.3, 0.3, 0.5))
			return
		var tex_size := texture.get_size()
		var scale_factor := minf(size.x / tex_size.x, size.y / tex_size.y)
		var drawn := Vector2(tex_size) * scale_factor
		var offset := (size - drawn) * 0.5
		var modulate_color := Color(0.35, 0.35, 0.35, 0.6) if greyed else Color.WHITE
		draw_texture_rect(texture, Rect2(offset, drawn), false, modulate_color)
