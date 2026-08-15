# -*- coding: utf-8 -*-
"""
战斗结算伤害计算测试 - 扩展场景
测试多张卡牌对战的伤害计算

场景类型：
- 2对1：克制方出2张，被克制方出1张
- 1对2：克制方出1张，被克制方出2张
- 2对2：双方各出2张，有克制关系
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
    """
    if my_main is None:
        return 0
    
    # 攻击禁用检查
    if atk_disabled or main_atk_zero:
        return 0
    
    # -- 第一步：主卡对主卡的克制判定 --
    my_main_atk = my_main.atk
    opp_main_atk = opp_main.atk if opp_main else 0
    
    # 弱化处理
    if my_weakened:
        my_main_atk = min(my_main_atk, 1)
    if opp_weakened:
        opp_main_atk = min(opp_main_atk, 1)
    
    # 阵营判定
    my_faction = my_main.faction
    opp_faction = opp_main.faction if opp_main else ""
    i_counter_opp = FACTION_COUNTER.get(my_faction, "") == opp_faction
    opp_counters_me = FACTION_COUNTER.get(opp_faction, "") == my_faction
    
    if i_counter_opp:
        main_damage = max(0, my_main_atk - opp_main_atk)
    elif opp_counters_me:
        main_damage = 0
    else:
        main_damage = my_main_atk
    
    # -- 第二步：计算辅助卡攻击力 --
    support_atk = 0
    for c in my_cards:
        if c != my_main:
            support_atk += c.atk
    
    # -- 第三步：总伤害 = 主卡伤害 + 辅助卡攻击力 --
    total_damage = main_damage + support_atk
    total_damage += atk_boost
    
    if my_weakened:
        total_damage = min(total_damage, 1)
    total_damage = max(0, total_damage)
    
    total_damage = int(total_damage * dmg_multiplier)
    
    return total_damage


def test_scenario_2v1():
    """
    场景1：2对1（克制方出2张，被克制方出1张）
    我方(克制方)：法主卡(atk=3) + 辅卡(atk=2)
    对方(被克制方)：射主卡(atk=4)
    
    预期：
    - 主卡克制：法→射，3 < 4 → main_damage = 0
    - 辅助卡：2
    - 总伤害：0 + 2 = 2
    """
    print("\n" + "=" * 70)
    print("场景1：2对1 - 克制方出2张，被克制方出1张")
    print("=" * 70)
    
    fa_main = CardData(4, "火爆辣椒", 2, 3, "法")      # 法主卡(atk=3)
    fu_support = CardData(8, "爆裂葡萄", 0, 2, "辅")   # 辅卡(atk=2)
    sh_main = CardData(6, "玉米投手", 2, 4, "射")      # 射主卡(atk=4)
    
    # 我方：2张（法主+辅）
    my_cards = [fa_main, fu_support]
    # 对方：1张（射主）
    opp_cards = [sh_main]
    
    result = calc_raw_damage(my_cards, fa_main, opp_cards, sh_main)
    
    print(f"\n  我方(克制方)出卡: 法主卡(atk=3) + 辅卡(atk=2)")
    print(f"  对方(被克制方)出卡: 射主卡(atk=4)")
    print(f"  ─────────────────────────────────────────────")
    print(f"  主卡克制判定: 法→射, 3 < 4")
    print(f"  主卡伤害:     0")
    print(f"  辅助卡伤害:   2")
    print(f"  ─────────────────────────────────────────────")
    print(f"  总伤害:       {result}")
    print(f"  预期:         2")
    print(f"  ✓ 通过:       {result == 2}")
    
    return result == 2, result


