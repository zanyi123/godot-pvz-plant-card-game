## music_manager.gd - PVZ 植物卡牌对战智能音乐管理系统
## 对应 Python: core/music_manager.py
## 功能：
##   - 自动扫描 music/pre_worlds/ 和 music/worlds/ 目录
##   - 解析文件名提取世界标识
##   - 建立智能配对字典，支持多BGM世界和单曲循环
##   - 提供 pick_random_world() / play_pre() / play_game() / stop() 接口
##   - 集成设置（BGM音量/静音/SFX音量）
##
## 目录结构（assets/music/）：
##   loading_page/  → 加载页音乐
##   menu/          → 菜单BGM
##   pre_worlds/    → 阵前曲（Pre Game / Battle）
##   worlds/        → 游戏BGM（Game Start / Battle）
extends Node

class_name MusicManager

signal pre_music_finished

# iOS/Android 音频焦点恢复
var _was_playing_before_pause: bool = false
var _paused_state_world: String = ""

# -- 常量 ----------------------------------------------------─
const MUSIC_ROOT: String = "res://assets/music"
const PRE_WORLDS_DIR: String = "res://assets/music/pre_worlds"
const WORLDS_DIR: String = "res://assets/music/worlds"
const MENU_DIR: String = "res://assets/music/menu"
const LOADING_DIR: String = "res://assets/music/loading_page"

const SINGLE_LOOP_DELAY_SEC: float = 5.0  # 单曲循环延迟（秒）
const MANA_HARD_CAP: int = 10

# 文件名中需要移除的关键词
var _PRE_KEYWORDS: PackedStringArray = ["Pre Game", "Battle", "Game Start"]
# 特殊世界（多首BGM）
var _SPECIAL_WORLDS: PackedStringArray = ["Neon Mixtape Tour"]


# -- 世界音乐数据 --------------------------------------------─
class WorldMusic:
	var world_key: String = ""
	var pre: String = ""          # 阵前曲资源路径
	var game: PackedStringArray = PackedStringArray()  # 游戏BGM资源路径列表
	var current_index: int = 0


# -- 状态 ----------------------------------------------------─
var _worlds: Dictionary = {}         # world_key → WorldMusic
var _world_keys: PackedStringArray = PackedStringArray()  # 用于随机选择

var _current_world: String = ""
var _is_pre_playing: bool = false
var _is_game_playing: bool = false

# 单曲循环倒计时
var _loop_timer: float = 0.0
var _loop_waiting: bool = false

# -- 音频节点 ------------------------------------------------─
var _bgm_player: AudioStreamPlayer       # BGM播放器
var _sfx_player: AudioStreamPlayer       # SFX播放器（出牌音效等）
var _sfx_hover: AudioStreamPlayer        # 悬停音效
var _sfx_click: AudioStreamPlayer        # 点击音效

# -- 设置 ----------------------------------------------------─
var _bgm_volume: float = 0.5
var _sfx_volume: float = 0.7
var _bgm_muted: bool = false

# 预加载的SFX
var _sfx_card_res: AudioStream
var _sfx_hover_res: AudioStream
var _sfx_click_res: AudioStream


func _ready() -> void:
	# 创建音频播放节点
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	add_child(_bgm_player)
	_bgm_player.finished.connect(_on_bgm_finished)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "SFXPlayer"
	add_child(_sfx_player)

	_sfx_hover = AudioStreamPlayer.new()
	_sfx_hover.name = "SFXHover"
	add_child(_sfx_hover)

	_sfx_click = AudioStreamPlayer.new()
	_sfx_click.name = "SFXClick"
	add_child(_sfx_click)

	# 预加载SFX资源
	_preload_sfx()

	# 加载设置
	load_settings()


func _preload_sfx() -> void:
	var card_path = "res://assets/sfx/card_lighter.wav"
	if ResourceLoader.exists(card_path):
		_sfx_card_res = load(card_path)

	var hover_path = "res://assets/sfx/button__pushbutn.wav"
	if ResourceLoader.exists(hover_path):
		_sfx_hover_res = load(hover_path)

	var click_path = "res://assets/sfx/menu_button.wav"
	if ResourceLoader.exists(click_path):
		_sfx_click_res = load(click_path)


# -- 设置持久化 ----------------------------------------------─

func load_settings() -> void:
	var path = "user://settings.json"
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data = json.get_data()
		_bgm_volume = float(data.get("bgm_volume", 0.5))
		_sfx_volume = float(data.get("sfx_volume", 0.7))
		_bgm_muted = bool(data.get("bgm_muted", false))
	file.close()
	_apply_volume()


