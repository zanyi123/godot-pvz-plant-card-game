## mailbox_scene.gd - 邮箱系统（玩前须知）
## 模拟收件箱，点击信件查看详细内容
## 已读/未读状态保存到 user://mailbox_read.json
extends Control

signal mailbox_closed()

var font: FontFile
var letters: Array = []
var read_ids: Array = []
var overlay: ColorRect
var panel: Panel
var list_vbox: VBoxContainer
var list_scroll: ScrollContainer
var content_area: RichTextLabel
var content_title: Label
var current_letter_idx: int = -1
var back_btn: Button
var back_list_btn: Button

func _ready() -> void:
	font = load("res://assets/fonts/simhei.ttf")
	_init_letters()
	_load_read_status()
	_build_ui()

func _init_letters() -> void:
	letters = [
		{
			"id": "copyright",
			"sender": "系统管理员",
			"subject": "📜 版权声明与使用限制",
			"body": "【版权声明】\n\n本游戏为《Plants vs. Zombies》（植物大战僵尸）同人作品。\n\n【版权归属】\n\n  · 《Plants vs. Zombies》及其所有角色、美术素材、音乐等知识产权归 Electronic Arts (EA) 和 PopCap Games 所有。\n  · 本项目的代码为本人的学习实践成果，但使用的 PVZ2 素材版权归原作者所有。\n\n【项目性质】\n\n  · 本项目为非官方、非商业的个人学习项目。\n  · 仅用于编程学习和技术研究，绝不用于商业用途。\n\n【使用限制】\n\n  · 禁止二次传播：请勿将本游戏上传至网络或分享给他人。\n  · 禁止商业使用：严禁用于任何形式的盈利或商业活动。\n  · 仅限个人学习：仅供本人学习使用，请勿扩散。\n\n【免责声明】\n\n  · 如因使用本游戏产生任何版权纠纷，本人不承担任何法律责任。\n\n【侵权处理】\n\n  如版权方（EA/PopCap）认为本项目侵犯您的权益，请联系作者。\n  本人将在收到通知后立即删除相关内容。\n\n继续游戏即表示您已阅读并同意以上条款。",
		},
		{
			"id": "changelog",
			"sender": "开发组",
			"subject": "📢 正式服版本更新说明",
			"body": "【v1.2 更新内容】\n\n新增功能：\n  · 新增22位新伙伴植物卡牌进入家族！\n  · 高级坦克：高坚果参与对战，神力钢地刺护你周全\n  · 二人对战联机模式已上线，邀请身边的朋友一起体验！\n\n修复问题：\n  · 修复卡牌结算回合部分问题\n  · 修复联机模式下血条显示不同步\n  · 修复精力点阵和 Buff 栏视角翻转\n\n感谢您的支持与反馈！",
		},
		{
			"id": "welcome",
			"sender": "系统管理员",
			"subject": "📬 欢迎来到植物卡牌对战！",
			"body": "亲爱的训练师，欢迎来到植物温室花房！\n\n这里是一片充满魔力的花园，各种植物在这里生长、战斗、进化。\n\n本手册将通过一系列信件向你介绍游戏的所有机制。\n\n请逐一阅读，了解如何成为一名优秀的植物训练师！\n\n——温室花房管理处"
		},
		{
			"id": "basics",
			"sender": "疯狂戴夫",
			"subject": "🌱 基础规则：回合与精力",
			"body": "嘿，伙计！我是疯狂戴夫！让我告诉你基础规则！\n\n【回合流程】\n每回合分为以下阶段：\n1. 出牌阶段（PLAY）：双方各出自己的牌\n2. 结算阶段（RESOLVE）：双方出牌互相结算伤害\n3. 回合结束（ROUND_END）：补牌，进入下一回合\n\n【精力系统】\n- 初始精力上限：5点\n- 每回合开始时精力自动补满\n- 每张卡牌都有费用，出牌消耗对应精力\n- 精力上限可以通过向日葵类卡牌（MANA效果）提升\n\n【胜利条件】\n先将对手HP降至0的玩家获胜！\n\n——疯狂戴夫"
		},
		{
			"id": "factions",
			"sender": "植物学教授",
			"subject": "⚔️ 阵营系统：四大阵营",
			"body": "训练师，你需要了解植物的阵营！\n\n54张植物卡牌分为4大阵营：\n\n【法师阵营（紫）】\n擅长直接伤害和控制效果。代表植物：寒冰射手、火焰豌豆。\n克制关系：法师 → 射手\n\n【射手阵营（蓝）】\n擅长持续输出和远程攻击。代表植物：豌豆射手、双发射手。\n克制关系：射手 → 坦克\n\n【坦克阵营（棕）】\n擅长防御和嘲讽，保护其他植物。代表植物：坚果墙、高坚果。\n克制关系：坦克 → 法师\n\n【辅助阵营（金）】\n擅长治疗、增益和特殊效果。代表植物：向日葵、大嘴花。\n\n【克制规则】\n法师克射手，射手克坦克，坦克克法师，形成三角循环。辅助不参与克制。\n\n——植物学教授"
		},
		{
			"id": "play_rules",
			"sender": "裁判机器人",
			"subject": "🃏 出牌规则详解",
			"body": "训练师，以下是详细出牌规则：\n\n【基本规则】\n- 每回合最多出2张牌\n- 出牌消耗精力，精力不足无法出牌\n\n【组合规则】\n每回合允许的出牌组合：\n1. 出1张任意阵营卡牌\n2. 出1张主阵营（法/射/坦）+ 1张辅助\n\n【限制规则】\n- 不能同时出2张主阵营牌（如：法师+射手）\n- 不能同时出2张辅助牌\n- 标有「限制」标记的卡牌只能单独出牌\n\n【出牌操作】\n1. 左键点击手牌 → 卡牌进入预出区\n2. 右键点击预出区的牌 → 撤回到手牌\n3. 点击牌库区域或按空格 → 结束出牌\n\n——裁判机器人"
		},
		{
			"id": "effects",
			"sender": "炼金术士",
			"subject": "✨ 效果系统：卡牌特效",
			"body": "训练师，卡牌的效果是取胜的关键！\n\n【伤害类效果】\n- DAMAGE：直接对目标造成伤害\n- PIERCE：穿透伤害，无视部分防御\n\n【防御类效果】\n- HEAL：恢复自身HP\n- SHIELD：获得护盾，吸收伤害\n- MANA：提升精力上限\n\n【控制类效果】\n- SILENCE：沉默对手，下回合无法出牌\n- STUN：眩晕目标，跳过其回合\n- FREEZE：冻结目标，延迟其行动\n\n【特殊效果】\n- DRAW：抽额外卡牌\n- BUFF：增强己方属性\n- DEBUFF：削弱对方属性\n- REMEDY：濒死补救，当HP归零时可自救\n\n每张卡牌的效果在卡牌详情中可以看到。\n\n——炼金术士"
		},
		{
			"id": "remedy",
			"sender": "急救向日葵",
			"subject": "💔 濒死补救机制",
			"body": "训练师，当你快要倒下时不要放弃！\n\n【濒死状态】\n当你的HP降至0以下时，不会立即死亡，而是进入濒死状态。\n\n【补救规则】\n1. 进入濒死状态后，你获得一次出牌机会\n2. 只能打出带有「治疗/护盾」效果的卡牌\n3. 如果补救后HP恢复到1以上，你将继续战斗\n4. 如果无法补救（没有合适的牌），则判定失败\n\n【补救卡牌】\n以下类型的卡牌可以用于补救：\n- 治疗类（HEAL）\n- 护盾类（SHIELD）\n- 其他标注「可用于补救」的卡牌\n\n——急救向日葵"
		},
		{
			"id": "strategy",
			"sender": "传奇训练师",
			"subject": "🏆 进阶策略与技巧",
			"body": "训练师，掌握这些策略能让你更强！\n\n【新手技巧】\n1. 合理分配精力，不要一次全部用完\n2. 保留辅助牌用于关键时刻的治疗\n3. 利用克制关系选择出牌顺序\n\n【进阶策略】\n1. 牌组管理：注意牌库剩余数量\n2. 心理博弈：观察对手出牌习惯\n3. 资源交换：用低费牌换掉对手的高费牌\n\n【常见组合】\n1. 坦克+辅助：防守反击\n2. 法师+辅助：爆发输出\n3. 射手连击：持续压制\n\n【注意事项】\n- 注意对手的精力使用情况\n- 关键时刻留一张补救牌\n- 不要忽视辅助牌的价值\n\n祝你在对战中取得胜利！\n\n——传奇训练师"
		},
		{
			"id": "online",
			"sender": "网络管理员",
			"subject": "🌐 联机对战指南",
			"body": "训练师，想要和其他玩家对战吗？\n\n【联机方式】\n1. 点击「二人对战」进入联机大厅\n2. 同一局域网下会自动发现其他玩家\n3. 也可以手动输入IP地址连接\n\n【同电脑双开】\n1. 打开两个Godot编辑器实例\n2. 都点击「二人对战」进入大厅\n3. 一方在IP输入框输入 127.0.0.1 并点击连接\n4. 另一方也会自动连接\n\n【联机规则】\n- Host（先连接的一方）选择先手\n- Client 等待 Host 选择后开始游戏\n- 双方操作体验完全一致\n\n【注意事项】\n- 确保网络连接稳定\n- 如果连接超时，请重新进入大厅\n\n——网络管理员"
		},
	]

