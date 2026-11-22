extends Control
## 准备间（游戏初始主界面）
##
## 结构：
## - 全屏像素底图（角色在左，右侧压暗给控制台让位）
## - 左侧「MINE / CRASH!」像素标题：两张 PNG 各自用单应矩阵贴到斜面上（真透视，不是简单旋转）；
##   MINE 那张带遮挡遮罩，会被前面的角色挡住（角色压在字上面）
## - 右侧控制台：内容全部画在一个 SubViewport 里，再用同一套单应矩阵贴到斜面上，
##   这样面板是真正的梯形透视；鼠标事件由本脚本按同一套矩阵映射回 SubViewport 内，
##   所以里面的页签 / 领取按钮 / 滚动列表都能正常交互。
## - 左上角「退出」「设置」是普通按钮，图标用 parts/lobby_icon.gd 代码绘制，后期可换贴图。

signal exit_requested
signal settings_requested
signal local_game_requested
signal online_game_requested

# ---------------------------------------------------------------- 透视布局

## 控制台在屏幕上的四个角（顺序：左上、右上、右下、左下）
const PANEL_QUAD := [
	Vector2(1296.0, 64.0),
	Vector2(1848.0, 10.0),
	Vector2(1848.0, 1058.0),
	Vector2(1296.0, 936.0),
]
## 控制台内容画布尺寸（与 SubViewport 一致）。宽高比要贴住四边形，
## 否则内容会被横向/纵向拉伸：四边形中间高度约 960，960 / 552 ≈ 1.739，780 * 1.739 ≈ 1350
const PANEL_SIZE := Vector2(780.0, 1350.0)

## 「MINE」在屏幕上的四个角（左高右低，和右下角的 CRASH! 同一个斜面角度）
const TITLE_MINE_QUAD := [
	Vector2(178.0, 16.0),
	Vector2(896.0, 116.0),
	Vector2(896.0, 326.0),
	Vector2(178.0, 226.0),
]
## 「CRASH!」在屏幕上的四个角（贴着屏幕左下角，倾斜角度与 MINE 一致）
const TITLE_CRASH_QUAD := [
	Vector2(150.0, 710.0),
	Vector2(1040.0, 875.0),
	Vector2(1040.0, 1050.0),
	Vector2(150.0, 885.0),
]

## 底图摆放：等比放大到屏高，再整体左移，把角色组推到画面左侧
const BG_SCALE := 1.0084
const BG_OFFSET := Vector2(-280.0, 0.0)

# ---------------------------------------------------------------- 奖励数据

## 福利列表。kind 对应 lobby_icon 的图标类型（0 门 / 1 齿轮 / 2 钻石 / 3 金币 / 4 头像）
const REWARDS := [
	{"name": "每日登录", "content": "钻石 ×1", "kind": 2, "color": Color(0.55, 0.85, 0.95)},
	{"name": "累计在线 30 分钟", "content": "金币 ×200", "kind": 3, "color": Color(0.96, 0.79, 0.42)},
	{"name": "完成首局游戏", "content": "钻石 ×3", "kind": 2, "color": Color(0.7, 0.6, 0.95)},
	{"name": "邀请好友联机", "content": "金币 ×500", "kind": 3, "color": Color(0.96, 0.62, 0.32)},
	{"name": "连续登录 7 天", "content": "钻石 ×10", "kind": 2, "color": Color(0.55, 0.9, 0.65)},
	{"name": "周常：挖矿 1000 块", "content": "金币 ×800", "kind": 3, "color": Color(0.9, 0.5, 0.45)},
]

@onready var bg_image: TextureRect = $Backdrop/BgImage
@onready var title_mine: TextureRect = $TitleMine
@onready var title_crash: TextureRect = $TitleCrash
@onready var panel_warp: TextureRect = $PanelWarp
@onready var panel_vp: SubViewport = $PanelViewport
@onready var tab_profile: Button = $PanelViewport/PanelRoot/TabProfile
@onready var tab_mall: Button = $PanelViewport/PanelRoot/TabMall
@onready var profile_page: Control = $PanelViewport/PanelRoot/Body
@onready var mall_page: Control = $PanelViewport/PanelRoot/MallPage
@onready var reward_scroll: ScrollContainer = $PanelViewport/PanelRoot/Body/RewardScroll
@onready var reward_list: VBoxContainer = $PanelViewport/PanelRoot/Body/RewardScroll/RewardList
@onready var row_template: PanelContainer = $PanelViewport/PanelRoot/Body/RewardScroll/RewardList/Row

var _panel_inv: Array = []      ## 屏幕像素 -> 面板 uv 的单应矩阵（三行）
var _panel_hovered := false
var _claim_buttons: Array = []


