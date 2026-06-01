class_name UpgradeDefinition
extends Resource

enum EffectType { INCOME_AMOUNT, INCOME_SPEED, OFFLINE_CAP, PLAY_COST_DISCOUNT }

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var effect_type: EffectType = EffectType.INCOME_AMOUNT
@export var base_cost: int = 10
@export var cost_growth: float = 1.15
@export var effect_per_level: float = 1.0
@export var max_level: int = 100


func get_cost_at_level(current_level: int) -> int:
	return int(round(base_cost * pow(cost_growth, current_level)))


static func effect_type_from_string(raw: String) -> EffectType:
	match raw.to_lower():
		"income_speed":
			return EffectType.INCOME_SPEED
		"offline_cap":
			return EffectType.OFFLINE_CAP
		"play_cost_discount":
			return EffectType.PLAY_COST_DISCOUNT
	return EffectType.INCOME_AMOUNT
