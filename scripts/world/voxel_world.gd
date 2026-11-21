extends Node3D
## 运行时体素世界：持有方块网格数据、渲染用 MultiMesh、以及可破坏的碰撞体。
## 与烘焙版矿洞不同，这里每块方块都有坐标可查，才能做射线拾取和破坏。

const BLOCK := 1.0

@export var rng_seed: int = 20261120
@export var interior_half_width: int = 4   # 内部半宽（块），4 => 内部 9 格宽
@export var interior_height: int = 6       # 内部高度（块）
@export var tunnel_length: int = 40        # 纵深（块）
@export var z_start: int = 6               # 起点 z

signal block_broken(pos: Vector3i, key: String)

var grid: Dictionary = {}                  # Vector3i -> String（方块类型）
var _instance_index: Dictionary = {}       # Vector3i -> int（在对应 MultiMesh 里的下标）
var _multimeshes: Dictionary = {}          # key -> MultiMesh
var _collisions: Dictionary = {}           # Vector3i -> CollisionShape3D
var _mats: Dictionary = {}
var _shared_box_shape: BoxShape3D
var _body: StaticBody3D
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

	_make_materials()
	_fill_grid()
	_build_visuals()
	_build_collision()


func _fill_grid() -> void:
	var hw := interior_half_width
	var h := interior_height
	var z_lo := z_start - tunnel_length + 1

	for k in range(z_lo, z_start + 1):
		for i in range(-hw - 1, hw + 2):
			# 地板铺两层：挖穿第一层能看见下面的岩层，而不是直接露出虚空
			grid[Vector3i(i, -1, k)] = _pick(0.05)
			grid[Vector3i(i, -2, k)] = _pick(0.05)
		for j in range(-2, h + 1):
			grid[Vector3i(-hw - 1, j, k)] = _pick(0.11)
			grid[Vector3i(hw + 1, j, k)] = _pick(0.11)

	# 尽头待挖的矿壁
	for dz in [1, 2]:
		for i in range(-hw - 1, hw + 2):
			for j in range(-2, h + 1):
				grid[Vector3i(i, j, z_lo - dz)] = _pick(0.22)


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


func _make_materials() -> void:
	_mats["stone_a"] = _mat(Color(0.335, 0.330, 0.355), 0.95, 0.0)
	_mats["stone_b"] = _mat(Color(0.272, 0.267, 0.296), 0.95, 0.0)
	_mats["gold"] = _mat(Color(0.80, 0.60, 0.15), 0.30, 0.70, Color(0.55, 0.38, 0.05), 0.35)
	_mats["quartz"] = _mat(Color(0.85, 0.86, 0.90), 0.20, 0.10, Color(0.32, 0.34, 0.42), 0.25)
	_mats["diamond"] = _mat(Color(0.38, 0.78, 0.88), 0.12, 0.30, Color(0.10, 0.38, 0.48), 0.55)
	_mats["emerald"] = _mat(Color(0.25, 0.68, 0.42), 0.18, 0.25, Color(0.05, 0.30, 0.15), 0.45)


func _mat(albedo: Color, roughness: float, metallic: float,
		emission: Color = Color.BLACK, emission_energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = roughness
	m.metallic = metallic
	if emission_energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = emission_energy
	return m


func _build_visuals() -> void:
	# 先按类型分组，才能一次分配固定 instance_count
	var by_key: Dictionary = {}
	for pos in grid:
		var key: String = grid[pos]
		if not by_key.has(key):
			by_key[key] = []
		by_key[key].append(pos)

	for key in by_key:
		var positions: Array = by_key[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var box := BoxMesh.new()
		box.size = Vector3(BLOCK, BLOCK, BLOCK)
		box.material = _mats[key]
		mm.mesh = box
		mm.instance_count = positions.size()
		for idx in positions.size():
			var p: Vector3i = positions[idx]
			mm.set_instance_transform(idx, Transform3D(Basis.IDENTITY, Vector3(p) * BLOCK))
			_instance_index[p] = idx
		var inst := MultiMeshInstance3D.new()
		inst.name = "Blocks_" + key
		inst.multimesh = mm
		add_child(inst)
		_multimeshes[key] = mm


func _build_collision() -> void:
	_shared_box_shape = BoxShape3D.new()
	_shared_box_shape.size = Vector3(BLOCK, BLOCK, BLOCK)

	_body = StaticBody3D.new()
	_body.name = "BlockCollision"
	add_child(_body)

	# 只给「露在空气里」的方块建碰撞体，内部的看不见也摸不到
	for pos in grid:
		if _is_exposed(pos):
			_ensure_collision(pos)


func _is_exposed(pos: Vector3i) -> bool:
	return not grid.has(pos + Vector3i.UP) \
		or not grid.has(pos + Vector3i.DOWN) \
		or not grid.has(pos + Vector3i.LEFT) \
		or not grid.has(pos + Vector3i.RIGHT) \
		or not grid.has(pos + Vector3i.FORWARD) \
		or not grid.has(pos + Vector3i.BACK)


func _ensure_collision(pos: Vector3i) -> void:
	if _collisions.has(pos):
		return
	var cs := CollisionShape3D.new()
	cs.shape = _shared_box_shape
	cs.position = Vector3(pos) * BLOCK
	_body.add_child(cs)
	_collisions[pos] = cs


func _drop_collision(pos: Vector3i) -> void:
	if _collisions.has(pos):
		_collisions[pos].queue_free()
		_collisions.erase(pos)


# ---------------------------------------------------------------- 拾取 / 破坏

func raycast_block(origin: Vector3, dir: Vector3, max_dist: float = 60.0) -> Dictionary:
	## 体素 DDA 遍历：不依赖碰撞体，直接在网格里找第一个实心格。
	## 返回 {hit: bool, pos: Vector3i, normal: Vector3i}
	if dir.length_squared() < 0.000001:
		return {"hit": false}

	var d := dir.normalized()
	# 方块 i 覆盖 [i-0.5, i+0.5)，平移到 q=p+0.5 后正好是 [i, i+1)
	var o := origin + Vector3(0.5, 0.5, 0.5)
	var cell := Vector3i(floori(o.x), floori(o.y), floori(o.z))
	var step := Vector3i(_axis_step(d.x), _axis_step(d.y), _axis_step(d.z))
	var t_delta := Vector3(
		_inv_or_inf(d.x), _inv_or_inf(d.y), _inv_or_inf(d.z))
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
	var idx: int = _instance_index.get(pos, -1)
	var mm: MultiMesh = _multimeshes.get(key)
	if mm != null and idx >= 0:
		# 缩到零并把实例挪远，等价于隐藏（直接减 instance_count 会打乱下标）
		mm.set_instance_transform(idx, Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -9999, 0)))

	_drop_collision(pos)
	grid.erase(pos)
	_instance_index.erase(pos)

	# 破开之后邻居暴露出来，补上碰撞体
	for offset in [Vector3i.UP, Vector3i.DOWN, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
		var n: Vector3i = pos + offset
		if grid.has(n):
			_ensure_collision(n)

	block_broken.emit(pos, key)
	return true