func _load_read_status() -> void:
	var path = "user://mailbox_read.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				read_ids = json.get_data()
			file.close()

func _save_read_status() -> void:
	var path = "user://mailbox_read.json"
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(read_ids, "\t"))
		file.close()

func _build_ui() -> void:
	overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	
	var pw = 620
	var ph = 520
	var px = (1024 - pw) / 2
	var py = (768 - ph) / 2
	
	panel = Panel.new()
	panel.position = Vector2(px, py)
	panel.size = Vector2(pw, ph)
	_set_panel_style(panel, Color(30.0/255, 42.0/255, 58.0/255), Color(70.0/255, 90.0/255, 120.0/255))
	overlay.add_child(panel)
	
	_show_list_view()

func _show_list_view() -> void:
	_clear_panel_children()
	var pw = panel.size.x
	var ph = panel.size.y
	
	# 标题
	var title = Label.new()
	title.position = Vector2(0, 15)
	title.size = Vector2(pw, 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, 240.0/255, 140.0/255))
	
	var unread = 0
	for l in letters:
		if not l["id"] in read_ids:
			unread += 1
	title.text = "📬 玩前须知（%d封未读）" % unread
	panel.add_child(title)
	
	var sep = HSeparator.new()
	sep.position = Vector2(20, 55)
	sep.size = Vector2(pw - 40, 2)
	panel.add_child(sep)
	
	# 信件列表
	list_scroll = ScrollContainer.new()
	list_scroll.position = Vector2(15, 62)
	list_scroll.size = Vector2(pw - 30, ph - 130)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(list_scroll)
	
	list_vbox = VBoxContainer.new()
	list_vbox.custom_minimum_size = Vector2(pw - 50, 0)
	list_vbox.add_theme_constant_override("separation", 4)
	list_scroll.add_child(list_vbox)
	
	for i in range(letters.size()):
		var l = letters[i]
		var is_read = l["id"] in read_ids
		var row = _create_letter_row(l, i, is_read)
		list_vbox.add_child(row)
	
	# 返回按钮
	back_btn = Button.new()
	back_btn.position = Vector2(pw / 2 - 80, ph - 55)
	back_btn.size = Vector2(160, 40)
	back_btn.text = "返回菜单"
	back_btn.add_theme_font_override("font", font)
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.pressed.connect(_on_back)
	panel.add_child(back_btn)

