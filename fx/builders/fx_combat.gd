extends RefCounted
## 战斗 / 受击链：FX011 工具命中反馈、FX014 怪物死亡消散。
## （FX012 / FX013 闪白与 FX033 墙体淡化是"贴附型"，见 fx_flash.gd / fx_wall_occluder.gd）

const RING_SHADER := preload("res://fx/shaders/ring.gdshader")


# ── FX011 工具命中反馈 ────────────────────────────────────────
func fx011(opts: Dictionary) -> Node3D:
	var root := Node3D.new()
	var normal: Vector3 = opts.get("normal", Vector3.UP)
	if normal.length() < 0.1:
		normal = Vector3.UP

	# 命中星：一个朝向镜头的暖白亮点，0.16s 内炸开再收
	var star_mat := FxUtil.billboard_material(Color(1.0, 0.98, 0.90), true, FxUtil.dot_texture())
	var star := FxUtil.mesh_instance(FxUtil.quad(FxPalette.S_IMPACT, star_mat))
	star.name = "ImpactStar"
	root.add_child(star)

	# 十字裂纹：两片细长条，体素风格的"叮"一下
	var cross := Node3D.new()
	cross.name = "ImpactCross"
	root.add_child(cross)
	var bar_mat := FxUtil.unshaded_alpha(FxPalette.SPARK, true)
	for i in 2:
		var bar := FxUtil.mesh_instance(FxUtil.box(Vector3(0.26, 0.014, 0.014), bar_mat))
		bar.rotation_degrees.z = 45.0 if i == 0 else -45.0
		bar.set_meta("_fx_no_flash", true)
		cross.add_child(bar)

	# 定向碎屑：法线方向为主，规模小、速度快，读作"打到了"
	var chips := FxUtil.particles({
		"amount": 5,
		"lifetime": 0.26,
		"explosiveness": 1.0,
		"randomness": 0.6,
		"mesh": FxUtil.box(Vector3(0.042, 0.042, 0.042), FxUtil.lit_material(Color.WHITE)),
		"shape": CPUParticles3D.EMISSION_SHAPE_SPHERE,
		"sphere_radius": 0.05,
		"direction": normal,
		"spread": 42.0,
		"gravity": Vector3(0, -10.0, 0),
		"vmin": 1.9,
		"vmax": 3.2,
		"smin": 0.55,
		"smax": 1.0,
		"spin_min": -420.0,
		"spin_max": 420.0,
		"color_ramp": FxUtil.ramp([
			Color(1.0, 0.93, 0.75),
			Color(0.85, 0.78, 0.62),
			Color(0.75, 0.7, 0.6, 0.0),
		], [0.0, 0.5, 1.0]),
	})
	chips.name = "ImpactChips"
	root.add_child(chips)
	FxUtil.emit_once(chips)

	FxUtil.on_start(root, func():
		var tw := root.create_tween().set_parallel(true)
		tw.tween_property(star, "scale", Vector3(1.1, 1.1, 1.1), 0.14) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).from(Vector3(0.35, 0.35, 0.35))
		tw.tween_property(cross, "scale", Vector3(1.5, 1.5, 1.5), 0.16).from(Vector3(0.6, 0.6, 0.6))
		tw.tween_property(cross, "rotation_degrees:z", 26.0, 0.2)
		tw.tween_property(cross, "position:z", 0.0, 0.2)
		FxUtil.tween_alpha(root, star_mat, 1.0, 0.0, 0.18, 0.04)
		FxUtil.tween_alpha(root, bar_mat, 0.95, 0.0, 0.16, 0.02)
	)
	return root


# ── FX014 怪物死亡消散 ────────────────────────────────────────
func fx014(opts: Dictionary) -> Node3D:
	var root := Node3D.new()
	var tint: Color = opts.get("tint", Color("#8C6BC8"))
	var body = opts.get("body", null)
	var ground_y: float = opts.get("ground_y", -0.45)

	root.add_user_signal("body_gone")

	# 体素式死亡：y 轴压扁 → 整体缩到 0（不改材质，不留半透明残影）
	if is_instance_valid(body):
		FxUtil.on_start(root, func():
			var tw := root.create_tween()
			tw.tween_property(body, "scale", Vector3(1.18, 0.10, 1.18), 0.24) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tw.tween_property(body, "scale", Vector3(0.02, 0.02, 0.02), 0.14)
			tw.tween_callback(func(): root.emit_signal("body_gone"))
		)

	# 22 块同色方块向上飘散 —— 尸体"散成体素"
	var puff := FxUtil.particles({
		"amount": 22,
		"lifetime": 0.52,
		"explosiveness": 0.75,
		"randomness": 0.85,
		"mesh": FxUtil.box(Vector3(0.075, 0.075, 0.075), FxUtil.emissive_material(Color.WHITE, 0.85)),
		"shape": CPUParticles3D.EMISSION_SHAPE_SPHERE,
		"sphere_radius": 0.28,
		"direction": Vector3.UP,
		"spread": 80.0,
		"gravity": Vector3(0, 1.5, 0),
		"vmin": 0.7,
		"vmax": 2.1,
		"damping_min": 1.2,
		"damping_max": 2.2,
		"smin": 0.7,
		"smax": 1.3,
		"scale_curve": FxUtil.curve([[0.0, 1.0], [0.7, 0.75], [1.0, 0.0]]),
		"spin_min": -260.0,
		"spin_max": 260.0,
		"color_ramp": FxUtil.ramp([
			tint,
			tint,
			Color(tint.r, tint.g, tint.b, 0.0),
		], [0.0, 0.55, 1.0]),
	})
	puff.name = "DeathVoxels"
	puff.position = Vector3(0, 0.15, 0)
	root.add_child(puff)
	FxUtil.emit_once(puff)

	# 贴地暗色环：把"这里死了一只"标记在地面上，掉落物仍在环内清晰可见
	var rm := ShaderMaterial.new()
	rm.shader = RING_SHADER
	rm.set_shader_parameter("color", tint)
	rm.set_shader_parameter("thickness", 0.14)
	rm.set_shader_parameter("strength", 0.7)
	var q := QuadMesh.new()
	q.size = Vector2(1.35, 1.35)
	q.orientation = PlaneMesh.FACE_Y
	var ring := FxUtil.mesh_instance(q, rm, Vector3(0, ground_y + 0.03, 0))
	ring.name = "DeathRing"
	root.add_child(ring)
	FxUtil.on_start(root, func():
		FxUtil.tween_param(root, rm, "progress", 0.05, 1.0, 0.5)
	)
	return root
