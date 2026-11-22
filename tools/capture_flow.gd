extends Node
## 验证完整流程：从 game_flow 直接跳到矿洞，检查两个玩家都挂上了角色模型。

const DIR := "D:/GodotProjects/voxel-game/.workbuddy/"


func _ready() -> void:
	var flow: Node = load("res://scenes/game_flow.tscn").instantiate()
	add_child(flow)
	await get_tree().create_timer(0.8).timeout

	flow._on_character_confirmed(0, 0)
	await get_tree().create_timer(1.6).timeout

	var players := get_tree().get_nodes_in_group("player")
	print("矿洞里的玩家数量 = %d" % players.size())
	for p in players:
		var has_model := p.get_node_or_null("Visual/SelectedCharacter") != null
		print("  %s  挂了模型=%s  HP=%d" % [p.name, has_model, p.hp])

	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(DIR + "flow_game.png")

	get_tree().quit(0)
