# 大师难度AI设计方案（最终版）

## 一、核心原则

### 1.1 信息对称性原则

#### AI可见信息（与真人玩家相同）
- ✅ 自己的手牌（完整信息）
- ✅ 自己的血量、护盾、精力值
- ✅ 对方已公开的卡牌（已出牌、已触发效果）
- ✅ 对方血量、护盾状态
- ✅ 对方精力值
- ✅ 回合数
- ✅ 自己的历史出牌记录

#### AI不可见信息（与真人玩家相同）
- ❌ 对方手牌内容
- ❌ 对方抽牌的顺序
- ❌ 对方下回合可能出什么牌

### 1.2 三回合预测基准

**预测依据**：自己的健康状态 + 手牌结构 + 精力变化趋势

**不预测**：对方具体手牌内容（因为不可见）

### 1.3 卡牌限制符规则

- `limit_flag = true` 的卡：**只能单独出**，不能与其他卡组合
- `limit_flag = false` 的卡：可单独出或与合法卡牌组合
- 出牌时必须检查所有候选卡的 `limit_flag`

---

## 二、游戏真实限制规则（必须严格遵守）

### 2.1 出牌规则（来自 game_board.gd）

```
规则1: 每回合最多出2张牌
规则2: limit_flag=true 的卡 → 只能单独出，不能与任何卡组合
规则3: 组合必须是 主(法/射/坦) + 辅 形式
规则4: 不能双主(法/射/坦 + 法/射/坦)
规则5: 不能双辅(辅 + 辅)
规则6: 组合总cost ≤ 当前精力值
```

### 2.2 组合合法性伪代码

```gdscript
func can_combo(card_a: CardData, card_b: CardData) -> bool:
    # 规则1: 任何一张是限制卡，都不能组合
    if card_a.limit_flag or card_b.limit_flag:
        return false
    
    # 规则2: 必须是 主 + 辅
    var main_factions = {"法": true, "射": true, "坦": true}
    var a_is_main = main_factions.has(card_a.faction)
    var b_is_main = main_factions.has(card_b.faction)
    var a_is_supp = card_a.faction == "辅"
    var b_is_supp = card_b.faction == "辅"
    
    if a_is_main and b_is_supp:
        return true  # 主 + 辅 ✓
    if b_is_main and a_is_supp:
        return true  # 辅 + 主 ✓
    
    return false  # 双主/双辅/其他
```

---

## 三、卡牌分类（基于 limit_flag）

### 3.1 限制卡（limit_flag=true）→ 只能单独出

#### 限制主卡（法/射/坦阵营）
| ID | 名称 | cost | atk | effect_id | 说明 |
|----|------|------|-----|-----------|------|
| 7 | 原始猕猴桃 | 3 | 3 | SHIELD_TURN | 抵挡一回合 |
| 11 | 幽暮投手 | 3 | 3 | ARMOR_PIERCE | 破甲射手 |
| 14 | 炙热山葵 | 4 | 3 | DISCARD_FA | 弃对方法师牌 |
| 19 | 冰龙草 | 4 | 4 | SILENCE | 沉默对方 |
| 24 | 火龙草 | 3 | 3 | ARMOR_PIERCE | 破甲法师 |
| 32 | 飞镖洋蓟 | 4 | 5 | COUNTER_ATK_ZERO | 克法师清0 |
| 33 | 西瓜投手 | 5 | 4 | COUNTER_DMG_X3 | 克坦克×3 |
| 34 | 毁灭菇 | 6 | 5 | NO_COUNTER_DMG_X2 | 无法被克制×2 |
| 36 | 旋转菠萝 | 5 | 1 | HEAL_4 | 回血+4 |
| 46 | 暗樱草 | 4 | 1 | STEAL_SH | 偷射手牌 |
| 48 | 全息坚果 | 4 | 2 | SHIELD_2 | 护盾+2 |
| 49 | 南瓜巫师 | 3 | 1 | COST_TO_HEAL_SELF | 自身费用转回血 |
| 51 | 热辣海藻 | 5 | 2 | SHIELD_TURN | 抵挡一回合 |
| 53 | 水晶兰 | 4 | 2 | ATK_TO_HEAL | 对方攻击转回血 |
| 58 | 高坚果t | 3 | 1 | SHIELD_4 | 护盾+4 |
| 59 | 钢地刺t | 5 | 2 | WEAKEN_ALL | 弱化对方至1 |
| 65 | 火葫芦fa | 2 | 3 | ARMOR_PEN | 破甲法师 |
| 68 | 橡木弓手s | 2 | 2 | DMG_BUFF_2X_COUNTER | 克坦克×2 |
| 69 | 缠绕水草fu | 3 | 1 | BLOCK_NEXT_DRAW | 对方下回合无法补牌 |
| 73 | 甜菜护卫t | 3 | 3 | HEAL_2 | 回血+2 |

#### 限制辅卡（辅阵营）
| ID | 名称 | cost | atk | effect_id | 说明 |
|----|------|------|-----|-----------|------|
| 15 | 巴豆 | 3 | 0 | SHIELD_6 | 护盾+6 |
| 16 | 仙桃 | 4 | 0 | HEAL_8 | 回血至8 |
| 38 | 香水蘑菇 | 2 | 0 | STEAL_CARD | 偷对方一张牌 |
| 40 | 魅惑菇 | 2 | 1 | REFLECT_ATK | 反弹对方攻击 |
| 42 | 向日葵歌手 | 2 | 0 | MANA_4 | 精力上限+4 |
| 56 | 冰冻生菜fu | 2 | 0 | SILENCE_ATTACK | 使对方攻击失效 |
| 57 | 樱桃炸弹fu | 2 | 3 | - | 高爆发伤害 |

### 3.2 可组合卡（limit_flag=false）→ 可单独出或组合

