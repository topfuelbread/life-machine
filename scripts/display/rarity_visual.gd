class_name RarityVisual
extends RefCounted

## Draw and material helpers for rare (green) and epic (rainbow) prize glow.

enum EffectTier { NONE, RARE, EPIC }

const RARE_GLOW := Color(0.22, 0.96, 0.42, 1.0)
const RARE_GLOW_SOFT := Color(0.35, 1.0, 0.55, 1.0)

const EPIC_RING_COUNT := 14
const EPIC_RING_WIDTH := 5.0


static func tier_for_prize(prize: PrizeDefinition) -> EffectTier:
	if prize == null:
		return EffectTier.NONE
	match prize.rarity:
		PrizeDefinition.Rarity.EPIC:
			return EffectTier.EPIC
		PrizeDefinition.Rarity.RARE:
			return EffectTier.RARE
	return EffectTier.NONE


static func tier_for_container(container: ContainerDefinition) -> EffectTier:
	if container == null:
		return EffectTier.NONE
	var prize := container.get_prize()
	if prize != null:
		return tier_for_prize(prize)
	match container.rarity:
		ContainerDefinition.Rarity.SUPER_RARE:
			return EffectTier.EPIC
		ContainerDefinition.Rarity.RARE:
			return EffectTier.RARE
	return EffectTier.NONE


static func needs_animation(tier: EffectTier) -> bool:
	return tier == EffectTier.EPIC


static func rainbow_color(time_sec: float, phase: float = 0.0) -> Color:
	var hue := fmod(time_sec * 0.9 + phase, 1.0)
	return Color.from_hsv(hue, 0.88, 1.0)


static func draw_aura(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	tier: EffectTier,
	time_sec: float,
) -> void:
	if tier == EffectTier.NONE:
		return
	match tier:
		EffectTier.RARE:
			_draw_rare_aura(canvas, center, radius)
		EffectTier.EPIC:
			_draw_epic_aura(canvas, center, radius, time_sec)


static func apply_material_glow(mat: StandardMaterial3D, tier: EffectTier, time_sec: float) -> void:
	if mat == null or tier == EffectTier.NONE:
		return
	mat.emission_enabled = true
	match tier:
		EffectTier.RARE:
			mat.emission = RARE_GLOW
			mat.emission_energy_multiplier = 0.55
		EffectTier.EPIC:
			mat.emission = rainbow_color(time_sec)
			mat.emission_energy_multiplier = 0.85


static func _draw_rare_aura(canvas: CanvasItem, center: Vector2, radius: float) -> void:
	for i in 4:
		var expand := 5.0 + float(i) * 4.0
		var alpha := 0.42 - float(i) * 0.09
		var col := RARE_GLOW if i < 2 else RARE_GLOW_SOFT
		col.a = alpha
		canvas.draw_circle(center, radius + expand, col)
	canvas.draw_arc(center, radius + 2.0, 0.0, TAU, 64, Color(RARE_GLOW.r, RARE_GLOW.g, RARE_GLOW.b, 0.7), 3.0, true)


static func _draw_epic_aura(canvas: CanvasItem, center: Vector2, radius: float, time_sec: float) -> void:
	var outer := radius + 10.0
	for ring in 3:
		var ring_r := outer + float(ring) * 5.0
		var col := rainbow_color(time_sec, float(ring) * 0.12)
		col.a = 0.3 - float(ring) * 0.08
		canvas.draw_arc(center, ring_r, 0.0, TAU, 56, col, 4.0, true)

	var segment := TAU / float(EPIC_RING_COUNT)
	for i in EPIC_RING_COUNT:
		var hue_phase := float(i) / float(EPIC_RING_COUNT)
		var col := rainbow_color(time_sec, hue_phase)
		col.a = 0.75
		var a0 := segment * float(i) - segment * 0.08
		var a1 := segment * float(i + 1) + segment * 0.08
		canvas.draw_arc(center, outer, a0, a1, 4, col, EPIC_RING_WIDTH, true)

	for i in 6:
		var sparkle_r := radius + 6.0 + float(i) * 2.5
		var angle := time_sec * 1.4 + float(i) * (TAU / 6.0)
		var sparkle_pos := center + Vector2(cos(angle), sin(angle)) * sparkle_r
		var col := rainbow_color(time_sec, float(i) * 0.16)
		col.a = 0.85
		canvas.draw_circle(sparkle_pos, 3.5, col)
