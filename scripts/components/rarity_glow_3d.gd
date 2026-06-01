class_name RarityGlow3D
extends Node

var _tier: RarityVisual.EffectTier = RarityVisual.EffectTier.NONE
var _materials: Array[StandardMaterial3D] = []
var _sprites: Array[Sprite3D] = []


func setup_from_container(container: ContainerDefinition) -> void:
	_tier = RarityVisual.tier_for_container(container)
	_collect_targets(get_parent())
	_apply_tier(0.0)
	set_process(RarityVisual.needs_animation(_tier))


func setup_from_prize(prize: PrizeDefinition) -> void:
	_tier = RarityVisual.tier_for_prize(prize)
	_collect_targets(get_parent())
	_apply_tier(0.0)
	set_process(RarityVisual.needs_animation(_tier))


func _collect_targets(root: Node) -> void:
	_materials.clear()
	_sprites.clear()
	if root == null:
		return
	_gather_targets(root)


func _gather_targets(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		if mesh_inst.name in ["BoxShell", "CapsuleShell"]:
			var mat := mesh_inst.material_override
			if mat is StandardMaterial3D:
				_materials.append(mat)
	if node is Sprite3D and node.name == "StickerSprite":
		_sprites.append(node as Sprite3D)
	for child in node.get_children():
		_gather_targets(child)


func _process(_delta: float) -> void:
	_apply_tier(Time.get_ticks_msec() / 1000.0)


func _apply_tier(time_sec: float) -> void:
	if _tier == RarityVisual.EffectTier.NONE:
		return
	for mat in _materials:
		RarityVisual.apply_material_glow(mat, _tier, time_sec)
	var sprite_tint := RarityVisual.RARE_GLOW
	if _tier == RarityVisual.EffectTier.EPIC:
		sprite_tint = RarityVisual.rainbow_color(time_sec)
	for sprite in _sprites:
		sprite.modulate = Color(sprite_tint.r, sprite_tint.g, sprite_tint.b, 1.15)
