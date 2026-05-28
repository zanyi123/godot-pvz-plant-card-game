## lobby_screen.gd - 联机大厅
## 对应 Python: network/lobby.py
## 功能：UDP 发现玩家 + 手动输入 IP 连接 + 邀请/接受流程
extends Control

## 信号
signal lobby_back()
signal lobby_connected()

## -- 颜色常量（对齐 Python lobby.py）--
var BG_COLOR: Color = Color(26.0/255, 43.0/255, 58.0/255)
var PANEL_BG: Color = Color(32.0/255, 45.0/255, 62.0/255)
var PANEL_BORDER: Color = Color(70.0/255, 90.0/255, 120.0/255)
var TITLE_COLOR: Color = Color(1.0, 240.0/255, 140.0/255)
var SUBTITLE_CLR: Color = Color(160.0/255, 180.0/255, 200.0/255)
var LAN_LABEL_CLR: Color = Color(100.0/255, 180.0/255, 1.0)
var ROW_BG: Color = Color(38.0/255, 52.0/255, 72.0/255)
var ROW_HOVER: Color = Color(55.0/255, 75.0/255, 100.0/255)
var NAME_CLR: Color = Color(230.0/255, 235.0/255, 245.0/255)
var ID_CLR: Color = Color(130.0/255, 145.0/255, 165.0/255)
var BTN_INVITE: Color = Color(55.0/255, 140.0/255, 90.0/255)
var BTN_INVITE_HVR: Color = Color(70.0/255, 170.0/255, 110.0/255)
var BTN_INVITE_DIS: Color = Color(60.0/255, 65.0/255, 72.0/255)
var BTN_TXT: Color = Color(235.0/255, 240.0/255, 245.0/255)
var BTN_BACK: Color = Color(45.0/255, 58.0/255, 75.0/255)
var BTN_BACK_HVR: Color = Color(72.0/255, 108.0/255, 140.0/255)
var BTN_BORDER: Color = Color(130.0/255, 150.0/255, 170.0/255)
var INPUT_BG: Color = Color(245.0/255, 245.0/255, 250.0/255)
var INPUT_BORDER: Color = Color(130.0/255, 150.0/255, 170.0/255)
var INPUT_ACTIVE_C: Color = Color(72.0/255, 108.0/255, 200.0/255)

## -- 节点引用 --
var font: FontFile
var bg: ColorRect
var title_label: Label
var panel: Panel
var lan_label: Label
var me_label: Label
var status_label: Label
var player_list_vbox: VBoxContainer
var player_list_scroll: ScrollContainer
var ip_input: LineEdit
var connect_btn: Button
var back_btn: Button
var overlay: ColorRect
var overlay_label: Label

## -- 状态 --
var _discovery: Node
var _hovered_invite_idx: int = -1
var _hovered_back: bool = false
var _hovered_connect: bool = false
var _status_msg: String = "等待发现玩家..."
var _inviting: bool = false
var _connected: bool = false
var _invite_result: String = ""  # "" / "host" / "client"
var _refresh_timer: float = 0.0
var _refresh_interval: float = 2.0  # 每2秒刷新列表
var _last_player_ids: Array = []  # 上次玩家ID列表，用于检测变化

## TCP 连接（邀请流程）
var _server: TCPServer
var _client_peer: StreamPeerTCP
var _connect_peer: StreamPeerTCP
var _server_port: int = 0
var _recv_buf: String = ""

## 玩家列表行节点缓存
var _row_nodes: Array = []

func _ready() -> void:
	font = load("res://assets/fonts/simhei.ttf")
	_build_ui()
	_start_discovery()
	_start_tcp_listen()
	
	# 连接信号
	lobby_back.connect(_on_lobby_back)
	lobby_connected.connect(_on_lobby_connected)
	
	# 播放菜单BGM
	if GlobalMusic:
		GlobalMusic.play_menu()

func _exit_tree() -> void:
	_stop_discovery()
	_stop_tcp()

## ══════════════════════════════════════════════════════════
##  UI 构建
## ══════════════════════════════════════════════════════════

