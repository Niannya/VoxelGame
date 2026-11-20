extends Node
## 一次性截图工具：加载示例场景，等渲染两帧后把视口存成 PNG 并退出。

const OUT_PATH := "D:/GodotProjects/voxel-game/.workbuddy/mine_demo.png"


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw

	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(OUT_PATH)
	if err != OK:
		push_error("截图保存失败：%s" % err)
	else:
		print("截图已保存：%s (%dx%d)" % [OUT_PATH, img.get_width(), img.get_height()])

	get_tree().quit(0)
