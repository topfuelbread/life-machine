extends Node

var inventory: Dictionary = {}
var owned_machine_ids: Array[String] = StarterContent.get_all_machine_ids()
var coins_by_currency: Dictionary = {"default": 20}
var active_machine_id: String = StarterContent.STARTER_MACHINE_ID

var _pack_cache: Dictionary = {}


func _ready() -> void:
	_ensure_pack_cached(StarterContent.STARTER_PACK_ID)
	_ensure_pack_cached(StarterContent.PLUSH_PACK_ID)


func set_active_machine(machine_id: String) -> void:
	if machine_id in owned_machine_ids:
		active_machine_id = machine_id


func get_claw_profile() -> ClawProfileDefinition:
	var machine := get_active_machine()
	if machine == null:
		return StarterContent.get_claw_profile(StarterContent.CLAW_STANDARD_ID)
	return StarterContent.get_claw_profile(machine.claw_profile_id)


func get_active_machine() -> CraneMachineDefinition:
	return StarterContent.get_machine(active_machine_id)


func get_pack(pack_id: String) -> PackDefinition:
	_ensure_pack_cached(pack_id)
	return _pack_cache.get(pack_id)


func get_owned_count(prize_id: String) -> int:
	return int(inventory.get(prize_id, 0))


func get_total_unique_prizes() -> int:
	return inventory.size()


func add_prize(prize: PrizeDefinition, amount: int = 1) -> void:
	if prize == null or prize.id.is_empty() or amount <= 0:
		return
	var total: int = get_owned_count(prize.id) + amount
	inventory[prize.id] = total
	GameEvents.prize_collected.emit(prize, total)


func get_coins(currency_id: String = "default") -> int:
	return int(coins_by_currency.get(currency_id, 0))


func can_play(machine: CraneMachineDefinition) -> bool:
	if machine == null:
		return false
	return get_coins(machine.coin_currency_id) >= machine.play_cost


func consume_play(machine: CraneMachineDefinition) -> bool:
	if machine == null or not can_play(machine):
		GameEvents.play_denied.emit(machine.id if machine else "", "not_enough_coins")
		return false
	var currency := machine.coin_currency_id
	coins_by_currency[currency] = get_coins(currency) - machine.play_cost
	GameEvents.play_consumed.emit(machine.id, get_coins(currency))
	return true


func _ensure_pack_cached(pack_id: String) -> void:
	if _pack_cache.has(pack_id):
		return
	var pack := StarterContent.get_pack(pack_id)
	if pack:
		_pack_cache[pack_id] = pack
