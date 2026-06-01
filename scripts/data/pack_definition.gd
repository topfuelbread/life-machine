class_name PackDefinition
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var prizes: Array[PrizeDefinition] = []

func pick_random() -> PrizeDefinition:
	if prizes.is_empty():
		return null
	return prizes[randi() % prizes.size()]
