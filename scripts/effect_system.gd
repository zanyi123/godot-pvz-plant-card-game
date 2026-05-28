## ═══════════════════════════════════════════════════════════════════
## 效果系统完整重构 — 对齐原 Python 三级架构 + 六阶段结算引擎
## ═══════════════════════════════════════════════════════════════════
##
## 对应原 Python 文件：
##   core/effect_registry.py   → 一级：18个效果大类（已内联为 PHASE_* 常量）
##   core/skill_registry.py    → 二级：SKILL_REGISTRY（effect_id → 类别+参数）
##   core/effect_executor.py   → 三级：28个 handler 执行函数
##   core/resolution_engine.py → 六阶段结算引擎（resolve_clash 主入口）
##   core/effects.py           → Buff 辅助（add_buff / consume_shield / tick_buffs）
##
## 结算顺序（优先级从低到高）：
##   阶段1: 基础效果1 — 护盾 & 生命恢复
##   阶段2: 基础效果2 — 精力增益 & 减伤 & 破甲 & 连携
##   阶段3: 阵营克制 — 决定反阵营机制（克制增伤/攻击清零）
##   阶段4: 基础效果3 — 增伤（辅助增伤 / 固定增伤）
##   阶段5: 特殊技能1 — 卡牌交互（弃牌/偷牌/转化/弱化/吸收/增生/困窘）
##   阶段6: 特殊技能2 — 控制 & 防御（抵挡/沉默/反弹）
##
## 克制关系：法→射→坦→法，辅助无克制
## 溢出伤害：A克制B + A_atk > B_atk → 溢出 = A_base - B_atk
##
extends Node

class_name EffectSystem

# --------------------------------------------------------------─
# §1  阵营克制关系
# --------------------------------------------------------------─

const FACTION_COUNTER: Dictionary = {
	"法": "射",   # 法师克制射手
	"射": "坦",   # 射手克制坦克
	"坦": "法",   # 坦克克制法师
	"辅": "",     # 辅助无克制
}

# --------------------------------------------------------------─
# §2  六阶段 effect_id 分组（对齐 Python resolution_engine）
# --------------------------------------------------------------─

const PHASE_1_EFFECTS: Dictionary = {
	# 护盾 & 生命恢复
	"SHIELD_1": true, "SHIELD_2": true, "SHIELD_4": true, "SHIELD_6": true,
	"HEAL_1": true, "HEAL_2": true, "HEAL_3": true, "HEAL_4": true,
	"HEAL_8": true,
}

const PHASE_2_EFFECTS: Dictionary = {
	# 精力 & 减伤 & 破甲 & 连携
	"MANA_1": true, "MANA_2": true, "MANA_3": true, "MANA_4": true,
	"REDUCE_DMG_2": true, "DMG_REDUCE_2": true,
	"ARMOR_PIERCE": true, "ARMOR_PEN": true,
	"BOOST_ATK_HEAL": true, "DMG_BUFF_ADD_3": true,
	"WEAKEN_ALL": true,
}

const PHASE_3_EFFECTS: Dictionary = {
	# 阵营克制
	"COUNTER_ATK_ZERO": true,
	"COUNTER_DMG_X3": true,
	"DMG_BUFF_2X": true,
	"NO_COUNTER_DMG_X2": true,
	"DMG_BUFF_2X_COUNTER": true,
}

const PHASE_4_EFFECTS: Dictionary = {
	# 增伤
	"SUPPORT_DMG_MULTIPLIER": true,
}

const PHASE_5_EFFECTS: Dictionary = {
	# 卡牌交互
	"DISCARD_FA": true,
	"STEAL_CARD": true, "STEAL_SH": true,
	"COST_TO_HEAL": true, "COST_TO_HEAL_SELF": true,
	"ATK_TO_HEAL": true,
	"ABSORB_SHIELD": true,
	"BLOCK_NEXT_DRAW": true,
	"MULTIPLY_DMG_BY_OPPONENT_COUNT": true,
}

const PHASE_6_EFFECTS: Dictionary = {
	# 控制 & 防御（最高优先级）
	"SHIELD_TURN": true,
	"ATK_DISABLE": true, "SILENCE_ATTACK": true,
	"SILENCE": true,
	"REFLECT_ATK": true,
}

# --------------------------------------------------------------─
# §3  二级：技能注册表  effect_id → {handler_key, value, …}
# --------------------------------------------------------------─

