## 关卡模块审计（对抗性检查，独立于 level_selftest）。
##
## 和 selftest 的区别：selftest 是"实现了什么测什么"，
## 这个文件按**需求案原文**写断言，专门找实现与需求不一致的地方。
## 断言里的期望值都必须能从需求案或几何推导出来，不能抄实现。
##
## 跑法：
##   Godot_v4.6.2-stable_win64.exe --headless --path . res://tests/level/level_audit.tscn
extends Node

var _problems: Array[String] = []
var _checks := 0


func _ready() -> void:
	_audit_loot_table()
	_audit_mining()
	_audit_depth()
	_audit_track_stability()
	await _audit_renderer_art()
	_audit_compat_layer()
	await _audit_scene()

	print("LEVEL AUDIT: %d checks, %d problems" % [_checks, _problems.size()])
	if _problems.is_empty():
		print("LEVEL AUDIT: PASS")
		get_tree().quit(0)
	else:
		for p in _problems:
			printerr("AUDIT-FAIL: " + p)
		print("LEVEL AUDIT: FAIL")
		get_tree().quit(1)


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_problems.append(message)


# ---------------------------------------------------------------- L01 数值

func _audit_loot_table() -> void:
	var table := LevelLootDataL01.build()

	# 需求案：每层总掉率都是 100%
	for depth in range(1, 9):
		_check(table.total_weight(depth) == 100000,
			"第 %d 层权重合计 %d，需求案要求 100000" % [depth, table.total_weight(depth)])

	# 需求案：高价档 0.60% 起步，每层 +0.10%，第 7 层起 1.20%（权重 600→1200）
	for depth in range(1, 9):
		var expected := mini(600 + 100 * (depth - 1), 1200)
		var actual := 0
		for e in table.entries:
			if e.item_id in [&"junk_hdd", &"antique_yongle", &"antique_qingming"]:
				actual += e.weight_at(depth)
		_check(actual == expected, "第 %d 层高价档合计 %d，需求案 %d" % [depth, actual, expected])

	# 需求案：西瓜皮让出高价档增量
	var watermelon: LevelLootEntry = null
	for e in table.entries:
		if e.item_id == &"junk_watermelon":
			watermelon = e
	_check(watermelon != null, "掉落表缺少西瓜皮")
	for depth in range(1, 9):
		var expected := 15400 - (mini(600 + 100 * (depth - 1), 1200) - 600)
		_check(watermelon.weight_at(depth) == expected,
			"第 %d 层西瓜皮 %d，应为 %d" % [depth, watermelon.weight_at(depth), expected])

	# 结构：18 件、id 唯一、8 层权重、售价为正
	_check(table.entries.size() == 18, "应有 18 件物品，实际 %d" % table.entries.size())
	var seen := {}
	for e in table.entries:
		_check(not seen.has(e.item_id), "item_id 重复: %s" % e.item_id)
		seen[e.item_id] = true
		_check(e.weights.size() == 8, "%s 的权重层数应为 8" % e.item_id)
		_check(e.price > 0, "%s 售价应为正" % e.item_id)

	# 需求案：月光石/黄金矿块/钻石带天然矿物标签，铀是特殊矿样
	var natural_ids := {}
	for e in table.entries:
		if e.is_natural_mineral:
			natural_ids[e.item_id] = true
	_check(natural_ids.size() == 3, "天然矿物应恰好 3 件，实际 %d" % natural_ids.size())
	_check(not natural_ids.has(&"mineral_uranium"), "铀-235 不应带天然矿物标签")

	# 矿物房表：只掉一种矿且满权重
	var room := LevelLootDataL01.build_mineral_room(&"diamond")
	_check(room.entries.size() == 1 and room.entries[0].item_id == &"mineral_diamond",
		"钻石矿物房应只掉钻石")
	_check(room.total_weight(3) == 100000, "矿物房权重应为满值")


# ---------------------------------------------------------------- L01 结算