func save_settings() -> void:
	var path = "user://settings.json"
	var data: Dictionary = {}
	# 先读取现有设置
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				data = json.get_data()
			file.close()
	# 更新音频设置
	data["bgm_volume"] = _bgm_volume
	data["sfx_volume"] = _sfx_volume
	data["bgm_muted"] = _bgm_muted
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func update_settings(s: Dictionary) -> void:
	_bgm_volume = float(s.get("bgm_volume", _bgm_volume))
	_sfx_volume = float(s.get("sfx_volume", _sfx_volume))
	_bgm_muted = bool(s.get("bgm_muted", _bgm_muted))
	_apply_volume()
	_apply_brightness(float(s.get("screen_brightness", 1.0)))


func _apply_volume() -> void:
	if _bgm_muted:
		_bgm_player.volume_db = -80.0  # 静音
	else:
		_bgm_player.volume_db = linear_to_db(_bgm_volume)
	_sfx_player.volume_db = linear_to_db(_sfx_volume)
	_sfx_hover.volume_db = linear_to_db(_sfx_volume)
	_sfx_click.volume_db = linear_to_db(_sfx_volume)

func _apply_brightness(val: float) -> void:
	val = clampf(val, 0.3, 1.0)
	var scene = get_tree().current_scene
	if scene:
		scene.modulate = Color(1, 1, 1, val)


# -- 扫描音乐 ------------------------------------------------─

func scan() -> void:
	_worlds.clear()
	_world_keys.clear()

	# 硬编码所有音频路径（Android 导出后 DirAccess 不可靠）
	var all_audio: Dictionary = {
		# 世界名: { "pre": "path", "game": ["path1", ...] }
		"Ancient Egypt": {
			"pre": PRE_WORLDS_DIR + "/005. Ancient Egypt Pre Game.mp3",
			"game": [WORLDS_DIR + "/002. Ancient Egypt Game Start.mp3"]
		},
		"Big Wave Beach": {
			"pre": PRE_WORLDS_DIR + "/012. Big Wave Beach Pre Game.mp3",
			"game": [WORLDS_DIR + "/008. Big Wave Beach Game Start.mp3"]
		},
		"Dark Ages": {
			"pre": PRE_WORLDS_DIR + "/019. Dark Ages Pre Game.mp3",
			"game": [WORLDS_DIR + "/015. Dark Ages Game Start.mp3"]
		},
		"Far Future": {
			"pre": PRE_WORLDS_DIR + "/028. Far Future Pre Game.mp3",
			"game": [WORLDS_DIR + "/024. Far Future Game Start.mp3"]
		},
		"Frostbite Caves": {
			"pre": PRE_WORLDS_DIR + "/035. Frostbite Caves Pre Game.mp3",
			"game": [WORLDS_DIR + "/031. Frostbite Caves Game Start.mp3"]
		},
		"Jurassic Marsh": {
			"pre": PRE_WORLDS_DIR + "/051. Jurassic Marsh Pre Game.mp3",
			"game": [WORLDS_DIR + "/047. Jurassic Marsh Game Start.mp3"]
		},
		"Kong Fu World": {
			"pre": PRE_WORLDS_DIR + "/053. Kong Fu World Battle.mp3",
			"game": [WORLDS_DIR + "/053. Kong Fu World Battle.mp3"]
		},
		"Lost City": {
			"pre": PRE_WORLDS_DIR + "/062. Lost City Pre Game.mp3",
			"game": [WORLDS_DIR + "/058. Lost City Game Start.mp3"]
		},
		"Modern Day": {
			"pre": PRE_WORLDS_DIR + "/069. Modern Day Pre Game.mp3",
			"game": [WORLDS_DIR + "/065. Modern Day Game Start.mp3"]
		},
		"Pirate Seas": {
			"pre": PRE_WORLDS_DIR + "/091. Pirate Seas Pre Game.mp3",
			"game": [WORLDS_DIR + "/087. Pirate Seas Game Start.mp3"]
		},
		"Sky City": {
			"pre": PRE_WORLDS_DIR + "/100. Sky City Battle.mp3",
			"game": [WORLDS_DIR + "/100. Sky City Battle.mp3"]
		},
		"Wild West": {
			"pre": PRE_WORLDS_DIR + "/121. Wild West Pre Game.mp3",
			"game": [WORLDS_DIR + "/117. Wild West Game Start.mp3"]
		},
		"Neon Mixtape Tour": {
			"pre": PRE_WORLDS_DIR + "/76. Neon Mixtape Tour - Sincerely the Theme.mp3",
			"game": [
				WORLDS_DIR + "/74. Neon Mixtape Tour - Funkasmic.mp3",
				WORLDS_DIR + "/76. Neon Mixtape Tour - Sincerely the Theme.mp3",
				WORLDS_DIR + "/77. Neon Mixtape Tour - Slam.mp3",
				WORLDS_DIR + "/78. Neon Mixtape Tour - Soda Jerk.mp3",
			]
		},
	}

	for world_name in all_audio:
		var info: Dictionary = all_audio[world_name]
		var pre_path: String = info.get("pre", "")
		var game_paths: PackedStringArray = []
		for p in info.get("game", []):
			game_paths.append(p)
		if pre_path != "" or game_paths.size() > 0:
			var wm: WorldMusic = WorldMusic.new()
			wm.world_key = world_name
			wm.pre = pre_path
			wm.game = game_paths
			_worlds[world_name] = wm

	var keys: Array = _worlds.keys()
	_world_keys = PackedStringArray(keys)
	_log_pairing()


