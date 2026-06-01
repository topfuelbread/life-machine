class_name ClawGeometry
extends RefCounted

## Sizes claw + prize from one sphere radius R (m).
##
## Open: tips on a circle of radius d_open so an equilateral 3-prong ring admits the sphere:
##   d_open >= R / cos(30°) ≈ 1.155 R  (chord between tips > 2R)
## Closed: tips curl to d_close < R so the sphere is trapped above the palm cup.
##
## Prize: solid sphere radius R. Shell visual may be slightly larger; physics uses R.

const ARM_COUNT := 3
const ARM_SPREAD_DEG := 120.0
const UPPER_SPLAY_DEG := -24.0

## Fraction of R — open tip horizontal radius (drop-in clearance).
const OPEN_RADIUS_FACTOR := 1.38
## Closed tip horizontal radius (inside prize surface).
const CLOSED_RADIUS_FACTOR := 0.52
## Palm supports sphere center at this depth below claw hub.
const GRASP_CENTER_DEPTH_FACTOR := 0.92
## Upper / lower arm length scales (must reach sphere equator when closed).
const UPPER_ARM_LEN_FACTOR := 1.34
const LOWER_ARM_LEN_HI_FACTOR := 3.0
## Grasp cage slightly smaller than R for contact pressure (interference fit).
const CAGE_RADIUS_FACTOR := 1.02

## Lower segment pivots at distal end of upper arm (local -Y).
const SEG_B_PIVOT := Vector3(0.0, -1.0, 0.0)
## Tip hook at distal end of lower arm, curls inward under the prize.
const TIP_LOCAL := Vector3(0.0, -1.0, 0.22)


## Single source of truth for prize sphere radius (m).
const CAPSULE_RADIUS := 0.30


static func prize_radius() -> float:
	return CAPSULE_RADIUS


static func solve(r: float) -> Dictionary:
	var d_open := r * OPEN_RADIUS_FACTOR
	var d_close := r * CLOSED_RADIUS_FACTOR
	var hub_r := r * 1.02
	var grasp_y := -r * GRASP_CENTER_DEPTH_FACTOR
	var arm_scale := 1.0
	var L1 := r * UPPER_ARM_LEN_FACTOR
	var L2 := 0.0
	var theta_open := 0.0
	var theta_close := 0.0
	for _attempt in range(10):
		L1 = r * UPPER_ARM_LEN_FACTOR * arm_scale
		L2 = _solve_lower_length(L1, hub_r, UPPER_SPLAY_DEG, d_open, d_close)
		theta_open = _solve_theta(L1, L2, hub_r, UPPER_SPLAY_DEG, d_open, 4.0, 24.0)
		theta_close = _solve_theta(L1, L2, hub_r, UPPER_SPLAY_DEG, d_close, 88.0, 118.0)
		var tip_close := _tip_position_yz(L1, L2, hub_r, UPPER_SPLAY_DEG, theta_close)
		# tip.y is downward in claw space; must reach at least the sphere equator.
		if tip_close.y <= grasp_y + r * 0.12:
			break
		arm_scale += 0.1
	return {
		"r": r,
		"hub_mount_r": hub_r,
		"upper_arm_len": L1,
		"lower_arm_len": L2,
		"finger_width": r * 0.16,
		"tip_cone_h": r * 0.44,
		"open_angle_deg": theta_open,
		"close_angle_deg": theta_close,
		"open_tip_radius": d_open,
		"closed_tip_radius": d_close,
		"grasp_center": Vector3(0.0, grasp_y, 0.0),
		"cage_radius": r * CAGE_RADIUS_FACTOR,
		"grab_zone_radius": r * 1.62,
		"palm_half_width": d_open * 0.98,
		"palm_depth": r * 0.44,
		"palm_y": grasp_y - r * 0.22,
		"drop_ray_length": r * (OPEN_RADIUS_FACTOR + L1 * 0.004 + L2 * 0.004 + 1.35),
	}


static func tip_horizontal_radius(
	L1: float,
	L2: float,
	hub_r: float,
	upper_splay_deg: float,
	lower_angle_deg: float,
) -> float:
	var tip := _tip_position_yz(L1, L2, hub_r, upper_splay_deg, lower_angle_deg)
	return Vector2(tip.y, tip.z).length()


static func _tip_position_yz(
	L1: float,
	L2: float,
	hub_r: float,
	upper_splay_deg: float,
	lower_angle_deg: float,
) -> Vector3:
	var seg_a := Vector3(0.0, 0.0, hub_r)
	var basis_a := Basis.from_euler(Vector3(deg_to_rad(upper_splay_deg), 0.0, 0.0))
	var seg_b := Vector3(0.0, -L1 * SEG_B_PIVOT.y, 0.0)
	var basis_b := Basis.from_euler(Vector3(deg_to_rad(lower_angle_deg), 0.0, 0.0))
	var tip_local := Vector3(0.0, -L2 * TIP_LOCAL.y, L2 * TIP_LOCAL.z)
	return seg_a + basis_a * (seg_b + basis_b * tip_local)


static func _solve_lower_length(
	L1: float,
	hub_r: float,
	splay_deg: float,
	d_open: float,
	d_close: float,
) -> float:
	var lo := L1 * 0.72
	var hi := L1 * LOWER_ARM_LEN_HI_FACTOR
	for _i in range(28):
		var mid := (lo + hi) * 0.5
		var r_open := tip_horizontal_radius(L1, mid, hub_r, splay_deg, 12.0)
		var r_close := tip_horizontal_radius(L1, mid, hub_r, splay_deg, 105.0)
		if r_open < d_open and r_close > d_close:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5


static func _solve_theta(
	L1: float,
	L2: float,
	hub_r: float,
	splay_deg: float,
	target_r: float,
	angle_min: float,
	angle_max: float,
) -> float:
	var lo := angle_min
	var hi := angle_max
	for _i in range(20):
		var mid := (lo + hi) * 0.5
		var r := tip_horizontal_radius(L1, L2, hub_r, splay_deg, mid)
		if r < target_r:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5


static func min_open_radius_for_sphere(r: float) -> float:
	# Three tips on circle radius d: pairwise distance = 2d*sin(60°) = d*sqrt(3).
	# Need d*sqrt(3) > 2r  =>  d > 2r/sqrt(3)
	return (2.0 * r) / sqrt(3.0)
