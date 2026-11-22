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
	print("被挡住：矿车 z=%.2f" % z0)

	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(DIR + "cart_blocked.png")

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
	var stand_z: float = cart.global_position.z - 3.0
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
	Input.action_press("p1_mine")
	await get_tree().create_timer(0.1).timeout
	Input.action_release("p1_mine")
	await get_tree().create_timer(0.1).timeout
	Input.action_press("p2_mine")
	await get_tree().create_timer(0.1).timeout
	Input.action_release("p2_mine")
	await get_tree().create_timer(0.15).timeout
	print("两人各按一次，共挖掉 %d 块" % (mining.total_broken - before))

	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(DIR + "cart_moved.png")

	# 爬虫贴脸验证
	var run_mgr := get_node("MinePlayground/RunManager")
	var c: Node3D = load("res://scenes/world/crawler.tscn").instantiate()
	c.add_to_group("crawler")
	run_mgr.add_child(c)
	c.global_position = p1.global_position + Vector3(0, 1.0, 1.5)
	await get_tree().create_timer(1.2).timeout
	print("P1 被咬后 HP = %d / 3" % p1.hp)

	get_tree().quit(0)


func _wait_blocked(cart: Node, timeout: float) -> void:
	var t := 0.0
	while t < timeout:
		if cart.blocked:
			return
		await get_tree().create_timer(0.1).timeout
		t += 0.1