func _scan_dir(dir_path: String, slot: String, bound_files: Dictionary) -> void:
	var da = DirAccess.open(dir_path)
	if da == null:
		return

	da.list_dir_begin()
	var file_name = da.get_next()
	while file_name != "":
		if da.current_is_dir():
			file_name = da.get_next()
			continue
		# 接受音频文件（导出后可能只剩 .import 文件，需要剥离后缀）
		var ext = file_name.get_extension().to_lower()
		var actual_name = file_name
		if ext == "import":
			# "xxx.mp3.import" → 去掉 .import，用原始路径
			actual_name = file_name.get_basename()
			ext = actual_name.get_extension().to_lower()
		if ext != "mp3" and ext != "wav" and ext != "ogg":
			file_name = da.get_next()
			continue

		var full_path = dir_path.path_join(actual_name)
		if bound_files.has(full_path):
			file_name = da.get_next()
			continue
		bound_files[full_path] = true

		var world_key = _parse_filename(file_name)
		if world_key == "":
			file_name = da.get_next()
			continue

		if not _worlds.has(world_key):
			_worlds[world_key] = WorldMusic.new()
			_worlds[world_key].world_key = world_key

		var wm: WorldMusic = _worlds[world_key]
		if slot == "pre":
			wm.pre = full_path
		else:
			wm.game.append(full_path)

		file_name = da.get_next()
	da.list_dir_end()


func _parse_filename(file_name: String) -> String:
	"""从文件名解析世界名称。
	格式: "005. Ancient Egypt Pre Game.mp3" → "Ancient Egypt"
	"""
	# 移除扩展名
	var base = file_name.get_basename()

	# 检查特殊世界
	for special in _SPECIAL_WORLDS:
		if special in base:
			return special

	# 移除关键词
	var raw = base
	for kw in _PRE_KEYWORDS:
		var idx = raw.find(kw)
		if idx >= 0:
			raw = raw.substr(0, idx).strip_edges()
			break

	# 移除序号前缀 "005. " 或 "76. "
	var dot_idx = raw.find(". ")
	if dot_idx >= 0 and dot_idx < 5:
		var world_name = raw.substr(dot_idx + 2).strip_edges()
		# 移除末尾可能残留的 " -"
		world_name = world_name.rstrip(" -")
		if world_name != "":
			return world_name

	return ""


func _log_pairing() -> void:
	pass  # 扫描日志仅在调试时启用


# -- 播放接口 ------------------------------------------------─

func pick_random_world() -> String:
	if _world_keys.is_empty():
		return ""
	return _world_keys[randi() % _world_keys.size()]


func play_pre(world_key: String) -> bool:
	if not _worlds.has(world_key):
		return false

	var wm: WorldMusic = _worlds[world_key]
	if wm.pre == "":
		return false

	_stop_current()
	_is_pre_playing = true
	_is_game_playing = false
	_current_world = world_key

	return _play_stream(wm.pre, false)


func play_game(world_key: String) -> bool:
	if not _worlds.has(world_key):
		return false

	var wm: WorldMusic = _worlds[world_key]
	if wm.game.is_empty():
		return false

	_stop_current()
	_is_pre_playing = false
	_is_game_playing = true
	_current_world = world_key
	wm.current_index = 0
	_loop_timer = 0.0
	_loop_waiting = false

	return _play_game_track(wm)


