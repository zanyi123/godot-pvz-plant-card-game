## 卡牌UI组件
## 显示单张卡牌：图片、名称、费用、攻击力
extends Control

var card_data: CardData

@onready var card_texture: TextureRect = $CardTexture
@onready var name_label: Label = $NameLabel
@onready var cost_label: Label = $CostLabel
@onready var atk_label: Label = $AtkLabel

func setup(data: CardData) -> void:
	card_data = data
	if data.get_image_path() != "" and ResourceLoader.exists(data.get_image_path()):
		card_texture.texture = load(data.get_image_path())
	name_label.text = data.name
	cost_label.text = str(data.cost)
	atk_label.text = str(data.atk)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 点击卡牌出牌
		var game_scene = get_tree().get_first_node_in_group("game_scene")
		if game_scene and game_scene.has_method("on_card_clicked"):
			game_scene.on_card_clicked(card_data)
