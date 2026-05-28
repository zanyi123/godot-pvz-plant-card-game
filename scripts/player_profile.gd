## player_profile.gd — 玩家档案管理（本地 JSON 存储）
## 对应 Python: core/player_profile.py
##
## 功能：
##   - 首次启动自动生成 UUID 作为 player_id
##   - 档案存储在 user://player_profile.json
##   - 提供加载/保存/检测是否已注册等接口
extends Node

const PROFILE_FILE = "user://player_profile.json"

var _profile: Dictionary = {}

func _ready() -> void:
	_profile = load_profile()
	if _profile.is_empty():
		print("[PlayerProfile] 未检测到玩家档案")
	else:
		print("[PlayerProfile] 已加载: %s (%s)" % [get_player_name(), get_display_id()])

func load_profile() -> Dictionary:
	if not FileAccess.file_exists(PROFILE_FILE):
		return {}
	var file = FileAccess.open(PROFILE_FILE, FileAccess.READ)
	if file == null:
		return {}
	var text = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(text) != OK:
		return {}
	return json.get_data()

func save_profile(profile: Dictionary) -> void:
	var file = FileAccess.open(PROFILE_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(profile, "\t"))
		file.close()
	_profile = profile

func is_registered() -> bool:
	return _profile.get("player_id", "") != "" and _profile.get("player_name", "") != ""

func create_profile(player_name: String) -> Dictionary:
	var profile = {
		"player_id": _generate_uuid(),
		"player_name": player_name.strip_edges(),
	}
	save_profile(profile)
	print("[PlayerProfile] 注册成功: %s (ID: %s)" % [player_name, get_display_id()])
	return profile

func get_player_id() -> String:
	return _profile.get("player_id", "")

func get_player_name() -> String:
	return _profile.get("player_name", "")

func get_display_id() -> String:
	var full_id = get_player_id()
	if full_id == "":
		return ""
	return full_id.left(8).to_upper()

## 生成类 UUID4（Godot 没有内置 UUID，用随机实现）
func _generate_uuid() -> String:
	var hex = "0123456789abcdef"
	var uuid = ""
	randomize()
	for i in range(32):
		if i == 8 or i == 12 or i == 16 or i == 20:
			uuid += "-"
		if i == 12:
			uuid += "4"  # UUID4 标记
		elif i == 16:
			uuid += hex[randi() % 4 + 8]  # 8~b
		else:
			uuid += hex[randi() % 16]
	return uuid
