## 全局卡牌效果计算器：伤害/治疗/护盾/控制/能量计算
## 任何模块（AI、UI展示、调试工具）均可调用，与AI难度无关
## 严格遵守倍率仅作用于自身atk的规则
## 伤害计算完全对齐 effect_system.gd._calc_raw_damage 逻辑
class_name EffectCalculator

const FACTION_COUNTER := {"法": "射", "射": "坦", "坦": "法"}

const RATE_MULTIPLIER_IDS := {
	"COUNTER_DMG_X3": 3,
	"NO_COUNTER_DMG_X2": 2,
	"DMG_BUFF_2X_COUNTER": 2,
}

static func calc_combo_damage(
	combo: Array,
	opp_main_faction: String,
	opp_played_count: int,
	opp_main_atk: int = 0
) -> int:
	var main_card: CardData = null
	var supp_cards: Array = []
	var has_support: bool = false

	for card in combo:
		if not (card is CardData):
			continue
		if card.faction == "辅":
			supp_cards.append(card)
			has_support = true
		elif card.faction in ["法", "射", "坦"] and main_card == null:
			main_card = card

	if main_card == null:
		return 0

	var main_atk: int = main_card.atk
	var opp_atk: int = opp_main_atk

	var my_faction: String = main_card.faction
	var i_counter_opp: bool = FACTION_COUNTER.get(my_faction, "") == opp_main_faction
	var opp_counters_me: bool = FACTION_COUNTER.get(opp_main_faction, "") == my_faction

	var main_damage: int = 0
	if i_counter_opp:
		main_damage = maxi(0, main_atk - opp_atk)
	elif opp_counters_me:
		main_damage = 0
	else:
		main_damage = main_atk

	var main_mult: float = 1.0
	match main_card.effect_id:
		"COUNTER_DMG_X3":
			if opp_main_faction == "坦":
				main_mult *= 3.0
		"NO_COUNTER_DMG_X2":
			if opp_main_faction != "坦":
				main_mult *= 2.0
		"DMG_BUFF_2X_COUNTER":
			if opp_main_faction == "坦":
				main_mult *= 2.0
		"SUPPORT_DMG_MULTIPLIER":
			if has_support:
				main_mult *= 3.0
		"MULTIPLY_DMG_BY_OPPONENT_COUNT":
			if opp_played_count > 0:
				main_mult *= float(opp_played_count)

	var total: int = int(main_damage * main_mult)

	for supp in supp_cards:
		var supp_atk: int = supp.atk
		var supp_mult: float = 1.0
		match supp.effect_id:
			"COUNTER_DMG_X3":
				if opp_main_faction == "坦":
					supp_mult *= 3.0
			"NO_COUNTER_DMG_X2":
				if opp_main_faction != "坦":
					supp_mult *= 2.0
			"DMG_BUFF_2X_COUNTER":
				if opp_main_faction == "坦":
					supp_mult *= 2.0
			"SUPPORT_DMG_MULTIPLIER":
				if has_support:
					supp_mult *= 3.0
			"MULTIPLY_DMG_BY_OPPONENT_COUNT":
				if opp_played_count > 0:
					supp_mult *= float(opp_played_count)
		total += int(supp_atk * supp_mult)

	for card in combo:
		if not (card is CardData):
			continue
		match card.effect_id:
			"DMG_BUFF_ADD_3":
				total += 3
			"BOOST_ATK_HEAL":
				total += 2
			"DMG_BUFF_ADD_2":
				total += 2

	return maxi(0, total)

static func calc_combo_heal(combo: Array, my_hp: int, max_hp: int) -> int:
	var heal: int = 0
	for card in combo:
		if not (card is CardData):
			continue
		match card.effect_id:
			"HEAL_1":
				heal += 1
			"HEAL_2":
				heal += 2
			"HEAL_3":
				heal += 3
			"HEAL_4":
				heal += 4
			"HEAL_8":
				heal = maxi(heal, max_hp - my_hp)
				if heal <= 0:
					heal = 8
			"BOOST_ATK_HEAL":
				heal += 2
			"COST_TO_HEAL":
				for other in combo:
					if other != card and other is CardData:
						heal += other.cost
			"COST_TO_HEAL_SELF":
				heal += card.cost
			"SHIELD_TURN":
				pass
			"SHIELD_1":
				pass
			"SHIELD_2":
				pass
			"SHIELD_4":
				pass
			"SHIELD_6":
				pass
	return heal

static func calc_combo_shield(combo: Array) -> int:
	var shield: int = 0
	for card in combo:
		if not (card is CardData):
			continue
		match card.effect_id:
			"SHIELD_1":
				shield += 1
			"SHIELD_2":
				shield += 2
			"SHIELD_4":
				shield += 4
			"SHIELD_6":
				shield += 6
			"SHIELD_TURN":
				shield += 99
	return shield

static func calc_combo_control(combo: Array) -> float:
	var control: float = 0.0
	for card in combo:
		if not (card is CardData):
			continue
		match card.effect_id:
			"SILENCE":
				control += 30.0
			"ATK_DISABLE":
				control += 20.0
			"SILENCE_ATTACK":
				control += 20.0
			"WEAKEN_ALL":
				control += 25.0
			"DISCARD_FA":
				control += 15.0
			"STEAL_CARD":
				control += 25.0
			"STEAL_SH":
				control += 15.0
			"BLOCK_NEXT_DRAW":
				control += 15.0
			"ABSORB_SHIELD":
				control += 15.0
			"REFLECT_ATK":
				control += 10.0
	return control

static func calc_combo_mana(combo: Array) -> int:
	var mana_gain: int = 0
	for card in combo:
		if not (card is CardData):
			continue
		match card.effect_id:
			"MANA_1":
				mana_gain += 1
			"MANA_2":
				mana_gain += 2
			"MANA_3":
				mana_gain += 3
			"MANA_4":
				mana_gain += 4
	return mana_gain

static func get_combo_main_card(combo: Array) -> CardData:
	for card in combo:
		if card is CardData and card.faction in ["法", "射", "坦"]:
			return card
	return null

static func get_combo_supp_card(combo: Array) -> CardData:
	for card in combo:
		if card is CardData and card.faction == "辅":
			return card
	return null

static func calc_combo_cost(combo: Array) -> int:
	var cost: int = 0
	for card in combo:
		if card is CardData:
			cost += card.cost
	return cost