func _show_letter_view(idx: int) -> void:
	current_letter_idx = idx
	var l = letters[idx]
	
	# 标记已读
	if not l["id"] in read_ids:
		read_ids.append(l["id"])
		_save_read_status()
	
	_clear_panel_children()
	var pw = panel.size.x
	var ph = panel.size.y
	
	# 发件人
	var sender = Label.new()
	sender.position = Vector2(20, 15)
	sender.size = Vector2(pw - 40, 24)
	sender.add_theme_font_override("font", font)
	sender.add_theme_font_size_override("font_size", 14)
	sender.add_theme_color_override("font_color", Color(160.0/255, 180.0/255, 200.0/255))
	sender.text = "发件人: %s" % l["sender"]
	panel.add_child(sender)
	
	# 主题
	var subject = Label.new()
	subject.position = Vector2(20, 40)
	subject.size = Vector2(pw - 40, 30)
	subject.add_theme_font_override("font", font)
	subject.add_theme_font_size_override("font_size", 20)
	subject.add_theme_color_override("font_color", Color(1, 240.0/255, 140.0/255))
	subject.text = l["subject"]
	panel.add_child(subject)
	
	var sep = HSeparator.new()
	sep.position = Vector2(20, 74)
	sep.size = Vector2(pw - 40, 2)
	panel.add_child(sep)
	
	# 正文
	content_area = RichTextLabel.new()
	content_area.position = Vector2(20, 82)
	content_area.size = Vector2(pw - 40, ph - 145)
	content_area.bbcode_enabled = false
	content_area.add_theme_font_override("normal_font", font)
	content_area.add_theme_font_size_override("normal_font_size", 16)
	content_area.add_theme_color_override("default_color", Color(230.0/255, 235.0/255, 245.0/255))
	content_area.text = l["body"]
	panel.add_child(content_area)
	
	# 返回列表按钮
	back_list_btn = Button.new()
	back_list_btn.position = Vector2(pw / 2 - 80, ph - 55)
	back_list_btn.size = Vector2(160, 40)
	back_list_btn.text = "返回信箱"
	back_list_btn.add_theme_font_override("font", font)
	back_list_btn.add_theme_font_size_override("font_size", 16)
	back_list_btn.pressed.connect(_show_list_view)
	panel.add_child(back_list_btn)

