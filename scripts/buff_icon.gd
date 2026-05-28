## buff_icon.gd — Buff 图标自绘控件
## 对应 Python: renderer._draw_buff_bar / _draw_buff_placeholder
## 在 36×36 区域内绘制：
##   ① buff 图片（有则绘制，无则首字母色块占位）
##   ② 彩色边框（按类型区分颜色）
##   ③ 右下角数值标签（黑底白字）
##   ④ 持续回合标签（图标下方）
extends Control

var _buff_tex: Texture2D = null
var _border_color: Color = Color(0.47, 0.47, 0.47)
var _placeholder_color: Color = Color(0.31, 0.31, 0.31)
var _icon_code: String = "?"
var _buff_value: int = 0
var _duration: int = 0
var _buff_name: String = ""
var _icon_size: float = 36.0
var _font: FontFile = null


func setup(buff_img_path: String, border_color: Color, placeholder_color: Color,
		icon_code: String, buff_value: int, duration: int,
		buff_name: String, icon_size: float, font: FontFile) -> void:
	_border_color = border_color
	_placeholder_color = placeholder_color
	_icon_code = icon_code
	_buff_value = buff_value
	_duration = duration
	_buff_name = buff_name
	_icon_size = icon_size
	_font = font
	if buff_img_path != "" and ResourceLoader.exists(buff_img_path):
		_buff_tex = load(buff_img_path)
	custom_minimum_size = Vector2(_icon_size, _icon_size)
	size = Vector2(_icon_size, _icon_size)
	queue_redraw()


func _draw() -> void:
	var sz: float = _icon_size
	var rect := Rect2(0, 0, sz, sz)

	# ① 底层：黑色背景
	draw_rect(rect, Color(0, 0, 0, 200))

	if _buff_tex != null:
		# 有图片：绘制 buff 图标
		draw_texture_rect(_buff_tex, rect, false)
	else:
		# 无图片：占位色块 + 首字母
		draw_rect(rect, _placeholder_color)
		if _font != null:
			var ch: String = _icon_code.left(1).to_upper()
			if ch == "":
				ch = "?"
			var ts := _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_CENTER, -1, 18)
			var tx: float = (sz - ts.x) / 2.0
			var ty: float = (sz - 18) / 2.0
			draw_string(_font, Vector2(tx, ty + 14), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1))

	# ② 边框（2px，四边）
	draw_rect(Rect2(0, 0, sz, 2), _border_color)
	draw_rect(Rect2(0, sz - 2, sz, 2), _border_color)
	draw_rect(Rect2(0, 0, 2, sz), _border_color)
	draw_rect(Rect2(sz - 2, 0, 2, sz), _border_color)

	# ③ 右下角数值标签
	if _buff_value > 0 and _font != null:
		var val_str: String = str(_buff_value)
		var vs := _font.get_string_size(val_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		var vw: float = max(vs.x + 4, 14.0)
		var vh: float = 13.0
		var vx: float = sz - vw - 1
		var vy: float = sz - vh - 1
		# 黑底
		draw_rect(Rect2(vx, vy, vw, vh), Color(0, 0, 0, 180))
		# 数字
		draw_string(_font, Vector2(vx + 2, vy + 10), val_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1))

	# ④ 持续回合标签（图标下方，仅 duration > 0 时显示）
	if _duration > 0 and _font != null:
		var dur_str: String = "%dR" % _duration
		draw_string(_font, Vector2(1, sz + 10), dur_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(200 / 255.0, 200 / 255.0, 200 / 255.0))
