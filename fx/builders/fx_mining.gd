extends RefCounted
## 挖矿链特效：FX001 / FX002 / FX006 / FX007 / FX008。
## 统一约定：所有坐标以"矿块 / 物品中心"为原点，特效自己往下找地面。

const RING_SHADER := preload("res://fx/shaders/ring.gdshader")


# ── FX001 矿块受击闪光 ────────────────────────────────────────
func fx001(opts: Dictionary) -> Node3D:
	var root := Node3D.new()
	var ore_color: Color = opts.get("ore_color", FxPalette.ROCK_CHIP)
	var normal: Vector3 = opts.get("normal", Vector3.UP)
	if normal.length() < 0.1:
		normal = Vector3.UP

	# 矿块本体闪一下（material_overlay 叠加，不改本体配色）
	var target = opts.get("target", null)
	if is_instance_valid(target):
		FxFlash.flash(target, 0.85, 0.045, 0.13, Color(1, 1, 1))

	# 外崩 6 粒同色碎屑：告诉玩家"这是矿，不是石头"
	var chips := FxUtil.particles({
		"amount": 6,
		"lifetime": 0.32,
		"explosiveness": 0.95,
		"randomness": 0.7,
		"mesh": FxUtil.box(Vector3(0.045, 0.045, 0.045), FxUtil.lit_material(Color.WHITE)),
		"shape": CPUParticles3D.EMISSION_SHAPE_SPHERE,
		"sphere_radius": 0.14,
		"direction": normal,
		"spread": 58.0,
		"gravity": Vector3(0, -9.5, 0),
		"vmin": 1.1,
		"vmax": 2.2,
		"smin": 0.55,
		"smax": 1.15,
		"spin_min": -340.0,
		"spin_max": 340.0,
		"color_ramp": FxUtil.ramp([
			ore_color,
			ore_color,
			Color(ore_color.r, ore_color.g, ore_color.b, 0.0),
		], [0.0, 0.62, 1.0]),
	})
	chips.name = "HitChips"
	root.add_child(chips)
	FxUtil.emit_once(chips)

	# 命中点小亮点：0.16s 的瞬时白
	var spark_mat := FxUtil.billboard_material(FxPalette.SPARK, true, FxUtil.dot_texture())
	var spark := FxUtil.mesh_instance(FxUtil.quad(0.26, spark_mat))
	spark.name = "HitSpark"
	root.add_child(spark)
	FxUtil.on_start(root, func():
		var tw := root.create_tween().set_parallel(true)
		tw.tween_property(spark, "scale", Vector3(1.35, 1.35, 1.35), 0.16).from(Vector3(0.55, 0.55, 0.55))
		FxUtil.tween_alpha(root, spark_mat, 0.9, 0.0, 0.16)
	)
	return root


