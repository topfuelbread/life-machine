class_name ClawProfileDefinition
extends Resource

## Per-claw tuning. Each crane machine references one profile via claw_profile_id.

@export var id: String = ""
@export var display_name: String = "Standard 3-prong"

@export_group("Payout / Grip")
@export_range(0.0, 1.0) var payout_probability: float = 0.33
@export var grip_torque_strong: float = 18.0
@export var grip_torque_weak: float = 2.8
## Seconds after ascend starts before the solenoid weakens (rigged machines).
@export var weak_grip_delay: float = 0.35
## If true, a payout roll keeps strong grip until the prize chute release.
@export var strong_grip_on_payout: bool = true
## If true, grip weakens mid-ascend so prizes can slip (arcade rigging).
@export var rigged_weak_grip: bool = true

@export_group("Prongs")
@export var prong_close_speed: float = 2.4
@export var prong_open_speed: float = 2.0
@export var grab_close_duration: float = 1.0
@export var release_open_duration: float = 0.85

@export_group("Hoist / Gantry")
@export var gantry_move_speed: float = 2.0
@export var transit_move_speed: float = 1.5
@export var hoist_drop_speed: float = 1.6
@export var hoist_ascend_speed: float = 1.5
@export var max_drop_depth: float = -3.2
@export var max_drop_seconds: float = 4.0
@export var drop_settle_seconds: float = 0.12
@export var max_ascend_seconds: float = 3.0

@export_group("Cabinet Flow")
## After ascend, move to the prize chute (real cabinets always do this).
@export var always_deliver_to_chute: bool = true
## Minimum overlap time at grab before we consider a prize "captured" for payout path.
@export var min_grab_overlap_seconds: float = 0.15