func _create_letter_row(l: Dictionary, idx: int, is_read: bool) -> Panel:
	var row = Panel.new()
	row.custom_minimum_size = Vector2(0, 52)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(38.0/255, 52.0/255, 72.0/255) if is_read else Color(50.0/255, 68.0/255, 95.0/255)
	style.set_corner_radius_all(4)
	style.set_border_width_all(1)
	style.border_color = Color(70.0/255, 90.0/255, 120.0/255)
	row.add_theme_stylebox_override("panel", style)
	
	# 未读标记
	var badge = Label.new()
	badge.position = Vector2(8, 14)
	badge.size = Vector2(24, 24)
	badge.add_theme_font_size_override("font_size", 18)
	badge.text = "🔵" if not is_read else "  "
	row.add_child(badge)
	
	# 主题
	var subj = Label.new()
	subj.position = Vector2(36, 6)
	subj.size = Vector2(440, 24)
	subj.add_theme_font_override("font", font)
	subj.add_theme_font_size_override("font_size", 16)
	subj.add_theme_color_override("font_color", Color(1, 1, 1) if not is_read else Color(180.0/255, 190.0/255, 200.0/255))
	subj.text = l["subject"]
	row.add_child(subj)
	
	# 发件人
	var sender = Label.new()
	sender.position = Vector2(36, 28)
	sender.size = Vector2(300, 18)
	sender.add_theme_font_override("font", font)
	sender.add_theme_font_size_override("font_size", 12)
	sender.add_theme_color_override("font_color", Color(130.0/255, 145.0/255, 165.0/255))
	sender.text = "来自: %s" % l["sender"]
	row.add_child(sender)
	
	# 点击信号
	row.gui_input.connect(_on_row_clicked.bind(idx))
	
	return row

func _on_row_clicked(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_letter_view(idx)

func _clear_panel_children() -> void:
	for child in panel.get_children():
		child.queue_free()

func _set_panel_style(p: Panel, bg_c: Color, border_c: Color) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_c
	style.border_color = border_c
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	p.add_theme_stylebox_override("panel", style)

func _on_back() -> void:
	mailbox_closed.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_back()
