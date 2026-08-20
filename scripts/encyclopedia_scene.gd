## 图鉴界面 — 展示所有卡牌，支持阵营/限制符筛选
## 右键点击卡牌查看介绍
extends Control

signal encyclopedia_closed

const FACTION_COLORS: Dictionary = {
	"法": Color(0.54, 0.17, 0.88),
	"射": Color(0.12, 0.56, 1.0),
	"坦": Color(0.63, 0.32, 0.18),
	"辅": Color(1.0, 0.84, 0.0),
}

const FACTION_BG_MAP: Dictionary = {
	"法": "res://assets/images/borders/bg_mage.jpg",
	"射": "res://assets/images/borders/bg_archer.jpg",
	"坦": "res://assets/images/borders/bg_tank.jpg",
	"辅": "res://assets/images/borders/bg_support.jpg",
}

const CARDS_PER_ROW: int = 4
const CARD_W: int = 120
const CARD_H: int = 180
const CARD_GAP: int = 24
const ROW_GAP: int = 20

var all_cards: Array = []
var filtered_cards: Array = []
var active_filter: String = "all"

var font: Font
var bg_tex: Texture2D
var _tex_cache: Dictionary = {}

var scroll_container: ScrollContainer
var grid_vbox: VBoxContainer
var count_label: Label
var desc_popup: Control

func _ready() -> void:
	font = load("res://assets/fonts/simhei.ttf")
	bg_tex = load("res://assets/images/bg_encyclopedia.jpg")
	_load_cards()
	_build_ui()
	_apply_filter("all")

func _load_cards() -> void:
	all_cards.clear()
	var path = "res://data/cards.json"
	if not FileAccess.file_exists(path):
		push_error("[Encyclopedia] cards.json 不存在")
		return
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var json_text = file.get_as_text()
	file.close()
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		return
	var data = json.get_data()
	var cards = data.get("cards", [])
	for entry in cards:
		if entry is Dictionary:
			all_cards.append(CardData.new(entry))

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = Vector2(1024, 768)

	# -- 背景 --
	# 全屏不透明遮罩（覆盖主菜单）
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.08, 0.05, 0.02)
	add_child(shade)

	# 木制外框面板（居中，略宽于4卡）
	var frame_panel := Panel.new()
	frame_panel.position = Vector2(192, 56)
	frame_panel.size = Vector2(640, 700)
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.22, 0.14, 0.06)
	frame_style.set_border_width_all(6)
	frame_style.border_color = Color(0.55, 0.35, 0.15)
	frame_style.set_corner_radius_all(12)
	frame_panel.add_theme_stylebox_override("panel", frame_style)
	add_child(frame_panel)

	# 框内背景图（木制纹理，仅填充框内区域）
	var inner_bg := TextureRect.new()
	inner_bg.texture = bg_tex
	inner_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner_bg.offset_left = 6
	inner_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	inner_bg.stretch_mode = TextureRect.STRETCH_SCALE
	inner_bg.offset_right = -6
	inner_bg.offset_top = 6
	inner_bg.offset_bottom = -6
	inner_bg.modulate = Color(0.7, 0.55, 0.35, 0.9)
	frame_panel.add_child(inner_bg)

	# -- 顶部栏 --
	var top_bar := Panel.new()
	top_bar.position = Vector2(0, 0)
	top_bar.size = Vector2(1024, 52)
	var tb_style := StyleBoxFlat.new()
	tb_style.bg_color = Color(0.15, 0.08, 0.03, 0.88)
	tb_style.set_border_width(3, 2)  # SIDE_BOTTOM = 3
	tb_style.border_color = Color(0.5, 0.3, 0.1)
	top_bar.add_theme_stylebox_override("panel", tb_style)
	add_child(top_bar)

	# -- 筛选按钮（左上角一行排列）--
	var filter_labels: Array = [
		["all", "全部"], ["法", "法"], ["射", "射"],
		["坦", "坦"], ["辅", "辅"], ["limit_yes", "限制符:有"], ["limit_no", "限制符:无"]
	]
	var btn_x: float = 10.0

	# 互斥按钮组（所有筛选按钮共享同一组）
	var filter_group := ButtonGroup.new()
	for entry in filter_labels:
		var key: String = entry[0]
		var label: String = entry[1]
		var btn := Button.new()
		btn.text = label
		btn.position = Vector2(btn_x, 10)
		btn.size = Vector2(90, 32)
		btn.add_theme_font_override("font", font)
		btn.add_theme_font_size_override("font_size", 14)
		btn.toggle_mode = true
		btn.button_group = filter_group
		if key == "all":
			btn.button_pressed = true
		btn.pressed.connect(_on_filter_pressed.bind(key, btn))
		top_bar.add_child(btn)
		btn_x += 96

	# -- 卡牌总数（右上角）--
	count_label = Label.new()
	count_label.position = Vector2(870, 15)
	count_label.size = Vector2(144, 24)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.add_theme_font_override("font", font)
	count_label.add_theme_font_size_override("font_size", 16)
	count_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	top_bar.add_child(count_label)

	# -- 返回按钮（右上角）--
	var back_btn := Button.new()
	back_btn.text = "← 返回"
	back_btn.position = Vector2(870, 10)
	back_btn.size = Vector2(100, 32)
	back_btn.add_theme_font_override("font", font)
	back_btn.add_theme_font_size_override("font_size", 14)
	# 重新调整总数和返回按钮位置避免重叠
	count_label.position = Vector2(740, 15)
	count_label.size = Vector2(120, 24)
	back_btn.position = Vector2(880, 10)
	back_btn.pressed.connect(_on_back_pressed)
	top_bar.add_child(back_btn)

	# -- 滚动卡牌区域 --
	scroll_container = ScrollContainer.new()
	scroll_container.position = Vector2(8, 8)
	scroll_container.size = Vector2(624, 684)
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame_panel.add_child(scroll_container)

	grid_vbox = VBoxContainer.new()
	grid_vbox.add_theme_constant_override("separation", ROW_GAP)
	grid_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(grid_vbox)

	# -- 右键介绍弹窗 --
	_build_desc_popup()