#### 可组合主卡（法/射/坦阵营）
| ID | 名称 | cost | atk | effect_id | 可搭配的辅卡类型 |
|----|------|------|-----|-----------|------------------|
| 2 | 豌豆射手 | 1 | 1 | - | 任意辅卡 |
| 3 | 坚果墙 | 2 | 1 | SHIELD_1 | 任意辅卡 |
| 4 | 火爆辣椒 | 2 | 3 | - | 任意辅卡 |
| 5 | 梅小美 | 1 | 1 | - | 任意辅卡 |
| 6 | 玉米投手 | 2 | 2 | - | 任意辅卡 |
| 9 | 寒冰射手 | 2 | 2 | REDUCE_DMG_2 | 任意辅卡 |
| 12 | 原始坚果墙 | 5 | 6 | - | 任意辅卡(高cost需注意) |
| 13 | 窝瓜 | 3 | 4 | - | 任意辅卡 |
| 18 | 白萝卜 | 4 | 2 | HEAL_2 | 任意辅卡 |
| 20 | 魔术菇 | 3 | 3 | - | 任意辅卡 |
| 21 | 梛子加农炮 | 2 | 5 | - | 任意辅卡 |
| 23 | 火龙果 | 2 | 2 | - | 任意辅卡 |
| 25 | 闪电芦苇 | 1 | 1 | - | 任意辅卡 |
| 28 | 仙人掌 | 2 | 3 | - | 任意辅卡 |
| 29 | 红针花 | 2 | 2 | - | 任意辅卡 |
| 30 | 莲小蓬 | 3 | 1 | SUPPORT_DMG_MULTIPLIER | 需要辅卡触发×3 |
| 31 | 小喷菇 | 0 | 1 | - | 任意辅卡 |
| 35 | 毒影菇 | 1 | 3 | - | 任意辅卡 |
| 37 | 榴莲 | 2 | 1 | - | 任意辅卡 |
| 44 | 熊果臼炮 | 3 | 2 | REDUCE_DMG_2 | 任意辅卡 |
| 45 | 胆小荆棘 | 2 | 1 | - | 任意辅卡 |
| 47 | 南瓜头 | 3 | 3 | - | 任意辅卡 |
| 50 | 强酸柠檬 | 2 | 3 | - | 任意辅卡 |
| 52 | 岩浆番石榴 | 5 | 4 | - | 任意辅卡(高cost需注意) |
| 54 | 双重射手 | 1 | 2 | - | 任意辅卡 |
| 60 | 激光豆s | 2 | 2 | - | 任意辅卡 |
| 61 | 棱镜草s | 2 | 3 | HEAL_1 | 任意辅卡 |
| 62 | 充能柚子fa | 4 | 4 | - | 任意辅卡 |
| 67 | 花生射手s | 3 | 1 | HEAL_2 | 任意辅卡 |
| 70 | 鳄梨t | 3 | 2 | - | 任意辅卡 |
| 71 | 保龄泡泡s | 2 | 2 | MULTIPLY_DMG_BY_OPPONENT_COUNT | 任意辅卡 |
| 72 | 辣椒投手s | 1 | 2 | - | 任意辅卡 |
| 75 | 飓风甘蓝fa | 3 | 1 | DMG_REDUCE_2 | 任意辅卡 |

#### 可组合辅卡（辅阵营）
| ID | 名称 | cost | atk | effect_id | 可搭配的主卡类型 |
|----|------|------|-----|-----------|------------------|
| 1 | 向日葵 | 1 | 0 | MANA_1 | 任意主卡 |
| 8 | 爆裂葡萄 | 0 | 5 | - | 任意主卡 |
| 10 | 阳光蓓蕾 | 2 | 0 | MANA_3 | 任意主卡 |
| 17 | 棉小雪 | 2 | 1 | ATK_DISABLE | 任意主卡 |
| 22 | 竹笋 | 1 | 1 | - | 任意主卡 |
| 26 | 龙舌兰 | 2 | 3 | - | 任意主卡 |
| 27 | 阳光菇 | 2 | 0 | MANA_3 | 任意主卡 |
| 39 | 粉丝心叶兰 | 4 | 0 | COST_TO_HEAL | 任意主卡(高cost需注意) |
| 41 | 能量花 | 3 | 0 | BOOST_ATK_HEAL | 任意主卡 |
| 43 | 三叶草 | 2 | 1 | HEAL_3 | 任意主卡 |
| 55 | 菜问fu | 3 | 3 | - | 任意主卡 |
| 63 | 星星果fu | 1 | 1 | - | 任意主卡 |
| 64 | 瓷砖萝卜fu | 2 | 0 | DMG_BUFF_ADD_3 | 任意主卡 |
| 74 | 眩晕洋葱fu | 1 | 1 | - | 任意主卡 |
| 76 | 金蟾菇fu | 2 | 1 | MANA_2 | 任意主卡 |

---

## 四、技能效果真实分类

### 4.1 技能触发阶段表