const SKILL_REGISTRY: Dictionary = {
	# -- 阶段1: 护盾 & 恢复 ------------------------------------
	"SHIELD_1":      {"handler_key": "add_shield",          "value": 1, "desc": "护盾+1"},
	"SHIELD_2":      {"handler_key": "add_shield",          "value": 2, "desc": "护盾+2"},
	"SHIELD_4":      {"handler_key": "add_shield",          "value": 4, "desc": "护盾+4"},
	"SHIELD_6":      {"handler_key": "add_shield",          "value": 6, "desc": "护盾+6"},
	"HEAL_1":        {"handler_key": "heal_flat",           "value": 1, "desc": "恢复1点生命"},
	"HEAL_2":        {"handler_key": "heal_flat",           "value": 2, "desc": "恢复2点生命"},
	"HEAL_3":        {"handler_key": "heal_flat",           "value": 3, "desc": "恢复3点生命"},
	"HEAL_4":        {"handler_key": "heal_flat",           "value": 4, "desc": "恢复4点生命"},
	"HEAL_8":        {"handler_key": "heal_to_value",       "value": 8, "desc": "血量恢复至8点"},
	# -- 阶段2: 精力 & 减伤 & 破甲 & 连携 --------------------─
	"MANA_1":        {"handler_key": "gain_mana",           "value": 1, "desc": "精力上限+1"},
	"MANA_2":        {"handler_key": "gain_mana",           "value": 2, "desc": "精力上限+2"},
	"MANA_3":        {"handler_key": "gain_mana",           "value": 3, "desc": "精力上限+3"},
	"MANA_4":        {"handler_key": "gain_mana",           "value": 4, "desc": "精力上限+4"},
	"REDUCE_DMG_2":  {"handler_key": "reduce_dmg_flat",     "value": 2, "desc": "减伤2点"},
	"DMG_REDUCE_2":  {"handler_key": "reduce_dmg_flat",     "value": 2, "desc": "减伤2点"},
	"ARMOR_PIERCE":  {"handler_key": "armor_pierce",        "value": 1, "desc": "破甲：无视护盾"},
	"ARMOR_PEN":     {"handler_key": "armor_pierce",        "value": 1, "desc": "破甲：无视护盾"},
	"BOOST_ATK_HEAL":{"handler_key": "boost_atk_and_heal",  "value": 2, "value2": 2, "desc": "增伤2+回血2"},
	"DMG_BUFF_ADD_3":{"handler_key": "dmg_buff_add_flat",   "value": 3, "desc": "增伤+3"},
	# -- 阶段3: 阵营克制 --------------------------------------─
	"COUNTER_ATK_ZERO":       {"handler_key": "counter_atk_zero",       "value": 0, "desc": "克制阵营攻击清0"},
	"COUNTER_DMG_X3":         {"handler_key": "counter_dmg_multiplier", "value": 3, "desc": "对克制阵营伤害×3"},
	"DMG_BUFF_2X":            {"handler_key": "dmg_buff_2x",            "value": 2, "desc": "无法被克制时伤害×2"},
	"NO_COUNTER_DMG_X2":      {"handler_key": "dmg_buff_2x",            "value": 2, "desc": "无法被克制时伤害×2"},
	"DMG_BUFF_2X_COUNTER":    {"handler_key": "dmg_buff_2x_counter",    "value": 2, "desc": "对克制阵营伤害×2"},
	# -- 阶段4: 增伤 ------------------------------------------─
	"SUPPORT_DMG_MULTIPLIER": {"handler_key": "support_dmg_multiplier", "value": 3, "desc": "有辅助时伤害×3"},
	# -- 阶段5: 卡牌交互 --------------------------------------─
	"DISCARD_FA":     {"handler_key": "discard_by_faction",   "value": 1, "faction_filter": "法", "desc": "弃对手法师阵营牌"},
	"STEAL_CARD":     {"handler_key": "steal_random_card",    "value": 1, "desc": "偷对手一张牌"},
	"STEAL_SH":       {"handler_key": "steal_by_faction",     "value": 1, "faction_filter": "射", "desc": "偷对手射手阵营牌"},
	"COST_TO_HEAL":   {"handler_key": "cost_to_heal_combo",   "value": 0, "desc": "同出牌费用转回血"},
	"COST_TO_HEAL_SELF":{"handler_key": "cost_to_heal_self",  "value": 0, "desc": "自身费用转回血"},
	"ATK_TO_HEAL":    {"handler_key": "atk_to_heal_opponent", "value": 0, "desc": "对方攻击转回血"},
	"WEAKEN_ALL":     {"handler_key": "weaken_all_opponent",  "value": 1, "desc": "弱化对手攻击至1"},
	"ABSORB_SHIELD":  {"handler_key": "absorb_shield",        "value": 0, "desc": "吸收对手护盾"},
	"BLOCK_NEXT_DRAW":{"handler_key": "block_next_draw",      "value": 1, "desc": "对手下回合无法补牌"},
	"MULTIPLY_DMG_BY_OPPONENT_COUNT": {"handler_key": "multiply_dmg_by_count", "value": 0, "desc": "伤害×对手出牌数"},
	# -- 阶段6: 控制 & 防御 ----------------------------------─
	"SHIELD_TURN":    {"handler_key": "block_one_turn",       "value": 1, "desc": "抵挡一回合攻击"},
	"ATK_DISABLE":    {"handler_key": "disable_atk",          "value": 1, "desc": "使对方攻击失效"},
	"SILENCE_ATTACK": {"handler_key": "disable_atk",          "value": 1, "desc": "使对方攻击失效"},
	"SILENCE":        {"handler_key": "silence_opponent",     "value": 1, "desc": "沉默对手"},
	"REFLECT_ATK":    {"handler_key": "reflect_attack",       "value": 1, "desc": "反弹对方攻击"},
}

## 向日葵系列兜底：effect_id为空但 card.id 在此映射表中时，走 gain_mana
const SUNFLOWER_MANA_MAP: Dictionary = {
	1: 1,   # 向日葵
	27: 1,  # 阳光菇（注：cards.json里阳光菇 effect_id="MANA_3"，但保留兜底）
	42: 1,  # 向日葵歌手
}

# --------------------------------------------------------------─
# §4  Buff 辅助函数（静态方法，可被外部直接调用）
# --------------------------------------------------------------─

static func _get_temp(state: Dictionary) -> Dictionary:
	if not state.has("temp"):
		state["temp"] = {}
	return state["temp"]

static func add_buff(player_state: Dictionary, buff_type: String, value: int, duration: int, icon_code: String) -> void:
	if not player_state.has("buffs"):
		player_state["buffs"] = []
	player_state["buffs"].append({
		"type": buff_type,
		"value": value,
		"duration": duration,
		"icon_code": icon_code,
	})

static func sum_buff_value(player_state: Dictionary, buff_type: String) -> int:
	if not player_state.has("buffs"):
		return 0
	var total: int = 0
	for b in player_state["buffs"]:
		if b.get("type", "") == buff_type:
			total += int(b.get("value", 0))
	return total

