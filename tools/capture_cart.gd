extends Node
## 验证：朝向前方高亮 → 按 F 挖掉 → 矿车继续推进；以及玩家走动时相机不动。

const DIR := "D:/GodotProjects/voxel-game/.workbuddy/"


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout

	var world := get_node("MinePlayground/VoxelWorld")
	var cart := get_node("MinePlayground/MineCart")
	var player := get_tree().get_first_node_in_group("player")
	var mining := get_node("MinePlayground/Mining")

	await _wait_blocked(cart, 15.0)
	var z0: float = cart.global_position.z
	print("被挡住：矿车 z=%.2f  卡住=%s" % [z0, cart.blocked])

	# 矿车停着时玩家走动，相机不该动
	var cam := get_viewport().get_camera_3d()
	var p0: Vector3 = player.global_position
	var c0: Vector3 = cam.global_position
	Input.action_press("move_left")
	await get_tree().create_timer(0.5).timeout
	Input.action_release("move_left")
	await get_tree().create_timer(0.3).timeout
	print("玩家走动：人移动 %.2f，相机移动 %.2f" % [
		(player.global_position - p0).length(),
		(cam.global_position - c0).length()])

	# 走到车头附近并面朝矿道深处（-Z），拍一张带高亮的图
	var stand_z: float = cart.global_position.z - 3.0
	player.global_position = Vector3(0.0, cart.global_position.y + 0.05, stand_z)
	player.get_node("Visual").rotation.y = 0.0
	await get_tree().create_timer(0.25).timeout
	var t: Array = mining.targets()
	print("中间列高亮目标 %d 个：%s" % [t.size(), t])
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(DIR + "mine_targets.png")

	# 三列各按一次 F
	for col in [-2.0, 0.0, 2.0]:
		player.global_position = Vector3(col, cart.global_position.y + 0.05, stand_z)
		player.get_node("Visual").rotation.y = 0.0
		await get_tree().create_timer(0.15).timeout
		var before: int = mining.total_broken
		var n: int = mining.targets().size()
		Input.action_press("mine")
		await get_tree().create_timer(0.1).timeout
		Input.action_release("mine")
		await get_tree().create_timer(0.15).timeout
		print("  x=%.0f：高亮 %d 块，按 F 挖掉 %d 块" % [col, n, mining.total_broken - before])

	await _wait_moved(cart, z0, 10.0)
	await _wait_blocked(cart, 15.0)
	print("挖完后：矿车 z=%.2f  前进 %.2f" % [cart.global_position.z, z0 - cart.global_position.z])

	var local: Vector3 = cart.to_local(player.global_position)
	print("玩家相对平台：%s（半宽 %.1f / 半深 %.1f）" % [
		local, cart.deck_half_width, cart.deck_half_depth])

	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(DIR + "cart_moved.png")

	get_tree().quit(0)


func _wait_blocked(cart: Node, timeout: float) -> void:
	var t := 0.0
	while t < timeout:
		if cart.blocked:
			return
		await get_tree().create_timer(0.1).timeout
		t += 0.1


func _wait_moved(cart: Node, from_z: float, timeout: float) -> void:
	var t := 0.0
	while t < timeout:
		if absf(cart.global_position.z - from_z) > 0.05:
			return
		await get_tree().create_timer(0.1).timeout
		t += 0.1