| 阶段 | effect_id | handler_key | 真实效果 | 触发条件 |
|------|-----------|-------------|----------|----------|
| **即时** | SILENCE | silence_opponent | 对方本回合无法出牌 | 出牌时立即触发 |
| **即时** | ATK_DISABLE | disable_atk | 对方攻击失效 | 出牌时立即触发 |
| **即时** | SILENCE_ATTACK | disable_atk | 对方攻击失效 | 出牌时立即触发 |
| **即时** | SHIELD_TURN | block_one_turn | 抵挡一回合攻击 | 出牌时立即触发 |
| **即时** | REFLECT_ATK | reflect_attack | 反弹对方攻击 | 出牌时立即触发 |
| **即时** | STEAL_CARD | steal_random_card | 偷对方一张牌 | 出牌时立即触发 |
| **即时** | STEAL_SH | steal_by_faction | 偷对方射手牌 | 出牌时立即触发 |
| **即时** | DISCARD_FA | discard_by_faction | 弃对方法师牌 | 出牌时立即触发 |
| **即时** | BLOCK_NEXT_DRAW | block_next_draw | 对方下回合无法补牌 | 出牌时立即触发 |
| **阶段1** | SHIELD_1/2/4/6 | add_shield | 添加护盾值 | 结算阶段触发 |
| **阶段1** | HEAL_1/2/3/4 | heal_flat | 固定回血 | 结算阶段触发 |
| **阶段1** | HEAL_8 | heal_to_value | 回血至指定值 | 结算阶段触发 |
| **阶段2** | MANA_1/2/3/4 | gain_mana | 精力上限+N | 结算阶段触发 |
| **阶段2** | REDUCE_DMG_2 | reduce_dmg_flat | 减伤2点 | 结算阶段触发 |
| **阶段2** | ARMOR_PIERCE | armor_pierce | 破甲无视护盾 | 结算阶段触发 |
| **阶段2** | BOOST_ATK_HEAL | boost_atk_and_heal | 增伤2+回血2 | 结算阶段触发 |
| **阶段2** | DMG_BUFF_ADD_3 | dmg_buff_add_flat | 增伤+3 | 结算阶段触发 |
| **阶段3** | COUNTER_ATK_ZERO | counter_atk_zero | 克制阵营攻击清0 | 对方主卡是克制阵营时 |
| **阶段3** | COUNTER_DMG_X3 | counter_dmg_multiplier | 克制阵营伤害×3 | 对方主卡是克制阵营时 |
| **阶段3** | NO_COUNTER_DMG_X2 | dmg_buff_2x | 无法被克制时伤害×2 | 对方主卡不克制自己时 |
| **阶段3** | DMG_BUFF_2X_COUNTER | dmg_buff_2x_counter | 克制阵营伤害×2 | 对方主卡是克制阵营时 |
| **阶段4** | SUPPORT_DMG_MULTIPLIER | support_dmg_multiplier | 有辅助时伤害×3 | 同出有辅助卡时 |
| **阶段5** | COST_TO_HEAL | cost_to_heal_combo | 同出牌费用转回血 | 与其他卡组合时 |
| **阶段5** | ATK_TO_HEAL | atk_to_heal_opponent | 对方攻击转回血 | 对方出牌后 |
| **阶段5** | WEAKEN_ALL | weaken_all_opponent | 弱化对方攻击至1 | 结算阶段触发 |
| **阶段5** | ABSORB_SHIELD | absorb_shield | 吸收对方护盾 | 结算阶段触发 |
| **阶段5** | MULTIPLY_DMG_BY_OPPONENT_COUNT | multiply_dmg_by_count | 伤害×对方出牌数 | 对方出多张牌时 |

### 4.2 阵营克制关系

```
法(法师) → 射(射手) → 坦(坦克) → 法(法师)
```

- 辅助(辅)阵营不参与克制
- 克制判定基于主卡(type="主")的阵营

---

## 五、合法组合生成算法

### 5.1 组合生成函数

```gdscript
func generate_valid_combos(hand: Array, mana: int) -> Array:
    """
    生成所有合法的出牌组合
    严格遵守 limit_flag 和阵营组合规则
    """
    var combos = []
    
    # 分类手牌
    var limit_cards = []      # limit_flag=true 的卡
    var combo_mains = []      # 可组合的主卡(法/射/坦, limit_flag=false)
    var combo_supps = []       # 可组合的辅卡(辅, limit_flag=false)
    
    for card in hand:
        if card.limit_flag:
            limit_cards.append(card)
        elif card.faction in ["法", "射", "坦"]:
            combo_mains.append(card)
        elif card.faction == "辅":
            combo_supps.append(card)
    
    # 1. 单卡组合（所有卡都可以单独出，只要cost足够）
    for card in hand:
        if card.cost <= mana:
            combos.append([card])
    
    # 2. 双卡组合：主卡 + 辅卡（必须都是 limit_flag=false）
    for main in combo_mains:
        for supp in combo_supps:
            if main.cost + supp.cost <= mana:
                combos.append([main, supp])
    
    return combos
```

### 5.2 组合合法性检查表

| 组合类型 | 主卡limit | 辅卡limit | 合法性 | 说明 |
|----------|-----------|-----------|--------|------|
| 限制主卡 + 任何卡 | true | true/false | ❌ | 限制卡不能组合 |
| 限制辅卡 + 任何卡 | true/false | true | ❌ | 限制卡不能组合 |
| 可组合主卡 + 可组合辅卡 | false | false | ✅ | 唯一合法组合 |
| 可组合主卡 + 可组合主卡 | false | false | ❌ | 双主不合法 |
| 可组合辅卡 + 可组合辅卡 | false | false | ❌ | 双辅不合法 |

---

## 六、策略选择（基于合法组合）

### 6.1 卡牌价值评估

#### 评估维度
```
score(card) = 基础分 + 加成分

基础分:
  攻击类: atk * 10
  防御类: shield_value * 8
  治疗类: heal_value * 8
  控制类: 固定分 25
  能量类: mana_value * 5

加成分（基于自己的状态）:
  对方血量低(<=30%): 攻击类+20
  自己血量低(<=30%): 防御/治疗类+20
  精力不足(<2): 能量类+15
  回合后期(>5回合): 所有类+5
```

### 6.2 策略选择决策树

```
开始
│
├─ 生成所有合法组合
│   └─ 限制卡 → 只能单出
│   └─ 可组合卡 → 可单出或主+辅组合
│
├─ 评估每个组合的价值
│   ├─ 低血量(≤30%) → 治疗/防御组合加分
│   ├─ 有击杀机会 → 攻击组合加分
│   ├─ 回合≤3 → 能量组合加分
│   └─ 默认 → 平衡组合
│
└─ 选择得分最高的组合
```

### 6.3 策略1：低血量保命（血量≤30%）

