## global_net.gd - 联机全局单例（AutoLoad）
## 跨场景传递网络连接信息：大厅 → 战斗场景
## 类似 GlobalMusic 的设计
extends Node

## 网络角色："" = 本地, "host" = 房主, "client" = 加入方
var role: String = ""

## 网络节点引用
var host_node: Node = null   # GameHostNet 实例
var client_node: Node = null # GameClientNet 实例

## 对手信息
var peer_name: String = ""
var peer_ip: String = ""

## 先手选择结果（联机模式下由 Host 决定并同步）
var first_player: String = "P1"

## 联机世界的音乐（由 Host 选定）
var world: String = ""

## 是否处于联机模式
func is_online() -> bool:
	return role != ""

## 是否是 Host
func is_host() -> bool:
	return role == "host"

## 是否是 Client
func is_client() -> bool:
	return role == "client"

## 设置为 Host 模式
func setup_host(host: Node, peer_n: String = "", peer_i: String = "") -> void:
	role = "host"
	# 将网络节点移到 GlobalNet（AutoLoad）下，防止场景切换时被销毁
	if host.get_parent():
		host.get_parent().remove_child(host)
	add_child(host)
	host_node = host
	peer_name = peer_n
	peer_ip = peer_i
	if OS.has_feature("debug"):
		print("[GlobalNet] 设置为 Host, 对手: %s (%s)" % [peer_n, peer_i])

## 设置为 Client 模式
func setup_client(client: Node, peer_n: String = "", peer_i: String = "") -> void:
	role = "client"
	# 将网络节点移到 GlobalNet（AutoLoad）下，防止场景切换时被销毁
	if client.get_parent():
		client.get_parent().remove_child(client)
	add_child(client)
	client_node = client
	peer_name = peer_n
	peer_ip = peer_i
	if OS.has_feature("debug"):
		print("[GlobalNet] 设置为 Client, 对手: %s (%s)" % [peer_n, peer_i])

## 清理网络资源
func cleanup() -> void:
	if host_node:
		host_node.close()
		if host_node.get_parent():
			host_node.get_parent().remove_child(host_node)
		host_node.queue_free()
		host_node = null
	if client_node:
		client_node.close()
		if client_node.get_parent():
			client_node.get_parent().remove_child(client_node)
		client_node.queue_free()
		client_node = null
	role = ""
	peer_name = ""
	peer_ip = ""
	first_player = "P1"
	if OS.has_feature("debug"):
		print("[GlobalNet] 已清理")
