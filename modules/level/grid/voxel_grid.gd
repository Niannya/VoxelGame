## L01 矿洞格子：唯一的方块数据与挖掘结算入口。
##
## 这个类**不碰任何渲染**。谁想画方块，订阅 `cell_changed` 自己画（见 LevelVoxelRenderer）。
## 这样"挖了什么"和"长什么样"可以分开改、分开测。
##
## 给其他模块的调用面（别用别的）：
##   apply_mining(cells, power, miner) -> Array[Dictionary]   # P04 挖掘提交
##   raycast_block(origin, dir, max_dist) -> Dictionary      # P03 瞄准
##   is_blocked_at(center, half_w, half_d, y_min, y_max)     # L04 通行判定
##   has_block / block_id_at / cell_depth / progress_ratio   # 只读查询
##   signals: cell_changed / block_damaged / block_broken / cell_cleared
##
## 不变量：
## - 每格最多保存 1 件基础掉落，只在进度到阈值的那一次结算。
## - is_boundary 的方块永远不会被破坏，也不会产生掉落。
## - 格子被破坏后立即从 _cells 移除，`cell_cleared` 与 `block_broken` 同时发出。
class_name LevelVoxelGrid
extends Node

## 单元格状态有任何变化（新增 / 破坏）都会发。
signal cell_changed(cell: Vector3i)
## 挖了但没挖穿。ratio 是 0～1 的进度比例，表现层用它换裂纹档位。
signal block_damaged(cell: Vector3i, ratio: float)
## 挖穿了。drops 是本次结算出的基础掉落（0 或 1 件）。
signal block_broken(cell: Vector3i, block_id: StringName, drops: Array)
## 通路清开（L03 铺轨、L04 通行都听这个）。
signal cell_cleared(cell: Vector3i)


## 一格的运行期状态。位置是字典的键，所以这里不存坐标。
class Cell:
	var id: StringName
	var progress: float
	var depth: int

	func _init(p_id: StringName, p_depth: int) -> void:
		id = p_id
		depth = p_depth


@export var block_types: Array[LevelBlockType] = []
@export var loot_table: LevelLootTable
@export var rng_seed: int = 20261120
## 生成器负责"矿道长什么样"，网格只负责存。留空则不生成。
@export var generator: LevelMineGenerator
## 深度来源（L02）。留空则所有格子按第 1 层结算。
@export var level_state: LevelState
@export var auto_generate: bool = true

var _cells: Dictionary = {}
var _by_id: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _generated := false


func _ready() -> void:
	_rng.seed = rng_seed
	if level_state == null:
		level_state = get_node_or_null("../LevelState") as LevelState
	# 场景没手工填数据时用首测默认值，保证"拖进场景就能跑"
	if block_types.is_empty():
		block_types = LevelDefaults.block_types()
	if loot_table == null:
		loot_table = LevelDefaults.loot_table()
	if generator == null:
		generator = LevelDefaults.generator()
	_rebuild_id_index()
	if auto_generate and generator != null and not _generated:
		generate()


## 方块类型表重建（改了 block_types 之后调用）。
func _rebuild_id_index() -> void:
	_by_id.clear()
	for bt in block_types:
		if bt == null:
			continue
		if _by_id.has(bt.id):
			push_warning("重复的方块 id: %s" % bt.id)
		_by_id[bt.id] = bt


func get_block_type(id: StringName) -> LevelBlockType:
	return _by_id.get(id)


func generate() -> void:
	if _generated or generator == null:
		return
	_generated = true
	generator.build(self, level_state)


# ---------------------------------------------------------------- 写入

## 生成器 / 测试专用：直接放一格。会发 cell_changed。
func set_cell(cell: Vector3i, block_id: StringName, depth: int = 1) -> void:
	if not _by_id.has(block_id):
		push_warning("未知方块 id: %s" % block_id)
	_cells[cell] = Cell.new(block_id, depth)
	cell_changed.emit(cell)


## 生成器 / 测试专用：清掉一格，不结算掉落。
func clear_cell(cell: Vector3i) -> void:
	if _cells.erase(cell):
		cell_changed.emit(cell)
		cell_cleared.emit(cell)


## P04 挖掘提交。
## power 是破岩词条，例如 {"stone": 1.0, "ore": 0.5}；
## 取不到对应类别时回退到 "default"（默认 1.0）。
## 返回逐格结果：[{cell, destroyed, ratio, drops}]，表现层据此播动画。
func apply_mining(cells: Array, power: Dictionary, miner: Node = null) -> Array:
	var results: Array = []
	for c in cells:
		var pos := c as Vector3i
		var cell: Cell = _cells.get(pos)
		if cell == null:
			continue
		var bt: LevelBlockType = _by_id.get(cell.id)
		if bt == null or bt.is_boundary:
			continue

		var amount := _power_for(bt, power)
		if amount <= 0.0:
			continue

		cell.progress += amount
		var need: float = maxf(bt.hardness, 0.001)
		if cell.progress >= need:
			var drops := _destroy(pos, cell)
			results.append({"cell": pos, "destroyed": true, "ratio": 1.0, "drops": drops})
		else:
			var ratio: float = clampf(cell.progress / need, 0.0, 1.0)
			block_damaged.emit(pos, ratio)
			results.append({"cell": pos, "destroyed": false, "ratio": ratio, "drops": []})
	return results


