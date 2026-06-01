class_name UnboxPopup
extends PanelContainer

signal closed

@onready var title_label: Label = %TitleLabel
@onready var preview: TextureRect = %Preview
@onready var close_button: Button = %CloseButton

var _item: UnopenedItem


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	visible = false


func open_for(item: UnopenedItem) -> void:
	_item = item
	var container := GameState.get_container(item.container_id)
	var prize := container.get_prize() if container else null
	title_label.text = "Unboxing…"
	if container:
		title_label.text = container.display_name
	if prize:
		preview.texture = PrizeCatalog.get_sticker_texture(prize)
	visible = true
	await get_tree().create_timer(1.2).timeout
	if _item:
		GameState.reveal_unopened(_item.instance_id)
	_item = null
	close_popup()


func close_popup() -> void:
	visible = false
	closed.emit()


func _on_close_pressed() -> void:
	if _item:
		GameState.reveal_unopened(_item.instance_id)
		_item = null
	close_popup()
