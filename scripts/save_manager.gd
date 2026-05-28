## 成就管理器
## 对应原 Python: core/save_manager.py
## 存档文件保存在用户目录
extends Node

const SAVE_FILE = "user://save_data.json"

var achievements: Dictionary = {}
var stats: Dictionary = {}

func _ready() -> void:
	load_save()

func load_save() -> void:
	if not FileAccess.file_exists(SAVE_FILE):
		achievements = {
			"first_win": false,
			"endurance_20": false,
			"card_master": false,
			"desperate_survival": false,
			"speed_run_10": false,
		}
		stats = {
			"used_card_ids": [],
			"total_wins": 0,
			"total_games": 0,
		}
		save_save()
		return
	
	var file = FileAccess.open(SAVE_FILE, FileAccess.READ)
	if file == null:
		return
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_text) != OK:
		return
	
	var data = json.get_data()
	achievements = data.get("achievements", {})
	stats = data.get("stats", {})

func save_save() -> void:
	var data = {
		"achievements": achievements,
		"stats": stats,
	}
	var file = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func check_achievements(round_count: int, used_card_ids: Array, remedy_flipped: bool) -> Array:
	var unlocked = []
	
	if not achievements.get("first_win", false):
		achievements["first_win"] = true
		unlocked.append("初战告捷")
	
	if not achievements.get("speed_run_10", false) and round_count <= 10:
		achievements["speed_run_10"] = true
		unlocked.append("速战速决")
	
	if not achievements.get("endurance_20", false) and round_count >= 20:
		achievements["endurance_20"] = true
		unlocked.append("坚韧不拔")
	
	if not achievements.get("desperate_survival", false) and remedy_flipped:
		achievements["desperate_survival"] = true
		unlocked.append("绝境逢生")
	
	# 合并卡牌使用记录
	var existing_ids = stats.get("used_card_ids", [])
	for cid in used_card_ids:
		if not cid in existing_ids:
			existing_ids.append(cid)
	stats["used_card_ids"] = existing_ids
	
	if not achievements.get("card_master", false) and existing_ids.size() >= 54:
		achievements["card_master"] = true
		unlocked.append("卡牌大师")
	
	stats["total_wins"] = int(stats.get("total_wins", 0)) + 1
	stats["total_games"] = int(stats.get("total_games", 0)) + 1
	
	save_save()
	return unlocked

func record_loss() -> void:
	stats["total_games"] = int(stats.get("total_games", 0)) + 1
	save_save()

func get_achievement_list() -> Array:
	var names = {
		"first_win": "初战告捷",
		"endurance_20": "坚韧不拔",
		"card_master": "卡牌大师",
		"desperate_survival": "绝境逢生",
		"speed_run_10": "速战速决",
	}
	var descs = {
		"first_win": "首次赢得对战",
		"endurance_20": "在20回合或以上后获胜",
		"card_master": "累计使用过全部54种卡牌",
		"desperate_survival": "在补救回合中翻盘并最终获胜",
		"speed_run_10": "在10回合或以内击败对手",
	}
	var result = []
	for key in names:
		result.append({
			"id": key,
			"name": names[key],
			"desc": descs[key],
			"unlocked": achievements.get(key, false),
		})
	return result
