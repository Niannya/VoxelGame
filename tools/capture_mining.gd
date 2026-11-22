extends Node
## 一次性验证：悬停命中 → 截图 → 按住挖矿 → 截图 → 打印计数。

const DIR := "D:/GodotProjects/voxel-game/.workbuddy/"


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout

	var mining := get_node("MinePlayground/Mining")
	var vp := get_viewport()
	var size := vp.get_visible_rect().size
	var aim := Vector2(size.x * 0.5, size.y * 0.40)
	mining.aim_override = aim

	await get_tree().create_timer(0.25).timeout
	print("命中: ", mining.has_hover(), "  方块坐标: ", mining.hovered_block())

	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(DIR + "mine_hover.png")

	Input.action_press("mine")
	await get_tree().create_timer(0.42).timeout
	print("蓄力中描边色: ", mining._outline_mat.albedo_color)
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(DIR + "mine_charge.png")

	await get_tree().create_timer(0.55).timeout
	Input.action_release("mine")
	await get_tree().create_timer(0.3).timeout

	print("已挖数量: ", mining.total_broken, "  分项: ", mining.broken_by_type)

	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(DIR + "mine_after.png")

	# 验证跳跃能跳出坑
	var player := get_tree().get_first_node_in_group("player")
	var y_before: float = player.global_position.y
	Input.action_press("jump")
	await get_tree().create_timer(0.12).timeout
	Input.action_release("jump")
	var y_peak: float = player.global_position.y
	print("跳跃: y %.2f -> %.2f  跳高 %.2f" % [y_before, y_peak, y_peak - y_before])

	get_tree().quit(0)
