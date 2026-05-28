## card_hover_particles.gd - 卡牌悬停四角星粒子特效
## 对应 Python: EdgeParticle + renderer._particles
## 悬停时从卡牌四边生成四角星粒子，颜色跟随阵营底色
extends Node2D

class_name CardHoverParticles

## 粒子数据结构
class Particle:
	var x: float
	var y: float
	var vx: float
	var vy: float
	var color: Color
	var life: float
	var decay: float
	var max_dist: float
	var origin_x: float
	var origin_y: float
	
	func _init(card_rect: Rect2, faction_color: Color) -> void:
		var cx: float = card_rect.position.x + card_rect.size.x / 2.0
		var cy: float = card_rect.position.y + card_rect.size.y / 2.0
		
		# 从四边随机选一条边生成
		var edge = randi() % 4
		match edge:
			0:  # top
				x = randf_range(card_rect.position.x, card_rect.position.x + card_rect.size.x)
				y = card_rect.position.y
			1:  # bottom
				x = randf_range(card_rect.position.x, card_rect.position.x + card_rect.size.x)
				y = card_rect.position.y + card_rect.size.y
			2:  # left
				x = card_rect.position.x
				y = randf_range(card_rect.position.y, card_rect.position.y + card_rect.size.y)
			3:  # right
				x = card_rect.position.x + card_rect.size.x
				y = randf_range(card_rect.position.y, card_rect.position.y + card_rect.size.y)
		
		# 速度方向：背离中心向外
		var dx: float = x - cx
		var dy: float = y - cy
		var dist: float = maxf(sqrt(dx * dx + dy * dy), 1.0)
		var speed: float = randf_range(0.6, 1.2)
		vx = (dx / dist) * speed
		vy = (dy / dist) * speed
		
		origin_x = cx
		origin_y = cy
		color = faction_color
		life = 1.0
		decay = 0.015
		max_dist = 22.0
	
	func update() -> void:
		x += vx
		y += vy
		life -= decay
		var traveled: float = sqrt((x - origin_x) * (x - origin_x) + (y - origin_y) * (y - origin_y))
		if traveled > max_dist:
			life -= 0.05
	
	func is_alive() -> bool:
		return life > 0.0

var _particles: Array = []

func _process(_delta: float) -> void:
	# 更新粒子
	var alive: Array = []
	for p in _particles:
		p.update()
		if p.is_alive():
			alive.append(p)
	_particles = alive
	queue_redraw()

## 添加一个粒子
func add_particle(card_rect: Rect2, faction_color: Color) -> void:
	_particles.append(Particle.new(card_rect, faction_color))

## 清空所有粒子
func clear_particles() -> void:
	_particles.clear()

## 绘制所有粒子（四角星）
func _draw() -> void:
	for p in _particles:
		if p.life <= 0.0:
			continue
		var alpha: float = p.life * 180.0 / 255.0
		var c = Color(p.color.r, p.color.g, p.color.b, alpha)
		_draw_four_point_star(Vector2(p.x, p.y), 5.0, 2.5, c)

## 绘制四角星
func _draw_four_point_star(center: Vector2, outer_r: float, inner_r: float, color: Color) -> void:
	var points: PackedVector2Array = []
	for i in range(8):
		var angle: float = i * PI / 4.0 - PI / 2.0
		var r: float = outer_r if i % 2 == 0 else inner_r
		points.append(center + Vector2(cos(angle) * r, sin(angle) * r))
	draw_colored_polygon(points, color)