func _ready() -> void:
	_layout_background()
	_setup_quad(title_mine, TITLE_MINE_QUAD)
	_setup_quad(title_crash, TITLE_CRASH_QUAD)
	_panel_inv = _setup_quad(panel_warp, PANEL_QUAD)
	panel_warp.texture = panel_vp.get_texture()

	tab_profile.pressed.connect(_show_tab.bind(0))
	tab_mall.pressed.connect(_show_tab.bind(1))
	_show_tab(0)

	_build_rewards()
	_style_scrollbar()

	$BtnExit.pressed.connect(func() -> void: exit_requested.emit())
	$BtnSettings.pressed.connect(func() -> void: settings_requested.emit())
	$PanelViewport/PanelRoot/Body/BtnLocal.pressed.connect(func() -> void: local_game_requested.emit())
	$PanelViewport/PanelRoot/Body/BtnRemote.pressed.connect(func() -> void: online_game_requested.emit())


## 底图：等比铺满屏高后左移，让角色组落在左侧、右侧留给控制台
func _layout_background() -> void:
	var tex := bg_image.texture
	if tex == null:
		return
	var w: float = tex.get_width() * BG_SCALE
	var h: float = tex.get_height() * BG_SCALE
	bg_image.position = BG_OFFSET
	bg_image.size = Vector2(w, h)

	# 遮挡遮罩是按底图原始像素画的，把底图在屏幕上的摆放位置告诉着色器，
	# 以后改 BG_OFFSET / BG_SCALE 不用重新生成遮罩
	var mat := title_mine.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("occlude_rect",
			Vector4(BG_OFFSET.x, BG_OFFSET.y, w, h))


## ---------------------------------------------------------------- 透视贴合

## 把 node 的纹理按 quad 四点做透视贴合：
## 算出「单位方形 -> 四边形」的单应矩阵，取逆后交给着色器（屏幕像素 -> uv），
## 逆矩阵同时留着给鼠标事件做反向映射。
func _setup_quad(node: TextureRect, quad: Array) -> Array:
	var inv := _mat_inv(_square_to_quad(quad))
	var mat := node.material as ShaderMaterial
	if mat != null:
		# 着色器按「屏幕像素」算 uv，所以 rect_size 必须是节点的真实尺寸
		mat.set_shader_parameter("rect_size", node.size)
		node.resized.connect(func() -> void:
			mat.set_shader_parameter("rect_size", node.size))
		mat.set_shader_parameter("h0", inv[0])
		mat.set_shader_parameter("h1", inv[1])
		mat.set_shader_parameter("h2", inv[2])
	return inv


## 单位方形 (0,0)(1,0)(1,1)(0,1) -> 四点四边形的单应矩阵（Heckbert 解法）
static func _square_to_quad(p: Array) -> Array:
	var p0: Vector2 = p[0]
	var p1: Vector2 = p[1]
	var p2: Vector2 = p[2]
	var p3: Vector2 = p[3]
	var dx1 := p1.x - p2.x
	var dx2 := p3.x - p2.x
	var dx3 := p0.x - p1.x + p2.x - p3.x
	var dy1 := p1.y - p2.y
	var dy2 := p3.y - p2.y
	var dy3 := p0.y - p1.y + p2.y - p3.y

	var a: float
	var b: float
	var c: float
	var d: float
	var e: float
	var f: float
	var g := 0.0
	var h := 0.0
	if absf(dx3) < 0.000001 and absf(dy3) < 0.000001:
		a = p1.x - p0.x
		b = p2.x - p1.x
		c = p0.x
		d = p1.y - p0.y
		e = p2.y - p1.y
		f = p0.y
	else:
		var den := dx1 * dy2 - dx2 * dy1
		g = (dx3 * dy2 - dx2 * dy3) / den
		h = (dx1 * dy3 - dx3 * dy1) / den
		a = p1.x - p0.x + g * p1.x
		b = p3.x - p0.x + h * p3.x
		c = p0.x
		d = p1.y - p0.y + g * p1.y
		e = p3.y - p0.y + h * p3.y
		f = p0.y
	return [Vector3(a, b, c), Vector3(d, e, f), Vector3(g, h, 1.0)]


## 3x3 矩阵（三行 Vector3）求逆
static func _mat_inv(m: Array) -> Array:
	var a: float = m[0].x
	var b: float = m[0].y
	var c: float = m[0].z
	var d: float = m[1].x
	var e: float = m[1].y
	var f: float = m[1].z
	var g: float = m[2].x
	var h: float = m[2].y
	var i: float = m[2].z
	var det := a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)
	if absf(det) < 1e-12:
		return [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)]
	var inv := 1.0 / det
	return [
		Vector3((e * i - f * h) * inv, (c * h - b * i) * inv, (b * f - c * e) * inv),
		Vector3((f * g - d * i) * inv, (a * i - c * g) * inv, (c * d - a * f) * inv),
		Vector3((d * h - e * g) * inv, (b * g - a * h) * inv, (a * e - b * d) * inv),
	]


## 用矩阵把点投影到 uv
static func _apply(m: Array, v: Vector2) -> Vector2:
	var x: float = m[0].x * v.x + m[0].y * v.y + m[0].z
	var y: float = m[1].x * v.x + m[1].y * v.y + m[1].z
	var w: float = m[2].x * v.x + m[2].y * v.y + m[2].z
	if absf(w) < 1e-9:
		return Vector2(-1.0, -1.0)
	return Vector2(x / w, y / w)


