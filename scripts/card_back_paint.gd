## CardBackPaint — 卡背自绘
extends Control

var back_tex: Texture2D
var card_w: int = 60
var card_h: int = 84
var rotated: bool = false  ## 横版模式：将竖版贴图旋转-90°绘制

func _ready() -> void:
	custom_minimum_size = Vector2(card_w, card_h)
	size = Vector2(card_w, card_h)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if rotated and back_tex:
		# 横版：将竖版贴图旋转-90°绘制到横向矩形
		var tex_w: float = back_tex.get_width()
		var tex_h: float = back_tex.get_height()
		# 缩放：旋转后 tex_h→显示宽, tex_w→显示高
		var scale_x: float = card_w / tex_h
		var scale_y: float = card_h / tex_w
		var s: float = minf(scale_x, scale_y)
		# 旋转-90°：围绕绘制中心顺时针旋转
		var center: Vector2 = Vector2(card_w / 2.0, card_h / 2.0)
		var src_rect: Rect2 = Rect2(0, 0, tex_w, tex_h)
		var dst_rect: Rect2 = Rect2(-tex_w * s / 2.0, -tex_h * s / 2.0, tex_w * s, tex_h * s)
		draw_set_transform(center, PI / 2.0, Vector2.ONE)
		draw_texture_rect_region(back_tex, dst_rect, src_rect)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# 边框
		draw_rect(Rect2(Vector2.ZERO, Vector2(card_w, card_h)), Color(0.4, 0.45, 0.5), false, 1.0)
	else:
		var rect := Rect2(Vector2.ZERO, Vector2(card_w, card_h))
		if back_tex:
			draw_texture_rect(back_tex, rect, false)
		else:
			draw_rect(rect, Color(0.2, 0.25, 0.35))
			var font_size: int = maxi(12, card_h / 5)
			draw_string(null, Vector2(card_w / 2.0 - 6, card_h / 2.0 + 6), "?",
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.6, 0.6, 0.6))
		draw_rect(rect, Color(0.4, 0.45, 0.5), false, 1.0)