static func consume_shield(player_state: Dictionary, damage: int) -> Array:
	## 返回 [absorbed, remaining_damage]
	if not player_state.has("buffs"):
		return [0, damage]
	var absorbed: int = 0
	var remaining: int = damage
	for buff in player_state["buffs"]:
		if buff.get("type", "") != "shield" or remaining <= 0:
			continue
		var shield_val: int = int(buff.get("value", 0))
		var take: int = min(remaining, shield_val)
		buff["value"] = shield_val - take
		absorbed += take
		remaining -= take
	player_state["buffs"] = player_state["buffs"].filter(
		func(b): return not (b.get("type","") == "shield" and int(b.get("value",0)) <= 0)
	)
	return [absorbed, remaining]

static func tick_buffs(player_state: Dictionary) -> void:
	if not player_state.has("buffs"):
		return
	var surviving: Array = []
	for buff in player_state["buffs"]:
		var duration: int = int(buff.get("duration", 0))
		if duration == -1 or duration <= 0:
			surviving.append(buff)
			continue
		var new_dur: int = duration - 1
		if new_dur > 0:
			buff["duration"] = new_dur
			surviving.append(buff)
	player_state["buffs"] = surviving

# --------------------------------------------------------------─
# §5  内部辅助
# --------------------------------------------------------------─

func _opp(player_key: String) -> String:
	return "P2" if player_key == "P1" else "P1"

func _ps(state: Dictionary, player_key: String) -> Dictionary:
	return state["players"][player_key]

func _log(logs: Array, player: String, action: String, value: int, reason: String) -> void:
	logs.append({"player": player, "action": action, "value": value, "reason": reason})

func _get_main_faction(state: Dictionary, player_key: String) -> String:
	var played: Array = state.get("played_cards", {}).get(player_key, [])
	for c in played:
		if c is CardData and c.type == "主":
			return c.faction
	return ""

func _get_main_card(cards: Array) -> CardData:
	for c in cards:
		if c is CardData and c.type == "主":
			return c
	return null

# --------------------------------------------------------------─
# §6  三级：技能执行器 — 派发入口
# --------------------------------------------------------------─

## 执行单张卡牌的所有技能（支持逗号分隔的 effect_id）
## 返回 logs
func execute_skill(state: Dictionary, player_key: String, card: CardData) -> Array:
	var logs: Array = []
	var effect_id: String = card.effect_id

	# effect_id 为空 → 向日葵兜底
	if effect_id == "":
		var mana_val: int = SUNFLOWER_MANA_MAP.get(card.id, 0)
		if mana_val > 0:
			_exec_gain_mana(state, player_key, card, {"value": mana_val}, logs)
		return logs

	# 支持多个 effect_id（逗号分隔）
	var effect_ids: PackedStringArray = effect_id.split(",")
	for eid in effect_ids:
		eid = eid.strip_edges()
		if eid == "":
			continue
		var skill_data: Dictionary = SKILL_REGISTRY.get(eid, {})
		if skill_data.is_empty():
			continue
		var handler_key: String = str(skill_data.get("handler_key", ""))
		_dispatch(handler_key, state, player_key, card, skill_data, logs)

	return logs

## 按阶段过滤执行：仅执行属于指定阶段的 effect_id
func execute_skill_in_phase(state: Dictionary, player_key: String, card: CardData, phase: int) -> Array:
	var logs: Array = []
	var effect_id: String = card.effect_id

	if effect_id == "":
		var mana_val: int = SUNFLOWER_MANA_MAP.get(card.id, 0)
		if mana_val > 0 and phase == 2:
			_exec_gain_mana(state, player_key, card, {"value": mana_val}, logs)
		return logs

	var phase_map: Dictionary = _get_phase_map(phase)
	var effect_ids: PackedStringArray = effect_id.split(",")
	for eid in effect_ids:
		eid = eid.strip_edges()
		if eid == "":
			continue
		if not phase_map.has(eid):
			continue
		var skill_data: Dictionary = SKILL_REGISTRY.get(eid, {})
		if skill_data.is_empty():
			continue
		var handler_key: String = str(skill_data.get("handler_key", ""))
		_dispatch(handler_key, state, player_key, card, skill_data, logs)

	return logs

func _get_phase_map(phase: int) -> Dictionary:
	match phase:
		1: return PHASE_1_EFFECTS
		2: return PHASE_2_EFFECTS
		3: return PHASE_3_EFFECTS
		4: return PHASE_4_EFFECTS
		5: return PHASE_5_EFFECTS
		6: return PHASE_6_EFFECTS
		_: return {}

# --------------------------------------------------------------─
# §7  handler 派发表
# --------------------------------------------------------------─

