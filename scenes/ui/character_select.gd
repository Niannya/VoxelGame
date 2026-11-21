extends Control
## 角色选择界面 · 占位交互脚本
## 包含：页签切换 / 角色选择（箭头+框选+模型颜色+名称联动）/ 工具选择（框选+属性联动）/ 确认切换
## 程序接入后可整体替换或逐个函数改造，数据结构见下方常量。

const CHAR_NAMES := ["角色名1", "角色名2", "角色名3", "角色名4", "角色名5", "角色名6"]
## 每个角色的模型（glTF 2.0 二进制 .glb，Godot 会自动导入为场景）
## 换成正式模型时只改这里；模型会自动脚底贴地台、XZ 居中
const CHAR_MODELS := [
	"res://assets/characters/char_01_cuntou.glb",
	"res://assets/characters/char_02_baimao.glb",
	"res://assets/characters/char_03_fenmao.glb",
	"res://assets/characters/char_04_lanmao.glb",
	"res://assets/characters/char_05_huangmao.glb",
	"res://assets/characters/char_06_hemao.glb",
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
@onready var model_holder: Node3D = $ModelPreview/SubViewport/CharacterPlaceholder/ModelHolder
@onready var preview: SubViewportContainer = $ModelPreview
@onready var cam: Camera3D = $ModelPreview/SubViewport/Camera3D

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
	preview.gui_input.connect(_on_preview_gui_input)
	# 模型等比放大 + 相机一次摆好（之后相机不动，地台固定）
	model_holder.scale = Vector3.ONE * MODEL_SCALE
	_setup_camera()
	# 等容器布局完成后再定位箭头（首帧时容器尚未排布）
	_apply_character.call_deferred(selected_char)


func _process(delta: float) -> void:
	# 待机呼吸：把正弦相位写给模型材质里的着色器（只动上半身，脚不动）
	if _breath_mat != null:
		_breath_time += delta
		_breath_mat.set_shader_parameter("breath", sin(_breath_time * TAU / BREATH_PERIOD))

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

	# 切换模型：删除旧实例、实例化对应角色的 glb
	_apply_model(index)

	name_label.text = CHAR_NAMES[index]


## ---- 模型展示：只让模型原地转台自转，相机与地台完全固定 ----

var _model_instance: Node3D = null
var _rot_y := 0.0        ## 模型绕竖直轴(Y)的自转角度：只转这一轴，脚永远踩在地台上
var _dragging := false

## ---- 待机呼吸（顶点着色器）----
## 不依赖骨骼：着色器按高度分带做位移，腰以下权重为 0，所以脚始终贴地台。
const BREATH_SHADER := preload("res://scenes/ui/shaders/voxel_breathing.gdshader")
const BREATH_PERIOD := 3.6    ## 一次完整呼吸的秒数（吸气 ~1.8s、呼气 ~1.8s）
var _breath_mat: ShaderMaterial = null
var _breath_time := 0.0

const ROT_SENS := 0.012      ## 每像素自转弧度
## MODEL_YAW：模型资源自身的朝向修正。这 6 个 MagicaVoxel 模型导出后默认背对镜头，
## 统一转 180° 让角色正面朝观众；换新模型时若朝向不对，只改这一个值。
const MODEL_YAW := PI
## 模型整体等比放大：让头顶到预览框上沿附近（1.0 = 原始 2.2 米高）
const MODEL_SCALE := 1.35
## 相机固定不动（地台不会跟着动）：位置与视线目标都写死
const CAM_POS := Vector3(0.0, 0.0, 0.0)
const CAM_LOOK_AT := Vector3(0.0, 0.16, -3.4)   ## 模型中心（地台顶面 -0.94 + 身高 2.2/2）


func _apply_model(index: int) -> void:
	if _model_instance and is_instance_valid(_model_instance):
		_model_instance.queue_free()
		_model_instance = null

	var path: String = CHAR_MODELS[index]
	if not ResourceLoader.exists(path):
		push_warning("模型缺失：" + path)
		return

	var packed := load(path) as PackedScene
	if packed == null:
		push_warning("模型无法加载：" + path)
		return

	var inst := packed.instantiate() as Node3D
	if inst == null:
		return
	model_holder.add_child(inst)
	_model_instance = inst

	# 统一摆放：XZ 居中、脚底贴 ModelHolder 的 y=0（即地台顶面）
	var box := _subtree_aabb(inst)
	if box.size != Vector3.ZERO:
		inst.position = Vector3(
			-(box.position.x + box.size.x * 0.5),
			-box.position.y,
			-(box.position.z + box.size.z * 0.5)
		)

	# 呼吸效果：给模型套一个顶点着色器材质（脚底锁定，只动上半身）
	_apply_breathing(inst, box)

	# 换角色时把视角复位到正面
	_rot_y = 0.0
	_apply_rotation()


## 给模型的所有 MeshInstance3D 换上呼吸材质。
## box 是模型自身空间的包围盒，用来告诉着色器"脚底在哪、有多高"，换模型无需改参数。
func _apply_breathing(root: Node, box: AABB) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = BREATH_SHADER
	mat.set_shader_parameter("base_y", box.position.y)
	mat.set_shader_parameter("model_height", box.size.y)
	_breath_mat = mat
	for node in root.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = mat


## 递归合并子树里所有 MeshInstance3D 的包围盒（相对传入节点）
func _subtree_aabb(node: Node, xform := Transform3D.IDENTITY) -> AABB:
	var result := AABB()
	var has := false
	for child in node.get_children():
		var t := xform
		if child is Node3D:
			t = xform * (child as Node3D).transform
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			var b: AABB = t * (child as MeshInstance3D).get_aabb()
			if not has:
				result = b
				has = true
			else:
				result = result.merge(b)
		var sub := _subtree_aabb(child, t)
		if sub.size != Vector3.ZERO:
			if not has:
				result = sub
				has = true
			else:
				result = result.merge(sub)
	return result


func _apply_rotation() -> void:
	# 只绕 Y（竖直轴）旋转：模型在原地转台自转，脚底不会离地、不会歪倒
	model_holder.rotation = Vector3(0.0, MODEL_YAW + _rot_y, 0.0)


func _setup_camera() -> void:
	# 相机一次性摆好、之后不再移动：地台因此始终固定在画面同一位置
	cam.position = CAM_POS
	cam.look_at(CAM_LOOK_AT, Vector3.UP)


func _on_preview_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		# 左右拖动 -> 模型绕竖直轴自转（相机与地台保持不动）
		_rot_y -= mm.relative.x * ROT_SENS
		_apply_rotation()


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
