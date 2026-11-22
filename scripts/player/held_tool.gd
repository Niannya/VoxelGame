class_name HeldTool
extends Node3D
## 角色手里拿的基础镐子：体素拼的，跟手走。
##
## 挂载结构：`Skeleton3D → BoneAttachment3D(arm.R) → Grip(沿骨骼偏移到手掌) → 本节点`
## - BoneAttachment3D 每帧被骨骼姿态覆盖，所以**偏移必须放在它的子节点 Grip 上**；
## - 朝向不跟骨骼（骨骼局部轴很歪，镐子会插进身体），改成每帧按角色朝向 + 固定前倾重建，
##   只借骨骼的位置，这样挥镐时镐子跟着手走、但不会歪着戳进肚子。
##
## 造型是 BoxMesh 拼的体素镐；要换正式模型就把 `_build()` 换成加载 glb。

const HANDLE_COLOR := Color(0.44, 0.29, 0.16)
const HEAD_COLOR := Color(0.66, 0.67, 0.70)
const HEAD_TIP_COLOR := Color(0.48, 0.49, 0.53)

## 绑哪根骨骼
const BONE := &"arm.R"
## 沿骨骼方向偏移到手掌（arm.R 约 0.43 单位长）
const HAND_ALONG_BONE := 0.34
## 没有骨骼时用的右手位置（相对包围盒的比例：x 向右、y 向上、z 向前）
const HAND_RATIO := Vector3(0.33, 0.40, -0.02)
## 镐子前倾角（度）
const PITCH_DEG := -18.0
## 往角色正前方挪一点，别让镐柄埋进胸口。
## basis.z 在 yaw=180° 时是 (0,0,-1)，所以负值才是"朝角色正面"（超镜头方向）。
const FORWARD_OFFSET := -0.26
## 整把镐的缩放倍率（相对角色身高单位）
const TOOL_SCALE := 0.9

const HANDLE_SIZE := Vector3(0.06, 0.52, 0.06)
const HEAD_SIZE := Vector3(0.36, 0.08, 0.08)
const TIP_SIZE := Vector3(0.15, 0.075, 0.075)
const TIP_ANGLE := 30.0

var _tool_index := 0
var _model: Node3D
var _grip: Node3D


static func attach_to(model: Node3D, tool_index: int = 0) -> Node3D:
	if model == null:
		return null

	var old := model.find_child("ToolHand", true, false)
	if old != null:
		old.queue_free()

	var hand: Node3D
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D

	if skeleton != null and skeleton.find_bone(BONE) >= 0:
		# 有骨骼：挂在 arm.R 上，跟着骨骼一起动
		var bone := BoneAttachment3D.new()
		bone.name = "ToolHand"
		bone.bone_name = BONE
		skeleton.add_child(bone)
		hand = bone
		hand.set_meta("grip_pos", Vector3(0.0, HAND_ALONG_BONE, 0.0))
	else:
		# 没有骨骼（静态网格版本的角色）：按包围盒比例放到右手
		# 模型正面朝 -Z、脚底在 y=0，所以右手在 +X 一侧、胸口偏下的高度
		var anch := Node3D.new()
		anch.name = "ToolHand"
		model.add_child(anch)
		hand = anch
		var box := _model_bounds(model)
		if box.size.y > 0.0:
			hand.set_meta("grip_pos", Vector3(
				box.position.x + box.size.x * (0.5 + HAND_RATIO.x),
				box.position.y + box.size.y * HAND_RATIO.y,
				box.position.z + box.size.z * (0.5 + HAND_RATIO.z)))
		else:
			hand.set_meta("grip_pos", Vector3(0.42, 1.0, -0.2))

	# 偏移放在子节点上（BoneAttachment3D 自身的变换会被骨骼姿态覆盖）
	var grip := Node3D.new()
	grip.name = "Grip"
	grip.position = hand.get_meta("grip_pos", Vector3(0.0, HAND_ALONG_BONE, 0.0))
	hand.add_child(grip)

	var tool := HeldTool.new()
	tool.name = "BasicPickaxe"
	tool._tool_index = tool_index
	tool._model = model
	tool._grip = grip
	grip.add_child(tool)
	tool._build()
	return tool


static func _model_bounds(node: Node, xform := Transform3D.IDENTITY) -> AABB:
	## 模型自身的包围盒（模型局部坐标，用于没有骨骼时找手的位置）
	var result := AABB()
	var found := false
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var b: AABB = (node as MeshInstance3D).get_aabb()
		result = b
		found = true
	for child in node.get_children():
		var sub := _model_bounds(child)
		if sub.size != Vector3.ZERO:
			result = sub if not found else result.merge(sub)
			found = true
	return result


func _process(_delta: float) -> void:
	if _grip == null or _model == null:
		return
	# 只借位置；朝向按"角色朝向 + 固定前倾"重建，避免骨骼局部轴把镐子拧进身体
	var basis := Basis.from_euler(Vector3(deg_to_rad(PITCH_DEG), _model.global_rotation.y, 0.0))
	var origin := _grip.global_position + basis.z * FORWARD_OFFSET
	global_transform = Transform3D(basis.scaled(Vector3.ONE * TOOL_SCALE), origin)


func _build() -> void:
	# 休息姿态：镐头握在手边、柄向下垂，镐头就不会顶到胸口和下巴
	_add_box(Vector3(0.0, -0.20, 0.0), HANDLE_SIZE, HANDLE_COLOR)

	# 镐头沿 Z 轴（前后方向）伸，握在手里时不会横穿身体、镐尖正对矿面
	var head_y := 0.075
	_add_box(Vector3(0.0, head_y, 0.0), Vector3(HEAD_SIZE.y, HEAD_SIZE.y, HEAD_SIZE.x), HEAD_COLOR)
	for side in [-1.0, 1.0]:
		var tip := _add_box(Vector3(0.0, head_y, 0.19 * side), Vector3(TIP_SIZE.y, TIP_SIZE.y, TIP_SIZE.x), HEAD_TIP_COLOR)
		tip.rotation_degrees.x = TIP_ANGLE * side


func _add_box(pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mat.metallic = 0.2 if color != HANDLE_COLOR else 0.0
	box.material = mat
	mi.mesh = box
	mi.position = pos
	add_child(mi)
	return mi