func _dispatch(handler_key: String, state: Dictionary, pk: String, card: CardData, sd: Dictionary, logs: Array) -> void:
	match handler_key:
		# 阶段1: 护盾 & 恢复
		"add_shield":                _exec_add_shield(state, pk, card, sd, logs)
		"heal_flat":                 _exec_heal_flat(state, pk, card, sd, logs)
		"heal_to_value":             _exec_heal_to_value(state, pk, card, sd, logs)
		# 阶段2: 精力 & 减伤 & 破甲 & 连携
		"gain_mana":                 _exec_gain_mana(state, pk, card, sd, logs)
		"reduce_dmg_flat":           _exec_reduce_dmg(state, pk, card, sd, logs)
		"armor_pierce":              _exec_armor_pierce(state, pk, card, sd, logs)
		"boost_atk_and_heal":        _exec_boost_atk_heal(state, pk, card, sd, logs)
		"dmg_buff_add_flat":         _exec_dmg_buff_add(state, pk, card, sd, logs)
		# 阶段3: 阵营克制
		"counter_atk_zero":          _exec_counter_atk_zero(state, pk, card, sd, logs)
		"counter_dmg_multiplier":    _exec_counter_dmg_x3(state, pk, card, sd, logs)
		"dmg_buff_2x":               _exec_dmg_buff_2x(state, pk, card, sd, logs)
		"dmg_buff_2x_counter":       _exec_dmg_buff_2x_counter(state, pk, card, sd, logs)
		# 阶段4: 增伤
		"support_dmg_multiplier":    _exec_support_dmg_mult(state, pk, card, sd, logs)
		# 阶段5: 卡牌交互
		"discard_by_faction":        _exec_discard_by_faction(state, pk, card, sd, logs)
		"steal_random_card":         _exec_steal_random(state, pk, card, sd, logs)
		"steal_by_faction":          _exec_steal_by_faction(state, pk, card, sd, logs)
		"cost_to_heal_combo":        _exec_cost_to_heal(state, pk, card, sd, logs)
		"cost_to_heal_self":         _exec_cost_to_heal_self(state, pk, card, sd, logs)
		"atk_to_heal_opponent":      _exec_atk_to_heal(state, pk, card, sd, logs)
		"weaken_all_opponent":       _exec_weaken_all(state, pk, card, sd, logs)
		"absorb_shield":             _exec_absorb_shield(state, pk, card, sd, logs)
		"block_next_draw":           _exec_block_next_draw(state, pk, card, sd, logs)
		"multiply_dmg_by_count":     _exec_multiply_dmg(state, pk, card, sd, logs)
		# 阶段6: 控制 & 防御
		"block_one_turn":            _exec_block_one_turn(state, pk, card, sd, logs)
		"disable_atk":               _exec_disable_atk(state, pk, card, sd, logs)
		"silence_opponent":          _exec_silence(state, pk, card, sd, logs)
		"reflect_attack":            _exec_reflect(state, pk, card, sd, logs)

# --------------------------------------------------------------─
# §8  阶段1 handler：护盾 & 恢复
# --------------------------------------------------------------─

func _exec_add_shield(state: Dictionary, pk: String, card: CardData, sd: Dictionary, logs: Array) -> void:
	var val: int = int(sd.get("value", 0))
	if val <= 0:
		return
	add_buff(_ps(state, pk), "shield", val, -1, "shield")
	_log(logs, pk, "gain_shield", val, card.name)

func _exec_heal_flat(state: Dictionary, pk: String, card: CardData, sd: Dictionary, logs: Array) -> void:
	var val: int = int(sd.get("value", 0))
	if val <= 0:
		return
	var ps: Dictionary = _ps(state, pk)
	var hp: int = int(ps.get("hp", 10))
	var max_hp: int = int(ps.get("max_hp", 10))
	var new_hp: int = mini(max_hp, hp + val)
	var actual: int = new_hp - hp
	ps["hp"] = new_hp
	_log(logs, pk, "heal", actual, card.name)

func _exec_heal_to_value(state: Dictionary, pk: String, card: CardData, sd: Dictionary, logs: Array) -> void:
	var target: int = int(sd.get("value", 8))
	var ps: Dictionary = _ps(state, pk)
	var hp: int = int(ps.get("hp", 10))
	var max_hp: int = int(ps.get("max_hp", 10))
	var new_hp: int = mini(max_hp, maxi(hp, target))
	ps["hp"] = new_hp
	_log(logs, pk, "heal_to", new_hp - hp, card.name)

# --------------------------------------------------------------─
# §9  阶段2 handler：精力 & 减伤 & 破甲 & 连携
# --------------------------------------------------------------─

func _exec_gain_mana(state: Dictionary, pk: String, card: CardData, sd: Dictionary, logs: Array) -> void:
	var gain: int = int(sd.get("value", 0))
	if gain <= 0:
		return
	var ps: Dictionary = _ps(state, pk)
	var old_max: int = int(ps.get("max_mana", 5))
	var new_max: int = mini(old_max + gain, 10)
	var actual: int = new_max - old_max
	ps["max_mana"] = new_max
	var old_cur: int = int(ps.get("current_mana", 0))
	ps["current_mana"] = mini(old_cur + gain, new_max)
	add_buff(ps, "mana_boost", actual, -1, "mana")
	_log(logs, pk, "mana_up", actual, card.name)

func _exec_reduce_dmg(state: Dictionary, pk: String, card: CardData, sd: Dictionary, logs: Array) -> void:
	var val: int = int(sd.get("value", 2))
	var temp: Dictionary = _get_temp(state)
	var cur: int = int(temp.get(pk + "_flat_dmg_reduce", 0))
	temp[pk + "_flat_dmg_reduce"] = cur + val
	add_buff(_ps(state, pk), "dmg_reduce", val, 1, "dmg_reduce")
	_log(logs, pk, "flat_dmg_reduce", val, card.name)

func _exec_armor_pierce(state: Dictionary, pk: String, _card: CardData, _sd: Dictionary, logs: Array) -> void:
	var temp: Dictionary = _get_temp(state)
	temp[pk + "_armor_pierce"] = true
	add_buff(_ps(state, pk), "armor_pen", 1, 1, "armor_pen")
	_log(logs, pk, "armor_pierce", 1, "破甲")

