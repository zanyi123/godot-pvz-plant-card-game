## loading_scene.gd - 加载界面
## 流程完全还原原版 PVZ：
## 1. 播放 Opening Splash 音乐
## 2. 显示标题 + 制作组致谢
## 3. 进度条从 0% 加载到 100%
## 4. 加载完成后出现 "点击开始游戏" 按钮
## 5. 点击后进入主菜单
extends Control

var font: FontFile
var font_small: FontFile

# 节点
var bg: TextureRect
var bg_color: ColorRect
var fade_overlay: ColorRect

# 标题区
var title_label: Label
var sub_label: Label

# 致谢区
var credit_panel: Panel
var credit_lines: Array = []

# 进度条
var progress_bg: ColorRect
var progress_fill: ColorRect
var progress_label: Label
var tip_label: Label

# 开始按钮
var start_btn: Button

# 动画状态
var phase: int = 0  # 0=淡入 1=致谢展示 2=进度条 3=等待点击 4=淡出
var timer: float = 0.0
var progress: float = 0.0
var load_duration: float = 2.5  # 进度条持续秒数
var tips: Array = []

func _ready() -> void:
	font = load("res://assets/fonts/simhei.ttf")
	
	tips = [
		"💡 提示：法师克制射手，射手克制坦克，坦克克制法师",
		"💡 提示：每回合最多出2张牌",
		"💡 揓示：注意保留精力用于关键时刻",
		"💡 提示：濒死时可以打出治疗牌自救",
		"💡 提示：辅助牌可以和任意主阵营牌搭配出牌",
	]
	
	_build_ui()
	_play_music()

func _build_ui() -> void:
	# 黑色背景
	bg_color = ColorRect.new()
	bg_color.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_color.color = Color(0.08, 0.08, 0.12)
	add_child(bg_color)
	
	# 花园背景（半透明）
	var garden_tex = load("res://assets/images/bg/bg_garden.png")
	if garden_tex:
		bg = TextureRect.new()
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.texture = garden_tex
		bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bg.modulate = Color(1, 1, 1, 0.3)
		add_child(bg)
	
	# ===== 标题区（上方）=====
	title_label = Label.new()
	title_label.position = Vector2(0, 100)
	title_label.size = Vector2(1024, 50)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", font)
	title_label.add_theme_font_size_override("font_size", 42)
	title_label.add_theme_color_override("font_color", Color(1, 0.84, 0))
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	title_label.text = "☀️ PVZ 植物卡牌对战"
	add_child(title_label)
	
	sub_label = Label.new()
	sub_label.position = Vector2(0, 155)
	sub_label.size = Vector2(1024, 26)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.add_theme_font_override("font", font)
	sub_label.add_theme_font_size_override("font_size", 16)
	sub_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	sub_label.text = "Plants vs. Zombies Card Battle — 粉丝致敬作品"
	add_child(sub_label)
	
	# ===== 致谢面板（中间）=====
	var panel_w = 480
	var panel_h = 200
	var panel_x = (1024 - panel_w) / 2
	var panel_y = 210
	
	credit_panel = Panel.new()
	credit_panel.position = Vector2(panel_x, panel_y)
	credit_panel.size = Vector2(panel_w, panel_h)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.12, 0.18, 0.85)
	panel_style.border_color = Color(0.3, 0.45, 0.6, 0.8)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(10)
	credit_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(credit_panel)
	
	# 致谢标题
	var credit_title = Label.new()
	credit_title.position = Vector2(0, 12)
	credit_title.size = Vector2(panel_w, 28)
	credit_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit_title.add_theme_font_override("font", font)
	credit_title.add_theme_font_size_override("font_size", 18)
	credit_title.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	credit_title.text = "📜 致谢"
	credit_panel.add_child(credit_title)
	
	# 致谢内容
	var credit_texts = [
		"Inspired by Plants vs. Zombies (PopCap Games)",
		"Music: PVZ Original Soundtrack (Laura Shigihara)",
		"",
		"植物卡牌对战 — 粉丝致敬作品",
		"感谢所有植物训练师的支持！",
		"",
		"Made with ❤️ and Godot Engine",
	]
	
	var cy = 48.0
	for ct in credit_texts:
		var cl = Label.new()
		cl.position = Vector2(24, cy)
		cl.size = Vector2(panel_w - 48, 20)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cl.add_theme_font_override("font", font)
		cl.add_theme_font_size_override("font_size", 14)
		cl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
		cl.text = ct
		credit_panel.add_child(cl)
		credit_lines.append(cl)
		cy += 20
	
	# ===== 进度条区（下方）=====
	var bar_w = 500
	var bar_h = 24
	var bar_x = (1024 - bar_w) / 2
	var bar_y = 460
	
	# 进度条背景
	progress_bg = ColorRect.new()
	progress_bg.position = Vector2(bar_x, bar_y)
	progress_bg.size = Vector2(bar_w, bar_h)
	progress_bg.color = Color(0.15, 0.15, 0.2)
	var bg_style = StyleBoxFlat.new()
	bg_style.set_corner_radius_all(12)
	add_child(progress_bg)
	
	# 进度条填充
	progress_fill = ColorRect.new()
	progress_fill.position = Vector2(bar_x + 2, bar_y + 2)
	progress_fill.size = Vector2(0, bar_h - 4)
	progress_fill.color = Color(0.2, 0.7, 0.3)
	add_child(progress_fill)
	
	# 百分比文字
	progress_label = Label.new()
	progress_label.position = Vector2(0, bar_y + 28)
	progress_label.size = Vector2(1024, 22)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_font_override("font", font)
	progress_label.add_theme_font_size_override("font_size", 15)
	progress_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	progress_label.text = "加载中... 0%"
	add_child(progress_label)
	
	# 提示文字
	tip_label = Label.new()
	tip_label.position = Vector2(0, 520)
	tip_label.size = Vector2(1024, 20)
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_label.add_theme_font_override("font", font)
	tip_label.add_theme_font_size_override("font_size", 14)
	tip_label.add_theme_color_override("font_color", Color(0.55, 0.6, 0.65))
	tip_label.text = tips[0]
	add_child(tip_label)
	
	# ===== 开始游戏按钮（初始隐藏）=====
	start_btn = Button.new()
	start_btn.position = Vector2(1024 / 2 - 120, 560)
	start_btn.size = Vector2(240, 52)
	start_btn.text = "🎮 点击开始游戏"
	start_btn.add_theme_font_override("font", font)
	start_btn.add_theme_font_size_override("font_size", 22)
	start_btn.visible = false
	start_btn.pressed.connect(_on_start_pressed)
	# 按钮样式
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.18, 0.55, 0.25)
	btn_normal.set_corner_radius_all(8)
	btn_normal.set_border_width_all(2)
	btn_normal.border_color = Color(0.3, 0.7, 0.4)
	btn_normal.content_margin_top = 8
	btn_normal.content_margin_bottom = 8
	start_btn.add_theme_stylebox_override("normal", btn_normal)
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.25, 0.65, 0.32)
	btn_hover.set_corner_radius_all(8)
	btn_hover.set_border_width_all(2)
	btn_hover.border_color = Color(0.4, 0.8, 0.5)
	btn_hover.content_margin_top = 8
	btn_hover.content_margin_bottom = 8
	start_btn.add_theme_stylebox_override("hover", btn_hover)
	add_child(start_btn)
	
	# 淡入淡出遮罩
	fade_overlay = ColorRect.new()
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_overlay.color = Color(0, 0, 0, 1)  # 初始全黑
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_overlay)

