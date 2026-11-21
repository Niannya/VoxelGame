extends Node3D
## 可游玩版矿洞：在示例场景之上挂一个可控角色。
## 关掉展示用的固定机位，改用角色自带的跟随相机。

func _ready() -> void:
	var demo_cam := get_node_or_null("MineDemo/Camera3D")
	if demo_cam:
		demo_cam.current = false

	var player_cam := get_node_or_null("Player/Camera3D")
	if player_cam:
		player_cam.make_current()
