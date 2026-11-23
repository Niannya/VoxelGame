extends SceneTree

const NAMES := ["char_01_cuntou", "char_02_baimao", "char_03_fenmao", "char_04_lanmao", "char_05_huangmao", "char_06_hemao"]
const CLIPS := [&"Idle", &"Select", &"Pick", &"Hammer", &"Bow", &"Torch", &"Backpack", &"Canteen"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for character in NAMES:
		var path := "res://assets/characters/rigged/%s.glb" % character
		var packed := load(path) as PackedScene
		if packed == null:
			_fail("missing rigged model: " + path)
			return
		var model := packed.instantiate()
		root.add_child(model)
		var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
		var player := model.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if skeleton == null or skeleton.get_bone_count() != 8 or player == null:
			_fail(character + " skeleton or AnimationPlayer missing")
			return
		for clip in CLIPS:
			if not player.has_animation(clip):
				_fail(character + " missing " + clip)
				return
		model.queue_free()
	await process_frame

	var flow: Variant = load("res://scenes/game_flow.tscn").instantiate()
	root.add_child(flow)
	await process_frame
	var selection: Control = flow._active_scene
	selection._select_character(3)
	var preview_anim := selection._model_instance.get_node("AnimationPlayer") as AnimationPlayer
	if preview_anim.current_animation != "Select":
		_fail("selection switch did not play Select")
		return
	selection.selected_tool = 3
	selection.get_node("BtnConfirm").pressed.emit()
	await process_frame
	await process_frame
	var game_model: Node3D = flow._active_scene.get_node("Player1/Visual/SelectedCharacter")
	var tree := game_model.get_node_or_null("CharacterAnimationTree") as AnimationTree
	if tree == null or not tree.active:
		_fail("gameplay AnimationTree inactive")
		return
	var controller = flow._active_scene.get_node("Player1")._character_animation
	if controller.current_tool_clip() != &"Torch":
		_fail("tool index 3 did not select Torch animation")
		return
	for tool_index in 6:
		controller.set_tool(tool_index)
		if controller.current_tool_clip() != CLIPS[tool_index + 2]:
			_fail("wrong animation for tool " + str(tool_index))
			return
		controller.play_tool_action()
		await process_frame
		if not bool(tree.get("parameters/ToolShot/active")):
			_fail("tool action channel did not fire for " + str(tool_index))
			return
	print("CHARACTER_ANIMATION_OK six rigs, eight clips each, preview and six tool channels")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
