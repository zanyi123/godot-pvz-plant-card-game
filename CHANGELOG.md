# 更新日志

## 2026-08-15 调试信息清理 + 中文本地化 + 工作规范

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
