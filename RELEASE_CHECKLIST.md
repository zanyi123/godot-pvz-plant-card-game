# 📦 发版清单模板

每次发版按此清单操作，确保 PC 和手机同步。

---

## 发版前检查

- [ ] 修改 `scripts/version_manager.gd` 中的版本号
  - `VERSION_MAJOR` / `VERSION_MINOR` / `VERSION_PATCH`
- [ ] 修改 `export_presets.cfg` 中 Android 的 `version/code` 和 `version/name`
- [ ] 在 Godot 编辑器中测试完整流程（注册→菜单→人机→联机）
- [ ] 更新 `CHANGELOG.md` 记录本次改动

## 导出步骤

### 方法一：一键导出（推荐）
```
双击 export_all.bat
```

### 方法二：Godot 编辑器手动导出
1. 项目 → 导出 → Windows Desktop → 导出项目
2. 项目 → 导出 → Android → 导出项目

## 导出后

### Windows 发布
- [ ] 检查 `PVZ卡牌游戏_发布版/` 文件夹中有 `.exe` + `.pck`
- [ ] 双击 `.exe` 确认可正常启动

### Android 发布
- [ ] 检查 `PVZ_Plant_Card_Game.apk` 已生成
- [ ] 传到手机安装测试

## 文件分发

| 平台 | 需要的文件 | 大小(约) |
|------|-----------|---------|
| Windows | `PVZ卡牌游戏_发布版/` 整个文件夹 | ~262 MB |
| Android | `PVZ_Plant_Card_Game.apk` | ~200 MB |

---

## 版本历史

### v1.0.0 (2026-05-18)
- 初始发布版本
- 完整卡牌对战系统
- 局域网联机
- 76张卡牌 / 6阶段效果系统
- Windows + Android 双平台