func _audit_mining() -> void:
	var grid := LevelVoxelGrid.new()
	grid.auto_generate = false
	add_child(grid)

	var cell := Vector3i(0, 0, 0)
	grid.set_cell(cell, &"stone_a", 1)

	# 需求案：进度保留，队友可以接着挖（0.3 + 0.3 不应破坏）
	grid.apply_mining([cell], {&"stone": 0.3}, null)
	grid.apply_mining([cell], {&"stone": 0.3}, null)
	_check(grid.has_block(cell), "0.3+0.3 时方块不应被破坏")
	_check(absf(grid.progress_ratio(cell) - 0.6) < 0.01,
		"两次 0.3 后进度应为 0.6，实际 %.2f" % grid.progress_ratio(cell))

	# 补满阈值那一击才破坏，且只结算 1 件
	var r: Array = grid.apply_mining([cell], {&"stone": 0.4}, null)
	_check(r.size() == 1 and r[0]["destroyed"], "补满进度的一击应破坏")
	_check(r[0]["drops"].size() == 1, "破坏应结算 1 件基础掉落")
	_check(not grid.has_block(cell), "破坏后格子应移除")

	var again: Array = grid.apply_mining([cell], {&"stone": 9.0}, null)
	_check(again.is_empty(), "空格再挖不应产生结果或掉落")

	# 边界：不可破坏且不产生结算
	var wall := Vector3i(5, 0, 5)
	grid.set_cell(wall, &"bedrock", 1)
	var wall_res: Array = grid.apply_mining([wall], {&"default": 999.0}, null)
	_check(wall_res.is_empty() and grid.has_block(wall), "边界方块应不可破坏且无结算")

	# 通行判定：用一个仍存在的方块测
	grid.set_cell(Vector3i(2, 0, 0), &"stone_a", 1)
	_check(grid.is_blocked_at(Vector3(2, 0, 0), 0.5, 0.5, 0.0, 1.0), "方块所在格应判为阻挡")
	_check(not grid.is_blocked_at(Vector3(4.0, 0, 0), 0.4, 0.4, 0.0, 1.0), "空处不应判为阻挡")
	# 几何：方块格 x=2 占 [1.5,2.5]，盒子 [2.5,3.5] 只是贴面，不算穿透
	_check(not grid.is_blocked_at(Vector3(3.0, 0, 0), 0.5, 0.5, 0.0, 1.0), "贴面不应算阻挡")

	grid.queue_free()


# ---------------------------------------------------------------- L02 深度

func _audit_depth() -> void:
	var state := LevelState.new()
	add_child(state)

	# 需求案：每层 50×d 格、下潜点 25×d×(d+1)
	_check(state.floor_length(1) == 50 and state.floor_length(4) == 200, "层长应为 50×d")
	_check(state.descent_point(1) == 50 and state.descent_point(3) == 300,
		"下潜点应为 25×d×(d+1)")

	state.advance_to(state.route_origin_z - 49.0)
	_check(state.depth == 1, "49 格时不应下潜")
	state.advance_to(state.route_origin_z - 50.0)
	_check(state.depth == 2, "第 50 格应下潜到第 2 层")
	_check(state.floor_progress() == 0, "刚下潜时本层进度应归零")

	# 需求案：停在边界反复穿越不应重复下潜
	state.advance_to(state.route_origin_z - 50.0)
	state.advance_to(state.route_origin_z - 51.0)
	_check(state.depth == 2, "重复经过下潜点不应再次下潜（实际第 %d 层）" % state.depth)

	# 需求案：倒退不增加里程
	var before := state.progress
	state.advance_to(state.route_origin_z - 10.0)
	_check(state.progress == before, "倒退不应增加里程")

	# 需求案：开局从 0 格开始，原点跟着矿车走
	state.set_origin(3.0)
	_check(state.progress == 0, "set_origin 后里程应归零")
	state.advance_to(2.0)
	_check(state.progress == 1, "从原点开 1 格应为 1，实际 %d" % state.progress)

	state.queue_free()


# ---------------------------------------------------------------- L03

