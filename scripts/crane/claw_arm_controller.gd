class_name ClawArmController
extends Node3D

## Unity ClawArmController: lower segment (02) curls inward via +X rotation.
## Open B ≈ 16° (wide trap), close B ≈ 108° (pinch). Upper segment splays outward.

@export var segment_b: Node3D
@export var open_angle_b_deg: float = 16.0
@export var close_angle_b_deg: float = 108.0
@export var rotation_speed_deg: float = 180.0

var _angle_b_deg: float = 16.0
var _target_close: bool = false
var _close_blend: float = 1.0


func _ready() -> void:
	open_immediate()


func open_immediate() -> void:
	_target_close = false
	_close_blend = 1.0
	_angle_b_deg = open_angle_b_deg
	_apply_angle()


func set_closed(closed: bool, close_blend: float = 1.0) -> void:
	_target_close = closed
	_close_blend = clampf(close_blend, 0.0, 1.0)


func _target_angle_b() -> float:
	if _target_close:
		return lerpf(open_angle_b_deg, close_angle_b_deg, _close_blend)
	return open_angle_b_deg


func _process(delta: float) -> void:
	var target := _target_angle_b()
	_angle_b_deg = move_toward(_angle_b_deg, target, rotation_speed_deg * delta)
	_apply_angle()


func _apply_angle() -> void:
	if segment_b:
		segment_b.rotation_degrees.x = _angle_b_deg