func _exec_boost_atk_heal(state: Dictionary, pk: String, card: CardData, sd: Dictionary, logs: Array) -> void:
	var atk_boost: int = int(sd.get("value", 2))
	var heal_val: int = int(sd.get("value2", 2))
	# 增伤标记
	var temp: Dictionary = _get_temp(state)
	var cur: int = int(temp.get(pk + "_atk_boost", 0))
	temp[pk + "_atk_boost"] = cur + atk_boost
	add_buff(_ps(state, pk), "dmg_buff", atk_boost, 1, "dmg_buff")
	_log(logs, pk, "atk_boost", atk_boost, card.name)
	# 即时回血
	if heal_val > 0:
		var ps: Dictionary = _ps(state, pk)
		var hp: int = int(ps.get("hp", 10))
		var max_hp: int = int(ps.get("max_hp", 10))
		var new_hp: int = mini(max_hp, hp + heal_val)
		ps["hp"] = new_hp
		_log(logs, pk, "heal", new_hp - hp, card.name)

func _exec_dmg_buff_add(state: Dictionary, pk: String, card: CardData, sd: Dictionary, logs: Array) -> void:
	var val: int = int(sd.get("value", 0))
	if val <= 0:
		return
	var temp: Dictionary = _get_temp(state)
	var cur: int = int(temp.get(pk + "_atk_boost", 0))
	temp[pk + "_atk_boost"] = cur + val
	add_buff(_ps(state, pk), "dmg_buff", val, 1, "dmg_buff")
	_log(logs, pk, "dmg_buff_add", val, card.name)

# --------------------------------------------------------------─
# §10 阶段3 handler：阵营克制
# --------------------------------------------------------------─

func _exec_counter_atk_zero(state: Dictionary, pk: String, card: CardData, _sd: Dictionary, logs: Array) -> void:
	## 飞镖洋蓟(ID:32) 射手 → 被法师攻击时，法师攻击清0
	if card.id != 32:
		return
	var opp: String = _opp(pk)
	var opp_faction: String = _get_main_faction(state, opp)
	if opp_faction == "法":
		var temp: Dictionary = _get_temp(state)
		temp[opp + "_main_atk_zero"] = true
		_log(logs, opp, "counter_atk_zero", 1, "法师攻击清0")

func _exec_counter_dmg_x3(state: Dictionary, pk: String, card: CardData, sd: Dictionary, logs: Array) -> void:
	## 西瓜投手(ID:33) 射手 → 攻击坦克时伤害×3
	if card.id != 33:
		return
	var mult: int = int(sd.get("value", 3))
	var opp: String = _opp(pk)
	var opp_faction: String = _get_main_faction(state, opp)
	if opp_faction == "坦":
		var temp: Dictionary = _get_temp(state)
		var cur: float = float(temp.get(pk + "_dmg_multiplier", 1.0))
		temp[pk + "_dmg_multiplier"] = cur * mult
		temp[pk + "_countering"] = true
		_log(logs, pk, "counter_dmg_x3", mult, "克制坦克×3")

func _exec_dmg_buff_2x(state: Dictionary, pk: String, card: CardData, sd: Dictionary, logs: Array) -> void:
	## 毁灭菇(ID:34) 法师 → 对方不是坦克时伤害×2
	if card.id != 34:
		return
	var opp: String = _opp(pk)
	var opp_faction: String = _get_main_faction(state, opp)
	if opp_faction != "坦":
		var mult: int = int(sd.get("value", 2))
		var temp: Dictionary = _get_temp(state)
		var cur: float = float(temp.get(pk + "_dmg_multiplier", 1.0))
		temp[pk + "_dmg_multiplier"] = cur * mult
		_log(logs, pk, "dmg_buff_2x", mult, "非坦克伤害×2")

func _exec_dmg_buff_2x_counter(state: Dictionary, pk: String, card: CardData, sd: Dictionary, logs: Array) -> void:
	## 橡木弓手(ID:68) 射手 → 克制坦克阵营伤害×2
	if card.faction != "射":
		return
	var opp: String = _opp(pk)
	var opp_faction: String = _get_main_faction(state, opp)
	if opp_faction == "坦":
		var mult: int = int(sd.get("value", 2))
		var temp: Dictionary = _get_temp(state)
		var cur: float = float(temp.get(pk + "_dmg_multiplier", 1.0))
		temp[pk + "_dmg_multiplier"] = cur * mult
		temp[pk + "_countering"] = true
		_log(logs, pk, "dmg_buff_2x_counter", mult, "克制坦克×2")

# --------------------------------------------------------------─
# §11 阶段4 handler：增伤
# --------------------------------------------------------------─

func _exec_support_dmg_mult(state: Dictionary, pk: String, card: CardData, sd: Dictionary, logs: Array) -> void:
	## 莲小蓬(ID:30)：同出有辅助卡时伤害×3
	var mult: int = int(sd.get("value", 3))
	var played: Array = state.get("played_cards", {}).get(pk, [])
	var has_support: bool = false
	for c in played:
		if c is CardData and c.type == "辅":
			has_support = true
			break
	if has_support:
		var temp: Dictionary = _get_temp(state)
		var cur: float = float(temp.get(pk + "_dmg_multiplier", 1.0))
		temp[pk + "_dmg_multiplier"] = cur * mult
		_log(logs, pk, "support_dmg_mult", mult, card.name)

# --------------------------------------------------------------─
# §12 阶段5 handler：卡牌交互
# --------------------------------------------------------------─

func _exec_discard_by_faction(state: Dictionary, pk: String, _card: CardData, sd: Dictionary, logs: Array) -> void:
	var opp: String = _opp(pk)
	var faction: String = str(sd.get("faction_filter", ""))
	var opp_hand: Array = state["hands"].get(opp, [])
	var candidates: Array = []
	for i in range(opp_hand.size()):
		if opp_hand[i] is CardData and opp_hand[i].faction == faction:
			candidates.append(i)
	if candidates.size() > 0:
		var idx: int = candidates[randi() % candidates.size()]
		var removed: CardData = opp_hand.pop_at(idx)
		_log(logs, opp, "card_discarded", 1, removed.name)