func play_menu() -> bool:
	"""播放菜单BGM（循环）。"""
	var menu_path = MENU_DIR + "/123. World Map.mp3"
	if not ResourceLoader.exists(menu_path):
		return false
	_stop_current()
	_is_pre_playing = false
	_is_game_playing = false
	_current_world = ""
	return _play_stream(menu_path, true)


func play_loading() -> bool:
	"""播放加载页BGM（循环）。"""
	var load_path = LOADING_DIR + "/080. Opening Splash.mp3"
	if not ResourceLoader.exists(load_path):
		return false
	_stop_current()
	_is_pre_playing = false
	_is_game_playing = false
	_current_world = ""
	return _play_stream(load_path, true)


func stop() -> void:
	_stop_current()
	_current_world = ""
	_loop_timer = 0.0
	_loop_waiting = false


func _stop_current() -> void:
	_bgm_player.stop()
	_is_pre_playing = false
	_is_game_playing = false
	_loop_timer = 0.0
	_loop_waiting = false


func _play_stream(resource_path: String, loop: bool) -> bool:
	if not ResourceLoader.exists(resource_path):
		return false

	var stream = load(resource_path)
	if stream == null:
		return false

	_bgm_player.stream = stream
	_apply_volume()
	_bgm_player.play()
	return true


func _play_game_track(wm: WorldMusic) -> bool:
	if wm.current_index >= wm.game.size():
		wm.current_index = 0
	var track_path = wm.game[wm.current_index]
	return _play_stream(track_path, false)


# -- 进程回调 ------------------------------------------------─

func _process(delta: float) -> void:
	# 单曲循环倒计时
	if _loop_waiting:
		_loop_timer += delta
		if _loop_timer >= SINGLE_LOOP_DELAY_SEC:
			_loop_timer = 0.0
			_loop_waiting = false
			if _current_world != "" and _worlds.has(_current_world):
				var wm: WorldMusic = _worlds[_current_world]
				_play_game_track(wm)

# -- iOS/Android 音频焦点恢复 -------------------------------------

func _notification(what: int) -> void:
	"""处理应用焦点变化，恢复音乐播放"""
	# 应用失去焦点（进入后台、接电话等）
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _is_game_playing or _is_pre_playing:
			_was_playing_before_pause = _bgm_player.playing
			_paused_state_world = _current_world
			_bgm_player.stop()

	# 应用获得焦点（从后台返回）
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if _was_playing_before_pause and _paused_state_world != "":
			# 恢复播放
			if _is_pre_playing:
				play_pre(_paused_state_world)
			elif _is_game_playing:
				play_game(_paused_state_world)
			elif _current_world == "":
				play_menu()

			_was_playing_before_pause = false
			_paused_state_world = ""


func _on_bgm_finished() -> void:
	if _is_pre_playing:
		# 阵前曲播放完毕，通知外部
		_is_pre_playing = false
		emit_signal("pre_music_finished")
		return
	
	if _is_game_playing and _current_world != "" and _worlds.has(_current_world):
		var wm: WorldMusic = _worlds[_current_world]
		if wm.game.size() == 1:
			# 单曲模式：5秒后重播
			_loop_timer = 0.0
			_loop_waiting = true
		else:
			# 多曲模式：下一首
			wm.current_index = (wm.current_index + 1) % wm.game.size()
			_play_game_track(wm)
		return
	
	# 菜单/加载页BGM（_current_world == ""）循环重播
	if _current_world == "" and _bgm_player.stream != null:
		_bgm_player.play()


# -- SFX 接口 ------------------------------------------------─

func play_card_sfx() -> void:
	"""出牌音效。"""
	if _sfx_card_res != null:
		_sfx_player.stream = _sfx_card_res
		_sfx_player.volume_db = linear_to_db(_sfx_volume)
		_sfx_player.play()


func play_hover_sfx() -> void:
	"""鼠标悬停按钮音效。"""
	if _sfx_hover_res != null and not _sfx_hover.playing:
		_sfx_hover.stream = _sfx_hover_res
		_sfx_hover.volume_db = linear_to_db(_sfx_volume)
		_sfx_hover.play()


func play_click_sfx() -> void:
	"""按钮点击音效。"""
	if _sfx_click_res != null:
		_sfx_click.stream = _sfx_click_res
		_sfx_click.volume_db = linear_to_db(_sfx_volume)
		_sfx_click.play()


# -- 信息接口 ------------------------------------------------─

func get_worlds() -> PackedStringArray:
	return _world_keys.duplicate()

func get_current_world() -> String:
	return _current_world

func is_playing() -> bool:
	return _bgm_player.playing
