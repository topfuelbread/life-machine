class_name PackSelectorPopup
extends PanelContainer

signal play_requested(pack: PackDefinition)
signal closed

const CARD_SIZE := Vector2(120, 140)

@onready var pack_grid: GridContainer = %PackGrid
@onready var detail_label: Label = %DetailLabel
@onready var play_button: Button = %PlayButton
@onready var close_button: Button = %CloseButton

var _selected_pack_id: String = ""


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	close_button.pressed.connect(_on_close_pressed)
	GameEvents.play_consumed.connect(func(_p, _c): _refresh_detail())
	GameEvents.pack_prize_won.connect(func(_p, _pr, _e, _r): _refresh_detail())
	GameEvents.coins_changed.connect(func(_c): _refresh_detail())
	visible = false


func open() -> void:
	_build_pack_grid()
	visible = true
	if _selected_pack_id.is_empty() and GameState.owned_pack_ids.size() > 0:
		_select_pack(GameState.active_pack_id)


func close_popup() -> void:
	visible = false
	closed.emit()


func _build_pack_grid() -> void:
	for child in pack_grid.get_children():
		child.queue_free()
	for pack_id in GameState.owned_pack_ids:
		var pack := GameState.get_pack(pack_id)
		if pack == null:
			continue
		var card := Button.new()
		card.custom_minimum_size = CARD_SIZE
		card.toggle_mode = true
		card.button_group = _get_button_group()
		card.text = pack.display_name
		card.pressed.connect(_select_pack.bind(pack_id))
		if pack_id == GameState.active_pack_id:
			card.button_pressed = true
			_selected_pack_id = pack_id
		pack_grid.add_child(card)
	_refresh_detail()


var _button_group: ButtonGroup


func _get_button_group() -> ButtonGroup:
	if _button_group == null:
		_button_group = ButtonGroup.new()
	return _button_group


func _select_pack(pack_id: String) -> void:
	_selected_pack_id = pack_id
	GameState.set_active_pack(pack_id)
	_refresh_detail()


func _refresh_detail() -> void:
	var pack := GameState.get_pack(_selected_pack_id)
	if pack == null:
		detail_label.text = "Select a pack."
		play_button.disabled = true
		return
	var machine := pack.get_machine()
	var prize_names: PackedStringArray = []
	for prize in pack.get_containing_prizes():
		prize_names.append(prize.display_name)
	var play_cost := machine.play_cost if machine else 1
	detail_label.text = (
		"%s\n\nPrizes: %s\nWon: %d · Remaining: %d · Plays: %d\nCost: %d coin · Coins: %d"
		% [
			pack.display_name,
			", ".join(prize_names) if not prize_names.is_empty() else "—",
			GameState.get_prizes_earned(pack.id),
			GameState.get_prizes_remaining(pack.id),
			GameState.get_pack_plays(pack.id),
			play_cost,
			GameState.get_coins(),
		]
	)
	var out_of_stock := GameState.get_prizes_remaining(pack.id) <= 0
	play_button.disabled = not GameState.can_play(pack) or out_of_stock
	if out_of_stock:
		play_button.text = "Empty — refill in Store"
	else:
		play_button.text = "Play — %s" % pack.display_name


func _on_play_pressed() -> void:
	var pack := GameState.get_pack(_selected_pack_id)
	if pack == null:
		return
	if not GameState.can_play(pack) or GameState.get_prizes_remaining(pack.id) <= 0:
		_refresh_detail()
		return
	play_requested.emit(pack)


func _on_close_pressed() -> void:
	close_popup()
