## AI系统主入口：普通AI与大师AI的调度中心
## 普通AI：单卡贪心（出攻击力最大的一张）
## 大师AI：组合搜索 + 策略评分 + 三回合预测
class_name AISystem extends RefCounted

enum AILevel { NORMAL, MASTER }

var ai_level: AILevel = AILevel.MASTER
var opp_played_cards: int = 0
var _damage_history: Array = []
var _predict_rounds: int = 3

func set_level(level: AILevel) -> void:
	ai_level = level

func record_opponent_play(cards: Array) -> void:
	opp_played_cards = cards.size()

func ai_play(
	hand: Array,
	mana: int,
	my_hp: int,
	my_max_hp: int,
	opp_hp: int,
	opp_max_hp: int,
	opp_main_faction: String,
	opp_main_atk: int,
	round: int,
	opp_played_this_turn: int
) -> Array:
	if ai_level == AILevel.NORMAL:
		return _normal_play(hand, mana)
	else:
		return _master_play(
			hand, mana, my_hp, my_max_hp,
			opp_hp, opp_max_hp, opp_main_faction, opp_main_atk,
			round, opp_played_this_turn
		)

func _normal_play(hand: Array, mana: int) -> Array:
	var playable: Array = []
	var all_cards: Array = []

	for card in hand:
		if not (card is CardData):
			continue
		all_cards.append(card)
		if card.cost <= mana:
			playable.append(card)

	if not playable.is_empty():
		playable.sort_custom(func(a, b): return a.atk > b.atk)
		return [playable[0]]

	# 强制兜底：没有符合精力的卡时，选cost最小的卡
	if not all_cards.is_empty():
		all_cards.sort_custom(func(a, b): return a.cost < b.cost)
		return [all_cards[0]]

	return []

func _master_play(
	hand: Array,
	mana: int,
	my_hp: int,
	my_max_hp: int,
	opp_hp: int,
	opp_max_hp: int,
	opp_main_faction: String,
	opp_main_atk: int,
	round: int,
	opp_played_count: int
) -> Array:
	if round <= 1 or _predict_rounds <= 0:
		var combos: Array = AIStrategy.generate_valid_combos(hand, mana)
		var chosen: Array = AIStrategy.select_best_combo(
			combos, hand, mana, my_hp, my_max_hp,
			opp_hp, opp_max_hp, opp_main_faction, opp_main_atk,
			opp_played_count, round
		)
		if chosen.is_empty():
			return _force_fallback(hand)
		return chosen

	var opp_avg_dmg: float = AIPredictor.calculate_opp_avg_damage(_damage_history)

	var result: Array = AIPredictor.predict_and_decide(
		hand, mana, my_hp, my_max_hp,
		opp_hp, opp_max_hp, opp_main_faction, opp_main_atk,
		opp_played_count, round, opp_avg_dmg
	)

	if result.is_empty():
		var combos: Array = AIStrategy.generate_valid_combos(hand, mana)
		var chosen: Array = AIStrategy.select_best_combo(
			combos, hand, mana, my_hp, my_max_hp,
			opp_hp, opp_max_hp, opp_main_faction, opp_main_atk,
			opp_played_count, round
		)
		if chosen.is_empty():
			return _force_fallback(hand)
		return chosen

	return result

func _force_fallback(hand: Array) -> Array:
	var fallback_card: CardData = null
	var min_cost: int = 999
	for card in hand:
		if card is CardData and card.cost < min_cost:
			min_cost = card.cost
			fallback_card = card
	if fallback_card:
		return [fallback_card]
	return []

func record_round_result(my_cards: Array, opp_cards: Array) -> void:
	var my_dmg: int = 0
	for card in my_cards:
		if card is CardData:
			my_dmg += card.atk
	_damage_history.append(my_dmg)
	if _damage_history.size() > 10:
		_damage_history.pop_front()

func reset() -> void:
	opp_played_cards = 0
	_damage_history.clear()
