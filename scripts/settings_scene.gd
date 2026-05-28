## 设置场景脚本
## BGM音量、音效音量、BGM静音、屏幕亮度
## 使用 _input 全局输入处理，避免子节点拦截问题
extends Control

signal settings_closed(settings: Dictionary)

var settings: Dictionary = {
	"bgm_volume": 0.5,
	"sfx_volume": 0.7,
	"bgm_muted": false,
	"screen_brightness": 1.0,
}

var font: FontFile
var slider_dragging: String = ""

var overlay: ColorRect
var panel: Panel

func _ready() -> void:
	font = load("res://assets/fonts/simhei.ttf")
	_load_settings()
	_build_ui()

func _load_settings() -> void:
	var path = "user://settings.json"
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data = json.get_data()
		for key in settings:
			if data.has(key):
				settings[key] = data[key]
	file.close()

func _save_settings() -> void:
	var path = "user://settings.json"
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings, "\t"))
		file.close()

func _build_ui() -> void:
	# 半透明遮罩
	overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.59)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	
	# 面板
	var pw = 500
	var ph = 420
	var px = (1024 - pw) / 2
	var py = (768 - ph) / 2
	
	panel = Panel.new()
	panel.position = Vector2(px, py)
	panel.size = Vector2(pw, ph)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(panel)
	
	# 标题
	var title_label = Label.new()
	title_label.position = Vector2(0, 20)
	title_label.size = Vector2(pw, 40)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", font)
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.text = "⚙️ 设置"
	panel.add_child(title_label)
	
	# 分隔线
	var sep = HSeparator.new()
	sep.position = Vector2(30, 60)
	sep.size = Vector2(pw - 60, 2)
	panel.add_child(sep)
	
	# 控件
	var y = 80.0
	_create_slider("bgm_volume", "🎵 BGM音量", 50, y, pw - 100, 0.0, 1.0, true)
	y += 80
	_create_slider("sfx_volume", "🔊 音效音量", 50, y, pw - 100, 0.0, 1.0, true)
	y += 80
	_create_toggle("bgm_muted", "🔇 关闭BGM", 50, y)
	y += 70
	_create_slider("screen_brightness", "🔆 屏幕亮度", 50, y, pw - 100, 0.3, 1.0, false)
	
	# 返回按钮
	var back_btn = Button.new()
	back_btn.position = Vector2(pw / 2 - 90, ph - 62)
	back_btn.size = Vector2(180, 42)
	back_btn.text = "返回"
	back_btn.add_theme_font_override("font", font)
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.pressed.connect(_on_back_pressed)
	panel.add_child(back_btn)

func _create_slider(key: String, label_text: String, x: float, y: float, w: float, min_val: float, max_val: float, is_pct: bool) -> void:
	var value = clampf(float(settings.get(key, 0.5)), min_val, max_val)
	
	var display_val = "%d%%" % int(value * 100) if is_pct else "%.1f" % value
	
	var lbl = Label.new()
	lbl.position = Vector2(x, y)
	lbl.size = Vector2(w, 24)
	lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.text = "%s: %s" % [label_text, display_val]
	lbl.name = key + "_label"
	panel.add_child(lbl)
	
	# 滑轨背景
	var track_bg = ColorRect.new()
	track_bg.position = Vector2(x, y + 30)
	track_bg.size = Vector2(w, 12)
	track_bg.color = Color(0.25, 0.25, 0.33)
	track_bg.name = key + "_track"
	panel.add_child(track_bg)
	
	# 滑轨填充
	var normalized = (value - min_val) / max(max_val - min_val, 0.001)
	var fill_w = normalized * w
	var track_fill = ColorRect.new()
	track_fill.position = Vector2(x, y + 30)
	track_fill.size = Vector2(max(0, fill_w), 12)
	track_fill.color = Color(0.31, 0.63, 0.94)
	track_fill.name = key + "_fill"
	panel.add_child(track_fill)
	
	# 手柄
	var handle = Panel.new()
	handle.position = Vector2(x + fill_w - 9, y + 27)
	handle.size = Vector2(18, 18)
	handle.name = key + "_handle"
	panel.add_child(handle)

