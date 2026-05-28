## 主菜单场景脚本
## 对应原 Python: ui/main_menu.py
## 完整实现：人机对战、成就系统、设置、规则弹窗、确认出征对话框
extends Control

# 按钮节点
@onready var pve_btn: Button = $PvEButton
@onready var pvp_btn: Button = $PvPButton
@onready var achieve_btn: Button = $AchieveButton
@onready var settings_btn: Button = $SettingsButton
@onready var rules_btn: Button = $RulesButton
@onready var guide_btn: Button = $GuideButton
@onready var quit_btn: Button = $QuitButton

# 玩家信息
@onready var player_name_label: Label = $PlayerInfoPanel/PlayerName
@onready var player_id_label: Label = $PlayerInfoPanel/PlayerID

# 成就管理器
var save_manager: Node

# 弹窗组件（通用）
var popup_overlay: ColorRect
var popup_panel: Panel
var popup_title_label: Label
var popup_body_label: RichTextLabel
var popup_close_btn: Button

# 确认出征对话框（对应 Python ConfirmDialog）
var confirm_overlay: ColorRect
var confirm_panel: Panel
var confirm_world_label: Label
var confirm_msg_label: Label
var confirm_btn: Button    # 确认出征
var cancel_btn: Button     # 取消
var _confirm_world: String = ""
var _confirm_visible: bool = false

# 选中的世界
var _selected_world: String = ""

var font: FontFile


