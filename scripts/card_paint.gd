## CardPaint — 自绘卡牌控件（对齐 Python CardRenderer 五层绘制）
## 层级：①阵营背景 → ②植物插图 → ③精力/攻击图标+数字 → ④限制符 → ⑤名称条
extends Control

class_name CardPaint

var card: CardData
var clickable: bool = false
var font: Font
var faction_color: Color = Color(0.4, 0.4, 0.4)
var display_name: String = ""
var mini_mode: bool = false
var large_mode: bool = false

var bg_tex: Texture2D
var plant_tex: Texture2D
var energy_tex: Texture2D
var atk_tex: Texture2D
var limit_tex: Texture2D

const CARD_W: int = 80
const CARD_H: int = 120
const MINI_W: int = 50
const MINI_H: int = 70
const LARGE_W: int = 120
const LARGE_H: int = 180

func _ready() -> void:
	if mini_mode:
		custom_minimum_size = Vector2(MINI_W, MINI_H)
		size = Vector2(MINI_W, MINI_H)
		modulate = Color(1, 1, 1, 0.7)
	elif large_mode:
		custom_minimum_size = Vector2(LARGE_W, LARGE_H)
		size = Vector2(LARGE_W, LARGE_H)
	else:
		custom_minimum_size = Vector2(CARD_W, CARD_H)
		size = Vector2(CARD_W, CARD_H)
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	clip_children = CLIP_CHILDREN_AND_DRAW

func _draw() -> void:
	if card == null:
		return

	var cw: int = MINI_W if mini_mode else (LARGE_W if large_mode else CARD_W)
	var ch: int = MINI_H if mini_mode else (LARGE_H if large_mode else CARD_H)
	var rect := Rect2(Vector2.ZERO, Vector2(cw, ch))

	# -- ① 阵营背景 ----------------------------------------─
	if bg_tex:
		draw_texture_rect(bg_tex, rect, false)
	else:
		draw_rect(rect, faction_color, true)

	# -- ② 植物插图（安全区，按模式缩放）----------------------
	var safe_w: float = 60.0
	var safe_h: float = 80.0
	var safe_y_off: float = 20.0
	if mini_mode:
		safe_w = 38.0; safe_h = 50.0; safe_y_off = 10.0
	elif large_mode:
		safe_w = 90.0; safe_h = 120.0; safe_y_off = 30.0
	if plant_tex:
		var tex_size: Vector2 = plant_tex.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			var ratio: float = minf(safe_w / tex_size.x, safe_h / tex_size.y)
			var sw: float = tex_size.x * ratio
			var sh: float = tex_size.y * ratio
			var dx: float = (cw - sw) / 2.0
			var dy: float = safe_y_off + (safe_h - sh) / 2.0
			draw_texture_rect(plant_tex, Rect2(dx, dy, sw, sh), false)

	# -- ③ 左上角精力图标 + 数字（mini不画图标）--------------─
	var badge_size := Vector2(22.0, 22.0)
	var font_size_main: int = 13
	var cost_text_y: float = 40.0
	var cost_text_x: float = 8.0
	if mini_mode:
		badge_size = Vector2(0, 0); font_size_main = 9; cost_text_y = 30.0; cost_text_x = 6.0
	elif large_mode:
		badge_size = Vector2(33.0, 33.0); font_size_main = 20; cost_text_y = 60.0; cost_text_x = 12.0

	if energy_tex and not mini_mode:
		draw_texture_rect(energy_tex, Rect2(2, 2, badge_size.x, badge_size.y), false)
	if font:
		draw_string(font, Vector2(cost_text_x, cost_text_y), str(card.cost),
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size_main, Color(1, 0.85, 0))

	# -- ④ 右上角攻击图标 + 数字（mini不画图标）--------------─
	var atk_text_x: float = cw - 18.0
	if large_mode:
		atk_text_x = cw - 27.0
	elif mini_mode:
		atk_text_x = cw - 14.0
	if atk_tex and not mini_mode:
		var ax: float = cw - badge_size.x - 2
		draw_texture_rect(atk_tex, Rect2(ax, 2, badge_size.x, badge_size.y), false)
	if font:
		draw_string(font, Vector2(atk_text_x, cost_text_y), str(card.atk),
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size_main, Color(1, 0.2, 0.2))

	# -- ⑤ 限制符（左下角，mini不画）--------------------------
	var limit_size: float = 18.0
	var limit_y: float = ch - 22.0
	if large_mode:
		limit_size = 27.0; limit_y = ch - 33.0
	if limit_tex and not mini_mode:
		draw_texture_rect(limit_tex, Rect2(2, limit_y, limit_size, limit_size), false)

	# -- ⑥ 底部名称条 --------------------------------------─
	var name_h: float = 20.0 if not mini_mode else 16.0
	if large_mode:
		name_h = 30.0
	var name_bar_y: float = ch - name_h
	draw_rect(Rect2(0, name_bar_y, cw, name_h), Color(0, 0, 0, 0.63))
	if font and display_name != "":
		var tw: float = font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size_main).x
		draw_string(font, Vector2((cw - tw) / 2.0, name_bar_y + name_h - 6), display_name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size_main, Color(1, 1, 1))

	# -- 边框 ------------------------------------------------
	var border_w: float = 1.0 if not large_mode else 2.0
	draw_rect(rect, Color(0.6, 0.6, 0.6), false, border_w)