def test_scenario_1v2():
    """
    场景2：1对2（克制方出1张，被克制方出2张）
    我方(克制方)：法主卡(atk=5)
    对方(被克制方)：射主卡(atk=3) + 辅卡(atk=1)
    
    预期：
    - 我方单张法主卡，克制对方射主卡
    - 主卡克制：法→射，5 > 3 → main_damage = 5-3 = 2
    - 我方无辅助卡
    - 总伤害：2
    """
    print("\n" + "=" * 70)
    print("场景2：1对2 - 克制方出1张，被克制方出2张")
    print("=" * 70)
    
    fa_main = CardData(4, "火爆辣椒", 2, 5, "法")      # 法主卡(atk=5)
    sh_main = CardData(6, "玉米投手", 2, 3, "射")      # 射主卡(atk=3)
    fu_support = CardData(8, "爆裂葡萄", 0, 1, "辅")   # 辅卡(atk=1)
    
    # 我方：1张（法主）
    my_cards = [fa_main]
    # 对方：2张（射主+辅）
    opp_cards = [sh_main, fu_support]
    
    result = calc_raw_damage(my_cards, fa_main, opp_cards, sh_main)
    
    print(f"\n  我方(克制方)出卡: 法主卡(atk=5)")
    print(f"  对方(被克制方)出卡: 射主卡(atk=3) + 辅卡(atk=1)")
    print(f"  ─────────────────────────────────────────────")
    print(f"  主卡克制判定: 法→射, 5 > 3")
    print(f"  主卡伤害:     5 - 3 = 2")
    print(f"  辅助卡伤害:   0（我方无辅助卡）")
    print(f"  ─────────────────────────────────────────────")
    print(f"  总伤害:       {result}")
    print(f"  预期:         2")
    print(f"  ✓ 通过:       {result == 2}")
    
    return result == 2, result


def test_scenario_2v2_counter():
    """
    场景3：2对2（有克制关系）
    我方：法主卡(atk=4) + 辅卡(atk=2)
    对方：射主卡(atk=3) + 辅卡(atk=1)
    
    预期：
    - 主卡克制：法→射，4 > 3 → main_damage = 4-3 = 1
    - 我方辅助卡：2
    - 总伤害：1 + 2 = 3
    """
    print("\n" + "=" * 70)
    print("场景3：2对2 - 有克制关系")
    print("=" * 70)
    
    fa_main = CardData(4, "火爆辣椒", 2, 4, "法")      # 法主卡(atk=4)
    fu_support = CardData(8, "爆裂葡萄", 0, 2, "辅")   # 辅卡(atk=2)
    sh_main = CardData(6, "玉米投手", 2, 3, "射")      # 射主卡(atk=3)
    fu_support2 = CardData(1, "向日葵", 1, 1, "辅")    # 辅卡(atk=1)
    
    # 我方：2张（法主+辅）
    my_cards = [fa_main, fu_support]
    # 对方：2张（射主+辅）
    opp_cards = [sh_main, fu_support2]
    
    result = calc_raw_damage(my_cards, fa_main, opp_cards, sh_main)
    
    print(f"\n  我方出卡: 法主卡(atk=4) + 辅卡(atk=2)")
    print(f"  对方出卡: 射主卡(atk=3) + 辅卡(atk=1)")
    print(f"  ─────────────────────────────────────────────")
    print(f"  主卡克制判定: 法→射, 4 > 3")
    print(f"  主卡伤害:     4 - 3 = 1")
    print(f"  辅助卡伤害:   2")
    print(f"  ─────────────────────────────────────────────")
    print(f"  总伤害:       {result}")
    print(f"  预期:         3")
    print(f"  ✓ 通过:       {result == 3}")
    
    return result == 3, result


def test_scenario_2v2_no_counter():
    """
    场景4：2对2（无克制关系 - 我方被克制）
    我方：射主卡(atk=3) + 辅卡(atk=2)
    对方：法主卡(atk=4) + 辅卡(atk=1)
    
    预期：
    - 主卡克制：射被法克制 → main_damage = 0
    - 我方辅助卡：2
    - 总伤害：0 + 2 = 2
    """
    print("\n" + "=" * 70)
    print("场景4：2对2 - 我方被克制")
    print("=" * 70)
    
    sh_main = CardData(2, "豌豆射手", 1, 3, "射")      # 射主卡(atk=3)
    fu_support = CardData(8, "爆裂葡萄", 0, 2, "辅")   # 辅卡(atk=2)
    fa_main = CardData(4, "火爆辣椒", 2, 4, "法")      # 法主卡(atk=4)
    fu_support2 = CardData(1, "向日葵", 1, 1, "辅")    # 辅卡(atk=1)
    
    # 我方：2张（射主+辅）
    my_cards = [sh_main, fu_support]
    # 对方：2张（法主+辅）
    opp_cards = [fa_main, fu_support2]
    
    result = calc_raw_damage(my_cards, sh_main, opp_cards, fa_main)
    
    print(f"\n  我方出卡: 射主卡(atk=3) + 辅卡(atk=2)")
    print(f"  对方出卡: 法主卡(atk=4) + 辅卡(atk=1)")
    print(f"  ─────────────────────────────────────────────")
    print(f"  主卡克制判定: 射被法克制")
    print(f"  主卡伤害:     0（被克制方主卡伤害清零）")
    print(f"  辅助卡伤害:   2")
    print(f"  ─────────────────────────────────────────────")
    print(f"  总伤害:       {result}")
    print(f"  预期:         2")
    print(f"  ✓ 通过:       {result == 2}")
    
    return result == 2, result