func _build_ui() -> void:
	# 背景
	bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = BG_COLOR
	add_child(bg)
	
	# 标题
	title_label = Label.new()
	title_label.position = Vector2(0, 20)
	title_label.size = Vector2(1024, 40)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", font)
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", TITLE_COLOR)
	title_label.text = "🌐 联机对战大厅"
	add_child(title_label)
	
	# 主面板
	var pw = 660
	var ph = 540
	var px = (1024 - pw) / 2
	var py = 70
	panel = Panel.new()
	panel.position = Vector2(px, py)
	panel.size = Vector2(pw, ph)
	_set_panel_color(panel, PANEL_BG, PANEL_BORDER)
	add_child(panel)
	
	# 局域网信息
	lan_label = Label.new()
	lan_label.position = Vector2(16, 12)
	lan_label.size = Vector2(pw - 32, 22)
	lan_label.add_theme_font_override("font", font)
	lan_label.add_theme_font_size_override("font_size", 14)
	lan_label.add_theme_color_override("font_color", LAN_LABEL_CLR)
	lan_label.text = "局域网: ..."
	panel.add_child(lan_label)
	
	# 自己信息
	me_label = Label.new()
	me_label.position = Vector2(16, 36)
	me_label.size = Vector2(pw - 32, 22)
	me_label.add_theme_font_override("font", font)
	me_label.add_theme_font_size_override("font_size", 14)
	me_label.add_theme_color_override("font_color", SUBTITLE_CLR)
	me_label.text = "你: 植物训练师"
	panel.add_child(me_label)
	
	# 状态
	status_label = Label.new()
	status_label.position = Vector2(16, 60)
	status_label.size = Vector2(pw - 32, 22)
	status_label.add_theme_font_override("font", font)
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", SUBTITLE_CLR)
	status_label.text = _status_msg
	panel.add_child(status_label)
	
	# 分隔线
	var sep = HSeparator.new()
	sep.position = Vector2(12, 86)
	sep.size = Vector2(pw - 24, 2)
	panel.add_child(sep)
	
	# 玩家列表（带滚动）
	player_list_scroll = ScrollContainer.new()
	player_list_scroll.position = Vector2(12, 94)
	player_list_scroll.size = Vector2(pw - 24, ph - 94 - 100)
	player_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(player_list_scroll)
	
	player_list_vbox = VBoxContainer.new()
	player_list_vbox.custom_minimum_size = Vector2(pw - 48, 0)
	player_list_vbox.add_theme_constant_override("separation", 4)
	player_list_scroll.add_child(player_list_vbox)
	
	# -- 底部 IP 输入 + 连接按钮 --
	var bottom_y = ph - 88
	
	var ip_label = Label.new()
	ip_label.position = Vector2(16, bottom_y - 18)
	ip_label.size = Vector2(pw - 32, 18)
	ip_label.add_theme_font_override("font", font)
	ip_label.add_theme_font_size_override("font_size", 12)
	ip_label.add_theme_color_override("font_color", SUBTITLE_CLR)
	ip_label.text = "手动连接 IP（同电脑双开输入 127.0.0.1）:"
	panel.add_child(ip_label)
	
	ip_input = LineEdit.new()
	ip_input.position = Vector2(16, bottom_y + 4)
	ip_input.size = Vector2(pw - 136, 34)
	ip_input.placeholder_text = "127.0.0.1"
	ip_input.add_theme_font_override("font", font)
	ip_input.add_theme_font_size_override("font_size", 16)
	ip_input.max_length = 21
	panel.add_child(ip_input)
	
	connect_btn = Button.new()
	connect_btn.position = Vector2(pw - 110, bottom_y + 4)
	connect_btn.size = Vector2(100, 34)
	connect_btn.text = "连接"
	connect_btn.add_theme_font_override("font", font)
	connect_btn.add_theme_font_size_override("font_size", 15)
	connect_btn.pressed.connect(_on_connect_btn)
	panel.add_child(connect_btn)
	
	# 返回按钮
	back_btn = Button.new()
	back_btn.position = Vector2(20, 768 - 55)
	back_btn.size = Vector2(140, 40)
	back_btn.text = "返回菜单"
	back_btn.add_theme_font_override("font", font)
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.pressed.connect(_on_back)
	add_child(back_btn)
	
	# 连接成功遮罩
	overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	
	overlay_label = Label.new()
	overlay_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay_label.add_theme_font_override("font", font)
	overlay_label.add_theme_font_size_override("font_size", 26)
	overlay_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	overlay_label.text = ""
	overlay.add_child(overlay_label)