func _audit_track_stability() -> void:
	var holder := Node3D.new()
	add_child(holder)

	var grid := LevelVoxelGrid.new()
	grid.name = "Grid"
	grid.auto_generate = false
	holder.add_child(grid)

	var track := LevelTrackService.new()
	track.name = "Track"
	track.grid_path = NodePath("../Grid")
	track.build_delay = 0.0
	track.seed_initial_route = false
	holder.add_child(track)

	grid.set_cell(Vector3i(0, 0, 0), &"stone_a", 1)
	_check(not track.is_track_ready(Vector3(0, 0, 0), 0.4, 0.4), "未清岩时不应有轨道")
	grid.apply_mining([Vector3i(0, 0, 0)], {&"default": 9.0}, null)
	_check(track.track_count() >= 1, "清岩后应铺轨")
	_check(track.is_track_ready(Vector3(0, 0, 0), 0.4, 0.4), "清岩 1 格后该格应可通行")
	_check(track.reclaim(Vector3i(0, 0, 0)), "已铺轨道应可回收")
	_check(not track.reclaim(Vector3i(0, 0, 0)), "同一格不应重复回收")

	# 稳定度：清开主路格应激活该段，搭柱应提升覆盖
	var stability := LevelStabilityService.new()
	stability.name = "Stability"
	stability.grid_path = NodePath("../Grid")
	holder.add_child(stability)

	var seg_cell := Vector3i(0, 0, -2)
	grid.set_cell(seg_cell, &"stone_a", 1)
	grid.apply_mining([seg_cell], {&"default": 9.0}, null)
	var segment := stability.segment_of_z(-2.0)
	_check(stability.is_active(segment), "清开主路格应激活该段稳定度")
	_check(absf(stability.coverage_ratio(segment) - 1.0) < 0.001,
		"未搭柱时未覆盖比例应为 1，实际 %.2f" % stability.coverage_ratio(segment))

	# 需求案：未覆盖的格子按 衰减 × 未覆盖比例 扣
	var before := stability.value_of(segment)
	stability._process(1.0)
	_check(stability.value_of(segment) < before,
		"未覆盖时稳定度应随时间下降（%.1f → %.1f）" % [before, stability.value_of(segment)])

	# 需求案：每根柱子 +20 并带来有效覆盖；满覆盖后时间项应为零
	_check(stability.add_pillar(Vector3i(0, 0, -2)), "搭柱应带来新的覆盖")
	_check(absf(stability.coverage_ratio(segment)) < 0.001,
		"满覆盖后未覆盖比例应为 0，实际 %.2f" % stability.coverage_ratio(segment))
	var covered_value := stability.value_of(segment)
	stability._process(1.0)
	_check(absf(stability.value_of(segment) - covered_value) < 0.001, "满覆盖后不应继续衰减")

	# 需求案：衰减 2 + 0.5×(d−1)；柱覆盖每两层减 1，最低 1
	_check(absf(stability.decay_rate(1) - 2.0) < 0.001 and absf(stability.decay_rate(5) - 4.0) < 0.001,
		"衰减应为 2 + 0.5×(d−1)")
	_check(stability.pillar_side(1) == 6 and stability.pillar_side(9) == 2 and stability.pillar_side(13) == 1,
		"柱覆盖边长应为 6/5/4/3/2/1 逐档递减")

	holder.queue_free()


# ---------------------------------------------------------------- L01 表现

func _audit_renderer_art() -> void:
	var holder := Node3D.new()
	add_child(holder)

	var grid := LevelVoxelGrid.new()
	grid.name = "Grid"
	grid.auto_generate = false
	holder.add_child(grid)
	grid.set_cell(Vector3i(0, 0, 0), &"stone_a", 1)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.DARK_RED
	var theme := LevelArtTheme.new()
	theme.block_materials = {&"stone_a": mat}

	var renderer := LevelVoxelRenderer.new()
	renderer.name = "Renderer"
	renderer.grid_path = NodePath("../Grid")
	renderer.art = theme
	holder.add_child(renderer)

	var solid: MultiMeshInstance3D = renderer.get_node_or_null("Solid_stone_a")
	_check(solid != null, "渲染层应建出 Solid_stone_a")
	if solid != null:
		_check(solid.material_override != null, "美术主题的 block_materials 应应用到实例")
		_check(solid.multimesh != null and solid.multimesh.instance_count == 1,
			"1 格应只有 1 个实例，实际 %d" % (solid.multimesh.instance_count if solid.multimesh else -1))

		# 注意：--headless 下 MultiMesh 实例变换不回读（引擎 dummy 渲染器），
		# 所以查渲染层自己维护的 display_state，而不是读 multimesh。
		var probe_cell := Vector3i(0, 0, 0)
		_check(bool(renderer.display_state(probe_cell).get("visible", false)), "初始应可见")

		grid.apply_mining([probe_cell], {&"stone": 0.3}, null)
		var hurt: Dictionary = renderer.display_state(probe_cell)
		_check(bool(hurt["visible"]) and float(hurt["scale"]) < 0.99,
			"受伤方块应缩小提示，实际 scale %.2f" % float(hurt["scale"]))
		_check(int(hurt["stage"]) == 1,
			"0.3 进度应落在第 1 档（1/3 阈值），实际第 %d 档" % int(hurt["stage"]))

		grid.apply_mining([probe_cell], {&"stone": 0.9}, null)
		_check(not bool(renderer.display_state(probe_cell)["visible"]), "挖穿后方块应不可见")

	# 有裂纹资产时应改用叠层而不是缩放
	var crack_mesh := BoxMesh.new()
	crack_mesh.size = Vector3(1.01, 1.01, 1.01)
	var theme2 := LevelArtTheme.new()
	theme2.crack_meshes = [crack_mesh, crack_mesh, crack_mesh]
	renderer.art = theme2
	renderer.rebuild()
	grid.set_cell(Vector3i(1, 0, 0), &"stone_a", 1)
	grid.apply_mining([Vector3i(1, 0, 0)], {&"stone": 0.4}, null)
	_check(renderer.get_node_or_null("Cracks/Crack_2") != null,
		"给了裂纹资产时应生成裂纹叠层节点")

	# 批量新增（模拟 L02 换层重新生成）：应合并成一次重建，不能每格重建一次
	var before := renderer.rebuild_count
	for i in 120:
		grid.set_cell(Vector3i(50 + i, 0, 0), &"stone_a", 1)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(renderer.rebuild_count - before <= 2,
		"批量新增 120 格应只重建 1 次，实际 %d 次" % (renderer.rebuild_count - before))
	_check(bool(renderer.display_state(Vector3i(50, 0, 0)).get("visible", false)),
		"批量新增的格子应可见")

	holder.queue_free()


