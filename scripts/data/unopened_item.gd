class_name UnopenedItem
extends Resource

var instance_id: String = ""
var container_id: String = ""
var pack_id: String = ""
var won_at: int = 0


static func create(container_id: String, pack_id: String) -> UnopenedItem:
	var item := UnopenedItem.new()
	item.instance_id = "unopened_%d" % Time.get_ticks_msec()
	item.container_id = container_id
	item.pack_id = pack_id
	item.won_at = int(Time.get_unix_time_from_system())
	return item
