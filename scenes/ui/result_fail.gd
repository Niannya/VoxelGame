extends Control
## 失败结算界面 · 占位脚本
## 负责：填数据 / 生成矿石槽 / 用 SubViewport 渲染每个玩家的角色大头照 / 矿石左右滚动 / 返回按钮
## 程序接入时只需要改下面三个 const（或把它们换成从对局数据里读），节点结构不用动。

signal back_requested

# ---------------------------------------------------------------- 数据区

## 4 名玩家。rank 按金币从高到低排；is_main = 本机玩家（头像会加金框）
## name 是玩家自己的昵称（不是角色名），程序接入时换成真实昵称
## char 是角色模型下标（0~5），与 character_select.gd 的 CHAR_MODELS 顺序一致
const PLAYERS := [
	{"rank": 1, "name": "玩家昵称1", "tag": "3P", "coin": 200, "death": 4, "char": 0, "is_main": false},
	{"rank": 2, "name": "玩家昵称2", "tag": "2P", "coin": 180, "death": 5, "char": 1, "is_main": false},
	{"rank": 3, "name": "玩家昵称3", "tag": "1P", "coin": 150, "death": 6, "char": 2, "is_main": true},
	{"rank": 4, "name": "玩家昵称4", "tag": "4P", "coin": 90, "death": 6, "char": 3, "is_main": false},
]

## 团队整体结算
const TEAM := {
	"cart_level": 4,
	"distance": 1200,
	"best": 2000,
}

## 收集到的矿石。count 为 0 的种类自动不显示；数量多到超出宽度时下方可左右滚动
## desc 是悬浮窗里的介绍文案（占位，程序接入时换成配置表数据）
const ORES := [
	{"name": "煤矿", "color": Color(0.52, 0.54, 0.58), "count": 3,
		"desc": "最常见的基础矿石，黑黢黢的但很可靠。矿道深处随处可见，是前期的主要收入来源。"},
	{"name": "铁矿", "color": Color(0.74, 0.46, 0.32), "count": 4,
		"desc": "硬度不错的红棕色矿石，敲起来铛铛响。可以用来修补矿车，也能卖个好价钱。"},
	{"name": "铜矿", "color": Color(0.88, 0.58, 0.28), "count": 10,
		"desc": "暖橙色的金属矿石，埋在中层矿脉里。数量多、价值适中，是探险队的支柱财源。"},
	{"name": "金矿", "color": Color(0.96, 0.79, 0.32), "count": 2,
		"desc": "闪闪发光的稀有矿石！通常藏在矿脉深处，小心：金矿附近常常有塌方风险。"},
	{"name": "青晶", "color": Color(0.42, 0.77, 0.86), "count": 6,
		"desc": "散发着淡淡蓝光的晶体矿石，摸起来冰凉。据说贴在脑门上能让人精神一振。"},
	{"name": "紫晶", "color": Color(0.68, 0.48, 0.86), "count": 1,
		"desc": "神秘的紫色晶体，在黑暗中会微微发光。矿工们都相信它能带来好运。"},
	{"name": "绿宝石", "color": Color(0.40, 0.78, 0.50), "count": 2,
		"desc": "温润的绿色宝石，切割后光彩夺目。商人们抢着收的好货，一枚能换不少金币。"},
	{"name": "红宝石", "color": Color(0.86, 0.32, 0.34), "count": 1,
		"desc": "炽热的红色宝石，仿佛内部藏着火焰。是本局挖到的最珍贵矿石，值得炫耀！"},
]

const RUN_ORE_TYPES := [
	{"key": "gold", "name": "黄金", "color": Color(0.96, 0.79, 0.32), "desc": "本局挖出的黄金。"},
	{"key": "quartz", "name": "石英", "color": Color(0.73, 0.81, 0.90), "desc": "本局挖出的石英。"},
	{"key": "diamond", "name": "钻石", "color": Color(0.42, 0.77, 0.86), "desc": "本局挖出的钻石。"},
	{"key": "emerald", "name": "绿宝石", "color": Color(0.40, 0.78, 0.50), "desc": "本局挖出的绿宝石。"},
]

const CHAR_MODELS := [
	"res://assets/characters/char_01_cuntou.glb",
	"res://assets/characters/char_02_baimao.glb",
	"res://assets/characters/char_03_fenmao.glb",
	"res://assets/characters/char_04_lanmao.glb",
	"res://assets/characters/char_05_huangmao.glb",
	"res://assets/characters/char_06_hemao.glb",
]

