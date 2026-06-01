class_name PrizeWinFlash
extends CanvasLayer

const DISPLAY_SECONDS := 0.9
const ZOOM_IN_PEAK_SCALE := 2.8
const ZOOM_IN_FRACTION := 0.48
const ZOOM_SETTLE_FRACTION := 0.12
const ZOOM_OUT_FRACTION := 0.28
const PRIZE_SIZE := Vector2(300, 300)

@onready var _host: Control = %FlashHost
@onready var _texture: TextureRect = %PrizeTexture

var _flash_generation: int = 0
var _active_tweens: Array[Tween] = []


func _ready() -> void:
	visible = false
	_host.visible = false
	_host.custom_minimum_size = PRIZE_SIZE
	_host.pivot_offset = PRIZE_SIZE * 0.5


func show_prize(prize: PrizeDefinition) -> void:
	if prize == null:
		return
	var sticker := PrizeCatalog.get_sticker_texture(prize)
	if sticker == null:
		return
	_texture.texture = sticker
	_play_flash()


func show_container(container: ContainerDefinition) -> void:
	var prize := container.get_prize() if container else null
	if prize != null:
		show_prize(prize)


func _play_flash() -> void:
	_stop_tweens()
	_flash_generation += 1
	var generation := _flash_generation

	var zoom_in_time := DISPLAY_SECONDS * ZOOM_IN_FRACTION
	var settle_time := DISPLAY_SECONDS * ZOOM_SETTLE_FRACTION
	var zoom_out_time := DISPLAY_SECONDS * ZOOM_OUT_FRACTION
	var hold_time := maxf(
		DISPLAY_SECONDS - zoom_in_time - settle_time - zoom_out_time,
		0.0,
	)
	var peak := Vector2(ZOOM_IN_PEAK_SCALE, ZOOM_IN_PEAK_SCALE)

	visible = true
	_host.visible = true
	_host.scale = Vector2.ZERO
	_host.rotation = 0.0
	_host.modulate = Color.WHITE

	var popup_tween := create_tween()
	_active_tweens.append(popup_tween)
	popup_tween.tween_property(_host, "scale", peak, zoom_in_time)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	popup_tween.tween_property(_host, "scale", Vector2.ONE, settle_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if hold_time > 0.0:
		popup_tween.tween_interval(hold_time)
	popup_tween.tween_property(_host, "scale", Vector2.ZERO, zoom_out_time)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	popup_tween.tween_callback(func() -> void:
		if generation == _flash_generation:
			_hide_flash()
	)


func _hide_flash() -> void:
	_stop_tweens()
	_host.scale = Vector2.ZERO
	_host.visible = false
	visible = false


func _stop_tweens() -> void:
	for tween in _active_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_active_tweens.clear()
