extends Control
## 角色选择界面 · 占位交互脚本
## 包含：页签切换 / 角色选择（箭头+框选+模型颜色+名称联动）/ 工具选择（框选+属性联动）/ 确认切换
## 程序接入后可整体替换或逐个函数改造，数据结构见下方常量。

const CHAR_NAMES := ["角色名1", "角色名2", "角色名3", "角色名4", "角色名5", "角色名6"]
## 每个角色的占位配色：[身体, 头, 腿]（正式接入后换成模型场景切换）
const CHAR_COLORS := [
	[Color(0.42, 0.66, 0.62), Color(0.93, 0.85, 0.71), Color(0.26, 0.42, 0.5)],
	[Color(0.85, 0.55, 0.28), Color(0.93, 0.85, 0.71), Color(0.45, 0.32, 0.22)],
	[Color(0.55, 0.42, 0.72), Color(0.93, 0.85, 0.71), Color(0.3, 0.24, 0.42)],
	[Color(0.78, 0.34, 0.34), Color(0.93, 0.85, 0.71), Color(0.4, 0.2, 0.2)],
	[Color(0.36, 0.52, 0.78), Color(0.93, 0.85, 0.71), Color(0.22, 0.3, 0.44)],
	[Color(0.6, 0.62, 0.35), Color(0.93, 0.85, 0.71), Color(0.35, 0.38, 0.2)],
]

const TOOL_DATA := [
	{"name": "采集镐", "type": "采集", "desc": "占位说明：敲击矿石与晶簇，产出基础材料。", "atk": 35, "dur": 80},
	{"name": "建造锤", "type": "建造", "desc": "占位说明：放置与加固体素方块，修筑工事。", "atk": 20, "dur": 95},
	{"name": "木弓", "type": "战斗", "desc": "占位说明：远程射击，消耗箭矢。", "atk": 72, "dur": 55},
	{"name": "火把", "type": "照明", "desc": "占位说明：照亮黑暗区域，驱散部分敌怪。", "atk": 12, "dur": 40},
	{"name": "背包", "type": "功能", "desc": "占位说明：扩容携带格，提升负重上限。", "atk": 0, "dur": 70},
	{"name": "水壶", "type": "功能", "desc": "占位说明：储存饮水，缓解口渴值消耗。", "atk": 0, "dur": 60},
]

const COLOR_STATUS_OK := Color(0.55, 0.78, 0.36)
const COLOR_STATUS_WAIT := Color(0.62, 0.63, 0.68)

@onready var tab_detail: Button = $RightPanel/TabBar/TabDetail
@onready var tab_tools: Button = $RightPanel/TabBar/TabTools
@onready var detail_page: Control = $RightPanel/DetailPage
@onready var tools_page: Control = $RightPanel/ToolsPage

@onready var char_slots: Array = [
	$CharList/List/Slot1,
	$CharList/List/Slot2,
	$CharList/List/Slot3,
	$CharList/List/Slot4,
	$CharList/List/Slot5,
	$CharList/List/Slot6,
]
@onready var char_scroll: ScrollContainer = $CharList
@onready var arrow: Label = $ArrowIndicator
@onready var name_label: Label = $NameTag/Label
@onready var model_root: Node3D = $ModelPreview/SubViewport/CharacterPlaceholder

@onready var tool_slots: Array = [
	$RightPanel/ToolsPage/ToolScroll/ToolGrid/Tool1,
	$RightPanel/ToolsPage/ToolScroll/ToolGrid/Tool2,
	$RightPanel/ToolsPage/ToolScroll/ToolGrid/Tool3,
	$RightPanel/ToolsPage/ToolScroll/ToolGrid/Tool4,
	$RightPanel/ToolsPage/ToolScroll/ToolGrid/Tool5,
	$RightPanel/ToolsPage/ToolScroll/ToolGrid/Tool6,
]
@onready var info_text: Label = $RightPanel/ToolsPage/ToolInfo/VBox/InfoText
@onready var attack_bar: ProgressBar = $RightPanel/ToolsPage/ToolInfo/VBox/AttackRow/AttackBar
@onready var attack_val: Label = $RightPanel/ToolsPage/ToolInfo/VBox/AttackRow/AttackVal
@onready var durability_bar: ProgressBar = $RightPanel/ToolsPage/ToolInfo/VBox/DurabilityRow/DurabilityBar
@onready var durability_val: Label = $RightPanel/ToolsPage/ToolInfo/VBox/DurabilityRow/DurabilityVal

@onready var btn_confirm: Button = $BtnConfirm
@onready var p1_status: Label = $TeamSlots/P1/Status

var selected_char := 0
var selected_tool := 0
var confirmed := false

