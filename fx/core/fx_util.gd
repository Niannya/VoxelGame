class_name FxUtil
extends RefCounted
## 特效基元工厂：贴图、材质、网格、粒子。
##
## 全库不依赖任何 PNG 贴图：柔光点、尘团全部由 GradientTexture2D 程序化生成，
## 碎片 / 尘条 / 火花全部是 Mesh 粒子（方块与四边形），贴合体素美术且零贴图加载。

static var _tex := {}


# ── 贴图 ──────────────────────────────────────────────────────
static func dot_texture() -> Texture2D:
	## 柔光圆点：中心实心、边缘渐隐。用于尘团、光点、火花。
	if _tex.has("dot"):
		return _tex["dot"]
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.52, Color(1, 1, 1, 0.72))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 64
	t.height = 64
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	_tex["dot"] = t
	return t


static func beam_texture() -> Texture2D:
	## 竖向光柱贴图：底部实、顶部渐隐。用于 FX017 搭建光柱、FX025 复苏光柱。
	if _tex.has("beam"):
		return _tex["beam"]
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.42))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 8
	t.height = 64
	t.fill = GradientTexture2D.FILL_LINEAR
	t.fill_from = Vector2(0.5, 0.0)
	t.fill_to = Vector2(0.5, 1.0)
	_tex["beam"] = t
	return t


static func chip_texture() -> Texture2D:
	## 硬边方块：用于"体素碎片"式火花，边缘 1px 抗锯齿。
	if _tex.has("chip"):
		return _tex["chip"]
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 32
	t.height = 32
	t.fill = GradientTexture2D.FILL_SQUARE
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	_tex["chip"] = t
	return t


# ── 材质 ──────────────────────────────────────────────────────
static func unshaded_alpha(color: Color, additive := false, tex: Texture2D = null) -> StandardMaterial3D:
	## 粒子通用材质：不参与光照、顶点色（粒子 color_ramp）作为 albedo。
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	m.albedo_texture = tex
	m.disable_receive_shadows = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


static func billboard_material(color: Color, additive := false, tex: Texture2D = null) -> StandardMaterial3D:
	var m := unshaded_alpha(color, additive, tex)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.no_depth_test = false
	return m


