## 关卡美术资产槽位（这是给美术/TA 的接口，不是给程序的）。
##
## 用法：新建一个 .tres（基于本资源），把每一项填上就换皮完成；
## 留空的槽位会走程序占位（灰色方块、内置材质），**不会崩**，也不会卡住玩法。
##
## 每个槽位期望的资产类型见 Docs/Dev/美术资产空位清单.md。
## 换皮不需要改任何代码：把 .tres 挂到 LevelVoxelRenderer.art 即可。
@tool
class_name LevelArtTheme
extends Resource

## 必须存在的方块 id，缺了会在编辑器里报"缺槽"。
const REQUIRED_BLOCKS: Array[StringName] = [&"stone_a", &"stone_b", &"bedrock"]

## 方块外观：id -> Mesh。建议 1×1×1 的立方体对齐（原点在中心）。
## 例：stone_a 用带倒角的岩石块，bedrock 用更暗的岩壁。
@export var block_meshes: Dictionary = {}
## 方块外观：id -> Material。留空则用内置纯色材质。
@export var block_materials: Dictionary = {}

## 裂纹叠层：下标 0 = 第 1 档（进度 1/3），依次加深。
## 留空则用"方块轻微缩放"做占位反馈（能玩，但不好看）。
@export var crack_meshes: Array[Mesh] = []

## 破坏碎屑粒子场景（可选）。留空则不播粒子。
@export var debris_scene: PackedScene = null
## 破坏音效（可选）。
@export var break_sound: AudioStream = null

## L03 轨道外观：单格枕木+钢轨的整段 Mesh（1×1 格长）。
@export var rail_mesh: Mesh = null
## L03 支撑柱外观（1×1 底面积，高度按实际拉长）。
@export var support_mesh: Mesh = null
## L04 矿车外观：整台车一个 Mesh，原点在车厢地面中心。
@export var cart_mesh: Mesh = null
## L04 矿车材质（可选）。
@export var cart_material: Material = null


## 返回还没填的方块槽位，给编辑器工具和自检用。
func missing_block_slots() -> Array[StringName]:
	var missing: Array[StringName] = []
	for id in REQUIRED_BLOCKS:
		if not block_meshes.has(id) or block_meshes[id] == null:
			missing.append(id)
	return missing


## 有多少槽位已填 / 总共多少（给"美术进度"面板用）。
func filled_ratio() -> float:
	var total := REQUIRED_BLOCKS.size() + 4
	var filled := 0
	for id in REQUIRED_BLOCKS:
		if block_meshes.has(id) and block_meshes[id] != null:
			filled += 1
	if not crack_meshes.is_empty():
		filled += 1
	if rail_mesh != null:
		filled += 1
	if support_mesh != null:
		filled += 1
	if cart_mesh != null:
		filled += 1
	return float(filled) / float(total)
