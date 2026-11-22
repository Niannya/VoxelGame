extends SceneTree
## 生成双人输入映射并写回 project.godot 的 [input] 段。
## 用脚本生成而不是手写，是为了让 Godot 自己写出正确的 InputEventKey 序列化格式。
##
## P1: WASD + F(挖) + 空格(跳)
## P2: 方向键 + /(挖) + .(跳)

func _initialize() -> void:
	var actions := {
		"p1_left": [KEY_A],
		"p1_right": [KEY_D],
		"p1_forward": [KEY_W],
		"p1_back": [KEY_S],
		"p1_mine": [KEY_F],
		"p1_jump": [KEY_SPACE],

		"p2_left": [KEY_LEFT],
		"p2_right": [KEY_RIGHT],
		"p2_forward": [KEY_UP],
		"p2_back": [KEY_DOWN],
		"p2_mine": [KEY_SLASH],
		"p2_jump": [KEY_PERIOD],
	}

	for action_name in actions:
		var events: Array = []
		for key in actions[action_name]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			events.append(ev)
		ProjectSettings.set_setting("input/" + action_name, {"deadzone": 0.2, "events": events})

	# 清掉旧的单人动作，避免残留
	for old in ["move_left", "move_right", "move_forward", "move_back", "jump", "mine"]:
		ProjectSettings.set_setting("input/" + old, null)

	var err := ProjectSettings.save()
	print("保存 project.godot: ", err)
	quit(0)
