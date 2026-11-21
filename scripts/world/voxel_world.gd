extends Node3D
## 运行时体素世界。
## 结构：起始空腔（矿车停靠）+ 前方整段矿道被矿体填满，必须由玩家挖开。
## 只砌远侧（-X）的矿壁，近侧（+X）敞开 —— 相机在近侧往远看，砌墙会挡住视线。
## 矿车进入矿层后，把「矿车前缘往后」那一段里没挖掉的方块直接隐藏（挖空式剖面），
## 免得挡住后面要挖的矿；前方待挖的矿始终保持实体。

const BLOCK := 1.0
## 零缩放 + 挪到远处，等价于隐藏该实例
var _hidden_xf := Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3(0, -9999, 0))

@export var rng_seed: int = 20261120
@export var interior_half_width: int = 4   # 内部半宽（块），4 => 9 格宽
@export var interior_height: int = 6       # 填矿高度（块）
@export var tunnel_length: int = 40        # 纵深（块）
@export var z_start: int = 6               # 起始空腔尾端 z
@export var chamber_length: int = 7        # 起始空腔长度
@export var cutaway_behind: float = 9.0    # 矿车前缘往后多远内的未挖方块要隐藏
@export var cutaway_min_height: int = 2    # 只隐藏这个高度以上的方块，保住通道两侧的矮墙
## +X 侧最后生成到哪一列。相机在 +X 侧往 -X 看，所以这一侧不砌墙，否则全被挡住。
@export var near_edge_cell: int = 1

signal block_broken(pos: Vector3i, key: String)

var grid: Dictionary = {}                  # Vector3i -> String
var _index: Dictionary = {}                # Vector3i -> int（MultiMesh 下标）
var _solid: Dictionary = {}                # key -> MultiMesh
var _hidden: Dictionary = {}               # Vector3i -> true（被剖面隐藏）
var _rng := RandomNumberGenerator.new()
var _built := false


func _ready() -> void:
	if not _built:
		generate()


# ---------------------------------------------------------------- 生成

func generate() -> void:
	if _built:
		return
	_built = true
	_rng.seed = rng_seed
	_fill_grid()
	_build_visuals()


func chamber_end_z() -> int:
	return z_start - chamber_length + 1


func _fill_grid() -> void:
	var hw := interior_half_width
	var h := interior_height
	var z_lo := z_start - tunnel_length + 1
	var chamber_end := chamber_end_z()
	var near_edge := near_edge_cell   # +X 侧只铺到这一列，再往外不生成，留给侧向机位看进来

	# 地板铺满整个宽度（近侧也要有，否则侧视会在画面下方露出虚空）；
	# 矿壁和矿体只到 near_edge 为止。
	for k in range(z_lo, z_start + 1):
		for i in range(-hw - 1, hw + 1):
			grid[Vector3i(i, -1, k)] = _pick(0.05)
			grid[Vector3i(i, -2, k)] = _pick(0.05)
		for j in range(-2, h + 1):
			grid[Vector3i(-hw - 1, j, k)] = _pick(0.11)

	# 空腔之后整段堵死，玩家必须自己挖开
	for k in range(z_lo, chamber_end):
		for i in range(-hw, near_edge + 1):
			for j in range(0, h):
				grid[Vector3i(i, j, k)] = _pick(0.12)

	# 空腔尾墙，避免回望看到虚空
	for i in range(-hw - 1, hw + 1):
		for j in range(-2, h):
			grid[Vector3i(i, j, z_start + 1)] = _pick(0.08)


func _pick(ore_chance: float) -> String:
	if _rng.randf() < ore_chance:
		var r := _rng.randf()
		if r < 0.55:
			return "gold"
		elif r < 0.85:
			return "quartz"
		elif r < 0.95:
			return "diamond"
		return "emerald"
	return "stone_a" if _rng.randf() < 0.68 else "stone_b"


func _build_visuals() -> void:
	var by_key: Dictionary = {}
	for pos in grid:
		var key: String = grid[pos]
		if not by_key.has(key):
			by_key[key] = []
		by_key[key].append(pos)

	for key in by_key:
		var positions: Array = by_key[key]
		_solid[key] = _make_multimesh(positions, key)

		var s := MultiMeshInstance3D.new()
		s.name = "Solid_" + key
		s.multimesh = _solid[key]
		add_child(s)