func _set_panel_color(p: Panel, bg_c: Color, border_c: Color) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_c
	style.border_color = border_c
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	p.add_theme_stylebox_override("panel", style)

## ══════════════════════════════════════════════════════════
##  LAN 发现
## ══════════════════════════════════════════════════════════

func _start_discovery() -> void:
	_discovery = Node.new()
	_discovery.set_script(load("res://scripts/network/lan_discovery.gd"))
	add_child(_discovery)
	_discovery.start_discovery("植物训练师")
	lan_label.text = "局域网: %s  监听端口: ..." % _discovery.get_subnet_name()
	me_label.text = "你: 植物训练师  ID: %s" % _discovery.get_player_id().left(8).to_upper()

func _stop_discovery() -> void:
	if _discovery:
		_discovery.stop_discovery()

## ══════════════════════════════════════════════════════════
##  TCP 监听（被动方 → 等待邀请 → 成为 Client）
## ══════════════════════════════════════════════════════════

func _start_tcp_listen() -> void:
	for port in range(NetProtocol.LAN_PORT, NetProtocol.LAN_PORT + 10):
		_server = TCPServer.new()
		if _server.listen(port) == OK:
			_server_port = port
			lan_label.text = "局域网: %s  监听端口: %d" % [_discovery.get_subnet_name() if _discovery else "?", port]
			print("[Lobby] TCP 监听: %d" % port)
			return
		_server = null
	print("[Lobby] TCP 端口绑定失败")

func _stop_tcp() -> void:
	if _server:
		_server.stop()
		_server = null
	if _connect_peer:
		_connect_peer.disconnect_from_host()
		_connect_peer = null

## ══════════════════════════════════════════════════════════
##  每帧更新
## ══════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	if _connected:
		return
	
	# 更新玩家列表（每2秒）
	_refresh_timer += delta
	if _refresh_timer >= _refresh_interval:
		_refresh_timer = 0.0
		_check_and_refresh_player_list()
	
	# 状态文字
	if _discovery:
		var players = _discovery.get_online_players()
		if not _inviting:
			if players.size() > 0:
				_status_msg = "已发现 %d 位玩家" % players.size()
			else:
				_status_msg = "等待发现玩家...（可手动输入 IP 连接）"
	status_label.text = _status_msg
	
	# TCP 接受连接（被动方收到邀请）
	_poll_tcp_accept()
	
	# 轮询已发起的连接（主动方发送邀请后的响应）
	_poll_connect_response()

## 轮询 TCP 接受连接
func _poll_tcp_accept() -> void:
	if not _server:
		return
	if _server.is_connection_available():
		var conn = _server.take_connection()
		if conn:
			# 接收邀请消息
			_read_invite(conn)

## 读取邀请并自动接受
func _read_invite(conn: StreamPeerTCP) -> void:
	conn.poll()
	var buf := ""
	var timeout = Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < timeout:
		conn.poll()
		var avail = conn.get_available_bytes()
		if avail > 0:
			var result = conn.get_partial_data(avail)
			if result[0] == OK:
				buf += result[1].get_string_from_utf8()
		if buf.find("\n") >= 0:
			break
		# 等待一小帧
		await get_tree().process_frame
	
	var idx = buf.find("\n")
	if idx >= 0:
		var line = buf.substr(0, idx)
		var parsed = NetProtocol.parse_message(line)
		if parsed and parsed[0] == "INVITE":
			# 自动接受邀请
			var resp = NetProtocol.make_message("INVITE_ACCEPT", {
				"player_id": _discovery.get_player_id() if _discovery else "",
				"player_name": PlayerProfile.get_player_name() if PlayerProfile and PlayerProfile.is_registered() else "植物训练师",
			})
			conn.put_data(resp.to_utf8_buffer())
			
			# 创建 Client 节点
			var client_node = Node.new()
			client_node.set_script(load("res://scripts/network/game_client_net.gd"))
			add_child(client_node)
			# 手动设置已连接的 peer
			client_node._peer = conn
			client_node._connected = true
			client_node._running = true
			
			var host_ip = conn.get_connected_host()
			GlobalNet.setup_client(client_node, parsed[1].get("player_name", ""), host_ip)
			_on_connect_success("client")
			return
	
	# 解析失败或超时，关闭连接
	conn.disconnect_from_host()

