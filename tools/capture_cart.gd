extends Node
## 验证：矿车自动前进 → 被矿体挡住 → 挖开 → 继续走；以及玩家走动时相机不动。

const DIR := "D:/GodotProjects/voxel-game/.workbuddy/"


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout

	var world := get_node("MinePlayground/VoxelWorld")
	var cart := get_node("MinePlayground/MineCart")
	var player := get_tree().get_first_node_in_group("player")

	await _wait_blocked(cart, 15.0)
	var z0: float = cart.global_position.z
	print("被挡住：矿车 z=%.2f  卡住=%s  隐藏=%d" % [z0, cart.blocked, world.hidden_count()])

	# 矿车停着时玩家在平台上走动，相机不该动
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

	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(DIR + "cart_blocked.png")

	# 找正前方第一排有矿的格子
	var block_z := 9999
	for k in range(int(floor(z0)), -80, -1):
		if world.has_block(Vector3i(0, 0, k)):
			block_z = k
			break
	print("前方阻挡排 z=%d" % block_z)

	# 挖开五排，每排就是整面矿（3 格宽 × 3 格高）
	for row in 5:
		for i in range(-1, 2):
			for j in range(0, 3):
				world.break_block(Vector3i(i, j, block_z - row))

	await _wait_moved(cart, z0, 10.0)
	await _wait_blocked(cart, 15.0)
	var z1: float = cart.global_position.z
	print("挖开后：矿车 z=%.2f  前进 %.2f  卡住=%s" % [z1, z0 - z1, cart.blocked])

	var local: Vector3 = cart.to_local(player.global_position)
	print("玩家相对平台：%s（平台半宽 %.1f / 半深 %.1f）" % [
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
	## 挖完之后要先等它真的动起来，否则读到的是上一帧的 blocked
	var t := 0.0
	while t < timeout:
		if absf(cart.global_position.z - from_z) > 0.05:
			return
		await get_tree().create_timer(0.1).timeout
		t += 0.1