func _play_music() -> void:
	if GlobalMusic:
		GlobalMusic.play_loading()

func _process(delta: float) -> void:
	timer += delta
	
	match phase:
		0:  # 淡入
			var alpha = 1.0 - clampf(timer / 0.8, 0, 1)
			fade_overlay.color = Color(0, 0, 0, alpha)
			if timer >= 0.8:
				phase = 1
				timer = 0.0
		
		1:  # 致谢展示一段时间后开始进度条
			if timer >= 1.0:
				phase = 2
				timer = 0.0
				progress = 0.0
		
		2:  # 进度条加载
			# 模拟加载：前80%快，后20%慢
			var speed = 0.8 if progress < 0.8 else 0.25
			progress += delta * speed / load_duration
			progress = clampf(progress, 0, 1)
			
			# 更新进度条
			var bar_w = 500 - 4
			progress_fill.size.x = progress * bar_w
			progress_label.text = "加载中... %d%%" % int(progress * 100)
			
			# 进度条颜色渐变
			if progress < 0.5:
				progress_fill.color = Color(0.2, 0.7, 0.3)
			elif progress < 0.85:
				progress_fill.color = Color(0.7, 0.6, 0.15)
			else:
				progress_fill.color = Color(0.85, 0.15, 0.15)
			
			# 切换提示
			if int(timer * 2) % 3 == 0:
				var tip_idx = int(timer) % tips.size()
				tip_label.text = tips[tip_idx]
			
			# 加载完成
			if progress >= 1.0:
				phase = 3
				timer = 0.0
				progress_label.text = "✅ 加载完成！"
				progress_fill.color = Color(0.15, 0.65, 0.2)
				start_btn.visible = true
				# 闪烁提示
				tip_label.text = "▼ 点击下方按钮开始游戏 ▼"
				tip_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
		
		3:  # 等待点击（按钮闪烁）
			if start_btn:
				var pulse = 0.85 + 0.15 * sin(timer * 3.0)
				start_btn.modulate = Color(pulse, pulse, pulse)

func _on_start_pressed() -> void:
	if phase != 3:
		return
	phase = 4
	start_btn.disabled = true
	start_btn.text = "加载中..."
	# 淡出
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, 0.6)
	tween.tween_callback(_go_to_menu)

func _go_to_menu() -> void:
	if GlobalMusic:
		GlobalMusic.stop()
	# 检查是否已注册，未注册则跳转注册界面
	if PlayerProfile and not PlayerProfile.is_registered():
		get_tree().change_scene_to_file("res://scenes/register.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _input(event: InputEvent) -> void:
	# 进度条完成后才响应点击
	if phase == 3:
		if event is InputEventMouseButton and event.pressed:
			_on_start_pressed()
		elif event is InputEventKey and event.pressed:
			_on_start_pressed()
		elif event is InputEventScreenTouch and event.pressed:
			_on_start_pressed()