# ── FX002 石头破碎 ────────────────────────────────────────────
func fx002(opts: Dictionary) -> Node3D:
	var root := Node3D.new()
	var ore_color: Color = opts.get("ore_color", FxPalette.ORE_COPPER)
	var show_dust: bool = opts.get("dust", true)
	var ground_y: float = opts.get("ground_y", -0.3)

	# 主碎块：大块方块，快速抛物落地（无碰撞体，靠 0.45s 生命 + 缩放在落地前消失）
	var cubes := FxUtil.particles({
		"amount": 9,
		"lifetime": 0.46,
		"explosiveness": 0.95,
		"randomness": 0.75,
		"mesh": FxUtil.box(Vector3(0.085, 0.085, 0.085), FxUtil.lit_material(Color.WHITE)),
		"shape": CPUParticles3D.EMISSION_SHAPE_SPHERE,
		"sphere_radius": 0.22,
		"direction": Vector3.UP,
		"spread": 62.0,
		"gravity": Vector3(0, -15.0, 0),
		"vmin": 2.0,
		"vmax": 3.4,
		"smin": 0.7,
		"smax": 1.35,
		"spin_min": -420.0,
		"spin_max": 420.0,
		"color_ramp": FxUtil.ramp([
			FxPalette.ROCK,
			FxPalette.ROCK_CHIP,
			Color(FxPalette.ROCK_CHIP.r, FxPalette.ROCK_CHIP.g, FxPalette.ROCK_CHIP.b, 0.0),
		], [0.0, 0.55, 1.0]),
	})
	cubes.name = "RockChunks"
	root.add_child(cubes)
	FxUtil.emit_once(cubes)

	# 薄片碎块：形状差异让破碎读起来更"脆"
	var slabs := FxUtil.particles({
		"amount": 6,
		"lifetime": 0.4,
		"explosiveness": 0.95,
		"randomness": 0.8,
		"mesh": FxUtil.box(Vector3(0.13, 0.035, 0.09), FxUtil.lit_material(Color.WHITE)),
		"shape": CPUParticles3D.EMISSION_SHAPE_SPHERE,
		"sphere_radius": 0.2,
		"direction": Vector3.UP,
		"spread": 70.0,
		"gravity": Vector3(0, -15.0, 0),
		"vmin": 2.4,
		"vmax": 3.8,
		"smin": 0.6,
		"smax": 1.2,
		"spin_min": -620.0,
		"spin_max": 620.0,
		"color_ramp": FxUtil.ramp([
			FxPalette.ROCK_DEEP,
			FxPalette.ROCK,
			Color(FxPalette.ROCK.r, FxPalette.ROCK.g, FxPalette.ROCK.b, 0.0),
		], [0.0, 0.6, 1.0]),
	})
	slabs.name = "RockSlabs"
	root.add_child(slabs)
	FxUtil.emit_once(slabs)

	# 矿物色碎屑：告诉玩家掉的是什么矿
	var ore_bits := FxUtil.particles({
		"amount": 5,
		"lifetime": 0.4,
		"explosiveness": 0.9,
		"randomness": 0.8,
		"mesh": FxUtil.box(Vector3(0.05, 0.05, 0.05), FxUtil.emissive_material(Color.WHITE, 1.1)),
		"shape": CPUParticles3D.EMISSION_SHAPE_SPHERE,
		"sphere_radius": 0.16,
		"direction": Vector3.UP,
		"spread": 75.0,
		"gravity": Vector3(0, -13.0, 0),
		"vmin": 2.2,
		"vmax": 3.2,
		"smin": 0.7,
		"smax": 1.1,
		"spin_min": -300.0,
		"spin_max": 300.0,
		"color_ramp": FxUtil.ramp([
			ore_color,
			ore_color,
			Color(ore_color.r, ore_color.g, ore_color.b, 0.0),
		], [0.0, 0.5, 1.0]),
	})
	ore_bits.name = "OreBits"
	root.add_child(ore_bits)
	FxUtil.emit_once(ore_bits)

	if show_dust:
		# 尘雾：alpha 上限 0.16 + 全部压在 y<0.2，掉落物（y≈0.35）始终看得见
		var dust := FxUtil.particles({
			"amount": 7,
			"lifetime": 0.62,
			"explosiveness": 0.55,
			"randomness": 0.85,
			"mesh": FxUtil.quad(0.34, FxUtil.billboard_material(FxPalette.DUST, false, FxUtil.dot_texture())),
			"shape": CPUParticles3D.EMISSION_SHAPE_SPHERE,
			"sphere_radius": 0.26,
			"direction": Vector3.UP,
			"spread": 88.0,
			"gravity": Vector3(0, 0.35, 0),
			"vmin": 0.35,
			"vmax": 0.85,
			"damping_min": 0.8,
			"damping_max": 1.6,
			"smin": 1.0,
			"smax": 1.0,
			"scale_curve": FxUtil.curve([[0.0, 0.5], [0.45, 1.5], [1.0, 1.9]]),
			"color_ramp": FxUtil.ramp([
				Color(FxPalette.DUST.r, FxPalette.DUST.g, FxPalette.DUST.b, 0.0),
				Color(FxPalette.DUST.r, FxPalette.DUST.g, FxPalette.DUST.b, 0.16),
				Color(FxPalette.DUST.r, FxPalette.DUST.g, FxPalette.DUST.b, 0.0),
			], [0.0, 0.22, 1.0]),
		})
		dust.name = "DustPuff"
		dust.position = Vector3(0, ground_y + 0.12, 0)
		root.add_child(dust)
		FxUtil.emit_once(dust)

		# 贴地尘环：一圈快速外扩的土黄，把"炸开"的方向讲清楚
		var rm := ShaderMaterial.new()
		rm.shader = RING_SHADER
		rm.set_shader_parameter("color", FxPalette.DUST)
		rm.set_shader_parameter("thickness", 0.20)
		rm.set_shader_parameter("strength", 0.5)
		rm.set_shader_parameter("grit", 0.55)
		var q := QuadMesh.new()
		q.size = Vector2(1.5, 1.5)
		q.orientation = PlaneMesh.FACE_Y
		var ring := FxUtil.mesh_instance(q, rm, Vector3(0, ground_y + 0.03, 0))
		ring.name = "DustRing"
		root.add_child(ring)
		FxUtil.on_start(root, func():
			FxUtil.tween_param(root, rm, "progress", 0.0, 1.0, 0.42)
		)

	return root


