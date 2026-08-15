## 组合记忆库：基于卡牌特性的硬性记忆组合规则
## 当AI生成的组合匹配记忆规则时，额外加分
class_name AIComboMemory

## 组合记忆规则定义
## 每条规则: {
##   id: 规则ID,
##   match_fn: 匹配函数名,
##   bonus: 匹配成功时的额外加分,
##   desc: 规则描述
## }

const RULES := [
	{
		"id": "need_support_trigger",
		"bonus": 30.0,
		"desc": "需辅卡触发倍率的主卡 + 任意辅卡",
	},
	{
		"id": "high_atk_support",
		"bonus": 25.0,
		"desc": "高攻主卡(atk>=4) + 爆裂葡萄(atk5)",
	},
	{
		"id": "buff_main_high_atk",
		"bonus": 20.0,
		"desc": "增伤类主卡 + 高攻辅卡",
	},
	{
		"id": "cost_to_heal",
		"bonus": 22.0,
		"desc": "费用转化主卡 + 高费辅卡",
	},
	{
		"id": "mana_support_combo",
		"bonus": 15.0,
		"desc": "能量辅卡 + 爆发主卡（低费高攻）",
	},
	{
		"id": "control_support",
		"bonus": 18.0,
		"desc": "控制辅卡 + 爆发主卡",
	},
	{
		"id": "multiply_support",
		"bonus": 20.0,
		"desc": "保龄泡泡 + 任意辅卡（稳定倍率）",
	},
]

static func get_combination_bonus(combo: Array) -> float:
	var bonus: float = 0.0
	var main_card: CardData = null
	var supp_card: CardData = null

	for card in combo:
		if not (card is CardData):
			continue
		if card.faction == "辅":
			supp_card = card
		elif card.faction in ["法", "射", "坦"]:
			main_card = card

	if main_card == null:
		return 0.0

	# 规则1: 需辅触发倍率的主卡 + 辅卡
	if supp_card != null:
		if main_card.effect_id == "SUPPORT_DMG_MULTIPLIER":
			bonus += 30.0
			if supp_card.atk >= 3:
				bonus += 10.0

	# 规则2: 保龄泡泡 + 辅卡
	if supp_card != null:
		if main_card.effect_id == "MULTIPLY_DMG_BY_OPPONENT_COUNT":
			bonus += 20.0
			if supp_card.atk >= 3:
				bonus += 5.0

	# 规则3: 高攻主卡(atk>=4) + 爆裂葡萄(atk5)
	if supp_card != null:
		if main_card.atk >= 4 and supp_card.id == 8:
			bonus += 25.0
		elif main_card.atk >= 4 and supp_card.atk >= 3:
			bonus += 12.0

	# 规则4: 增伤类主卡 + 高攻辅卡
	if supp_card != null:
		if main_card.effect_id in ["DMG_BUFF_ADD_3", "BOOST_ATK_HEAL", "DMG_BUFF_ADD_2"]:
			if supp_card.atk >= 3:
				bonus += 20.0
			elif supp_card.atk >= 1:
				bonus += 10.0

	# 规则5: 费用转化主卡 + 高费辅卡
	if supp_card != null:
		if main_card.effect_id == "COST_TO_HEAL":
			if supp_card.cost >= 3:
				bonus += 22.0
			elif supp_card.cost >= 1:
				bonus += 10.0

	# 规则6: 能量辅卡 + 爆发主卡（低费高攻）
	if supp_card != null:
		if supp_card.effect_id in ["MANA_1", "MANA_2", "MANA_3", "MANA_4"]:
			if main_card.cost <= 2 and main_card.atk >= 3:
				bonus += 15.0
				if main_card.atk >= 5:
					bonus += 10.0

	# 规则7: 控制辅卡 + 爆发主卡
	if supp_card != null:
		if supp_card.effect_id in ["ATK_DISABLE", "SILENCE_ATTACK", "WEAKEN_ALL"]:
			if main_card.atk >= 3:
				bonus += 18.0

	# 规则8: 增伤类主卡 + 低费辅卡（能量效率）
	if supp_card != null:
		if main_card.effect_id in ["DMG_BUFF_ADD_3", "BOOST_ATK_HEAL"]:
			if supp_card.cost <= 1:
				bonus += 8.0

	# 规则9: 莲小蓬 + 保龄泡泡组合（射手联动）
	if main_card.effect_id == "SUPPORT_DMG_MULTIPLIER" and supp_card.effect_id == "MULTIPLY_DMG_BY_OPPONENT_COUNT":
		bonus += 25.0

	# 规则10: 坦克主卡 + 爆裂葡萄辅助
	if supp_card != null:
		if main_card.faction == "坦" and main_card.atk >= 4 and supp_card.id == 8:
			bonus += 15.0

	return bonus

static func get_combo_description(combo: Array) -> String:
	var main_card: CardData = null
	var supp_card: CardData = null

	for card in combo:
		if not (card is CardData):
			continue
		if card.faction == "辅":
			supp_card = card
		elif card.faction in ["法", "射", "坦"]:
			main_card = card

	if main_card == null:
		return "单卡"

	if supp_card == null:
		return main_card.name

	if main_card.effect_id == "SUPPORT_DMG_MULTIPLIER":
		return main_card.name + "(x3)+" + supp_card.name

	if main_card.effect_id == "MULTIPLY_DMG_BY_OPPONENT_COUNT":
		return main_card.name + "(xN)+" + supp_card.name

	if supp_card.id == 8 and main_card.atk >= 4:
		return main_card.name + "+爆裂葡萄"

	return main_card.name + "+" + supp_card.name