#### 选择优先级
```
1. 限制治疗/防御卡（只能单独出）
   - 16仙桃(HEAL_8, cost4): 回血至8
   - 15巴豆(SHIELD_6, cost3): 护盾+6
   - 7原始猕猴桃(SHIELD_TURN, cost3): 抵挡一回合
   - 40魅惑菇(REFLECT_ATK, cost2): 反弹攻击
   - 48全息坚果(SHIELD_2, cost4): 护盾+2
   - 58高坚果t(SHIELD_4, cost3): 护盾+4

2. 可组合治疗/防御（主+辅）
   - 3坚果墙(SHIELD_1, cost2) + 43三叶草(HEAL_3, cost2): cost4, 盾1+回血3
   - 44熊果臼炮(减伤2, cost3) + 41能量花(增伤2+回血2, cost3): cost6
   - 61棱镜草s(HEAL_1, cost2) + 43三叶草(HEAL_3, cost2): cost4, 回血4
   - 67花生射手s(HEAL_2, cost3) + 43三叶草(HEAL_3, cost2): cost5, 回血5

3. 可组合治疗/防御（单独出）
   - 18白萝卜(HEAL_2, cost4): 回血2
```

#### 组合示例（合法）
| 组合 | 主卡 | 辅卡 | 总cost | 预期效果 | 合法性 |
|------|------|------|--------|----------|--------|
| ✅ | 3坚果墙(SHIELD_1) | 43三叶草(HEAL_3) | 4 | 盾1+回血3 | 合法(主+辅) |
| ✅ | 44熊果臼炮(REDUCE_DMG_2) | 41能量花(BOOST_ATK_HEAL) | 6 | 减伤2+增伤2+回血2 | 合法(主+辅) |
| ✅ | 61棱镜草s(HEAL_1) | 43三叶草(HEAL_3) | 4 | 回血1+3=4 | 合法(主+辅) |
| ✅ | 16仙桃(HEAL_8) | - | 4 | 回血至8 | 合法(限制卡单出) |
| ❌ | 37榴莲 | 16仙桃 | 6 | - | ❌ 仙桃是限制卡 |
| ❌ | 15巴豆 | 3坚果墙 | 5 | - | ❌ 巴豆是限制卡 |

### 6.4 策略2：爆发攻击（有击杀机会）

#### 选择优先级
```
1. 限制攻击卡（只能单独出）
   - 34毁灭菇(atk5, NO_COUNTER_DMG_X2, cost6): 无法被克制时×2
   - 32飞镖洋蓟(atk5, COUNTER_ATK_ZERO, cost4): 克制法师清0
   - 33西瓜投手(atk4, COUNTER_DMG_X3, cost5): 克坦克×3
   - 11幽暮投手(atk3, ARMOR_PIERCE, cost3): 破甲
   - 24火龙草(atk3, ARMOR_PIERCE, cost3): 破甲
   - 65火葫芦fa(atk3, ARMOR_PEN, cost2): 破甲
   - 68橡木弓手s(atk2, DMG_BUFF_2X_COUNTER, cost2): 克坦克×2

2. 可组合攻击（主+辅）
   - 4火爆辣椒(atk3, cost2) + 8爆裂葡萄(atk5, cost0): cost2, atk3+5=8
   - 21梛子加农炮(atk5, cost2) + 8爆裂葡萄(atk5, cost0): cost2, atk5+5=10
   - 12原始坚果墙(atk6, cost5) + 8爆裂葡萄(atk5, cost0): cost5, atk6+5=11
   - 13窝瓜(atk4, cost3) + 8爆裂葡萄(atk5, cost0): cost3, atk4+5=9
   - 30莲小蓬(atk1, SUPPORT_DMG_MULTIPLIER, cost3) + 8爆裂葡萄(atk5, cost0): cost3, 莲小蓬自身atk×3 + 辅卡atk = 1×3+5=8
   - 71保龄泡泡s(atk2, MULTIPLY_DMG_BY_OPPONENT_COUNT, cost2) + 8爆裂葡萄(atk5, cost0): cost2, 保龄泡泡自身atk×对方出牌数 + 辅卡atk
   - 任意可组合主卡 + 64瓷砖萝卜fu(DMG_BUFF_ADD_3, cost2): 增伤3
   - 任意可组合主卡 + 41能量花(BOOST_ATK_HEAL, cost3): 增伤2+回血2

3. 可组合攻击（单独出）
   - 21梛子加农炮(atk5, cost2): 低费高攻
   - 12原始坚果墙(atk6, cost5): 最高攻
   - 13窝瓜(atk4, cost3): 高攻坦克
```

#### 组合示例（合法）
| 组合 | 主卡 | 辅卡 | 总cost | 预期伤害 | 合法性 |
|------|------|------|--------|----------|--------|
| ✅ | 21梛子加农炮(atk5) | 8爆裂葡萄(atk5) | 2 | 10 | 合法(主+辅) |
| ✅ | 30莲小蓬(atk1,有辅×3) | 8爆裂葡萄(atk5) | 3 | 8=1×3+5 | 合法(主+辅，倍率仅作用于自身atk) |
| ✅ | 4火爆辣椒(atk3) | 64瓷砖萝卜fu(加攻3) | 4 | 6=3+3 | 合法(主+辅) |
| ✅ | 34毁灭菇(atk5,×2) | - | 6 | 10=5×2 | 合法(限制卡单出) |
| ✅ | 33西瓜投手(atk4,克坦克×3) | - | 5 | 12=4×3(对坦克) | 合法(限制卡单出) |
| ❌ | 34毁灭菇 | 8爆裂葡萄 | 6 | - | ❌ 毁灭菇是限制卡 |
| ❌ | 32飞镖洋蓟 | 64瓷砖萝卜fu | 7 | - | ❌ 飞镖是限制卡 |

### 6.5 策略3：控制打断

