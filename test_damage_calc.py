# -*- coding: utf-8 -*-
"""
战斗结算伤害计算测试脚本
对齐 effect_system.gd 中的 _calc_raw_damage 逻辑

测试规则：
1. 主卡对主卡的克制判定
2. 辅助卡独立计算（不受克制影响）
3. 总伤害 = 主卡伤害 + 辅助卡攻击力
"""

# 阵营克制关系
FACTION_COUNTER = {
    "法": "射",   # 法师克制射手
    "射": "坦",   # 射手克制坦克
    "坦": "法",   # 坦克克制法师
    "辅": "",     # 辅助无克制
}


class CardData:
    """模拟卡牌数据"""
    def __init__(self, card_id, name, cost, atk, faction, card_type="主"):
        self.id = card_id
        self.name = name
        self.cost = cost
        self.atk = atk
        self.faction = faction
        self.type = card_type


def calc_raw_damage(my_cards, my_main, opp_cards, opp_main, 
                    atk_boost=0, my_weakened=False, opp_weakened=False,
                    dmg_multiplier=1.0, atk_disabled=False, main_atk_zero=False):
    """
    计算原始伤害
    对齐 effect_system.gd#L743-L800 的逻辑
    
    参数：
    - my_cards: 我方所有出牌数组
    - my_main: 我方主卡
    - opp_cards: 对方所有出牌数组
    - opp_main: 对方主卡
    - atk_boost: 攻击增益
    - my_weakened: 我方是否被弱化
    - opp_weakened: 对方是否被弱化
    - dmg_multiplier: 伤害乘算
    - atk_disabled: 攻击是否被禁用
    - main_atk_zero: 主卡攻击是否清零
    
    返回：最终伤害值
    """
    if my_main is None:
        return 0
    
    # 攻击禁用检查
    if atk_disabled or main_atk_zero:
        return 0
    
    # -- 第一步：主卡对主卡的克制判定 --
    my_main_atk = my_main.atk
    opp_main_atk = opp_main.atk if opp_main else 0
    
    # 弱化处理（影响主卡攻击力）
    if my_weakened:
        my_main_atk = min(my_main_atk, 1)
    if opp_weakened:
        opp_main_atk = min(opp_main_atk, 1)
    
    # 阵营判定（基于主卡）
    my_faction = my_main.faction
    opp_faction = opp_main.faction if opp_main else ""
    i_counter_opp = FACTION_COUNTER.get(my_faction, "") == opp_faction
    opp_counters_me = FACTION_COUNTER.get(opp_faction, "") == my_faction
    
    if i_counter_opp:
        # 我克制对手：主卡伤害 = max(0, my_main_atk - opp_main_atk)
        main_damage = max(0, my_main_atk - opp_main_atk)
    elif opp_counters_me:
        # 对手克制我：主卡伤害为0
        main_damage = 0
    else:
        # 无克制：主卡全额伤害
        main_damage = my_main_atk
    
    # -- 第二步：计算辅助卡攻击力（独立计算，不受克制影响）--
    support_atk = 0
    for c in my_cards:
        if c != my_main:
            support_atk += c.atk
    
    # -- 第三步：总伤害 = 主卡伤害 + 辅助卡攻击力 --
    total_damage = main_damage + support_atk
    
    # 应用 atk_boost（加算到总伤害）
    total_damage += atk_boost
    
    # 应用弱化（影响总伤害）
    if my_weakened:
        total_damage = min(total_damage, 1)
    total_damage = max(0, total_damage)
    
    # 应用乘算（dmg_multiplier）
    total_damage = int(total_damage * dmg_multiplier)
    
    return total_damage


