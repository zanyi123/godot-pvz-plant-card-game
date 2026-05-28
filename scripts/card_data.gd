## 卡牌数据模型
## 对应原 Python: core/models.py 中的 Card 类
class_name CardData

var id: int = 0
var name: String = ""
var cost: int = 0
var atk: int = 0
var faction: String = ""
var type: String = ""
var limit_flag: bool = false
var effect_id: String = ""
var description: String = ""
var image_file: String = ""

func _init(data: Dictionary = {}) -> void:
	if data.is_empty():
		return
	id = int(data.get("id", 0))
	name = str(data.get("name", ""))
	cost = int(data.get("cost", 0))
	atk = int(data.get("atk", 0))
	faction = str(data.get("faction", ""))
	type = str(data.get("type", ""))
	limit_flag = bool(data.get("limit_flag", false))
	effect_id = str(data.get("effect_id", ""))
	description = str(data.get("description", ""))
	image_file = str(data.get("image_file", ""))

func get_image_path() -> String:
	if image_file == "":
		return ""
	return "res://assets/" + image_file