def test_scenario_2v2_tank_counter():
    """
    场景5：2对2 - 坦克克制法师
    我方(克制方)：坦主卡(atk=5) + 辅卡(atk=2)
    对方(被克制方)：法主卡(atk=3) + 辅卡(atk=1)
    
    预期：
    - 主卡克制：坦→法，5 > 3 → main_damage = 5-3 = 2
    - 我方辅助卡：2
    - 总伤害：2 + 2 = 4
    """
    print("\n" + "=" * 70)
    print("场景5：2对2 - 坦克克制法师")
    print("=" * 70)
    
    tk_main = CardData(13, "窝瓜", 3, 5, "坦")        # 坦主卡(atk=5)
    fu_support = CardData(8, "爆裂葡萄", 0, 2, "辅")   # 辅卡(atk=2)
    fa_main = CardData(4, "火爆辣椒", 2, 3, "法")      # 法主卡(atk=3)
    fu_support2 = CardData(1, "向日葵", 1, 1, "辅")    # 辅卡(atk=1)
    
    # 我方：2张（坦主+辅）
    my_cards = [tk_main, fu_support]
    # 对方：2张（法主+辅）
    opp_cards = [fa_main, fu_support2]
    
    result = calc_raw_damage(my_cards, tk_main, opp_cards, fa_main)
    
    print(f"\n  我方出卡: 坦主卡(atk=5) + 辅卡(atk=2)")
    print(f"  对方出卡: 法主卡(atk=3) + 辅卡(atk=1)")
    print(f"  ─────────────────────────────────────────────")
    print(f"  主卡克制判定: 坦→法, 5 > 3")
    print(f"  主卡伤害:     5 - 3 = 2")
    print(f"  辅助卡伤害:   2")
    print(f"  ─────────────────────────────────────────────")
    print(f"  总伤害:       {result}")
    print(f"  预期:         4")
    print(f"  ✓ 通过:       {result == 4}")
    
    return result == 4, result


def test_scenario_2v2_archer_counter():
    """
    场景6：2对2 - 射手克制坦克
    我方(克制方)：射主卡(atk=4) + 辅卡(atk=2)
    对方(被克制方)：坦主卡(atk=3) + 辅卡(atk=1)
    
    预期：
    - 主卡克制：射→坦，4 > 3 → main_damage = 4-3 = 1
    - 我方辅助卡：2
    - 总伤害：1 + 2 = 3
    """
    print("\n" + "=" * 70)
    print("场景6：2对2 - 射手克制坦克")
    print("=" * 70)
    
    sh_main = CardData(2, "豌豆射手", 1, 4, "射")      # 射主卡(atk=4)
    fu_support = CardData(8, "爆裂葡萄", 0, 2, "辅")   # 辅卡(atk=2)
    tk_main = CardData(3, "坚果墙", 2, 3, "坦")        # 坦主卡(atk=3)
    fu_support2 = CardData(1, "向日葵", 1, 1, "辅")    # 辅卡(atk=1)
    
    # 我方：2张（射主+辅）
    my_cards = [sh_main, fu_support]
    # 对方：2张（坦主+辅）
    opp_cards = [tk_main, fu_support2]
    
    result = calc_raw_damage(my_cards, sh_main, opp_cards, tk_main)
    
    print(f"\n  我方出卡: 射主卡(atk=4) + 辅卡(atk=2)")
    print(f"  对方出卡: 坦主卡(atk=3) + 辅卡(atk=1)")
    print(f"  ─────────────────────────────────────────────")
    print(f"  主卡克制判定: 射→坦, 4 > 3")
    print(f"  主卡伤害:     4 - 3 = 1")
    print(f"  辅助卡伤害:   2")
    print(f"  ─────────────────────────────────────────────")
    print(f"  总伤害:       {result}")
    print(f"  预期:         3")
    print(f"  ✓ 通过:       {result == 3}")
    
    return result == 3, result