# ── FX006 物品拾取反馈 ────────────────────────────────────────
func fx006(opts: Dictionary) -> Node3D:
	var root := Node3D.new()
	var color: Color = opts.get("color", FxPalette.SPARK)

	# 缩放 pop：0.6 → 1.3 → 0，先"确认"再消失
	var pop_mat := FxUtil.unshaded_alpha(color, true)
	var pop := FxUtil.mesh_instance(FxUtil.box(Vector3(0.17, 0.17, 0.17), pop_mat))
	pop.name = "PickPop"
	root.add_child(pop)
	FxUtil.on_start(root, func():
		var tw := root.create_tween()
		tw.tween_property(pop, "scale", Vector3(1.3, 1.3, 1.3), 0.1) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).from(Vector3(0.6, 0.6, 0.6))
		tw.parallel().tween_property(pop, "rotation_degrees:y", 90.0, 0.3)
		tw.tween_property(pop, "scale", Vector3.ZERO, 0.16).set_ease(Tween.EASE_IN)
	)

	var motes := FxUtil.particles({
		"amount": 6,
		"lifetime": 0.34,
		"explosiveness": 0.7,
		"randomness": 0.8,
		"mesh": FxUtil.quad(0.09, FxUtil.billboard_material(color, true, FxUtil.dot_texture())),
		"shape": CPUParticles3D.EMISSION_SHAPE_SPHERE,
		"sphere_radius": 0.12,
		"direction": Vector3.UP,
		"spread": 35.0,
		"gravity": Vector3(0, 1.6, 0),
		"vmin": 0.6,
		"vmax": 1.4,
		"smin": 0.6,
		"smax": 1.1,
		"color_ramp": FxUtil.ramp([
			Color(color.r, color.g, color.b, 0.0),
			Color(color.r, color.g, color.b, 0.95),
			Color(color.r, color.g, color.b, 0.0),
		], [0.0, 0.2, 1.0]),
	})
	motes.name = "PickMotes"
	root.add_child(motes)
	FxUtil.emit_once(motes)

	var rm := ShaderMaterial.new()
	rm.shader = RING_SHADER
	rm.set_shader_parameter("color", color)
	rm.set_shader_parameter("thickness", 0.10)
	rm.set_shader_parameter("strength", 0.9)
	var q := QuadMesh.new()
	q.size = Vector2(0.75, 0.75)
	q.orientation = PlaneMesh.FACE_Y
	var ring := FxUtil.mesh_instance(q, rm, Vector3(0, -0.18, 0))
	ring.name = "PickRing"
	root.add_child(ring)
	FxUtil.on_start(root, func():
		FxUtil.tween_param(root, rm, "progress", 0.05, 1.0, 0.3)
	)
	return root


# ── FX007 物品投炉反馈 ────────────────────────────────────────
func fx007(opts: Dictionary) -> Node3D:
	var root := Node3D.new()
	var mouth: Vector3 = opts.get("mouth_offset", Vector3(0, 0.9, 0))
	var item = opts.get("item", null)
	var color: Color = opts.get("color", FxPalette.WARN)

	# 炉口辉光：先亮后收
	var glow_mat := FxUtil.billboard_material(color, true, FxUtil.dot_texture())
	var glow := FxUtil.mesh_instance(FxUtil.quad(0.7, glow_mat), null, mouth)
	glow.name = "MouthGlow"
	root.add_child(glow)

	# 火星：向上飘，重力为正（热气流）
	var embers := FxUtil.particles({
		"amount": 16,
		"lifetime": 0.55,
		"explosiveness": 0.8,
		"randomness": 0.7,
		"mesh": FxUtil.quad(0.075, FxUtil.billboard_material(color, true, FxUtil.dot_texture())),
		"shape": CPUParticles3D.EMISSION_SHAPE_SPHERE,
		"sphere_radius": 0.12,
		"direction": Vector3.UP,
		"spread": 34.0,
		"gravity": Vector3(0, 1.4, 0),
		"vmin": 1.6,
		"vmax": 3.0,
		"smin": 0.55,
		"smax": 1.15,
		"color_ramp": FxUtil.ramp([
			Color(1.0, 0.85, 0.5, 0.0),
			Color(color.r, color.g, color.b, 1.0),
			Color(1.0, 0.35, 0.12, 0.0),
		], [0.0, 0.25, 1.0]),
	})
	embers.name = "Embers"
	embers.position = mouth
	root.add_child(embers)
	FxUtil.emit_once(embers)

	# 同步时点：物品缩到 0 的同一帧发 item_consumed，玩法据此开始熔炼计时
	root.add_user_signal("item_consumed")
	FxUtil.on_start(root, func():
		var tw := root.create_tween().set_parallel(true)
		tw.tween_property(glow, "scale", Vector3(1.35, 1.35, 1.35), 0.34) \
			.set_ease(Tween.EASE_OUT).from(Vector3(0.55, 0.55, 0.55))
		FxUtil.tween_alpha(root, glow_mat, 0.85, 0.0, 0.34)
		if is_instance_valid(item):
			var t2 := root.create_tween()
			t2.tween_property(item, "global_position", item.global_position + mouth, 0.16) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t2.parallel().tween_property(item, "scale", Vector3.ZERO, 0.16)
			t2.tween_callback(func(): root.emit_signal("item_consumed"))
		else:
			root.create_tween().tween_interval(0.16).finished.connect(
				func(): root.emit_signal("item_consumed"))
	)
	return root


