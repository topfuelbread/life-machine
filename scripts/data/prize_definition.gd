class_name PrizeDefinition
extends Resource

enum PhysicalShape { CAPSULE, BOX }
enum PrizeCategory { DOLL_PART, DECORATION, COLLECTIBLE }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC }

@export var id: String = ""
@export var pack_id: String = ""
@export var display_name: String = ""
@export var physical_shape: PhysicalShape = PhysicalShape.CAPSULE
@export var rarity: Rarity = Rarity.COMMON
@export var category: PrizeCategory = PrizeCategory.COLLECTIBLE
@export var weight: float = 1.0
@export var mass: float = 0.4
@export var recycle_value: int = 1
@export var albedo_color: Color = Color.WHITE
