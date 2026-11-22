extends Node
## 验证双人版：矿车推进、相机稳定、两人各自朝前高亮并挖矿。

const DIR := "D:/GodotProjects/voxel-game/.workbuddy/"


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout

	var cart := get_node("MinePlayground/MineCart")
	var p1 := get_node("MinePlayground/Player1")
	var p2 := get_node("MinePlayground/Player2")
	var mining := get_node("MinePlayground/Mining")

	await _wait_blocked(cart, 15.0)
	var z0: float = cart.global_position.z
	var face_z: float = z0 - cart.deck_half_depth
	var world_node := get_node("MinePlayground/VoxelWorld")
	var first_ore := 9999
	for k in range(int(floor(z0)), -80, -1):
		if world_node.has_block(Vector3i(0, 1, k)):
			first_ore = k
			break
	print("被挡住：矿车 z=%.2f  车头 z=%.2f  矿面 z=%.2f  空档 %.2f 格" % [
		z0, face_z, first_ore + 0.5, (face_z - (first_ore + 0.5))])

	# 直接调世界函数量窗口，避开帧序干扰
	var lo := 99.0
	var hi := -99.0
	var probe: float = cart.global_position.z + 4.0
	while probe > cart.global_position.z - 4.0:
		var hit: Array = world_node.targets_in_front(
			Vector3(-1.5, cart.global_position.y + 0.05, probe), Vector3(0, 0, -1), mining.reach_distance)
		if not hit.is_empty():
			lo = minf(lo, probe)
			hi = maxf(hi, probe)
		probe -= 0.1
	print("够得着的窗口：z %.2f ~ %.2f（宽 %.2f 米，reach=%.1f）" % [lo, hi, hi - lo, mining.reach_distance])
	# 自然流程：只按 D 走到车头，然后按交互键
	print("P1 出生 z=%.2f，高亮 %d 块" % [p1.global_position.z, mining.targets_of(0).size()])
	Input.action_press("p1_right")
	await get_tree().create_timer(1.6).timeout
	Input.action_release("p1_right")
	await get_tree().create_timer(0.3).timeout
	print("按 D 走到 z=%.2f，高亮 %d 块：%s" % [
		p1.global_position.z, mining.targets_of(0).size(), mining.targets_of(0)])
	var nb: int = mining.total_broken
	Input.action_press("p1_interact")
	await get_tree().create_timer(0.1).timeout
	Input.action_release("p1_interact")
	await get_tree().create_timer(0.2).timeout
	print("按空格后，挖掉 %d 块" % (mining.total_broken - nb))

	# 相机稳定性 + 移动轴方向
	var cam := get_viewport().get_camera_3d()
	var c0: Vector3 = cam.global_position
	p1.global_position.x = 0.0
	await get_tree().create_timer(0.15).timeout
	var p0: Vector3 = p1.global_position

	Input.action_press("p1_forward")
	await get_tree().create_timer(0.45).timeout
	Input.action_release("p1_forward")
	await get_tree().create_timer(0.3).timeout
	print("按 W：dx=%+.2f（应为负=往远墙）  dz=%+.2f（应接近 0）" % [
		p1.global_position.x - p0.x, p1.global_position.z - p0.z])

	p0 = p1.global_position
	Input.action_press("p1_right")
	await get_tree().create_timer(0.45).timeout
	Input.action_release("p1_right")
	await get_tree().create_timer(0.3).timeout
	print("按 D：dx=%+.2f（应接近 0）  dz=%+.2f（应为负=矿车前方）" % [
		p1.global_position.x - p0.x, p1.global_position.z - p0.z])
	print("相机位移 %.2f（应为 0）" % (cam.global_position - c0).length())

	# 两人分别站到车头，面朝矿道
	var stand_z: float = cart.global_position.z - 3.9   # 贴近车头，让第二层也在 reach 内（验证不会一次挖两层）
	var deck_y: float = cart.global_position.y + 0.05
	p1.global_position = Vector3(-1.5, deck_y, stand_z)
	p2.global_position = Vector3(1.5, deck_y, stand_z)
	p1.get_node("Visual").rotation.y = 0.0
	p2.get_node("Visual").rotation.y = 0.0
	await get_tree().create_timer(0.25).timeout

	print("P1 高亮 %d 块：%s" % [mining.targets_of(0).size(), mining.targets_of(0)])
	print("P2 高亮 %d 块：%s" % [mining.targets_of(1).size(), mining.targets_of(1)])

	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(DIR + "mine_targets.png")

	# 一人挖一列，交替按各自的键
	var before: int = mining.total_broken
	Input.action_press("p1_interact")
	await get_tree().create_timer(0.1).timeout
	Input.action_release("p1_interact")
	await get_tree().create_timer(0.1).timeout
	Input.action_press("p2_interact")
	await get_tree().create_timer(0.1).timeout
	Input.action_release("p2_interact")
	await get_tree().create_timer(0.15).timeout
	print("两人各按一次，共挖掉 %d 块" % (mining.total_broken - before))

	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(DIR + "cart_moved.png")

	# 面朝打怪：正面那个应该被打掉，背后那个应该打不到
	var run_mgr := get_node("MinePlayground/RunManager")
	var front: Node3D = load("res://scenes/world/crawler.tscn").instantiate()
	front.add_to_group("crawler")
	run_mgr.add_child(front)
	front.global_position = p1.global_position + Vector3(0, 1.0, -2.2)

	var back: Node3D = load("res://scenes/world/crawler.tscn").instantiate()
	back.add_to_group("crawler")
	run_mgr.add_child(back)
	back.global_position = p1.global_position + Vector3(0, 1.0, 2.2)

	await get_tree().create_timer(0.12).timeout
	var hp_before: int = p1.hp
	Input.action_press("p1_interact")
	await get_tree().create_timer(0.08).timeout
	Input.action_release("p1_interact")
	await get_tree().create_timer(0.15).timeout
	print("面朝打怪：正面还在=%s  背后还在=%s  P1 HP %d→%d" % [
		is_instance_valid(front), is_instance_valid(back), hp_before, p1.hp])

	# 走深一点，复现「已挖 50+ / 11 米」时的画面
	var deep_z: int = int(floor(cart.global_position.z)) - 2
	for row in 26:
		for i in range(-1, 2):
			for j in range(0, 3):
				get_node("MinePlayground/VoxelWorld").break_block(Vector3i(i, j, deep_z - row))
	await get_tree().create_timer(7.0).timeout
	print("走深后：矿车 z=%.2f" % cart.global_position.z)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(DIR + "deep.png")

	get_tree().quit(0)


func _wait_blocked(cart: Node, timeout: float) -> void:
	var t := 0.0
	while t < timeout:
		if cart.blocked:
			return
		await get_tree().create_timer(0.1).timeout
		t += 0.1
