## 游戏战斗场景脚本
## 对应原 Python: main.py (run_game) + ui/renderer.py
## 完整实现：出牌、AI、结算、血条、精力、倒计时、游戏结束、先手选择
extends Control

# -- 先手选择对话框 ------------------------------------------─
var order_overlay: ColorRect
var order_panel: Panel
var order_first_btn: Button
var order_second_btn: Button
var first_player: String = "P1"
var _order_visible: bool = false
var _game_started: bool = false

# -- 节点引用 ------------------------------------------------─
@onready var p1_hand_container: HBoxContainer = $P1HandZone/P1HandContainer
@onready var p2_hand_container: HBoxContainer = $OpponentZone/P2HandContainer
@onready var p1_slot_container: HBoxContainer = $Battlefield/P1SlotContainer
@onready var p2_slot_container: HBoxContainer = $Battlefield/P2SlotContainer
@onready var history_area: HBoxContainer = $Battlefield/HistoryArea

@onready var p1_hp_bar: ProgressBar = $P1HPBar
@onready var p2_hp_bar: ProgressBar = $P2HPBar
@onready var p1_hp_label: Label = $P1HPLabel
@onready var p2_hp_label: Label = $P2HPLabel

@onready var timer_label: Label = $TimerLabel
@onready var round_label: Label = $RoundLabel
@onready var phase_hint: Label = $Battlefield/PhaseHint

@onready var deck_zone: Panel = $DeckZone
@onready var deck_label: Label = $DeckZone/DeckLabel
@onready var deck_hint: Label = $DeckZone/DeckHint

@onready var surrender_btn: Button = $SurrenderBtn
@onready var pause_btn: Button = $PauseBtn

@onready var game_overlay: ColorRect = $GameOverlay
@onready var game_over_title: Label = $GameOverlay/GameOverTitle
@onready var game_over_sub: Label = $GameOverlay/GameOverSub
@onready var game_over_btn: Button = $GameOverlay/GameOverBtn

@onready var pause_overlay: ColorRect = $PauseOverlay
@onready var resume_btn: Button = $PauseOverlay/ResumeBtn
@onready var back_menu_btn: Button = $PauseOverlay/BackMenuBtn

@onready var tooltip_panel: Panel = $TooltipPanel
@onready var tooltip_name: Label = $TooltipPanel/TooltipName
@onready var tooltip_meta: Label = $TooltipPanel/TooltipMeta
@onready var tooltip_desc: RichTextLabel = $TooltipPanel/TooltipDesc

@onready var toast_container: VBoxContainer = $ToastContainer

# -- 游戏状态 ------------------------------------------------─
var state_machine: Node
var card_loader_node: Node
var all_cards: Array[CardData] = []

var p1_hand: Array[CardData] = []
var p2_hand: Array[CardData] = []
var deck_cards: Array[CardData] = []
var p1_played: Array[CardData] = []
var p2_played: Array[CardData] = []
var p1_pending: Array[CardData] = []

var p1_hp: int = 10
var p2_hp: int = 10
var p1_max_hp: int = 10
var p2_max_hp: int = 10

var max_mana: int = 5
var current_mana: int = 5

var round_count: int = 1
var phase: String = "PLAY_P1"
var phase_timer: float = 0.0
var phase_timeout: float = 90.0
var time_left: float = 90.0

var ai_timer: float = 0.0
var ai_delay: float = 3.0
var round_end_timer: float = 0.0
var round_end_delay: float = 0.6

var winner: String = ""
var history: Array = []

# 效果系统
var effect_system: Node
var game_state: Dictionary = {}

# -- 动画/特效 --
var hover_particles: Node2D      # 悬停粒子
var deal_anim: Node               # 发牌动画
var _deal_pending: bool = false   # 发牌动画进行中

# -- 牌库视觉 --
var _deck_back_nodes: Array = []  # 牌库卡背节点列表
var _deck_hovering: bool = false  # 鼠标是否悬停牌库
var _long_press_timer: float = 0.0  # 长按计时器
var _long_press_threshold: float = 0.5  # 长按阈值(秒)
var _long_pressing_card: CardData = null  # 当前长按的卡牌
var _deck_tooltip: Label = null   # 牌库数量提示
var _draw_anim_pending: bool = false  # 补牌动画进行中
var _draw_phase: String = ""         # "deal"=开局发牌, "draw"=回合补牌

var _remedy_queue: Array = []    # 补救队列：["P2","P1"] 或 ["P1"] 或 ["P2"]

var paused: bool = false
var pause_time_accumulated: float = 0.0

# 成就
var save_manager: Node
var used_card_ids: Array = []

# -- 联机模式 --------------------------------------------------
var is_online: bool = false
var network_role: String = ""  # "", "host", "client"
var _waiting_for_first_choice: bool = false  # Client 等待 Host 选择先手

# Client 模式状态
var remote_state: Dictionary = {}
var p2_pending_ids: Array[int] = []  # Client 预选卡牌 ID
var _sync_timer: float = 0.0
var _sync_interval: float = 0.1  # 状态同步间隔（秒）
var _online_label: Label = null

# 卡牌场景
var card_scene: PackedScene

# -- 阵营颜色 ------------------------------------------------─
const FACTION_COLORS: Dictionary = {
	"法": Color(0.54, 0.17, 0.88),
	"射": Color(0.12, 0.56, 1.0),
	"坦": Color(0.63, 0.32, 0.18),
	"辅": Color(1.0, 0.84, 0.0),
}

func _ready() -> void:
	# 监听大厅连接成功信号
	if get_parent() != null and get_parent().has_signal("lobby_connected"):
		get_parent().lobby_connected.connect(_on_lobby_connected)
	
	# 检测联机模式
	if GlobalNet and GlobalNet.is_online():
		is_online = true
		network_role = GlobalNet.role
		print("[GameBoard] 联机模式: %s" % network_role)
	
	# Client 监听先手选择信号
	if is_online and network_role == "client" and GlobalNet.client_node:
		if GlobalNet.client_node.has_signal("first_player_received"):
			GlobalNet.client_node.first_player_received.connect(_on_first_player_received)
	
	# 隐藏界面
	game_overlay.visible = false
	pause_overlay.visible = false
	tooltip_panel.visible = false
	
	# 连接按钮
	surrender_btn.pressed.connect(_on_surrender)
	pause_btn.pressed.connect(_on_pause)
	game_over_btn.pressed.connect(_on_game_over_btn)
	resume_btn.pressed.connect(_on_resume)
	back_menu_btn.pressed.connect(_on_back_menu)
	# 连接牌库点击
	deck_zone.gui_input.connect(_on_deck_gui_input)
	
	# 加载卡牌
	card_loader_node = Node.new()
	card_loader_node.set_script(load("res://scripts/card_loader.gd"))
	add_child(card_loader_node)
	all_cards = card_loader_node.load_cards()
	
	# 加载成就管理器
	save_manager = Node.new()
	save_manager.set_script(load("res://scripts/save_manager.gd"))
	add_child(save_manager)
	
	# 加载效果系统
	effect_system = Node.new()
	effect_system.set_script(load("res://scripts/effect_system.gd"))
	add_child(effect_system)
	
	# 悬停粒子系统
	hover_particles = Node2D.new()
	hover_particles.set_script(load("res://scripts/card_hover_particles.gd"))
	hover_particles.z_index = 50
	add_child(hover_particles)
	
	# 发牌动画控制器
	deal_anim = Node.new()
	deal_anim.set_script(load("res://scripts/deal_animation.gd"))
	deal_anim._create_card_front_func = _deal_create_front
	deal_anim._create_card_back_func = _deal_create_back
	deal_anim.deal_finished.connect(_on_deal_finished)
	add_child(deal_anim)
	
	# 牌库数量提示标签（仅悬停时显示）
	_deck_tooltip = Label.new()
	_deck_tooltip.name = "DeckTooltip"
	var tip_font = load("res://assets/fonts/simhei.ttf")
	_deck_tooltip.add_theme_font_override("font", tip_font)
	_deck_tooltip.add_theme_font_size_override("font_size", 14)
	_deck_tooltip.add_theme_color_override("font_color", Color(1, 1, 0.8))
	_deck_tooltip.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	_deck_tooltip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_deck_tooltip.visible = false
	_deck_tooltip.z_index = 20
	add_child(_deck_tooltip)
	
	# 隐藏旧 DeckLabel（改用悬停提示）
	deck_label.visible = false
	# 先手选择对话框（预备曲继续播放）
	if is_online:
		_show_order_dialog_online()
	else:
		_show_order_dialog()

# -- 先手选择对话框（对应 Python OrderDialog）----------------─

