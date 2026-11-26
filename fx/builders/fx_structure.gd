extends RefCounted
## 支撑搭建链：FX017 支撑搭建完成反馈。

const RING_SHADER := preload("res://fx/shaders/ring.gdshader")


func fx017(opts: Dictionary) -> Node3D:
	var root := Node3D.new()
	var color: Color = opts.get("color", FxPalette.VALID)
	var height: float = opts.get("height", 1.5)
	var footprint: float = opts.get("footprint", 1.5)

	# ① 贴地环：从结构脚下向外扩散，0.55s 收干净
	var rm := ShaderMaterial.new()
	rm.shader = RING_SHADER
	rm.set_shader_parameter("color", color)
	rm.set_shader_parameter("thickness", 0.09)
	rm.set_shader_parameter("strength", 1.2)
	rm.set_shader_parameter("grit", 0.2)
	var q := QuadMesh.new()
	q.size = Vector2(footprint, footprint)
	q.orientation = PlaneMesh.FACE_Y
	var ring := FxUtil.mesh_instance(q, rm, Vector3(0, 0.03, 0))
	ring.name = "BuildRing"
	root.add_child(ring)

	# ② 光柱：0.45s 内升起再收掉，不留在场上（不干扰后续 UI 辨识）
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_mat.albedo_texture = FxUtil.beam_texture()
	beam_mat.albedo_color = Color(color.r, color.g, color.b, 0.55)
	var cyl := CylinderMesh.new()
	cyl.top_radius = footprint * 0.11
	cyl.bottom_radius = footprint * 0.17
	cyl.height = height
	cyl.radial_segments = 6      # 六棱柱，贴合体素风
	cyl.rings = 1
	cyl.material = beam_mat
	var beam := FxUtil.mesh_instance(cyl, null, Vector3(0, height * 0.5, 0))
	beam.name = "BuildBeam"
	root.add_child(beam)

	# ③ 四角防滑钉火花：把"四角都固定住了"这件事讲明白
	var sparks := Node3D.new()
	sparks.name = "CornerSparks"
	root.add_child(sparks)
	var spark_mat := FxUtil.unshaded_alpha(color, true)
	var half := footprint * 0.34
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var s := FxUtil.mesh_instance(FxUtil.box(Vector3(0.05, 0.16, 0.05), spark_mat),
				null, Vector3(half * sx, 0.09, half * sz))
			s.set_meta("_fx_no_flash", true)
			sparks.add_child(s)

	# ④ 一点落地尘，别让"凭空出现"感太强
	var dust := FxUtil.particles({
		"amount": 8,
		"lifetime": 0.55,
		"explosiveness": 0.5,
		"randomness": 0.9,
		"mesh": FxUtil.quad(0.3, FxUtil.billboard_material(FxPalette.DUST, false, FxUtil.dot_texture())),
		"shape": CPUParticles3D.EMISSION_SHAPE_BOX,
		"box_extents": Vector3(footprint * 0.4, 0.02, footprint * 0.4),
		"direction": Vector3.UP,
		"spread": 80.0,
		"gravity": Vector3(0, 0.2, 0),
		"vmin": 0.3,
		"vmax": 0.7,
		"damping_min": 1.0,
		"damping_max": 1.8,
		"smin": 1.0,
		"smax": 1.0,
		"scale_curve": FxUtil.curve([[0.0, 0.5], [0.5, 1.4], [1.0, 1.8]]),
		"color_ramp": FxUtil.ramp([
			Color(FxPalette.DUST.r, FxPalette.DUST.g, FxPalette.DUST.b, 0.0),
			Color(FxPalette.DUST.r, FxPalette.DUST.g, FxPalette.DUST.b, 0.13),
			Color(FxPalette.DUST.r, FxPalette.DUST.g, FxPalette.DUST.b, 0.0),
		], [0.0, 0.2, 1.0]),
	})
	dust.name = "BuildDust"
	dust.position.y = 0.05
	root.add_child(dust)
	FxUtil.emit_once(dust)

	FxUtil.on_start(root, func():
		FxUtil.tween_param(root, rm, "progress", 0.02, 1.0, 0.55)
		var tw := root.create_tween().set_parallel(true)
		tw.tween_property(beam, "scale", Vector3(1.0, 1.0, 1.0), 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).from(Vector3(0.2, 0.05, 0.2))
		tw.tween_property(beam, "scale", Vector3(0.6, 1.15, 0.6), 0.22).set_delay(0.24)
		FxUtil.tween_alpha(root, beam_mat, 0.55, 0.0, 0.3, 0.18)
		for child in sparks.get_children():
			var tw2 := root.create_tween()
			tw2.tween_property(child, "position:y", 0.42, 0.34) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw2.parallel().tween_property(child, "scale", Vector3(0.01, 0.01, 0.01), 0.34).set_delay(0.08)
	)
	return root
