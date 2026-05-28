## splash_scene.gd - 开场致谢动画
## 播放 "080. Opening Splash.mp3"，显示标题和致谢信息，淡出后进入主菜单
extends Control

var font: FontFile
var overlay: ColorRect
var title_label: Label
var sub_label: Label
var credit_label: RichTextLabel
var timer: float = 0.0
var duration: float = 4.5  # 总时长
var fade_start: float = 3.5  # 开始淡出的时间

func _ready() -> void:
	# 强制保持宽高比，防止手机宽屏 UI 偏移
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	font = load("res://assets/fonts/simhei.ttf")
	_build_ui()
	_play_music()

func _build_ui() -> void:
	# 黑色背景
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 1)
	add_child(bg)
	
	overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	
	# 主标题
	title_label = Label.new()
	title_label.set_anchors_preset(Control.PRESET_CENTER)
	title_label.position = Vector2(-200, -60)
	title_label.size = Vector2(400, 50)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", font)
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", Color(1, 0.84, 0))
	title_label.text = "PVZ 植物卡牌对战"
	add_child(title_label)
	
	# 副标题
	sub_label = Label.new()
	sub_label.set_anchors_preset(Control.PRESET_CENTER)
	sub_label.position = Vector2(-200, -10)
	sub_label.size = Vector2(400, 30)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.add_theme_font_override("font", font)
	sub_label.add_theme_font_size_override("font_size", 16)
	sub_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	sub_label.text = "Plants vs. Zombies Card Battle"
	add_child(sub_label)
	
	# 致谢信息
	credit_label = RichTextLabel.new()
	credit_label.set_anchors_preset(Control.PRESET_CENTER)
	credit_label.position = Vector2(-180, 40)
	credit_label.size = Vector2(360, 100)
	credit_label.bbcode_enabled = true
	credit_label.add_theme_font_override("normal_font", font)
	credit_label.add_theme_font_size_override("normal_font_size", 14)
	credit_label.add_theme_color_override("default_color", Color(0.5, 0.6, 0.7))
	credit_label.text = (
		"[center]Inspired by Plants vs. Zombies[/center]\n" +
		"[center]植物卡牌对战 - 粉丝致敬作品[/center]\n\n" +
		"[center]Music: PVZ OST[/center]\n" +
		"[center]点击任意处跳过[/center]"
	)
	add_child(credit_label)

func _play_music() -> void:
	if GlobalMusic:
		GlobalMusic.play_loading()

func _process(delta: float) -> void:
	timer += delta
	
	# 淡出
	if timer >= fade_start:
		var alpha = (timer - fade_start) / (duration - fade_start)
		alpha = clampf(alpha, 0, 1)
		overlay.color = Color(0, 0, 0, alpha)
	
	# 结束
	if timer >= duration:
		_go_to_menu()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_go_to_menu()
	elif event is InputEventKey and event.pressed:
		_go_to_menu()
	elif event is InputEventScreenTouch and event.pressed:
		_go_to_menu()

func _go_to_menu() -> void:
	set_process(false)
	get_tree().change_scene_to_file("res://scenes/loading.tscn")
