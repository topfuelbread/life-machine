extends Control

const STICKER_SCENE := preload("res://scenes/display_room/display_sticker.tscn")
const ROOM_1_3D_ID := "room_1"

const SCALE_STEP := 0.08
const ROTATE_STEP := 5.0

@onready var background: ColorRect = $Background
@onready var board: Control = %DisplayBoard
@onready var board_fill: ColorRect = $DisplayBoard/BoardFill
@onready var room_3d_viewport: SubViewportContainer = %Room3DViewport
@onready var room_sub_viewport: SubViewport = $DisplayBoard/Room3DViewport/SubViewport
@onready var white_room_3d: WhiteRoomBoard3D = $DisplayBoard/Room3DViewport/SubViewport/WhiteRoomBoard3D
@onready var sticker_layer: Control = %StickerLayer
@onready var placement_hint: Label = %PlacementHint
@onready var room_title: Label = %RoomTitleLabel
@onready var coins_label: Label = %CoinsLabel
@onready var daily_label: Label = %DailyLabel
@onready var storage_button: Button = %StorageButton
@onready var store_button: Button = %StoreButton
@onready var collections_button: Button = %CollectionsButton
@onready var stat_board_button: Button = %StatBoardButton
@onready var pack_button: Button = %PackButton
@onready var prev_room_button: Button = %PrevRoomButton
@onready var next_room_button: Button = %NextRoomButton
@onready var edit_actions: HBoxContainer = %EditActions
@onready var send_backward_button: Button = %SendBackwardButton
@onready var put_away_button: Button = %PutAwayButton
@onready var bring_forward_button: Button = %BringForwardButton
@onready var storage_panel: StoragePanel = %StoragePanel
@onready var pack_popup: PackSelectorPopup = %PackSelectorPopup
@onready var store_popup: StorePopup = %StorePopup
@onready var collections_popup: CollectionsPopup = %CollectionsPopup
@onready var stat_board_popup: StatBoardPopup = %StatBoardPopup
@onready var unbox_popup: UnboxPopup = %UnboxPopup
@onready var sticker_tooltip: StickerHoverTooltip = %StickerHoverTooltip

var _pending_prize: PrizeDefinition
var _pending_container: ContainerDefinition
var _stickers: Dictionary = {}
var _hovered_sticker: DisplaySticker
var _selected_sticker: DisplaySticker
var _default_sticker_anchors := {}
var _using_room_1_3d := false
var _empty_panel_style: StyleBoxEmpty


func _ready() -> void:
	storage_button.pressed.connect(_on_storage_pressed)
	store_button.pressed.connect(_on_store_pressed)
	collections_button.pressed.connect(_on_collections_pressed)
	stat_board_button.pressed.connect(_on_stat_board_pressed)
	pack_button.pressed.connect(_on_pack_pressed)
	prev_room_button.pressed.connect(func(): _cycle_room(-1))
	next_room_button.pressed.connect(func(): _cycle_room(1))
	put_away_button.pressed.connect(_on_put_away_pressed)
	send_backward_button.pressed.connect(_on_send_backward_pressed)
	bring_forward_button.pressed.connect(_on_bring_forward_pressed)
	storage_panel.container_selected.connect(_on_container_selected_for_placement)
	storage_panel.prize_selected.connect(_on_prize_selected_for_placement)
	storage_panel.unopened_selected.connect(_on_unopened_selected)
	storage_panel.closed.connect(_on_panel_closed)
	pack_popup.play_requested.connect(_on_play_requested)
	pack_popup.closed.connect(_on_panel_closed)
	store_popup.closed.connect(_on_panel_closed)
	collections_popup.closed.connect(_on_panel_closed)
	stat_board_popup.closed.connect(_on_panel_closed)
	board.gui_input.connect(_on_board_gui_input)
	sticker_layer.gui_input.connect(_on_board_gui_input)

	GameEvents.display_sticker_placed.connect(_on_sticker_placed_externally)
	GameEvents.display_sticker_removed.connect(_on_sticker_removed_externally)
	GameEvents.display_room_changed.connect(_on_display_room_changed)
	GameEvents.unopened_revealed.connect(_on_unopened_revealed)
	GameEvents.coins_changed.connect(_refresh_coins)
	GameEvents.unopened_added.connect(func(_i): _refresh_badges())
	GameEvents.daily_quest_progress.connect(func(_q, _v): _refresh_daily())
	GameEvents.daily_quest_claimed.connect(func(_q): _refresh_daily())
	GameEvents.offline_income_applied.connect(_on_offline_income)

	_refresh_coins(GameState.get_coins())
	_cache_default_sticker_layout()
	board.resized.connect(_on_board_resized)
	_apply_room_visual()
	_refresh_room_title()
	_refresh_badges()
	_refresh_daily()
	_load_placements()
	_update_placement_hint()
	edit_actions.visible = false


