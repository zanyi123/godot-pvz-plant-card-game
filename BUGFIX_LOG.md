# 🐛 Bug 修复记录

## 快速记录模板

每次修复 bug 后，在这个文件末尾添加一条记录。

---

## 修复历史

### [日期] - 版本号 - 标题
**描述：** 简要描述 bug 现象
**原因：** 找到的根本原因
**修复：** 改了哪些文件/哪行代码
**测试：** 如何验证已修复

---

### 2026-05-23 - v1.0.1 - 血条颜色不更新
**描述：** P2 受伤后血条仍显示绿色，不会变成橙/红色
**原因：** `_refresh_hp_bar()` 没有调用
**修复：** 在 `_apply_damage()` 后添加 `_refresh_hp_bar()`
**测试：** P2 受伤到 4 点血，血条变成橙色 ✅

---

### 2026-05-23 - v1.0.1 - 联机状态同步三个问题（第一轮）
**描述：**
1. 二人对战时，Host/Client 显示的阶段提示不一致（一方"等待对手出牌"，另一方"AI在思考"）
2. 卡牌动态变化时，对方视角看自己预出牌时，手牌数量没有动态减少
3. 一方出牌不能观察到前两回合的已出卡牌（历史显示不正确）

**原因：**
1. Client 模式在出牌中时（`p1_pending.size() > 0`），只更新 phase 和 HP，不更新 phase_hint
2. Client 模式下 `_refresh_p1_hand()` 渲染 `p2_hand` 时没有过滤掉已在 `p1_pending` 中的牌
3. `_send_state_to_client()` 根本没有发送 `history` 字段，Client 端 `history` 数组始终为空

**修复（文件：scripts/game_board.gd）：**
1. 在 `_process()` Client 分支中，即使出牌中也要根据 rphase 更新 phase_hint 和 deck_hint
2. 在 `_refresh_p1_hand()` Client 模式中添加过滤：`if card in p1_pending: continue`
3. 新增 `_serialize_history()` 辅助函数；`_send_state_to_client()` 中添加 `"history": _serialize_history()` 字段；`_render_remote_state()` 中从 `remote_state["history"]` 反序列化

**测试：** 双开联机对战 ✅

---

### 2026-05-23 - v1.0.1 - 音频系统修复（Android APK）
**描述：** Android APK 导出后，对局游戏中世界音乐无法播放
**原因：**
1. `_play_stream()` 函数被错误添加了 `await`（非 async 函数），导致所有音乐播放均失败
2. Neon Mixtape Tour 音频文件名包含特殊字符 `–`（U+2013 en-dash），Android 路径解析异常

**修复（文件：scripts/music_manager.gd）：**
1. 移除 `_play_stream()` 中错误的 `await` 调用，恢复同步播放
2. Neon Mixtape Tour 硬编码路径中 `–` 替换为 `-`（hyphen）
3. 新增 `_notification()` 处理应用焦点变化，切后台返回后自动恢复音乐播放
4. 重命名 5 个音频文件（去除 en-dash）
5. `game_board.gd` 中 `_start_game_music()` 增加联机模式下 `GlobalNet.world` 的优先读取

**测试：** Android 安装后各世界音乐正常播放 ✅

---

### 2026-05-23 - v1.0.2 - 冰龙草沉默联机不生效
**描述：** 冰龙草（effect_id=SILENCE）的沉默技能在联机模式下无法生效，对手（Client）仍能正常出牌
**原因：** `_send_state_to_client()` 中 `"temp": {}` 始终为空字典，Client 收不到 `P2_silenced` 等状态标记。Client 本地 `game_state.temp` 永远为空，沉默检查 `cli_temp.get("P2_silenced", false)` 始终返回 false
**修复（文件：scripts/game_board.gd）：**
1. 第 597 行：`"temp": {}` → `"temp": game_state.get("temp", {})`，将真实的 temp 状态同步给 Client
2. 第 834 行：`_render_remote_state()` 中添加 `game_state["temp"] = remote_state.get("temp", {})`，Client 反序列化 temp
**测试：** Host 出冰龙草 → Client 被沉默 → Client 点击手牌提示"您被沉默，无法出牌！" ✅

---

### 2026-05-23 - v1.0.2 - Host 等待 Client 出牌时显示"AI正在思考"
**描述：** 联机模式下 Host 等待 Client 出牌时，阶段提示显示"AI 正在思考..."，应显示"等待对手出牌..."
**原因：** `_change_phase("PLAY_P2")` 和 `"REMEDY_AI"` 分支没有区分联机 Host 模式和本地 AI 模式
**修复（文件：scripts/game_board.gd）：**
1. PLAY_P2 分支：增加 `elif is_online and network_role == "host"` → 显示 `"🌐 等待对手出牌..."`
2. REMEDY_AI 分支：增加 `if is_online and network_role == "host"` → 显示 `"🌐 等待对手补救..."`
**测试：** 联机 Host 等待 Client 出牌时阶段提示正确 ✅

---