func _make_multimesh(positions: Array, key: String) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3(BLOCK, BLOCK, BLOCK)
	box.material = _material(key)
	mm.mesh = box
	mm.instance_count = positions.size()

	for idx in positions.size():
		var p: Vector3i = positions[idx]
		mm.set_instance_transform(idx, Transform3D(Basis.IDENTITY, Vector3(p) * BLOCK))
		_index[p] = idx
	return mm


func _base_color(key: String) -> Color:
	match key:
		"gold":
			return Color(0.80, 0.60, 0.15)
		"quartz":
			return Color(0.85, 0.86, 0.90)
		"diamond":
			return Color(0.38, 0.78, 0.88)
		"emerald":
			return Color(0.25, 0.68, 0.42)
		"stone_b":
			return Color(0.272, 0.267, 0.296)
		_:
			return Color(0.335, 0.330, 0.355)


func _material(key: String) -> StandardMaterial3D:
	var base := _base_color(key)
	var m := StandardMaterial3D.new()
	m.albedo_color = base
	m.roughness = 0.92
	m.metallic = 0.05

	if key in ["gold", "quartz", "diamond", "emerald"]:
		m.emission_enabled = true
		m.emission = base * 0.6
		m.emission_energy_multiplier = 0.35
	return m


# ---------------------------------------------------------------- 剖面隐藏

func update_cutaway(center: Vector3, half_depth: float) -> void:
	## 只处理矿车「已经进入 / 已经走过」的那一段：从前缘往后 cutaway_behind 格。
	## 前方待挖的矿保持实体，那是接下来的目标，不能藏。
	var front_z := center.z - half_depth
	var back_z := center.z + cutaway_behind

	var want: Dictionary = {}
	var chamber_end := chamber_end_z()
	for pos in grid:
		if pos.y < cutaway_min_height:
			continue
		# 只对矿体做剖面，空腔和尾墙不动
		if pos.z >= chamber_end:
			continue
		var z := float(pos.z)
		if z >= front_z and z <= back_z:
			want[pos] = true

	for pos in want:
		if not _hidden.has(pos):
			_set_hidden(pos, true)

	for pos in _hidden.keys():
		if not want.has(pos) and grid.has(pos):
			_set_hidden(pos, false)


func _set_hidden(pos: Vector3i, on: bool) -> void:
	var key: String = grid.get(pos, "")
	if not _solid.has(key):
		return
	var idx: int = _index.get(pos, -1)
	if idx < 0:
		return
	var here := Transform3D(Basis.IDENTITY, Vector3(pos) * BLOCK)
	_solid[key].set_instance_transform(idx, _hidden_xf if on else here)
	if on:
		_hidden[pos] = true
	else:
		_hidden.erase(pos)


func hidden_count() -> int:
	return _hidden.size()


# ---------------------------------------------------------------- 碰撞查询

func cell_of(p: float) -> int:
	return floori(p + 0.5)


func _cells(a: float, b: float) -> Array[int]:
	var out: Array[int] = []
	for v in range(cell_of(a), cell_of(b - 0.0001) + 1):
		out.append(v)
	return out


func is_blocked_at(center: Vector3, half_w: float, half_d: float,
		y_min: float, y_max: float) -> bool:
	for i in _cells(center.x - half_w, center.x + half_w):
		for j in _cells(y_min, y_max):
			for k in _cells(center.z - half_d, center.z + half_d):
				if grid.has(Vector3i(i, j, k)):
					return true
	return false


# ---------------------------------------------------------------- 拾取 / 破坏

func raycast_block(origin: Vector3, dir: Vector3, max_dist: float = 60.0) -> Dictionary:
	## 体素 DDA：不依赖碰撞体，直接在网格里找第一个实心格。
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
		if grid.has(cell):
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


func has_block(pos: Vector3i) -> bool:
	return grid.has(pos)


func block_key(pos: Vector3i) -> String:
	return grid.get(pos, "")


func break_block(pos: Vector3i) -> bool:
	if not grid.has(pos):
		return false

	var key: String = grid[pos]
	var idx: int = _index.get(pos, -1)
	if _solid.has(key) and idx >= 0:
		_solid[key].set_instance_transform(idx, _hidden_xf)

	_hidden.erase(pos)
	grid.erase(pos)
	_index.erase(pos)

	block_broken.emit(pos, key)
	return true
