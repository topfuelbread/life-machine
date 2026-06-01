class_name WhiteRoomBoard3D
extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var table_top: MeshInstance3D = $DisplayTable/TableTop


func get_board_top_screen_rect(viewport_size: Vector2) -> Rect2:
	if camera == null or table_top == null or table_top.mesh == null:
		return Rect2(Vector2.ZERO, viewport_size)

	var half: Vector3 = (table_top.mesh as BoxMesh).size * 0.5
	var top_y := half.y
	var corners := [
		Vector3(-half.x, top_y, -half.z),
		Vector3(half.x, top_y, -half.z),
		Vector3(half.x, top_y, half.z),
		Vector3(-half.x, top_y, half.z),
	]

	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for local: Vector3 in corners:
		var world: Vector3 = table_top.global_transform * local
		var screen: Vector2 = camera.unproject_position(world)
		min_p.x = minf(min_p.x, screen.x)
		min_p.y = minf(min_p.y, screen.y)
		max_p.x = maxf(max_p.x, screen.x)
		max_p.y = maxf(max_p.y, screen.y)

	return Rect2(min_p, max_p - min_p)