func _refresh_coins(_amount: int = 0) -> void:
	coins_label.text = "Coins: %d (%s)" % [GameState.get_coins(), IdleIncomeService.get_income_rate_label()]


func _refresh_room_title() -> void:
	var room := GameState.get_active_display_room()
	var rooms := GameState.get_display_rooms()
	if room == null:
		room_title.text = "Display Room"
		return
	var idx := GameState.get_save().active_display_room_index + 1
	room_title.text = "%s  (%d of %d)" % [room.display_name, idx, rooms.size()]


func _refresh_badges() -> void:
	var unopened := GameState.get_unopened_count()
	storage_button.text = "Storage (%d)" % unopened if unopened > 0 else "Storage"
	var nearest := GameState.get_nearest_collection_progress()
	if nearest.collection and nearest.total > 0 and nearest.filled < nearest.total:
		collections_button.text = "Collections (%d/%d)" % [nearest.filled, nearest.total]
	else:
		collections_button.text = "Collections"


func _refresh_daily() -> void:
	var claimed := GameState.get_daily_quests_completed_count()
	var total := StoreCatalog.get_daily_quest_defs().size()
	daily_label.text = "Daily %d/%d" % [claimed, total]


func _on_offline_income(amount: int) -> void:
	placement_hint.text = "Welcome back! +%d coins while away." % amount
	placement_hint.visible = true


func _load_placements() -> void:
	for child in sticker_layer.get_children():
		child.queue_free()
	_stickers.clear()
	_deselect_sticker()
	for placement in GameState.get_placements_for_active_room():
		_spawn_sticker(placement)
	_apply_sticker_z_order()


func _spawn_sticker(placement: DisplayPlacement) -> DisplaySticker:
	var sticker: DisplaySticker = STICKER_SCENE.instantiate()
	sticker.setup(placement)
	if sticker.prize == null and sticker.container == null:
		sticker.queue_free()
		return null
	sticker.drag_started.connect(_on_sticker_drag_started)
	sticker.drag_ended.connect(_on_sticker_drag_ended)
	sticker.hover_started.connect(_on_sticker_hover_started)
	sticker.hover_ended.connect(_on_sticker_hover_ended)
	sticker.sticker_selected.connect(_on_sticker_selected)
	sticker_layer.add_child(sticker)
	sticker.z_index = 0
	_stickers[placement.instance_id] = sticker
	return sticker


func _cycle_room(delta: int) -> void:
	_deselect_sticker()
	_clear_pending_placement()
	GameState.cycle_display_room(delta)


func _on_display_room_changed(_room: DisplayRoomInstance) -> void:
	_refresh_room_title()
	_apply_room_visual()
	_load_placements()
	_update_placement_hint()


func _cache_default_sticker_layout() -> void:
	_default_sticker_anchors = {
		"preset": sticker_layer.anchors_preset,
		"left": sticker_layer.anchor_left,
		"top": sticker_layer.anchor_top,
		"right": sticker_layer.anchor_right,
		"bottom": sticker_layer.anchor_bottom,
		"offset_left": sticker_layer.offset_left,
		"offset_top": sticker_layer.offset_top,
		"offset_right": sticker_layer.offset_right,
		"offset_bottom": sticker_layer.offset_bottom,
	}


