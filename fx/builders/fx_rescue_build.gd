extends RefCounted
## 救援链：FX025 复苏成功反馈（FX024 救援进行是持续型控制器，见 fx_rescue.gd）。

const RING_SHADER := preload("res://fx/shaders/ring.gdshader")


func fx025(opts: Dictionary) -> Node3D:
	var root := Node3D.new()
	var color: Color = opts.get("color", FxPalette.SUCCESS)
	var player = opts.get("player", null)

	# 先给一次极短的白色"回过神"，紧接青绿扩散 —— 与受击的红白瞬闪刻意区分
	if is_instance_valid(player):
		FxFlash.flash(player, 0.55, 0.05, 0.16, color)

	# ① 双环：一个快、一个慢，做出"扩散 + 余波"的层次
	var rm_fast := ShaderMaterial.new()
	rm_fast.shader = RING_SHADER
	rm_fast.set_shader_parameter("color", color)
	rm_fast.set_shader_parameter("thickness", 0.09)
	rm_fast.set_shader_parameter("strength", 1.5)
	rm_fast.set_shader_parameter("grit", 0.15)
	var q1 := QuadMesh.new()
	q1.size = Vector2(1.4, 1.4)
	q1.orientation = PlaneMesh.FACE_Y
	var ring1 := FxUtil.mesh_instance(q1, rm_fast, Vector3(0, 0.03, 0))
	root.add_child(ring1)

	var rm_slow := ShaderMaterial.new()
	rm_slow.shader = RING_SHADER
	rm_slow.set_shader_parameter("color", color)
	rm_slow.set_shader_parameter("thickness", 0.16)
	rm_slow.set_shader_parameter("strength", 0.7)
	rm_slow.set_shader_parameter("grit", 0.4)
	var q2 := QuadMesh.new()
	q2.size = Vector2(2.2, 2.2)
	q2.orientation = PlaneMesh.FACE_Y
	var ring2 := FxUtil.mesh_instance(q2, rm_slow, Vector3(0, 0.02, 0))
	root.add_child(ring2)

	# ② 光柱：人物被"拉起来"的竖向读法
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_mat.albedo_texture = FxUtil.beam_texture()
	beam_mat.albedo_color = Color(color.r, color.g, color.b, 0.6)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.10
	cyl.bottom_radius = 0.30
	cyl.height = 1.9
	cyl.radial_segments = 6
	cyl.rings = 1
	cyl.material = beam_mat
	var beam := FxUtil.mesh_instance(cyl, null, Vector3(0, 0.95, 0))
	root.add_child(beam)

	# ③ 上浮光点
	var motes := FxUtil.particles({
		"amount": 18,
		"lifetime": 0.75,
		"explosiveness": 0.55,
		"randomness": 0.8,
		"mesh": FxUtil.quad(0.09, FxUtil.billboard_material(color, true, FxUtil.dot_texture())),
		"shape": CPUParticles3D.EMISSION_SHAPE_SPHERE,
		"sphere_radius": 0.3,
		"direction": Vector3.UP,
		"spread": 22.0,
		"gravity": Vector3(0, 1.8, 0),
		"vmin": 1.2,
		"vmax": 2.6,
		"damping_min": 0.4,
		"damping_max": 1.0,
		"smin": 0.6,
		"smax": 1.2,
		"color_ramp": FxUtil.ramp([
			Color(color.r, color.g, color.b, 0.0),
			Color(0.9, 1.0, 0.98, 1.0),
			Color(color.r, color.g, color.b, 0.0),
		], [0.0, 0.2, 1.0]),
	})
	motes.name = "ReviveMotes"
	motes.position.y = 0.15
	root.add_child(motes)
	FxUtil.emit_once(motes)

	FxUtil.on_start(root, func():
		FxUtil.tween_param(root, rm_fast, "progress", 0.02, 1.0, 0.4)
		FxUtil.tween_param(root, rm_slow, "progress", 0.0, 1.0, 0.85)
		var tw := root.create_tween().set_parallel(true)
		tw.tween_property(beam, "scale", Vector3(1.0, 1.0, 1.0), 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).from(Vector3(0.3, 0.1, 0.3))
		FxUtil.tween_alpha(root, beam_mat, 0.6, 0.0, 0.55, 0.15)
	)
	return root
