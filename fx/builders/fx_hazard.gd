extends RefCounted
## 危险 / 坍塌链：FX019 小落石、FX021 大落石（FX019 放大变体）、FX022 坍塌尘雾（FX018 体积变体）。

const RING_SHADER := preload("res://fx/shaders/ring.gdshader")


# ── FX019 / FX021 落石（同一实现，两档强度）────────────────────
func fx019(opts: Dictionary) -> Node3D:
	return _rockfall(opts, false)


func fx021(opts: Dictionary) -> Node3D:
	return _rockfall(opts, true)


func _rockfall(opts: Dictionary, big: bool) -> Node3D:
	var root := Node3D.new()
	var count: int = int(opts.get("count", 15 if big else 5))
	var area: float = float(opts.get("area", 3.2 if big else 1.5))
	var fall_h: float = float(opts.get("fall_height", 3.6 if big else 2.6))
	var s_min := 0.18 if big else 0.055
	var s_max := 0.55 if big else 0.095

	if big:
		# 震屏信号：只发信号，具体抖多少由相机/玩法决定（美术不硬写相机）
		root.add_user_signal("camera_shake")

	for i in count:
		var s := randf_range(s_min, s_max)
		var shade := FxPalette.ROCK if randf() > 0.4 else FxPalette.ROCK_DEEP
		var body := FxUtil.box(
			Vector3(s, s * randf_range(0.7, 1.25), s),
			FxUtil.lit_material(shade)
		)
		var rock := FxUtil.mesh_instance(body)
		var ang := randf() * TAU
		var rad := sqrt(randf()) * area
		rock.position = Vector3(cos(ang) * rad, fall_h, sin(ang) * rad)
		rock.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		rock.set_meta("_fx_no_flash", true)

		# 每块石头单独一个 tween：延迟 → 加速下坠 → 落地小弹跳 → 碎裂消失
		var delay := randf() * (1.05 if big else 0.55)
		var fall_t := randf_range(0.32, 0.5) * (1.45 if big else 1.0)
		var spin := Vector3(randf_range(-360, 360), randf_range(-240, 240), randf_range(-360, 360))
		var rest_y := s * 0.5
		rock.scale = Vector3(0.01, 0.01, 0.01)
		root.add_child(rock)

		var rock_ref := rock
		var rest := rest_y
		var fall := fall_t
		var dl := delay
		var sp := spin
		var sz := s
		FxUtil.on_start(root, func():
			var tw := root.create_tween()
			tw.tween_interval(dl)
			tw.tween_property(rock_ref, "scale", Vector3.ONE, 0.08)
			tw.parallel().tween_property(rock_ref, "position:y", rest, fall) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(rock_ref, "rotation_degrees", sp, fall)
			# 落地：一次小反弹 + 尘
			tw.tween_property(rock_ref, "position:y", rest + sz * 0.35, 0.06) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(rock_ref, "position:y", rest, 0.07)
			tw.tween_callback(func(): _land_dust(root, rock_ref.global_position, sz, big))
			tw.tween_interval(0.1)
			tw.tween_property(rock_ref, "scale", Vector3(0.01, 0.01, 0.01), 0.14) \
				.set_ease(Tween.EASE_IN)
		)

	# 大落石额外：贴地冲击尘环（小落石不加，保持"小"的体量）
	if big:
		var rm := ShaderMaterial.new()
		rm.shader = RING_SHADER
		rm.set_shader_parameter("color", FxPalette.DUST_DARK)
		rm.set_shader_parameter("thickness", 0.22)
		rm.set_shader_parameter("strength", 0.75)
		rm.set_shader_parameter("grit", 0.6)
		var q := QuadMesh.new()
		q.size = Vector2(area * 2.4, area * 2.4)
		q.orientation = PlaneMesh.FACE_Y
		var ring := FxUtil.mesh_instance(q, rm, Vector3(0, 0.04, 0))
		ring.name = "ImpactRing"
		root.add_child(ring)
		FxUtil.on_start(root, func():
			FxUtil.tween_param(root, rm, "progress", 0.02, 1.0, 0.7)
			root.create_tween().tween_interval(0.15).finished.connect(
				func(): root.emit_signal("camera_shake", 0.35))
		)

	return root


