# -*- coding: utf-8 -*-
"""
战斗结算伤害计算测试 - 双向伤害明细
展示双方互相造成伤害的完整对比
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


def calc_raw_damage(attacker_cards, attacker_main, defender_cards, defender_main, 
                    atk_boost=0, attacker_weakened=False, defender_weakened=False,
                    dmg_multiplier=1.0, atk_disabled=False, main_atk_zero=False):
    """
    计算攻击方对防守方造成的伤害
    """
    if attacker_main is None:
        return 0
    
    if atk_disabled or main_atk_zero:
        return 0
    
    # -- 第一步：主卡对主卡的克制判定 --
    atk_main_atk = attacker_main.atk
    def_main_atk = defender_main.atk if defender_main else 0
    
    if attacker_weakened:
        atk_main_atk = min(atk_main_atk, 1)
    if defender_weakened:
        def_main_atk = min(def_main_atk, 1)
    
    atk_faction = attacker_main.faction
    def_faction = defender_main.faction if defender_main else ""
    i_counter_def = FACTION_COUNTER.get(atk_faction, "") == def_faction
    def_counter_me = FACTION_COUNTER.get(def_faction, "") == atk_faction
    
    if i_counter_def:
        main_damage = max(0, atk_main_atk - def_main_atk)
    elif def_counter_me:
        main_damage = 0
    else:
        main_damage = atk_main_atk
    
    # -- 第二步：计算辅助卡攻击力 --
    support_atk = 0
    for c in attacker_cards:
        if c != attacker_main:
            support_atk += c.atk
    
    # -- 第三步：总伤害 = 主卡伤害 + 辅助卡攻击力 --
    total_damage = main_damage + support_atk
    total_damage += atk_boost
    
    if attacker_weakened:
        total_damage = min(total_damage, 1)
    total_damage = max(0, total_damage)
    
    total_damage = int(total_damage * dmg_multiplier)
    
    return total_damage


def show_battle_detail(p1_cards, p2_cards, scenario_name):
    """
    显示双方战斗的详细伤害计算
    """
    p1_main = None
    p2_main = None
    for c in p1_cards:
        if c.type == "主":
            p1_main = c
    for c in p2_cards:
        if c.type == "主":
            p2_main = c
    
    p1_to_p2 = calc_raw_damage(p1_cards, p1_main, p2_cards, p2_main)
    p2_to_p1 = calc_raw_damage(p2_cards, p2_main, p1_cards, p1_main)
    
    print(f"\n{'='*80}")
    print(f"【{scenario_name}】")
    print(f"{'='*80}")
    
    # 显示双方出卡
    print(f"\n  P1 出卡: ", end="")
    for i, c in enumerate(p1_cards):
        prefix = "主" if c.type == "主" else "辅"
        faction_info = f"[{c.faction}]" if c.faction else ""
        print(f"{c.name}(atk={c.atk}, {prefix}{faction_info})", end="")
        if i < len(p1_cards) - 1:
            print(", ", end="")
    
    print(f"\n  P2 出卡: ", end="")
    for i, c in enumerate(p2_cards):
        prefix = "主" if c.type == "主" else "辅"
        faction_info = f"[{c.faction}]" if c.faction else ""
        print(f"{c.name}(atk={c.atk}, {prefix}{faction_info})", end="")
        if i < len(p2_cards) - 1:
            print(", ", end="")
    
    # 详细伤害计算
    print(f"\n  {'─'*76}")
    print(f"  P1 → P2 伤害计算:")
    
    if p1_main and p2_main:
        p1_faction = p1_main.faction
        p2_faction = p2_main.faction
        p1_counters_p2 = FACTION_COUNTER.get(p1_faction, "") == p2_faction
        p2_counters_p1 = FACTION_COUNTER.get(p2_faction, "") == p1_faction
        
        if p1_counters_p2:
            print(f"    主卡克制: {p1_faction}→{p2_faction} ✓ (P1克制P2)")
            print(f"    主卡伤害: max(0, {p1_main.atk} - {p2_main.atk}) = {max(0, p1_main.atk - p2_main.atk)}")
        elif p2_counters_p1:
            print(f"    主卡克制: {p1_faction}←{p2_faction} ✗ (P2克制P1, P1主卡伤害=0)")
        else:
            print(f"    主卡克制: 无克制关系")
            print(f"    主卡伤害: {p1_main.atk}")
        
        # 辅助卡
        p1_support = sum(c.atk for c in p1_cards if c != p1_main)
        print(f"    辅助卡伤害: {p1_support}")
        print(f"    P1 → P2 总伤害: {p1_to_p2}")
    
    print(f"\n  P2 → P1 伤害计算:")
    
    if p1_main and p2_main:
        p1_faction = p1_main.faction
        p2_faction = p2_main.faction
        p1_counters_p2 = FACTION_COUNTER.get(p1_faction, "") == p2_faction
        p2_counters_p1 = FACTION_COUNTER.get(p2_faction, "") == p1_faction
        
        if p2_counters_p1:
            print(f"    主卡克制: {p2_faction}→{p1_faction} ✓ (P2克制P1)")
            print(f"    主卡伤害: max(0, {p2_main.atk} - {p1_main.atk}) = {max(0, p2_main.atk - p1_main.atk)}")
        elif p1_counters_p2:
            print(f"    主卡克制: {p2_faction}←{p1_faction} ✗ (P1克制P2, P2主卡伤害=0)")
        else:
            print(f"    主卡克制: 无克制关系")
            print(f"    主卡伤害: {p2_main.atk}")
        
        p2_support = sum(c.atk for c in p2_cards if c != p2_main)
        print(f"    辅助卡伤害: {p2_support}")
        print(f"    P2 → P1 总伤害: {p2_to_p1}")
    
    # 伤害对比
    print(f"\n  {'─'*76}")
    print(f"  伤害对比:")
    print(f"    P1 对 P2 造成伤害: {p1_to_p2}")
    print(f"    P2 对 P1 造成伤害: {p2_to_p1}")
    
    if p1_to_p2 > p2_to_p1:
        diff = p1_to_p2 - p2_to_p1
        print(f"    → P1 多造成 {diff} 点伤害")
    elif p2_to_p1 > p1_to_p2:
        diff = p2_to_p1 - p1_to_p2
        print(f"    → P2 多造成 {diff} 点伤害")
    else:
        print(f"    → 双方伤害相等")
    
    return p1_to_p2, p2_to_p1


def main():
    print("=" * 80)
    print("战斗结算伤害计算 - 双向伤害明细")
    print("=" * 80)
    print("\n阵营克制关系: 法→射→坦→法")
    print("伤害计算规则:")
    print("  1. 主卡对主卡：先进行克制溢出结算")
    print("  2. 辅助卡独立：攻击力独立计算，不受克制影响")
    print("  3. 总伤害 = 主卡伤害 + 辅助卡攻击力")
    
    all_results = []
    
    # ===== 场景1：2对1（克制方出2张，被克制方出1张）=====
    p1_cards_1 = [
        CardData(4, "火爆辣椒", 2, 3, "法", "主"),      # 法主卡(atk=3)
        CardData(8, "爆裂葡萄", 0, 2, "辅", "辅"),     # 辅卡(atk=2)
    ]
    p2_cards_1 = [
        CardData(6, "玉米投手", 2, 4, "射", "主"),      # 射主卡(atk=4)
    ]
    
    r1 = show_battle_detail(p1_cards_1, p2_cards_1, 
                            "场景1: 2对1 - P1(法3+辅2) vs P2(射4)")
    all_results.append(("场景1: 2对1", r1))
    
    # ===== 场景2：1对2（克制方出1张，被克制方出2张）=====
    p1_cards_2 = [
        CardData(4, "火爆辣椒", 2, 5, "法", "主"),      # 法主卡(atk=5)
    ]
    p2_cards_2 = [
        CardData(6, "玉米投手", 2, 3, "射", "主"),      # 射主卡(atk=3)
        CardData(8, "爆裂葡萄", 0, 1, "辅", "辅"),     # 辅卡(atk=1)
    ]
    
    r2 = show_battle_detail(p1_cards_2, p2_cards_2,
                            "场景2: 1对2 - P1(法5) vs P2(射3+辅1)")
    all_results.append(("场景2: 1对2", r2))
    
    # ===== 场景3：2对2（有克制关系）=====
    p1_cards_3 = [
        CardData(4, "火爆辣椒", 2, 4, "法", "主"),      # 法主卡(atk=4)
        CardData(8, "爆裂葡萄", 0, 2, "辅", "辅"),     # 辅卡(atk=2)
    ]
    p2_cards_3 = [
        CardData(6, "玉米投手", 2, 3, "射", "主"),      # 射主卡(atk=3)
        CardData(1, "向日葵", 1, 1, "辅", "辅"),       # 辅卡(atk=1)
    ]
    
    r3 = show_battle_detail(p1_cards_3, p2_cards_3,
                            "场景3: 2对2 - P1(法4+辅2) vs P2(射3+辅1)")
    all_results.append(("场景3: 2对2", r3))
    
    # ===== 场景4：2对2（我方被克制）=====
    p1_cards_4 = [
        CardData(2, "豌豆射手", 1, 3, "射", "主"),      # 射主卡(atk=3)
        CardData(8, "爆裂葡萄", 0, 2, "辅", "辅"),     # 辅卡(atk=2)
    ]
    p2_cards_4 = [
        CardData(4, "火爆辣椒", 2, 4, "法", "主"),      # 法主卡(atk=4)
        CardData(1, "向日葵", 1, 1, "辅", "辅"),       # 辅卡(atk=1)
    ]
    
    r4 = show_battle_detail(p1_cards_4, p2_cards_4,
                            "场景4: 2对2 - P1(射3+辅2) vs P2(法4+辅1)")
    all_results.append(("场景4: 2对2(被克制)", r4))
    
    # ===== 场景5：2对2（坦克克制法师）=====
    p1_cards_5 = [
        CardData(13, "窝瓜", 3, 5, "坦", "主"),         # 坦主卡(atk=5)
        CardData(8, "爆裂葡萄", 0, 2, "辅", "辅"),     # 辅卡(atk=2)
    ]
    p2_cards_5 = [
        CardData(4, "火爆辣椒", 2, 3, "法", "主"),      # 法主卡(atk=3)
        CardData(1, "向日葵", 1, 1, "辅", "辅"),       # 辅卡(atk=1)
    ]
    
    r5 = show_battle_detail(p1_cards_5, p2_cards_5,
                            "场景5: 2对2 - P1(坦5+辅2) vs P2(法3+辅1)")
    all_results.append(("场景5: 坦克克法", r5))
    
    # ===== 场景6：2对2（射手克制坦克）=====
    p1_cards_6 = [
        CardData(2, "豌豆射手", 1, 4, "射", "主"),      # 射主卡(atk=4)
        CardData(8, "爆裂葡萄", 0, 2, "辅", "辅"),     # 辅卡(atk=2)
    ]
    p2_cards_6 = [
        CardData(3, "坚果墙", 2, 3, "坦", "主"),       # 坦主卡(atk=3)
        CardData(1, "向日葵", 1, 1, "辅", "辅"),       # 辅卡(atk=1)
    ]
    
    r6 = show_battle_detail(p1_cards_6, p2_cards_6,
                            "场景6: 2对2 - P1(射4+辅2) vs P2(坦3+辅1)")
    all_results.append(("场景6: 射克坦克", r6))
    
    # ===== 场景7：2对2（主卡攻击力相等）=====
    p1_cards_7 = [
        CardData(4, "火爆辣椒", 2, 3, "法", "主"),      # 法主卡(atk=3)
        CardData(8, "爆裂葡萄", 0, 2, "辅", "辅"),     # 辅卡(atk=2)
    ]
    p2_cards_7 = [
        CardData(6, "玉米投手", 2, 3, "射", "主"),      # 射主卡(atk=3)
        CardData(1, "向日葵", 1, 1, "辅", "辅"),       # 辅卡(atk=1)
    ]
    
    r7 = show_battle_detail(p1_cards_7, p2_cards_7,
                            "场景7: 2对2 - P1(法3+辅2) vs P2(射3+辅1)")
    all_results.append(("场景7: 攻击相等", r7))
    
    # ===== 汇总表 =====
    print("\n" + "=" * 80)
    print("伤害汇总表")
    print("=" * 80)
    print(f"\n{'场景':<30} {'P1→P2':>8} {'P2→P1':>8} {'差值':>8}")
    print("-" * 58)
    
    for name, (p1_dmg, p2_dmg) in all_results:
        diff = p1_dmg - p2_dmg
        diff_str = f"+{diff}" if diff > 0 else str(diff) if diff < 0 else "0"
        print(f"{name:<30} {p1_dmg:>8} {p2_dmg:>8} {diff_str:>8}")
    
    print("-" * 58)
    print(f"\n说明:")
    print(f"  P1→P2: P1对P2造成的伤害")
    print(f"  P2→P1: P2对P1造成的伤害")
    print(f"  差值:  正数表示P1多造成的伤害，负数表示P2多造成的伤害")


if __name__ == "__main__":
    main()
