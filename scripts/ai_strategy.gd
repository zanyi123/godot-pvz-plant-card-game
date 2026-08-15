## 策略生成器：生成合法组合 + 策略评分 + 最优选择
## 严格遵守 limit_flag 和阵营组合规则
class_name AIStrategy

static func generate_valid_combos(hand: Array, mana: int) -> Array:
	var combos: Array = []
	var limit_cards: Array = []
	var combo_mains: Array = []
	var combo_supps: Array = []
	var all_cards: Array = []

	for card in hand:
		if not (card is CardData):
			continue
		all_cards.append(card)
		if card.limit_flag:
			limit_cards.append(card)
		elif card.faction in ["法", "射", "坦"]:
			combo_mains.append(card)
		elif card.faction == "辅":
			combo_supps.append(card)

	# 生成cost允许的单卡组合
	for card in hand:
		if card is CardData and card.cost <= mana:
			combos.append([card])

	# 生成合法的双卡组合（主+辅）
	for main in combo_mains:
		for supp in combo_supps:
			if main.cost + supp.cost <= mana:
				combos.append([main, supp])

	return combos

static func evaluate_combo(
	combo: Array,
	my_hp: int,
	my_max_hp: int,
	opp_hp: int,
	opp_max_hp: int,
	opp_main_faction: String,
	opp_main_atk: int,
	opp_played_count: int,
	round: int
) -> float:
	var score: float = 0.0
	var damage: int = EffectCalculator.calc_combo_damage(combo, opp_main_faction, opp_played_count, opp_main_atk)
	var heal: int = EffectCalculator.calc_combo_heal(combo, my_hp, my_max_hp)
	var shield: int = EffectCalculator.calc_combo_shield(combo)
	var control: float = EffectCalculator.calc_combo_control(combo)
	var mana_gain: int = EffectCalculator.calc_combo_mana(combo)
	var cost: int = EffectCalculator.calc_combo_cost(combo)

	score += float(damage) * 2.0
	score += float(heal) * 1.5
	score += float(shield) * 1.2
	score += control * 1.2
	score += float(mana_gain) * 1.0

	# 硬性记忆加分：基于卡牌特性的组合规则匹配
	score += AIComboMemory.get_combination_bonus(combo)

	var hp_ratio: float = float(my_hp) / float(my_max_hp) if my_max_hp > 0 else 1.0
	var opp_hp_ratio: float = float(opp_hp) / float(opp_max_hp) if opp_max_hp > 0 else 1.0

	if hp_ratio <= 0.3:
		if heal > 0:
			score += 50.0
		if shield > 0:
			score += 40.0
		var has_reflect: bool = false
		for card in combo:
			if card is CardData and card.effect_id == "REFLECT_ATK":
				has_reflect = true
				break
		if has_reflect:
			score += 35.0

	if damage >= opp_hp:
		score += 100.0
	elif damage >= opp_hp * 0.7:
		score += 30.0

	if round <= 3 and mana_gain > 0:
		score += 20.0

	if combo.size() == 2:
		score += 15.0

	if combo.size() == 1 and combo[0] is CardData and combo[0].limit_flag:
		score += 5.0

	if round > 5:
		score += 5.0

	score -= float(cost) * 0.5

	return score

static func select_best_combo(
	combos: Array,
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
) -> Array:
	if combos.is_empty():
		# 兜底强制出牌逻辑：从手牌中找cost最小的卡，不考虑精力限制
		var fallback_card: CardData = null
		var min_cost: int = 999
		for card in hand:
			if card is CardData and card.cost < min_cost:
				min_cost = card.cost
				fallback_card = card
		if fallback_card:
			return [fallback_card]
		return []

	var scored: Array = []
	for combo in combos:
		var s: float = evaluate_combo(
			combo, my_hp, my_max_hp, opp_hp, opp_max_hp,
			opp_main_faction, opp_main_atk, opp_played_count, round
		)
		scored.append({"combo": combo, "score": s})

	scored.sort_custom(func(a, b): return a.score > b.score)

	return scored[0].combo

static func should_keep_card(card: CardData, my_hp: int, my_max_hp: int, hand: Array, round: int) -> bool:
	if card.limit_flag:
		if card.effect_id == "HEAL_8" and float(my_hp) / float(my_max_hp) <= 0.3:
			return true
		if card.effect_id == "SHIELD_TURN" and float(my_hp) / float(my_max_hp) <= 0.2:
			return true
		if card.effect_id == "SILENCE":
			return true
		if card.effect_id == "HEAL_4" and float(my_hp) / float(my_max_hp) <= 0.4:
			return true
		return false

	if round >= 6:
		if card.atk >= 4 or card.effect_id in ["SILENCE", "SHIELD_TURN"]:
			return true

	return false
