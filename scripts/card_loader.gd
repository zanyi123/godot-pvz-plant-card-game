## 卡牌加载器
## 对应原 Python: main.py 中的 _load_full_deck()
## 从 data/cards.json 读取全部卡牌数据
extends Node

var full_deck: Array[CardData] = []
var _loaded: bool = false

func load_cards() -> Array[CardData]:
	if _loaded:
		return full_deck

	var path = "res://data/cards.json"
	if not FileAccess.file_exists(path):
		push_error("[CardLoader] cards.json 不存在: " + path)
		return full_deck

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[CardLoader] 无法打开 cards.json")
		return full_deck

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("[CardLoader] JSON 解析错误: " + json.get_error_message())
		return full_deck

	var data = json.get_data()
	var templates = data.get("cards", [])

	var seen_ids: Dictionary = {}
	for entry in templates:
		if not entry is Dictionary:
			continue
		var card_id = int(entry.get("id", -1))
		if seen_ids.has(card_id):
			continue
		seen_ids[card_id] = true
		full_deck.append(CardData.new(entry))

	_loaded = true
	if OS.has_feature("debug"):
		print("[CardLoader] 成功加载 %d 张卡牌" % full_deck.size())
	return full_deck