func _show_order_dialog() -> void:
	"""弹出先手选择对话框，预备曲继续播放中。"""
	var font = load("res://assets/fonts/simhei.ttf")
	var dlg_w = 440
	var dlg_h = 300
	var dlg_x = (1024 - dlg_w) / 2
	var dlg_y = (768 - dlg_h) / 2
	
	# 半透明遮罩
	order_overlay = ColorRect.new()
	order_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	order_overlay.color = Color(0, 0, 0, 0.63)
	order_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 面板 — 深蓝灰底 对应 Python (50,50,80)
	order_panel = Panel.new()
	order_panel.position = Vector2(dlg_x, dlg_y)
	order_panel.size = Vector2(dlg_w, dlg_h)
	order_panel.self_modulate = Color(50.0/255, 50.0/255, 80.0/255)
	
	# 标题
	var title = Label.new()
	title.position = Vector2(0, 20)
	title.size = Vector2(dlg_w, 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 22)
	title.text = "⚔️  选择出牌顺序"
	order_panel.add_child(title)
	
	# 分隔线
	var sep = HSeparator.new()
	sep.position = Vector2(30, 58)
	sep.size = Vector2(dlg_w - 60, 2)
	order_panel.add_child(sep)
	
	# 先手说明
	var first_label = Label.new()
	first_label.position = Vector2(dlg_w/2 - 140, 78)
	first_label.size = Vector2(130, 28)
	first_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	first_label.add_theme_font_override("font", font)
	first_label.add_theme_font_size_override("font_size", 17)
	first_label.add_theme_color_override("font_color", Color(130.0/255, 1.0, 130.0/255))
	first_label.text = "先手出牌"
	order_panel.add_child(first_label)
	
	var first_desc = Label.new()
	first_desc.position = Vector2(dlg_w/2 - 140, 108)
	first_desc.size = Vector2(130, 24)
	first_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	first_desc.add_theme_font_override("font", font)
	first_desc.add_theme_font_size_override("font_size", 13)
	first_desc.add_theme_color_override("font_color", Color(180.0/255, 180.0/255, 200.0/255))
	first_desc.text = "您先出牌，AI后出"
	order_panel.add_child(first_desc)
	
	# 后手说明
	var second_label = Label.new()
	second_label.position = Vector2(dlg_w/2 + 10, 78)
	second_label.size = Vector2(130, 28)
	second_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	second_label.add_theme_font_override("font", font)
	second_label.add_theme_font_size_override("font_size", 17)
	second_label.add_theme_color_override("font_color", Color(130.0/255, 180.0/255, 1.0))
	second_label.text = "后手出牌"
	order_panel.add_child(second_label)
	
	var second_desc = Label.new()
	second_desc.position = Vector2(dlg_w/2 + 10, 108)
	second_desc.size = Vector2(130, 24)
	second_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	second_desc.add_theme_font_override("font", font)
	second_desc.add_theme_font_size_override("font_size", 13)
	second_desc.add_theme_color_override("font_color", Color(180.0/255, 180.0/255, 200.0/255))
	second_desc.text = "AI先出牌，您后出"
	order_panel.add_child(second_desc)
	
	# 提示文字
	var hint = Label.new()
	hint.position = Vector2(0, 150)
	hint.size = Vector2(dlg_w, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", font)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(1.0, 215.0/255, 0))
	hint.text = "选择将决定整场比赛的出牌顺序"
	order_panel.add_child(hint)
	
	# 按钮
	var btn_w = 150
	var btn_h = 50
	var btn_spacing = 40
	var total_btn_w = 2 * btn_w + btn_spacing
	var btn_start_x = (dlg_w - total_btn_w) / 2
	var btn_y = dlg_h - btn_h - 30
	
	# 先手按钮（绿色）
	order_first_btn = Button.new()
	order_first_btn.position = Vector2(btn_start_x, btn_y)
	order_first_btn.size = Vector2(btn_w, btn_h)
	order_first_btn.text = "🗡️ 先手"
	order_first_btn.add_theme_font_override("font", font)
	order_first_btn.add_theme_font_size_override("font_size", 16)
	order_first_btn.pressed.connect(_on_order_first)
	order_panel.add_child(order_first_btn)
	
	# 后手按钮（蓝色）
	order_second_btn = Button.new()
	order_second_btn.position = Vector2(btn_start_x + btn_w + btn_spacing, btn_y)
	order_second_btn.size = Vector2(btn_w, btn_h)
	order_second_btn.text = "🛡️ 后手"
	order_second_btn.add_theme_font_override("font", font)
	order_second_btn.add_theme_font_size_override("font_size", 16)
	order_second_btn.pressed.connect(_on_order_second)
	order_panel.add_child(order_second_btn)
	
	order_overlay.add_child(order_panel)
	add_child(order_overlay)
	_order_visible = true


func _on_order_first() -> void:
	"""选择先手 → 预备曲停止，切换到游戏BGM，开始游戏。"""
	first_player = "P1"
	if GlobalMusic:
		GlobalMusic.play_click_sfx()
	_order_visible = false
	order_overlay.queue_free()
	# 预备曲 → 游戏BGM（同一世界）
	_start_game_music()
	# 初始化牌局
	_start_game()
	# 发送先手选择给 Client
	if network_role == "host" and is_online:
		print("[GameBoard] Host 准备发送先手选择... GlobalNet.host_node=%s" % str(GlobalNet.host_node != null))
		if GlobalNet.host_node:
			print("[GameBoard]   host_node._peer=%s _client_connected=%s" % [str(GlobalNet.host_node._peer != null), str(GlobalNet.host_node._client_connected)])
		_send_first_player("P1")


func _on_order_second() -> void:
	"""选择后手 → AI先手。"""
	first_player = "P2"
	if GlobalMusic:
		GlobalMusic.play_click_sfx()
	_order_visible = false
	order_overlay.queue_free()
	_start_game_music()
	_start_game()
	_start_game()
	# 发送先手选择给 Client
	if network_role == "host" and is_online:
		_send_first_player("P2")

func _send_first_player(choice: String) -> void:
	"""发送先手选择给 Client"""
	if not is_online or network_role != "host":
		return
	
	var msg = NetProtocol.make_message("FIRST_PLAYER", {"first_player": choice})
	if GlobalNet.host_node and GlobalNet.host_node._peer:
		GlobalNet.host_node._peer.put_data(msg.to_utf8_buffer())
		print("[GameBoard] 发送先手选择: %s" % choice)
	else:
		print("[GameBoard] 无法发送先手选择: GlobalNet.host_node 或 _peer 为空")
# -- 联机先手选择 --------------------------------------------─

func _show_order_dialog_online() -> void:
	"""联机模式先手选择：Host/P1 先手按钮，Client/P2 后手按钮。"""
	var fnt = load("res://assets/fonts/simhei.ttf")
	var dlg_w = 440
	var dlg_h = 300
	var dlg_x = (1024 - dlg_w) / 2
	var dlg_y = (768 - dlg_h) / 2
	
	order_overlay = ColorRect.new()
	order_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	order_overlay.color = Color(0, 0, 0, 0.63)
	order_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	order_panel = Panel.new()
	order_panel.position = Vector2(dlg_x, dlg_y)
	order_panel.size = Vector2(dlg_w, dlg_h)
	order_panel.self_modulate = Color(50.0/255, 50.0/255, 80.0/255)
	
	var title = Label.new()
	title.position = Vector2(0, 20)
	title.size = Vector2(dlg_w, 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", fnt)
	title.add_theme_font_size_override("font_size", 22)
	title.text = "🌐 联机对战 — 选择先手"
	order_panel.add_child(title)
	
	var sep = HSeparator.new()
	sep.position = Vector2(30, 58)
	sep.size = Vector2(dlg_w - 60, 2)
	order_panel.add_child(sep)
	
	var role_label = Label.new()
	role_label.position = Vector2(0, 75)
	role_label.size = Vector2(dlg_w, 28)
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_label.add_theme_font_override("font", fnt)
	role_label.add_theme_font_size_override("font_size", 16)
	role_label.add_theme_color_override("font_color", Color(100.0/255, 200.0/255, 1.0))
	if network_role == "host":
		role_label.text = "你是 P1（房主）"
	else:
		role_label.text = "你是 P2（加入方）"
	order_panel.add_child(role_label)
	
	# 联机模式：Host 直接决定先手
	var hint = Label.new()
	hint.position = Vector2(0, 110)
	hint.size = Vector2(dlg_w, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", fnt)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(1.0, 215.0/255, 0))
	if network_role == "host":
		hint.text = "请选择先手顺序（对方将跟随）"
	else:
		hint.text = "等待房主选择先手..."
	order_panel.add_child(hint)
	
	var btn_w = 150
	var btn_h = 50
	var btn_spacing = 40
	var total_btn_w = 2 * btn_w + btn_spacing
	var btn_start_x = (dlg_w - total_btn_w) / 2
	var btn_y = dlg_h - btn_h - 30
	
	if network_role == "host":
		order_first_btn = Button.new()
		order_first_btn.position = Vector2(btn_start_x, btn_y)
		order_first_btn.size = Vector2(btn_w, btn_h)
		order_first_btn.text = "🗡️ 先手"
		order_first_btn.add_theme_font_override("font", fnt)
		order_first_btn.add_theme_font_size_override("font_size", 16)
		order_first_btn.pressed.connect(_on_order_first)
		order_panel.add_child(order_first_btn)
		
		order_second_btn = Button.new()
		order_second_btn.position = Vector2(btn_start_x + btn_w + btn_spacing, btn_y)
		order_second_btn.size = Vector2(btn_w, btn_h)
		order_second_btn.text = "🛡️ 后手"
		order_second_btn.add_theme_font_override("font", fnt)
		order_second_btn.add_theme_font_size_override("font_size", 16)
		order_second_btn.pressed.connect(_on_order_second)
		order_panel.add_child(order_second_btn)
	else:
		# Client: 等待 Host 决定先手
		_waiting_for_first_choice = true
		var wait_label = Label.new()
		wait_label.position = Vector2(0, btn_y + 10)
		wait_label.size = Vector2(dlg_w, 30)
		wait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wait_label.add_theme_font_override("font", fnt)
		wait_label.add_theme_font_size_override("font_size", 15)
		wait_label.add_theme_color_override("font_color", Color(180.0/255, 200.0/255, 220.0/255))
		wait_label.text = "等待中..."
		wait_label.name = "WaitLabel"
		order_panel.add_child(wait_label)
	
	order_overlay.add_child(order_panel)
	add_child(order_overlay)
	_order_visible = true
	
	# Client 模式：发送等待状态，然后立即从 Host 接收先手决定
	if network_role == "client":
		_wait_for_host_start()

func _wait_for_host_start() -> void:
	"""Client 等待 Host 发送游戏状态。"""
	# 发送准备就绪
	if GlobalNet.client_node:
		GlobalNet.client_node.send_action("ready", {})
		print("[GameBoard] Client 已发送 ready，等待 Host 状态...")
	else:
		print("[GameBoard] Client 错误: GlobalNet.client_node 为空!")
	
	# 等待第一个有效状态
	var wait_frames = 0
	while true:
		await get_tree().process_frame
		wait_frames += 1
		
		# 每60帧打印一次调试信息
		if wait_frames % 60 == 0:
			print("[GameBoard] Client 等待中... 帧=%d client_node=%s" % [wait_frames, str(GlobalNet.client_node != null)])
			if GlobalNet.client_node:
				var s = GlobalNet.client_node.get_latest_state()
				print("[GameBoard]   latest_state size=%d phase=%s" % [s.size(), str(s.get("phase", ""))])
		
		# 检查退出
		if not is_instance_valid(self):
			return
		
		if GlobalNet.client_node:
			var state = GlobalNet.client_node.get_latest_state()
			if state.size() > 0 and state.get("phase", "") != "WAITING" and state.get("phase", "") != "":
				# 收到游戏状态，先从状态中读取先手
				first_player = state.get("first_player", "P1")
				# 同步世界音乐
				var recv_world = str(state.get("world", ""))
				if recv_world != "" and GlobalNet:
					GlobalNet.world = recv_world
				if recv_world != "" and GlobalMusic:
					GlobalMusic.play_pre(recv_world)
				remote_state = state
				_order_visible = false
				if order_overlay:
					order_overlay.queue_free()
				_start_game_music()
				_start_game_online_client()
				return
		
		if wait_frames > 3600:  # 60秒超时
			_show_toast("等待超时，连接可能已断开")
			_on_back_menu()
			return


# -- 联机 Host 模式 --------------------------------------------─

func _serialize_history() -> Array:
	"""将 history 数组序列化为可传输的 JSON 格式。"""
	var result: Array = []
	for entry in history:
		var serialized: Dictionary = {}
		serialized["P1"] = NetProtocol.serialize_cards(entry.get("P1", []))
		serialized["P2"] = NetProtocol.serialize_cards(entry.get("P2", []))
		result.append(serialized)
	return result

func _send_state_to_client() -> void:
	"""Host 每帧同步状态给 Client。"""
	if not GlobalNet.host_node or not GlobalNet.host_node.is_client_connected():
		return
	
	var state := {
		"phase": phase,
		"time_left": time_left,
		"winner": winner,
		"round_count": round_count,
		"first_player": first_player,
		"world": GlobalNet.world if is_online else "",
		"players": {
			"P1": {
				"hp": p1_hp, "max_hp": p1_max_hp,
				"max_mana": max_mana, "current_mana": current_mana,
				"buffs": game_state.get("players", {}).get("P1", {}).get("buffs", []),
			},
			"P2": {
				"hp": p2_hp, "max_hp": p2_max_hp,
				"max_mana": int(game_state.get("players", {}).get("P2", {}).get("max_mana", 5)),
				"current_mana": int(game_state.get("players", {}).get("P2", {}).get("current_mana", 5)),
				"buffs": game_state.get("players", {}).get("P2", {}).get("buffs", []),
			},
		},
		"hands": {
			"P1": NetProtocol.serialize_cards(p1_hand, true),   # 对 Client 隐藏
			"P2": NetProtocol.serialize_cards(p2_hand),           # Client 自己的手牌
		},
		"played_cards": {
			"P1": NetProtocol.serialize_cards(p1_played),
			"P2": NetProtocol.serialize_cards(p2_played),
		},
		"pending_play": {
			"P1": NetProtocol.serialize_cards(p1_pending),
			"P2": NetProtocol.serialize_cards(p2_played),  # 简化：P2 已出的牌
		},
		"history": _serialize_history(),
		"deck_size": deck_cards.size(),
		"toasts": [],
		"temp": game_state.get("temp", {}),
	}
	GlobalNet.host_node.send_state(state)

func _poll_host_actions() -> void:
	"""Host 获取 Client(P2) 的操作，替代 AI。"""
	if not GlobalNet.host_node:
		return
	var actions = GlobalNet.host_node.poll_actions()
	for action in actions:
		var act: String = str(action.get("action", ""))
		if act == "play_card":
			var card_id: int = int(action.get("card_id", -1))
			_host_p2_play_card(card_id)
		elif act == "finish_turn" or act == "finish_turn_with_commit":
			_host_p2_finish_turn()
		elif act == "remedy_play_card":
			var card_id: int = int(action.get("card_id", -1))
			_host_p2_remedy(card_id)
		elif act == "mana_update":
			# Bug 3 修复：实时更新 Client(P2) 精力显示
			var cli_cur: int = int(action.get("current_mana", 5))
			var cli_max: int = int(action.get("max_mana", 5))
			if not game_state.has("players"):
				game_state["players"] = {"P1": {}, "P2": {}}
			game_state["players"]["P2"]["current_mana"] = cli_cur
			game_state["players"]["P2"]["max_mana"] = cli_max
			# 实时刷新 P2 精力点阵
			_refresh_mana_dots($P2ManaDots, cli_cur, cli_max)

func _host_p2_play_card(card_id: int) -> void:
	"""Host 收到 Client 出牌指令，从 P2 手牌中找到对应卡牌出牌。"""
	if phase != "PLAY_P2":
		return
	var found: CardData = null
	for card in p2_hand:
		if card.id == card_id:
			found = card
			break
	if found == null:
		return
	# P2 出牌（不需要检查精力，Host 信任 Client 的本地验证）
	p2_hand.erase(found)
	p2_played.append(found)

func _host_p2_finish_turn() -> void:
	"""Host 收到 Client 结束出牌指令。"""
	if phase != "PLAY_P2":
		return
	_advance_after_ai()

func _host_p2_remedy(card_id: int) -> void:
	"""Host 收到 Client 补救出牌（对齐 Python _remedy_resolve 回溯结算）。"""
	if phase != "REMEDY_AI":
		return
	var found: CardData = null
	for card in p2_hand:
		if card.id == card_id and _is_rescue_card_p2(card):
			found = card
			break
	if found == null:
		return
	var remedy_info: Dictionary = game_state.get("remedy", {}).get("P2", {})
	if remedy_info.is_empty():
		winner = "P1"
		_change_phase("GAME_OVER")
		return
	var before_hp: int = int(remedy_info.get("before_hp", 0))
	var damage_taken: int = int(remedy_info.get("damage_taken", 0))
	var current_hp: int = before_hp - damage_taken
	var eid: String = found.effect_id
	var final_hp: int = current_hp

	# -- 回溯结算 ---
	if eid.begins_with("HEAL") or eid == "COST_TO_HEAL" or eid == "COST_TO_HEAL_SELF" or eid == "ATK_TO_HEAL" or eid == "BOOST_ATK_HEAL":
		var heal_val: int = _get_remedy_heal_value_p2(found)
		final_hp = mini(p2_max_hp, current_hp + heal_val)
	elif eid == "SHIELD_TURN" or eid == "ATK_DISABLE" or eid == "SILENCE_ATTACK":
		final_hp = before_hp
	elif eid == "REFLECT_ATK":
		final_hp = before_hp
		var opp_hp: int = p1_hp
		p1_hp = maxi(0, opp_hp - damage_taken)
		game_state["players"]["P1"]["hp"] = p1_hp
	elif eid == "REDUCE_DMG_2" or eid == "DMG_REDUCE_2":
		var reduced_dmg: int = maxi(0, damage_taken - 2)
		final_hp = before_hp - reduced_dmg
	elif eid.begins_with("SHIELD"):
		var shield_val: int = _get_shield_value_from_eid(eid)
		var remaining: int = maxi(0, damage_taken - shield_val)
		final_hp = before_hp - remaining
	else:
		final_hp = before_hp

	final_hp = mini(p2_max_hp, final_hp)
	p2_hp = final_hp
	game_state["players"]["P2"]["hp"] = final_hp
	p2_hand.erase(found)
	_show_toast("🌐 对手补救成功！HP恢复至 %d" % final_hp)
	if final_hp <= 0:
		winner = "P1"
		_change_phase("GAME_OVER")
		return
	game_state.erase("remedy")
	# P2 补救成功，检查队列中是否还有 P1 待补救
	_remedy_queue.erase("P2")
	if _remedy_queue.has("P1") and p1_hp <= 0:
		_show_toast("⚠️ 您也濒死了！请打出治疗卡自救！")
		_change_phase("REMEDY")
		return
	_change_phase("ROUND_END")


# -- 联机 Client 模式 --------------------------------------------─

func _start_game_online_client() -> void:
	"""Client 模式初始化：用 Host 的状态初始化本地游戏，体验和 Host 一致。"""
	_game_started = true
	
	# 从 remote_state 读取先手
	if _waiting_for_first_choice:
		first_player = remote_state.get("first_player", "P1")
		_waiting_for_first_choice = false
	
	# 加载卡牌数据（发牌动画需要）
	card_loader_node = Node.new()
	card_loader_node.set_script(load("res://scripts/card_loader.gd"))
	add_child(card_loader_node)
	all_cards = card_loader_node.load_cards()
	
	# 创建效果系统
	effect_system = Node.new()
	effect_system.set_script(load("res://scripts/effect_system.gd"))
	add_child(effect_system)
	
	# 加载成就管理器
	save_manager = Node.new()
	save_manager.set_script(load("res://scripts/save_manager.gd"))
	add_child(save_manager)
	
	# 悬停粒子系统
	hover_particles = Node2D.new()
	hover_particles.set_script(load("res://scripts/card_hover_particles.gd"))
	hover_particles.z_index = 50
	add_child(hover_particles)
	
	# 从 remote_state 恢复游戏状态
	var rplayers: Dictionary = remote_state.get("players", {})
	var p2_data: Dictionary = rplayers.get("P2", {})
	var p1_data: Dictionary = rplayers.get("P1", {})
	
	p1_hp = int(p1_data.get("hp", 10))
	p1_max_hp = int(p1_data.get("max_hp", 10))
	p2_hp = int(p2_data.get("hp", 10))
	p2_max_hp = int(p2_data.get("max_hp", 10))
	max_mana = int(p2_data.get("max_mana", 5))
	current_mana = int(p2_data.get("current_mana", 5))
	
	p1_hand = NetProtocol.deserialize_cards(remote_state.get("hands", {}).get("P1", []))
	p2_hand = NetProtocol.deserialize_cards(remote_state.get("hands", {}).get("P2", []))
	p1_played = NetProtocol.deserialize_cards(remote_state.get("played_cards", {}).get("P1", []))
	p2_played = NetProtocol.deserialize_cards(remote_state.get("played_cards", {}).get("P2", []))
	
	deck_cards.clear()
	var deck_size: int = int(remote_state.get("deck_size", 0))
	for i in range(deck_size):
		var dummy = CardData.new()
		deck_cards.append(dummy)
	
	round_count = int(remote_state.get("round_count", 1))
	winner = str(remote_state.get("winner", ""))
	
	game_state = {
		"players": {
			"P1": {"hp": p1_hp, "max_hp": p1_max_hp, "max_mana": int(p1_data.get("max_mana", 5)), "current_mana": int(p1_data.get("current_mana", 5)), "buffs": []},
			"P2": {"hp": p2_hp, "max_hp": p2_max_hp, "max_mana": max_mana, "current_mana": current_mana, "buffs": []},
		},
		"hands": {"P1": p1_hand, "P2": p2_hand},
		"played_cards": {"P1": p1_played, "P2": p2_played},
		"temp": {},
		"control_effects": {},
	}
	
	# 联机标识
	_online_label = Label.new()
	_online_label.position = Vector2(10, 10)
	_online_label.size = Vector2(300, 20)
	_online_label.add_theme_font_override("font", load("res://assets/fonts/simhei.ttf"))
	_online_label.add_theme_font_size_override("font_size", 14)
	_online_label.add_theme_color_override("font_color", Color(100.0/255, 200.0/255, 1.0))
	_online_label.text = "🌐 联机对战 - 你是 P2（Client）"
	add_child(_online_label)
	
	# 设置 phase
	phase = str(remote_state.get("phase", "PLAY_P2"))
	
	# 播放发牌动画（和 Host 一样）
	_show_toast("🌐⚔️ 战斗开始！%s先手" % ("你" if first_player == "P2" else "对手"))
	_start_deal_animation()

func _render_remote_state() -> void:
	"""Client 模式：从 remote_state 渲染界面。"""
	if remote_state.is_empty():
		return
	
	var rphase: String = str(remote_state.get("phase", ""))
	var rplayers: Dictionary = remote_state.get("players", {})
	var rhands: Dictionary = remote_state.get("hands", {})
	var rplayed: Dictionary = remote_state.get("played_cards", {})
	
	# 解析玩家状态
	var p1_data: Dictionary = rplayers.get("P1", {})
	var p2_data: Dictionary = rplayers.get("P2", {})
	
	p1_hp = int(p1_data.get("hp", 10))
	p1_max_hp = int(p1_data.get("max_hp", 10))
	p2_hp = int(p2_data.get("hp", 10))
	p2_max_hp = int(p2_data.get("max_hp", 10))
	max_mana = int(p2_data.get("max_mana", 5))  # Client 的精力 = P2
	current_mana = int(p2_data.get("current_mana", 5))
	
	# 解析手牌 — P2 是自己的（显示），P1 是对手的（隐藏）
	p2_hand = NetProtocol.deserialize_cards(rhands.get("P2", []))
	p1_hand = NetProtocol.deserialize_cards(rhands.get("P1", []))  # 这些是 hidden 卡
	p1_played = NetProtocol.deserialize_cards(rplayed.get("P1", []))
	p2_played = NetProtocol.deserialize_cards(rplayed.get("P2", []))
	
	deck_cards.clear()
	var deck_size: int = int(remote_state.get("deck_size", 0))
	for i in range(deck_size):
		var dummy = CardData.new()
		deck_cards.append(dummy)
	
	round_count = int(remote_state.get("round_count", 0))
	phase = rphase
	winner = str(remote_state.get("winner", ""))
	
	# 同步 buffs 到 game_state
	if not game_state.has("players"):
		game_state["players"] = {"P1": {}, "P2": {}}
	game_state["players"]["P1"]["buffs"] = p1_data.get("buffs", [])
	game_state["players"]["P2"]["buffs"] = p2_data.get("buffs", [])
	# Bug 1 修复：同步 temp（沉默/破甲等状态标记）
	game_state["temp"] = remote_state.get("temp", {})
	game_state["players"]["P1"]["hp"] = p1_hp
	game_state["players"]["P1"]["max_hp"] = p1_max_hp
	game_state["players"]["P2"]["hp"] = p2_hp
	game_state["players"]["P2"]["max_hp"] = p2_max_hp
	game_state["players"]["P1"]["max_mana"] = int(p1_data.get("max_mana", 5))
	game_state["players"]["P1"]["current_mana"] = int(p1_data.get("current_mana", 5))
	game_state["players"]["P2"]["max_mana"] = max_mana
	game_state["players"]["P2"]["current_mana"] = current_mana
	
	# Bug 3 修复：同步历史出牌记录
	var rhistory: Array = remote_state.get("history", [])
	history.clear()
	for hentry in rhistory:
		if hentry is Dictionary:
			history.append({
				"P1": NetProtocol.deserialize_cards(hentry.get("P1", [])),
				"P2": NetProtocol.deserialize_cards(hentry.get("P2", [])),
			})
	
	# 渲染 UI
	_refresh_all_ui()
	
	# 更新阶段提示
	match rphase:
		"PLAY_P2":
			_update_phase_hint("你的回合 - 点击手牌出牌 | 空格/点牌库结束")
			deck_hint.text = "点击结束出牌"
		"PLAY_P1":
			_update_phase_hint("对手出牌中...")
			deck_hint.text = "牌库"
		"RESOLVE":
			_update_phase_hint("结算中...")
		"ROUND_END":
			_update_phase_hint("回合结束...")
		"REMEDY_AI":
			_update_phase_hint("⚠️ 你已濒死！打出治疗卡自救！")
			deck_hint.text = "点击自救"
		"GAME_OVER":
			if winner != "":
				_show_game_over()
			else:
				_update_phase_hint(rphase)
		_:
			_update_phase_hint(rphase)
	
	_update_timer_ui()

func _client_play_card(card: CardData) -> void:
	"""Client 模式出牌：和 Host 操作完全一致，用 p1_pending 管理预出牌。"""
	if phase != "PLAY_P2" and phase != "REMEDY_AI":
		return
	# 防止重复出牌
	if card in p1_pending:
		return
	# 卡牌必须在手牌中
	if not card in p2_hand:
		return
	var card_cost: int = int(card.cost)
	if current_mana < card_cost:
		_show_toast("精力不足！")
		return
	
	# 出牌规则校验（复用 Host 逻辑）
	if phase == "PLAY_P2":
		if not _validate_play_card(card):
			return
	
	# 出牌：和 Host 完全一样的操作
	current_mana -= card_cost
	p2_hand.erase(card)
	p1_pending.append(card)  # Client 视角翻转，预出牌放 p1_pending
	if not card.id in used_card_ids:
		used_card_ids.append(card.id)
	_refresh_all_ui()
	_play_sfx()
	# Bug 3 修复：实时同步精力给 Host
	_send_client_mana_update()
	
	if phase == "REMEDY_AI":
		# 补救直接发送
		if GlobalNet.client_node:
			GlobalNet.client_node.send_action("remedy_play_card", {"card_id": card.id})
		p1_pending.clear()

func _client_finish_turn() -> void:
	"""Client 结束出牌：发送所有预选牌给 Host。"""
	if phase != "PLAY_P2":
		return
	if p1_pending.size() == 0:
		_show_toast("请先出牌再结束！")
		return
	if GlobalNet.client_node:
		# 发送所有预选卡牌的 ID
		for card in p1_pending:
			GlobalNet.client_node.send_action("play_card", {"card_id": card.id})
		p1_pending.clear()
		GlobalNet.client_node.send_action("finish_turn_with_commit")
	_update_phase_hint("已结束出牌，等待对手...")


func _send_client_mana_update() -> void:
	"""Bug 3 修复：Client 实时同步当前精力给 Host，让 Host 看到 P2 精力变化。"""
	if not is_online or network_role != "client":
		return
	if GlobalNet.client_node:
		GlobalNet.client_node.send_action("mana_update", {
			"current_mana": current_mana,
			"max_mana": max_mana,
		})

func _start_game() -> void:
	var deck = all_cards.duplicate()
	deck.shuffle()
	if deck.size() > 54:
		deck = deck.slice(0, 54)
	
	deck.shuffle()
	p1_hand = deck.slice(0, 5)
	p2_hand = deck.slice(5, 10)
	deck_cards = deck.slice(10, deck.size())
	
	p1_hp = 10
	p2_hp = 10
	p1_max_hp = 10
	p2_max_hp = 10
	max_mana = 5
	current_mana = max_mana
	round_count = 1
	winner = ""
	history.clear()
	game_state = {
		"players": {
			"P1": {"hp": 10, "max_hp": 10, "max_mana": 5, "current_mana": 5, "buffs": []},
			"P2": {"hp": 10, "max_hp": 10, "max_mana": 5, "current_mana": 5, "buffs": []},
		},
		"hands": {"P1": p1_hand, "P2": p2_hand},
		"played_cards": {"P1": [], "P2": []},
		"temp": {},
		"control_effects": {},
	}
	
	_change_phase("PLAY_P1" if first_player == "P1" else "PLAY_P2")
	var online_tag = "🌐 联机" if is_online else ""
	_show_toast("%s⚔️ 战斗开始！%s先手 — 六阶段结算引擎已加载" % [online_tag, "玩家" if first_player == "P1" else "AI" if not is_online else "对手"])
	
	# 联机 Host：发送初始状态
	if is_online and network_role == "host":
		_send_state_to_client()
		_online_label = Label.new()
		_online_label.position = Vector2(10, 10)
		_online_label.size = Vector2(300, 20)
		_online_label.add_theme_font_override("font", load("res://assets/fonts/simhei.ttf"))
		_online_label.add_theme_font_size_override("font_size", 14)
		_online_label.add_theme_color_override("font_color", Color(100.0/255, 200.0/255, 1.0))
		_online_label.text = "🌐 联机对战 - 你是 P1（Host）"
		add_child(_online_label)
	
	# 启动发牌动画
	_start_deal_animation()

func _start_game_music() -> void:
	"""进入战斗场景后，从阵前曲切换到游戏BGM。"""
	if GlobalMusic:
		GlobalMusic.update_settings(_load_settings_dict())
		var world = ""
		
		# 联机模式：用 GlobalNet.world（Host 选定的世界）
		if is_online and GlobalNet and GlobalNet.world != "":
			world = GlobalNet.world
		elif GlobalMusic.get_current_world() != "":
			world = GlobalMusic.get_current_world()
		
		if world != "":
			GlobalMusic.play_game(world)
		else:
			# 兜底：随机选一个世界
			world = GlobalMusic.pick_random_world()
			if world != "":
				GlobalMusic.play_game(world)

func _load_settings_dict() -> Dictionary:
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

# -- 发牌动画 ------------------------------------------------─

func _start_deal_animation() -> void:
	"""先手选择后，从牌库发5张牌到玩家手牌区，动画完成后才进入出牌。"""
	_deal_pending = true
	_draw_phase = "deal"
	
	# 先清空手牌显示
	for child in p1_hand_container.get_children():
		child.queue_free()
	
	# 计算牌库全局位置（动画起点，牌库中心）
	var deck_global: Vector2 = deck_zone.global_position + Vector2(deck_zone.size.x / 2.0 - 30.0, deck_zone.size.y / 2.0 - 42.0)
	
	# 计算5张牌的目标位置（手牌区中，从左到右排列）
	var hand_positions: Array = []
	var card_w: float = 80.0
	var sep: float = 16.0
	var start_x: float = p1_hand_container.global_position.x + 10
	var start_y: float = p1_hand_container.global_position.y + 10
	# Client 模式发牌用 p2_hand（自己的手牌显示在 p1_hand_container）
	var deal_hand: Array = p1_hand
	if is_online and network_role == "client":
		deal_hand = p2_hand
	
	for i in range(deal_hand.size()):
		hand_positions.append(Vector2(start_x + i * (card_w + sep), start_y))
	
	deal_anim.start_deal(deal_hand, deck_global, hand_positions, self)
	_update_phase_hint("发牌中...")
	deck_hint.text = "发牌中..."

func _on_deal_finished() -> void:
	"""发牌/补牌动画结束，根据阶段执行对应逻辑。"""
	if _draw_phase == "draw":
		# 补牌动画结束
		_on_draw_anim_finished()
		return
	# 开局发牌动画结束
	_deal_pending = false
	
	# Client 模式：从 Host 最新状态渲染
	if is_online and network_role == "client":
		if GlobalNet.client_node:
			var new_state = GlobalNet.client_node.get_latest_state()
			if new_state.size() > 0:
				remote_state = new_state
				_render_remote_state()
				return
		_show_toast("🃏 发牌完成！")
		return
	
	# Host / 本地模式
	_refresh_all_ui()
	_update_phase_hint("点击手牌出牌 | 空格/点牌库结束出牌")
	deck_hint.text = "点击结束出牌"
	_show_toast("🃏 发牌完成，开始出牌！")

func _deal_create_front(card_data: CardData) -> Control:
	"""发牌动画用：创建正面卡牌。"""
	return _create_card_button(card_data, false)

func _deal_create_back() -> Control:
	"""发牌动画用：创建卡背。"""
	return _create_card_back()

# -- 牌库悬停提示 ----------------------------------------------

func _update_deck_hover() -> void:
	"""每帧检测鼠标是否悬停牌库，显示/隐藏数量提示。"""
	if _deck_tooltip == null:
		return
	var mouse_pos: Vector2 = get_global_mouse_position()
	var zone_rect: Rect2 = Rect2(deck_zone.global_position, deck_zone.size)
	var was_hovering: bool = _deck_hovering
	_deck_hovering = zone_rect.has_point(mouse_pos)
	_deck_tooltip.visible = _deck_hovering and deck_cards.size() > 0
	if _deck_hovering:
		_deck_tooltip.text = "剩余 %d 张" % deck_cards.size()

# -- 补牌动画 --------------------------------------------------

## 开始补牌动画（在 _next_round 中调用，牌从牌库飞向手牌区再翻面）
func _start_draw_animation(cards_to_draw: Array) -> void:
	_draw_anim_pending = true
	_draw_phase = "draw"
	
	# 计算牌库全局位置（动画起点）
	var deck_global: Vector2 = deck_zone.global_position + Vector2(deck_zone.size.x / 2.0, deck_zone.size.y / 2.0)
	
	# 计算目标位置（手牌区中已有牌之后的空位）
	var existing_count: int = p1_hand.size() - cards_to_draw.size()  # 已有手牌数
	var card_w: float = 80.0
	var sep: float = 16.0
	var start_x: float = p1_hand_container.global_position.x + 10
	var start_y: float = p1_hand_container.global_position.y + 10
	var hand_positions: Array = []
	for i in range(cards_to_draw.size()):
		hand_positions.append(Vector2(start_x + (existing_count + i) * (card_w + sep), start_y))
	
	deck_hint.text = "补牌中..."
	_update_phase_hint("🃏 补牌中...")
	
	# 复用 deal_anim（发牌动画控制器）
	deal_anim.start_deal(cards_to_draw, deck_global, hand_positions, self)
	# 等待 deal_finished 信号，由 _on_draw_anim_finished 处理

## 补牌动画结束回调
func _on_draw_anim_finished() -> void:
	_draw_anim_pending = false
	_refresh_deck()  # 更新牌库视觉
	_advance_to_play_phase()

## 根据 first_player 推进到出牌阶段
func _advance_to_play_phase() -> void:
	# 任一方无牌可出（手牌+牌库都空）→ 按血量判定胜负
	var p1_no_cards: bool = p1_hand.is_empty() and deck_cards.is_empty()
	var p2_no_cards: bool = p2_hand.is_empty() and deck_cards.is_empty()
	if p1_no_cards or p2_no_cards:
		if p1_hp > p2_hp:
			winner = "P1"
		elif p2_hp > p1_hp:
			winner = "P2"
		else:
			winner = "DRAW"
		_change_phase("GAME_OVER")
		return
	_refresh_all_ui()
	if first_player == "P1":
		_change_phase("PLAY_P1")
	else:
		_change_phase("PLAY_P2")

# -- 悬停粒子特效 ----------------------------------------------

func _update_hover_particles() -> void:
	"""每帧检测鼠标悬停的卡牌，生成阵营色四角星粒子。"""
	if not hover_particles or _deal_pending:
		return
	
	var mouse_pos: Vector2 = get_global_mouse_position()
	
	# 检测 P1 手牌悬停
	var hand_cards: Array = p1_hand
	if is_online and network_role == "client":
		hand_cards = p2_hand  # Client 模式底部是 P2
	
	for i in range(hand_cards.size()):
		var child_count = p1_hand_container.get_child_count()
		if i >= child_count:
			break
		var card_btn = p1_hand_container.get_child(i) as Control
		if card_btn == null:
			continue
		var card_rect := Rect2(card_btn.global_position, card_btn.size)
		if card_rect.grow(4).has_point(mouse_pos):
			# 获取阵营颜色
			var faction: String = hand_cards[i].faction
			var f_color: Color = FACTION_COLORS.get(faction, Color(1, 1, 1))
			hover_particles.add_particle(card_rect, f_color)

# -- 阶段管理 ------------------------------------------------─

func _change_phase(new_phase: String) -> void:
	phase = new_phase
	phase_timer = 0.0
	
	match new_phase:
		"PLAY_P1":
			current_mana = max_mana
			# 同步精力回满
			game_state["players"]["P1"]["current_mana"] = current_mana
			phase_timeout = 90.0
			time_left = 90.0
			p1_pending.clear()
			if is_online and network_role == "client":
				_update_phase_hint("对手出牌中...")
				deck_hint.text = "牌库"
			else:
				_update_phase_hint("点击手牌出牌 | 空格/点牌库结束出牌")
				deck_hint.text = "点击结束出牌"
		"PLAY_P2":
			ai_timer = 0.0
			phase_timeout = 90.0
			time_left = 90.0
			if is_online and network_role == "client":
				_update_phase_hint("你的回合 - 点击手牌出牌")
				deck_hint.text = "点击结束出牌"
			elif is_online and network_role == "host":
				_update_phase_hint("🌐 等待对手出牌...")
				deck_hint.text = "牌库"
			else:
				_update_phase_hint("AI 正在思考...")
				deck_hint.text = "牌库"
		"RESOLVE":
			phase_timeout = 10.0
			time_left = 10.0
			_update_phase_hint("结算中...")
			deck_hint.text = "牌库"
		"ROUND_END":
			round_end_timer = 0.0
			phase_timeout = 5.0
			time_left = 5.0
			_update_phase_hint("回合结束...")
			deck_hint.text = "点击补牌"
		"REMEDY":
			phase_timeout = 30.0
			time_left = 30.0
			_update_phase_hint("⚠️ 濒死补救！打出治疗卡自救！")
			deck_hint.text = "30秒内自救"
		"REMEDY_AI":
			ai_timer = 0.0
			phase_timeout = 5.0
			time_left = 5.0
			if is_online and network_role == "host":
				_update_phase_hint("🌐 等待对手补救...")
			else:
				_update_phase_hint("AI 正在尝试补救...")
			deck_hint.text = "牌库"
		"GAME_OVER":
			_show_game_over()
	
	_refresh_all_ui()

func _update_phase_hint(text: String) -> void:
	phase_hint.text = text

# -- 每帧更新 ------------------------------------------------─

func _process(delta: float) -> void:
	# 发牌动画进行中，只驱动动画，不推进游戏
	if _deal_pending or _draw_anim_pending:
		_update_deck_hover()
		return
	if paused or phase == "GAME_OVER":
		# 联机模式下仍然同步状态
		if is_online and network_role == "host":
			_sync_timer += delta
			if _sync_timer >= _sync_interval:
				_sync_timer = 0.0
				_send_state_to_client()
		return
	
	# -- 联机 Client 模式：从 Host 接收状态 --
	if is_online and network_role == "client":
		if GlobalNet.client_node:
			var new_state = GlobalNet.client_node.get_latest_state()
			if new_state.size() > 0:
				remote_state = new_state
				# 出牌中不刷新手牌，防止覆盖本地预选状态
				if p1_pending.size() == 0:
					_render_remote_state()
				else:
					# 只更新 phase 和 HP，不覆盖手牌和预出牌
					var rphase: String = str(remote_state.get("phase", phase))
					phase = rphase
					# Bug 1 修复：即使出牌中也要更新 phase_hint
					match rphase:
						"PLAY_P2":
							_update_phase_hint("你的回合 - 点击手牌出牌 | 空格/点牌库结束")
							deck_hint.text = "点击结束出牌"
						"PLAY_P1":
							_update_phase_hint("对手出牌中...")
							deck_hint.text = "牌库"
						"RESOLVE":
							_update_phase_hint("结算中...")
							deck_hint.text = "牌库"
						"ROUND_END":
							_update_phase_hint("回合结束...")
							deck_hint.text = "点击补牌"
						"REMEDY_AI":
							_update_phase_hint("⚠️ 你已濒死！打出治疗卡自救！")
							deck_hint.text = "点击自救"
					var rplayers: Dictionary = remote_state.get("players", {})
					var p2_data: Dictionary = rplayers.get("P2", {})
					p2_hp = int(p2_data.get("hp", p2_hp))
					p2_max_hp = int(p2_data.get("max_hp", p2_max_hp))
					p1_hp = int(rplayers.get("P1", {}).get("hp", p1_hp))
					_refresh_hp()
			_update_timer_ui()
			return
	
	# -- 联机 Host 模式：同步状态 + 接收 Client 操作 --
	if is_online and network_role == "host":
		_poll_host_actions()
		_sync_timer += delta
		if _sync_timer >= _sync_interval:
			_sync_timer = 0.0
			_send_state_to_client()
	
	phase_timer += delta
	time_left = max(0, phase_timeout - phase_timer)
	
	match phase:
		"PLAY_P1":
			# 超时判负
			if time_left <= 0:
				winner = "P2"
				_change_phase("GAME_OVER")
		"PLAY_P2":
			if is_online and network_role == "host":
				# 联机 Host：等待 Client 出牌，不自动 AI
				pass
			else:
				ai_timer += delta
				if ai_timer >= ai_delay:
					_ai_play()
		"RESOLVE":
			# 结算在进入时已完成，直接进回合结束
			if phase_timer >= 0.5:
				_change_phase("ROUND_END")
		"ROUND_END":
			round_end_timer += delta
			if round_end_timer >= round_end_delay:
				_next_round()
		"REMEDY":
			# 30秒超时判负
			if time_left <= 0:
				winner = "P2"
				_change_phase("GAME_OVER")
		"REMEDY_AI":
			if is_online and network_role == "host":
				# 联机 Host：等待 Client 补救出牌
				pass
			else:
				ai_timer += delta
				if ai_timer >= 2.0:
					_ai_remedy()
	
	_update_timer_ui()
	_update_hover_particles()
	_update_deck_hover()

# -- 出牌逻辑 ------------------------------------------------─

func _on_card_clicked(card: CardData) -> void:
	# 联机 Client 模式
	if is_online and network_role == "client":
		if phase == "REMEDY_AI":
			if not _is_rescue_card_p2(card):
				_show_toast("只能打出治疗/护盾类卡牌自救！")
				return
			_client_play_card(card)
			return
		if phase == "PLAY_P2":
			# 沉默检查
			var cli_temp: Dictionary = game_state.get("temp", {})
			if cli_temp.get("P2_silenced", false):
				_show_toast("🔇 您被沉默，无法出牌！")
				return
			_client_play_card(card)
			return
		return
	
	if phase == "REMEDY":
		# 补救回合：只允许出治疗/护盾类卡
		if card.effect_id == "" or not _is_rescue_card(card):
			_show_toast("只能打出治疗/护盾类卡牌自救！")
			return
		_apply_remedy(card)
		return
	if phase != "PLAY_P1":
		return
	# -- 沉默检查：被沉默时无法出牌（对齐 Python play_card）---
	var temp_state: Dictionary = game_state.get("temp", {})
	if temp_state.get("P1_silenced", false):
		_show_toast("🔇 您被沉默，无法出牌！")
		return
	# 防止重复出牌：已在预出区的卡牌不可再点击
	if card in p1_pending:
		return
	# 卡牌必须在手牌中才能出
	if not card in p1_hand:
		return
	var card_cost: int = int(card.cost)
	if current_mana < card_cost:
		_show_toast("精力不足！")
		return
	
	# -- 出牌规则校验（对齐 Python state_machine.play_card） --
	if not _validate_play_card(card):
		return
	
	# 出牌
	current_mana -= card_cost
	p1_hand.erase(card)
	p1_pending.append(card)
	# 记录使用的卡牌ID
	if not card.id in used_card_ids:
		used_card_ids.append(card.id)
	_refresh_all_ui()
	_play_sfx()

## 出牌规则校验（对齐 Python play_card 组合规则）
## 规则：每回合最多出2张 | 限制卡只能单出 | 一主(法/射/坦)+一辅 | 不能双主/双辅
func _validate_play_card(card: CardData) -> bool:
	var pending_count: int = p1_pending.size()
	var card_faction: String = card.faction
	var card_is_limit: bool = card.limit_flag
	var main_factions: Dictionary = {"法": true, "射": true, "坦": true}
	
	# 每回合最多出2张
	if pending_count >= 2:
		_show_toast("每回合最多出2张牌！")
		return false
	
	# 限制卡只能单出（不能搭配其他牌）
	if card_is_limit and pending_count > 0:
		_show_toast("限制卡只能单独出牌！")
		return false
	
	if pending_count == 1:
		var existing: CardData = p1_pending[0]
		var existing_faction: String = existing.faction
		var existing_is_limit: bool = existing.limit_flag
		
		# 已选是限制卡，不能再搭配
		if existing_is_limit:
			_show_toast("限制卡只能单独出牌！")
			return false
		
		# 校验组合：一主(法/射/坦) + 一辅
		var combo_has_main: bool = main_factions.has(existing_faction) or main_factions.has(card_faction)
		var combo_has_supp: bool = (existing_faction == "辅") or (card_faction == "辅")
		var both_main: bool = main_factions.has(existing_faction) and main_factions.has(card_faction)
		var both_supp: bool = existing_faction == "辅" and card_faction == "辅"
		
		if both_main:
			_show_toast("不能同时出两张主阵营牌！")
			return false
		if both_supp:
			_show_toast("不能同时出两张辅助牌！")
			return false
		if not combo_has_supp:
			# 也不是双主（上面已拦截），说明组合不合法
			_show_toast("只能一主+一辅组合出牌！")
			return false
	
	return true

## 判断是否为可补救卡（对齐 Python _check_remedy_card_allowed）
##
## Python 允许的补救卡范围：
##   allowed_categories: HEAL, BLOCK, REFLECT, CONVERT, DMG_REDUCE
##   allowed_skill_ids: COST_TO_HEAL, COST_TO_HEAL_SELF, REFLECT_ATK,
##                      ATK_TO_HEAL, ATK_DISABLE, SILENCE_ATTACK, SHIELD_TURN
##   SHIELD: 条件允许（护盾值≥伤害且对方无破甲）
##   COUNTER_ATK_ZERO: 条件允许（对方是法师）
##
func _is_rescue_card(card: CardData) -> bool:
	var eid: String = card.effect_id

	# -- 向日葵类卡（effect_id为空，兜底mana卡，atm=0无法补救，但按规则允许）
	if card.id in [1, 27, 42]:
		return true
	if eid == "":
		return false

	# -- 精确 effect_id 匹配：治疗/恢复类
	var heal_ids: Dictionary = {
		"HEAL_1": true, "HEAL_2": true, "HEAL_3": true, "HEAL_4": true, "HEAL_8": true,
	}
	if heal_ids.has(eid):
		return true

	# -- 精确 effect_id 匹配：抵挡/免疫类
	var block_ids: Dictionary = {
		"SHIELD_TURN": true,
	}
	if block_ids.has(eid):
		return true

	# -- 精确 effect_id 匹配：转化类
	var convert_ids: Dictionary = {
		"COST_TO_HEAL": true, "COST_TO_HEAL_SELF": true, "ATK_TO_HEAL": true,
	}
	if convert_ids.has(eid):
		return true

	# -- 精确 effect_id 匹配：反弹类
	var reflect_ids: Dictionary = {
		"REFLECT_ATK": true,
	}
	if reflect_ids.has(eid):
		return true

	# -- 精确 effect_id 匹配：控制类（攻击失效/沉默攻击）
	var control_ids: Dictionary = {
		"ATK_DISABLE": true, "SILENCE_ATTACK": true,
	}
	if control_ids.has(eid):
		return true

	# -- 精确 effect_id 匹配：减伤类
	var reduce_ids: Dictionary = {
		"REDUCE_DMG_2": true, "DMG_REDUCE_2": true,
	}
	if reduce_ids.has(eid):
		return true

	# -- 护盾类：条件允许（护盾值≥伤害且对方无破甲）
	var shield_ids: Dictionary = {
		"SHIELD_1": true, "SHIELD_2": true, "SHIELD_4": true, "SHIELD_6": true,
	}
	if shield_ids.has(eid):
		# 检查对方是否有破甲
		var temp: Dictionary = game_state.get("temp", {})
		var opp: String = "P2"  # P1 补救时对手是 P2
		if temp.get(opp + "_armor_pierce", false):
			return false
		# 检查护盾值是否>=受到的伤害
		var shield_val: int = _get_shield_value_from_eid(eid)
		var remedy_info: Dictionary = game_state.get("remedy", {}).get("P1", {})
		var damage_taken: int = int(remedy_info.get("damage_taken", 0))
		if shield_val >= damage_taken:
			return true
		return false

	# -- 连携类（增伤+回血）：BOOST_ATK_HEAL 算恢复类
	if eid == "BOOST_ATK_HEAL":
		return true

	return false

## 从 effect_id 解析护盾数值
func _get_shield_value_from_eid(eid: String) -> int:
	var parts: PackedStringArray = eid.rsplit("_", false)
	if parts.size() >= 2:
		var last: String = parts[parts.size() - 1]
		if last.is_valid_int():
			return last.to_int()
	return 0

## 判断卡牌是否可用于 AI 补救（P2 视角）
func _is_rescue_card_p2(card: CardData) -> bool:
	var eid: String = card.effect_id
	if card.id in [1, 27, 42]:
		return true
	if eid == "":
		return false

	var allowed_ids: Dictionary = {
		# 治疗/恢复
		"HEAL_1": true, "HEAL_2": true, "HEAL_3": true, "HEAL_4": true, "HEAL_8": true,
		# 护盾（AI不细算，直接允许）
		"SHIELD_1": true, "SHIELD_2": true, "SHIELD_4": true, "SHIELD_6": true,
		# 抵挡
		"SHIELD_TURN": true,
		# 转化
		"COST_TO_HEAL": true, "COST_TO_HEAL_SELF": true, "ATK_TO_HEAL": true,
		# 反弹
		"REFLECT_ATK": true,
		# 控制
		"ATK_DISABLE": true, "SILENCE_ATTACK": true,
		# 减伤
		"REDUCE_DMG_2": true, "DMG_REDUCE_2": true,
		# 连携
		"BOOST_ATK_HEAL": true,
	}
	return allowed_ids.has(eid)

## 玩家补救（对齐 Python _remedy_resolve 回溯结算）
##
## 补救结算规则（对齐 Python state_machine._remedy_resolve）：
##   HEAL/CONVERT → 在受伤后HP基础上直接回血
##   BLOCK(SHIELD_TURN) → HP恢复到受伤前（完全免疫）
##   SILENCE/ATK_DISABLE/SILENCE_ATTACK → HP恢复到受伤前（攻击失效=无伤害）
##   REFLECT_ATK → HP恢复到受伤前，伤害反弹给对手
##   SHIELD → HP恢复，扣除护盾吸收后的剩余伤害
##   DMG_REDUCE → HP恢复，按减伤后伤害重新扣血
##   COUNTER_ATK_ZERO → 对方是法师时HP恢复到受伤前
##
func _apply_remedy(card: CardData) -> void:
	var remedy_info: Dictionary = game_state.get("remedy", {}).get("P1", {})
	if remedy_info.is_empty():
		_change_phase("GAME_OVER")
		return
	var before_hp: int = int(remedy_info.get("before_hp", 0))
	var damage_taken: int = int(remedy_info.get("damage_taken", 0))
	var current_hp: int = before_hp - damage_taken  # 受伤后的HP
	var eid: String = card.effect_id
	var final_hp: int = current_hp

	# -- 回溯结算（对齐 Python _remedy_resolve）---
	if eid.begins_with("HEAL") or eid == "COST_TO_HEAL" or eid == "COST_TO_HEAL_SELF" or eid == "ATK_TO_HEAL" or eid == "BOOST_ATK_HEAL":
		# HEAL / CONVERT / 连携回血类：在受伤后HP基础上回血
		var heal_val: int = _get_remedy_heal_value(card)
		final_hp = mini(p1_max_hp, current_hp + heal_val)
		_show_toast("💚 %s 补救成功！恢复 %d 点生命 (HP %d→%d)" % [card.name, heal_val, current_hp, final_hp])
	elif eid == "SHIELD_TURN":
		# 抵挡：完全免疫，恢复到受伤前
		final_hp = before_hp
		_show_toast("🛡️ %s 抵挡成功！HP恢复至 %d" % [card.name, final_hp])
	elif eid == "ATK_DISABLE" or eid == "SILENCE_ATTACK":
		# 攻击失效：HP恢复到受伤前
		final_hp = before_hp
		_show_toast("🔇 %s 使对方攻击失效！HP恢复至 %d" % [card.name, final_hp])
	elif eid == "REFLECT_ATK":
		# 反弹：HP恢复到受伤前，伤害反弹给对手
		final_hp = before_hp
		var opp_hp: int = p2_hp
		p2_hp = maxi(0, opp_hp - damage_taken)
		game_state["players"]["P2"]["hp"] = p2_hp
		_show_toast("↩️ %s 反弹攻击！HP恢复至 %d，对手受到 %d 伤害" % [card.name, final_hp, damage_taken])
	elif eid == "REDUCE_DMG_2" or eid == "DMG_REDUCE_2":
		# 减伤：按减伤后伤害重新扣血
		var reduce_val: int = 2  # 固定减伤2
		var reduced_dmg: int = maxi(0, damage_taken - reduce_val)
		final_hp = before_hp - reduced_dmg
		_show_toast("🧊 %s 减伤补救！伤害 %d→%d，HP恢复至 %d" % [card.name, damage_taken, reduced_dmg, final_hp])
	elif eid.begins_with("SHIELD"):
		# 护盾：恢复到受伤前，扣除护盾吸收后的剩余伤害
		var shield_val: int = _get_shield_value_from_eid(eid)
		var remaining: int = maxi(0, damage_taken - shield_val)
		final_hp = before_hp - remaining
		_show_toast("🛡️ %s 护盾补救！吸收 %d 伤害，HP恢复至 %d" % [card.name, mini(shield_val, damage_taken), final_hp])
	else:
		# 兜底：恢复到受伤前
		final_hp = before_hp
		_show_toast("💚 %s 补救成功！HP恢复至 %d" % [card.name, final_hp])

	final_hp = mini(p1_max_hp, final_hp)
	p1_hp = final_hp
	game_state["players"]["P1"]["hp"] = final_hp
	p1_hand.erase(card)

	if final_hp <= 0:
		winner = "P2"
		_change_phase("GAME_OVER")
		return
	# P1 补救成功，检查队列中是否还有 P2 待补救
	_remedy_queue.erase("P1")
	if _remedy_queue.has("P2") and p2_hp <= 0:
		_show_toast("⚠️ 对手也濒死了！AI尝试补救...")
		_change_phase("REMEDY_AI")
		return
	game_state.erase("remedy")
	_change_phase("ROUND_END")

## 获取补救卡的回血量（触发技能效果）
func _get_remedy_heal_value(card: CardData) -> int:
	var eid: String = card.effect_id
	# HEAL_N 类
	if eid.begins_with("HEAL"):
		if eid == "HEAL_8":
			# HEAL_TO_8: 恢复到8
			var current_hp: int = p1_hp
			return maxi(0, mini(p1_max_hp, maxi(current_hp, 8)) - current_hp)
		# HEAL_N: 固定回血
		var val_str: String = eid.replace("HEAL_", "")
		if val_str.is_valid_int():
			return val_str.to_int()
	# COST_TO_HEAL: 同出牌费用转回血（补救时只有自己一张，用自身cost）
	if eid == "COST_TO_HEAL" or eid == "COST_TO_HEAL_SELF":
		return card.cost
	# ATK_TO_HEAL: 对方攻击转回血
	if eid == "ATK_TO_HEAL":
		return _get_last_damage("P1")  # 用受到的伤害值作为回血
	# BOOST_ATK_HEAL: 回血2点
	if eid == "BOOST_ATK_HEAL":
		return 2
	# 兜底：用卡牌攻击值
	return card.atk

## AI 补救（对齐 Python _remedy_resolve 回溯结算）
func _ai_remedy() -> void:
	var remedy_info: Dictionary = game_state.get("remedy", {}).get("P2", {})
	if remedy_info.is_empty():
		winner = "P1"
		_change_phase("GAME_OVER")
		return
	# AI 找一张最佳补救卡（优先选恢复效果最好的）
	var best_card: CardData = null
	var best_score: int = -1
	for card in p2_hand:
		if not _is_rescue_card_p2(card):
			continue
		var score: int = _ai_remedy_score(card, remedy_info)
		if score > best_score:
			best_score = score
			best_card = card

	var before_hp: int = int(remedy_info.get("before_hp", 0))
	var damage_taken: int = int(remedy_info.get("damage_taken", 0))
	var current_hp: int = before_hp - damage_taken

	if best_card != null:
		var eid: String = best_card.effect_id
		var final_hp: int = current_hp

		# -- 回溯结算（对齐 Python）---
		if eid.begins_with("HEAL") or eid == "COST_TO_HEAL" or eid == "COST_TO_HEAL_SELF" or eid == "ATK_TO_HEAL" or eid == "BOOST_ATK_HEAL":
			var heal_val: int = _get_remedy_heal_value_p2(best_card)
			final_hp = mini(p2_max_hp, current_hp + heal_val)
		elif eid == "SHIELD_TURN" or eid == "ATK_DISABLE" or eid == "SILENCE_ATTACK":
			final_hp = before_hp
		elif eid == "REFLECT_ATK":
			final_hp = before_hp
			var opp_hp: int = p1_hp
			p1_hp = maxi(0, opp_hp - damage_taken)
			game_state["players"]["P1"]["hp"] = p1_hp
		elif eid == "REDUCE_DMG_2" or eid == "DMG_REDUCE_2":
			var reduced_dmg: int = maxi(0, damage_taken - 2)
			final_hp = before_hp - reduced_dmg
		elif eid.begins_with("SHIELD"):
			var shield_val: int = _get_shield_value_from_eid(eid)
			var remaining: int = maxi(0, damage_taken - shield_val)
			final_hp = before_hp - remaining
		else:
			final_hp = before_hp

		final_hp = mini(p2_max_hp, final_hp)
		p2_hp = final_hp
		game_state["players"]["P2"]["hp"] = final_hp
		p2_hand.erase(best_card)
		_show_toast("AI 补救成功！HP恢复至 %d" % final_hp)
		if final_hp <= 0:
			winner = "P1"
			_change_phase("GAME_OVER")
			return
	else:
		_show_toast("AI 无治疗卡可救！")
		winner = "P1"
		_change_phase("GAME_OVER")
		return
	game_state.erase("remedy")
	# P2 补救成功，检查队列中是否还有 P1 待补救
	_remedy_queue.erase("P2")
	if _remedy_queue.has("P1") and p1_hp <= 0:
		_show_toast("⚠️ 您也濒死了！请打出治疗卡自救！")
		_change_phase("REMEDY")
		return
	_change_phase("ROUND_END")

## AI 补救评分（选最佳补救卡）
func _ai_remedy_score(card: CardData, remedy_info: Dictionary) -> int:
	var before_hp: int = int(remedy_info.get("before_hp", 0))
	var damage_taken: int = int(remedy_info.get("damage_taken", 0))
	var current_hp: int = before_hp - damage_taken
	var eid: String = card.effect_id

	# 抵挡/免疫类 → 直接恢复满，最高优先
	if eid == "SHIELD_TURN" or eid == "ATK_DISABLE" or eid == "SILENCE_ATTACK" or eid == "REFLECT_ATK":
		return before_hp - current_hp  # = damage_taken

	# HEAL 类
	if eid.begins_with("HEAL") and eid != "HEAL_8":
		var val_str: String = eid.replace("HEAL_", "")
		if val_str.is_valid_int():
			return val_str.to_int()
	if eid == "HEAL_8":
		return maxi(0, 8 - current_hp)

	# 护盾类
	if eid.begins_with("SHIELD"):
		var sv: int = _get_shield_value_from_eid(eid)
		return mini(sv, damage_taken)

	# 转化类
	if eid == "COST_TO_HEAL" or eid == "COST_TO_HEAL_SELF":
		return card.cost
	if eid == "ATK_TO_HEAL":
		return damage_taken
	if eid == "BOOST_ATK_HEAL":
		return 2  # 回血2

	# 减伤类
	if eid == "REDUCE_DMG_2" or eid == "DMG_REDUCE_2":
		return mini(2, damage_taken)

	return 0

## 获取 P2 补救卡回血量
func _get_remedy_heal_value_p2(card: CardData) -> int:
	var eid: String = card.effect_id
	var current_hp: int = p2_hp
	if eid.begins_with("HEAL"):
		if eid == "HEAL_8":
			return maxi(0, mini(p2_max_hp, maxi(current_hp, 8)) - current_hp)
		var val_str: String = eid.replace("HEAL_", "")
		if val_str.is_valid_int():
			return val_str.to_int()
	if eid == "COST_TO_HEAL" or eid == "COST_TO_HEAL_SELF":
		return card.cost
	if eid == "ATK_TO_HEAL":
		return _get_last_damage("P2")
	if eid == "BOOST_ATK_HEAL":
		return 2
	return card.atk

func _finish_p1_turn() -> void:
	if phase != "PLAY_P1":
		return
	# 提交预出牌到战场
	p1_played = p1_pending.duplicate()
	p1_pending.clear()
	# 同步游戏状态
	game_state["hands"] = {"P1": p1_hand, "P2": p2_hand}
	if not game_state["players"]["P1"].has("buffs"):
		game_state["players"]["P1"]["buffs"] = []
	if not game_state["players"]["P2"].has("buffs"):
		game_state["players"]["P2"]["buffs"] = []
	game_state["players"]["P1"]["hp"] = p1_hp
	game_state["players"]["P1"]["max_hp"] = p1_max_hp
	game_state["players"]["P1"]["max_mana"] = max_mana
	game_state["players"]["P1"]["current_mana"] = current_mana
	game_state["players"]["P2"]["hp"] = p2_hp
	game_state["players"]["P2"]["max_hp"] = p2_max_hp
	# 触发 P1 主卡即时效果（对齐 Python commit_pending_play）
	var commit_logs: Array = effect_system.commit_effects(game_state, "P1", p1_played)
	if commit_logs.size() > 0:
		_broadcast_logs(commit_logs)
		# 读取效果后的状态
		p1_hp = int(game_state["players"]["P1"].get("hp", p1_hp))
		p2_hp = int(game_state["players"]["P2"].get("hp", p2_hp))
		max_mana = int(game_state["players"]["P1"].get("max_mana", max_mana))
		current_mana = int(game_state["players"]["P1"].get("current_mana", current_mana))
		p1_hand = game_state["hands"].get("P1", p1_hand)
		p2_hand = game_state["hands"].get("P2", p2_hand)
		_refresh_all_ui()
	# 根据 first_player 决定下一阶段
	if first_player == "P1":
		# P1 先手，出完轮到 P2(AI)
		_change_phase("PLAY_P2")
	else:
		# P1 后手，出完直接结算
		_resolve()

func _undo_last_play() -> void:
	if p1_pending.is_empty():
		return
	var card = p1_pending.pop_back()
	current_mana += int(card.cost)
	p1_hand.append(card)
	_refresh_all_ui()

# -- AI 出牌 --------------------------------------------------

func _ai_play() -> void:
	# -- 沉默检查：被沉默时 AI 跳过出牌（对齐 Python play_card）---
	var temp_state: Dictionary = game_state.get("temp", {})
	if temp_state.get("P2_silenced", false):
		_show_toast("🔇 对手被沉默，无法出牌！")
		p2_played.clear()
		_advance_after_ai()
		return

	# 简单AI：出一张精力够用且攻击力最大的牌
	var playable: Array[CardData] = []
	for card in p2_hand:
		if int(card.cost) <= current_mana:
			playable.append(card)
	
	if playable.is_empty():
		p2_played.clear()
		# AI 无牌可出（精力不够出任何牌）→ 跳过
		_show_toast("AI 精力不足，跳过出牌")
		_advance_after_ai()
		return
	
	# 按攻击力排序，出最大的
	playable.sort_custom(func(a, b): return a.atk > b.atk)
	var chosen = playable[0]
	current_mana -= int(chosen.cost)
	p2_hand.erase(chosen)
	p2_played = [chosen]
	# 同步游戏状态
	game_state["hands"] = {"P1": p1_hand, "P2": p2_hand}
	if not game_state["players"]["P2"].has("buffs"):
		game_state["players"]["P2"]["buffs"] = []
	if not game_state["players"]["P1"].has("buffs"):
		game_state["players"]["P1"]["buffs"] = []
	game_state["players"]["P2"]["hp"] = p2_hp
	game_state["players"]["P2"]["max_hp"] = p2_max_hp
	game_state["players"]["P1"]["hp"] = p1_hp
	game_state["players"]["P1"]["max_hp"] = p1_max_hp
	# 触发 P2 主卡即时效果（对齐 Python commit_pending_play）
	var commit_logs: Array = effect_system.commit_effects(game_state, "P2", p2_played)
	if commit_logs.size() > 0:
		_broadcast_logs(commit_logs)
		p1_hp = int(game_state["players"]["P1"].get("hp", p1_hp))
		p2_hp = int(game_state["players"]["P2"].get("hp", p2_hp))
		p1_hand = game_state["hands"].get("P1", p1_hand)
		p2_hand = game_state["hands"].get("P2", p2_hand)
		_refresh_all_ui()
	_advance_after_ai()


func _advance_after_ai() -> void:
	"""AI出牌完成后，根据 first_player 决定下一阶段。
	对应 Python: _advance_after_player("P2")"""
	if first_player == "P2":
		# AI 先手，出完轮到玩家(P1)
		_change_phase("PLAY_P1")
	else:
		# AI 后手，出完直接结算
		_resolve()

# -- 结算（六阶段引擎）----------------------------------------─

func _resolve() -> void:
	# 保存历史
	if not p1_played.is_empty() or not p2_played.is_empty():
		history.append({
			"P1": p1_played.duplicate(),
			"P2": p2_played.duplicate(),
		})
		if history.size() > 2:
			history.pop_front()
	
	# 同步游戏状态到效果系统
	game_state["hands"] = {"P1": p1_hand, "P2": p2_hand}
	# ⚠️ 不清空 temp — commit_effects 设置的标记（如 atk_disabled, armor_pierce）需要在结算时生效
	# temp 会在 resolve_clash 末尾统一清理
	if not game_state.has("temp"):
		game_state["temp"] = {}
	game_state["players"]["P1"]["hp"] = p1_hp
	game_state["players"]["P1"]["max_hp"] = p1_max_hp
	game_state["players"]["P1"]["max_mana"] = max_mana
	game_state["players"]["P1"]["current_mana"] = current_mana
	game_state["players"]["P2"]["hp"] = p2_hp
	game_state["players"]["P2"]["max_hp"] = p2_max_hp
	game_state["players"]["P2"]["max_mana"] = 5
	game_state["players"]["P2"]["current_mana"] = 5
	if not game_state["players"]["P2"].has("buffs"):
		game_state["players"]["P2"]["buffs"] = []
	# control_effects 跨回合保持（block_next_draw）
	if not game_state.has("control_effects"):
		game_state["control_effects"] = {}
	
	# 调用六阶段结算引擎
	var logs: Array = effect_system.resolve_clash(game_state, p1_played, p2_played)
	
	# 读取结算后的数据
	p1_hp = int(game_state["players"]["P1"].get("hp", p1_hp))
	p2_hp = int(game_state["players"]["P2"].get("hp", p2_hp))
	max_mana = int(game_state["players"]["P1"].get("max_mana", max_mana))
	current_mana = int(game_state["players"]["P1"].get("current_mana", current_mana))
	p1_hand = game_state["hands"].get("P1", p1_hand)
	p2_hand = game_state["hands"].get("P2", p2_hand)
	
	# 战报播报（完整覆盖所有 action 类型）
	_broadcast_logs(logs)
	
	_refresh_all_ui()
	
	# -- 补救回合检测（对齐 Python state_machine）--------------─
	# 双方同时濒死时：P2 先补救 → P1 再补救 → 都救活才继续
	# 这样保证两方都有补救机会，不会跳过任何一方
	var p2_dying: bool = p2_hp <= 0
	var p1_dying: bool = p1_hp <= 0
	var remedy_data: Dictionary = {}
	if p2_dying:
		remedy_data["P2"] = {"before_hp": p2_hp + _get_last_damage("P2"), "damage_taken": _get_last_damage("P2")}
	if p1_dying:
		remedy_data["P1"] = {"before_hp": p1_hp + _get_last_damage("P1"), "damage_taken": _get_last_damage("P1")}
	game_state["remedy"] = remedy_data

	if p2_dying and p1_dying:
		# 双方同时濒死：先处理 P2 补救（AI/Client），P2 救完后自动进 P1 补救
		_remedy_queue = ["P2", "P1"]
		_show_toast("⚠️ 双方同时濒死！")
		if is_online and network_role == "host":
			_change_phase("REMEDY_AI")
		else:
			_show_toast("⚠️ 对手濒死！AI尝试补救...")
			_change_phase("REMEDY_AI")
		return
	elif p2_dying:
		# 仅 P2 濒死
		_remedy_queue = ["P2"]
		if is_online and network_role == "host":
			_change_phase("REMEDY_AI")
		else:
			_show_toast("⚠️ 对手濒死！AI尝试补救...")
			_change_phase("REMEDY_AI")
		return
	elif p1_dying:
		# 仅 P1 濒死
		_remedy_queue = ["P1"]
		_show_toast("⚠️ 您已濒死！请打出治疗卡自救！")
		_change_phase("REMEDY")
		return

	_change_phase("ROUND_END")

## 获取最后结算中某玩家受到的伤害（从logs解析）
var _last_damage_log: Dictionary = {}

func _get_last_damage(player: String) -> int:
	return _last_damage_log.get(player, 0)

## 战报播报：将效果系统返回的 logs 转为 Toast 消息
func _broadcast_logs(logs: Array) -> void:
	_last_damage_log.clear()
	for entry in logs:
		var action: String = str(entry.get("action", ""))
		var val: int = int(entry.get("value", 0))
		var player: String = str(entry.get("player", ""))
		var reason: String = str(entry.get("reason", ""))
		
		# 记录伤害用于补救计算
		if action == "take_damage":
			_last_damage_log[player] = _last_damage_log.get(player, 0) + val
		
		match action:
			# -- 伤害 --
			"take_damage":
				_show_toast("💥 %s 受到 %d 点伤害" % [player, val])
			# -- 恢复 --
			"heal", "heal_to":
				if val > 0:
					_show_toast("💚 %s 恢复 %d 点生命" % [player, val])
			# -- 护盾 --
			"gain_shield":
				_show_toast("🛡️ %s 获得 %d 点护盾" % [player, val])
			"shield_absorb":
				_show_toast("🛡️ %s 护盾吸收 %d 点" % [player, val])
			# -- 精力 --
			"mana_up":
				_show_toast("✨ %s 精力上限 +%d" % [player, val])
			# -- 克制 --
			"counter_atk_zero":
				_show_toast("🛡️ %s 克制：法师攻击清0!" % player)
			"counter_dmg_x3":
				_show_toast("🎯 %s 克制坦克，伤害×%d!" % [player, val])
			"dmg_buff_2x":
				_show_toast("💥 %s 伤害×2!" % player)
			"dmg_buff_2x_counter":
				_show_toast("🎯 %s 克制坦克，伤害×2!" % player)
			# -- 增伤 --
			"atk_boost":
				_show_toast("⚔️ %s 增伤 +%d" % [player, val])
			"dmg_buff_add":
				_show_toast("⚔️ %s 增伤 +%d" % [player, val])
			"support_dmg_mult":
				_show_toast("🌟 %s 辅助增伤×%d!" % [player, val])
			"flat_dmg_reduce":
				_show_toast("🧊 %s 减伤 %d 点" % [player, val])
			# -- 控制 --
			"atk_disabled":
				_show_toast("🔇 %s 攻击失效!" % player)
			"silenced":
				_show_toast("🔇 %s 被沉默!" % player)
			"gain_block", "block_turn_triggered":
				_show_toast("🛡️ %s 抵挡了全部伤害!" % player)
			"reflect", "reflect_triggered":
				_show_toast("↩️ %s 反弹攻击!" % player)
			# -- 卡牌交互 --
			"steal_card":
				_show_toast("🃏 %s 偷取了 %s" % [player, reason])
			"card_discarded":
				_show_toast("🗑️ %s 的 %s 被弃置" % [player, reason])
			"cost_to_heal", "cost_to_heal_self":
				if val > 0:
					_show_toast("💚 %s 费用转回血 %d" % [player, val])
			"atk_to_heal":
				if val > 0:
					_show_toast("💚 %s 攻击转回血 %d" % [player, val])
			# -- 特殊 --
			"weaken_all":
				_show_toast("📉 %s 弱化对手攻击至1!" % player)
			"absorb_shield":
				_show_toast("🧲 %s 吸收了对手 %d 点护盾" % [player, val])
			"block_next_draw":
				_show_toast("🌿 %s 困窘：对手下回合无法补牌!" % player)
			"multiply_dmg":
				_show_toast("🎳 %s 伤害×对手出牌数(%d)!" % [player, val])
			"armor_pierce", "armor_pierce_bypass":
				_show_toast("🗡️ %s 破甲!" % player)

# -- 回合流转 ------------------------------------------------─

func _next_round() -> void:
	p1_played.clear()
	p2_played.clear()
	p1_pending.clear()
	round_count += 1
	
	# 精力回满（不自动增长上限，上限只能通过 MANA 类卡牌效果提升）
	# 先从 game_state 读回结算引擎可能已提升的 max_mana
	max_mana = int(game_state["players"]["P1"].get("max_mana", max_mana))
	current_mana = max_mana
	game_state["players"]["P1"]["max_mana"] = max_mana
	game_state["players"]["P1"]["current_mana"] = current_mana
	# P2 同样只回满，不自增上限
	var p2_max: int = int(game_state["players"]["P2"].get("max_mana", 5))
	game_state["players"]["P2"]["max_mana"] = p2_max
	game_state["players"]["P2"]["current_mana"] = p2_max
	
	# 补牌（补到5张，检查 block_next_draw 控制效果）
	var ctrl: Dictionary = game_state.get("control_effects", {})
	
	# P1 补牌到5张
	var p1_drawn: Array[CardData] = []  # 记录抽到的牌，用于动画
	if ctrl.get("P1_block_next_draw", false):
		ctrl.erase("P1_block_next_draw")
		_show_toast("🌿 P1 被困窘，无法补牌!")
	else:
		var p1_need: int = max(0, 5 - p1_hand.size())
		for i in range(p1_need):
			if not deck_cards.is_empty():
				var drawn_card: CardData = deck_cards.pop_front()
				p1_hand.append(drawn_card)
				p1_drawn.append(drawn_card)
	
	# P2 补牌到5张
	if ctrl.get("P2_block_next_draw", false):
		ctrl.erase("P2_block_next_draw")
		_show_toast("🌿 P2 被困窘，无法补牌!")
	else:
		var p2_need: int = max(0, 5 - p2_hand.size())
		for i in range(p2_need):
			if not deck_cards.is_empty():
				p2_hand.append(deck_cards.pop_front())
	
	# 更新牌库视觉（立即反映牌库减少）
	_refresh_deck()
	
	# P1 有补牌时，播放补牌动画
	if p1_drawn.size() > 0:
		_start_draw_animation(p1_drawn)
		return  # 动画结束后由 _on_draw_anim_finished 推进阶段
	
	# 无需补牌，直接进入出牌阶段
	_advance_to_play_phase()

# -- UI 刷新 --------------------------------------------------

func _refresh_all_ui() -> void:
	_refresh_p1_hand()
	_refresh_p2_hand()
	_refresh_p1_slot()
	_refresh_p2_slot()
	_refresh_hp()
	_refresh_deck()
	_refresh_round()
	_refresh_history()

func _refresh_p1_hand() -> void:
	for child in p1_hand_container.get_children():
		child.queue_free()
	# Client 模式：P1 手牌区显示 P2（自己）的牌
	if is_online and network_role == "client":
		for card in p2_hand:
			# Bug 2 修复：过滤掉已在预出牌区的牌
			if card in p1_pending:
				continue
			var is_clickable = (phase == "PLAY_P2" or phase == "REMEDY_AI")
			var btn = _create_card_button(card, is_clickable)
			p1_hand_container.add_child(btn)
		return
	for card in p1_hand:
		var btn = _create_card_button(card, true)
		p1_hand_container.add_child(btn)

func _refresh_p2_hand() -> void:
	for child in p2_hand_container.get_children():
		child.queue_free()
	# Client 模式：对手区显示 P1（Host）的牌（卡背）
	if is_online and network_role == "client":
		for card in p1_hand:
			var btn = _create_card_back()
			p2_hand_container.add_child(btn)
		return
	for card in p2_hand:
		var btn = _create_card_back()
		p2_hand_container.add_child(btn)

func _refresh_p1_slot() -> void:
	for child in p1_slot_container.get_children():
		child.queue_free()
	# Client: 底部slot显示自己的预出牌/已出牌
	if is_online and network_role == "client":
		if phase == "PLAY_P2" and p1_pending.size() > 0:
			for card in p1_pending:
				var btn = _create_card_button(card, true)
				p1_slot_container.add_child(btn)
		elif p2_played.size() > 0:
			for card in p2_played:
				var btn2 = _create_card_button(card, false)
				p1_slot_container.add_child(btn2)
		return
	var cards = p1_pending if phase == "PLAY_P1" else p1_played
	for card in cards:
		var btn = _create_card_button(card, phase == "PLAY_P1")
		p1_slot_container.add_child(btn)

func _refresh_p2_slot() -> void:
	for child in p2_slot_container.get_children():
		child.queue_free()
	# Client 模式：P2 slot 显示 P1 的出牌
	if is_online and network_role == "client":
		for card in p1_played:
			var btn = _create_card_button(card, false)
			p2_slot_container.add_child(btn)
		return
	for card in p2_played:
		var btn = _create_card_button(card, false)
		p2_slot_container.add_child(btn)

func _refresh_hp() -> void:
	if is_online and network_role == "client":
		# Client: 底部p1_hp_bar显示自己(P2)，顶部p2_hp_bar显示对手(P1)
		_refresh_hp_bar(p1_hp_bar, p2_max_hp, max(0, p2_hp))
		_refresh_hp_bar(p2_hp_bar, p1_max_hp, max(0, p1_hp))
		p1_hp_label.text = "你(P2) HP: %d/%d  Mana: %d/%d" % [max(0, p2_hp), p2_max_hp, current_mana, max_mana]
		p2_hp_label.text = "对手(P1) HP: %d/%d" % [max(0, p1_hp), p1_max_hp]
	else:
		_refresh_hp_bar(p1_hp_bar, p1_max_hp, max(0, p1_hp))
		_refresh_hp_bar(p2_hp_bar, p2_max_hp, max(0, p2_hp))
		p1_hp_label.text = "P1 HP: %d/%d  Mana: %d/%d" % [max(0, p1_hp), p1_max_hp, current_mana, max_mana]
		p2_hp_label.text = "P2 HP: %d/%d" % [max(0, p2_hp), p2_max_hp]
	# buff 和精力也要根据视角翻转
	if is_online and network_role == "client":
		_refresh_buff_bar($P1BuffBar, game_state.get("players", {}).get("P2", {}))
		_refresh_buff_bar($P2BuffBar, game_state.get("players", {}).get("P1", {}))
		_refresh_mana_dots($P1ManaDots, current_mana, max_mana)
		var e_p1_max: int = int(game_state.get("players", {}).get("P1", {}).get("max_mana", 5))
		var e_p1_cur: int = int(game_state.get("players", {}).get("P1", {}).get("current_mana", 5))
		_refresh_mana_dots($P2ManaDots, e_p1_cur, e_p1_max)
	else:
		_refresh_buff_bar($P1BuffBar, game_state.get("players", {}).get("P1", {}))
		_refresh_buff_bar($P2BuffBar, game_state.get("players", {}).get("P2", {}))
		_refresh_mana_dots($P1ManaDots, current_mana, max_mana)
		var e_p2_max: int = int(game_state.get("players", {}).get("P2", {}).get("max_mana", 5))
		var e_p2_cur: int = int(game_state.get("players", {}).get("P2", {}).get("current_mana", 5))
		_refresh_mana_dots($P2ManaDots, e_p2_cur, e_p2_max)

## 刷新单个血条（1-2红/3-5橙棕/6-10绿）
func _refresh_hp_bar(bar: ProgressBar, max_hp: int, hp: int) -> void:
	bar.min_value = 0
	bar.max_value = max_hp
	bar.value = hp
	# 背景样式
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.12, 0.12, 0.15)
	bg_style.set_corner_radius_all(6)
	bg_style.border_color = Color(0.3, 0.3, 0.3)
	bg_style.set_border_width_all(1)
	bg_style.content_margin_left = 2
	bg_style.content_margin_right = 2
	bg_style.content_margin_top = 2
	bg_style.content_margin_bottom = 2
	bar.add_theme_stylebox_override("background", bg_style)
	# 填充样式
	var fill_style = StyleBoxFlat.new()
	if hp >= 6:
		fill_style.bg_color = Color(0.15, 0.65, 0.2)    # 绿色
	elif hp >= 3:
		fill_style.bg_color = Color(0.75, 0.45, 0.15)  # 橙棕色
	else:
		fill_style.bg_color = Color(0.85, 0.12, 0.12)  # 红色
	fill_style.set_corner_radius_all(5)
	fill_style.content_margin_left = 0
	fill_style.content_margin_right = 0
	fill_style.content_margin_top = 0
	fill_style.content_margin_bottom = 0
	bar.add_theme_stylebox_override("fill", fill_style)

## 精力点阵：10个圆点（2行×5列），黄色=可用，深灰=空位
func _refresh_mana_dots(container: Control, cur: int, max_val: int) -> void:
	for child in container.get_children():
		child.queue_free()
	max_val = mini(max_val, 10)
	var dot_r: int = 6
	var gap: int = 4
	var cols: int = 5
	for i in range(10):
		var row: int = i / cols
		var col: int = i % cols
		var cx: float = col * (dot_r * 2 + gap) + dot_r
		var cy: float = row * (dot_r * 2 + gap) + dot_r
		var dot = Panel.new()
		dot.position = Vector2(cx - dot_r, cy - dot_r)
		dot.size = Vector2(dot_r * 2, dot_r * 2)
		var style = StyleBoxFlat.new()
		if i < max_val:
			if i < cur:
				style.bg_color = Color(1, 0.84, 0)  # 黄色 #FFD700
			else:
				style.bg_color = Color(0.18, 0.18, 0.18)  # 深灰
		else:
			style.bg_color = Color(0.24, 0.24, 0.24)  # 灰色预留
		style.set_corner_radius_all(dot_r)
		dot.add_theme_stylebox_override("panel", style)
		container.add_child(dot)

func _refresh_buff_bar(container: GridContainer, player_state: Dictionary) -> void:
	for child in container.get_children():
		child.queue_free()
	var buffs: Array = player_state.get("buffs", [])
	if not buffs or not buffs is Array:
		return
	
	var active_buffs: Array = []
	for b in buffs:
		if b is Dictionary and int(b.get("value", 0)) > 0:
			active_buffs.append(b)
	if active_buffs.is_empty():
		return
	
	# buff 图片路径映射
	var buff_img_map: Dictionary = {
		"shield": "res://assets/images/buffs/buff_shield.jpg",
		"heal_over_time": "res://assets/images/buffs/buff_restore HP.jpg",
		"heal": "res://assets/images/buffs/buff_restore HP.jpg",
		"armor_pen": "res://assets/images/buffs/buff_armor_pen.png",
		"dmg_buff": "res://assets/images/buffs/buff_dmg_add.png",
		"dmg_reduce": "res://assets/images/buffs/buff_dmg_reduce.png",
		"silence_attack": "res://assets/images/buffs/buff_silence_attack.png",
		"mana_boost": "res://assets/images/borders/bg_energy.png",
		"mana": "res://assets/images/borders/bg_energy.png",
		"block_turn": "res://assets/images/buffs/buff_block_turn.png",
	}
	
	# 边框颜色映射（对应 Python _buff_border_color）
	var border_color_map: Dictionary = {
		"shield": Color(70/255.0, 130/255.0, 230/255.0),
		"heal_over_time": Color(50/255.0, 200/255.0, 80/255.0),
		"heal": Color(50/255.0, 200/255.0, 80/255.0),
		"dmg_reduce": Color(200/255.0, 170/255.0, 50/255.0),
		"dmg_buff": Color(230/255.0, 120/255.0, 50/255.0),
		"armor_pen": Color(200/255.0, 60/255.0, 60/255.0),
		"silence_attack": Color(160/255.0, 50/255.0, 180/255.0),
		"mana_boost": Color(180/255.0, 130/255.0, 255/255.0),
		"mana": Color(180/255.0, 130/255.0, 255/255.0),
		"block_turn": Color(50/255.0, 200/255.0, 100/255.0),
	}
	
	# 占位色块映射（无图片时用首字母色块）
	var placeholder_color_map: Dictionary = {
		"s": Color(40/255.0, 80/255.0, 180/255.0),
		"h": Color(30/255.0, 140/255.0, 60/255.0),
		"d": Color(160/255.0, 140/255.0, 30/255.0),
		"b": Color(180/255.0, 50/255.0, 20/255.0),
		"m": Color(120/255.0, 80/255.0, 200/255.0),
		"a": Color(200/255.0, 60/255.0, 60/255.0),
		"n": Color(230/255.0, 120/255.0, 50/255.0),
		"i": Color(160/255.0, 50/255.0, 180/255.0),
		"l": Color(50/255.0, 200/255.0, 100/255.0),
	}
	
	# 中文名映射
	var name_map: Dictionary = {
		"shield": "护盾", "dmg_buff": "增攻", "dmg_reduce": "减伤",
		"armor_pen": "破甲", "silence_attack": "禁攻", "block_turn": "免疫",
		"mana_boost": "精力", "mana": "精力",
		"heal_over_time": "恢复", "heal": "治疗",
	}
	
	var icon_size: float = 36.0
	var font: FontFile = load("res://assets/fonts/simhei.ttf")
	
	for idx in range(active_buffs.size()):
		var buff: Dictionary = active_buffs[idx]
		var btype: String = str(buff.get("type", ""))
		var buff_value: int = int(buff.get("value", 0))
		var icon_code: String = str(buff.get("icon_code", btype))
		var duration: int = int(buff.get("duration", 0))
		
		# 创建 buff 图标（使用 buff_icon.gd 自绘）
		var icon_node := Control.new()
		icon_node.set_script(load("res://scripts/buff_icon.gd"))
		icon_node.mouse_filter = Control.MOUSE_FILTER_PASS
		
		# tooltip
		var dur_text: String = "永久" if duration == -1 else ("%d回合" % duration if duration > 0 else "")
		var desc: String = "%s: %d" % [name_map.get(btype, btype), buff_value]
		if dur_text != "":
			desc += " (%s)" % dur_text
		icon_node.tooltip_text = desc
		
		container.add_child(icon_node)
		
		# 初始化自绘数据（add_child 后才能调用 setup）
		icon_node.setup(
			buff_img_map.get(btype, ""),
			border_color_map.get(btype, Color(0.47, 0.47, 0.47)),
			placeholder_color_map.get(icon_code.left(1).to_lower(), Color(80/255.0, 80/255.0, 80/255.0)),
			icon_code,
			buff_value,
			duration,
			name_map.get(btype, btype),
			icon_size,
			font
		)

func _refresh_deck() -> void:
	# -- 牌库卡背视觉 ---
	for n in _deck_back_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_deck_back_nodes.clear()
	
	var deck_count: int = deck_cards.size()
	if deck_count <= 0:
		_update_deck_tooltip_position()
		return
	
	# 每4张牌=1张卡背，最多11张
	var back_count: int = ceili(deck_count / 4.0)
	if back_count > 11:
		back_count = 11
	
	# 牌库区域
	var zone_pos: Vector2 = deck_zone.global_position
	var zone_size: Vector2 = deck_zone.size
	var back_w: float = zone_size.x - 4.0  # 横卡宽=牌库宽-边距
	var back_h: float = roundf(back_w * 60.0 / 84.0)  # 保持卡牌宽高比
	# 垂直叠放：居中水平，从上往下偏移
	var start_x: float = zone_pos.x + 2.0  # 左边距2px
	var start_y: float = zone_pos.y + 8.0  # 顶部留一点空间
	# 垂直间距（重叠量随数量调整）
	var total_stack_h: float = zone_size.y - 16.0 - back_h  # 可用于叠放的高度
	var spacing: float = 0.0
	if back_count > 1:
		spacing = minf(total_stack_h / float(back_count - 1), 14.0)
	
	for i in range(back_count):
		var back_node: Control = _create_deck_back()
		var px: float = start_x
		var py: float = start_y + i * spacing
		back_node.global_position = Vector2(px, py)
		back_node.z_index = i  # 越上层越前
		add_child(back_node)
		_deck_back_nodes.append(back_node)
	
	_update_deck_tooltip_position()

## 更新牌库提示标签位置（紧贴牌库上方）
func _update_deck_tooltip_position() -> void:
	if _deck_tooltip == null:
		return
	var zone_pos: Vector2 = deck_zone.global_position
	var zone_w: float = deck_zone.size.x
	_deck_tooltip.global_position = Vector2(zone_pos.x - 5, zone_pos.y - 22)
	_deck_tooltip.size = Vector2(zone_w + 10, 20)
	_deck_tooltip.text = "剩余 %d 张" % deck_cards.size()

func _refresh_round() -> void:
	round_label.text = "Round %d" % round_count

func _refresh_history() -> void:
	for child in history_area.get_children():
		child.queue_free()
	
	var label_font = load("res://assets/fonts/simhei.ttf")
	
	for i in range(history.size()):
		var entry = history[history.size() - 1 - i]
		var vbox = VBoxContainer.new()
		
		var label = Label.new()
		label.add_theme_font_override("font", label_font)
		label.add_theme_font_size_override("font_size", 12)
		if i == 0:
			label.text = "上回合"
		else:
			label.text = "前两回合"
		vbox.add_child(label)
		
		# Bug 3 修复：Client 模式翻转显示
		var my_faction: String = "P2" if (is_online and network_role == "client") else "P1"
		var opp_faction: String = "P1" if my_faction == "P2" else "P2"
		# 显示自己出牌（上方）
		for card in entry[my_faction]:
			var small = _create_mini_card(card)
			vbox.add_child(small)
		# 分隔
		var sep = HSeparator.new()
		vbox.add_child(sep)
		# 显示对手出牌（下方）
		for card in entry[opp_faction]:
			var small = _create_mini_card(card)
			vbox.add_child(small)
		
		history_area.add_child(vbox)

func _update_timer_ui() -> void:
	timer_label.text = "Phase: %s  Time: %ds" % [phase, int(time_left)]

# -- 卡牌 UI 创建 --------------------------------------------─

## 卡牌绘制用缓存
var _tex_cache: Dictionary = {}

## 安全加载纹理（带缓存）
func _load_tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	if ResourceLoader.exists(path):
		var tex = load(path)
		_tex_cache[path] = tex
		return tex
	return null

## 阵营背景图路径
const FACTION_BG_MAP: Dictionary = {
	"法": "res://assets/images/borders/bg_mage.jpg",
	"射": "res://assets/images/borders/bg_archer.jpg",
	"坦": "res://assets/images/borders/bg_tank.jpg",
	"辅": "res://assets/images/borders/bg_support.jpg",
}

## 创建卡牌（自绘 Control + _draw，对齐 Python CardRenderer）
func _create_card_button(card: CardData, clickable: bool) -> Control:
	var node = CardPaint.new()
	node.card = card
	node.clickable = clickable
	node.font = load("res://assets/fonts/simhei.ttf")
	node.faction_color = FACTION_COLORS.get(card.faction, Color(0.4, 0.4, 0.4))
	node.display_name = _clean_card_name(card.name)
	if node.display_name.length() > 4:
		node.display_name = node.display_name.left(4) + ".."
	# 预加载纹理
	node.bg_tex = _load_tex(FACTION_BG_MAP.get(card.faction, ""))
	node.plant_tex = _load_tex(card.get_image_path())
	node.energy_tex = _load_tex("res://assets/images/borders/bg_energy.png")
	node.atk_tex = _load_tex("res://assets/images/borders/bg_atk.png")
	node.limit_tex = _load_tex("res://assets/images/borders/bg_limit.png") if card.limit_flag else null
	node.custom_minimum_size = Vector2(80, 120)
	node.size = Vector2(80, 120)
	if clickable:
		node.gui_input.connect(_on_card_gui_input.bind(card))
	return node

func _on_card_gui_input(event: InputEvent, card: CardData) -> void:
	# 手机触摸处理
	if event is InputEventScreenTouch:
		if event.pressed:
			_long_press_timer = 0.0
			_long_pressing_card = card
		else:
			# 触摸抬起，短按逻辑
			if _long_pressing_card == card and _long_press_timer < _long_press_threshold:
				if card in p1_pending:
					# 短按已预出的牌 → 撤回（等同PC右键）
					if is_online and network_role == "client":
						_undo_client_pending(card)
					else:
						_undo_card_from_pending(card)
				elif phase == "PLAY_P1" or phase == "PLAY_P2" or phase == "REMEDY" or phase == "REMEDY_AI":
					_on_card_clicked(card)
			_long_pressing_card = null
			_long_press_timer = 0.0
		return
	elif event is InputEventScreenDrag:
		if _long_pressing_card == card:
			_long_press_timer += get_process_delta_time()
			if _long_press_timer >= _long_press_threshold:
				_show_card_info(card)
				_long_pressing_card = null
				_long_press_timer = 0.0
		return
	
	# PC 鼠标处理（原代码）
	if event is InputEventMouseButton and event.pressed:
		# 右键：撤回预出牌
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if card in p1_pending:
				# Client 模式撤回
				if is_online and network_role == "client":
					_undo_client_pending(card)
				else:
					_undo_card_from_pending(card)
			return
		# 左键：只有手牌中的卡牌才能出牌，slot 中的不响应
		if event.button_index == MOUSE_BUTTON_LEFT:
			if card in p1_pending:
				# 已在预出区，左键不响应
				return
			if phase == "PLAY_P1":
				_on_card_clicked(card)
			elif phase == "PLAY_P2":
				_on_card_clicked(card)
			elif phase == "REMEDY":
				_on_card_clicked(card)
			elif phase == "REMEDY_AI":
				_on_card_clicked(card)

## 清洗卡牌名称（去除英文后缀）
func _clean_card_name(raw: String) -> String:
	var cleaned: String = raw.strip_edges()
	var has_ascii: bool = false
	for ch in cleaned:
		if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z"):
			has_ascii = true
			break
	if has_ascii:
		cleaned = cleaned.replace("fa", "").replace("fu", "").replace("s", "").replace("t", "").strip_edges()
	if cleaned == "":
		cleaned = raw
	return cleaned

func _create_card_back() -> Control:
	var node = Control.new()
	node.custom_minimum_size = Vector2(60, 84)
	node.size = Vector2(60, 84)
	# 自绘卡背
	var back_tex: Texture2D = _load_tex("res://assets/images/card_back.jpg")
	var script = load("res://scripts/card_back_paint.gd")
	if script:
		node.set_script(script)
		node.back_tex = back_tex
		node.card_w = 60
		node.card_h = 84
	return node

## 牌库专用横向卡背（宽=牌库宽120, 高≈86, 贴图旋转-90°）
func _create_deck_back() -> Control:
	var deck_w: float = deck_zone.size.x - 4.0  # 左右各留2px边距
	var deck_h: float = roundf(deck_w * 60.0 / 84.0)  # 保持卡牌宽高比（短边:长边）
	var node = Control.new()
	node.custom_minimum_size = Vector2(deck_w, deck_h)
	node.size = Vector2(deck_w, deck_h)
	var back_tex: Texture2D = _load_tex("res://assets/images/card_back.jpg")
	var script = load("res://scripts/card_back_paint.gd")
	if script:
		node.set_script(script)
		node.back_tex = back_tex
		node.card_w = int(deck_w)
		node.card_h = int(deck_h)
		node.rotated = true
	return node

func _create_mini_card(card: CardData) -> Control:
	# 缩小版卡牌（历史出牌用，60×90）
	var node = CardPaint.new()
	node.card = card
	node.clickable = false
	node.font = load("res://assets/fonts/simhei.ttf")
	node.faction_color = FACTION_COLORS.get(card.faction, Color(0.4, 0.4, 0.4))
	node.display_name = _clean_card_name(card.name)
	if node.display_name.length() > 3:
		node.display_name = node.display_name.left(3) + ".."
	node.bg_tex = _load_tex(FACTION_BG_MAP.get(card.faction, ""))
	node.plant_tex = _load_tex(card.get_image_path())  # 缩略图也显示植物图
	node.energy_tex = null
	node.atk_tex = null
	node.limit_tex = null
	node.mini_mode = true
	node.custom_minimum_size = Vector2(50, 70)
	node.size = Vector2(50, 70)
	return node

# -- 输入处理 ------------------------------------------------─

func _gui_input(event: InputEvent) -> void:
	pass

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# 空格结束出牌
		if event.keycode == KEY_SPACE:
			if is_online and network_role == "client" and phase == "PLAY_P2":
				_client_finish_turn()
			elif phase == "PLAY_P1":
				_finish_p1_turn()
		# ESC 暂停
		if event.keycode == KEY_ESCAPE:
			if phase != "GAME_OVER":
				if paused:
					_on_resume()
				else:
					_on_pause()
		# Z 撤回
		if event.keycode == KEY_Z and phase == "PLAY_P1":
			_undo_last_play()
	
	# 鼠标悬停提示
	if event is InputEventMouseMotion:
		_check_tooltip(event.position)

## 牌库点击（左键结束出牌/补牌）
func _on_deck_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_deck_clicked()

## 牌库点击逻辑
func _on_deck_clicked() -> void:
	# 联机 Client 模式
	if is_online and network_role == "client":
		if phase == "PLAY_P2":
			_client_finish_turn()
		return
	
	if phase == "PLAY_P1":
		_finish_p1_turn()
	elif phase == "ROUND_END":
		_next_round()

## 右键撤回指定卡牌
func _undo_card_from_pending(card: CardData) -> void:
	if p1_pending.has(card):
		p1_pending.erase(card)
		current_mana += int(card.cost)
		p1_hand.append(card)
		_refresh_all_ui()
		_play_sfx()

func _undo_client_pending(card: CardData) -> void:
	"""Client 撤回预出牌。"""
	if p1_pending.has(card):
		p1_pending.erase(card)
		current_mana += int(card.cost)
		p2_hand.append(card)  # Client 手牌是 p2_hand
		_refresh_all_ui()
		_play_sfx()
		# Bug 3 修复：实时同步精力给 Host
		_send_client_mana_update()

# -- 按钮事件 ------------------------------------------------─

func _on_surrender() -> void:
	winner = "P2"
	_change_phase("GAME_OVER")

func _on_pause() -> void:
	paused = true
	pause_overlay.visible = true

func _on_resume() -> void:
	paused = false
	pause_overlay.visible = false
	# 补偿暂停时间
	phase_timer -= pause_time_accumulated
	pause_time_accumulated = 0.0

func _on_back_menu() -> void:
	if GlobalNet:
		GlobalNet.cleanup()
	if GlobalMusic:
		GlobalMusic.play_menu()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_game_over_btn() -> void:
	if GlobalNet:
		GlobalNet.cleanup()
	if GlobalMusic:
		GlobalMusic.play_menu()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_lobby_connected() -> void:
	"""从大厅切换到游戏时调用"""
	print("[GameBoard] 接收到 lobby_connected 信号")
	if is_online and network_role == "client":
		# Client 端也需要显示先手选择对话框
		_show_order_dialog_online()

func _on_first_player_received(choice: String) -> void:
	"""Client 收到 Host 的先手选择"""
	print("[GameBoard] Client 收到先手选择: %s" % choice)
	first_player = choice
	_waiting_for_first_choice = false
	# 关闭等待对话框
	if order_overlay:
		order_overlay.queue_free()
		order_overlay = null
	# 开始游戏
	_start_game_music()
	_start_game_online_client()

# -- 游戏结束 ------------------------------------------------─

func _show_game_over() -> void:
	game_overlay.visible = true
	surrender_btn.visible = false
	pause_btn.visible = false
	
	# 判断自己是否赢了
	var i_win: bool = false
	var is_draw: bool = (winner == "DRAW")
	if is_online and network_role == "client":
		i_win = (winner == "P2")  # Client 是 P2
	else:
		i_win = (winner == "P1")  # Host / 本地是 P1
	
	if is_draw:
		game_over_title.text = "势均力敌"
		game_over_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		game_over_sub.text = "双方平局！血量相同，用了 %d 个回合" % round_count
		game_over_btn.text = "再来一局"
	elif i_win:
		# 记录成就
		var unlocked = save_manager.check_achievements(round_count, used_card_ids, false)
		var ach_text = ""
		if unlocked.size() > 0:
			ach_text = "\n\n成就解锁："
			for name in unlocked:
				ach_text += "\n  " + name
		game_over_title.text = "您战胜了强大的对手"
		game_over_title.add_theme_color_override("font_color", Color(1, 0.84, 0))
		game_over_sub.text = "恭喜胜利！用了 %d 个回合%s" % [round_count, ach_text]
		game_over_btn.text = "简简单单啊~"
	else:
		save_manager.record_loss()
		game_over_title.text = "无力回天"
		game_over_title.add_theme_color_override("font_color", Color(0.78, 0.2, 0.2))
		game_over_sub.text = "坚持了 %d 个回合" % round_count
		game_over_btn.text = "好吧"

# -- 提示框 --------------------------------------------------─

func _check_tooltip(pos: Vector2) -> void:
	# 只在可操作阶段显示tooltip
	var allowed_phases: Array = ["PLAY_P1", "PLAY_P2", "RESOLVE", "ROUND_END", "REMEDY", "REMEDY_AI"]
	if not phase in allowed_phases:
		tooltip_panel.visible = false
		return
	
	# 确定数据源：Client 视角翻转
	var my_hand: Array = p1_hand
	var my_slot: Array = p1_pending if (phase == "PLAY_P1" or phase == "PLAY_P2") else p1_played
	if is_online and network_role == "client":
		my_hand = p2_hand
		my_slot = p1_pending if phase == "PLAY_P2" else p2_played
	
	# 检测鼠标是否在手牌上
	for i in range(my_hand.size()):
		var child_count = p1_hand_container.get_child_count()
		if i < child_count:
			var card_btn = p1_hand_container.get_child(i) as Control
			if card_btn and Rect2(card_btn.global_position, card_btn.size).has_point(pos):
				_show_tooltip(my_hand[i], pos)
				return
	
	# 检测鼠标是否在预出区(slot)上
	for i in range(my_slot.size()):
		var child_count = p1_slot_container.get_child_count()
		if i < child_count:
			var card_btn = p1_slot_container.get_child(i) as Control
			if card_btn and Rect2(card_btn.global_position, card_btn.size).has_point(pos):
				_show_tooltip(my_slot[i], pos)
				return
	
	tooltip_panel.visible = false

func _show_tooltip(card: CardData, pos: Vector2) -> void:
	tooltip_panel.visible = true
	tooltip_name.text = card.name
	
	var faction_name = card.faction
	if faction_name == "法":
		faction_name = "法师"
	elif faction_name == "射":
		faction_name = "射手"
	elif faction_name == "坦":
		faction_name = "坦克"
	elif faction_name == "辅":
		faction_name = "辅助"
	
	var card_type = "辅卡" if card.type == "辅" else "主卡"
	tooltip_meta.text = "%s | %s | 费用:%d 攻击:%d" % [faction_name, card_type, card.cost, card.atk]
	tooltip_desc.text = card.description
	
	# 位置
	var tx = pos.x + 12
	var ty = pos.y
	if tx + 200 > 1024:
		tx = pos.x - 212
	if ty + 150 > 768:
		ty = 768 - 155
	tooltip_panel.position = Vector2(tx, ty)
	tooltip_panel.size = Vector2(200, 150)

# -- Toast 消息 ----------------------------------------------─

func _show_toast(text: String) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(1, 0.84, 0))
	var font = load("res://assets/fonts/simhei.ttf")
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 18)
	
	# 背景
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(0, 30)
	panel.add_child(label)
	
	toast_container.add_child(panel)
	
	# 2.5秒后自动移除
	var tween = get_tree().create_tween()
	tween.tween_interval(2.5)
	tween.tween_callback(panel.queue_free)

# -- 音效 ----------------------------------------------------─

func _play_sfx() -> void:
	if GlobalMusic:
		GlobalMusic.play_card_sfx()
	return
	# 旧代码（保留备用）
	var sfx_path = "res://assets/sfx/card_lighter.wav"
	if ResourceLoader.exists(sfx_path):
		var sfx = load(sfx_path)
		if sfx:
			$AudioStreamPlayer.stream = sfx
			$AudioStreamPlayer.play()

## 显示卡牌详细信息（手机长按/PC 悬停）
func _show_card_info(card: CardData) -> void:
	print("[CardInfo] 卡牌: %s (%s)" % [card.card_name, card.faction])
	print("[CardInfo] 生命: %d  攻击: %d" % [card.hp, card.attack])
	if card.description != "":
		print("[CardInfo] 描述: %s" % card.description)
