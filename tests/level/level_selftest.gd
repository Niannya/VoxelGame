## 关卡模块自检：不依赖编辑器、不依赖美术、不开窗口。
##
## 跑法：
##   & "C:\Users\28257\Desktop\Godot_v4.6.2-stable_win64.exe" --headless `
##       --path "C:\Users\28257\Downloads\VoxelGame-main (2)\VoxelGame-main" `
##       res://tests/level/level_selftest.tscn
##
## 改完掉落表 / 挖掘结算 / 深度推进后**必须**跑一遍再提交，别人也靠它判断有没有被你的改动弄坏。
extends Node

var _failures: Array[String] = []


func _ready() -> void:
	_test_loot_table()
	_test_mining()
	_test_boundary()
	_test_depth()
	_test_cart_reasons()
	_test_spawner()
	_test_economy()
	await _test_sandbox_scene()

	if _failures.is_empty():
		print("LEVEL SELFTEST: PASS")
		get_tree().quit(0)
		return
	for f in _failures:
		printerr("FAIL: " + f)
	print("LEVEL SELFTEST: FAIL (%d)" % _failures.size())
	get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


# ---------------------------------------------------------------- L01 掉落表

func _test_loot_table() -> void:
	var table := LevelLootDataL01.build()
	for problem in table.validate():
		_failures.append(problem)

	_expect(table.entries.size() == 18, "掉落表应有 18 件，实际 %d" % table.entries.size())
	_expect(table.total_weight(1) == 100000, "第 1 层权重合计应为 100000")
	_expect(table.total_weight(7) == 100000, "第 7 层权重合计应为 100000")
	_expect(table.total_weight(9) == table.total_weight(7), "第 9 层应沿用第 7 层")

	var ev1 := table.expected_value(1)
	var ev7 := table.expected_value(7)
	_expect(absf(ev1 - 8.455) < 0.02, "第 1 层每格期望 %.3f 偏离 8.455" % ev1)
	_expect(absf(ev7 - 9.061) < 0.02, "第 7 层每格期望 %.3f 偏离 9.061" % ev7)

	# 高价档随深度增长，西瓜皮让出
	var yongle: LevelLootEntry = null
	var watermelon: LevelLootEntry = null
	for e in table.entries:
		if e.item_id == &"antique_yongle":
			yongle = e
		elif e.item_id == &"junk_watermelon":
			watermelon = e
	_expect(yongle != null and yongle.weight_at(1) == 300 and yongle.weight_at(7) == 600,
		"《永乐大典》权重应为 300 → 600")
	_expect(watermelon != null and watermelon.weight_at(1) == 15400 and watermelon.weight_at(7) == 14800,
		"西瓜皮权重应为 15400 → 14800")

	# 抽样：垃圾类占比应接近 75.56%
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var samples := 20000
	var junk := 0
	for _i in samples:
		var entry := table.roll(1, rng)
		if entry != null and entry.tier == &"junk":
			junk += 1
	var share := float(junk) / float(samples)
	_expect(absf(share - 0.7556) < 0.01, "垃圾占比 %.3f 偏离 0.7556" % share)


# ---------------------------------------------------------------- 挖掘结算

func _test_mining() -> void:
	var grid := LevelVoxelGrid.new()
	grid.auto_generate = false
	add_child(grid)

	var cell := Vector3i(0, 0, 0)
	grid.set_cell(cell, &"stone_a", 1)
	var power := {&"stone": 0.4}

	var r1: Array = grid.apply_mining([cell], power, null)
	_expect(r1.size() == 1 and not r1[0]["destroyed"], "第一次挖掘不应破坏")
	_expect(absf(r1[0]["ratio"] - 0.4) < 0.001, "第一次进度应为 0.4，实际 %.3f" % r1[0]["ratio"])

	grid.apply_mining([cell], power, null)
	var r3: Array = grid.apply_mining([cell], power, null)
	_expect(r3.size() == 1 and r3[0]["destroyed"], "第三次挖掘应破坏")
	_expect(r3[0]["drops"].size() == 1, "破坏应产出 1 件基础掉落")
	_expect(not grid.has_block(cell), "破坏后格子应清空")

	# 已清空的格子再挖不产生掉落
	var again: Array = grid.apply_mining([cell], power, null)
	_expect(again.is_empty(), "空格再挖不应有结果")

	# 多格一挥：逐格独立结算
	var cell_a := Vector3i(1, 0, 0)
	var cell_b := Vector3i(2, 0, 0)
	grid.set_cell(cell_a, &"stone_a", 1)
	grid.set_cell(cell_b, &"stone_b", 1)
	var multi: Array = grid.apply_mining([cell_a, cell_b], {&"stone": 5.0}, null)
	_expect(multi.size() == 2, "多格挥击应返回 2 条结果")
	_expect(multi[0]["destroyed"] and multi[1]["destroyed"], "高倍率应破坏两格")

	grid.queue_free()


func _test_boundary() -> void:
	var grid := LevelVoxelGrid.new()
	grid.auto_generate = false
	add_child(grid)
	var cell := Vector3i(3, 0, 3)
	grid.set_cell(cell, &"bedrock", 1)
	grid.apply_mining([cell], {&"default": 9999.0}, null)
	_expect(grid.has_block(cell), "边界方块不应被破坏")
	grid.queue_free()