static func lit_material(color: Color) -> StandardMaterial3D:
	## 碎片用的受光材质：方块有明暗面，才有体积感。
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.92
	m.metallic_specular = 0.18
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func emissive_material(color: Color, energy := 1.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.roughness = 0.55
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	return m


static func shader_material(path: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	return m


# ── 网格 ──────────────────────────────────────────────────────
static func box(size: Vector3, mat: Material = null) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	if mat:
		b.material = mat
	return b


static func quad(size: float, mat: Material = null) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	if mat:
		q.material = mat
	return q


static func ring_quad(size: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	# QuadMesh 默认立在 XY 平面，绕 X 转 -90° 让 UV 贴地
	q.orientation = PlaneMesh.FACE_Y
	return q


# ── 粒子 ──────────────────────────────────────────────────────
static func particles(cfg: Dictionary) -> CPUParticles3D:
	## 统一的 CPUParticles3D 装配（兼容 GL Compatibility，不依赖 compute）。
	## 用 CPU 粒子而非 GPU 粒子：本库粒子数均 < 120，CPU 足够，且 Compatibility / 移动端行为完全一致。
	var p := CPUParticles3D.new()
	p.amount = int(cfg.get("amount", 12))
	p.lifetime = float(cfg.get("lifetime", 0.6))
	p.one_shot = bool(cfg.get("one_shot", true))
	p.explosiveness = float(cfg.get("explosiveness", 0.92))
	p.randomness = float(cfg.get("randomness", 0.55))
	p.local_coords = bool(cfg.get("local_coords", false))
	p.emitting = false
	p.fixed_fps = 0
	p.mesh = cfg.get("mesh", null)

	p.emission_shape = int(cfg.get("shape", CPUParticles3D.EMISSION_SHAPE_POINT))
	p.emission_sphere_radius = float(cfg.get("sphere_radius", 0.1))
	var ext: Vector3 = cfg.get("box_extents", Vector3(0.1, 0.05, 0.1))
	p.emission_box_extents = ext

	p.direction = cfg.get("direction", Vector3.UP)
	p.spread = float(cfg.get("spread", 60.0))
	p.flatness = float(cfg.get("flatness", 0.0))
	p.gravity = cfg.get("gravity", Vector3(0, -9.8, 0))
	p.initial_velocity_min = float(cfg.get("vmin", 1.0))
	p.initial_velocity_max = float(cfg.get("vmax", 2.0))
	p.scale_amount_min = float(cfg.get("smin", 1.0))
	p.scale_amount_max = float(cfg.get("smax", 1.0))
	p.damping_min = float(cfg.get("damping_min", 0.0))
	p.damping_max = float(cfg.get("damping_max", 0.0))
	p.angular_velocity_min = float(cfg.get("spin_min", 0.0))
	p.angular_velocity_max = float(cfg.get("spin_max", 0.0))

	if cfg.has("color_ramp"):
		p.color_ramp = cfg["color_ramp"]

	if cfg.has("scale_curve"):
		p.scale_amount_curve = cfg["scale_curve"]

	if bool(cfg.get("align_y", false)):
		p.particle_flag_align_y = true

	var off: Vector3 = cfg.get("position", Vector3.ZERO)
	p.position = off
	return p


static func ramp(colors: Array, offsets: Array = []) -> Gradient:
	## 便捷构造粒子生命曲线：ramp([Color(c,1), Color(c,0)]) 即"出生不透明→死亡消失"。
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	var n := colors.size()
	for i in n:
		var off := float(i) / float(max(n - 1, 1)) if offsets.is_empty() else float(offsets[i])
		offs.append(off)
		cols.append(colors[i])
	var g := Gradient.new()
	g.offsets = offs
	g.colors = cols
	return g


static func curve(points: Array) -> Curve:
	## points: [[offset, value], ...]，用于粒子缩放曲线（如"先胀后缩"）。
	var c := Curve.new()
	for p in points:
		c.add_point(Vector2(float(p[0]), float(p[1])))
	c.bake_resolution = 24
	return c


# ── 节点 ──────────────────────────────────────────────────────
static func mesh_instance(mesh: Mesh, mat: Material = null, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if mat:
		mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func label3d(text: String, size := 48, color := Color.WHITE) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.modulate = color
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.shaded = false
	l.pixel_size = 0.0022
	l.render_priority = 4
	return l


static func tween_free(node: Node, delay: float) -> void:
	var scene := node.get_tree()
	if scene == null:
		return
	scene.create_timer(max(delay, 0.01)).timeout.connect(func():
		if is_instance_valid(node):
			node.queue_free()
	)


# ── 生命周期回调 ──────────────────────────────────────────────
# 特效节点由 builder 在"还没进场景树"时搭好，因此补间与粒子启动不能直接调，
# 统一登记成 on_start 回调，由 FxManager 在 add_child 之后执行。

static func on_start(root: Node, fn: Callable) -> void:
	var arr: Array = root.get_meta("_fx_start", [])
	arr.append(fn)
	root.set_meta("_fx_start", arr)


static func run_start(root: Node) -> void:
	## 递归执行整棵子树的启动回调：emit_once 这类回调登记在粒子子节点上，
	## play() 只拿得到根节点，必须递归才能全部触发。
	_run_start_one(root)
	for c in root.get_children():
		run_start(c)


static func _run_start_one(n: Node) -> void:
	if not n.has_meta("_fx_start"):
		return
	var arr: Array = n.get_meta("_fx_start")
	n.remove_meta("_fx_start")
	for fn in arr:
		if fn is Callable:
			fn.call()


static func emit_once(p: CPUParticles3D) -> void:
	## 一次性发射：restart() 会重置发射状态并立刻喷一轮。
	on_start(p, func():
		if is_instance_valid(p):
			p.restart()
	)


static func loop_from(p: CPUParticles3D, preheat := 0.8) -> void:
	## 持续发射：预热一段时间，出现时就已经是满的，不会"从空开始长出来"。
	p.preprocess = preheat
	on_start(p, func():
		if is_instance_valid(p):
			p.emitting = true
	)


static func tween_param(host: Node, mat: ShaderMaterial, param: String, from: float, to: float, dur: float,
		trans := Tween.TRANS_QUAD, ease_type := Tween.EASE_OUT) -> Tween:
	var tw := host.create_tween()
	tw.tween_method(func(v): mat.set_shader_parameter(param, v), from, to, maxf(dur, 0.01)) \
		.set_trans(trans).set_ease(ease_type)
	return tw


static func tween_scale(host: Node, node: Node3D, from: Vector3, to: Vector3, dur: float,
		trans := Tween.TRANS_BACK, ease_type := Tween.EASE_OUT) -> Tween:
	node.scale = from
	var tw := host.create_tween()
	tw.tween_property(node, "scale", to, maxf(dur, 0.01)).set_trans(trans).set_ease(ease_type)
	return tw


static func tween_alpha(host: Node, mat: StandardMaterial3D, from: float, to: float, dur: float,
		delay := 0.0) -> Tween:
	var c := mat.albedo_color
	mat.albedo_color = Color(c.r, c.g, c.b, from)
	var tw := host.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(_apply_alpha.bind(mat), from, to, maxf(dur, 0.01))
	return tw


static func _apply_alpha(a: float, mat: StandardMaterial3D) -> void:
	if not is_instance_valid(mat):
		return
	var c := mat.albedo_color
	mat.albedo_color = Color(c.r, c.g, c.b, a)
