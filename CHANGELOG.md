# 更新日志

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