func _build_desc_popup() -> void:
	desc_popup = Control.new()
	desc_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	desc_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	desc_popup.visible = false
	add_child(desc_popup)

	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	desc_popup.add_child(overlay)

	var panel := Panel.new()
	panel.position = Vector2(282, 250)
	panel.size = Vector2(460, 260)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.12, 0.06, 0.02, 0.95)
	ps.set_border_width_all(3)
	ps.border_color = Color(0.6, 0.4, 0.15)
	ps.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", ps)
	desc_popup.add_child(panel)

	var title := Label.new()
	title.position = Vector2(20, 15)
	title.size = Vector2(420, 36)
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	panel.add_child(title)

	var info := Label.new()
	info.position = Vector2(20, 55)
	info.size = Vector2(420, 24)
	info.add_theme_font_override("font", font)
	info.add_theme_font_size_override("font_size", 14)
	info.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	panel.add_child(info)

	var desc := Label.new()
	desc.position = Vector2(20, 90)
	desc.size = Vector2(420, 100)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_override("font", font)
	desc.add_theme_font_size_override("font_size", 16)
	desc.add_theme_color_override("font_color", Color(1, 1, 1))
	panel.add_child(desc)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(180, 210)
	close_btn.size = Vector2(100, 34)
	close_btn.add_theme_font_override("font", font)
	close_btn.add_theme_font_size_override("font_size", 15)
	close_btn.pressed.connect(_close_desc_popup)
	panel.add_child(close_btn)

	# 点击遮罩关闭
	overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_close_desc_popup()
	)

	# 存储引用
	desc_popup.set_meta("title", title)
	desc_popup.set_meta("info", info)
	desc_popup.set_meta("desc", desc)

func _on_filter_pressed(filter_key: String, btn: Button) -> void:
	active_filter = filter_key
	_apply_filter(filter_key)

