extends CanvasLayer

@onready var coins_label: Label = %CoinsLabel
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	_refresh()
	GameEvents.prize_collected.connect(func(_p, _t): _refresh())
	GameEvents.play_consumed.connect(func(_m, _c): _refresh())
	GameEvents.play_denied.connect(_on_play_denied)


func _refresh() -> void:
	var machine := GameState.get_active_machine()
	var profile := GameState.get_claw_profile()
	coins_label.text = "Coins: %d" % GameState.get_coins()
	if machine and profile:
		status_label.text = "%s · %s · Esc=Hub · Space=Drop" % [
			machine.display_name,
			profile.display_name,
		]
	else:
		status_label.text = "Esc — Hub · Space — Drop"


func _on_play_denied(_machine_id: String, reason: String) -> void:
	if reason == "not_enough_coins":
		status_label.text = "Not enough coins to drop."


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game_root.tscn")