### 2026-05-23 - v1.0.2 - Host 看不到 Client 预出牌精力实时变化
**描述：** Client 预出牌时精力黄点在 Host 方不可见实时变化（可用于判断出牌点数），而 Host 预出牌时 Client 能看到精力变化。双方体验不对称
**原因：** Client 预出牌只在本地管理 `p1_pending` 和 `current_mana`，出牌操作直到 `finish_turn` 才批量发送给 Host，Host 无法实时感知 Client 精力消耗
**修复（文件：scripts/game_board.gd）：**
1. 新增 `_send_client_mana_update()` 函数：Client 出牌/撤回时通过 `mana_update` 消息实时发送 `{current_mana, max_mana}`
2. `_client_play_card()` 末尾调用 `_send_client_mana_update()`
3. `_undo_client_pending()` 末尾调用 `_send_client_mana_update()`
4. Host `_poll_host_actions()` 新增 `mana_update` 分支：接收并更新 `game_state["players"]["P2"]` 的精力值，调用 `_refresh_mana_dots($P2ManaDots, ...)` 实时刷新
**测试：** 联机 Client 出牌 → Host 端 P2 精力黄点实时减少；Client 撤回 → Host 端恢复 ✅

---

### 2026-05-23 - v1.0.2 - 导出脚本无法运行（换行符问题）
**描述：** `export_all.bat` 和 `release.bat` 双击后闪退或报错无法运行
**原因：** 文件换行符为 Unix LF (`0x0A`)，Windows `cmd.exe` 要求 `.bat` 文件必须用 CRLF (`0x0D 0x0A`)；此外 `--path` 参数错误指向 `project.godot` 文件而非项目目录
**修复：**
1. 两个 `.bat` 文件转换为 CRLF 换行符
2. `export_all.bat`：`set PROJECT` 改为指向项目目录而非 `project.godot` 文件
3. `release.bat`：`set PROJECT` 改为 `%PROJECT_DIR%.`
4. `export_all.bat`：Android 导出改用 `--export-debug`（使用 debug.keystore 签名，无需 release 签名）
5. `export_presets.cfg`：Android 预设添加 debug keystore 配置
**测试：** 双击 `export_all.bat` 成功导出 Windows exe + Android APK ✅

---

### 2026-05-24 - v1.0.3 - 导出版卡牌资源无法加载（Unicode幽灵字符）
**描述：** 导出的 exe 运行后人机模式卡牌资源全部无法加载，游戏内容为旧版本
**原因：** `game_board.gd` 第944行末尾有幽灵 Unicode 字符 `─`（U+2500），导致 Godot headless 导出时编译该脚本失败（`SCRIPT ERROR: Parse Error: Invalid character "─"`），但导出流程继续生成了不完整的 pck 包
**修复（文件：scripts/game_board.gd）：**
1. 第944行 `)─` → `)`，删除幽灵字符
2. 删除 `.godot/exported/` 导出缓存
3. 清理 `PVZ卡牌游戏_发布版/` 中残留的旧版 exe+pck
4. `export_all.bat` 添加导出前自动清理旧文件逻辑
**测试：** 重新导出后双击 exe 卡牌正常加载，0 编译错误 ✅

---

### 2026-05-24 - v1.0.3 - AI 出牌无精力校验（毁灭菇开局可被打出）
**描述：** 毁灭菇（cost=6）在开局精力只有 5 时 AI 仍然能打出，玩家出牌有精力校验但 AI 没有
**原因：** `_ai_play()` 函数直接遍历所有手牌选攻击力最大的出，完全没有检查 `card.cost <= current_mana`。而玩家出牌 `_on_card_clicked()` 有 `current_mana < card_cost` 校验
**修复（文件：scripts/game_board.gd）：**
1. `_ai_play()` 新增精力过滤：先筛选 `playable` 数组（`card.cost <= current_mana`），再从中选攻击力最大的
2. 删除调试用 `_show_toast("[DEBUG] cost=%d mana=%d")`
**测试：** 开局 max_mana=5，AI 无法打出 cost=6 的毁灭菇 ✅

---

### 2026-05-24 - v1.0.3 - 双方同时濒死补救 + 牌打完判胜负
**描述：**
1. 结算后双方 HP 同时 ≤ 0 时，只补救先检测到的一方，另一方空血进入下一回合
2. 双方卡牌都打完后不判定胜负，游戏无法结束

**原因：**
1. 补救检测是 if/elif 顺序判断，P2 濒死进入 REMEDY_AI 后直接到下一回合，P1 的补救机会被跳过
2. `_advance_to_play_phase()` 没有检查牌库+手牌为空的终止条件

**修复（文件：scripts/game_board.gd）：**
1. 新增 `_remedy_queue` 补救队列变量（`["P2", "P1"]` 或 `["P1"]` 或 `["P2"]`）
2. 结算后同时检查双方 HP，将濒死者加入队列
3. `_apply_remedy()`（P1 补救）完成后：从队列移除 P1，检查是否还有 P2 待补救
4. `_ai_remedy()`（P2 补救）完成后：从队列移除 P2，检查是否还有 P1 待补救
5. `_host_p2_remedy()`（联机 P2 补救）同理处理队列
6. `_advance_to_play_phase()` 新增牌耗尽判定：任一方手牌+牌库为空 → 按血量判定 P1赢/P2赢/DRAW平局
7. `_show_game_over()` 新增 DRAW 平局显示处理

**测试：** 导出 0 错误 ✅

---

## 待修复列表

（暂无）
