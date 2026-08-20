# 更新日志

## 2026-08-19 v1.4.0 图鉴功能 + 信箱公告补全 + Bug 修复

### 新增功能

**图鉴系统（主菜单 → 图鉴按钮）**
- 新增 `encyclopedia_scene.gd` 图鉴主脚本，动态加载 `cards.json` 全部卡牌
- 新增 `card_paint.gd` `large_mode` 属性支持 120×180 大尺寸卡牌渲染（与实战 UI 一致）
- 新增 `bg_encyclopedia.jpg` 棕色木制相框背景图（AI 生成）
- 主菜单 `EncyclopediaButton` 按钮接线（`main_menu.tscn` + `main_menu.gd`）
- 每行 4 张卡牌网格布局（ScrollContainer + VBox/HBox 动态生成）
- 7 类筛选互斥单选：全部/法/射/坦/辅/限制符:有/限制符:无
- 右上角实时显示当前筛选结果总数
- 右键点击卡牌弹出详情弹窗（属性 + 技能描述）
- ESC 键或返回按钮一键退出图鉴

**信箱公告补全**
- 补写 v1.3.0 大师级人机 + 无牌强制结算公告
- 新写 v1.4.0 图鉴功能公告
- 原 v1.2 公告保留并修正 ID 为 `changelog_v1_2`

### Bug 修复