#### 选择优先级
```
1. 限制控制卡（只能单独出）
   - 19冰龙草(SILENCE, cost4): 沉默对方
   - 14炙热山葵(DISCARD_FA, cost4): 弃对方法师牌
   - 46暗樱草(STEAL_SH, cost4): 偷对方射手牌
   - 38香水蘑菇(STEAL_CARD, cost2): 偷对方一张牌
   - 59钢地刺t(WEAKEN_ALL, cost5): 弱化对方至1
   - 56冰冻生菜fu(SILENCE_ATTACK, cost2): 使对方攻击失效
   - 69缠绕水草fu(BLOCK_NEXT_DRAW, cost3): 对方下回合无法补牌

2. 可组合控制（主+辅）
   - 可组合主卡 + 17棉小雪(ATK_DISABLE, cost2):
     - 4火爆辣椒(atk3, cost2) + 17棉小雪(ATK_DISABLE, cost2): cost4, 高攻+禁攻
     - 21梛子加农炮(atk5, cost2) + 17棉小雪(ATK_DISABLE, cost2): cost4, 高攻+禁攻
   - 可组合主卡 + 64瓷砖萝卜fu(DMG_BUFF_ADD_3, cost2):
     - 控制+增伤组合
```

### 6.6 策略4：能量积累（回合≤3）

#### 选择优先级
```
1. 限制能量卡（只能单独出）
   - 42向日葵歌手(MANA_4, cost2): 精力上限+4

2. 可组合能量（主+辅）
   - 可组合主卡 + 1向日葵(MANA_1, cost1):
     - 4火爆辣椒(atk3, cost2) + 1向日葵(MANA_1, cost1): cost3, atk3+mana+1
   - 可组合主卡 + 10阳光蓓蕾(MANA_3, cost2):
     - 2豌豆射手(atk1, cost1) + 10阳光蓓蕾(MANA_3, cost2): cost3, atk1+mana+3
   - 可组合主卡 + 27阳光菇(MANA_3, cost2):
     - 2豌豆射手(atk1, cost1) + 27阳光菇(MANA_3, cost2): cost3, atk1+mana+3
   - 可组合主卡 + 76金蟾菇fu(MANA_2, cost2):
     - 4火爆辣椒(atk3, cost2) + 76金蟾菇fu(MANA_2, cost2): cost4, atk3+mana+2

3. 可组合能量（单独出）
   - 10阳光蓓蕾(MANA_3, cost2): 精力上限+3
   - 27阳光菇(MANA_3, cost2): 精力上限+3
   - 1向日葵(MANA_1, cost1): 精力上限+1
```

### 6.7 策略5：默认平衡

#### 选择优先级
```
1. 限制爆发卡（单独出）
   - 34毁灭菇(atk5, ×2, cost6): 无法被克制时×2
   - 33西瓜投手(atk4, 克坦克×3, cost5): 克坦克时×3
   - 11幽暮投手(atk3, 破甲, cost3): 破甲

2. 可组合爆发（主+辅）
   - 最高atk可组合主卡 + 8爆裂葡萄(atk5, cost0)
   - 最高atk可组合主卡 + 64瓷砖萝卜fu(加攻3, cost2)
   - 控制主卡 + 加攻辅卡

3. 可组合爆发（单独出）
   - 最高atk可组合主卡
```

---

## 七、三回合预测算法

### 7.1 预测流程

```gdscript
func predict_and_decide(hand: Array, mana: int, my_hp: int, 
                        opp_hp: int, round: int) -> Array:
    
    # 第一回合：当前回合决策
    var current = evaluate_current_round(hand, mana, my_hp, opp_hp, round)
    
    # 第二回合：预测下回合自己的可能状态
    var next_hand = simulate_next_hand(hand, current)
    var next_mana = simulate_next_mana(mana, current)
    var next_hp = simulate_next_hp(my_hp, current)
    var next = evaluate_current_round(next_hand, next_mana, next_hp, opp_hp, round + 1)
    
    # 第三回合：预测第三回合
    var third_hand = simulate_next_hand(next_hand, next)
    var third_mana = simulate_next_mana(next_mana, next)
    var third_hp = simulate_next_hp(next_hp, next)
    var third = evaluate_current_round(third_hand, third_mana, third_hp, opp_hp, round + 2)
    
    # 综合评估（越靠后权重越低）
    var total_score = current.score * 1.0 
                    + next.score * 0.6 
                    + third.score * 0.3
    
    # 选择得分最高的组合
    return current.best_combo
```

### 7.2 回合状态模拟函数

```gdscript
func simulate_next_hand(current_hand: Array, played_cards: Array) -> Array:
    """
    模拟下回合的手牌
    - 移除已出的卡
    - 假设抽1张新卡（随机从卡池）
    """
    var remaining = []
    for card in current_hand:
        if card not in played_cards:
            remaining.append(card)
    
    # 模拟抽牌（简化版，随机类型）
    var new_card = random_card_from_pool()
    remaining.append(new_card)
    
    return remaining

func simulate_next_mana(current_mana: int, played_cards: Array, round: int) -> int:
    """
    模拟下回合的精力值
    - 基础精力 = 3 + round/2（取整）
    - 减去出牌消耗
    - 加上MANA类卡牌的增益
    """
    var base_mana = 3 + int(round / 2)
    var mana_gain = 0
    for card in played_cards:
        if card.effect_id.begins_with("MANA_"):
            mana_gain += get_mana_value(card.effect_id)
    
    return base_mana + mana_gain

func simulate_next_hp(current_hp: int, played_cards: Array, opp_avg_damage: float) -> int:
    """
    模拟下回合的血量
    - 加上治疗效果
    - 减去可能受到的伤害（基于对方历史平均伤害）
    """
    var hp = current_hp
    for card in played_cards:
        if card.effect_id.begins_with("HEAL_"):
            hp += get_heal_value(card.effect_id)
        elif card.effect_id == "COST_TO_HEAL":
            hp += calc_cost_to_heal(card)
    
    # 减去预计受到的伤害（基于历史数据）
    hp -= opp_avg_damage
    
    return maxi(0, hp)
```

---

## 八、留牌策略

### 8.1 留牌决策函数