func _exec_steal_random(state: Dictionary, pk: String, _card: CardData, _sd: Dictionary, logs: Array) -> void:
	var opp: String = _opp(pk)
	var opp_hand: Array = state["hands"].get(opp, [])
	if opp_hand.size() > 0:
		var idx: int = randi() % opp_hand.size()
		var stolen: CardData = opp_hand.pop_at(idx)
		if not state["hands"].has(pk):
			state["hands"][pk] = []
		state["hands"][pk].append(stolen)
		_log(logs, pk, "steal_card", 1, stolen.name)

func _exec_steal_by_faction(state: Dictionary, pk: String, _card: CardData, sd: Dictionary, logs: Array) -> void:
	var opp: String = _opp(pk)
	var faction: String = str(sd.get("faction_filter", ""))
	var opp_hand: Array = state["hands"].get(opp, [])
	var candidates: Array = []
	for i in range(opp_hand.size()):
		if opp_hand[i] is CardData and opp_hand[i].faction == faction:
			candidates.append(i)
	if candidates.size() > 0:
		var idx: int = candidates[randi() % candidates.size()]
		var stolen: CardData = opp_hand.pop_at(idx)
		if not state["hands"].has(pk):
			state["hands"][pk] = []
		state["hands"][pk].append(stolen)
		_log(logs, pk, "steal_card", 1, stolen.name)

func _exec_cost_to_heal(state: Dictionary, pk: String, card: CardData, _sd: Dictionary, logs: Array) -> void:
	## 同出牌费用转回血（排除本卡）
	var played: Array = state.get("played_cards", {}).get(pk, [])
	var total_cost: int = 0
	for c in played:
		if c is CardData and c.id != card.id:
			total_cost += c.cost
	if total_cost > 0:
		var ps: Dictionary = _ps(state, pk)
		var hp: int = int(ps.get("hp", 10))
		var max_hp: int = int(ps.get("max_hp", 10))
		ps["hp"] = mini(max_hp, hp + total_cost)
		_log(logs, pk, "cost_to_heal", mini(max_hp - hp, total_cost), card.name)

func _exec_cost_to_heal_self(state: Dictionary, pk: String, card: CardData, _sd: Dictionary, logs: Array) -> void:
	var cost: int = card.cost
	if cost > 0:
		var ps: Dictionary = _ps(state, pk)
		var hp: int = int(ps.get("hp", 10))
		var max_hp: int = int(ps.get("max_hp", 10))
		var new_hp: int = mini(max_hp, hp + cost)
		ps["hp"] = new_hp
		_log(logs, pk, "cost_to_heal_self", new_hp - hp, card.name)

func _exec_atk_to_heal(state: Dictionary, pk: String, _card: CardData, _sd: Dictionary, logs: Array) -> void:
	## 对方出牌攻击值转回血
	var opp: String = _opp(pk)
	var opp_played: Array = state.get("played_cards", {}).get(opp, [])
	var total_atk: int = 0
	for c in opp_played:
		if c is CardData:
			total_atk += c.atk
	if total_atk > 0:
		var ps: Dictionary = _ps(state, pk)
		var hp: int = int(ps.get("hp", 10))
		var max_hp: int = int(ps.get("max_hp", 10))
		var new_hp: int = mini(max_hp, hp + total_atk)
		ps["hp"] = new_hp
		_log(logs, pk, "atk_to_heal", new_hp - hp, "对方攻击转回血")

func _exec_weaken_all(state: Dictionary, pk: String, card: CardData, _sd: Dictionary, logs: Array) -> void:
	var opp: String = _opp(pk)
	var temp: Dictionary = _get_temp(state)
	temp[opp + "_weakened"] = true
	_log(logs, pk, "weaken_all", 1, card.name)

func _exec_absorb_shield(state: Dictionary, pk: String, card: CardData, _sd: Dictionary, logs: Array) -> void:
	var opp: String = _opp(pk)
	var opp_ps: Dictionary = _ps(state, opp)
	var total: int = sum_buff_value(opp_ps, "shield")
	if total > 0:
		opp_ps["buffs"] = opp_ps["buffs"].filter(func(b): return b.get("type","") != "shield")
		_log(logs, pk, "absorb_shield", total, card.name)

func _exec_block_next_draw(state: Dictionary, pk: String, card: CardData, _sd: Dictionary, logs: Array) -> void:
	var opp: String = _opp(pk)
	if not state.has("control_effects"):
		state["control_effects"] = {}
	state["control_effects"][opp + "_block_next_draw"] = true
	_log(logs, pk, "block_next_draw", 1, card.name)

func _exec_multiply_dmg(state: Dictionary, pk: String, card: CardData, _sd: Dictionary, logs: Array) -> void:
	var opp: String = _opp(pk)
	var opp_count: int = state.get("played_cards", {}).get(opp, []).size()
	if opp_count > 0:
		var temp: Dictionary = _get_temp(state)
		var cur: float = float(temp.get(pk + "_dmg_multiplier", 1.0))
		temp[pk + "_dmg_multiplier"] = cur * opp_count
		_log(logs, pk, "multiply_dmg", opp_count, card.name)

# --------------------------------------------------------------─
# §13 阶段6 handler：控制 & 防御
# --------------------------------------------------------------─

func _exec_block_one_turn(state: Dictionary, pk: String, _card: CardData, _sd: Dictionary, logs: Array) -> void:
	add_buff(_ps(state, pk), "block_turn", 1, 1, "block")
	_log(logs, pk, "gain_block", 1, "抵挡一回合")

func _exec_disable_atk(state: Dictionary, pk: String, _card: CardData, _sd: Dictionary, logs: Array) -> void:
	var opp: String = _opp(pk)
	var temp: Dictionary = _get_temp(state)
	temp[opp + "_atk_disabled"] = true
	add_buff(_ps(state, opp), "silence_attack", 1, 1, "silence_attack")
	_log(logs, opp, "atk_disabled", 1, "攻击失效")

