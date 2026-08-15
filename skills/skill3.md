# skill3 — 参考项目代码风格（不修改其他项目）

> 适用对象：所有 AI 工作助手
> 适用场景：在本项目下进行任何代码开发时，参考项目内已有代码的风格
> 放置位置：skills/skill3.md

---

## 一、核心原则

```
参考 ≠ 复制      风格一致 ≠ 行为绑定
看现有代码可以    改现有代码绝对禁止（除非明确要求）
```

---

## 二、规则详解

### 规则 1：识别参考对象

按以下顺序识别"风格基准"：

1. **同一脚本类别**的脚本优先（如写 UI 脚本就看其他 UI 脚本）
2. **同功能模块**的脚本次之（如写卡牌效果就看 effect_system.gd）
3. **同代码作者**的最近文件再次
4. 在动手前**必须**用 `Read` 至少看 1–3 个相关脚本的代码风格

### 规则 2：参考的具体维度

参考其他脚本时，**至少**对齐以下 8 个维度：

| # | 维度 | 例子 |
|---|------|------|
| 1 | 命名风格 | 变量小写+下划线 (`_player_hp`)，函数小写+下划线 (`_on_card_clicked`)，常量全大写 (`MAX_HP`) |
| 2 | 缩进风格 | Tab 缩进，4 空格对齐 |
| 3 | 信号定义 | `signal card_played(card_data: CardData)` |
| 4 | 类型标注 | `var hp: int = 10`，`func _process(delta: float) -> void` |
| 5 | 注释风格 | 单行注释 `# 说明`，函数头注释 `## 函数说明` |
| 6 | 错误处理 | `if err != OK: push_error("错误信息")` |
| 7 | 资源加载 | `load("res://path/to/resource")` 预加载，`preload()` 用于常量 |
| 8 | 调试控制 | `if OS.has_feature("debug"): print(...)` 条件编译 |

### 规则 3：当前项目的风格基线

#### 基线 A：GDScript 脚本（参考 scripts/ 下各脚本）
- 框架：Godot 4.x GDScript
- 编码：UTF-8，LF 换行
- 命名：`_variable` 私有变量，`variable` 公有变量，`_function()` 私有函数
- 缩进：Tab 缩进
- 信号：`signal event_name(params)`
- 导出：`@export var variable: type`
- 调试：`if OS.has_feature("debug"): print(...)` 
- 节点访问：`$NodePath` 或 `get_node("NodePath")`

#### 基线 B：场景文件（参考 scenes/ 下各 .tscn 文件）
- 场景结构：根节点 + 子节点，节点按功能分组
- 资源路径：`res://assets/` 前缀
- 脚本绑定：`[ext_resource type="Script" path="res://scripts/xxx.gd"]`

#### 基线 C：数据文件（参考 data/ 下各 .json 文件）
- 卡牌数据：`cards.json`，字段包含 `id`, `name`, `faction`, `cost`, `atk`, `effect_id`
- 存档数据：`default_save_data.json`
- 设置数据：`default_settings.json`

### 规则 4：硬性禁止

- ❌ **禁止**修改、删除项目中其他脚本的代码（除非用户明确要求）
- ❌ **禁止**把其他脚本里的代码"逐字复制"到新脚本而不做适配
- ❌ **禁止**用与基线完全冲突的方案（如不用 GDScript 而用 C#，除非用户要求）
- ❌ **禁止**因为"别的引擎是这样"就照搬明显错误/过时的写法

### 规则 5：风格冲突时的处理

如本项目需求与基线风格冲突，按以下优先级处理：

```
项目自身需求  >  skill3 参考基线  >  AI 默认风格
```

- 冲突时**必须**向用户报告："基线项目是 X 风格，但您的需求是 Y 风格，建议采用 Y，是否确认？"
- 确认后按 Y 写，并在注释里说明"本项目因 XX 原因采用 Y 风格"

---

## 三、与其他 skill 的关系

- skill3 是 skill1 第 2 步"生成方案"和第 4 步"严格执行"过程中的**横切关注点**
- skill3 的"识别基线脚本"应在 skill2 阶段 A 提问时**一并确认**
- skill3 的"自检 8 维度"应纳入 skill2 阶段 B 的自检清单

---

## 四、项目结构速查表

| 目录 | 内容 | 说明 |
|------|------|------|
| `assets/cards/` | 卡牌图标 | 按阵营命名 (fa_, fu_, sh_, tk_) |
| `assets/images/` | 游戏图片 | 背景、边框、植物图片 |
| `assets/music/` | 背景音乐 | 按场景分类 (menu/, worlds/) |
| `assets/sfx/` | 音效 | 按钮、卡牌音效 |
| `data/` | 数据文件 | JSON 格式卡牌、存档、设置 |
| `scenes/` | 场景文件 | .tscn 格式场景 |
| `scripts/` | 游戏脚本 | .gd 格式 GDScript |
| `scripts/network/` | 联机脚本 | TCP/UDP 联机通信 |

---

## 五、反例（禁止行为）

- ❌ AI 写新脚本时变量命名用驼峰式（`playerHp`），而项目统一用下划线（`player_hp`）
- ❌ AI 觉得"项目的 print 风格太啰嗦"，把所有调试语句都删了
- ❌ AI 在项目里引入 C# 脚本，理由是"自己更熟悉 C#"
- ❌ AI 看到项目用 `$NodePath` 访问节点，却改用 `get_node_or_null()` 而不考虑项目一致性
- ❌ AI 修改其他功能脚本给自己"统一风格"

---

## 六、版本

- v1.0 — 初始版本
- v1.1 — 适配 Godot 植物大战僵尸卡牌游戏项目