# ---------------------------------------------------------------- 兼容层（队友在用）

func _audit_compat_layer() -> void:
	var root := LevelRoot.new()
	root.name = "Root"
	var grid := LevelVoxelGrid.new()
	grid.name = "Grid"
	grid.auto_generate = false
	root.add_child(grid)

	var emitted: Array = []
	root.block_broken.connect(func(pos: Vector3i, key: String) -> void:
		emitted.append([pos, key]))

	add_child(root)
	grid.set_cell(Vector3i(0, 0, 0), &"stone_a", 1)

	var hit: Dictionary = root.raycast_block(Vector3(0, 0, 5), Vector3(0, 0, -1), 20.0)
	_check(hit.get("hit", false) and hit.get("pos", Vector3i.ZERO) == Vector3i(0, 0, 0),
		"兼容层 raycast_block 应命中 (0,0,0)，实际 %s" % str(hit))

	_check(root.break_block(Vector3i(0, 0, 0)), "兼容层 break_block 应返回 true")
	_check(not grid.has_block(Vector3i(0, 0, 0)), "兼容层 break_block 应真的破坏方块")
	_check(emitted.size() == 1 and emitted[0][1] == "stone_a",
		"兼容层应发出两参 block_broken(pos, String)，实际 %s" % str(emitted))

	root.queue_free()


# ---------------------------------------------------------------- 装配体

func _audit_scene() -> void:
	var packed: PackedScene = load("res://scenes/levels/level_sandbox.tscn")
	var root: Node = packed.instantiate()
	add_child(root)

	var state: LevelState = root.get_node_or_null("LevelState")
	var cart: LevelCartController = root.get_node_or_null("MineCart")

	# 需求案：每局从累计推进 0 格开始（给几帧缓冲，不能只在第 1 帧查）
	for _i in 12:
		await get_tree().physics_frame
	_check(state != null and state.progress == 0,
		"开局累计推进应为 0，实际 %d" % (state.progress if state else -1))

	for _i in 260:
		await get_tree().physics_frame

	_check(cart != null and cart.stop_reason == LevelCartController.StopReason.ROCK,
		"矿车应因岩块停下")
	if cart != null:
		# 几何：矿体在 z=-1（占 [-1.5,-0.5]），车头 = z − 1.8，贴合时应停在 z≈1.3
		_check(absf(cart.global_position.z - 1.3) < 0.06,
			"矿车应停在 z≈1.3，实际 %.2f" % cart.global_position.z)
		# 从 3.0 开到 1.3 约 1.7 格，向下取整后里程应为 1
		_check(state.progress == 1, "里程应为 1 格，实际 %d" % state.progress)

	root.queue_free()