# ── FX008 金币获得反馈 ────────────────────────────────────────
func fx008(opts: Dictionary) -> Node3D:
	var root := Node3D.new()
	var amount: int = int(opts.get("amount", 0))
	var text: String = opts.get("text", "+%d" % amount)

	# 金币体：躺平的金色圆盘 + 自转，俯视下是一个明确的"金"
	var coin_mat := FxUtil.emissive_material(FxPalette.GOLD, 1.9)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.085
	cyl.bottom_radius = 0.085
	cyl.height = 0.028
	cyl.radial_segments = 8        # 低面数 = 体素风
	cyl.rings = 1
	cyl.material = coin_mat
	var coin := FxUtil.mesh_instance(cyl, null, Vector3(0, -0.1, 0))
	coin.name = "Coin"
	root.add_child(coin)

	# 数值：只做读法，数字由程序给
	var label := FxUtil.label3d(text, 64, FxPalette.GOLD)
	label.position = Vector3(0, 0.32, 0)
	label.name = "AmountLabel"
	root.add_child(label)

	var motes := FxUtil.particles({
		"amount": 9,
		"lifetime": 0.5,
		"explosiveness": 0.85,
		"randomness": 0.8,
		"mesh": FxUtil.quad(0.07, FxUtil.billboard_material(FxPalette.GOLD, true, FxUtil.dot_texture())),
		"shape": CPUParticles3D.EMISSION_SHAPE_SPHERE,
		"sphere_radius": 0.1,
		"direction": Vector3.UP,
		"spread": 60.0,
		"gravity": Vector3(0, 1.2, 0),
		"vmin": 0.9,
		"vmax": 2.0,
		"smin": 0.6,
		"smax": 1.2,
		"color_ramp": FxUtil.ramp([
			Color(FxPalette.GOLD.r, FxPalette.GOLD.g, FxPalette.GOLD.b, 0.0),
			Color(1.0, 0.95, 0.7, 1.0),
			Color(FxPalette.GOLD.r, FxPalette.GOLD.g, FxPalette.GOLD.b, 0.0),
		], [0.0, 0.2, 1.0]),
	})
	motes.name = "GoldMotes"
	root.add_child(motes)
	FxUtil.emit_once(motes)

	FxUtil.on_start(root, func():
		# 金币上跳 0.45m 后淡出
		var tw := root.create_tween().set_parallel(true)
		tw.tween_property(coin, "position:y", 0.35, 0.55) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).from(-0.1)
		tw.tween_property(coin, "rotation_degrees:y", 540.0, 0.62)
		FxUtil.tween_alpha(root, coin_mat, 1.0, 0.0, 0.28, 0.42)

		# 数字延迟 0.08s 出现，比金币更晚消失（信息优先）
		var t2 := root.create_tween()
		t2.tween_interval(0.08)
		t2.tween_property(label, "position:y", 0.68, 0.62) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).from(0.32)
		t2.parallel().tween_property(label, "modulate:a", 0.0, 0.28).set_delay(0.44)
		t2.parallel().tween_property(label, "scale", Vector3(1.18, 1.18, 1.18), 0.14)
	)
	return root
