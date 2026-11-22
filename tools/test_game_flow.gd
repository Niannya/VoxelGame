extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var flow: Variant = load("res://scenes/game_flow.tscn").instantiate()
	root.add_child(flow)
	await process_frame
	if flow._active_scene.name != "CharacterSelect":
		_fail("F5 did not start at character selection")
		return

	var selection: Variant = flow._active_scene
	selection.selected_char = 2
	selection.get_node("BtnConfirm").pressed.emit()
	await process_frame
	await process_frame
	if flow._active_scene.name != "MinePlayground":
		_fail("confirm did not enter the mine")
		return
	# 2-player MVP：关卡里是 Player1 / Player2（同属 player 组），不再有单个 Player 节点
	var players: Array = []
	for p in get_nodes_in_group("player"):
		if flow._active_scene.is_ancestor_of(p):
			players.append(p)
	if players.is_empty():
		_fail("mine has no player instance")
		return
	for p in players:
		if p.get_node_or_null("Visual/SelectedCharacter") == null:
			_fail("selected character model was not carried into the mine (%s)" % p.name)
			return

	flow._active_scene.get_node("Mining").broken_by_type["gold"] = 3
	flow._on_end_run()
	await process_frame
	await process_frame
	if flow._active_scene.name != "ResultFail":
		_fail("ending the run did not show the result")
		return
	if flow._active_scene.run_character_index != 2 or flow._active_scene.run_ore_counts.get("gold") != 3:
		_fail("character or ore count was lost")
		return

	flow._active_scene.get_node("BtnBack").pressed.emit()
	await process_frame
	await process_frame
	if flow._active_scene.name != "CharacterSelect":
		_fail("result did not return to selection")
		return
	print("GAME_FLOW_OK")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
