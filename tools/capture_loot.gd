extends SceneTree
const Catalog = preload("res://scripts/items/mineral_catalog.gd")
var _scene: Node3D
var _world: Node3D


func _initialize() -> void:
	run.call_deferred()


func aim(cell: Vector3i) -> Vector2:
	var camera: Camera3D = _scene.get_node("MineCart/Camera3D")
	var point: Vector3 = _world.cell_to_global(cell) + Vector3(0, 0, 0.49)
	var pointer := camera.unproject_position(point)
	var motion := InputEventMouseMotion.new()
	motion.position = pointer
	root.push_input(motion, true)
	return pointer


func button(pointer: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = root.get_final_transform() * pointer
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)


func save(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("LOOT_CAPTURE ", path)


func run() -> void:
	_scene = load("res://scenes/levels/tool_mining_demo.tscn").instantiate()
	root.add_child(_scene)
	_world = _scene.get_node("VoxelWorld")
	var mining: Node3D = _scene.get_node("Mining")
	mining.set_tool(0, 1)
	for frame in 35:
		await process_frame
	var args := OS.get_cmdline_user_args()
	var base: String = args[0]
	var pointer := aim(Vector3i(0, 1, -10))
	await physics_frame
	button(pointer, true)
	var timeout := create_timer(5.0)
	while mining.furnace.total_absorbed == 0 and timeout.time_left > 0:
		await process_frame
	button(pointer, false)
	await create_timer(0.1).timeout
	await save(base + "_入炉.png")
	var rare_cell := Vector3i.ZERO
	for cell in _world.grid:
		if cell.z == -10 and cell.y >= 0 and cell.y < 3 and abs(cell.x) <= 1 and Catalog.is_rare(_world.block_key(cell)):
			rare_cell = cell
			break
	if rare_cell == Vector3i.ZERO:
		push_error("No natural rare ore on the first face")
		quit(1)
		return
	pointer = aim(rare_cell)
	await physics_frame
	button(pointer, true)
	var rare: Node3D
	timeout = create_timer(6.0)
	while rare == null and timeout.time_left > 0:
		for node in get_nodes_in_group("mineral_drop"):
			if Catalog.is_rare(node.mineral_key):
				rare = node
				break
		await process_frame
	button(pointer, false)
	if rare == null:
		push_error("Rare ore was not mined")
		quit(1)
		return
	await create_timer(1.5).timeout
	var player: Node3D = _scene.get_node("Player1")
	var cart: Node3D = _scene.get_node("MineCart")
	var local := cart.to_local(rare.global_position)
	player.global_position = cart.to_global(Vector3(clampf(local.x, -2.2, 2.2), 0.05, clampf(local.z, -3.8, 3.8)))
	await physics_frame
	Input.action_press("p1_pickup")
	await create_timer(0.25).timeout
	Input.action_release("p1_pickup")
	await create_timer(0.5).timeout
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	root.push_input(tab, true)
	await create_timer(0.12).timeout
	await save(base + "_背包.png")
	print("LOOT_CAPTURE_COUNTS furnace=", mining.furnace.total_absorbed, " bag=", player.get_node("Inventory").counts())
	_scene.queue_free()
	await process_frame
	quit()
