class_name ClawLandingIndicator
extends Node3D

## Flat ring on the cabinet floor under the claw grasp point (toggle via GameState / HUD / I key).

const RAY_LENGTH := 14.0
const SURFACE_OFFSET := 0.012

var _claw_hub: Node3D
var _marker: MeshInstance3D
var _floor_ray: RayCast3D


func setup(claw_hub: Node3D) -> void:
	_claw_hub = claw_hub
	_build_marker()
	_build_ray()
	_apply_visibility()


func _physics_process(_delta: float) -> void:
	_apply_visibility()
	if not visible:
		return
	if _claw_hub == null or not is_instance_valid(_claw_hub):
		_marker.visible = false
		return

	var origin := _grasp_world_position()
	_floor_ray.global_position = origin + Vector3.UP * 0.35
	_floor_ray.force_raycast_update()
	if not _floor_ray.is_colliding():
		_marker.visible = false
		return

	var hit := _floor_ray.get_collision_point()
	var normal := _floor_ray.get_collision_normal()
	_marker.visible = true
	_marker.global_position = hit + normal * SURFACE_OFFSET
	if normal.dot(Vector3.UP) > 0.85:
		_marker.global_rotation = Vector3.ZERO
	else:
		var forward := Vector3.FORWARD
		if absf(normal.dot(forward)) > 0.92:
			forward = Vector3.RIGHT
		var right := normal.cross(forward).normalized()
		forward = right.cross(normal).normalized()
		_marker.global_basis = Basis(right, normal, forward)


func _build_marker() -> void:
	_marker = MeshInstance3D.new()
	_marker.name = "LandingMarker"
	var torus := TorusMesh.new()
	var radius := ClawRig.grab_zone_radius()
	torus.inner_radius = maxf(radius * 0.5, 0.08)
	torus.outer_radius = maxf(radius * 0.92, 0.14)
	torus.rings = 28
	torus.ring_segments = 8
	_marker.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.15, 0.72, 1.0, 0.42)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_marker.material_override = mat
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marker)
	_marker.visible = false


func _build_ray() -> void:
	_floor_ray = RayCast3D.new()
	_floor_ray.name = "FloorRay"
	_floor_ray.enabled = true
	_floor_ray.collision_mask = PhysicsLayers.CABINET
	_floor_ray.hit_from_inside = true
	_floor_ray.target_position = Vector3(0.0, -RAY_LENGTH, 0.0)
	add_child(_floor_ray)


func _grasp_world_position() -> Vector3:
	var offset := ClawRig.get_grasp_center_offset()
	return _claw_hub.global_position + _claw_hub.global_transform.basis * offset


func _apply_visibility() -> void:
	visible = GameState.is_claw_landing_indicator_enabled()