**StyleBoxFlat 属性赋值越界**（[encyclopedia_scene.gd:100](file:///e:/项目储存/pvz-project/pvz-godot/pvz-plant-card-game/scripts/encyclopedia_scene.gd#L100)）
- 问题：`set_border_width(4, 2)` 中 side=4 越界（Godot 4 `SIDE_BOTTOM=3`）
- 修复：改为 `set_border_width(3, 2)`

**StyleBoxFlat 边框/圆角直接属性赋值**（5 处）
- 问题：`border_width_all = 3`、`border_width_bottom = 2`、`corner_radius_*` 等直接属性赋值在 Godot 4 中无效
- 修复：统一改为方法调用 `set_border_width_all(3)`、`set_border_width(3, 2)`、`set_corner_radius_all(8)`

**ButtonGroup 互斥失效**（[encyclopedia_scene.gd:98](file:///e:/项目储存/pvz-project/pvz-godot/pvz-plant-card-game/scripts/encyclopedia_scene.gd#L98)）
- 问题：`ButtonGroup.new()` 在循环内创建，7 个筛选按钮各有独立分组，互斥失效
- 修复：在循环外创建共享 `filter_group`，所有按钮共用同一组

**背景图覆盖全屏 + 透明度过高**（[encyclopedia_scene.gd:72-102](file:///e:/项目储存/pvz-project/pvz-godot/pvz-plant-card-game/scripts/encyclopedia_scene.gd#L72-L102)）
- 问题：背景图以 `STRETCH_TILE` 平铺全屏 + 半透明遮罩，导致能看穿主菜单
- 修复：改为三层结构 — 全屏不透明 `ColorRect` 遮罩 + 居中木制 `Panel` 外框 + `TextureRect` 仅填充框内区域

**背景图未缩放导致偏离**（[encyclopedia_scene.gd:91-102](file:///e:/项目储存/pvz-project/pvz-godot/pvz-plant-card-game/scripts/encyclopedia_scene.gd#L91-L102)）
- 问题：`STRETCH_KEEP_ASPECT_CENTERED` 保持比例居中导致留白偏离
- 修复：改为 `STRETCH_SCALE` + `EXPAND_IGNORE_SIZE` + `PRESET_FULL_RECT` + offset 6px 自动适配框架大小

### 版本号更新

- `version_manager.gd`：1.3.0 → 1.4.0
- `main_menu.tscn` VersionLabel：v1.2 → v1.4.0
- `export_presets.cfg` Android version/code：1 → 10400，version/name：1.0 → 1.4.0

### 涉及文件

| 文件 | 改动 |
|---|---|
| [scripts/encyclopedia_scene.gd](file:///e:/项目储存/pvz-project/pvz-godot/pvz-plant-card-game/scripts/encyclopedia_scene.gd) | 新建 + 4 轮 bug 修复（StyleBoxFlat/ButtonGroup/背景图） |
| [scripts/card_paint.gd](file:///e:/项目储存/pvz-project/pvz-godot/pvz-plant-card-game/scripts/card_paint.gd) | 新增 `large_mode` + `LARGE_W/H` 常量 |
| [scripts/main_menu.gd](file:///e:/项目储存/pvz-project/pvz-godot/pvz-plant-card-game/scripts/main_menu.gd) | 新增 `encyclopedia_btn` 引用 + 信号连接 |
| [scenes/main_menu.tscn](file:///e:/项目储存/pvz-project/pvz-godot/pvz-plant-card-game/scenes/main_menu.tscn) | 新增 `EncyclopediaButton` 节点 + VersionLabel 更新 |
| [scripts/mailbox_scene.gd](file:///e:/项目储存/pvz-project/pvz-godot/pvz-plant-card-game/scripts/mailbox_scene.gd) | 补写 3 封更新公告（v1.2/v1.3/v1.4） |
| [scripts/version_manager.gd](file:///e:/项目储存/pvz-project/pvz-godot/pvz-plant-card-game/scripts/version_manager.gd) | 版本号 1.3.0 → 1.4.0 |
| [export_presets.cfg](file:///e:/项目储存/pvz-project/pvz-godot/pvz-plant-card-game/export_presets.cfg) | Android version/code + name |
| [assets/images/bg_encyclopedia.jpg](file:///e:/项目储存/pvz-project/pvz-godot/pvz-plant-card-game/assets/images/bg_encyclopedia.jpg) | AI 生成棕色木制相框背景图 |

---

## 2026-08-15 v1.3.0 大师级人机 + 无牌强制结算 + 克制关系修复

### 新增功能

**大师级人机 AI 系统**
- 新增 `ai_system.gd`、`ai_strategy.gd`、`ai_predictor.gd`、`ai_combo_memory.gd`、`ai_card_analyzer.gd`
- 阵营克制计算、双卡组合策略、防守反击思维、三回合预测、卡牌记忆库
- 难度选择：普通 / 大师（主菜单可切换）
- 文档：`docs/大师AI设计方案.md`

### Bug 修复

**无牌强制结算失效**
- 问题：双方手牌+牌库耗尽时未触发游戏结束
- 修复：新增 `_check_no_cards()` 统一函数，覆盖 5 个关键流程点

**克制关系失效**
- 问题：辅助卡 `type=主` 但 `faction=辅` 导致主卡识别错误
- 修复：主卡识别优先选 `faction` 为 法/射/坦 的卡

**AI 不出牌**
- 问题：无合法组合时返回空数组，AI 跳过回合
- 修复：新增兜底逻辑强制出最小 cost 卡

**伤害计算错误**
- 问题：倍率错误应用于总伤害
- 修复：倍率仅作用于自身卡牌攻击力，辅助卡攻击独立计算

### 涉及文件

- `scripts/ai_system.gd`、`scripts/ai_strategy.gd`、`scripts/ai_predictor.gd`、`scripts/ai_combo_memory.gd`、`scripts/ai_card_analyzer.gd`
- `scripts/game_board.gd`、`scripts/effect_system.gd`、`scripts/game_config.gd`
- `scripts/version_manager.gd` → 1.3.0
- `scenes/main_menu.tscn`、`project.godot`、`export_presets.cfg`（难度选择）
- `docs/大师AI设计方案.md`、`docs/战斗结算机制.md`

---

## 2026-08-15 v1.1.0 调试信息清理 + 中文本地化 + 工作规范

### 问题
1. 正式打包版游戏中仍显示调试信息弹幕（如 `[DEBUG] cost=2 mana=5`）
2. 阶段显示为技术术语（如 `Phase: PLAY_P1`）而非中文描述
3. 联机状态显示技术角色信息（如 "P1（Host）"）
4. print() 语句在正式版中仍输出到控制台

### 根因
1. 旧版 APK 包含已删除的调试代码
2. TimerLabel 使用英文 phase 常量而非中文映射
3. 联机标签直接显示角色技术信息
4. print() 语句未加条件编译，debug/release 版本都输出

### 修复内容

**export_presets.cfg**
- `debug/export_console_wrapper=1` → `0`，移除 Windows 控制台窗口

**game_board.gd**
- 清理技术化 Toast 消息（移除"六阶段结算引擎已加载"等）
- 添加中文 phase 映射（你的回合/对手回合/结算中等）
- 清理联机标签（"联机对战 - 你是 P1（Host）" → "🌐 联机对战"）

**多脚本 print() 条件编译**
- main.gd, version_manager.gd, card_loader.gd
- global_net.gd, player_profile.gd
- game_client_net.gd, game_host_net.gd
- 所有 print() 添加 `if OS.has_feature("debug")` 条件

**skills/ 工作规范**
- 新增 skill1.md — 通用工作流
- 新增 skill2.md — 新工作质量保障
- 新增 skill3.md — 代码风格参考

---

## 2026-05-19 音频系统修复

### 问题
Android APK 导出后，对局游戏中世界音乐无法播放。

### 根因
1. `_play_stream()` 函数被错误添加了 `await`（非 async 函数），导致所有音乐播放均失败
2. Neon Mixtape Tour 音频文件名包含特殊字符 `–`（U+2013 en-dash），Android 路径解析异常

### 修复内容

**music_manager.gd**
- 移除 `_play_stream()` 中错误的 `await` 调用，恢复同步播放
- Neon Mixtape Tour 硬编码路径中 `–` 替换为 `-`（hyphen）
- 新增 `_notification()` 处理应用焦点变化，切后台返回后自动恢复音乐播放

**音频文件重命名**（5 个文件）
- `74. Neon Mixtape Tour – Funkasmic.mp3` → `74. Neon Mixtape Tour - Funkasmic.mp3`
- `76. Neon Mixtape Tour – Sincerely the Theme.mp3` → `76. Neon Mixtape Tour - Sincerely the Theme.mp3`
- `77. Neon Mixtape Tour – Slam.mp3` → `77. Neon Mixtape Tour - Slam.mp3`
- `78. Neon Mixtape Tour – Soda Jerk.mp3` → `78. Neon Mixtape Tour - Soda Jerk.mp3`
- `pre_worlds/76. Neon Mixtape Tour – Sincerely the Theme.mp3` → 同理

**game_board.gd**
- `_start_game_music()` 增加联机模式下 `GlobalNet.world` 的优先读取

**清理**
- 移除所有调试日志、临时诊断脚本和文档