## 屏幕坐标 -> 控制台内部坐标（返回 (-1,-1) 表示落在面板外）
func screen_to_panel(pos: Vector2) -> Vector2:
	var uv := _apply(_panel_inv, pos)
	# 留一点容差：正好点在边上时浮点误差会算出 -1e-7 被误判成面板外
	var eps := 0.003
	if uv.x < -eps or uv.x > 1.0 + eps or uv.y < -eps or uv.y > 1.0 + eps:
		return Vector2(-1.0, -1.0)
	return Vector2(clampf(uv.x, 0.0, 1.0) * PANEL_SIZE.x, clampf(uv.y, 0.0, 1.0) * PANEL_SIZE.y)


## ---------------------------------------------------------------- 输入桥接

func _input(event: InputEvent) -> void:
	if event is not InputEventMouse:
		return
	# 用事件自带的坐标（已经过 canvas_items 拉伸换算成 1920x1080 设计坐标），
	# 不要用 get_global_mouse_position() —— 那个读的是系统鼠标位置，和事件可能不同步
	var pos := (event as InputEventMouse).position
	var local := screen_to_panel(pos)
	if local.x < 0.0:
		if _panel_hovered:
			_panel_hovered = false
			_push_motion(Vector2(-60.0, -60.0), Vector2.ZERO)
		return

	_panel_hovered = true
	if event is InputEventMouseMotion:
		_push_motion(local, (event as InputEventMouseMotion).relative)
	elif event is InputEventMouseButton:
		_push_button(event as InputEventMouseButton, local)
		get_viewport().set_input_as_handled()


func _push_motion(local: Vector2, rel: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = local
	ev.global_position = local
	ev.relative = rel
	panel_vp.push_input(ev, true)


func _push_button(src: InputEventMouseButton, local: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = src.button_index
	ev.pressed = src.pressed
	ev.double_click = src.double_click
	ev.factor = src.factor
	ev.position = local
	ev.global_position = local
	panel_vp.push_input(ev, true)


## ---------------------------------------------------------------- 页签 / 福利

func _show_tab(index: int) -> void:
	profile_page.visible = index == 0
	mall_page.visible = index == 1
	tab_profile.button_pressed = index == 0
	tab_mall.button_pressed = index == 1
	var on: StyleBox = tab_profile.get_theme_stylebox("pressed")
	var off: StyleBox = tab_profile.get_theme_stylebox("normal")
	_restyle(tab_profile, on if index == 0 else off, index == 0)
	_restyle(tab_mall, on if index == 1 else off, index == 1)


func _restyle(btn: Button, style: StyleBox, active: bool) -> void:
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_color_override("font_color", Color(0.98, 0.88, 0.68) if active else Color(0.62, 0.64, 0.7))


func _build_rewards() -> void:
	row_template.visible = false
	for data in REWARDS:
		var row: PanelContainer = row_template.duplicate()
		row.visible = true
		row.name = "Row_%s" % String(data["name"]).replace(" ", "")
		var icon: Control = row.find_child("Icon", true, false)
		if icon:
			icon.set("icon_kind", data["kind"])
			icon.set("tint", data["color"])
		var name_label: Label = row.find_child("Name", true, false)
		if name_label:
			name_label.text = data["name"]
		var content: Label = row.find_child("Reward", true, false)
		if content:
			content.text = data["content"]
		var claim: Button = row.find_child("Claim", true, false)
		if claim:
			claim.pressed.connect(_on_claim.bind(claim))
			_claim_buttons.append(claim)
		reward_list.add_child(row)


func _on_claim(btn: Button) -> void:
	btn.text = "已领取"
	btn.disabled = true
	btn.add_theme_color_override("font_disabled_color", Color(0.45, 0.45, 0.5))
	var dim := StyleBoxFlat.new()
	dim.bg_color = Color(0.19, 0.2, 0.23, 1)
	dim.border_width_left = 2
	dim.border_width_top = 2
	dim.border_width_right = 2
	dim.border_width_bottom = 2
	dim.border_color = Color(0.3, 0.31, 0.35, 1)
	dim.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("disabled", dim)


## ScrollContainer 的滚动条是子节点，theme_override 挂在容器上不会生效，需要直接改滚动条本身
func _style_scrollbar() -> void:
	var bar := reward_scroll.get_v_scroll_bar()
	bar.custom_minimum_size = Vector2(7.0, 0.0)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.028, 0.032, 0.041, 0.9)
	track.set_corner_radius_all(3)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(0.58, 0.46, 0.25, 0.95)
	grab.set_corner_radius_all(3)
	var grab_hi := StyleBoxFlat.new()
	grab_hi.bg_color = Color(0.86, 0.66, 0.32, 1.0)
	grab_hi.set_corner_radius_all(3)
	for state in ["scroll", "scroll_focus"]:
		bar.add_theme_stylebox_override(state, track)
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(state, grab if state == "grabber" else grab_hi)