```gdscript
func should_keep_card(card, my_hp, hand, round) -> bool:
    """
    判断是否应该留牌（不出）
    """
    
    # 规则1: 限制卡不留（除非是关键牌）
    if card.limit_flag and not is_key_card(card, my_hp):
        return False
    
    # 规则2: 低血量时留防御/治疗牌
    if my_hp <= 30%:
        if card.effect_id in ["HEAL_8", "HEAL_4", "SHIELD_TURN", "SHIELD_6"]:
            # 检查是否能形成更好的组合
            if can_form_better_combo(card, hand):
                return True  # 留牌等待组合
    
    # 规则3: 即将进入后期时留强力卡
    if round >= 6:
        if card.atk >= 4 or card.effect_id in ["SILENCE", "SHIELD_TURN"]:
            if not is_needed_now(card, my_hp, round):
                return True  # 留到关键回合
    
    # 规则4: 有明确的组合等待时留牌
    if waiting_for_combo(card, hand):
        return True
    
    return False

func is_key_card(card, my_hp) -> bool:
    """判断是否为关键牌"""
    if card.effect_id == "HEAL_8" and my_hp < 30%:
        return True
    if card.effect_id == "SHIELD_TURN" and my_hp < 20%:
        return True
    if card.effect_id == "SILENCE":
        return True
    return False
```

---

## 九、AI决策伪代码

### 9.1 主决策函数

```gdscript
# ai_system.gd

enum AILevel { NORMAL, MASTER }

var ai_level: AILevel = AILevel.MASTER

func ai_play(hand: Array, mana: int, my_hp: int, opp_hp: int, 
             my_shield: int, opp_shield: int, round: int,
             opp_avg_damage: float) -> Array:
    
    if ai_level == AILevel.NORMAL:
        return _normal_play(hand, mana)
    else:
        return _master_play(hand, mana, my_hp, opp_hp, my_shield, round, opp_avg_damage)

func _normal_play(hand: Array, mana: int) -> Array:
    """普通AI：只出攻击力最大的一张"""
    var playable = []
    for card in hand:
        if card.cost <= mana:
            playable.append(card)
    
    if playable.is_empty():
        return []
    
    playable.sort_custom(func(a, b): return a.atk > b.atk)
    return [playable[0]]

func _master_play(hand: Array, mana: int, my_hp: int, opp_hp: int, 
                  my_shield: int, round: int, opp_avg_damage: float) -> Array:
    """大师AI：多维度决策"""
    
    # Step 1: 分类手牌
    var limit_cards = []
    var combo_mains = []  # limit_flag=false, 法/射/坦
    var combo_supps = []  # limit_flag=false, 辅
    
    for card in hand:
        if card.limit_flag:
            limit_cards.append(card)
        elif card.faction in ["法", "射", "坦"]:
            combo_mains.append(card)
        elif card.faction == "辅":
            combo_supps.append(card)
    
    # Step 2: 生成所有合法组合
    var combos = []
    
    # 单卡：所有cost足够的卡
    for card in hand:
        if card.cost <= mana:
            combos.append([card])
    
    # 双卡：只有 combo_mains + combo_supps 才能组合
    for main in combo_mains:
        for supp in combo_supps:
            if main.cost + supp.cost <= mana:
                combos.append([main, supp])
    
    if combos.is_empty():
        return []
    
    # Step 3: 评估每个组合
    var scored_combos = []
    for combo in combos:
        var score = evaluate_combo(combo, my_hp, opp_hp, round)
        scored_combos.append({"combo": combo, "score": score})
    
    # Step 4: 选择得分最高的
    scored_combos.sort_custom(func(a, b): return a.score > b.score)
    
    return scored_combos[0].combo
```

### 9.2 组合评估函数

```gdscript
func evaluate_combo(combo: Array, my_hp: int, opp_hp: int, round: int) -> float:
    var score = 0.0
    
    # 获取卡牌
    var main_card = null
    var supp_card = null
    for card in combo:
        if card.faction in ["法", "射", "坦"]:
            main_card = card
        elif card.faction == "辅":
            supp_card = card
    
    # 计算预期伤害、治疗、控制
    var damage = calc_damage(combo)
    var heal = calc_heal(combo)
    var control = calc_control(combo)
    
    # 基础分
    score += damage * 2.0      # 伤害价值
    score += heal * 1.5        # 治疗价值
    score += control * 1.2     # 控制价值
    
    # 策略调整
    if my_hp <= 30:
        # 低血量：大幅加分治疗/防御
        if heal > 0:
            score += 50
        if has_shield(combo):
            score += 40
        if has_reflect(combo):
            score += 35
    
    if damage >= opp_hp:
        # 可以击杀：大幅加分
        score += 100
    
    if round <= 3 and has_mana(combo):
        # 早期能量积累
        score += 20
    
    # 组合加分
    if combo.size() == 2:
        score += 15  # 主+辅组合额外加分
    
    # 限制卡单独出加分（因为不能组合，给基础分）
    if combo.size() == 1 and combo[0].limit_flag:
        score += 5
    
    return score

func calc_damage(combo: Array) -> int:
    var dmg = 0
    for card in combo:
        dmg += card.atk
    
    # 检查伤害增益
    for card in combo:
        match card.effect_id:
            "DMG_BUFF_ADD_3":
                dmg += 3
            "BOOST_ATK_HEAL":
                dmg += 2
            "SUPPORT_DMG_MULTIPLIER":
                if combo.size() == 2:  # 有辅助卡
                    dmg = dmg * 3 - card.atk
            "COUNTER_DMG_X3":
                pass  # 需要在运行时判断对方阵营
            "DMG_BUFF_2X_COUNTER":
                pass
            "NO_COUNTER_DMG_X2":
                pass
            "MULTIPLY_DMG_BY_OPPONENT_COUNT":
                pass
    
    return dmg

func calc_heal(combo: Array) -> int:
    var heal = 0
    for card in combo:
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
                heal += 8
            "BOOST_ATK_HEAL":
                heal += 2
            "COST_TO_HEAL":
                for other in combo:
                    if other != card:
                        heal += other.cost
            "COST_TO_HEAL_SELF":
                heal += card.cost
    
    return heal

func calc_control(combo: Array) -> float:
    var control = 0.0
    for card in combo:
        match card.effect_id:
            "SILENCE":
                control += 30
            "ATK_DISABLE":
                control += 20
            "SILENCE_ATTACK":
                control += 20
            "WEAKEN_ALL":
                control += 25
            "DISCARD_FA":
                control += 15
            "STEAL_CARD":
                control += 25
            "STEAL_SH":
                control += 15
            "BLOCK_NEXT_DRAW":
                control += 15
            "ABSORB_SHIELD":
                control += 15
    
    return control
```

