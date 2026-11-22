extends SceneTree
## 生成双人输入映射并写回 project.godot 的 [input] 段。
## 用脚本生成而不是手写，是为了让 Godot 自己写出正确的 InputEventKey 序列化格式。
##
## P1: WASD + 空格(交互)　P2: 方向键 + 小键盘0(交互)
## 交互键同时管挖矿和打怪，没有跳跃。

func _initialize() -> void:
	var actions := {
		"p1_left": [KEY_A],
		"p1_right": [KEY_D],
		"p1_forward": [KEY_W],
		"p1_back": [KEY_S],
		"p1_interact": [KEY_SPACE],

		"p2_left": [KEY_LEFT],
		"p2_right": [KEY_RIGHT],
		"p2_forward": [KEY_UP],
		"p2_back": [KEY_DOWN],
		"p2_interact": [KEY_KP_0],
	}

	for action_name in actions:
		var events: Array = []
		for key in actions[action_name]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			events.append(ev)
		ProjectSettings.set_setting("input/" + action_name, {"deadzone": 0.2, "events": events})

	# 清掉旧的单人动作，避免残留
	for old in ["move_left", "move_right", "move_forward", "move_back", "jump", "mine", "p1_mine", "p2_mine", "p1_jump", "p2_jump"]:
		ProjectSettings.set_setting("input/" + old, null)

	var err := ProjectSettings.save()
	print("保存 project.godot: ", err)
	quit(0)