func _create_toggle(key: String, label_text: String, x: float, y: float) -> void:
	var is_on = bool(settings.get(key, false))
	
	var lbl = Label.new()
	lbl.position = Vector2(x, y)
	lbl.size = Vector2(200, 28)
	lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.text = label_text
	panel.add_child(lbl)
	
	var toggle_w = 56
	var toggle_h = 28
	var toggle_x = x + 220
	
	var track = Panel.new()
	track.position = Vector2(toggle_x, y)
	track.size = Vector2(toggle_w, toggle_h)
	track.name = key + "_toggle"
	track.modulate = Color(0.27, 0.71, 0.39) if is_on else Color(0.35, 0.35, 0.39)
	panel.add_child(track)
	
	var knob = Label.new()
	if is_on:
		knob.position = Vector2(toggle_x + toggle_w - 18, y + 5)
	else:
		knob.position = Vector2(toggle_x + 8, y + 5)
	knob.size = Vector2(14, 18)
	knob.text = "●"
	knob.add_theme_font_size_override("font_size", 14)
	knob.name = key + "_knob"
	panel.add_child(knob)
	
	var status = Label.new()
	status.position = Vector2(toggle_x + toggle_w + 12, y + 3)
	status.size = Vector2(40, 24)
	status.add_theme_font_override("font", font)
	status.add_theme_font_size_override("font_size", 17)
	status.text = "ON" if is_on else "OFF"
	status.name = key + "_status"
	panel.add_child(status)

## 用 _input 而非 _gui_input，确保能收到所有输入事件
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_back_pressed()
		return
	
	if event is InputEventMouseButton:
		var local_pos = event.position - panel.global_position
		var pw = panel.size.x
		var ph = panel.size.y
		
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# 检查 toggle 点击
			_handle_toggle_click(local_pos)
			# 检查滑块点击
			_handle_slider_click(local_pos)
		
		if not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if slider_dragging != "":
				slider_dragging = ""
	
	if event is InputEventMouseMotion and slider_dragging != "":
		var local_pos = event.position - panel.global_position
		_update_slider(slider_dragging, local_pos.x)

func _handle_toggle_click(local_pos: Vector2) -> void:
	# toggle 位置: x=270, y=240, w=56, h=28（BGM静音那行）
	# 需要根据重建后的实际位置判断
	# 简化：检查 "关闭BGM" 文字右侧区域
	var toggle_x = 270.0
	var toggle_y = 240.0
	var toggle_w = 56.0
	var toggle_h = 28.0
	# 检查面板内鼠标位置
	var rect = Rect2(toggle_x, toggle_y, toggle_w, toggle_h)
	if rect.has_point(local_pos):
		settings["bgm_muted"] = not bool(settings.get("bgm_muted", false))
		_apply_audio_settings()
		_rebuild_ui()

func _handle_slider_click(local_pos: Vector2) -> void:
	var y_positions = {"bgm_volume": 80.0, "sfx_volume": 160.0, "screen_brightness": 320.0}
	var ctrl_w = panel.size.x - 100
	
	for key in y_positions:
		var y = y_positions[key]
		var track_rect = Rect2(50, y + 25, ctrl_w, 24)
		if track_rect.has_point(local_pos):
			slider_dragging = key
			_update_slider(key, local_pos.x)
			return

func _update_slider(key: String, mouse_x: float) -> void:
	var ctrl_w = panel.size.x - 100
	var normalized = clampf((mouse_x - 50) / max(ctrl_w, 1.0), 0.0, 1.0)
	
	var min_val = 0.0
	var max_val = 1.0
	if key == "screen_brightness":
		min_val = 0.3
	
	var value = min_val + normalized * (max_val - min_val)
	value = snapped(value, 0.01)
	settings[key] = value
	_apply_audio_settings()
	_rebuild_ui()

func _rebuild_ui() -> void:
	# 保存标题和返回按钮引用，清除其他
	var children = panel.get_children()
	for child in children:
		child.queue_free()
	
	var pw = panel.size.x
	var ph = panel.size.y
	
	# 标题
	var title_label = Label.new()
	title_label.position = Vector2(0, 20)
	title_label.size = Vector2(pw, 40)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", font)
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.text = "⚙️ 设置"
	panel.add_child(title_label)
	
	var sep = HSeparator.new()
	sep.position = Vector2(30, 60)
	sep.size = Vector2(pw - 60, 2)
	panel.add_child(sep)
	
	var y = 80.0
	_create_slider("bgm_volume", "🎵 BGM音量", 50, y, pw - 100, 0.0, 1.0, true)
	y += 80
	_create_slider("sfx_volume", "🔊 音效音量", 50, y, pw - 100, 0.0, 1.0, true)
	y += 80
	_create_toggle("bgm_muted", "🔇 关闭BGM", 50, y)
	y += 70
	_create_slider("screen_brightness", "🔆 屏幕亮度", 50, y, pw - 100, 0.3, 1.0, false)
	
	var back_btn = Button.new()
	back_btn.position = Vector2(pw / 2 - 90, ph - 62)
	back_btn.size = Vector2(180, 42)
	back_btn.text = "返回"
	back_btn.add_theme_font_override("font", font)
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.pressed.connect(_on_back_pressed)
	panel.add_child(back_btn)

func _on_back_pressed() -> void:
	_save_settings()
	_apply_audio_settings()
	settings_closed.emit(settings)
	queue_free()

func _apply_audio_settings() -> void:
	if GlobalMusic:
		GlobalMusic.update_settings(settings)