---

## 十、真实对局场景示例

### 场景1：手牌混合（有各种限制）
```
手牌: [仙桃(limit,cost4), 火爆辣椒(cost2), 坚果墙(cost2), 爆裂葡萄(cost0), 冰龙草(limit,cost4)]
精力: 4

生成合法组合:
1. 单卡: 
   - 仙桃(4): 回血至8
   - 火爆辣椒(2): atk3
   - 坚果墙(2): atk1+SHIELD_1
   - 爆裂葡萄(0): atk5
   - 冰龙草(4): SILENCE
   
2. 双卡（只有可组合卡）:
   - 火爆辣椒 + 坚果墙 → ❌ 双主(法+坦)不合法
   - 火爆辣椒 + 爆裂葡萄 → ✅ 主+辅, cost2, atk8
   - 坚果墙 + 爆裂葡萄 → ✅ 主+辅, cost2, atk6+SHIELD_1
   - 仙桃 + 火爆辣椒 → ❌ 仙桃是限制卡
   - 冰龙草 + 爆裂葡萄 → ❌ 冰龙草是限制卡

最佳选择:
- 低血量(≤30%): 仙桃(4) → 回血至8
- 有击杀机会: 火爆辣椒+爆裂葡萄(2) → atk8
- 控制需求: 冰龙草(4) → SILENCE
- 默认: 坚果墙+爆裂葡萄(2) → atk6+SHIELD_1
```

### 场景2：全是限制卡
```
手牌: [毁灭菇(limit,cost6), 仙桃(limit,cost4), 冰龙草(limit,cost4)]
精力: 6

生成合法组合:
1. 单卡:
   - 毁灭菇(6): atk5×2=10
   - 仙桃(4): 回血至8
   - 冰龙草(4): SILENCE
   
2. 双卡: 
   - 无合法组合（所有卡都是limit_flag=true）

最佳选择:
- 有击杀机会: 毁灭菇(6) → atk10
- 低血量: 仙桃(4) → 回血至8
- 控制需求: 冰龙草(4) → SILENCE
```

### 场景3：全是可组合卡
```
手牌: [豌豆射手(cost1), 竹笋(cost1), 梅小美(cost1), 向日葵(cost1)]
精力: 2

生成合法组合:
1. 单卡:
   - 豌豆射手(1): atk1
   - 竹笋(1): atk1
   - 梅小美(1): atk1
   - 向日葵(1): MANA_1
   
2. 双卡（主+辅）:
   - 豌豆射手 + 竹笋 → ✅ 主+辅, cost2, atk2
   - 豌豆射手 + 向日葵 → ✅ 主+辅, cost2, atk1+mana+1
   - 梅小美 + 竹笋 → ✅ 主+辅, cost2, atk2
   - 梅小美 + 向日葵 → ✅ 主+辅, cost2, atk1+mana+1

注意: 豌豆射手+梅小美 → ❌ 双主(射+射)不合法
注意: 竹笋+向日葵 → ❌ 双辅(辅+辅)不合法

最佳选择:
- 平衡: 豌豆射手+竹笋(2) → atk2
- 能量: 豌豆射手+向日葵(2) → atk1+mana+1
```

---

## 十一、实现架构

### 11.1 代码结构
```
scripts/
├── ai_system.gd          # AI主入口（调度）
├── ai_card_analyzer.gd   # 卡牌分析器（价值评估）
├── ai_strategy.gd        # 策略生成器（组合策略）
├── ai_predictor.gd       # 回合预测器（三回合预测）
└── ai_history.gd         # 历史记录（记录对方行为模式）
```

### 11.2 难度配置
```gdscript
# NORMAL_AI_CONFIG
const NORMAL_CONFIG = {
    "combo_search": false,
    "predict_rounds": 0,
    "use_limit_flag": true,  # 即使普通AI也遵守限制符
    "random_factor": 0.2,
}

# MASTER_AI_CONFIG
const MASTER_CONFIG = {
    "combo_search": true,
    "predict_rounds": 3,
    "use_limit_flag": true,
    "use_hold_strategy": true,
    "hold_threshold": 0.6,
    "random_factor": 0.05,
}
```

### 11.3 实现计划

| 阶段 | 内容 | 预计时间 |
|------|------|----------|
| **Phase 1** | 基础框架 + 限制符实现 | 1天 |
| **Phase 2** | 卡牌分析器 | 1天 |
| **Phase 3** | 组合策略实现 | 1天 |
| **Phase 4** | 三回合预测 | 2天 |
| **Phase 5** | 留牌策略 + 历史记录 | 1天 |
| **Phase 6** | 集成测试 | 2天 |

---

## 十二、验证标准

### 12.1 信息对称性验证
- ✅ AI 不会基于对方手牌内容做决策
- ✅ AI 只使用已公开的信息（血量、精力、已出牌）
- ✅ AI 的决策逻辑与真人玩家视角一致

### 12.2 限制符验证
- ✅ `limit_flag=true` 的卡不会与其他卡组合
- ✅ `limit_flag=true` 的卡可以单独出
- ✅ 组合的 cost 总和不超过当前精力

