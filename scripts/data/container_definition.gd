class_name ContainerDefinition
extends Resource

## Inventory container that encapsulates a [[PrizeDefinition]] (capsule, box, etc.).

enum ContainerType { CAPSULE, BOX }
enum Rarity { COMMON, RARE, SUPER_RARE }

@export var id: String = ""
@export var pack_id: String = ""
@export var container_type: ContainerType = ContainerType.CAPSULE
@export var prize_id: String = ""
@export var display_name: String = ""
@export var rarity: Rarity = Rarity.COMMON
@export var shell_color: Color = Color.WHITE
@export_range(0.05, 1.0, 0.01) var shell_opacity: float = 0.28
@export var mass: float = 0.4
@export var spawn_weight: float = 1.0


func get_prize() -> PrizeDefinition:
	return PrizeCatalog.get_prize(prize_id)


func is_transparent() -> bool:
	return container_type == ContainerType.CAPSULE


func get_display_shell_opacity() -> float:
	if container_type == ContainerType.BOX:
		return 1.0
	return clampf(shell_opacity, 0.05, 1.0)


static func type_label(type: ContainerType) -> String:
	return "Capsule" if type == ContainerType.CAPSULE else "Box"


static func rarity_label(rarity: Rarity) -> String:
	match rarity:
		Rarity.RARE:
			return "Rare"
		Rarity.SUPER_RARE:
			return "Super Rare"
	return "Common"


static func rarity_stat_key(rarity: Rarity) -> String:
	match rarity:
		Rarity.RARE:
			return "rare"
		Rarity.SUPER_RARE:
			return "super_rare"
	return "common"
