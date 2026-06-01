class_name StatBoardPopup
extends PanelContainer

signal closed

@onready var stats_label: Label = %StatsLabel
@onready var daily_list: VBoxContainer = %DailyList
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	GameEvents.container_storage_changed.connect(func(_c, _s): refresh())
	GameEvents.user_data_changed.connect(refresh)
	GameEvents.crane_play_recorded.connect(func(_p, _t): refresh())
	GameEvents.coins_changed.connect(func(_c): refresh())
	GameEvents.daily_quest_claimed.connect(func(_q): refresh())
	visible = false
	refresh()


func open() -> void:
	refresh()
	visible = true


func close_popup() -> void:
	visible = false
	closed.emit()


func refresh() -> void:
	var storage := GameState.get_container_storage_stats()
	var lines := PackedStringArray()
	lines.append("Coins: %d" % GameState.get_coins())
	lines.append("Unopened: %d" % GameState.get_unopened_count())
	lines.append("Recycle tokens: %d" % GameState.get_save().recycle_tokens)
	lines.append("")
	lines.append("Containers in storage: %d" % int(storage.get("total", 0)))
	lines.append("Total crane plays: %d" % GameState.get_total_crane_plays())
	lines.append("Prizes earned (lifetime): %d" % GameState.get_total_prizes_earned())
	lines.append("")
	for pack_id in GameState.owned_pack_ids:
		var pack := GameState.get_pack(pack_id)
		if pack == null:
			continue
		lines.append(
			"%s: %d%% complete · %d remaining" % [
				pack.display_name,
				int(GameState.get_pack_completion_percent(pack_id)),
				GameState.get_prizes_remaining(pack_id),
			]
		)
	stats_label.text = "\n".join(lines)
	_refresh_daily()


func _refresh_daily() -> void:
	for child in daily_list.get_children():
		child.queue_free()
	for def in StoreCatalog.get_daily_quest_defs():
		if not def is Dictionary:
			continue
		var qid := str(def.get("id", ""))
		var target := int(def.get("target", 1))
		var progress := int(GameState.get_save().daily_quest_progress.get(qid, 0))
		var claimed := qid in GameState.get_save().daily_quests_claimed
		var row := HBoxContainer.new()
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = "%s (%d/%d)" % [def.get("display_name", qid), mini(progress, target), target]
		row.add_child(label)
		var btn := Button.new()
		if claimed:
			btn.text = "Done"
			btn.disabled = true
		elif progress >= target:
			btn.text = "Claim %d" % int(def.get("reward_coins", 0))
			var captured_qid := qid
			btn.pressed.connect(func(): GameState.claim_daily_quest(captured_qid))
		else:
			btn.text = "…"
			btn.disabled = true
		row.add_child(btn)
		daily_list.add_child(row)


func _on_close_pressed() -> void:
	close_popup()
