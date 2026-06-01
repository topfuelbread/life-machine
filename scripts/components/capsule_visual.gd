class_name CapsuleVisual
extends RefCounted

## Builds a 3D capsule mesh: thin transparent shell + prize sticker rattling inside.

const ContainerDef := preload("res://scripts/data/container_definition.gd")
const PrizeDef := preload("res://scripts/data/prize_definition.gd")

const STICKER_FILL_RATIO := 1.05
const SHELL_RADIUS_SCALE := 1.0


static func attach(body: RigidBody3D, container_def: ContainerDef) -> void:
	var prize: PrizeDef = container_def.get_prize()
	if prize == null and not container_def.prize_id.is_empty():
		prize = PrizeCatalog.get_prize(container_def.prize_id)
	var radius := ClawGeometry.CAPSULE_RADIUS

	var core := _add_inner_sticker(body, prize, radius)
	if container_def.container_type == ContainerDef.ContainerType.BOX:
		_add_box_shell(body, container_def, radius)
	else:
		_add_capsule_shell(body, container_def, radius)
	if core != null:
		var half_extent := _sticker_half_extent(prize, radius)
		core.configure(radius, half_extent)
	_attach_rarity_glow(body, container_def)


static func attach_loose(body: RigidBody3D, prize: PrizeDef) -> void:
	var radius := ClawGeometry.CAPSULE_RADIUS * 0.82
	_add_inner_sticker(body, prize, radius)
	_attach_rarity_glow_prize(body, prize)


static func _attach_rarity_glow(body: RigidBody3D, container_def: ContainerDef) -> void:
	if RarityVisual.tier_for_container(container_def) == RarityVisual.EffectTier.NONE:
		return
	var glow := RarityGlow3D.new()
	glow.name = "RarityGlow3D"
	body.add_child(glow)
	glow.setup_from_container(container_def)


static func _attach_rarity_glow_prize(body: RigidBody3D, prize: PrizeDef) -> void:
	if RarityVisual.tier_for_prize(prize) == RarityVisual.EffectTier.NONE:
		return
	var glow := RarityGlow3D.new()
	glow.name = "RarityGlow3D"
	body.add_child(glow)
	glow.setup_from_prize(prize)


static func _add_inner_sticker(body: RigidBody3D, prize: PrizeDef, radius: float) -> CapsuleInnerMotion:
	var core := CapsuleInnerMotion.new()
	core.name = "PrizeCore"
	body.add_child(core)

	if prize == null:
		core.configure(radius, radius * 0.2)
		return core

	var texture := PrizeCatalog.get_sticker_texture(prize)
	if texture == null:
		_add_color_fallback(core, prize, radius)
		return core

	var sprite := Sprite3D.new()
	sprite.name = "StickerSprite"
	sprite.texture = texture
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.double_sided = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.08
	sprite.pixel_size = _sprite_pixel_size(texture, radius)
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.add_child(sprite)
	return core


static func _add_color_fallback(core: Node3D, prize: PrizeDef, radius: float) -> void:
	var fallback := MeshInstance3D.new()
	fallback.name = "StickerFallback"
	var mesh := SphereMesh.new()
	mesh.radius = radius * 0.35
	mesh.height = mesh.radius * 2.0
	fallback.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = prize.albedo_color
	fallback.material_override = mat
	fallback.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.add_child(fallback)


static func _add_box_shell(body: RigidBody3D, container_def: ContainerDef, radius: float) -> void:
	var shell := MeshInstance3D.new()
	shell.name = "BoxShell"
	var mesh := BoxMesh.new()
	var side := radius * 1.55
	mesh.size = Vector3(side, side * 0.95, side)
	shell.mesh = mesh
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat := StandardMaterial3D.new()
	var shell_color: Color = container_def.shell_color
	var alpha: float = clampf(container_def.get_display_shell_opacity(), 0.35, 1.0)
	mat.albedo_color = Color(shell_color.r, shell_color.g, shell_color.b, alpha)
	if alpha < 0.99:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.35
	mat.metallic = 0.05
	shell.material_override = mat
	body.add_child(shell)


static func _add_capsule_shell(body: RigidBody3D, container_def: ContainerDef, radius: float) -> void:
	var shell := MeshInstance3D.new()
	shell.name = "CapsuleShell"
	var mesh := SphereMesh.new()
	mesh.radius = radius * SHELL_RADIUS_SCALE
	mesh.height = mesh.radius * 2.0
	shell.mesh = mesh
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat := StandardMaterial3D.new()
	var shell_color: Color = container_def.shell_color
	var alpha: float = clampf(container_def.get_display_shell_opacity() * 0.55, 0.10, 0.22)
	mat.albedo_color = Color(shell_color.r, shell_color.g, shell_color.b, alpha)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.04
	mat.metallic = 0.0
	mat.rim_enabled = true
	mat.rim = 0.55
	mat.rim_tint = 0.35
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.18
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.render_priority = 1
	shell.material_override = mat
	body.add_child(shell)


static func _sprite_pixel_size(texture: Texture2D, radius: float) -> float:
	var size := texture.get_size()
	var max_dim := maxf(float(size.x), float(size.y))
	if max_dim <= 0.0:
		return radius * 0.004
	return (radius * STICKER_FILL_RATIO) / max_dim


static func _sticker_half_extent(prize: PrizeDef, radius: float) -> float:
	if prize == null:
		return radius * 0.35
	var texture := PrizeCatalog.get_sticker_texture(prize)
	if texture == null:
		return radius * 0.35
	var size := texture.get_size()
	var max_dim := maxf(float(size.x), float(size.y))
	return max_dim * _sprite_pixel_size(texture, radius) * 0.5