def run_tests():
    """运行测试用例"""
    
    print("=" * 60)
    print("战斗结算伤害计算测试")
    print("=" * 60)
    
    test_results = []
    
    # ===== 测试用例 1：法主卡克制射主卡（主卡攻击小于对方）=====
    print("\n【测试1】法主卡(atk=3) + 辅卡(atk=2) vs 射主卡(atk=4)")
    print("-" * 60)
    
    fa_card = CardData(4, "火爆辣椒", 2, 3, "法")  # 法师主卡
    fu_card = CardData(8, "爆裂葡萄", 0, 2, "辅")  # 辅助卡
    sh_card = CardData(6, "玉米投手", 2, 4, "射")  # 射手主卡
    
    my_cards = [fa_card, fu_card]
    opp_cards = [sh_card]
    
    result = calc_raw_damage(my_cards, fa_card, opp_cards, sh_card)
    
    print(f"  主卡克制判定: 法→射, 3 < 4 → main_damage = 0")
    print(f"  辅助卡计算:  辅卡atk=2 → support_atk = 2")
    print(f"  总伤害:      0 + 2 = {result}")
    print(f"  预期结果:    2")
    print(f"  ✓ 测试通过:  {result == 2}")
    
    test_results.append(result == 2)
    
    # ===== 测试用例 2：法主卡克制射主卡（主卡攻击大于对方）=====
    print("\n【测试2】法主卡(atk=5) + 辅卡(atk=2) vs 射主卡(atk=4)")
    print("-" * 60)
    
    fa_strong = CardData(4, "法师强卡", 3, 5, "法")  # 法师主卡(atk=5)
    fu_card2 = CardData(8, "爆裂葡萄", 0, 2, "辅")  # 辅助卡
    sh_card2 = CardData(6, "玉米投手", 2, 4, "射")  # 射手主卡
    
    my_cards2 = [fa_strong, fu_card2]
    opp_cards2 = [sh_card2]
    
    result2 = calc_raw_damage(my_cards2, fa_strong, opp_cards2, sh_card2)
    
    print(f"  主卡克制判定: 法→射, 5 > 4 → main_damage = 5-4 = 1")
    print(f"  辅助卡计算:  辅卡atk=2 → support_atk = 2")
    print(f"  总伤害:      1 + 2 = {result2}")
    print(f"  预期结果:    3")
    print(f"  ✓ 测试通过:  {result2 == 3}")
    
    test_results.append(result2 == 3)
    
    # ===== 测试用例 3：无克制关系 =====
    print("\n【测试3】射主卡(atk=3) + 辅卡(atk=2) vs 坦主卡(atk=2)")
    print("-" * 60)
    
    sh_card3 = CardData(2, "豌豆射手", 1, 3, "射")  # 射手主卡
    fu_card3 = CardData(8, "爆裂葡萄", 0, 2, "辅")  # 辅助卡
    tk_card = CardData(3, "坚果墙", 2, 2, "坦")  # 坦克主卡
    
    my_cards3 = [sh_card3, fu_card3]
    opp_cards3 = [tk_card]
    
    result3 = calc_raw_damage(my_cards3, sh_card3, opp_cards3, tk_card)
    
    print(f"  主卡克制判定: 射→坦(克制), 3 > 2 → main_damage = 3-2 = 1")
    print(f"  辅助卡计算:  辅卡atk=2 → support_atk = 2")
    print(f"  总伤害:      1 + 2 = {result3}")
    print(f"  预期结果:    3")
    print(f"  ✓ 测试通过:  {result3 == 3}")
    
    test_results.append(result3 == 3)
    
    # ===== 测试用例 4：被克制方 =====
    print("\n【测试4】射主卡(atk=3) + 辅卡(atk=2) vs 法主卡(atk=2)")
    print("-" * 60)
    
    sh_card4 = CardData(2, "豌豆射手", 1, 3, "射")  # 射手主卡
    fu_card4 = CardData(8, "爆裂葡萄", 0, 2, "辅")  # 辅助卡
    fa_card4 = CardData(4, "火爆辣椒", 2, 2, "法")  # 法师主卡
    
    my_cards4 = [sh_card4, fu_card4]
    opp_cards4 = [fa_card4]
    
    result4 = calc_raw_damage(my_cards4, sh_card4, opp_cards4, fa_card4)
    
    print(f"  主卡克制判定: 射被法克制 → main_damage = 0")
    print(f"  辅助卡计算:  辅卡atk=2 → support_atk = 2")
    print(f"  总伤害:      0 + 2 = {result4}")
    print(f"  预期结果:    2")
    print(f"  ✓ 测试通过:  {result4 == 2}")
    
    test_results.append(result4 == 2)
    
    # ===== 测试用例 5：多辅助卡 =====
    print("\n【测试5】法主卡(atk=2) + 辅卡1(atk=1) + 辅卡2(atk=1) vs 射主卡(atk=5)")
    print("-" * 60)
    
    fa_card5 = CardData(4, "法师", 2, 2, "法")  # 法师主卡
    fu_card5a = CardData(1, "向日葵", 1, 1, "辅")  # 辅助卡1
    fu_card5b = CardData(5, "梅小美", 1, 1, "辅")  # 辅助卡2
    sh_card5 = CardData(6, "玉米投手", 2, 5, "射")  # 射手主卡
    
    my_cards5 = [fa_card5, fu_card5a, fu_card5b]
    opp_cards5 = [sh_card5]
    
    result5 = calc_raw_damage(my_cards5, fa_card5, opp_cards5, sh_card5)
    
    print(f"  主卡克制判定: 法→射, 2 < 5 → main_damage = 0")
    print(f"  辅助卡计算:  辅卡atk=1+1 → support_atk = 2")
    print(f"  总伤害:      0 + 2 = {result5}")
    print(f"  预期结果:    2")
    print(f"  ✓ 测试通过:  {result5 == 2}")
    
    test_results.append(result5 == 2)
    
    # ===== 测试用例 6：atk_boost 增益 =====
    print("\n【测试6】射主卡(atk=3) + 辅卡(atk=1) vs 坦主卡(atk=3), atk_boost=2")
    print("-" * 60)
    
    sh_card6 = CardData(2, "豌豆射手", 1, 3, "射")  # 射手主卡
    fu_card6 = CardData(8, "爆裂葡萄", 0, 1, "辅")  # 辅助卡
    tk_card6 = CardData(3, "坚果墙", 2, 3, "坦")  # 坦克主卡
    
    my_cards6 = [sh_card6, fu_card6]
    opp_cards6 = [tk_card6]
    
    result6 = calc_raw_damage(my_cards6, sh_card6, opp_cards6, tk_card6, atk_boost=2)
    
    print(f"  主卡克制判定: 射→坦(克制), 3 = 3 → main_damage = 0")
    print(f"  辅助卡计算:  辅卡atk=1 → support_atk = 1")
    print(f"  加算增益:    + atk_boost(2)")
    print(f"  总伤害:      0 + 1 + 2 = {result6}")
    print(f"  预期结果:    3")
    print(f"  ✓ 测试通过:  {result6 == 3}")
    
    test_results.append(result6 == 3)
    
    # ===== 测试用例 7：弱化效果 =====
    print("\n【测试7】法主卡(atk=5) + 辅卡(atk=3) vs 射主卡(atk=4), 我方被弱化")
    print("-" * 60)
    
    fa_card7 = CardData(4, "法师强卡", 3, 5, "法")  # 法师主卡
    fu_card7 = CardData(8, "爆裂葡萄", 0, 3, "辅")  # 辅助卡
    sh_card7 = CardData(6, "玉米投手", 2, 4, "射")  # 射手主卡
    
    my_cards7 = [fa_card7, fu_card7]
    opp_cards7 = [sh_card7]
    
    result7 = calc_raw_damage(my_cards7, fa_card7, opp_cards7, sh_card7, my_weakened=True)
    
    print(f"  主卡克制判定: 法→射, 5弱化→1, 1 < 4 → main_damage = 0")
    print(f"  辅助卡计算:  辅卡atk=3 → support_atk = 3")
    print(f"  总伤害(弱化前): 0 + 3 = 3")
    print(f"  弱化总伤害:   min(3, 1) = {result7}")
    print(f"  预期结果:    1")
    print(f"  ✓ 测试通过:  {result7 == 1}")
    
    test_results.append(result7 == 1)
    
    # ===== 测试用例 8：无主卡 =====
    print("\n【测试8】只有辅助卡，无主卡")
    print("-" * 60)
    
    fu_card8 = CardData(8, "爆裂葡萄", 0, 5, "辅")  # 辅助卡
    sh_card8 = CardData(6, "玉米投手", 2, 4, "射")  # 射手主卡
    
    my_cards8 = [fu_card8]
    opp_cards8 = [sh_card8]
    
    result8 = calc_raw_damage(my_cards8, None, opp_cards8, sh_card8)
    
    print(f"  无主卡，返回: {result8}")
    print(f"  预期结果:    0")
    print(f"  ✓ 测试通过:  {result8 == 0}")
    
    test_results.append(result8 == 0)
    
    # ===== 测试用例 9：伤害乘算 =====
    print("\n【测试9】射主卡(atk=3) + 辅卡(atk=2) vs 坦主卡(atk=2), dmg_multiplier=2.0")
    print("-" * 60)
    
    sh_card9 = CardData(2, "豌豆射手", 1, 3, "射")  # 射手主卡
    fu_card9 = CardData(8, "爆裂葡萄", 0, 2, "辅")  # 辅助卡
    tk_card9 = CardData(3, "坚果墙", 2, 2, "坦")  # 坦克主卡
    
    my_cards9 = [sh_card9, fu_card9]
    opp_cards9 = [tk_card9]
    
    result9 = calc_raw_damage(my_cards9, sh_card9, opp_cards9, tk_card9, dmg_multiplier=2.0)
    
    print(f"  主卡克制判定: 射→坦(克制), 3 > 2 → main_damage = 1")
    print(f"  辅助卡计算:  辅卡atk=2 → support_atk = 2")
    print(f"  总伤害(乘算前): 1 + 2 = 3")
    print(f"  乘算:         3 × 2.0 = {result9}")
    print(f"  预期结果:    6")
    print(f"  ✓ 测试通过:  {result9 == 6}")
    
    test_results.append(result9 == 6)
    
    # ===== 汇总结果 =====
    print("\n" + "=" * 60)
    print("测试结果汇总")
    print("=" * 60)
    
    passed = sum(test_results)
    total = len(test_results)
    
    for i, passed_flag in enumerate(test_results, 1):
        status = "✓ PASS" if passed_flag else "✗ FAIL"
        print(f"  测试{i}: {status}")
    
    print(f"\n  通过率: {passed}/{total} ({passed*100//total}%)")
    
    if passed == total:
        print("\n  🎉 所有测试通过！伤害计算逻辑正确。")
    else:
        print("\n  ❌ 有测试未通过，请检查逻辑。")
    
    return passed == total


if __name__ == "__main__":
    run_tests()
