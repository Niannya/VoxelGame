extends SceneTree
## 把移动用的输入动作写进 project.godot 的 [input] 段。
## 用脚本生成而不是手写，是为了让 Godot 自己写出正确的 InputEventKey 序列化格式。

func _initialize() -> void:
	var actions := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"jump": [KEY_SPACE],
	}

	for action_name in actions:
		var events: Array = []
		for key in actions[action_name]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			events.append(ev)
		ProjectSettings.set_setting("input/" + action_name, {"deadzone": 0.2, "events": events})

	# 挖矿：按住鼠标左键
	var mouse_ev := InputEventMouseButton.new()
	mouse_ev.button_index = MOUSE_BUTTON_LEFT
	ProjectSettings.set_setting("input/mine", {"deadzone": 0.2, "events": [mouse_ev]})

	var err := ProjectSettings.save()
	print("保存 project.godot: ", err)
	quit(0)