func _apply_filter(filter_key: String) -> void:
	filtered_cards.clear()
	for card in all_cards:
		if card is CardData:
			if filter_key == "all":
				filtered_cards.append(card)
			elif filter_key == "limit_yes":
				if card.limit_flag:
					filtered_cards.append(card)
			elif filter_key == "limit_no":
				if not card.limit_flag:
					filtered_cards.append(card)
			else:
				# 阵营筛选
				if card.faction == filter_key:
					filtered_cards.append(card)

	# 按id排序
	filtered_cards.sort_custom(func(a, b): return a.id < b.id)

	_refresh_grid()
	count_label.text = "卡牌: %d / %d" % [filtered_cards.size(), all_cards.size()]

func _refresh_grid() -> void:
	for child in grid_vbox.get_children():
		child.queue_free()

	var row: HBoxContainer = null
	var count_in_row: int = 0

	for card in filtered_cards:
		if count_in_row == 0:
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", CARD_GAP)
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			grid_vbox.add_child(row)

		var card_node := _create_card_node(card)
		row.add_child(card_node)
		count_in_row += 1

		if count_in_row >= CARDS_PER_ROW:
			count_in_row = 0

func _create_card_node(card: CardData) -> Control:
	var node := CardPaint.new()
	node.card = card
	node.clickable = false
	node.font = font
	node.large_mode = true
	node.faction_color = FACTION_COLORS.get(card.faction, Color(0.4, 0.4, 0.4))
	node.display_name = _clean_card_name(card.name)
	if node.display_name.length() > 5:
		node.display_name = node.display_name.left(5) + ".."
	# 预加载纹理
	node.bg_tex = _load_tex(FACTION_BG_MAP.get(card.faction, ""))
	node.plant_tex = _load_tex(card.get_image_path())
	node.energy_tex = _load_tex("res://assets/images/borders/bg_energy.png")
	node.atk_tex = _load_tex("res://assets/images/borders/bg_atk.png")
	node.limit_tex = _load_tex("res://assets/images/borders/bg_limit.png") if card.limit_flag else null
	node.custom_minimum_size = Vector2(CARD_W, CARD_H)
	node.size = Vector2(CARD_W, CARD_H)
	# 右键查看介绍
	node.gui_input.connect(_on_card_right_click.bind(card))
	return node

func _on_card_right_click(event: InputEvent, card: CardData) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_show_desc_popup(card)
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# 左键也能查看（移动端兼容）
			_show_desc_popup(card)

func _show_desc_popup(card: CardData) -> void:
	var title: Label = desc_popup.get_meta("title")
	var info: Label = desc_popup.get_meta("info")
	var desc: Label = desc_popup.get_meta("desc")

	title.text = _clean_card_name(card.name)
	var faction_name: String = card.faction
	var type_str: String = "限制" if card.limit_flag else "普通"
	info.text = "阵营: %s  |  费用: %d  |  攻击: %d  |  类型: %s" % [faction_name, card.cost, card.atk, type_str]
	desc.text = card.description if card.description != "" else "无技能描述"

	desc_popup.visible = true

func _close_desc_popup() -> void:
	desc_popup.visible = false

func _on_back_pressed() -> void:
	encyclopedia_closed.emit()
	queue_free()

func _load_tex(path: String) -> Texture2D:
	if path == "":
		return null
	if _tex_cache.has(path):
		return _tex_cache[path]
	if ResourceLoader.exists(path):
		var tex = load(path)
		_tex_cache[path] = tex
		return tex
	return null

func _clean_card_name(raw: String) -> String:
	var cleaned: String = raw.strip_edges()
	var has_ascii: bool = false
	for ch in cleaned:
		if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z"):
			has_ascii = true
			break
	if has_ascii:
		cleaned = cleaned.replace("fa", "").replace("fu", "").replace("s", "").replace("t", "").strip_edges()
	if cleaned == "":
		cleaned = raw
	return cleaned

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE and event.pressed:
			if desc_popup.visible:
				_close_desc_popup()
			else:
				_on_back_pressed()
