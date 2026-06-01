class_name PrizeDefinition
extends Resource

## Collectible sticker for the display room and collector book.

enum PrizeCategory { DOLL_PART, DECORATION, COLLECTIBLE }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC }

@export var id: String = ""
@export var pack_id: String = ""
@export var container_id: String = ""
@export var group_name: String = ""
@export var display_name: String = ""
@export var rarity: Rarity = Rarity.COMMON
@export var category: PrizeCategory = PrizeCategory.COLLECTIBLE
@export var weight: float = 1.0
@export var recycle_value: int = 1
@export var albedo_color: Color = Color.WHITE
@export_file("*.png", "*.webp", "*.svg", "*.jpg", "*.jpeg") var sprite_path: String = ""


static func rarity_label(rarity: Rarity) -> String:
	match rarity:
		Rarity.UNCOMMON:
			return "Uncommon"
		Rarity.RARE:
			return "Rare"
		Rarity.EPIC:
			return "Epic"
	return "Common"


static func category_label(category: PrizeCategory) -> String:
	match category:
		PrizeCategory.DOLL_PART:
			return "Doll Part"
		PrizeCategory.DECORATION:
			return "Decoration"
	return "Collectible"


static func rarity_from_string(raw: String) -> Rarity:
	match raw.to_lower():
		"uncommon":
			return Rarity.UNCOMMON
		"rare":
			return Rarity.RARE
		"epic":
			return Rarity.EPIC
	return Rarity.COMMON


static func category_from_string(raw: String) -> PrizeCategory:
	match raw.to_lower():
		"doll_part", "doll part":
			return PrizeCategory.DOLL_PART
		"decoration", "deco":
			return PrizeCategory.DECORATION
	return PrizeCategory.COLLECTIBLE
