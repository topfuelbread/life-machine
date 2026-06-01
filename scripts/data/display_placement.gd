class_name DisplayPlacement
extends Resource

## Saved item on the display board (prize sticker or sealed container).

enum Kind { PRIZE, CONTAINER }

@export var instance_id: String = ""
@export var kind: Kind = Kind.PRIZE
@export var prize_id: String = ""
@export var container_id: String = ""
@export var position: Vector2 = Vector2.ZERO
@export var rotation_degrees: float = 0.0
@export var scale: float = 1.0
@export var flip_h: bool = false
@export var flip_v: bool = false
@export var z_index: int = 0
@export var locked: bool = false


static func create_prize(prize_id: String, pos: Vector2) -> DisplayPlacement:
	var p := DisplayPlacement.new()
	p.instance_id = "%s_%d" % [prize_id, Time.get_ticks_msec()]
	p.kind = Kind.PRIZE
	p.prize_id = prize_id
	p.position = pos
	return p


static func create_container(container_id: String, pos: Vector2) -> DisplayPlacement:
	var p := DisplayPlacement.new()
	p.instance_id = "%s_%d" % [container_id, Time.get_ticks_msec()]
	p.kind = Kind.CONTAINER
	p.container_id = container_id
	var container := PrizeCatalog.get_container(container_id)
	if container:
		p.prize_id = container.prize_id
	p.position = pos
	return p
