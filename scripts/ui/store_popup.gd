class_name StorePopup
extends PanelContainer

signal closed

@onready var tabs: TabContainer = %Tabs
@onready var pack_grid: GridContainer = %PackGrid
@onready var upgrade_list: VBoxContainer = %UpgradeList
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	GameEvents.coins_changed.connect(func(_c): refresh())
	GameEvents.pack_purchased.connect(func(_id): refresh())
	GameEvents.upgrade_purchased.connect(func(_id): refresh())
	visible = false


func open() -> void:
	refresh()
	visible = true


func close_popup() -> void:
	visible = false
	closed.emit()


func refresh() -> void:
	_refresh_packs()
	_refresh_upgrades()


func _refresh_packs() -> void:
	for child in pack_grid.get_children():
		child.queue_free()
	for entry in StoreCatalog.get_store_packs():
		if not entry is Dictionary:
			continue
		var pack_id := str(entry.get("pack_id", ""))
		if pack_id.is_empty() or pack_id in GameState.owned_pack_ids:
			continue
		var pack := GameState.get_pack(pack_id)
		var price := int(entry.get("price_coins", 0))
		var btn := Button.new()
		btn.text = "Buy %s\n%d coins" % [pack.display_name if pack else pack_id, price]
		btn.disabled = GameState.get_coins() < price
		var buy_id := pack_id
		btn.pressed.connect(func(): GameState.purchase_pack(buy_id))
		pack_grid.add_child(btn)
	for pack_id in GameState.owned_pack_ids:
		if GameState.get_prizes_remaining(pack_id) > 0:
			continue
		var pack := GameState.get_pack(pack_id)
		var btn := Button.new()
		btn.text = "Refill %s\n50 coins" % (pack.display_name if pack else pack_id)
		btn.disabled = GameState.get_coins() < 50
		var pid := pack_id
		btn.pressed.connect(func(): GameState.refill_pack_for_coins(pid))
		pack_grid.add_child(btn)
	if pack_grid.get_child_count() == 0:
		var label := Label.new()
		label.text = "No packs for sale. Refill owned packs when empty."
		pack_grid.add_child(label)


func _refresh_upgrades() -> void:
	for child in upgrade_list.get_children():
		child.queue_free()
	for upgrade in StoreCatalog.get_all_upgrades():
		var level := GameState.get_upgrade_level(upgrade.id)
		var row := HBoxContainer.new()
		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if level >= upgrade.max_level:
			info.text = "%s — MAX (Lv %d)\n%s" % [upgrade.display_name, level, upgrade.description]
		else:
			var cost := upgrade.get_cost_at_level(level)
			info.text = "%s — Lv %d/%d — %d coins\n%s" % [
				upgrade.display_name, level, upgrade.max_level, cost, upgrade.description,
			]
		row.add_child(info)
		var buy := Button.new()
		buy.text = "Buy"
		buy.disabled = level >= upgrade.max_level or GameState.get_coins() < upgrade.get_cost_at_level(level)
		var uid := upgrade.id
		buy.pressed.connect(func(): GameState.purchase_upgrade(uid))
		row.add_child(buy)
		upgrade_list.add_child(row)


func _on_close_pressed() -> void:
	close_popup()
