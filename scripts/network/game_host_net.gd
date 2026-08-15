## network/game_host_net.gd - 联机 Host（房主）端
## 对应 Python: network/game_host.py
## 职责：运行完整游戏逻辑，接收 Client 操作，同步状态给 Client
extends Node

signal client_connected()
signal client_disconnected()
signal action_received(action: Dictionary)

var _server: TCPServer
var _peer: StreamPeerTCP
var _recv_buffer: String = ""
var _action_queue: Array = []
var _running: bool = false
var _client_connected: bool = false
var _listen_port: int = 0

## 启动 TCP 监听（双开兼容：尝试多个端口）
func start_server(base_port: int = NetProtocol.LAN_PORT) -> bool:
	for port in range(base_port, base_port + 10):
		_server = TCPServer.new()
		var err = _server.listen(port)
		if err == OK:
			_listen_port = port
			_running = true
			if OS.has_feature("debug"):
				print("[GameHost] 监听启动: 端口 %d" % port)
			return true
		_server = null
	if OS.has_feature("debug"):
		print("[GameHost] 所有端口绑定失败")
	return false

## 获取监听端口
func get_listen_port() -> int:
	return _listen_port

## 每帧轮询
func _process(_delta: float) -> void:
	if not _running:
		return
	
	# 接受新连接
	if _server and _server.is_connection_available():
		if _peer == null:
			_peer = _server.take_connection()
			_client_connected = true
			client_connected.emit()
			if OS.has_feature("debug"):
				print("[GameHost] Client 已连接")
		else:
			# 已有连接，拒绝新的
			var rejected = _server.take_connection()
			if rejected:
				rejected.disconnect_from_host()
	
	# 读取数据
	if _peer:
		_peer.poll()
		var status = _peer.get_status()
		if status == StreamPeerTCP.STATUS_CONNECTED:
			var available = _peer.get_available_bytes()
			while available > 0:
				var result = _peer.get_partial_data(mini(available, 8192))
				if result[0] == OK:
					_recv_buffer += result[1].get_string_from_utf8()
				available = _peer.get_available_bytes()
			# 处理完整消息
			_process_buffer()
		elif status == StreamPeerTCP.STATUS_NONE or status == StreamPeerTCP.STATUS_ERROR:
			_client_connected = false
			client_disconnected.emit()
			_peer = null

## 处理接收缓冲区中的完整消息
func _process_buffer() -> void:
	while _recv_buffer.find("\n") >= 0:
		var idx = _recv_buffer.find("\n")
		var line = _recv_buffer.substr(0, idx)
		_recv_buffer = _recv_buffer.substr(idx + 1)
		var parsed = NetProtocol.parse_message(line)
		if parsed:
			var msg_type: String = parsed[0]
			var payload: Dictionary = parsed[1]
			if msg_type == "PLAYER_ACTION":
				_action_queue.append(payload)
				action_received.emit(payload)
			elif msg_type == "HEARTBEAT":
				pass  # 心跳忽略
			elif msg_type == "GOODBYE":
				_client_connected = false
				client_disconnected.emit()
				_peer = null

## 获取并清空 Client 操作队列
func poll_actions() -> Array:
	var actions = _action_queue.duplicate()
	_action_queue.clear()
	return actions

## 发送游戏状态给 Client
func send_state(state: Dictionary) -> void:
	if not _peer or not _client_connected:
		return
	_peer.poll()
	if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
	var msg = NetProtocol.make_message("GAME_STATE", state)
	var err = _peer.put_data(msg.to_utf8_buffer())
	if err != OK:
		if OS.has_feature("debug"):
			print("[GameHost] 发送状态失败: %d" % err)

## Client 是否已连接
func is_client_connected() -> bool:
	return _client_connected

## 关闭连接
func close() -> void:
	_running = false
	if _peer:
		# 发送 GOODBYE
		var msg = NetProtocol.make_message("GOODBYE", {})
		_peer.put_data(msg.to_utf8_buffer())
		_peer.disconnect_from_host()
		_peer = null
	if _server:
		_server.stop()
		_server = null
	_client_connected = false
