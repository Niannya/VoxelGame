extends RefCounted
## 矿洞示例场景生成器。
## 把块状矿洞写进指定的 Node3D 父节点，由 tools/bake_mine_demo.gd 调用后烘焙成静态场景。
## 后续要调尺寸 / 矿脉密度，改这里的参数重新烘焙即可。

const BLOCK := 1.0

# ---- 可调参数 ----
var rng_seed: int = 20261120
var interior_half_width: int = 4   # 通道内部半宽（块），4 => 内部 9 格宽
var interior_height: int = 6       # 通道内部高度（块）
var tunnel_length: int = 40        # 纵深（块）
var z_start: int = 6               # 起点 z（矿车后方）

var _rng := RandomNumberGenerator.new()
var _mats: Dictionary = {}         # key -> Material
var _meshes: Dictionary = {}       # key -> BoxMesh
var _xforms: Dictionary = {}       # key -> Array[Transform3D]


func build(parent: Node3D) -> void:
	_rng.seed = rng_seed
	_mats.clear()
	_meshes.clear()
	_xforms.clear()

	_make_materials()
	_build_shell()
	_build_face_wall()
	_build_props(parent)
	_build_collision(parent)
	_flush_blocks(parent)


# ---------------------------------------------------------------- 材质

func _make_materials() -> void:
	_mats["stone_a"] = _mat(Color(0.335, 0.330, 0.355), 0.95, 0.0)
	_mats["stone_b"] = _mat(Color(0.272, 0.267, 0.296), 0.95, 0.0)
	_mats["gold"] = _mat(Color(0.80, 0.60, 0.15), 0.30, 0.70, Color(0.55, 0.38, 0.05), 0.35)
	_mats["quartz"] = _mat(Color(0.85, 0.86, 0.90), 0.20, 0.10, Color(0.32, 0.34, 0.42), 0.25)
	_mats["diamond"] = _mat(Color(0.38, 0.78, 0.88), 0.12, 0.30, Color(0.10, 0.38, 0.48), 0.55)
	_mats["emerald"] = _mat(Color(0.25, 0.68, 0.42), 0.18, 0.25, Color(0.05, 0.30, 0.15), 0.45)
	_mats["wood"] = _mat(Color(0.36, 0.23, 0.13), 0.92, 0.0)
	_mats["metal"] = _mat(Color(0.45, 0.47, 0.52), 0.32, 0.85)
	_mats["steel"] = _mat(Color(0.52, 0.40, 0.29), 0.55, 0.55)
	_mats["iron"] = _mat(Color(0.17, 0.17, 0.19), 0.45, 0.80)
	_mats["ember"] = _mat(Color(1.0, 0.45, 0.12), 0.60, 0.0, Color(1.0, 0.42, 0.10), 3.0)


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


# ---------------------------------------------------------------- 块体

func _build_shell() -> void:
	var hw := interior_half_width
	var h := interior_height
	var z_lo := z_start - tunnel_length + 1

	for k in range(z_lo, z_start + 1):
		# 地面一整排
		for i in range(-hw - 1, hw + 2):
			_add(i, -1, k, _pick_floor())
		# 左右矿壁
		for j in range(-1, h + 1):
			_add(-hw - 1, j, k, _pick_wall())
			_add(hw + 1, j, k, _pick_wall())


func _build_face_wall() -> void:
	## 隧道尽头待挖的矿壁（对应策划案里"挖掉矿层才能前进"）
	var hw := interior_half_width
	var h := interior_height
	var z_lo := z_start - tunnel_length + 1
	for dz in [1, 2]:
		for i in range(-hw - 1, hw + 2):
			for j in range(-1, h + 1):
				_add(i, j, z_lo - dz, _pick_wall(0.22))


func _pick_floor() -> String:
	return _pick(0.05)


func _pick_wall(ore_bias: float = 0.11) -> String:
	return _pick(ore_bias)


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


func _add(i: int, j: int, k: int, key: String) -> void:
	if not _xforms.has(key):
		_xforms[key] = []
	_xforms[key].append(Transform3D(Basis.IDENTITY, Vector3(i, j, k) * BLOCK))


func _box(key: String) -> BoxMesh:
	if _meshes.has(key):
		return _meshes[key]
	var b := BoxMesh.new()
	b.size = Vector3(BLOCK, BLOCK, BLOCK)
	b.material = _mats[key]
	_meshes[key] = b
	return b