func _exec_silence(state: Dictionary, pk: String, _card: CardData, _sd: Dictionary, logs: Array) -> void:
	var opp: String = _opp(pk)
	var temp: Dictionary = _get_temp(state)
	temp[opp + "_silenced"] = true
	add_buff(_ps(state, opp), "silence_attack", 1, 1, "silence_attack")
	_log(logs, opp, "silenced", 1, "被沉默")

func _exec_reflect(state: Dictionary, pk: String, _card: CardData, _sd: Dictionary, logs: Array) -> void:
	var temp: Dictionary = _get_temp(state)
	temp[pk + "_reflect_atk"] = true
	_log(logs, pk, "reflect", 1, "反弹攻击")

# --------------------------------------------------------------─
# §14 六阶段结算引擎 — 主入口 resolve_clash
# --------------------------------------------------------------─
##
## 调用方式（game_board.gd 的 _resolve 方法中）：
##   var logs = effect_system.resolve_clash(game_state, p1_played, p2_played)
##
## 结算流程：
##   1. 存入 played_cards
##   2. P1 + P2 依次走阶段1~6
##   3. 最终伤害计算（克制溢出 + 护盾 + 减伤 + 反弹 + block_turn）
##   4. 扣血
##   5. buff tick + 清理 temp
##

func resolve_clash(state: Dictionary, p1_cards: Array, p2_cards: Array) -> Array:
	var logs: Array = []

	# 存入出牌
	state["played_cards"] = {"P1": p1_cards.duplicate(), "P2": p2_cards.duplicate()}

	# -- 双方依次执行 阶段1~6 ----------------------------------
	# 注意：即时效果已在 commit_effects() 中触发（SILENCE/STEAL/DISCARD/REFLECT/SHIELD_TURN/BLOCK_NEXT_DRAW 等）
	# 此处只执行结算阶段效果（护盾/治疗/精力/减伤/破甲/连携/克制/增伤/弱化/吸收/增生等）
	for pk in ["P1", "P2"]:
		var cards: Array = p1_cards if pk == "P1" else p2_cards
		for phase_num in range(1, 7):
			for card in cards:
				if card is CardData:
					# 跳过已在 commit 时触发的即时效果
					var eid: String = card.effect_id
					if eid != "" and IMMEDIATE_EFFECT_IDS.has(eid):
						continue
					var phase_logs: Array = execute_skill_in_phase(state, pk, card, phase_num)
					logs.append_array(phase_logs)

	# -- 最终伤害结算 ------------------------------------------
	var p1_main: CardData = _get_main_card(p1_cards)
	var p2_main: CardData = _get_main_card(p2_cards)
	var temp: Dictionary = _get_temp(state)

	# 计算双方原始伤害
	var p2_damage: int = _calc_raw_damage(state, "P1", p1_main, p2_main, temp)
	var p1_damage: int = _calc_raw_damage(state, "P2", p2_main, p1_main, temp)

	# -- 防御处理（减伤 → 护盾/破甲 → block_turn）------------─
	p1_damage = _apply_defense(state, "P1", p1_damage, temp.get("P2_armor_pierce", false), logs)
	p2_damage = _apply_defense(state, "P2", p2_damage, temp.get("P1_armor_pierce", false), logs)

	# -- 反弹处理 ----------------------------------------------
	if temp.get("P1_reflect_atk", false) and p1_damage > 0:
		p2_damage += p1_damage
		_log(logs, "P1", "reflect_triggered", p1_damage, "反弹")
		p1_damage = 0
	if temp.get("P2_reflect_atk", false) and p2_damage > 0:
		p1_damage += p2_damage
		_log(logs, "P2", "reflect_triggered", p2_damage, "反弹")
		p2_damage = 0

	# -- 扣血 --------------------------------------------------
	_do_damage(state, "P1", p1_damage, logs)
	_do_damage(state, "P2", p2_damage, logs)

	# -- 回合结束：buff 递减 + temp 清理 ----------------------
	for pk in ["P1", "P2"]:
		tick_buffs(_ps(state, pk))
	state["temp"] = {}

	return logs

# --------------------------------------------------------------─
# §15 伤害计算：阵营克制 + 溢出伤害 + 弱化
# --------------------------------------------------------------─
##
## 克制关系：法→射→坦→法（辅助无克制）
## 克制规则（对齐 Python _resolve_main_damage）：
##   A克制B + A_base > B_raw → B受溢出伤害(A_base - B_raw), A受0
##   A克制B + A_base ≤ B_raw → 双方0（被克制方无法造成伤害）
##   无克制 → 全额互伤

func _calc_raw_damage(state: Dictionary, attacker: String, my_main: CardData, opp_main: CardData, temp: Dictionary) -> int:
	## 攻击方 = attacker 对对手造成的伤害
	if my_main == null:
		return 0

	# 攻击禁用检查
	if temp.get(attacker + "_atk_disabled", false) or temp.get(attacker + "_main_atk_zero", false):
		return 0

	# 基础攻击力
	var atk: int = my_main.atk + int(temp.get(attacker + "_atk_boost", 0))

	# 弱化
	if temp.get(attacker + "_weakened", false):
		atk = mini(atk, 1)
	atk = maxi(0, atk)

	# 乘算
	var mult: float = float(temp.get(attacker + "_dmg_multiplier", 1.0))
	var base_dmg: int = int(atk * mult)

	# 阵营判定
	var my_faction: String = my_main.faction
	var opp_faction: String = opp_main.faction if opp_main else ""
	var i_counter_opp: bool = FACTION_COUNTER.get(my_faction, "") == opp_faction
	var opp_counters_me: bool = FACTION_COUNTER.get(opp_faction, "") == my_faction

	if i_counter_opp:
		# 我克制对手：溢出伤害 = base_dmg - 对手原始atk
		var opp_raw_atk: int = opp_main.atk if opp_main else 0
		if temp.get(_opp(attacker) + "_weakened", false):
			opp_raw_atk = mini(opp_raw_atk, 1)
		return maxi(0, base_dmg - opp_raw_atk)
	elif opp_counters_me:
		# 对手克制我：我攻击清零
		return 0
	else:
		# 无克制：全额
		return base_dmg

