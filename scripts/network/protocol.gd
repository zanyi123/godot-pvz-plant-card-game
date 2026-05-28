## network/protocol.gd - 联机通信协议
## 对应 Python: network/protocol.py
## 消息格式：JSON + 换行符分隔，与 Python 版完全兼容
class_name NetProtocol

## 端口配置
const LAN_PORT: int = 9988
const BROADCAST_PORT: int = 9989
const BROADCAST_INTERVAL: float = 2.0
const DISCOVER_TIMEOUT: float = 6.0

## 消息类型
const DISCOVER: String = "DISCOVER"
const DISCOVER_RESP: String = "DISCOVER_RESP"
const INVITE: String = "INVITE"
const INVITE_ACCEPT: String = "INVITE_ACCEPT"
const INVITE_REJECT: String = "INVITE_REJECT"
const GAME_STATE: String = "GAME_STATE"
const PLAYER_ACTION: String = "PLAYER_ACTION"
const GAME_OVER: String = "GAME_OVER"
const HEARTBEAT: String = "HEARTBEAT"
const GOODBYE: String = "GOODBYE"

## 构造 JSON 消息（带换行符结尾）
static func make_message(msg_type: String, payload: Dictionary = {}) -> String:
	var msg = {"type": msg_type, "payload": payload}
	var json = JSON.new()
	return json.stringify(msg, "", false) + "\n"

## 解析 JSON 消息，返回 [type, payload] 或 null
static func parse_message(data: String) -> Variant:
	data = data.strip_edges()
	if data == "":
		return null
	var json = JSON.new()
	if json.parse(data) != OK:
		return null
	var obj = json.get_data()
	if not obj is Dictionary:
		return null
	return [obj.get("type", ""), obj.get("payload", {})]

## 获取本机局域网 IP
static func get_local_ip() -> String:
	var addresses = IP.get_local_addresses()
	for addr in addresses:
		# 过滤掉 127.x.x.x 和 0.0.0.0
		if addr != "127.0.0.1" and addr != "0.0.0.0" and addr.find(":") < 0:
			return addr
	return "127.0.0.1"

## 获取子网标识
static func get_subnet_name() -> String:
	var ip = get_local_ip()
	var parts = ip.split(".")
	if parts.size() >= 3:
		return "%s.%s.%s.x" % [parts[0], parts[1], parts[2]]
	return ip

## 序列化卡牌列表（用于状态同步）
static func serialize_cards(cards: Array, hide: bool = false) -> Array:
	var result: Array = []
	if hide:
		for _c in cards:
			result.append({"hidden": true})
		return result
	for card in cards:
		if card is CardData:
			result.append({
				"id": card.id,
				"name": card.name,
				"cost": card.cost,
				"atk": card.atk,
				"faction": card.faction,
				"type": card.type,
				"limit_flag": card.limit_flag,
				"effect_id": card.effect_id,
				"description": card.description,
				"image_file": card.image_file,
			})
		elif card is Dictionary:
			result.append(card)
	return result

## 反序列化卡牌
static func deserialize_card(d: Dictionary) -> CardData:
	var card = CardData.new()
	card.id = int(d.get("id", 0))
	card.name = str(d.get("name", ""))
	card.cost = int(d.get("cost", 0))
	card.atk = int(d.get("atk", 0))
	card.faction = str(d.get("faction", ""))
	card.type = str(d.get("type", ""))
	card.limit_flag = bool(d.get("limit_flag", false))
	card.effect_id = str(d.get("effect_id", ""))
	card.description = str(d.get("description", ""))
	card.image_file = str(d.get("image_file", ""))
	return card

## 反序列化卡牌列表
static func deserialize_cards(arr: Array) -> Array[CardData]:
	var cards: Array[CardData] = []
	for item in arr:
		if item is Dictionary:
			if item.get("hidden", false):
				var c = CardData.new()
				c.name = "?"
				cards.append(c)
			else:
				cards.append(deserialize_card(item))
	return cards