### 12.3 三回合预测验证
- ✅ 预测基于自己的状态，而非对方手牌
- ✅ 预测结果考虑历史行为模式（对方平均伤害）
- ✅ 预测权重递减（当前 > 下一回合 > 第三回合）

### 12.4 组合合法性验证
- ✅ 不会出现双主组合
- ✅ 不会出现双辅组合
- ✅ 限制卡不会与任何卡组合
- ✅ 组合总cost不超过精力值

---

## 十三、预期效果

| 指标 | 普通AI | 大师AI |
|------|--------|--------|
| 信息对称性 | ✅ 遵守 | ✅ 遵守 |
| 限制符遵守 | ✅ 遵守 | ✅ 遵守 |
| 出牌策略 | 单卡贪心 | 1-2卡组合 |
| 回合规划 | ❌ | 三回合预测 |
| 胜率预期 | 30-40% | 50-65% |

---

## 十四、常见错误组合

| 错误组合 | 原因 |
|----------|------|
| 仙桃 + 坚果墙 | 仙桃是限制卡(limit_flag=true) |
| 冰龙草 + 爆裂葡萄 | 冰龙草是限制卡(limit_flag=true) |
| 豌豆射手 + 梅小美 | 双主(射+射)不合法 |
| 竹笋 + 向日葵 | 双辅(辅+辅)不合法 |
| 限制主卡 + 任何卡 | 限制卡不能组合 |
| 限制辅卡 + 任何卡 | 限制卡不能组合 |

---

## 十五、倍率机制修正说明（v3+v5合并后补充）

### 15.1 核心规则：倍率只作用于自身atk

**倍率类技能（×N / ×对方出牌数）仅作用于该卡牌自身的atk值，不影响其他卡牌的atk或全局buff。**

修正后的伤害计算公式：
```
最终伤害 = Σ(每张卡牌自身atk × 该卡独立倍率) + Σ(atk_boost类flat buff)
```

### 15.2 所有倍率类技能及其正确机制

| 技能ID | 卡牌 | 倍率描述 | 作用范围 | 错误理解（旧） | 正确机制（新） |
|--------|------|----------|----------|----------------|----------------|
| `COUNTER_DMG_X3` | 33西瓜投手(主,射,限制) | 对坦克阵营时×3 | 仅自身atk | 总伤害×3 | 西瓜投手自身atk×3 |
| `NO_COUNTER_DMG_X2` | 34毁灭菇(主,法,限制) | 对方非坦克时×2 | 仅自身atk | 总伤害×2 | 毁灭菇自身atk×2 |
| `DMG_BUFF_2X_COUNTER` | 68橡木弓手(主,射,限制) | 对坦克阵营时×2 | 仅自身atk | 总伤害×2 | 橡木弓手自身atk×2 |
| `SUPPORT_DMG_MULTIPLIER` | 30莲小蓬(主,射) | 有辅卡时×3 | 仅自身atk | (主+辅)×3 | 莲小蓬自身atk×3 + 辅卡原atk |
| `MULTIPLY_DMG_BY_OPPONENT_COUNT` | 71保龄泡泡(主,射) | ×对方本回合出牌数 | 仅自身atk | (主+辅)×N | 保龄泡泡自身atk×N + 辅卡原atk |

### 15.3 可能被误解的组合（已修正）

以下组合的伤害计算在旧文档/旧代码中存在错误，现已全部修正为"倍率仅作用于自身atk"：

| 组合 | 卡牌组成 | 旧错误伤害 | 正确伤害 | 修正说明 |
|------|----------|-----------|----------|----------|
| 莲小蓬+爆裂葡萄 | 30(atk1,×3)+8(atk5) | 18=(1+5)×3 | 8=1×3+5 | 倍率只乘莲小蓬自己的atk |
| 莲小蓬+瓷砖萝卜 | 30(atk1,×3)+64(加攻3) | 12=(1+0+3)×3 | 6=1×3+3 | 倍率不影响atk_boost |
| 保龄泡泡+爆裂葡萄(N=2) | 71(atk2,×2)+8(atk5) | 14=(2+5)×2 | 9=2×2+5 | 倍率只乘保龄泡泡自己的atk |
| 保龄泡泡+爆裂葡萄(N=3) | 71(atk2,×3)+8(atk5) | 21=(2+5)×3 | 11=2×3+5 | 同上 |
| 保龄泡泡+龙舌兰(N=2) | 71(atk2,×2)+10(atk3) | 10=(2+3)×2 | 7=2×2+3 | 同上 |
| 西瓜投手(对坦克) | 33(atk4,×3,限制) | 12=4×3 | 12=4×3 | 单卡无影响 |
| 毁灭菇(对非坦克) | 34(atk5,×2,限制) | 10=5×2 | 10=5×2 | 单卡无影响 |
| 橡木弓手(对坦克) | 68(atk2,×2,限制) | 4=2×2 | 4=2×2 | 单卡无影响 |

### 15.4 不受倍率影响的flat buff类技能

以下技能为**flat加算型**，不参与任何倍率运算：

| 技能ID | 卡牌 | 效果 | 作用方式 |
|--------|------|------|----------|
| `DMG_BUFF_ADD_3` | 64瓷砖萝卜(辅) | 增伤+3 | 直接加算到总伤害 |
| `BOOST_ATK_HEAL` | 41能量花(辅) | 增伤+2+回血2 | 增伤+2直接加算 |
| `DMG_BUFF_ADD_2` | 38香水蘑菇(辅) | 增伤+2 | 直接加算到总伤害 |

### 15.5 代码修正对照

`effect_system.gd` 中已完成以下修改：

1. **5个倍率handler** — 从写入全局 `_dmg_multiplier` 改为写入每卡独立 `_card_multipliers[card_id]`
2. **`_calc_raw_damage`** — 从 `total_damage × global_mult` 改为 `Σ(card_atk × per_card_mult[card_id]) + atk_boost`
3. 倍率仅作用于声明该技能的卡牌自身atk，不影响其他卡牌atk或flat buff