const ICON_SCRIPT := preload("res://scenes/ui/parts/result_icon.gd")

const GOLD := Color(0.96, 0.79, 0.42, 1.0)
const GOLD_DIM := Color(0.96, 0.79, 0.42, 0.75)
const TEXT_MAIN := Color(0.95, 0.93, 0.88, 1.0)
const TEXT_DIM := Color(0.5, 0.52, 0.58, 1.0)
const RANK_DIM := Color(0.82, 0.84, 0.88, 1.0)

## 模型资源默认背对镜头（与角色选择界面一致）
const MODEL_YAW := PI
## 头像取景：模型高度 2.2，头部中心约 1.92
const PORTRAIT_SIZE := Vector2i(192, 192)
## 取景参数（都按身高比例）：画面中心在头顶往下 17.5% 处，视野高度取 47% 身高
const PORTRAIT_MODEL_H := 2.2
const PORTRAIT_FRAME_TOP := 0.205
const PORTRAIT_FRAME_HEIGHT := 0.68
const PORTRAIT_CAM_DIST := 2.6

@onready var portrait_pool: Node = $PortraitPool
@onready var ore_scroll: ScrollContainer = $TeamPanel/Margin/VBox/OreWrap/OreScroll
@onready var ore_row: HBoxContainer = $TeamPanel/Margin/VBox/OreWrap/OreScroll/OreRow
@onready var ore_summary: Label = $TeamPanel/Margin/VBox/OreHead/Summary
@onready var btn_back: Button = $BtnBack
@onready var btn_ore_left: Button = $TeamPanel/Margin/VBox/OreWrap/BtnOreLeft
@onready var btn_ore_right: Button = $TeamPanel/Margin/VBox/OreWrap/BtnOreRight

var _portrait_views: Array[SubViewport] = []
var run_character_index: int = -1
var run_distance: int = -1
var run_ore_counts: Dictionary = {}
var _players: Array = []
var _ores: Array = []

## 矿石悬浮窗（跟随鼠标）
var _tip: PanelContainer
var _tip_name: Label
var _tip_desc: Label
var _tip_owner_slot: Control = null


func _ready() -> void:
	_players = PLAYERS.duplicate(true)
	_ores = ORES.duplicate(true)
	if run_character_index >= 0:
		_players[2]["char"] = clampi(run_character_index, 0, CHAR_MODELS.size() - 1)
	if run_distance >= 0:
		_ores.clear()
		for template in RUN_ORE_TYPES:
			var ore: Dictionary = template.duplicate()
			ore["count"] = int(run_ore_counts.get(ore["key"], 0))
			_ores.append(ore)
	_fill_players()
	_fill_team()
	_build_ore_slots()
	_build_ore_tip()

	btn_back.pressed.connect(_on_back_pressed)
	btn_ore_left.pressed.connect(_scroll_ore.bind(-1.0))
	btn_ore_right.pressed.connect(_scroll_ore.bind(1.0))
	ore_scroll.gui_input.connect(_on_ore_wheel)

	_build_portraits()


# ---------------------------------------------------------------- 玩家榜

func _fill_players() -> void:
	for i in _players.size():
		var p: Dictionary = _players[i]
		var base := "Board/Margin/VBox/Row%d/HBox" % (i + 1)
		var rank: Label = get_node(base + "/Rank")
		var portrait: PanelContainer = get_node(base + "/Portrait")
		var name_label: Label = get_node(base + "/NameBox/Name")
		var tag_label: Label = get_node(base + "/NameBox/Tag")
		var coin: Label = get_node(base + "/Stats/CoinRow/Value")
		var death: Label = get_node(base + "/Stats/DeathRow/Value")
		var is_main: bool = p.is_main

		rank.text = str(p.rank)
		rank.add_theme_color_override("font_color", GOLD if p.rank == 1 else RANK_DIM)
		name_label.text = p.name
		name_label.add_theme_color_override("font_color", GOLD if is_main else TEXT_MAIN)
		tag_label.text = ("%s · 本机" % p.tag) if is_main else str(p.tag)
		tag_label.add_theme_color_override("font_color", GOLD_DIM if is_main else TEXT_DIM)
		coin.text = str(p.coin)
		death.text = str(p.death)
		portrait.add_theme_stylebox_override("panel", _portrait_style(is_main))