func _land_dust(root: Node3D, world_pos: Vector3, size: float, big: bool) -> void:
	## 落地尘：局部坐标系换算回特效根节点下，一个短促的小尘团。
	var local := root.to_local(world_pos)
	var p := FxUtil.particles({
		"amount": 5 if big else 3,
		"lifetime": 0.45,
		"explosiveness": 0.85,
		"randomness": 0.9,
		"mesh": FxUtil.quad(size * 2.4, FxUtil.billboard_material(FxPalette.DUST, false, FxUtil.dot_texture())),
		"shape": CPUParticles3D.EMISSION_SHAPE_SPHERE,
		"sphere_radius": size * 0.5,
		"direction": Vector3.UP,
		"spread": 88.0,
		"gravity": Vector3(0, 0.25, 0),
		"vmin": 0.25,
		"vmax": 0.7,
		"damping_min": 1.2,
		"damping_max": 2.0,
		"smin": 1.0,
		"smax": 1.0,
		"scale_curve": FxUtil.curve([[0.0, 0.45], [0.5, 1.3], [1.0, 1.6]]),
		"color_ramp": FxUtil.ramp([
			Color(FxPalette.DUST.r, FxPalette.DUST.g, FxPalette.DUST.b, 0.0),
			Color(FxPalette.DUST.r, FxPalette.DUST.g, FxPalette.DUST.b, 0.20),
			Color(FxPalette.DUST.r, FxPalette.DUST.g, FxPalette.DUST.b, 0.0),
		], [0.0, 0.25, 1.0]),
	})
	p.position = local
	root.add_child(p)
	p.restart()


# ── FX022 坍塌尘雾（FX018 的体积变体）────────────────────────
func fx022(opts: Dictionary) -> Node3D:
	var root := Node3D.new()
	var area: float = opts.get("area", 4.5)
	var color: Color = opts.get("color", FxPalette.SMOKE)

	# 三波尘团：0s / 0.55s / 1.15s，一波比一波高、一波比一波淡
	var waves := [
		{"delay": 0.0, "amount": 16, "speed": 2.2, "alpha": 0.30, "size": 1.15, "y": 0.25},
		{"delay": 0.55, "amount": 14, "speed": 1.6, "alpha": 0.24, "size": 1.35, "y": 0.55},
		{"delay": 1.15, "amount": 12, "speed": 1.0, "alpha": 0.16, "size": 1.55, "y": 0.9},
	]
	for i in waves.size():
		var w: Dictionary = waves[i]
		var p := FxUtil.particles({
			"amount": w["amount"],
			"lifetime": 2.0,
			"explosiveness": 0.35,
			"randomness": 0.9,
			"mesh": FxUtil.quad(w["size"], FxUtil.billboard_material(color, false, FxUtil.dot_texture())),
			"shape": CPUParticles3D.EMISSION_SHAPE_SPHERE,
			"sphere_radius": area * 0.35,
			"direction": Vector3.UP,
			"spread": 88.0,
			"gravity": Vector3(0, 0.45, 0),
			"vmin": w["speed"] * 0.6,
			"vmax": w["speed"],
			"damping_min": 0.9,
			"damping_max": 1.5,
			"smin": 1.0,
			"smax": 1.0,
			"scale_curve": FxUtil.curve([[0.0, 0.55], [0.45, 1.25], [1.0, 1.8]]),
			"color_ramp": FxUtil.ramp([
				Color(color.r, color.g, color.b, 0.0),
				Color(color.r, color.g, color.b, w["alpha"]),
				Color(color.r, color.g, color.b, 0.0),
			], [0.0, 0.22, 1.0]),
		})
		p.name = "DustWave%d" % i
		p.position = Vector3(0, w["y"], 0)
		root.add_child(p)
		var delay: float = w["delay"]
		var pp := p
		FxUtil.on_start(root, func():
			if delay <= 0.0:
				pp.restart()
			else:
				root.create_tween().tween_interval(delay).finished.connect(func(): pp.restart())
		)

	# 贴地扩散的尘墙：坍塌时先向四周推一圈
	var rm := ShaderMaterial.new()
	rm.shader = RING_SHADER
	rm.set_shader_parameter("color", color)
	rm.set_shader_parameter("thickness", 0.30)
	rm.set_shader_parameter("strength", 0.55)
	rm.set_shader_parameter("grit", 0.7)
	var q := QuadMesh.new()
	q.size = Vector2(area * 2.6, area * 2.6)
	q.orientation = PlaneMesh.FACE_Y
	var ring := FxUtil.mesh_instance(q, rm, Vector3(0, 0.05, 0))
	ring.name = "DustWaveRing"
	root.add_child(ring)
	FxUtil.on_start(root, func():
		FxUtil.tween_param(root, rm, "progress", 0.0, 1.0, 1.1, Tween.TRANS_QUAD, Tween.EASE_OUT)
	)
	return root
