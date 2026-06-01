class_name StoragePanel
extends PanelContainer

signal container_selected(container: ContainerDefinition)
signal prize_selected(prize: PrizeDefinition)
signal unopened_selected(item: UnopenedItem)
signal closed

enum SortMode { LAST_ACQUIRED, NAME, RARITY, OWNED_COUNT }
enum Tab { PRIZES, CONTAINERS, UNOPENED }

const CARD_SIZE := Vector2(112, 148)

@onready var tabs: TabContainer = %Tabs
@onready var sort_option: OptionButton = %SortOption
@onready var container_grid: GridContainer = %ContainerGrid
@onready var prize_grid: GridContainer = %PrizeGrid
@onready var unopened_grid: GridContainer = %UnopenedGrid
@onready var container_empty_label: Label = %ContainerEmptyLabel
@onready var prize_empty_label: Label = %PrizeEmptyLabel
@onready var unopened_empty_label: Label = %UnopenedEmptyLabel
@onready var subtitle: Label = %Subtitle
@onready var close_button: Button = %CloseButton

var _sort_mode: SortMode = SortMode.LAST_ACQUIRED


func _ready() -> void:
	sort_option.clear()
	sort_option.add_item("Last Acquired", SortMode.LAST_ACQUIRED)
	sort_option.add_item("Name", SortMode.NAME)
	sort_option.add_item("Rarity", SortMode.RARITY)
	sort_option.add_item("# Owned", SortMode.OWNED_COUNT)
	sort_option.item_selected.connect(_on_sort_changed)
	tabs.tab_changed.connect(_on_tab_changed)
	tabs.set_tab_hidden(Tab.CONTAINERS, true)
	close_button.pressed.connect(_on_close_pressed)
	GameEvents.prize_collected.connect(func(_p, _t): refresh())
	GameEvents.container_storage_changed.connect(func(_c, _s): refresh())
	GameEvents.unopened_added.connect(func(_i): refresh())
	GameEvents.unopened_revealed.connect(func(_i, _c, _p): refresh())
	GameEvents.prize_recycled.connect(func(_id, _a): refresh())
	GameEvents.display_sticker_placed.connect(func(_p): refresh())
	GameEvents.display_sticker_removed.connect(func(_id): refresh())
	visible = false
	refresh()


func open() -> void:
	refresh()
	visible = true


func close_panel() -> void:
	visible = false
	closed.emit()


func refresh() -> void:
	_refresh_prizes()
	_refresh_unopened()
	_update_subtitle()


func _refresh_unopened() -> void:
	for child in unopened_grid.get_children():
		child.queue_free()
	var items := GameState.get_unopened_items()
	unopened_empty_label.visible = items.is_empty()
	for item in items:
		var card := _make_unopened_card(item)
		if card:
			unopened_grid.add_child(card)


func _refresh_containers() -> void:
	for child in container_grid.get_children():
		child.queue_free()
	var entries := _filter_available_entries(_sorted_container_entries(GameState.get_owned_container_entries()))
	container_empty_label.visible = entries.is_empty()
	for entry in entries:
		container_grid.add_child(_make_container_card(entry))


func _refresh_prizes() -> void:
	for child in prize_grid.get_children():
		child.queue_free()
	var entries := _filter_available_entries(_sorted_prize_entries(GameState.get_owned_prize_entries()))
	prize_empty_label.visible = entries.is_empty()
	for entry in entries:
		prize_grid.add_child(_make_prize_card(entry))


func _sorted_container_entries(entries: Array[Dictionary]) -> Array[Dictionary]:
	var sorted := entries.duplicate()
	match _sort_mode:
		SortMode.NAME:
			sorted.sort_custom(func(a, b): return a.container.display_name < b.container.display_name)
		SortMode.RARITY:
			sorted.sort_custom(func(a, b): return int(a.container.rarity) > int(b.container.rarity))
		SortMode.OWNED_COUNT:
			sorted.sort_custom(func(a, b): return a.owned_count > b.owned_count)
	return sorted


