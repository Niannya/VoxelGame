extends Node
## 一次性验证工具：模拟按住前进键跑一段，打印位移并截图。

const OUT_PATH := "D:/GodotProjects/voxel-game/.workbuddy/playground.png"
const HOLD_SECONDS := 1.2


func _ready() -> void:
	await get_tree().process_frame

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		push_error("找不到 player 组的节点")
		get_tree().quit(1)
		return

	var cam := player.get_node_or_null("Camera3D")
	if cam:
		print("相机欧拉角: ", cam.global_rotation_degrees)
		print("相机当前生效: ", cam.current)

	var start: Vector3 = player.global_position
	print("起始位置: ", start)

	Input.action_press("move_forward")
	for i in 6:
		await get_tree().create_timer(0.2).timeout
		print("  t=%.1fs strength=%.2f vel=%s pos=%s" % [
			(i + 1) * 0.2,
			Input.get_action_strength("move_forward"),
			player.velocity,
			player.global_position,
		])
	Input.action_release("move_forward")
	await get_tree().create_timer(0.35).timeout

	var end: Vector3 = player.global_position
	print("前进后位置: ", end)
	print("位移: ", end - start, "  长度: %.2f" % (end - start).length())
	print("是否在地面: ", player.is_on_floor())

	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img.save_png(OUT_PATH) == OK:
		print("截图已保存: ", OUT_PATH)

	get_tree().quit(0)