# --------------------------------------------------------------─
# §16 防御处理：减伤 → 护盾/破甲 → block_turn
# --------------------------------------------------------------─

func _apply_defense(state: Dictionary, defender: String, damage: int, has_armor_pierce: bool, logs: Array) -> int:
	if damage <= 0:
		return 0

	var ps: Dictionary = _ps(state, defender)

	# ① 减伤 buff（固定值减少，对齐 Python flat_dmg_reduce × 对手出牌数）
	# 注：flat_dmg_reduce 在 _calc_raw_damage 之后这里不做二次处理，
	# 减伤已在 temp 中由 reduce_dmg_flat handler 设置
	# 此处仅处理 dmg_reduce 类 buff（百分比减伤）
	var dmg_reduce: int = sum_buff_value(ps, "dmg_reduce")
	if dmg_reduce > 0:
		damage = int(damage * maxf(0.0, 1.0 - dmg_reduce / 100.0))

	# ② 护盾吸收（破甲跳过）
	if not has_armor_pierce:
		var result: Array = consume_shield(ps, damage)
		var absorbed: int = result[0]
		damage = result[1]
		if absorbed > 0:
			_log(logs, defender, "shield_absorb", absorbed, "护盾吸收")
	elif damage > 0:
		_log(logs, defender, "armor_pierce_bypass", damage, "破甲穿透护盾")

	# ③ block_turn 完全免疫
	var buffs: Array = ps.get("buffs", [])
	var has_block: bool = false
	for b in buffs:
		if b.get("type", "") == "block_turn":
			has_block = true
			break
	if has_block:
		ps["buffs"] = ps["buffs"].filter(func(b): return b.get("type","") != "block_turn")
		_log(logs, defender, "block_turn_triggered", damage, "抵挡全部伤害")
		return 0

	return damage

# --------------------------------------------------------------─
# §17 扣血
# --------------------------------------------------------------─

func _do_damage(state: Dictionary, defender: String, damage: int, logs: Array) -> void:
	if damage <= 0:
		return
	var ps: Dictionary = _ps(state, defender)
	var hp: int = int(ps.get("hp", 10))
	var new_hp: int = hp - damage
	ps["hp"] = new_hp
	_log(logs, defender, "take_damage", damage, "受到伤害")
	_log(logs, defender, "set_hp", new_hp, "扣血后")

# --------------------------------------------------------------─
# §18 即时效果触发（出牌确认时触发，对齐 Python commit_pending_play）
# --------------------------------------------------------------
##
## Python 架构中，以下效果在 commit_pending_play() 时触发（出牌确认时），
## 而不是在 resolve_clash() 时触发：
##   - SILENCE / ATK_DISABLE / SILENCE_ATTACK: 需要在对手出牌前生效
##   - STEAL_CARD / STEAL_SH / DISCARD_FA: 卡牌交互，影响对手手牌
##   - REFLECT_ATK: 需要在伤害结算前设置标记
##   - SHIELD_TURN / BLOCK_ONE_TURN: 需要在伤害结算前设置
##
## 克制类效果（COUNTER_*）延迟到 resolve_clash() 阶段3执行。
##

const IMMEDIATE_EFFECT_IDS: Dictionary = {
	# 控制 & 防御（需要出牌时立即生效）
	"SILENCE": true,
	"ATK_DISABLE": true,
	"SILENCE_ATTACK": true,
	"SHIELD_TURN": true,
	"REFLECT_ATK": true,
	# 卡牌交互（影响对手手牌）
	"STEAL_CARD": true,
	"STEAL_SH": true,
	"DISCARD_FA": true,
	"BLOCK_NEXT_DRAW": true,
}

## 在 commit_pending 时触发的即时效果（对齐 Python commit_pending_play）
## 返回 logs
func commit_effects(state: Dictionary, player_key: String, cards: Array) -> Array:
	var logs: Array = []
	for card in cards:
		if not card is CardData:
			continue
		var eid: String = card.effect_id
		if eid == "":
			# 向日葵党底（精力卡在出牌时立即生效）
			var mana_val: int = SUNFLOWER_MANA_MAP.get(card.id, 0)
			if mana_val > 0:
				_exec_gain_mana(state, player_key, card, {"value": mana_val}, logs)
			continue
		# 只执行需要在出牌确认时立即生效的效果
		# 其余效果（护盾/治疗/减伤/增伤/克制/弱化/吸收等）由 resolve_clash 按阶段执行
		if not IMMEDIATE_EFFECT_IDS.has(eid):
			continue
		var skill_data: Dictionary = SKILL_REGISTRY.get(eid, {})
		if skill_data.is_empty():
			continue
		var handler_key: String = str(skill_data.get("handler_key", ""))
		_dispatch(handler_key, state, player_key, card, skill_data, logs)
	return logs

# --------------------------------------------------------------─
# §19 向后兼容入口（game_board.gd 旧调用方式）
# --------------------------------------------------------------─

func resolve_damage(state: Dictionary, p1_cards: Array, p2_cards: Array) -> Array:
	return resolve_clash(state, p1_cards, p2_cards)
