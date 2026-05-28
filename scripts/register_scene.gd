## register_scene.gd - 首次启动玩家注册界面
## 对应 Python: ui/register_screen.py
##
## 界面：
##   - 标题 "欢迎来到 PVZ 植物卡牌对战"
##   - 副标题 "请输入你的玩家名字"
##   - 文本输入框
##   - "确认注册" 按钮
##   - 底部提示 "你的 ID 将自动生成"
extends Control

var font: FontFile
var input_field: LineEdit
var confirm_btn: Button
var error_label: Label
var fade_overlay: ColorRect
var registered: bool = false
var timer: float = 0.0
var phase: int = 0  # 0=淡入 1=注册 2=淡出

func _ready() -> void:
	font = load("res://assets/fonts/simhei.ttf")
	_build_ui()

func _build_ui() -> void:
	# 背景色
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(26.0/255, 43.0/255, 58.0/255)
	add_child(bg)
	
	# 花园背景（半透明装饰）
	var garden_tex = load("res://assets/images/bg/bg_garden.png")
	if garden_tex:
		var bg_img = TextureRect.new()
		bg_img.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg_img.texture = garden_tex
		bg_img.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		bg_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bg_img.modulate = Color(1, 1, 1, 0.15)
		add_child(bg_img)
	
	# 标题
	var title = Label.new()
	title.position = Vector2(0, 180)
	title.size = Vector2(1024, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1, 0.94, 0.55))
	title.text = "☀️ 欢迎来到 PVZ 植物卡牌对战"
	add_child(title)
	
	# 副标题
	var subtitle = Label.new()
	subtitle.position = Vector2(0, 240)
	subtitle.size = Vector2(1024, 30)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("font", font)
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(190.0/255, 210.0/255, 230.0/255))
	subtitle.text = "请输入你的玩家名字"
	add_child(subtitle)
	
	# 输入框容器（居中装饰框）
	var input_panel = Panel.new()
	var panel_w = 340
	var panel_h = 52
	input_panel.position = Vector2((1024 - panel_w) / 2, 300)
	input_panel.size = Vector2(panel_w, panel_h)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(245.0/255, 245.0/255, 250.0/255)
	panel_style.set_corner_radius_all(8)
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(72.0/255, 108.0/255, 200.0/255)
	input_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(input_panel)
	
	# 输入框
	input_field = LineEdit.new()
	input_field.position = Vector2((1024 - 320) / 2, 304)
	input_field.size = Vector2(320, 44)
	input_field.placeholder_text = "输入名字..."
	input_field.max_length = 12
	input_field.add_theme_font_override("font", font)
	input_field.add_theme_font_size_override("font_size", 20)
	input_field.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	input_field.add_theme_color_override("font_placeholder_color", Color(0.5, 0.5, 0.5))
	# 透明背景
	var input_style = StyleBoxFlat.new()
	input_style.bg_color = Color(0, 0, 0, 0)
	input_style.set_corner_radius_all(6)
	input_field.add_theme_stylebox_override("normal", input_style)
	input_field.add_theme_stylebox_override("focus", input_style)
	input_field.add_theme_stylebox_override("read_only", input_style)
	add_child(input_field)
	
	# 错误提示
	error_label = Label.new()
	error_label.position = Vector2(0, 360)
	error_label.size = Vector2(1024, 22)
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.add_theme_font_override("font", font)
	error_label.add_theme_font_size_override("font_size", 14)
	error_label.add_theme_color_override("font_color", Color(0.86, 0.24, 0.24))
	error_label.text = ""
	add_child(error_label)
	
	# 确认按钮
	confirm_btn = Button.new()
	confirm_btn.position = Vector2(1024 / 2 - 80, 395)
	confirm_btn.size = Vector2(160, 46)
	confirm_btn.text = "✅ 确认注册"
	confirm_btn.add_theme_font_override("font", font)
	confirm_btn.add_theme_font_size_override("font_size", 18)
	confirm_btn.pressed.connect(_on_confirm)
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(55.0/255, 140.0/255, 90.0/255)
	btn_normal.set_corner_radius_all(8)
	btn_normal.set_border_width_all(2)
	btn_normal.border_color = Color(130.0/255, 150.0/255, 170.0/255)
	confirm_btn.add_theme_stylebox_override("normal", btn_normal)
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(72.0/255, 160.0/255, 108.0/255)
	btn_hover.set_corner_radius_all(8)
	btn_hover.set_border_width_all(2)
	btn_hover.border_color = Color(150.0/255, 170.0/255, 190.0/255)
	confirm_btn.add_theme_stylebox_override("hover", btn_hover)
	add_child(confirm_btn)
	
	# 底部提示
	var hint = Label.new()
	hint.position = Vector2(0, 460)
	hint.size = Vector2(1024, 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", font)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(120.0/255, 130.0/255, 145.0/255))
	hint.text = "你的唯一 ID 将在注册后自动生成（UUID4）"
	add_child(hint)
	
	# 版本信息
	var ver_label = Label.new()
	ver_label.position = Vector2(0, 720)
	ver_label.size = Vector2(1024, 20)
	ver_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver_label.add_theme_font_override("font", font)
	ver_label.add_theme_font_size_override("font_size", 12)
	ver_label.add_theme_color_override("font_color", Color(0.3, 0.35, 0.4))
	ver_label.text = "PVZ Plant Card Game v1.0 — Fan Game"
	add_child(ver_label)
	
	# 淡入淡出遮罩
	fade_overlay = ColorRect.new()
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_overlay.color = Color(0, 0, 0, 1)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_overlay)

func _process(delta: float) -> void:
	timer += delta
	match phase:
		0:  # 淡入
			var alpha = 1.0 - clampf(timer / 0.6, 0, 1)
			fade_overlay.color = Color(0, 0, 0, alpha)
			if timer >= 0.6:
				phase = 1
				input_field.grab_focus()
		2:  # 淡出
			var alpha = clampf(timer / 0.5, 0, 1)
			fade_overlay.color = Color(0, 0, 0, alpha)
			if timer >= 0.5:
				_go_to_menu()

func _on_confirm() -> void:
	var name = input_field.text.strip_edges()
	if name == "":
		error_label.text = "❌ 名字不能为空！"
		return
	if name.length() < 1:
		error_label.text = "❌ 名字至少 1 个字符"
		return
	
	# 注册
	PlayerProfile.create_profile(name)
	registered = true
	confirm_btn.disabled = true
	confirm_btn.text = "✅ 注册成功！"
	
	# 淡出进入主菜单
	phase = 2
	timer = 0.0

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		if phase == 1 and not registered:
			_on_confirm()

func _go_to_menu() -> void:
	if GlobalMusic:
		GlobalMusic.stop()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
