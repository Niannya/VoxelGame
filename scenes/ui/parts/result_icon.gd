@tool
extends Control
## 结算界面用的小图标：金币 / 死亡 / 矿石晶体。
## 纯代码绘制，@tool 让它在本体编辑器里也能直接看到，不用等运行。
## 用法：把本脚本挂在任意 Control 上，选 icon_kind；矿石再选 ore_color。
## 正式美术图到位后，把这些节点换成 TextureRect + 贴图即可，接口不变。

enum Kind { COIN, SKULL, ORE }

@export var icon_kind: Kind = Kind.COIN:
	set(value):
		icon_kind = value
		queue_redraw()

@export var ore_color: Color = Color(0.86, 0.35, 0.32):
	set(value):
		ore_color = value
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
		Kind.COIN:
			_draw_coin(c, side)
		Kind.SKULL:
			_draw_skull(c, side)
		Kind.ORE:
			_draw_ore(c, side)


## 金币：深金外圈 + 亮金币面 + 中心深色图案 + 左上高光
func _draw_coin(c: Vector2, s: float) -> void:
	var r: float = s * 0.46
	draw_circle(c, r, Color(0.5, 0.35, 0.09))
	draw_circle(c, r * 0.90, Color(0.96, 0.78, 0.33))
	draw_circle(c, r * 0.42, Color(0.70, 0.50, 0.13))
	draw_arc(c, r * 0.42, 0.0, TAU, 20, Color(0.99, 0.86, 0.52), maxf(1.0, s * 0.04), true)
	draw_circle(c + Vector2(-r * 0.36, -r * 0.38), r * 0.13, Color(1.0, 0.97, 0.85, 0.85))


## 死亡：小骷髅（颅骨 + 下颌 + 眼窝 + 牙缝）
func _draw_skull(c: Vector2, s: float) -> void:
	var bone := Color(0.90, 0.90, 0.85)
	var hollow := Color(0.09, 0.10, 0.12)
	var r: float = s * 0.33
	var head: Vector2 = c + Vector2(0.0, -s * 0.05)
	var jaw := Rect2(head.x - r * 0.58, head.y + r * 0.52, r * 1.16, r * 0.60)

	draw_circle(head, r, bone)
	draw_rect(jaw, bone)
	# 眼窝
	draw_circle(head + Vector2(-r * 0.42, -r * 0.12), r * 0.30, hollow)
	draw_circle(head + Vector2(r * 0.42, -r * 0.12), r * 0.30, hollow)
	# 鼻腔
	var n: float = r * 0.15
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(0.0, r * 0.16),
		head + Vector2(-n, r * 0.46),
		head + Vector2(n, r * 0.46),
	]), hollow)
	# 牙缝
	var line_w: float = maxf(1.0, s * 0.035)
	for i in 3:
		var x: float = jaw.position.x + jaw.size.x * (0.28 + 0.22 * float(i))
		draw_line(
			Vector2(x, jaw.position.y + jaw.size.y * 0.15),
			Vector2(x, jaw.position.y + jaw.size.y * 0.90),
			hollow, line_w
		)


## 矿石：竖向六边形晶体 + 亮顶面 + 暗左面 + 描边
func _draw_ore(c: Vector2, s: float) -> void:
	var r: float = s * 0.40
	var pts := PackedVector2Array()
	for i in 6:
		var a: float = -PI * 0.5 + float(i) * TAU / 6.0
		pts.append(c + Vector2(cos(a) * 0.80, sin(a)) * r)

	draw_colored_polygon(pts, ore_color)
	# 顶面提亮
	var apex: Vector2 = c + Vector2(0.0, -r * 0.40)
	draw_colored_polygon(PackedVector2Array([pts[5], pts[0], pts[1], apex]), ore_color.lightened(0.38))
	# 左侧压暗（体积感）
	draw_colored_polygon(PackedVector2Array([pts[3], pts[4], pts[5], apex, c]), ore_color.darkened(0.22))
	# 描边
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, ore_color.darkened(0.50), maxf(1.0, s * 0.028), true)
