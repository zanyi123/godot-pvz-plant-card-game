## deal_animation.gd - 发牌动画控制器
## 描述：牌库卡背飞向手牌区 → 翻面展示卡牌信息 → 动画结束后进入出牌阶段
extends Node

signal deal_finished()

## 动画状态
var _animating: bool = false
var _cards_to_deal: Array = []       # 待发的 CardData 列表
var _card_nodes: Array = []          # 动画中的 Control 节点
var _step: int = 0                   # 0=飞行 1=翻面 2=完成
var _timer: float = 0.0
var _current_index: int = 0
var _parent: Control = null

## 目标位置
var _deck_pos: Vector2 = Vector2.ZERO
var _hand_positions: Array = []      # 每张牌的目标位置

## 参数
const FLY_DURATION: float = 0.3     # 单张飞行时间
const FLIP_DURATION: float = 0.25   # 翻面时间
const DEAL_INTERVAL: float = 0.08   # 发牌间隔

## 卡牌创建回调（由 game_board 提供）
var _create_card_front_func: Callable
var _create_card_back_func: Callable

## 开始发牌动画
## cards: Array[CardData] 要发的牌
## deck_global_pos: 牌库的全局坐标
## hand_global_positions: 每张牌对应手牌区的全局坐标
## parent: 添加动画节点的父节点
func start_deal(cards: Array, deck_global_pos: Vector2, hand_global_positions: Array, parent: Control) -> void:
	_animating = true
	_cards_to_deal = cards
	_deck_pos = deck_global_pos
	_hand_positions = hand_global_positions
	_parent = parent
	_step = 0
	_timer = 0.0
	_current_index = 0
	_card_nodes.clear()
	
	# 预创建所有卡背节点（初始在牌库位置，隐藏）
	for i in range(cards.size()):
		var back_node: Control = _create_card_back_func.call()
		back_node.global_position = _deck_pos
		back_node.visible = false
		back_node.z_index = 100  # 动画层在最上面
		parent.add_child(back_node)
		_card_nodes.append({
			"node": back_node,
			"target_pos": hand_global_positions[i] if i < hand_global_positions.size() else _deck_pos,
			"flying": false,
			"fly_progress": 0.0,
			"flipping": false,
			"flip_progress": 0.0,
			"flipped": false,
			"card_data": cards[i],
		})

func _process(delta: float) -> void:
	if not _animating:
		return
	
	_timer += delta
	
	match _step:
		0:  # 逐张飞行
			_process_flying(delta)
		1:  # 逐张翻面
			_process_flipping(delta)

func _process_flying(_delta: float) -> void:
	# 按间隔触发下一张
	if _current_index < _card_nodes.size():
		if _timer >= DEAL_INTERVAL:
			_timer = 0.0
			var info = _card_nodes[_current_index]
			info["flying"] = true
			info["node"].visible = true
			_current_index += 1
	
	# 更新所有飞行中的牌
	var all_done = true
	for i in range(_card_nodes.size()):
		var info = _card_nodes[i]
		if not info["flying"]:
			if i <= _current_index:
				all_done = false
			continue
		if info["flip_progress"] > 0 or info["flipped"]:
			continue
		
		info["fly_progress"] += _delta / FLY_DURATION if FLY_DURATION > 0 else 1.0
		if info["fly_progress"] >= 1.0:
			info["fly_progress"] = 1.0
			info["node"].global_position = info["target_pos"]
		else:
			var t = _ease_out_quad(info["fly_progress"])
			info["node"].global_position = _deck_pos.lerp(info["target_pos"], t)
			all_done = false
	
	if all_done and _current_index >= _card_nodes.size():
		_step = 1
		_timer = 0.0
		_current_index = 0

func _process_flipping(_delta: float) -> void:
	# 逐张翻面（前半程缩小到0，换正面，后半程放大到1）
	if _current_index >= _card_nodes.size():
		_step = 2
		_animating = false
		# 清理动画节点
		for info in _card_nodes:
			var n = info["node"]
			if n and is_instance_valid(n):
				n.queue_free()
		_card_nodes.clear()
		deal_finished.emit()
		return
	
	var info = _card_nodes[_current_index]
	if not info["flipping"]:
		info["flipping"] = true
		info["flip_progress"] = 0.0
	
	info["flip_progress"] += _delta / FLIP_DURATION if FLIP_DURATION > 0 else 1.0
	
	if info["flip_progress"] >= 1.0:
		info["flip_progress"] = 1.0
		info["flipped"] = true
		# 替换为正面卡
		var old_node: Control = info["node"]
		var front_node: Control = _create_card_front_func.call(info["card_data"])
		front_node.global_position = info["target_pos"]
		front_node.z_index = 100
		_parent.add_child(front_node)
		old_node.queue_free()
		info["node"] = front_node
		_current_index += 1
	else:
		var t = info["flip_progress"]
		var scale_x: float
		if t < 0.5:
			# 前半：卡背缩小
			scale_x = 1.0 - t * 2.0
		else:
			# 后半：正面放大（这里还用卡背，到1.0时才换正面）
			scale_x = (t - 0.5) * 2.0
		scale_x = maxf(scale_x, 0.01)
		info["node"].scale = Vector2(scale_x, 1.0)

func is_animating() -> bool:
	return _animating

## 清理
func force_finish() -> void:
	for info in _card_nodes:
		var n = info["node"]
		if n and is_instance_valid(n):
			n.queue_free()
	_card_nodes.clear()
	_animating = false

static func _ease_out_quad(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)