func _apply_room_visual() -> void:
	var room := GameState.get_active_display_room()
	var use_3d := room != null and room.room_id == ROOM_1_3D_ID
	_using_room_1_3d = use_3d

	room_3d_viewport.visible = use_3d
	board_fill.visible = not use_3d

	if use_3d:
		background.color = Color(0.97, 0.97, 0.98, 1)
		if _empty_panel_style == null:
			_empty_panel_style = StyleBoxEmpty.new()
		board.add_theme_stylebox_override("panel", _empty_panel_style)
		_sync_room_3d_viewport_size()
		call_deferred("_layout_sticker_layer_for_3d_board")
	else:
		background.color = Color(0.16, 0.15, 0.2, 1)
		board.remove_theme_stylebox_override("panel")
		_restore_flat_sticker_layer()


func _sync_room_3d_viewport_size() -> void:
	var board_size := board.size.floor()
	if board_size.x <= 0 or board_size.y <= 0:
		return
	room_sub_viewport.size = Vector2i(board_size)


func _on_board_resized() -> void:
	if not _using_room_1_3d:
		return
	_sync_room_3d_viewport_size()
	call_deferred("_layout_sticker_layer_for_3d_board")


func _layout_sticker_layer_for_3d_board() -> void:
	if not _using_room_1_3d or white_room_3d == null:
		return

	var board_rect := white_room_3d.get_board_top_screen_rect(room_sub_viewport.size)
	if board_rect.size.x < 8.0 or board_rect.size.y < 8.0:
		return

	var parent_size := board.size
	if parent_size.x <= 0.0 or parent_size.y <= 0.0:
		return

	var scale := parent_size / Vector2(room_sub_viewport.size)
	var scaled_rect := Rect2(board_rect.position * scale, board_rect.size * scale)

	sticker_layer.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	sticker_layer.offset_left = scaled_rect.position.x
	sticker_layer.offset_top = scaled_rect.position.y
	sticker_layer.offset_right = scaled_rect.position.x + scaled_rect.size.x
	sticker_layer.offset_bottom = scaled_rect.position.y + scaled_rect.size.y


func _restore_flat_sticker_layer() -> void:
	sticker_layer.set_anchors_preset(_default_sticker_anchors.get("preset", Control.PRESET_FULL_RECT))
	sticker_layer.anchor_left = _default_sticker_anchors.get("left", 0.0)
	sticker_layer.anchor_top = _default_sticker_anchors.get("top", 0.0)
	sticker_layer.anchor_right = _default_sticker_anchors.get("right", 1.0)
	sticker_layer.anchor_bottom = _default_sticker_anchors.get("bottom", 1.0)
	sticker_layer.offset_left = _default_sticker_anchors.get("offset_left", 0.0)
	sticker_layer.offset_top = _default_sticker_anchors.get("offset_top", 0.0)
	sticker_layer.offset_right = _default_sticker_anchors.get("offset_right", 0.0)
	sticker_layer.offset_bottom = _default_sticker_anchors.get("offset_bottom", 0.0)
	sticker_layer.position = Vector2.ZERO
	sticker_layer.size = Vector2.ZERO


func _close_all_popups() -> void:
	storage_panel.close_panel()
	pack_popup.close_popup()
	store_popup.close_popup()
	collections_popup.close_popup()
	stat_board_popup.close_popup()


func _on_storage_pressed() -> void:
	_close_all_popups()
	_deselect_sticker()
	storage_panel.open()


func _on_store_pressed() -> void:
	_close_all_popups()
	_deselect_sticker()
	store_popup.open()


func _on_collections_pressed() -> void:
	_close_all_popups()
	_deselect_sticker()
	collections_popup.open()


func _on_stat_board_pressed() -> void:
	_close_all_popups()
	_deselect_sticker()
	stat_board_popup.open()


func _on_pack_pressed() -> void:
	_close_all_popups()
	_deselect_sticker()
	pack_popup.open()


func _on_panel_closed() -> void:
	pass


func _on_container_selected_for_placement(container: ContainerDefinition) -> void:
	if GameState.get_available_container_count(container.id) <= 0:
		return
	_deselect_sticker()
	_clear_pending_placement()
	_pending_container = container
	storage_panel.close_panel()
	_update_placement_hint()


func _on_prize_selected_for_placement(prize: PrizeDefinition) -> void:
	if GameState.get_available_prize_count(prize.id) <= 0:
		return
	_deselect_sticker()
	_clear_pending_placement()
	_pending_prize = prize
	storage_panel.close_panel()
	_update_placement_hint()


