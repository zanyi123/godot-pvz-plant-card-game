## 游戏配置单例：存储跨场景的游戏设置
## 包括AI难度、对战模式等
extends Node

var ai_difficulty: int = 1  # 0=普通, 1=大师（默认大师）
var battle_mode: String = "pve"  # "pve" or "pvp"
var selected_world: String = ""

func set_ai_difficulty(difficulty: int) -> void:
	ai_difficulty = difficulty

func get_ai_difficulty() -> int:
	return ai_difficulty

func set_battle_mode(mode: String) -> void:
	battle_mode = mode

func set_selected_world(world: String) -> void:
	selected_world = world
