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
	if flow._active_scene.get_node_or_null("Player1/Visual/SelectedCharacter") == null:
		_fail("selected character model was not carried into the mine")
		return
	if get_nodes_in_group("player").size() != 1:
		_fail("single-player flow spawned extra actors")
		return

	flow._active_scene.get_node("Mining").broken_by_type["gold"] = 3
	flow._active_scene.get_node("Player1/Inventory").try_add("gold", 2)
	flow._active_scene.get_node("Mining").furnace.receive("stone_a", 1)
	flow._on_end_run()
	await process_frame
	await process_frame
	if flow._active_scene.name != "ResultFail":
		_fail("ending the run did not show the result")
		return
	if flow._active_scene.run_character_index != 2 or flow._active_scene.run_ore_counts.get("gold") != 3:
		_fail("character or ore count was lost")
		return
	if flow._active_scene._players.size() != 1:
		_fail("single-player results contained mock teammates")
		return
	if flow._active_scene.run_inventory_counts.get("gold") != 2 or flow._active_scene.run_furnace_count != 1:
		_fail("inventory or furnace counters were lost at results")
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
