extends Control

@onready var coins_label: Label = %CoinsLabel
@onready var collection_label: Label = %CollectionLabel
@onready var status_label: Label = %StatusLabel
@onready var play_button: Button = %PlayButton
@onready var machine_option: OptionButton = %MachineOption


func _ready() -> void:
	_build_machine_list()
	_sync_machine_selection()
	_refresh_hud()
	GameEvents.prize_collected.connect(_on_prize_collected)
	play_button.pressed.connect(_on_play_pressed)
	machine_option.item_selected.connect(_on_machine_selected)


func _build_machine_list() -> void:
	machine_option.clear()
	for machine_id in GameState.owned_machine_ids:
		var machine := StarterContent.get_machine(machine_id)
		if machine == null:
			continue
		var profile := StarterContent.get_claw_profile(machine.claw_profile_id)
		var claw_label := profile.display_name if profile else machine.claw_profile_id
		machine_option.add_item("%s — %s" % [machine.display_name, claw_label])
		machine_option.set_item_metadata(machine_option.item_count - 1, machine_id)


func _sync_machine_selection() -> void:
	for i in machine_option.item_count:
		if machine_option.get_item_metadata(i) == GameState.active_machine_id:
			machine_option.select(i)
			return


func _refresh_hud() -> void:
	var machine := GameState.get_active_machine()
	var profile := GameState.get_claw_profile()
	coins_label.text = "Coins: %d" % GameState.get_coins()
	collection_label.text = "Unique prizes: %d" % GameState.get_total_unique_prizes()
	if machine:
		play_button.text = "Play — %s (%d coin)" % [machine.display_name, machine.play_cost]
		play_button.disabled = not GameState.can_play(machine)
		if profile:
			status_label.text = "Claw: %s · Payout ~%d%%" % [
				profile.display_name,
				int(profile.payout_probability * 100.0),
			]
		else:
			status_label.text = "Select a machine to play."
	else:
		play_button.disabled = true
		status_label.text = "No machine configured."


func _on_machine_selected(index: int) -> void:
	var machine_id: String = machine_option.get_item_metadata(index)
	GameState.set_active_machine(machine_id)
	_refresh_hud()


func _on_play_pressed() -> void:
	var machine := GameState.get_active_machine()
	if machine == null:
		status_label.text = "No machine configured."
		return
	if not GameState.can_play(machine):
		status_label.text = "Need more coins to play."
		_refresh_hud()
		return
	get_tree().change_scene_to_file(machine.scene_path)


func _on_prize_collected(_prize: PrizeDefinition, _total: int) -> void:
	_refresh_hud()