## 轮询主动连接的响应
func _poll_connect_response() -> void:
	if not _connect_peer or not _inviting:
		return
	_connect_peer.poll()
	var status = _connect_peer.get_status()
	if status == StreamPeerTCP.STATUS_CONNECTED:
		var avail = _connect_peer.get_available_bytes()
		if avail > 0:
			var result = _connect_peer.get_partial_data(avail)
			if result[0] == OK:
				_recv_buf += result[1].get_string_from_utf8()
		if _recv_buf.find("\n") >= 0:
			var idx = _recv_buf.find("\n")
			var line = _recv_buf.substr(0, idx)
			_recv_buf = ""
			var parsed = NetProtocol.parse_message(line)
			if parsed:
				if parsed[0] == "INVITE_ACCEPT":
					# 创建 Host 节点
					var host_node = Node.new()
					host_node.set_script(load("res://scripts/network/game_host_net.gd"))
					add_child(host_node)
					host_node._peer = _connect_peer
					host_node._client_connected = true
					host_node._running = true
					
					GlobalNet.setup_host(host_node, parsed[1].get("player_name", ""), _connect_peer.get_connected_host())
					_connect_peer = null
					_on_connect_success("host")
				elif parsed[0] == "INVITE_REJECT":
					_status_msg = "对方拒绝了邀请"
					_inviting = false
					_connect_peer = null
	elif status == StreamPeerTCP.STATUS_NONE or status == StreamPeerTCP.STATUS_ERROR:
		_status_msg = "连接失败"
		_inviting = false
		_connect_peer = null

## 连接成功
func _on_connect_success(result: String) -> void:
	_connected = true
	_invite_result = result
	overlay.visible = true
	overlay_label.text = "✅ 连接成功！正在启动游戏..."
	# 停止发现
	_stop_discovery()
	_stop_tcp()
	
	# Host 选择世界并播放阵前曲
	if result == "host" and GlobalMusic:
		var world = GlobalMusic.pick_random_world()
		if world != "":
			GlobalNet.first_player = "P1"
			GlobalMusic.play_pre(world)
			# 将世界名存到 GlobalNet 供 game_board 使用
			GlobalNet.world = world
	
	# 延迟切换场景
	await get_tree().create_timer(1.5).timeout
	lobby_connected.emit()

## ══════════════════════════════════════════════════════════
##  邀请（主动方 → Host 角色）
## ══════════════════════════════════════════════════════════

func _send_invite(peer_ip: String) -> void:
	if _inviting or _connected:
		return
	_status_msg = "正在连接 %s ..." % peer_ip
	_inviting = true
	_recv_buf = ""
	
	# 尝试连接（多端口兼容）
	_connect_peer = StreamPeerTCP.new()
	var connected = false
	
	var is_localhost = peer_ip in ["127.0.0.1", "localhost", "0.0.0.0"]
	for port in range(NetProtocol.LAN_PORT, NetProtocol.LAN_PORT + 10):
		# 跳过自己的监听端口，防止自连
		if is_localhost and port == _server_port:
			continue
		if _connect_peer.connect_to_host(peer_ip, port) == OK:
			# 等待连接建立
			var timeout = Time.get_ticks_msec() + 2000
			while Time.get_ticks_msec() < timeout:
				_connect_peer.poll()
				var s = _connect_peer.get_status()
				if s == StreamPeerTCP.STATUS_CONNECTED:
					connected = true
					break
				elif s == StreamPeerTCP.STATUS_NONE or s == StreamPeerTCP.STATUS_ERROR:
					break
				await get_tree().process_frame
			if connected:
				break
			# 重试下一个端口
			_connect_peer.disconnect_from_host()
			_connect_peer = StreamPeerTCP.new()
	
	if not connected:
		_status_msg = "连接失败: 无法连接到 %s" % peer_ip
		_inviting = false
		_connect_peer = null
		return
	
	# 发送邀请
	var invite = NetProtocol.make_message("INVITE", {
		"player_id": _discovery.get_player_id() if _discovery else "",
		"player_name": PlayerProfile.get_player_name() if PlayerProfile and PlayerProfile.is_registered() else "植物训练师",
	})
	_connect_peer.put_data(invite.to_utf8_buffer())