func _on_unopened_selected(item: UnopenedItem) -> void:
	storage_panel.close_panel()
	unbox_popup.open_for(item)


func _on_unopened_revealed(_item: UnopenedItem, _container: ContainerDefinition, prize: PrizeDefinition) -> void:
	if prize == null:
		return
	_deselect_sticker()
	_clear_pending_placement()
	call_deferred("_place_unboxed_prize", prize.id)


func _place_unboxed_prize(prize_id: String) -> void:
	if GameState.get_available_prize_count(prize_id) <= 0:
		return
	GameState.place_prize(prize_id, _get_sticker_layer_center())


func _get_sticker_layer_center() -> Vector2:
	if sticker_layer.size.x > 0.0 and sticker_layer.size.y > 0.0:
		return sticker_layer.size * 0.5
	return sticker_layer.get_rect().size * 0.5


func _on_board_gui_input(event: InputEvent) -> void:
	if _pending_prize == null and _pending_container == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos := sticker_layer.get_local_mouse_position()
		if _pending_container:
			GameState.place_container(_pending_container.id, local_pos)
		elif _pending_prize:
			GameState.place_prize(_pending_prize.id, local_pos)
		_clear_pending_placement()
		_update_placement_hint()
		get_viewport().set_input_as_handled()


func _on_sticker_selected(sticker: DisplaySticker) -> void:
	_deselect_sticker()
	_clear_pending_placement()
	_selected_sticker = sticker
	sticker.set_selected(true)
	edit_actions.visible = true
	_update_placement_hint()
	_clear_sticker_hover()


func _deselect_sticker() -> void:
	if _selected_sticker:
		_selected_sticker.set_selected(false)
	_selected_sticker = null
	edit_actions.visible = false


func _on_send_backward_pressed() -> void:
	_send_selected_backward()


func _on_bring_forward_pressed() -> void:
	_bring_selected_forward()


func _send_selected_backward() -> void:
	if _selected_sticker == null or _selected_sticker.placement == null:
		return
	GameState.reorder_sticker_layer(_selected_sticker.placement.instance_id, -1)
	_apply_sticker_z_order()


func _bring_selected_forward() -> void:
	if _selected_sticker == null or _selected_sticker.placement == null:
		return
	GameState.reorder_sticker_layer(_selected_sticker.placement.instance_id, 1)
	_apply_sticker_z_order()


func _apply_sticker_z_order() -> void:
	var ordered: Array[DisplaySticker] = []
	for sticker: DisplaySticker in _stickers.values():
		if is_instance_valid(sticker) and sticker.placement != null:
			ordered.append(sticker)
	ordered.sort_custom(func(a: DisplaySticker, b: DisplaySticker) -> bool:
		if a.placement.z_index != b.placement.z_index:
			return a.placement.z_index < b.placement.z_index
		return a.placement.instance_id < b.placement.instance_id
	)
	for i in ordered.size():
		sticker_layer.move_child(ordered[i], i)


func _on_put_away_pressed() -> void:
	if _selected_sticker == null or _selected_sticker.placement == null:
		return
	var id := _selected_sticker.placement.instance_id
	GameState.remove_sticker(id)
	_deselect_sticker()
	_update_placement_hint()


func _on_sticker_drag_started(sticker: DisplaySticker) -> void:
	sticker_layer.move_child(sticker, -1)
	_clear_sticker_hover()
	GameState.defer_persist()


func _on_sticker_drag_ended(sticker: DisplaySticker) -> void:
	sticker.sync_to_state()
	GameState.update_sticker_transform(
		sticker.placement.instance_id,
		sticker.placement.position,
		sticker.placement.rotation_degrees,
		sticker.placement.scale,
		sticker.placement.flip_h,
		sticker.placement.flip_v,
	)
	_apply_sticker_z_order()
	GameState.flush_persist()


func _on_sticker_hover_started(sticker: DisplaySticker) -> void:
	if _pending_prize != null or _pending_container != null or _selected_sticker != null:
		return
	_hovered_sticker = sticker
	sticker_tooltip.show_sticker(sticker)


