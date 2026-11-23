extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: Node3D = load("res://scenes/levels/tool_mining_demo.tscn").instantiate()
	root.add_child(scene)
	for frame in 35:
		await process_frame
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "user://tool_mining_preview.png"
	var camera: Camera3D = scene.get_node("MineCart/Camera3D")
	var world: Node3D = scene.get_node("VoxelWorld")
	var pointer: Vector2 = camera.unproject_position(world.cell_to_global(Vector3i(0, 1, -10)) + Vector3(0, 0, 0.49))
	var motion := InputEventMouseMotion.new()
	motion.position = pointer
	root.push_input(motion, true)
	await physics_frame
	await physics_frame
	await _save(output)
	if args.size() > 1 and args[1] == "animation":
		var spawned: Array = []
		world.drop_spawned.connect(func(cell: Vector3i, key: String, _amount: int) -> void: spawned.append([cell, key]))
		var button := InputEventMouseButton.new()
		button.position = root.get_final_transform() * pointer
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = true
		Input.parse_input_event(button)
		var timer := create_timer(5.0)
		while spawned.is_empty() and timer.time_left > 0.0:
			await process_frame
		button.pressed = false
		Input.parse_input_event(button)
		await create_timer(0.18).timeout
		await _save(output.get_basename() + "_掉落.png")
		await create_timer(1.4).timeout
		await _save(output.get_basename() + "_落地.png")
	scene.queue_free()
	await process_frame
	quit()


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(path)
	print("CAPTURE_SAVED ", path, " ", image.get_size())
