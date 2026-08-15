## network/game_client_net.gd - 联机 Client（加入方）端
## 对应 Python: network/game_client.py
## 职责：接收 Host 状态，发送 P2 操作，不运行游戏逻辑
extends Node

signal connected_to_host()
signal disconnected_from_host()
signal state_received(state: Dictionary)
signal first_player_received(first_player: String)

var _peer: StreamPeerTCP
var _recv_buffer: String = ""
var _latest_state: Dictionary = {}
var _running: bool = false
var _connected: bool = false
var _disconnect_count: int = 0

## 连接到 Host
func connect_to_host(ip: String, port: int = NetProtocol.LAN_PORT) -> bool:
	_peer = StreamPeerTCP.new()
	var err = _peer.connect_to_host(ip, port)
	if err != OK:
		if OS.has_feature("debug"):
			print("[GameClient] 连接失败: %s:%d (err=%d)" % [ip, port, err])
		return false
	_running = true
	if OS.has_feature("debug"):
		print("[GameClient] 正在连接 %s:%d ..." % [ip, port])
	return true

## 每帧轮询
func _process(_delta: float) -> void:
	if not _running or not _peer:
		return
	
	_peer.poll()
	var status = _peer.get_status()
	
	match status:
		StreamPeerTCP.STATUS_CONNECTING:
			return  # 还在连接中
		StreamPeerTCP.STATUS_CONNECTED:
			if not _connected:
				_connected = true
				connected_to_host.emit()
				if OS.has_feature("debug"):
					print("[GameClient] 已连接到 Host")
			_disconnect_count = 0
			# 读取数据
			var available = _peer.get_available_bytes()
			while available > 0:
				var result = _peer.get_partial_data(mini(available, 65536))
				if result[0] == OK:
					_recv_buffer += result[1].get_string_from_utf8()
				available = _peer.get_available_bytes()
			_process_buffer()
		StreamPeerTCP.STATUS_NONE, StreamPeerTCP.STATUS_ERROR:
			_disconnect_count += 1
			if _disconnect_count > 300:  # 5秒无连接
				if _connected:
					_connected = false
					disconnected_from_host.emit()
				_running = false
				if OS.has_feature("debug"):
					print("[GameClient] 与 Host 断开连接")

## 处理接收缓冲区（只保留最新状态）
func _process_buffer() -> void:
	while _recv_buffer.find("\n") >= 0:
		var idx = _recv_buffer.find("\n")
		var line = _recv_buffer.substr(0, idx)
		_recv_buffer = _recv_buffer.substr(idx + 1)
		var parsed = NetProtocol.parse_message(line)
		if parsed:
			var msg_type: String = parsed[0]
			var payload: Dictionary = parsed[1]
			if msg_type == "GAME_STATE":
				_latest_state = payload
				state_received.emit(payload)
			elif msg_type == "FIRST_PLAYER":
				# 收到 Host 的先手选择
				if GlobalNet:
					GlobalNet.first_player = payload.get("first_player", "P1")
					if OS.has_feature("debug"):
						print("[GameClient] 收到先手选择: %s" % GlobalNet.first_player)
				first_player_received.emit(payload.get("first_player", "P1"))
			elif msg_type == "GOODBYE":
				_connected = false
				disconnected_from_host.emit()
				_running = false

## 获取最新状态
func get_latest_state() -> Dictionary:
	return _latest_state

## 发送操作给 Host
func send_action(action: String, data: Dictionary = {}) -> void:
	if not _peer or not _connected:
		return
	var payload = {"action": action}
	payload.merge(data)
	var msg = NetProtocol.make_message("PLAYER_ACTION", payload)
	_peer.put_data(msg.to_utf8_buffer())

## 发送心跳
func send_heartbeat() -> void:
	if not _peer or not _connected:
		return
	var msg = NetProtocol.make_message("HEARTBEAT", {})
	_peer.put_data(msg.to_utf8_buffer())

## 是否已连接
func is_connected_to_host() -> bool:
	return _connected

## 关闭连接
func close() -> void:
	_running = false
	if _peer:
		var msg = NetProtocol.make_message("GOODBYE", {})
		_peer.put_data(msg.to_utf8_buffer())
		_peer.disconnect_from_host()
		_peer = null
	_connected = false