# ---------------------------------------------------------------- L02 深度

func _test_depth() -> void:
	var state := LevelState.new()
	add_child(state)
	_expect(state.depth == 1, "开局应在第 1 层")
	_expect(state.floor_length(1) == 50 and state.floor_length(3) == 150, "层长应为 50×d")
	_expect(state.descent_point(1) == 50 and state.descent_point(2) == 150,
		"下潜点应为 25×d×(d+1)")

	state.advance_to(state.route_origin_z - 49.0)
	_expect(state.progress == 49 and state.depth == 1, "49 格应仍在第 1 层")

	state.advance_to(state.route_origin_z - 50.0)
	_expect(state.progress == 50, "应累计到 50 格")
	_expect(state.depth == 2, "50 格应下潜到第 2 层")

	state.advance_to(10.0)
	_expect(state.progress == 50, "往回开不应增加里程")
	_expect(state.floor_progress() == 0, "刚下潜时本层进度应为 0")

	state.queue_free()


# ---------------------------------------------------------------- L04 停车原因

func _test_cart_reasons() -> void:
	var grid := LevelVoxelGrid.new()
	grid.auto_generate = false
	add_child(grid)
	grid.set_cell(Vector3i(0, 0, 0), &"stone_a", 1)

	var cart := LevelCartController.new()
	cart._grid = grid
	cart.require_track = false
	var reason: int = cart._check_ahead(Vector3(0, 0, 0))
	_expect(reason == LevelCartController.StopReason.ROCK,
		"前方有方块应报 ROCK，实际 %d" % reason)

	grid.clear_cell(Vector3i(0, 0, 0))
	reason = cart._check_ahead(Vector3(0, 0, 0))
	_expect(reason == LevelCartController.StopReason.NONE, "清空后应可通行")

	cart.free()
	grid.queue_free()


# ---------------------------------------------------------------- L05 抽怪

func _test_spawner() -> void:
	for depth in [1, 2, 3, 5, 8]:
		var band := LevelMonsterSpawner.band_for(depth)
		var total := 0
		for key in band["weights"]:
			total += int(band["weights"][key])
		_expect(total == 100, "第 %d 层普通怪概率合计 %d，应为 100" % [depth, total])

	_expect(LevelMonsterSpawner.foreman_quota(3) == 6, "第 3 层保底工头应为 6 只")
	_expect(LevelMonsterSpawner.foreman_start_floor_progress(2) == 90,
		"第 2 层保底起点应为本层第 90 格")

	var rng := RandomNumberGenerator.new()
	rng.seed = 999
	var wanderer := 0
	var samples := 20000
	for _i in samples:
		if LevelMonsterSpawner.pick_normal(1, rng) == LevelMonsterSpawner.WANDERER:
			wanderer += 1
	var share := float(wanderer) / float(samples)
	_expect(absf(share - 0.70) < 0.02, "第 1 层游荡丧尸占比 %.3f 偏离 0.70" % share)


# ---------------------------------------------------------------- L06 经济

func _test_economy() -> void:
	var eco := LevelEconomyService.new()
	add_child(eco)
	_expect(eco.coins == 0, "开局共享金币应为 0")
	var earned := eco.sell([{"price": 10}, {"price": 16}])
	_expect(earned == 26 and eco.coins == 26, "卖 10+16 应得 26，实际 %d" % earned)
	_expect(not eco.try_spend(100), "余额不足不应扣钱")
	_expect(eco.coins == 26, "扣钱失败不应改余额")
	_expect(eco.try_spend(26) and eco.coins == 0, "足额扣钱后应归零")
	eco.queue_free()


# ---------------------------------------------------------------- 装配体（冒烟）

## 把 level_sandbox.tscn 真的跑起来，检查"生成 → 铺轨 → 矿车被岩块挡住"这条链。
func _test_sandbox_scene() -> void:
	var packed: PackedScene = load("res://scenes/levels/level_sandbox.tscn")
	if packed == null:
		_failures.append("加载不到 level_sandbox.tscn")
		return
	var root: Node = packed.instantiate()
	add_child(root)

	for _i in 220:
		await get_tree().physics_frame

	var grid: LevelVoxelGrid = root.get_node_or_null("Grid")
	var cart: LevelCartController = root.get_node_or_null("MineCart")
	var track: LevelTrackService = root.get_node_or_null("Track")

	_expect(grid != null and grid.cell_count() > 0, "沙盒场景应生成矿洞格子")
	_expect(grid.has_block(Vector3i(0, 0, -1)), "起始空腔前方应有矿体挡住矿车")
	_expect(track != null and track.track_count() > 0, "开局应铺好起始段的旧轨")
	_expect(cart != null and cart.global_position.z < 2.9, "矿车应已经往前开")
	_expect(cart != null and cart.stop_reason == LevelCartController.StopReason.ROCK,
		"矿车应因岩块停下（实际 %d）" % (cart.stop_reason if cart else -1))

	root.queue_free()
