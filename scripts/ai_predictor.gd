## 三回合预测器：基于当前状态预测未来3回合的最优决策
## 仅基于自己的状态预测，不假设知道对方手牌
class_name AIPredictor

static func predict_and_decide(
	hand: Array,
	mana: int,
	my_hp: int,
	my_max_hp: int,
	opp_hp: int,
	opp_max_hp: int,
	opp_main_faction: String,
	opp_main_atk: int,
	opp_played_count: int,
	round: int,
	opp_avg_damage: float
) -> Array:
	var current: Dictionary = _evaluate_current(
		hand, mana, my_hp, my_max_hp, opp_hp, opp_max_hp,
		opp_main_faction, opp_main_atk, opp_played_count, round
	)

	if current.get("combo", []).is_empty():
		return []

	var next_hand: Array = _simulate_next_hand(hand, current.get("combo", []))
	var next_mana: int = _simulate_next_mana(mana, current.get("combo", []), round)
	var next_hp: int = _simulate_next_hp(my_hp, my_max_hp, current.get("combo", []), opp_avg_damage)

	var next: Dictionary = _evaluate_current(
		next_hand, next_mana, next_hp, my_max_hp, opp_hp, opp_max_hp,
		opp_main_faction, opp_main_atk, opp_played_count, round + 1
	)

	var third_hand: Array = _simulate_next_hand(next_hand, next.get("combo", []))
	var third_mana: int = _simulate_next_mana(next_mana, next.get("combo", []), round + 1)
	var third_hp: int = _simulate_next_hp(next_hp, my_max_hp, next.get("combo", []), opp_avg_damage)

	var third: Dictionary = _evaluate_current(
		third_hand, third_mana, third_hp, my_max_hp, opp_hp, opp_max_hp,
		opp_main_faction, opp_main_atk, opp_played_count, round + 2
	)

	var total_score: float = current.get("score", 0.0) * 1.0 \
		+ next.get("score", 0.0) * 0.6 \
		+ third.get("score", 0.0) * 0.3

	var current_combo_score: float = current.get("score", 0.0)
	var immediate_value: float = current.get("immediate_value", 0.0)

	if immediate_value >= opp_hp:
		return current.get("combo", [])

	if current_combo_score >= 15.0:
		return current.get("combo", [])

	return current.get("combo", [])

static func _evaluate_current(
	hand: Array,
	mana: int,
	my_hp: int,
	my_max_hp: int,
	opp_hp: int,
	opp_max_hp: int,
	opp_main_faction: String,
	opp_main_atk: int,
	opp_played_count: int,
	round: int
) -> Dictionary:
	var combos: Array = AIStrategy.generate_valid_combos(hand, mana)
	if combos.is_empty():
		return {"combo": [], "score": 0.0, "immediate_value": 0}

	var scored: Array = []
	for combo in combos:
		var s: float = AIStrategy.evaluate_combo(
			combo, my_hp, my_max_hp, opp_hp, opp_max_hp,
			opp_main_faction, opp_main_atk, opp_played_count, round
		)
		var dmg: int = EffectCalculator.calc_combo_damage(combo, opp_main_faction, opp_played_count, opp_main_atk)
		scored.append({"combo": combo, "score": s, "immediate_value": dmg})

	scored.sort_custom(func(a, b): return a.score > b.score)
	var best: Dictionary = scored[0]
	return best

static func _simulate_next_hand(current_hand: Array, played_cards: Array) -> Array:
	var remaining: Array = []
	for card in current_hand:
		var played: bool = false
		for pc in played_cards:
			if card == pc:
				played = true
				break
		if not played:
			remaining.append(card)

	return remaining

static func _simulate_next_mana(current_mana: int, played_cards: Array, round: int) -> int:
	var base_mana: int = 3 + int(round / 2)
	var mana_gain: int = 0
	for card in played_cards:
		if card is CardData:
			match card.effect_id:
				"MANA_1": mana_gain += 1
				"MANA_2": mana_gain += 2
				"MANA_3": mana_gain += 3
				"MANA_4": mana_gain += 4
				"MANA_": mana_gain += 0
	return base_mana + mana_gain

static func _simulate_next_hp(current_hp: int, max_hp: int, played_cards: Array, opp_avg_damage: float) -> int:
	var hp: int = current_hp
	for card in played_cards:
		if not (card is CardData):
			continue
		match card.effect_id:
			"HEAL_1": hp += 1
			"HEAL_2": hp += 2
			"HEAL_3": hp += 3
			"HEAL_4": hp += 4
			"HEAL_8": hp = max_hp
			"BOOST_ATK_HEAL": hp += 2
			"COST_TO_HEAL":
				for other in played_cards:
					if other != card and other is CardData:
						hp += other.cost
			"COST_TO_HEAL_SELF": hp += card.cost
	hp -= int(opp_avg_damage)
	return maxi(0, hp)

static func calculate_opp_avg_damage(history: Array) -> float:
	if history.is_empty():
		return 3.0
	var total: float = 0.0
	var count: int = 0
	for entry in history:
		if entry.has("P2"):
			var dmg: int = 0
			for card in entry["P2"]:
				if card is CardData:
					dmg += card.atk
			total += float(dmg)
			count += 1
	if count == 0:
		return 3.0
	return total / float(count)