func _portrait_style(is_main: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.13, 0.1, 1.0) if is_main else Color(0.09, 0.1, 0.12, 1.0)
	sb.border_color = GOLD if is_main else Color(0.34, 0.36, 0.42, 1.0)
	sb.set_border_width_all(4 if is_main else 2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(3)
	if is_main:
		sb.shadow_color = Color(0.96, 0.77, 0.38, 0.42)
		sb.shadow_size = 14
	return sb


# ---------------------------------------------------------------- 团队结算

func _count_run_ores() -> int:
	var total := 0
	for ore in _ores:
		total += int(ore.count)
	return total

func _fill_team() -> void:
	$TeamPanel/Margin/VBox/LvRow/LvPill/Value.text = "Lv. %d" % TEAM.cart_level
	$TeamPanel/Margin/VBox/DistRow/Value.text = "%d m" % (run_distance if run_distance >= 0 else TEAM.distance)
	if run_distance >= 0:
		$TeamPanel/Margin/VBox/BestRow/Label.text = "本局已挖矿石  %d 个" % _count_run_ores()
	else:
		$TeamPanel/Margin/VBox/BestRow/Label.text = "前进距离最高记录  %d m" % TEAM.best

	var total := 0
	var kinds := 0
	for ore in _ores:
		total += int(ore.count)
		if int(ore.count) > 0:
			kinds += 1
	ore_summary.text = "共 %d 个 · %d 种" % [total, kinds]


# ---------------------------------------------------------------- 矿石槽

func _build_ore_slots() -> void:
	var template := ore_row.get_node("Template") as PanelContainer
	template.visible = false
	var index := 0
	for ore in _ores:
		if int(ore.count) <= 0:
			continue
		var slot := template.duplicate() as PanelContainer
		slot.visible = true
		slot.name = "Ore%d" % index
		slot.set_meta("ore", ore)
		var icon := slot.find_child("Icon", true, false) as Control
		if icon:
			icon.set("ore_color", ore.color)
		var num := slot.find_child("Count", true, false) as Label
		if num:
			num.text = "×%d" % ore.count
		ore_row.add_child(slot)
		index += 1
	var bar := ore_scroll.get_h_scroll_bar()
	bar.custom_minimum_size = Vector2(0, 7)
	bar.value_changed.connect(_on_ore_scrolled)
	await get_tree().process_frame
	_update_arrow_state()


# ---------------------------------------------------------------- 矿石悬浮窗

## 悬浮窗挂在根节点最后，保证画在最上层；内容为矿石名 + 占位文案
func _build_ore_tip() -> void:
	_tip = PanelContainer.new()
	_tip.name = "OreTip"
	_tip.visible = false
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.z_index = 100
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.11, 0.14, 0.97)
	sb.border_color = Color(0.96, 0.79, 0.42, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	_tip.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_tip.add_child(vb)

	_tip_name = Label.new()
	_tip_name.add_theme_font_size_override("font_size", 17)
	_tip_name.add_theme_color_override("font_color", GOLD)
	vb.add_child(_tip_name)

	_tip_desc = Label.new()
	_tip_desc.add_theme_font_size_override("font_size", 13)
	_tip_desc.add_theme_color_override("font_color", Color(0.78, 0.79, 0.84))
	_tip_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_desc.custom_minimum_size = Vector2(250, 0)
	vb.add_child(_tip_desc)

	add_child(_tip)


## 每帧做命中检测（比 mouse_entered 稳：滚动、窗口焦点变化都不会漏）
func _update_ore_hover(m: Vector2) -> void:
	var found: Control = null
	if ore_scroll.get_global_rect().has_point(m):
		for child in ore_row.get_children():
			var slot := child as Control
			if slot == null or not slot.visible:
				continue
			if slot.get_global_rect().has_point(m):
				found = slot
				break

	if found == null:
		if _tip.visible:
			_tip.visible = false
			_tip_owner_slot = null
		return

	if found != _tip_owner_slot:
		var ore: Dictionary = found.get_meta("ore", {})
		_tip_owner_slot = found
		_tip_name.text = "%s  ×%d" % [ore.get("name", ""), int(ore.get("count", 0))]
		_tip_desc.text = str(ore.get("desc", ""))
		_tip.visible = true
		_tip.reset_size()
	_place_tip(m)


## 跟随鼠标：默认出现在右下方，靠近边缘时自动翻到另一侧
func _place_tip(m: Vector2) -> void:
	var margin := 10.0
	_tip.reset_size()
	var ts := _tip.size
	var pos := m + Vector2(18.0, 24.0)
	if pos.x + ts.x > size.x - margin:
		pos.x = m.x - ts.x - 14.0
	if pos.y + ts.y > size.y - margin:
		pos.y = m.y - ts.y - 14.0
	_tip.position = Vector2(maxf(margin, pos.x), maxf(margin, pos.y))


func _process(_delta: float) -> void:
	if _tip == null:
		return
	_update_ore_hover(get_global_mouse_position())


func _on_ore_wheel(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_scroll_ore(1.0)
		ore_scroll.accept_event()
	elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		_scroll_ore(-1.0)
		ore_scroll.accept_event()


func _scroll_ore(direction: float) -> void:
	var bar := ore_scroll.get_h_scroll_bar()
	var page: float = maxf(bar.page * 0.6, 240.0)
	var target: int = clampi(int(bar.value + direction * page), 0, int(bar.max_value - bar.page))
	var tw := create_tween()
	tw.tween_method(
		func(v: float) -> void: ore_scroll.scroll_horizontal = int(v),
		float(bar.value), float(target), 0.22
	)


func _on_ore_scrolled(_value: float) -> void:
	_update_arrow_state()


func _update_arrow_state() -> void:
	var bar := ore_scroll.get_h_scroll_bar()
	btn_ore_left.disabled = bar.value <= 0.5
	btn_ore_right.disabled = bar.value >= bar.max_value - bar.page - 0.5


# ---------------------------------------------------------------- 角色头像

## 每个玩家一个 SubViewport，拍角色头部特写；渲染几帧后切到 UPDATE_ONCE 就不再占 GPU
func _build_portraits() -> void:
	await get_tree().process_frame
	for i in _players.size():
		var p: Dictionary = _players[i]
		var ci: int = clampi(int(p.char), 0, CHAR_MODELS.size() - 1)
		var holder: PanelContainer = get_node("Board/Margin/VBox/Row%d/HBox/Portrait" % (i + 1))
		_make_portrait(holder, CHAR_MODELS[ci])
		await get_tree().process_frame
	# 多渲染两帧，确保模型和灯光都已就位再定格
	await get_tree().process_frame
	await get_tree().process_frame
	for vp in _portrait_views:
		if is_instance_valid(vp):
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _make_portrait(holder: PanelContainer, model_path: String) -> void:
	if not ResourceLoader.exists(model_path):
		return
	var packed := load(model_path) as PackedScene
	if packed == null:
		return

	var vp := SubViewport.new()
	vp.size = PORTRAIT_SIZE
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.name = "PortraitView"
	portrait_pool.add_child(vp)
	_portrait_views.append(vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.74, 0.77, 0.88)
	env.ambient_light_energy = 0.55
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	vp.add_child(world_env)

	var cam := Camera3D.new()
	vp.add_child(cam)

	var model_root := Node3D.new()
	model_root.rotation.y = MODEL_YAW + 0.36
	vp.add_child(model_root)
	var model: Node = packed.instantiate()
	model_root.add_child(model)

	# 每个角色帽子/头发高度不一样，按实测包围盒给每个人单独取景：
	# 画面中心落在「头顶往下 17.5% 身高」处，视野高度取 47% 身高 → 头完整、露一点肩
	var box := _model_aabb(model)
	var top := box.end.y
	var h := maxf(box.size.y, 0.1)
	var look_y := top - h * PORTRAIT_FRAME_TOP
	var view_h := h * PORTRAIT_FRAME_HEIGHT
	var dist := PORTRAIT_CAM_DIST
	cam.fov = rad_to_deg(2.0 * atan(view_h * 0.5 / dist))
	cam.position = Vector3(0.0, look_y, dist)
	cam.look_at_from_position(cam.position, Vector3(0.0, look_y, 0.0), Vector3.UP)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-14, -26, 0)
	key.light_energy = 1.05
	cam.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-2, 40, 0)
	fill.light_color = Color(0.84, 0.89, 1.0)
	fill.light_energy = 0.4
	fill.light_specular = 0.1
	cam.add_child(fill)

	var tex := TextureRect.new()
	tex.texture = vp.get_texture()
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(tex)


## 合并所有 MeshInstance3D 的全局包围盒（模型已归一化到脚底 y=0）
func _model_aabb(root: Node) -> AABB:
	var merged := AABB()
	var found := false
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var box: AABB = mi.global_transform * mi.mesh.get_aabb()
		merged = box if not found else merged.merge(box)
		found = true
	if not found:
		return AABB(Vector3(-0.4, 0.0, -0.4), Vector3(0.8, PORTRAIT_MODEL_H, 0.8))
	return merged


# ---------------------------------------------------------------- 返回

func _on_back_pressed() -> void:
	back_requested.emit()