func _sorted_prize_entries(entries: Array[Dictionary]) -> Array[Dictionary]:
	var sorted := entries.duplicate()
	match _sort_mode:
		SortMode.NAME:
			sorted.sort_custom(func(a, b): return a.prize.display_name < b.prize.display_name)
		SortMode.RARITY:
			sorted.sort_custom(func(a, b): return int(a.prize.rarity) > int(b.prize.rarity))
		SortMode.OWNED_COUNT:
			sorted.sort_custom(func(a, b): return a.owned_count > b.owned_count)
	return sorted


func _filter_available_entries(entries: Array[Dictionary]) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for entry in entries:
		if int(entry.get("available_count", 0)) > 0:
			filtered.append(entry)
	return filtered


func _make_container_card(entry: Dictionary) -> Control:
	var container: ContainerDefinition = entry.container
	var available: int = entry.available_count
	return _make_entity_card(
		container.display_name,
		_rarity_pack_line(ContainerDefinition.rarity_label(container.rarity), container.pack_id),
		_make_shell_preview(container),
		available,
		func(): container_selected.emit(container),
		"Place container on display board",
	)


func _make_unopened_card(item: UnopenedItem) -> Control:
	var container := GameState.get_container(item.container_id)
	if container == null:
		return null
	var captured: UnopenedItem = item
	return _make_entity_card(
		container.display_name,
		_rarity_pack_line(ContainerDefinition.rarity_label(container.rarity), item.pack_id),
		_make_container_preview(container),
		1,
		func(): unopened_selected.emit(captured),
		"Tap to unbox",
	)


func _make_prize_card(entry: Dictionary) -> Control:
	var prize: PrizeDefinition = entry.prize
	var available: int = entry.available_count
	var owned: int = entry.owned_count
	var texture := PrizeCatalog.get_sticker_texture(prize)
	var card := _make_entity_card(
		prize.display_name,
		_rarity_pack_line(PrizeDefinition.rarity_label(prize.rarity), prize.pack_id),
		_make_texture_preview(texture, prize),
		available,
		func(): prize_selected.emit(prize),
		"Place prize on display board",
	)
	if owned > 1 and available > 0:
		var wrap := VBoxContainer.new()
		wrap.add_child(card)
		var recycle_btn := Button.new()
		recycle_btn.text = "Recycle 1"
		var pid := prize.id
		recycle_btn.pressed.connect(func(): GameState.recycle_prize(pid, 1))
		wrap.add_child(recycle_btn)
		return wrap
	return card


func _make_entity_card(
	display_name: String,
	subtitle_line: String,
	preview: Control,
	available: int,
	on_pressed: Callable,
	tooltip: String,
) -> Control:
	var button := Button.new()
	button.custom_minimum_size = CARD_SIZE
	button.tooltip_text = tooltip
	button.disabled = available <= 0
	button.flat = true

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 6)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(vbox)

	var preview_center := CenterContainer.new()
	preview_center.custom_minimum_size = Vector2(80, 80)
	preview_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_center.add_child(preview)
	vbox.add_child(preview_center)

	var name_label := Label.new()
	name_label.text = display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	var detail_label := Label.new()
	detail_label.text = subtitle_line
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.add_theme_font_size_override("font_size", 12)
	detail_label.add_theme_color_override("font_color", Color(0.78, 0.78, 0.84))
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(detail_label)

	button.pressed.connect(on_pressed)
	return button


func _make_texture_preview(texture: Texture2D, prize: PrizeDefinition = null) -> Control:
	var preview := _PreviewControl.new()
	preview.custom_minimum_size = Vector2(72, 72)
	preview.mode = _PreviewControl.Mode.TEXTURE
	preview.texture = texture
	if prize != null:
		preview.effect_tier = RarityVisual.tier_for_prize(prize)
	return preview


func _make_shell_preview(container: ContainerDefinition) -> Control:
	var preview := _PreviewControl.new()
	preview.custom_minimum_size = Vector2(72, 72)
	preview.mode = _PreviewControl.Mode.SHELL
	preview.shell_color = container.shell_color
	preview.effect_tier = RarityVisual.tier_for_container(container)
	return preview


func _make_container_preview(container: ContainerDefinition) -> Control:
	var preview := _PreviewControl.new()
	preview.custom_minimum_size = Vector2(72, 72)
	preview.mode = _PreviewControl.Mode.CONTAINER
	preview.shell_color = container.shell_color
	preview.shell_opacity = container.get_display_shell_opacity()
	preview.container_type = container.container_type
	var prize := container.get_prize()
	if prize:
		preview.texture = PrizeCatalog.get_sticker_texture(prize)
	preview.effect_tier = RarityVisual.tier_for_container(container)
	return preview


