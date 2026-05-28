## network/lan_discovery.gd - 局域网玩家发现
## 对应 Python: network/lan_discovery.py
## UDP 广播 + 监听，无需中心服务器
extends Node

## 发现新玩家信号
signal player_discovered(player_id: String, name: String, ip: String)
signal player_lost(player_id: String)

## 在线玩家列表
var _players: Dictionary = {}  # {player_id: {name, ip, last_seen}}
var _running: bool = false
var _broadcast_timer: float = 0.0

## UDP 节点
var _udp_send: PacketPeerUDP
var _udp_recv: PacketPeerUDP

## 本机信息
var _my_id: String = ""
var _my_name: String = "植物训练师"

func _ready() -> void:
	_my_id = _generate_player_id()

func _process(delta: float) -> void:
	if not _running:
		return
	
	# 周期广播
	_broadcast_timer += delta
	if _broadcast_timer >= NetProtocol.BROADCAST_INTERVAL:
		_broadcast_timer = 0.0
		_send_broadcast()
	
	# 监听广播
	_receive_broadcasts()
	
	# 超时剔除
	_timeout_players(delta)

## 启动发现服务
func start_discovery(player_name: String = "植物训练师") -> void:
	_my_name = player_name
	_running = true
	_broadcast_timer = NetProtocol.BROADCAST_INTERVAL  # 立即发送第一次
	
	# 创建发送 UDP
	_udp_send = PacketPeerUDP.new()
	_udp_send.set_broadcast_enabled(true)
	
	# 创建接收 UDP
	_udp_recv = PacketPeerUDP.new()
	var err = _udp_recv.bind(NetProtocol.BROADCAST_PORT)
	if err != OK:
		print("[LanDiscovery] 绑定广播端口失败: %d, 尝试备用端口" % NetProtocol.BROADCAST_PORT)
		# 备用端口
		for alt_port in range(NetProtocol.BROADCAST_PORT + 1, NetProtocol.BROADCAST_PORT + 5):
			if _udp_recv.bind(alt_port) == OK:
				print("[LanDiscovery] 绑定备用端口成功: %d" % alt_port)
				break
	
	print("[LanDiscovery] 启动完成, ID=%s, IP=%s" % [_my_id, NetProtocol.get_local_ip()])

## 停止发现服务
func stop_discovery() -> void:
	_running = false
	if _udp_send:
		_udp_send.close()
		_udp_send = null
	if _udp_recv:
		_udp_recv.close()
		_udp_recv = null

## 获取在线玩家列表
func get_online_players() -> Array:
	var result: Array = []
	var now = Time.get_ticks_msec() / 1000.0
	for pid in _players:
		var info = _players[pid]
		result.append({
			"player_id": pid,
			"name": info.get("name", "未知"),
			"ip": info.get("ip", ""),
		})
	return result

## 获取本机 IP
func get_local_ip() -> String:
	return NetProtocol.get_local_ip()

## 获取子网名称
func get_subnet_name() -> String:
	return NetProtocol.get_subnet_name()

## 获取本机 ID
func get_player_id() -> String:
	return _my_id

## -- 内部方法 ------------------------------------------

func _send_broadcast() -> void:
	if not _udp_send:
		return
	var msg = NetProtocol.make_message("DISCOVER", {
		"player_id": _my_id,
		"player_name": _my_name,
		"ip": NetProtocol.get_local_ip(),
	})
	_udp_send.set_dest_address("255.255.255.255", NetProtocol.BROADCAST_PORT)
	_udp_send.put_packet(msg.to_utf8_buffer())

func _receive_broadcasts() -> void:
	if not _udp_recv:
		return
	while _udp_recv.get_available_packet_count() > 0:
		var packet = _udp_recv.get_packet()
		if packet.size() == 0:
			continue
		var data = packet.get_string_from_utf8()
		var parsed = NetProtocol.parse_message(data)
		if parsed == null:
			continue
		var msg_type: String = parsed[0]
		var payload: Dictionary = parsed[1]
		if msg_type == "DISCOVER":
			var pid: String = str(payload.get("player_id", ""))
			if pid != "" and pid != _my_id:
				var now = Time.get_ticks_msec() / 1000.0
				var is_new = not _players.has(pid)
				_players[pid] = {
					"name": payload.get("player_name", "未知"),
					"ip": payload.get("ip", ""),
					"last_seen": now,
				}
				if is_new:
					player_discovered.emit(pid, _players[pid]["name"], _players[pid]["ip"])

func _timeout_players(delta: float) -> void:
	var now = Time.get_ticks_msec() / 1000.0
	var to_remove: Array = []
	for pid in _players:
		var info = _players[pid]
		if now - float(info.get("last_seen", 0)) > NetProtocol.DISCOVER_TIMEOUT:
			to_remove.append(pid)
	for pid in to_remove:
		_players.erase(pid)
		player_lost.emit(pid)

func _generate_player_id() -> String:
	# 基于时间戳 + 随机数生成唯一 ID
	var t = Time.get_ticks_msec()
	var r = randi() % 100000
	return "%x%x" % [t, r]
