extends SceneTree
const World = preload("res://scripts/world/voxel_world.gd")
const Operator = preload("res://scripts/tools/tool_operator.gd")
const Resolver = preload("res://scripts/systems/mining_resolver.gd")
const Player = preload("res://tools/fixtures/mining_player.gd")
const Enemy = preload("res://tools/fixtures/mining_enemy.gd")
const Controller = preload("res://scripts/systems/tool_mining_controller.gd")
var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func fill_wall(world: Node3D) -> void:
	world.grid.clear()
	world.mining_work.clear()
	for x in range(-1, 2):
		for y in 3:
			for z in range(-4, -1):
				world.grid[Vector3i(x, y, z)] = "stone_a"


func _run() -> void:
	var world = World.new()
	world._built = true
	root.add_child(world)
	var player = Player.new()
	root.add_child(player)
	var operator = Operator.new()
	var resolver = Resolver.new()
	var drops: Array = []
	world.drop_spawned.connect(func(cell: Vector3i, key: String, amount: int) -> void: drops.append([cell, key, amount]))
	fill_wall(world)
	var snapshot: Dictionary = operator.preview(world, player)
	check(snapshot.cells == [Vector3i(0, 1, -2)], "normal pickaxe must select one nearest cell")
	var first: Array = resolver.resolve(world, snapshot)
	check(first.size() == 1 and not first[0].broken and is_equal_approx(first[0].progress, 0.6), "first swing must preserve partial work")
	resolver.resolve(world, snapshot)
	check(not world.has_block(Vector3i(0, 1, -2)) and world.has_block(Vector3i(0, 0, -2)), "second swing must break only the aimed layer")
	check(drops.size() == 1, "one broken cell must emit one drop")
	resolver.resolve(world, snapshot)
	check(drops.size() == 1, "stale snapshots must not duplicate drops")
	fill_wall(world)
	var second_operator = Operator.new()
	resolver.resolve(world, operator.preview(world, player))
	resolver.resolve(world, second_operator.preview(world, player))
	check(not world.has_block(Vector3i(0, 1, -2)), "two miners must share grid work")
	fill_wall(world)
	operator.grant_range_swing()
	check(operator.preview(world, player).cells.size() == 3, "vertical range swing must cover three cells")
	operator.vertical = false
	check(operator.preview(world, player).cells.size() == 3, "horizontal range swing must cover three cells")
	operator.aim_height = 0
	operator.vertical = true
	world.grid[Vector3i(0, -1, -2)] = "stone_a"
	check(operator.preview(world, player).cells.size() == 2, "range swing must preserve floor cells")
	operator.aim_height = 1
	operator.grant_golden_mining()
	check(operator.preview(world, player).cells.size() == 27, "golden swing must preview all 27 cells")
	operator.equip(1)
	snapshot = operator.preview(world, player)
	var before: int = drops.size()
	check(operator.begin_operation(snapshot, true), "ready operation must start")
	var results: Array = resolver.resolve(world, snapshot)
	check(results.size() == 27 and drops.size() - before == 27, "golden heavy swing must resolve exactly its preview")
	check(operator.golden_seconds == 0.0, "effective golden swing must consume the one-shot")
	check(not operator.begin_operation(snapshot, true), "cooldown must reject repeated input")
	operator.equip(0)
	check(operator.cooldown > 0.0, "switching tool must not bypass cooldown")
	operator.advance(0.8)
	check(operator.cooldown == 0.0, "cooldown must recover over simulation time")
	operator.grant_golden_mining()
	operator.begin_operation(operator.preview(world, player), false)
	check(operator.golden_seconds > 0.0, "empty swings must preserve golden charge")
	operator.advance(21.0)
	check(operator.range_seconds == 0.0 and operator.golden_seconds == 0.0, "talents must expire")
	fill_wall(world)
	operator.equip(3)
	snapshot = operator.preview(world, player)
	check(resolver.resolve(world, snapshot).is_empty() and world.mining_work.is_empty(), "ordinary gun must never mine")
	check(second_operator.range_seconds == 0.0, "one player's talent must not affect another")
	operator.equip(2)
	operator.grant_longblade()
	snapshot = operator.preview(world, player)
	check(snapshot.cells.size() == 2, "longblade must cover two consecutive cells")
	resolver.resolve(world, snapshot)
	check(is_equal_approx(world.mining_progress(Vector3i(0, 1, -2)), 0.1), "blade must use its own weak mining rate")
	operator.advance(16.0)
	check(operator.preview(world, player).cells.size() == 1, "longblade coverage must expire")
	# Mouse targeting uses the hovered cell, independently of heading or R height.
	var mouse_operator = Operator.new()
	fill_wall(world)
	var hovered := {"mouse": true, "hit": true, "pos": Vector3i(0, 2, -2), "normal": Vector3i.BACK}
	snapshot = mouse_operator.preview(world, player, hovered)
	check(snapshot.cells == [Vector3i(0, 2, -2)] and snapshot.aim_height == 2, "mouse must select the hovered upper cell without cycling height")
	check(mouse_operator.preview(world, player, {"mouse": true, "hit": false}).cells.is_empty(), "empty cursor must not fall back to heading selection")
	hovered.pos = Vector3i(0, 1, -3)
	check(mouse_operator.preview(world, player, hovered).reason == "被前方矿块遮挡", "mouse must not mine through a foreground mineral")
	world.grid[Vector3i(0, 1, -8)] = "gold"
	hovered.pos = Vector3i(0, 1, -8)
	check(mouse_operator.preview(world, player, hovered).reason == "距离太远，请靠近", "mouse must preserve tool reach")
	world.grid[Vector3i(0, 1, 2)] = "gold"
	hovered.pos = Vector3i(0, 1, 2)
	hovered.normal = Vector3i.FORWARD
	check(mouse_operator.preview(world, player, hovered).cells == [Vector3i(0, 1, 2)], "mouse must work while the actor initially faces away")
	world.grid[Vector3i(0, -1, 0)] = "stone_a"
	hovered.pos = Vector3i(0, -1, 0)
	check(mouse_operator.preview(world, player, hovered).reason == "结构不能开采", "mouse must preserve structural floor")
	# Non-cubic grid regression: crossing the 2m X boundary occurs at t=1m.
	world.grid.clear()
	world.grid[Vector3i(1, 1, 0)] = "stone_a"
	var cast: Dictionary = world.raycast_block(Vector3(0, 1, 0), Vector3.RIGHT, 0.9)
	check(not cast.hit, "DDA must honor physical reach on non-cubic X cells")
	cast = world.raycast_block(Vector3(0, 1, 0), Vector3.RIGHT, 1.1)
	check(cast.hit and cast.pos == Vector3i(1, 1, 0), "DDA must cross a 2m X cell at the correct distance")
	world.grid[Vector3i(0, -1, 0)] = "stone_a"
	check(not world.apply_mining_work(Vector3i(0, -1, 0), 100.0).accepted, "structure must reject mining work")
	check(not world.apply_mining_work(Vector3i(1, 1, 0), -1.0).accepted, "invalid work must not heal or corrupt progress")
	check(not world.apply_mining_work(Vector3i(1, 1, 0), NAN).accepted, "NaN work must not corrupt progress")
	# Real integration: one action hits an enemy and a rock, rather than skipping P04.
	fill_wall(world)
	var controller = Controller.new()
	controller.name = "Mining"
	world.name = "World"
	player.name = "Miner"
	controller.world_path = NodePath("../World")
	controller.player_paths.append(NodePath("../Miner"))
	root.add_child(controller)
	controller.set_physics_process(false)
	var enemy = Enemy.new()
	enemy.position = Vector3(0, 1, -0.7)
	enemy.add_to_group("crawler")
	root.add_child(enemy)
	check(controller.perform(0), "integration swing must execute")
	check(enemy.hp == 9 and world.mining_progress(Vector3i(0, 1, -2)) > 0.0, "same swing must hit both an enemy and a mineral")
	player.is_down = true
	controller.operators[0].advance(1.0)
	check(not controller.perform(0), "downed miners must not operate tools")
	player.is_down = false
	controller.set_tool(0, 3)
	enemy.position.z = -3.0
	controller.perform(0)
	check(enemy.hp == 9, "ordinary ranged attack must not cross a solid mineral wall")
	world.grid.clear()
	controller.set_tool(0, 2)
	controller.operators[0].advance(1.0)
	controller.operators[0].grant_longblade()
	controller.perform(0)
	check(enemy.hp == 6, "longblade must extend combat reach by the same extra grid cell")
	# Real camera projection, mouse events, one actor and animated drops.
	controller.queue_free()
	enemy.queue_free()
	player.queue_free()
	world.queue_free()
	await process_frame
	var scene: Node3D = load("res://scenes/levels/tool_mining_demo.tscn").instantiate()
	root.add_child(scene)
	for frame in 5:
		await physics_frame
	var mining: Node = scene.get_node("Mining")
	check(get_nodes_in_group("player").size() == 1 and mining.operators.size() == 1, "single-player scene must contain one actor and operator")
	var camera: Camera3D = scene.get_node("MineCart/Camera3D")
	var point: Vector3 = scene.get_node("VoxelWorld").cell_to_global(Vector3i(0, 1, -10)) + Vector3(0, 0, 0.49)
	var pointer: Vector2 = camera.unproject_position(point)
	var selected: Dictionary = mining.mouse_selection(pointer)
	check(selected.get("hit", false) and selected.pos == Vector3i(0, 1, -10), "camera ray must select the mineral under the pointer")
	check(not mining.mouse_selection(Vector2(-20, -20)).hit, "pointer outside viewport must not select")
	check(not mining.mouse_selection(Vector2(40, 40)).hit, "HUD must prevent click-through selection")
	var motion := InputEventMouseMotion.new()
	motion.position = pointer
	motion.global_position = pointer
	root.push_input(motion, true)
	await physics_frame
	await physics_frame
	print("CURSOR_SELECTION ", mining.targets_of(0))
	check(mining.targets_of(0).size() == 1, "real mouse motion must update the target preview")
	var button := InputEventMouseButton.new()
	# parse_input_event accepts window pixels; the camera projects viewport pixels.
	button.position = root.get_final_transform() * pointer
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = true
	Input.parse_input_event(button)
	await create_timer(3.2).timeout
	button.pressed = false
	Input.parse_input_event(button)
	check(mining.total_broken >= 1, "holding the actual left mouse button must mine")
	await create_timer(1.6).timeout
	var loot: Array[Node] = get_nodes_in_group("mineral_drop")
	check(mining.furnace.total_absorbed > 0, "mined common stone must automatically reach the furnace")
	var remaining_common := 0
	for drop in loot:
		if drop.mineral_key in ["stone_a", "stone_b"]:
			remaining_common += 1
	check(remaining_common == 0, "absorbed stone must leave no duplicate collectible")
	check(scene.get_node("Player1/Inventory").counts().is_empty(), "ordinary stone must not enter the rare-ore backpack")
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("TOOL_MINING_OK ", checks, " checks")
		quit(0)
	else:
		print("TOOL_MINING_FAILED ", failures.size(), "/", checks)
		quit(1)
