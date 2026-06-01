extends CanvasLayer

@onready var coins_label: Label = %CoinsLabel
@onready var status_label: Label = %StatusLabel
@onready var indicator_toggle: CheckButton = %IndicatorToggle


func _ready() -> void:
	_refresh()
	_sync_indicator_toggle()
	GameEvents.coins_changed.connect(func(_c): _refresh())
	GameEvents.play_consumed.connect(func(_p, _c): _refresh())
	GameEvents.play_denied.connect(_on_play_denied)
	GameEvents.claw_landing_indicator_changed.connect(_on_indicator_changed)
	indicator_toggle.toggled.connect(_on_indicator_toggle_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_claw_indicator"):
		GameState.set_claw_landing_indicator_enabled(
			not GameState.is_claw_landing_indicator_enabled(),
		)


func _refresh() -> void:
	var pack := GameState.get_active_pack()
	var profile := GameState.get_claw_profile()
	coins_label.text = "Coins: %d" % GameState.get_coins()
	if pack and profile:
		status_label.text = "%s · %s · Esc=Hub · Space=Drop · I=Marker" % [
			pack.display_name,
			profile.display_name,
		]
	else:
		status_label.text = "Esc — Hub · Space — Drop · I — Marker"


func _sync_indicator_toggle() -> void:
	indicator_toggle.set_block_signals(true)
	indicator_toggle.button_pressed = GameState.is_claw_landing_indicator_enabled()
	indicator_toggle.set_block_signals(false)


func _on_indicator_changed(_enabled: bool) -> void:
	_sync_indicator_toggle()


func _on_indicator_toggle_pressed(enabled: bool) -> void:
	GameState.set_claw_landing_indicator_enabled(enabled)


func _on_play_denied(_pack_id: String, reason: String) -> void:
	if reason == "not_enough_coins":
		status_label.text = "Not enough coins to drop."


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/display_room/display_room.tscn")
