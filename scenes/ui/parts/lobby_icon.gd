@tool
extends Control
## 准备间用的小图标：门（退出）/ 齿轮（设置）/ 钻石 / 金币 / 玩家头像剪影。
## 纯代码绘制，@tool 让它在编辑器里就能看到。
## 正式美术图到位后，把这些节点换成 TextureRect + 贴图即可，接口不变。

enum Kind { DOOR, GEAR, DIAMOND, COIN, HEAD }

@export var icon_kind: Kind = Kind.DOOR:
	set(value):
		icon_kind = value
		queue_redraw()

@export var tint: Color = Color(0.94, 0.79, 0.44):
	set(value):
		tint = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not resized.is_connected(queue_redraw):
		resized.connect(queue_redraw)


func _draw() -> void:
	var side: float = minf(size.x, size.y)
	if side <= 0.0:
		return
	var c: Vector2 = size * 0.5
	match icon_kind:
		Kind.DOOR:
			_draw_door(c, side)
		Kind.GEAR:
			_draw_gear(c, side)
		Kind.DIAMOND:
			_draw_diamond(c, side)
		Kind.COIN:
			_draw_coin(c, side)
		Kind.HEAD:
			_draw_head(c, side)


## 门：门框 + 门板 + 两块凹板 + 门把手 + 门下透出的光
func _draw_door(c: Vector2, s: float) -> void:
	var w: float = s * 0.44
	var h: float = s * 0.58
	var r := Rect2(c + Vector2(-w * 0.5, -h * 0.5 - s * 0.02), Vector2(w, h))
	# 门框
	draw_rect(r, tint.darkened(0.58), true)
	# 门板
	var inner := Rect2(r.position + Vector2(s * 0.055, s * 0.055), r.size - Vector2(s * 0.11, s * 0.11))
	draw_rect(inner, tint, true)
	# 两块凹板
	draw_rect(Rect2(inner.position + Vector2(s * 0.05, s * 0.05), Vector2(inner.size.x - s * 0.10, inner.size.y * 0.34)), tint.darkened(0.22), true)
	draw_rect(Rect2(inner.position + Vector2(s * 0.05, inner.size.y * 0.50), Vector2(inner.size.x - s * 0.10, inner.size.y * 0.40)), tint.darkened(0.22), true)
	# 门把手
	draw_circle(c + Vector2(w * 0.26, h * 0.05), s * 0.042, tint.darkened(0.62))
	# 门下透出的光
	draw_rect(Rect2(Vector2(r.position.x, r.end.y + s * 0.03), Vector2(w, s * 0.05)), Color(1.0, 0.85, 0.48, 0.5), true)


## 齿轮：外圈 + 8 个齿 + 中心孔
func _draw_gear(c: Vector2, s: float) -> void:
	var r: float = s * 0.26
	var teeth := 8
	for i in teeth:
		var a: float = TAU * float(i) / float(teeth)
		var dir := Vector2(cos(a), sin(a))
		var base: Vector2 = c + dir * r * 0.92
		var tip: Vector2 = c + dir * r * 1.34
		var side := Vector2(-dir.y, dir.x) * s * 0.075
		draw_colored_polygon(PackedVector2Array([base + side, tip + side * 0.7, tip - side * 0.7, base - side]), tint)
	draw_circle(c, r, tint)
	draw_circle(c, r * 0.62, tint.darkened(0.28))
	draw_circle(c, r * 0.34, Color(0.06, 0.07, 0.09))


## 钻石：上方台面 + 两个侧切面 + 底部尖角
func _draw_diamond(c: Vector2, s: float) -> void:
	var w: float = s * 0.42
	var h: float = s * 0.40
	var top := c + Vector2(0.0, -h)
	var top_l := c + Vector2(-w * 0.62, -h * 0.42)
	var top_r := c + Vector2(w * 0.62, -h * 0.42)
	var mid_l := c + Vector2(-w, -h * 0.10)
	var mid_r := c + Vector2(w, -h * 0.10)
	var bot := c + Vector2(0.0, h)

	draw_colored_polygon(PackedVector2Array([top_l, top, top_r, mid_r, mid_l]), tint.lightened(0.22))
	draw_colored_polygon(PackedVector2Array([top_l, mid_l, bot]), tint.darkened(0.10))
	draw_colored_polygon(PackedVector2Array([top_r, mid_r, bot]), tint.darkened(0.30))
	draw_colored_polygon(PackedVector2Array([mid_l, mid_r, bot]), tint)
	# 高光
	draw_colored_polygon(PackedVector2Array([
		top + Vector2(-w * 0.34, h * 0.10),
		top + Vector2(w * 0.10, h * 0.10),
		top + Vector2(-w * 0.10, h * 0.34),
	]), Color(1, 1, 1, 0.55))


func _draw_coin(c: Vector2, s: float) -> void:
	var r: float = s * 0.42
	draw_circle(c, r, tint.darkened(0.45))
	draw_circle(c, r * 0.88, tint)
	draw_circle(c, r * 0.40, tint.darkened(0.22))
	draw_circle(c + Vector2(-r * 0.34, -r * 0.36), r * 0.13, Color(1.0, 0.97, 0.84, 0.8))


## 玩家头像剪影：圆头 + 肩线
func _draw_head(c: Vector2, s: float) -> void:
	var head_r: float = s * 0.17
	var head_c: Vector2 = c + Vector2(0.0, -s * 0.12)
	draw_circle(head_c, head_r, tint.darkened(0.25))
	# 肩膀：半圆
	var pts := PackedVector2Array()
	for i in 19:
		var a: float = PI + PI * float(i) / 18.0
		pts.append(c + Vector2(cos(a), sin(a)) * s * 0.30 + Vector2(0.0, s * 0.30))
	draw_colored_polygon(pts, tint.darkened(0.25))
