extends Node

var _timer: Timer


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = false
	add_child(_timer)
	_timer.timeout.connect(_on_tick)
	_apply_tick_interval()
	GameEvents.upgrade_purchased.connect(func(_id): _apply_tick_interval())
	call_deferred("_apply_offline_income")


func get_coins_per_tick() -> int:
	var cfg := StoreCatalog.get_income_config()
	var base := int(cfg.get("base_coins_per_tick", 1))
	var level := GameState.get_upgrade_level("coin_boost")
	var upgrade := StoreCatalog.get_upgrade("coin_boost")
	var per_level := upgrade.effect_per_level if upgrade else 1.0
	return base + int(level * per_level)


func get_tick_interval_seconds() -> float:
	var cfg := StoreCatalog.get_income_config()
	var base := float(cfg.get("base_tick_interval_seconds", 10.0))
	var level := GameState.get_upgrade_level("fast_earnings")
	var upgrade := StoreCatalog.get_upgrade("fast_earnings")
	var per_level := upgrade.effect_per_level if upgrade else 0.05
	var reduction := level * per_level
	return maxf(base * (1.0 - reduction), 1.0)


func get_max_offline_hours() -> float:
	var cfg := StoreCatalog.get_income_config()
	var base := float(cfg.get("max_offline_hours", 4.0))
	var level := GameState.get_upgrade_level("offline_vault")
	var upgrade := StoreCatalog.get_upgrade("offline_vault")
	var per_level := upgrade.effect_per_level if upgrade else 2.0
	return base + level * per_level


func get_income_rate_label() -> String:
	return "+%d/%ds" % [get_coins_per_tick(), int(get_tick_interval_seconds())]


func _apply_tick_interval() -> void:
	if _timer == null:
		return
	_timer.wait_time = get_tick_interval_seconds()
	if not _timer.is_stopped():
		_timer.start()


func _apply_offline_income() -> void:
	var save := GameState.get_save()
	var now := int(Time.get_unix_time_from_system())
	var last := save.last_income_tick_unix
	if last <= 0:
		save.last_income_tick_unix = now
		return
	var elapsed := float(now - last)
	var interval := get_tick_interval_seconds()
	var ticks := int(elapsed / interval)
	var max_ticks := int(get_max_offline_hours() * 3600.0 / interval)
	ticks = mini(ticks, max_ticks)
	if ticks > 0:
		var earned := ticks * get_coins_per_tick()
		GameState.add_coins(earned, false)
		if earned > 0:
			GameEvents.offline_income_applied.emit(earned)
	save.last_income_tick_unix = now
	_timer.start()


func _on_tick() -> void:
	GameState.add_coins(get_coins_per_tick(), false)
	GameState.get_save().last_income_tick_unix = int(Time.get_unix_time_from_system())