def test_scenario_2v2_equal_atk():
    """
    场景7：2对2 - 主卡攻击力相等
    我方(克制方)：法主卡(atk=3) + 辅卡(atk=2)
    对方(被克制方)：射主卡(atk=3) + 辅卡(atk=1)
    
    预期：
    - 主卡克制：法→射，3 = 3 → main_damage = 0
    - 我方辅助卡：2
    - 总伤害：0 + 2 = 2
    """
    print("\n" + "=" * 70)
    print("场景7：2对2 - 主卡攻击力相等")
    print("=" * 70)
    
    fa_main = CardData(4, "火爆辣椒", 2, 3, "法")      # 法主卡(atk=3)
    fu_support = CardData(8, "爆裂葡萄", 0, 2, "辅")   # 辅卡(atk=2)
    sh_main = CardData(6, "玉米投手", 2, 3, "射")      # 射主卡(atk=3)
    fu_support2 = CardData(1, "向日葵", 1, 1, "辅")    # 辅卡(atk=1)
    
    # 我方：2张（法主+辅）
    my_cards = [fa_main, fu_support]
    # 对方：2张（射主+辅）
    opp_cards = [sh_main, fu_support2]
    
    result = calc_raw_damage(my_cards, fa_main, opp_cards, sh_main)
    
    print(f"\n  我方出卡: 法主卡(atk=3) + 辅卡(atk=2)")
    print(f"  对方出卡: 射主卡(atk=3) + 辅卡(atk=1)")
    print(f"  ─────────────────────────────────────────────")
    print(f"  主卡克制判定: 法→射, 3 = 3")
    print(f"  主卡伤害:     0（克制方攻击力≤被克制方）")
    print(f"  辅助卡伤害:   2")
    print(f"  ─────────────────────────────────────────────")
    print(f"  总伤害:       {result}")
    print(f"  预期:         2")
    print(f"  ✓ 通过:       {result == 2}")
    
    return result == 2, result


def run_all_tests():
    """运行所有测试"""
    
    print("=" * 70)
    print("战斗结算伤害计算测试 - 扩展场景")
    print("=" * 70)
    print("\n测试场景:")
    print("  1. 2对1 - 克制方出2张，被克制方出1张")
    print("  2. 1对2 - 克制方出1张，被克制方出2张")
    print("  3. 2对2 - 有克制关系（克制方出2张，被克制方出2张）")
    print("  4. 2对2 - 我方被克制")
    print("  5. 2对2 - 坦克克制法师")
    print("  6. 2对2 - 射手克制坦克")
    print("  7. 2对2 - 主卡攻击力相等")
    
    tests = [
        ("2对1 (克制方2 vs 被克制方1)", test_scenario_2v1),
        ("1对2 (克制方1 vs 被克制方2)", test_scenario_1v2),
        ("2对2 (克制方2 vs 被克制方2)", test_scenario_2v2_counter),
        ("2对2 (我方被克制)", test_scenario_2v2_no_counter),
        ("2对2 (坦克克制法师)", test_scenario_2v2_tank_counter),
        ("2对2 (射手克制坦克)", test_scenario_2v2_archer_counter),
        ("2对2 (主卡攻击力相等)", test_scenario_2v2_equal_atk),
    ]
    
    results = []
    for name, test_fn in tests:
        passed, value = test_fn()
        results.append((name, passed, value))
    
    # 汇总
    print("\n" + "=" * 70)
    print("测试结果汇总")
    print("=" * 70)
    
    passed_count = 0
    total = len(results)
    
    for i, (name, passed, value) in enumerate(results, 1):
        status = "✓ PASS" if passed else "✗ FAIL"
        print(f"  {i}. [{status}] {name} → 伤害: {value}")
        if passed:
            passed_count += 1
    
    print(f"\n  通过率: {passed_count}/{total} ({passed_count*100//total}%)")
    
    if passed_count == total:
        print("\n  🎉 所有测试通过！伤害计算逻辑正确。")
        print("\n  伤害计算规则确认：")
        print("  ┌─────────────────────────────────────────────────────────┐")
        print("  │ 1. 主卡对主卡：先进行克制溢出结算                         │")
        print("  │ 2. 辅助卡独立：攻击力独立计算，不受克制影响               │")
        print("  │ 3. 总伤害 = 主卡伤害 + 辅助卡攻击力                      │")
        print("  └─────────────────────────────────────────────────────────┘")
    else:
        print("\n  ❌ 有测试未通过，请检查逻辑。")
    
    return passed_count == total


if __name__ == "__main__":
    run_all_tests()