func _flush_blocks(parent: Node3D) -> void:
	var holder := Node3D.new()
	holder.name = "Blocks"
	parent.add_child(holder)

	for key in ["stone_a", "stone_b", "gold", "quartz", "diamond", "emerald"]:
		if not _xforms.has(key):
			continue
		var list: Array = _xforms[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _box(key)
		mm.instance_count = list.size()
		for idx in list.size():
			mm.set_instance_transform(idx, list[idx])
		var inst := MultiMeshInstance3D.new()
		inst.name = key.capitalize()
		inst.multimesh = mm
		holder.add_child(inst)


# ---------------------------------------------------------------- 碰撞

func _build_collision(parent: Node3D) -> void:
	## 用 4 个大盒子代替上千个方块碰撞体：直通道的形状完全等价，成本低得多。
	var hw := interior_half_width
	var h := interior_height
	var z_lo := z_start - tunnel_length + 1
	var length := float(tunnel_length) + 2.0
	var mid_z := (float(z_start) + float(z_lo)) * 0.5
	var wall_y := (h - 1) * 0.5

	var body := StaticBody3D.new()
	body.name = "Collision"
	parent.add_child(body)

	# 地面：方块层中心在 y=-1，顶面 -0.5
	_add_box(body, "Floor", Vector3(0, -1.0, mid_z), Vector3((hw + 1) * 2.0, 1.0, length))
	# 左右矿壁
	_add_box(body, "WallL", Vector3(-(hw + 1), wall_y, mid_z), Vector3(1.0, h + 2.0, length))
	_add_box(body, "WallR", Vector3(hw + 1, wall_y, mid_z), Vector3(1.0, h + 2.0, length))
	# 尽头待挖矿壁
	_add_box(body, "Face", Vector3(0, wall_y, z_lo - 1.0), Vector3((hw + 1) * 2.0, h + 2.0, 1.0))


func _add_box(body: StaticBody3D, nm: String, pos: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	cs.name = nm
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	body.add_child(cs)


# ---------------------------------------------------------------- 道具

func _build_props(parent: Node3D) -> void:
	var z_lo := float(z_start - tunnel_length + 2)
	var z_hi := float(z_start)
	_build_rails(parent, z_lo, z_hi)
	_build_supports(parent, z_lo)
	_build_cart(parent)
	_build_furnace(parent)
	_build_torches(parent, z_lo)


func _build_rails(parent: Node3D, z_lo: float, z_hi: float) -> void:
	var holder := Node3D.new()
	holder.name = "Rails"
	parent.add_child(holder)

	var length := z_hi - z_lo
	var mid_z := (z_hi + z_lo) * 0.5

	for side in [-1, 1]:
		var rail := MeshInstance3D.new()
		rail.name = "Rail_L" if side < 0 else "Rail_R"
		var b := BoxMesh.new()
		b.size = Vector3(0.14, 0.14, length)
		b.material = _mats["metal"]
		rail.mesh = b
		rail.position = Vector3(0.62 * side, -0.31, mid_z)
		holder.add_child(rail)

	# 枕木：一条 MultiMesh 铺满
	var tie_xf: Array[Transform3D] = []
	var z := z_lo
	while z <= z_hi:
		tie_xf.append(Transform3D(Basis.IDENTITY, Vector3(0, -0.43, z)))
		z += 1.6
	var tie_mesh := BoxMesh.new()
	tie_mesh.size = Vector3(2.2, 0.14, 0.34)
	tie_mesh.material = _mats["wood"]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = tie_mesh
	mm.instance_count = tie_xf.size()
	for idx in tie_xf.size():
		mm.set_instance_transform(idx, tie_xf[idx])
	var ties := MultiMeshInstance3D.new()
	ties.name = "Ties"
	ties.multimesh = mm
	holder.add_child(ties)


func _build_supports(parent: Node3D, z_lo: float) -> void:
	## 支撑柱：拆轨道枕木搭起来的木柱 + 顶部横梁（对应策划案的"承重与稳定"）
	var holder := Node3D.new()
	holder.name = "Supports"
	parent.add_child(holder)

	var hw := interior_half_width
	var z := float(z_start - 4)
	var idx := 1
	while z > z_lo + 2:
		var post_x := float(hw) + 0.35
		for side in [-1.0, 1.0]:
			var post := MeshInstance3D.new()
			post.name = "Post%d_%s" % [idx, "L" if side < 0 else "R"]
			var b := BoxMesh.new()
			b.size = Vector3(0.32, interior_height * BLOCK, 0.32)
			b.material = _mats["wood"]
			post.mesh = b
			post.position = Vector3(post_x * side, (interior_height - 1) * 0.5, z)
			holder.add_child(post)

		var beam := MeshInstance3D.new()
		beam.name = "Beam%d" % idx
		var bb := BoxMesh.new()
		bb.size = Vector3((hw + 0.9) * 2.0, 0.28, 0.34)
		bb.material = _mats["wood"]
		beam.mesh = bb
		beam.position = Vector3(0, interior_height - 0.65, z)
		holder.add_child(beam)

		z -= 8.0
		idx += 1


func _build_cart(parent: Node3D) -> void:
	## 矿车：车厢 + 四个轮子
	var cart := Node3D.new()
	cart.name = "Minecart"
	cart.position = Vector3(0, 0, 4)
	parent.add_child(cart)

	var body := MeshInstance3D.new()
	body.name = "Body"
	var bb := BoxMesh.new()
	bb.size = Vector3(1.9, 1.0, 2.6)
	bb.material = _mats["steel"]
	body.mesh = bb
	body.position = Vector3(0, 0.85, 0)
	cart.add_child(body)

	var inner := MeshInstance3D.new()
	inner.name = "InnerVoid"
	var ib := BoxMesh.new()
	ib.size = Vector3(1.5, 0.12, 2.2)
	ib.material = _mats["iron"]
	inner.mesh = ib
	inner.position = Vector3(0, 1.30, 0)
	cart.add_child(inner)

	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var wheel := MeshInstance3D.new()
			wheel.name = "Wheel_%s%s" % ["L" if sx < 0 else "R", "F" if sz < 0 else "B"]
			var wb := CylinderMesh.new()
			wb.top_radius = 0.30
			wb.bottom_radius = 0.30
			wb.height = 0.16
			wb.material = _mats["iron"]
			wheel.mesh = wb
			wheel.rotation_degrees = Vector3(0, 0, 90)
			wheel.position = Vector3(0.75 * sx, 0.04, 0.85 * sz)
			cart.add_child(wheel)


func _build_furnace(parent: Node3D) -> void:
	## 熔炉：投矿石换金币
	var furnace := Node3D.new()
	furnace.name = "Furnace"
	furnace.position = Vector3(-2.35, 0, 1.2)
	parent.add_child(furnace)

	var shell := MeshInstance3D.new()
	shell.name = "Shell"
	var sb := BoxMesh.new()
	sb.size = Vector3(1.5, 1.7, 1.5)
	sb.material = _mats["iron"]
	shell.mesh = sb
	shell.position = Vector3(0, 0.35, 0)
	furnace.add_child(shell)

	var mouth := MeshInstance3D.new()
	mouth.name = "Mouth"
	var mb := BoxMesh.new()
	mb.size = Vector3(0.9, 0.6, 0.12)
	mb.material = _mats["ember"]
	mouth.mesh = mb
	mouth.position = Vector3(0, 0.30, 0.76)
	furnace.add_child(mouth)

	var glow := OmniLight3D.new()
	glow.name = "Glow"
	glow.position = Vector3(0, 0.4, 1.0)
	glow.light_color = Color(1.0, 0.52, 0.22)
	glow.light_energy = 2.2
	glow.omni_range = 6.0
	glow.shadow_enabled = false
	furnace.add_child(glow)


func _build_torches(parent: Node3D, z_lo: float) -> void:
	var holder := Node3D.new()
	holder.name = "Torches"
	parent.add_child(holder)

	var hw := float(interior_half_width)
	var z := float(z_start - 6)
	var side := -1.0
	var idx := 1
	while z > z_lo + 2:
		var torch := Node3D.new()
		torch.name = "Torch%d" % idx
		torch.position = Vector3((hw + 0.55) * side, interior_height - 1.6, z)
		holder.add_child(torch)

		var stick := MeshInstance3D.new()
		stick.name = "Stick"
		var b := BoxMesh.new()
		b.size = Vector3(0.10, 0.55, 0.10)
		b.material = _mats["wood"]
		stick.mesh = b
		torch.add_child(stick)

		var flame := MeshInstance3D.new()
		flame.name = "Flame"
		var fb := BoxMesh.new()
		fb.size = Vector3(0.18, 0.22, 0.18)
		fb.material = _mats["ember"]
		flame.mesh = fb
		flame.position = Vector3(0, 0.36, 0)
		torch.add_child(flame)

		var light := OmniLight3D.new()
		light.name = "Light"
		light.position = Vector3(0, 0.42, 0)
		light.light_color = Color(1.0, 0.72, 0.38)
		light.light_energy = 3.4
		light.omni_range = 10.0
		light.omni_attenuation = 1.4
		light.shadow_enabled = true
		torch.add_child(light)

		z -= 10.0
		side = -side
		idx += 1
