class_name DisplayRoomInstance
extends Resource

var room_id: String = ""
var display_name: String = ""
var placements: Array[DisplayPlacement] = []


static func create(room_id: String, display_name: String) -> DisplayRoomInstance:
	var room := DisplayRoomInstance.new()
	room.room_id = room_id
	room.display_name = display_name
	return room