func _power_for(bt: LevelBlockType, power: Dictionary) -> float:
	if power.has(bt.category):
		return float(power[bt.category])
	if power.has(&"default"):
		return float(power[&"default"])
	return 1.0


func _destroy(pos: Vector3i, cell: Cell) -> Array:
	var drops: Array = []
	if loot_table != null:
		var entry: LevelLootEntry = loot_table.roll(cell.depth, _rng)
		if entry != null:
			drops.append({
				"item_id": entry.item_id,
				"display_name": entry.display_name,
				"price": entry.price,
				"tier": entry.tier,
				"is_natural_mineral": entry.is_natural_mineral,
			})

	var block_id := cell.id
	_cells.erase(pos)
	cell_changed.emit(pos)
	cell_cleared.emit(pos)
	block_broken.emit(pos, block_id, drops)
	return drops


# ---------------------------------------------------------------- 只读查询

func has_block(cell: Vector3i) -> bool:
	return _cells.has(cell)


func block_id_at(cell: Vector3i) -> StringName:
	var cell_state: Cell = _cells.get(cell)
	return &"" if cell_state == null else cell_state.id


func cell_depth(cell: Vector3i) -> int:
	var cell_state: Cell = _cells.get(cell)
	return 1 if cell_state == null else cell_state.depth


## 0～1；格子不存在时返回 0。
func progress_ratio(cell: Vector3i) -> float:
	var cell_state: Cell = _cells.get(cell)
	if cell_state == null:
		return 0.0
	var bt: LevelBlockType = _by_id.get(cell_state.id)
	if bt == null:
		return 0.0
	return clampf(cell_state.progress / maxf(bt.hardness, 0.001), 0.0, 1.0)


func cell_count() -> int:
	return _cells.size()


## 所有格子的坐标（渲染层和存档用；不要拿来改数据）。
func cell_positions() -> Array:
	return _cells.keys()


## 按方块 id 分组的坐标（渲染层一次性铺 MultiMesh 用）。
func cells_by_id() -> Dictionary:
	var out: Dictionary = {}
	for pos in _cells:
		var cell_state: Cell = _cells[pos]
		if not out.has(cell_state.id):
			out[cell_state.id] = []
		out[cell_state.id].append(pos)
	return out


## 包围盒是否被方块占据（L04 通行判定）。
func is_blocked_at(center: Vector3, half_w: float, half_d: float,
		y_min: float, y_max: float) -> bool:
	for i in _cells_of(center.x - half_w, center.x + half_w):
		for j in _cells_of(y_min, y_max):
			for k in _cells_of(center.z - half_d, center.z + half_d):
				if _cells.has(Vector3i(i, j, k)):
					return true
	return false


## 盒内所有实心格（L04 用来标"是哪几块挡住车"）。
func solid_cells_in(center: Vector3, half_w: float, half_d: float,
		y_min: float, y_max: float) -> Array:
	var out: Array = []
	for i in _cells_of(center.x - half_w, center.x + half_w):
		for j in _cells_of(y_min, y_max):
			for k in _cells_of(center.z - half_d, center.z + half_d):
				var pos := Vector3i(i, j, k)
				if _cells.has(pos):
					out.append(pos)
	return out


# ---------------------------------------------------------------- 拾取

## 体素 DDA。不依赖碰撞体，能精确选中方块本身。
func raycast_block(origin: Vector3, dir: Vector3, max_dist: float = 60.0) -> Dictionary:
	if dir.length_squared() < 0.000001:
		return {"hit": false}

	var d := dir.normalized()
	var o := origin + Vector3(0.5, 0.5, 0.5)
	var cell := Vector3i(floori(o.x), floori(o.y), floori(o.z))
	var step := Vector3i(_axis_step(d.x), _axis_step(d.y), _axis_step(d.z))
	var t_delta := Vector3(_inv_or_inf(d.x), _inv_or_inf(d.y), _inv_or_inf(d.z))
	var t_max := Vector3(
		_first_t(o.x, cell.x, d.x), _first_t(o.y, cell.y, d.y), _first_t(o.z, cell.z, d.z))

	var normal := Vector3i.ZERO
	for _i in 256:
		if _cells.has(cell):
			return {"hit": true, "pos": cell, "normal": normal}

		if t_max.x < t_max.y and t_max.x < t_max.z:
			if t_max.x > max_dist:
				break
			cell.x += step.x
			t_max.x += t_delta.x
			normal = Vector3i(-step.x, 0, 0)
		elif t_max.y < t_max.z:
			if t_max.y > max_dist:
				break
			cell.y += step.y
			t_max.y += t_delta.y
			normal = Vector3i(0, -step.y, 0)
		else:
			if t_max.z > max_dist:
				break
			cell.z += step.z
			t_max.z += t_delta.z
			normal = Vector3i(0, 0, -step.z)

	return {"hit": false}


func _cells_of(a: float, b: float) -> Array[int]:
	var out: Array[int] = []
	for v in range(floori(a + 0.5), floori(b - 0.0001 + 0.5) + 1):
		out.append(v)
	return out


func _axis_step(v: float) -> int:
	if v > 0.0:
		return 1
	if v < 0.0:
		return -1
	return 0


func _inv_or_inf(v: float) -> float:
	if is_zero_approx(v):
		return INF
	return absf(1.0 / v)


func _first_t(o: float, cell: int, d: float) -> float:
	if d > 0.0:
		return (float(cell) + 1.0 - o) / d
	if d < 0.0:
		return (o - float(cell)) / -d
	return INF
