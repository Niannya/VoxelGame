## 矿道生成器（L02 的地形侧）：决定"这一段矿洞长什么样"。
##
## 做成 Resource 是为了将来能存成 .tres 给不同层/不同关卡复用，
## 也让"生成规则"和"格子存储"（LevelVoxelGrid）分开——想换生成算法不用动网格代码。
##
## 目前只生成首测playground的形态：起始空腔 + 前方被矿体堵死的矿道 + 近侧敞开。
@tool
class_name LevelMineGenerator
extends Resource

## 内部半宽（格）。4 => 9 格宽。
@export var interior_half_width: int = 4
## 填矿高度（格）。
@export var interior_height: int = 6
## 纵深（格）。
@export var tunnel_length: int = 40
## 起始空腔尾端的 z。
@export var z_start: int = 6
## 起始空腔长度（格）。
@export var chamber_length: int = 7
## +X 侧最后生成到哪一列（相机在 +X 侧，不砌墙）。
@export var near_edge_cell: int = 1
@export var rng_seed: int = 20261120

## 普通岩石的候选 id（随机挑一个，纯表现差异）。
@export var stone_ids: Array[StringName] = [&"stone_a", &"stone_b"]
## 边界的不可破坏方块 id。
@export var boundary_id: StringName = &"bedrock"

var _rng := RandomNumberGenerator.new()


func build(grid: LevelVoxelGrid, state: LevelState) -> void:
	_rng.seed = rng_seed
	var hw := interior_half_width
	var h := interior_height
	var z_lo := z_start - tunnel_length + 1
	var chamber_end := z_start - chamber_length + 1

	# 地板：铺满整个宽度（含近侧，否则侧视会露出虚空）
	for k in range(z_lo, z_start + 1):
		for i in range(-hw - 1, hw + 1):
			_put(grid, state, Vector3i(i, -1, k))
			_put(grid, state, Vector3i(i, -2, k))
		# 远侧外壳：不可破坏
		for j in range(-2, h + 1):
			_put_boundary(grid, state, Vector3i(-hw - 1, j, k))

	# 空腔之后整段堵死，玩家必须自己挖开
	for k in range(z_lo, chamber_end):
		for i in range(-hw, near_edge_cell + 1):
			for j in range(0, h):
				_put(grid, state, Vector3i(i, j, k))

	# 空腔尾墙，避免回望看到虚空
	for i in range(-hw - 1, hw + 1):
		for j in range(-2, h):
			_put(grid, state, Vector3i(i, j, z_start + 1))


func _depth_for(state: LevelState, z: int) -> int:
	return 1 if state == null else state.depth_at_z(float(z))


func _put(grid: LevelVoxelGrid, state: LevelState, pos: Vector3i) -> void:
	var id: StringName = &"stone_a"
	if not stone_ids.is_empty():
		id = stone_ids[_rng.randi_range(0, stone_ids.size() - 1)]
	grid.set_cell(pos, id, _depth_for(state, pos.z))


func _put_boundary(grid: LevelVoxelGrid, state: LevelState, pos: Vector3i) -> void:
	grid.set_cell(pos, boundary_id, _depth_for(state, pos.z))