func _rarity_pack_line(rarity_label: String, pack_id: String) -> String:
	return "%s - %s" % [rarity_label.to_lower(), _pack_display_name(pack_id)]


func _pack_display_name(pack_id: String) -> String:
	if pack_id.is_empty():
		return "unknown pack"
	var pack := GameState.get_pack(pack_id)
	if pack and not pack.display_name.is_empty():
		return pack.display_name
	return pack_id.replace("_", " ")


func _update_subtitle() -> void:
	match tabs.current_tab:
		Tab.PRIZES:
			subtitle.text = "Loose prize stickers — place on the board."
		Tab.CONTAINERS:
			subtitle.text = "Empty container shells — place on the board."
		Tab.UNOPENED:
			subtitle.text = "Won from the claw — tap to unbox."
		_:
			subtitle.text = ""


func _on_tab_changed(_tab: int) -> void:
	_update_subtitle()


func _on_sort_changed(index: int) -> void:
	_sort_mode = index as SortMode
	refresh()


func _on_close_pressed() -> void:
	close_panel()


class _PreviewControl extends Control:
	enum Mode { TEXTURE, SHELL, CONTAINER }

	var mode := Mode.TEXTURE
	var texture: Texture2D
	var shell_color := Color.WHITE
	var shell_opacity := 0.55
	var container_type: ContainerDefinition.ContainerType = ContainerDefinition.ContainerType.CAPSULE
	var effect_tier: RarityVisual.EffectTier = RarityVisual.EffectTier.NONE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(RarityVisual.needs_animation(effect_tier))
		queue_redraw()

	func _process(_delta: float) -> void:
		if RarityVisual.needs_animation(effect_tier):
			queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		var aura_r := minf(size.x, size.y) * 0.42
		if effect_tier != RarityVisual.EffectTier.NONE:
			RarityVisual.draw_aura(self, center, aura_r, effect_tier, Time.get_ticks_msec() / 1000.0)
		match mode:
			Mode.TEXTURE:
				_draw_texture_fit(texture)
			Mode.SHELL:
				_draw_shell(Vector2.ONE * 0.42, 0.55)
			Mode.CONTAINER:
				_draw_container_preview()

	func _draw_container_preview() -> void:
		var center := size * 0.5
		if container_type == ContainerDefinition.ContainerType.BOX:
			var side := minf(size.x, size.y) * 0.78
			var box_rect := Rect2(center - Vector2.ONE * side * 0.5, Vector2.ONE * side)
			draw_rect(box_rect, Color(0.05, 0.05, 0.08, 0.35))
			draw_rect(box_rect, Color(shell_color.r, shell_color.g, shell_color.b, 0.95))
		else:
			_draw_texture_fit(texture, Vector2.ONE * minf(size.x, size.y) * 0.65)
			_draw_shell(Vector2.ONE * 0.42, clampf(shell_opacity, 0.15, 0.75))

	func _draw_shell(radius_scale: Vector2, alpha: float) -> void:
		var center := size * 0.5
		var radius := minf(size.x * radius_scale.x, size.y * radius_scale.y)
		draw_circle(center, radius + 2.0, Color(0.05, 0.05, 0.08, 0.35))
		draw_circle(
			center,
			radius,
			Color(shell_color.r, shell_color.g, shell_color.b, alpha),
		)

	func _draw_texture_fit(
		tex: Texture2D,
		max_size: Vector2 = Vector2.ZERO,
		at_center: Vector2 = Vector2(-1.0, -1.0),
	) -> void:
		if tex == null:
			return
		var tex_size := tex.get_size()
		if tex_size.x <= 0.0 or tex_size.y <= 0.0:
			return
		var bounds := max_size if max_size != Vector2.ZERO else size
		var scale_factor := minf(bounds.x / tex_size.x, bounds.y / tex_size.y)
		var drawn := Vector2(tex_size) * scale_factor
		var center := at_center if at_center.x >= 0.0 else size * 0.5
		var offset := center - drawn * 0.5
		draw_texture_rect(tex, Rect2(offset, drawn), false)