func _on_sticker_hover_ended(sticker: DisplaySticker) -> void:
	if _hovered_sticker == sticker:
		_clear_sticker_hover()


func _clear_sticker_hover() -> void:
	_hovered_sticker = null
	sticker_tooltip.hide_tooltip()


func _clear_pending_placement() -> void:
	_pending_prize = null
	_pending_container = null
	_clear_sticker_hover()


func _on_sticker_placed_externally(placement: DisplayPlacement) -> void:
	if _stickers.has(placement.instance_id):
		return
	_spawn_sticker(placement)
	_apply_sticker_z_order()


func _on_sticker_removed_externally(instance_id: String) -> void:
	if not _stickers.has(instance_id):
		return
	var sticker: DisplaySticker = _stickers[instance_id]
	if _selected_sticker == sticker:
		_deselect_sticker()
	_stickers.erase(instance_id)
	sticker.queue_free()


func _on_play_requested(pack: PackDefinition) -> void:
	pack_popup.close_popup()
	if pack == null:
		return
	var machine := pack.get_machine()
	if machine:
		get_tree().change_scene_to_file(machine.scene_path)


func _update_placement_hint() -> void:
	if _selected_sticker:
		placement_hint.text = "Wheel: zoom · Q/E: tilt · H/V: flip · [/]: layer · Delete: put away · Esc: done"
		placement_hint.visible = true
	elif _pending_container:
		placement_hint.text = "Click the board to place: %s — Esc to cancel" % _pending_container.display_name
		placement_hint.visible = true
	elif _pending_prize:
		placement_hint.text = "Click the board to place: %s — Esc to cancel" % _pending_prize.display_name
		placement_hint.visible = true
	else:
		placement_hint.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _selected_sticker:
		if event is InputEventMouseButton:
			if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_selected_sticker.adjust_scale(SCALE_STEP)
				_sync_selected_transform()
				get_viewport().set_input_as_handled()
			elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_selected_sticker.adjust_scale(-SCALE_STEP)
				_sync_selected_transform()
				get_viewport().set_input_as_handled()
		if event is InputEventKey and event.pressed:
			match event.keycode:
				KEY_Q:
					_selected_sticker.adjust_rotation(-ROTATE_STEP)
					_sync_selected_transform()
					get_viewport().set_input_as_handled()
				KEY_E:
					_selected_sticker.adjust_rotation(ROTATE_STEP)
					_sync_selected_transform()
					get_viewport().set_input_as_handled()
				KEY_H:
					_selected_sticker.toggle_flip_h()
					_sync_selected_transform()
					get_viewport().set_input_as_handled()
				KEY_V:
					_selected_sticker.toggle_flip_v()
					_sync_selected_transform()
					get_viewport().set_input_as_handled()
				KEY_BRACKETLEFT:
					_send_selected_backward()
					get_viewport().set_input_as_handled()
				KEY_BRACKETRIGHT:
					_bring_selected_forward()
					get_viewport().set_input_as_handled()
				KEY_DELETE:
					_on_put_away_pressed()
					get_viewport().set_input_as_handled()

	if event.is_action_pressed("ui_cancel"):
		if _selected_sticker:
			_deselect_sticker()
			_update_placement_hint()
			get_viewport().set_input_as_handled()
		elif _pending_prize or _pending_container:
			_clear_pending_placement()
			_update_placement_hint()
			get_viewport().set_input_as_handled()
		elif storage_panel.visible:
			storage_panel.close_panel()
			get_viewport().set_input_as_handled()
		elif store_popup.visible:
			store_popup.close_popup()
			get_viewport().set_input_as_handled()
		elif collections_popup.visible:
			collections_popup.close_popup()
			get_viewport().set_input_as_handled()
		elif stat_board_popup.visible:
			stat_board_popup.close_popup()
			get_viewport().set_input_as_handled()
		elif pack_popup.visible:
			pack_popup.close_popup()
			get_viewport().set_input_as_handled()


func _sync_selected_transform() -> void:
	if _selected_sticker == null or _selected_sticker.placement == null:
		return
	var p := _selected_sticker.placement
	GameState.update_sticker_transform(p.instance_id, p.position, p.rotation_degrees, p.scale, p.flip_h, p.flip_v)