var _char_slot_selected: StyleBox
var _char_slot_normal: StyleBox
var _tool_slot_selected: StyleBox
var _tool_slot_normal: StyleBox


func _ready() -> void:
	tab_detail.pressed.connect(_show_tab.bind(0))
	tab_tools.pressed.connect(_show_tab.bind(1))
	btn_confirm.pressed.connect(_toggle_confirm)

	# 框选样式来源：Slot1/Tool1 当前是选中态描边，Slot2/Tool2 是普通态
	_char_slot_selected = char_slots[0].get_theme_stylebox("normal")
	_char_slot_normal = char_slots[1].get_theme_stylebox("normal")
	_tool_slot_selected = tool_slots[0].get_theme_stylebox("normal")
	_tool_slot_normal = tool_slots[1].get_theme_stylebox("normal")

	for i in char_slots.size():
		char_slots[i].pressed.connect(_select_character.bind(i))
	for i in tool_slots.size():
		tool_slots[i].pressed.connect(_select_tool.bind(i))

	_apply_tool(selected_tool)
	# 等容器布局完成后再定位箭头（首帧时容器尚未排布）
	_apply_character.call_deferred(selected_char)


func _process(_delta: float) -> void:
	# 箭头每帧跟随选中头像：滚动列表、布局变化时都会自动跟上
	if selected_char < char_slots.size():
		var slot: Control = char_slots[selected_char]
		arrow.global_position.y = slot.global_position.y + (slot.size.y - arrow.size.y) * 0.5


func _show_tab(index: int) -> void:
	detail_page.visible = index == 0
	tools_page.visible = index == 1
	tab_detail.button_pressed = index == 0
	tab_tools.button_pressed = index == 1


## ---- 角色选择：箭头跟随 + 框选跟随 + 模型配色 + 名称联动 ----

func _select_character(index: int) -> void:
	selected_char = index
	_apply_character(index)


func _apply_character(index: int) -> void:
	for i in char_slots.size():
		var style := _char_slot_selected if i == index else _char_slot_normal
		char_slots[i].add_theme_stylebox_override("normal", style)
		char_slots[i].add_theme_stylebox_override("hover", style)
		char_slots[i].add_theme_stylebox_override("pressed", style)

	# 选中的头像滚出可视区时自动滚回可见位置（箭头本身由 _process 每帧跟随）
	char_scroll.ensure_control_visible(char_slots[index])

	# 占位模型换色（正式接入后改为：删除旧模型实例、实例化对应角色场景）
	var colors: Array = CHAR_COLORS[index]
	_set_model_colors(colors[0], colors[1], colors[2])

	name_label.text = CHAR_NAMES[index]


func _set_model_colors(body_c: Color, head_c: Color, leg_c: Color) -> void:
	var body: MeshInstance3D = model_root.get_node("Body")
	var head: MeshInstance3D = model_root.get_node("Head")
	var legs := [model_root.get_node("LegL"), model_root.get_node("LegR")]
	(body.get_surface_override_material(0) as StandardMaterial3D).albedo_color = body_c
	(head.get_surface_override_material(0) as StandardMaterial3D).albedo_color = head_c
	for leg in legs:
		(leg.get_surface_override_material(0) as StandardMaterial3D).albedo_color = leg_c


## ---- 工具选择：框选跟随 + 属性面板联动 ----

func _select_tool(index: int) -> void:
	selected_tool = index
	_apply_tool(index)


func _apply_tool(index: int) -> void:
	for i in tool_slots.size():
		var style := _tool_slot_selected if i == index else _tool_slot_normal
		tool_slots[i].add_theme_stylebox_override("normal", style)
		tool_slots[i].add_theme_stylebox_override("hover", style)
		tool_slots[i].add_theme_stylebox_override("pressed", style)

	var data: Dictionary = TOOL_DATA[index]
	info_text.text = "工具名称：%s\n\n类型：%s\n\n作用：%s" % [data["name"], data["type"], data["desc"]]
	attack_bar.value = data["atk"]
	attack_val.text = "%d / 100" % data["atk"]
	durability_bar.value = data["dur"]
	durability_val.text = "%d / 100" % data["dur"]


## ---- 确认 / 取消确认：按钮文字与 1P 状态同步 ----

func _toggle_confirm() -> void:
	confirmed = not confirmed
	btn_confirm.text = "取消确认" if confirmed else "确认"
	btn_confirm.modulate = Color(1.0, 0.85, 0.85) if confirmed else Color.WHITE
	p1_status.text = "已确认" if confirmed else "选择中…"
	p1_status.add_theme_color_override("font_color", COLOR_STATUS_OK if confirmed else COLOR_STATUS_WAIT)