func _ready() -> void:
	font = load("res://assets/fonts/simhei.ttf")
	
	# 连接按钮信号
	pve_btn.pressed.connect(_on_pve_pressed)
	pvp_btn.pressed.connect(_on_pvp_pressed)
	achieve_btn.pressed.connect(_on_achieve_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	rules_btn.pressed.connect(_on_rules_pressed)
	guide_btn.pressed.connect(_on_guide_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	
	# 创建弹窗
	_create_popup()
	# 创建确认出征对话框
	_create_confirm_dialog()
	
	# 加载成就管理器
	save_manager = Node.new()
	save_manager.set_script(load("res://scripts/save_manager.gd"))
	add_child(save_manager)
	
	# 加载玩家信息
	_load_player_info()
	
	# 播放菜单BGM
	if GlobalMusic:
		GlobalMusic.play_menu()
		GlobalMusic.update_settings(_load_settings())


# -- 通用弹窗 ------------------------------------------------─

func _create_popup() -> void:
	var pop_w = 580
	var pop_h = 520
	var pop_x = (1024 - pop_w) / 2
	var pop_y = (768 - pop_h) / 2
	
	popup_overlay = ColorRect.new()
	popup_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_overlay.color = Color(0, 0, 0, 0.7)
	popup_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	popup_overlay.gui_input.connect(_on_popup_bg_clicked)
	
	popup_panel = Panel.new()
	popup_panel.position = Vector2(pop_x, pop_y)
	popup_panel.size = Vector2(pop_w, pop_h)
	
	popup_title_label = Label.new()
	popup_title_label.position = Vector2(0, 12)
	popup_title_label.size = Vector2(pop_w, 36)
	popup_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_title_label.add_theme_font_override("font", font)
	popup_title_label.add_theme_font_size_override("font_size", 22)
	popup_title_label.text = "标题"
	
	popup_body_label = RichTextLabel.new()
	popup_body_label.position = Vector2(20, 56)
	popup_body_label.size = Vector2(pop_w - 40, pop_h - 120)
	popup_body_label.bbcode_enabled = false
	popup_body_label.add_theme_font_override("normal_font", font)
	popup_body_label.add_theme_font_size_override("normal_font_size", 15)
	
	popup_close_btn = Button.new()
	popup_close_btn.position = Vector2(pop_w / 2 - 70, pop_h - 56)
	popup_close_btn.size = Vector2(140, 40)
	popup_close_btn.text = "我知道了"
	popup_close_btn.add_theme_font_override("font", font)
	popup_close_btn.add_theme_font_size_override("font_size", 16)
	popup_close_btn.pressed.connect(_hide_popup)
	
	popup_panel.add_child(popup_title_label)
	popup_panel.add_child(popup_body_label)
	popup_panel.add_child(popup_close_btn)
	popup_overlay.add_child(popup_panel)
	add_child(popup_overlay)
	popup_overlay.visible = false


func _on_popup_bg_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hide_popup()

func _show_popup(title: String, body: String) -> void:
	popup_title_label.text = title
	popup_body_label.text = body
	popup_overlay.visible = true

func _hide_popup() -> void:
	popup_overlay.visible = false


# -- 确认出征对话框（对应 Python ConfirmDialog）--------------

func _create_confirm_dialog() -> void:
	# 尺寸参数
	var dlg_w = 420
	var dlg_h = 280
	var dlg_x = (1024 - dlg_w) / 2
	var dlg_y = (768 - dlg_h) / 2
	
	# 半透明遮罩
	confirm_overlay = ColorRect.new()
	confirm_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirm_overlay.color = Color(0, 0, 0, 0.63)
	confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 面板 — 蓝底对应 Python (41,128,185)
	confirm_panel = Panel.new()
	confirm_panel.position = Vector2(dlg_x, dlg_y)
	confirm_panel.size = Vector2(dlg_w, dlg_h)
	# 自绘蓝色背景
	confirm_panel.self_modulate = Color(41.0/255, 128.0/255, 185.0/255)
	
	# 标题
	var title = Label.new()
	title.position = Vector2(0, 20)
	title.size = Vector2(dlg_w, 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 22)
	title.text = "⚔️  准备出征！"
	title.name = "TitleLabel"
	confirm_panel.add_child(title)
	
	# 分隔线
	var sep = HSeparator.new()
	sep.position = Vector2(30, 60)
	sep.size = Vector2(dlg_w - 60, 2)
	confirm_panel.add_child(sep)
	
	# 世界名称（金黄色，对应 Python (255,235,100)）
	confirm_world_label = Label.new()
	confirm_world_label.position = Vector2(0, 75)
	confirm_world_label.size = Vector2(dlg_w, 40)
	confirm_world_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_world_label.add_theme_font_override("font", font)
	confirm_world_label.add_theme_font_size_override("font_size", 26)
	confirm_world_label.add_theme_color_override("font_color", Color(1.0, 235.0/255, 100.0/255))
	confirm_world_label.text = "🌍 世界名"
	confirm_panel.add_child(confirm_world_label)
	
	# 提示文字
	confirm_msg_label = Label.new()
	confirm_msg_label.position = Vector2(0, 120)
	confirm_msg_label.size = Vector2(dlg_w, 30)
	confirm_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_msg_label.add_theme_font_override("font", font)
	confirm_msg_label.add_theme_font_size_override("font_size", 15)
	confirm_msg_label.add_theme_color_override("font_color", Color(220.0/255, 235.0/255, 1.0))
	confirm_msg_label.text = "与 AI 对战并获取胜利"
	confirm_panel.add_child(confirm_msg_label)
	
	# 按钮区域
	var btn_w = 140
	var btn_h = 46
	var btn_spacing = 30
	var total_btn_w = 2 * btn_w + btn_spacing
	var btn_start_x = (dlg_w - total_btn_w) / 2
	var btn_y = dlg_h - btn_h - 30
	
	# 确认按钮（绿色）
	confirm_btn = Button.new()
	confirm_btn.position = Vector2(btn_start_x, btn_y)
	confirm_btn.size = Vector2(btn_w, btn_h)
	confirm_btn.text = "✅ 确认出征"
	confirm_btn.add_theme_font_override("font", font)
	confirm_btn.add_theme_font_size_override("font_size", 16)
	confirm_btn.pressed.connect(_on_confirm出征)
	confirm_panel.add_child(confirm_btn)
	
	# 取消按钮（红色）
	cancel_btn = Button.new()
	cancel_btn.position = Vector2(btn_start_x + btn_w + btn_spacing, btn_y)
	cancel_btn.size = Vector2(btn_w, btn_h)
	cancel_btn.text = "❌ 取消"
	cancel_btn.add_theme_font_override("font", font)
	cancel_btn.add_theme_font_size_override("font_size", 16)
	cancel_btn.pressed.connect(_on_confirm_cancel)
	confirm_panel.add_child(cancel_btn)
	
	confirm_overlay.add_child(confirm_panel)
	add_child(confirm_overlay)
	confirm_overlay.visible = false
	_confirm_visible = false


func _show_confirm_dialog(world_name: String) -> void:
	_confirm_world = world_name
	confirm_world_label.text = "🌍 " + world_name
	confirm_overlay.visible = true
	_confirm_visible = true


func _hide_confirm_dialog() -> void:
	confirm_overlay.visible = false
	_confirm_visible = false


func _on_confirm出征() -> void:
	"""确认出征 → 预备曲继续播放，携带世界名进入战斗场景。"""
	_play_click_sfx()
	_hide_confirm_dialog()
	if _confirm_world != "":
		# 预备曲已播放，直接切换到战斗场景（预备曲继续）
		get_tree().change_scene_to_file("res://scenes/game_board.tscn")


func _on_confirm_cancel() -> void:
	"""取消 → 停止预备曲，恢复菜单BGM。"""
	_play_click_sfx()
	_hide_confirm_dialog()
	if GlobalMusic:
		GlobalMusic.stop()
		GlobalMusic.play_menu()


# -- 按钮事件 ------------------------------------------------─

func _on_pve_pressed() -> void:
	"""人机对战 → 弹出确认出征对话框 + 播放预备曲。"""
	print("[Menu] 人机对战 - 选择世界")
	_play_click_sfx()
	
	if GlobalMusic:
		var world = GlobalMusic.pick_random_world()
		if world != "":
			_selected_world = world
			GlobalMusic.play_pre(world)
			_show_confirm_dialog(world)
		else:
			# 没有扫描到世界，直接进入
			get_tree().change_scene_to_file("res://scenes/game_board.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/game_board.tscn")


func _on_pvp_pressed() -> void:
	print("[Menu] 二人对战")
	_play_click_sfx()
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")


func _on_achieve_pressed() -> void:
	print("[Menu] 成就框")
	_play_click_sfx()
	if save_manager == null:
		_show_popup("成就", "成就系统加载中...")
		return
	
	var ach_list = save_manager.get_achievement_list()
	var body = "【成就列表】\n\n"
	for ach in ach_list:
		var status = "已解锁" if ach["unlocked"] else "未解锁"
		body += "%s  [%s]\n   %s\n\n" % [ach["name"], status, ach["desc"]]
	
	var total = ach_list.size()
	var unlocked_count = 0
	for ach in ach_list:
		if ach["unlocked"]:
			unlocked_count += 1
	
	body += "--------─\n"
	body += "解锁进度: %d/%d\n" % [unlocked_count, total]
	body += "总胜场: %d\n" % int(save_manager.stats.get("total_wins", 0))
	body += "总场次: %d" % int(save_manager.stats.get("total_games", 0))
	
	_show_popup("成就", body)


func _on_settings_pressed() -> void:
	print("[Menu] 设置")
	_play_click_sfx()
	var settings_scene = Control.new()
	settings_scene.set_script(load("res://scripts/settings_scene.gd"))
	settings_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(settings_scene)
	settings_scene.settings_closed.connect(_on_settings_done)


func _on_settings_done(s: Dictionary) -> void:
	print("[Menu] 设置已保存")


func _on_rules_pressed() -> void:
	_play_click_sfx()
	var mailbox = Control.new()
	mailbox.set_script(load("res://scripts/mailbox_scene.gd"))
	mailbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(mailbox)


func _on_guide_pressed() -> void:
	_play_click_sfx()
	var guide_text = "【玩法介绍】\n\n1. 背景故事：在植物温室花房，植物屡次击退强敌。花园主人们想通过植物对决证明自己实力。\n\n2. 阵营：54张植物分为4大阵营：法师(FA)、射手(SH)、坦克(TK)、辅助(FU)。三大阵营相互制约：法师克制射手，射手克制坦克，坦克克制法师。\n\n3. 精力系统：初始精力上限5点。出牌消耗精力，每回合自动补满。精力上限只能通过向日葵类卡牌（MANA效果）提升。\n\n4. 补牌回合：当玩家血量降至0以下时，进入濒死状态，玩家获得一次出牌机会以存活。\n\n5. 出牌规则：每回合允许出一张任意阵营卡牌，或一张三大阵营加一张辅助。精力消耗不超过当前精力值。\n\n6. 限制牌：卡牌左下角标记，决定该卡是否只能单独出牌。"
	_show_popup("玩法介绍", guide_text)


func _on_quit_pressed() -> void:
	_play_click_sfx()
	if GlobalMusic:
		GlobalMusic.stop()
	get_tree().quit()


# -- 工具函数 ------------------------------------------------─

func _play_click_sfx() -> void:
	if GlobalMusic:
		GlobalMusic.play_click_sfx()

func _load_settings() -> Dictionary:
	var s: Dictionary = {}
	var path = "user://settings.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				s = json.get_data()
			file.close()
	return s

func _load_player_info() -> void:
	var total_wins = 0
	if save_manager:
		total_wins = int(save_manager.stats.get("total_wins", 0))
	
	if PlayerProfile and PlayerProfile.is_registered():
		player_name_label.text = PlayerProfile.get_player_name()
		player_id_label.text = "ID: %s  胜场: %d" % [PlayerProfile.get_display_id(), total_wins]
	else:
		player_name_label.text = "植物训练师"
		player_id_label.text = "胜场: %d" % total_wins
