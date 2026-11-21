extends Node
## 验证：矿车被矿体挡住 → 挖开 → 自动前进，且玩家留在平台上。

const DIR := "D:/GodotProjects/voxel-game/.workbuddy/"


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(1.2).timeout

	var world := get_node("MinePlayground/VoxelWorld")
	var cart := get_node("MinePlayground/MineCart")
	var player := get_tree().get_first_node_in_group("player")

	var z0: float = cart.global_position.z
	print("起始：矿车 z=%.2f  卡住=%s  隐藏方块=%d" % [z0, cart.blocked, world.hidden_count()])

	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(DIR + "cart_blocked.png")

	# 找到正前方第一排有矿的格子
	var block_z := 9999
	for k in range(int(floor(z0)), -60, -1):
		if world.has_block(Vector3i(0, 0, k)):
			block_z = k
			break
	print("前方阻挡排 z=%d" % block_z)

	# 挖开五排 3 宽 × 2 高，让矿车真正进入矿层
	for row in 5:
		for i in range(-1, 2):
			for j in range(0, 2):
				world.break_block(Vector3i(i, j, block_z - row))

	await get_tree().create_timer(3.0).timeout

	var z1: float = cart.global_position.z
	print("挖开后：矿车 z=%.2f  前进 %.2f  卡住=%s  隐藏=%d" % [
		z1, z0 - z1, cart.blocked, world.hidden_count()])

	var local: Vector3 = cart.to_local(player.global_position)
	print("玩家相对平台：%s（平台半宽 %.1f / 半深 %.1f）" % [
		local, cart.deck_half_width, cart.deck_half_depth])

	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(DIR + "cart_moved.png")

	get_tree().quit(0)