## ══════════════════════════════════════════════════════════
##  玩家列表 UI
## ══════════════════════════════════════════════════════════

func _check_and_refresh_player_list() -> void:
	"""只在玩家列表变化时才重建 UI，避免按钮被销毁。"""
	if not _discovery:
		return
	var players = _discovery.get_online_players()
	
	# 检查是否有变化
	var current_ids: Array = []
	for p in players:
		current_ids.append(str(p.get("player_id", "")))
	current_ids.sort()
	
	if current_ids == _last_player_ids:
		return  # 没有变化，不重建
	
	_last_player_ids = current_ids
	_rebuild_player_list(players)

func _rebuild_player_list(players: Array) -> void:
	"""实际重建玩家列表 UI。"""
	# 清空
	for child in player_list_vbox.get_children():
		child.queue_free()
	_row_nodes.clear()
	
	if players.size() == 0:
		var empty = Label.new()
		empty.add_theme_font_override("font", font)
		empty.add_theme_font_size_override("font_size", 15)
		empty.add_theme_color_override("font_color", ID_CLR)
		empty.text = "暂无其他玩家在线，可手动输入 IP 连接"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		player_list_vbox.add_child(empty)
		return
	
	for i in range(players.size()):
		var player = players[i]
		var row = _create_player_row(player, i)
		player_list_vbox.add_child(row)
		_row_nodes.append(row)

func _create_player_row(player: Dictionary, idx: int) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 44)
	row.add_theme_constant_override("separation", 8)
	
	# 背景色（奇偶行区分）
	var bg_panel = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = ROW_BG if idx % 2 == 0 else Color(42.0/255, 56.0/255, 76.0/255)
	style.set_corner_radius_all(4)
	bg_panel.add_theme_stylebox_override("panel", style)
	
	# 名字
	var name_l = Label.new()
	name_l.text = "  " + str(player.get("name", "未知"))
	name_l.add_theme_font_override("font", font)
	name_l.add_theme_font_size_override("font_size", 15)
	name_l.add_theme_color_override("font_color", NAME_CLR)
	name_l.custom_minimum_size = Vector2(240, 0)
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_l)
	
	# ID
	var pid = str(player.get("player_id", "")).left(8).to_upper()
	var id_l = Label.new()
	id_l.text = "ID: %s" % pid
	id_l.add_theme_font_override("font", font)
	id_l.add_theme_font_size_override("font_size", 13)
	id_l.add_theme_color_override("font_color", ID_CLR)
	id_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	id_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(id_l)
	
	# 邀请按钮
	var invite_btn = Button.new()
	invite_btn.text = "邀请" if not _inviting else "等待中"
	invite_btn.add_theme_font_override("font", font)
	invite_btn.add_theme_font_size_override("font_size", 14)
	invite_btn.custom_minimum_size = Vector2(80, 30)
	if _inviting:
		invite_btn.disabled = true
	invite_btn.pressed.connect(_on_invite_btn.bind(str(player.get("ip", ""))))
	row.add_child(invite_btn)
	
	return row

## ══════════════════════════════════════════════════════════
##  按钮事件
## ══════════════════════════════════════════════════════════

func _on_invite_btn(peer_ip: String) -> void:
	print("[Lobby] 邀请: %s" % peer_ip)
	_send_invite(peer_ip)

func _on_connect_btn() -> void:
	var ip = ip_input.text.strip_edges()
	if ip == "":
		_status_msg = "请输入 IP 地址"
		return
	print("[Lobby] 手动连接: %s" % ip)
	_send_invite(ip)

func _on_back() -> void:
	_stop_discovery()
	_stop_tcp()
	GlobalNet.cleanup()
	lobby_back.emit()

## 输入处理
func _on_lobby_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_lobby_connected() -> void:
	get_tree().change_scene_to_file("res://scenes/game_board.tscn")

## 输入处理
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_back()
		elif event.keycode == KEY_ENTER and ip_input.has_focus():
			_on_connect_btn()
