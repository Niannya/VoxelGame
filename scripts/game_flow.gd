extends Node
## 串接角色选择、矿洞和失败结算；F5 从这里开始。

const CHARACTER_SELECT := preload("res://scenes/ui/character_select.tscn")
const MINE_PLAYGROUND := preload("res://scenes/levels/mine_playground.tscn")
const RESULT_FAIL := preload("res://scenes/ui/result_fail.tscn")
const CHARACTER_MODELS := [
	"res://assets/characters/char_01_cuntou.glb",
	"res://assets/characters/char_02_baimao.glb",
	"res://assets/characters/char_03_fenmao.glb",
	"res://assets/characters/char_04_lanmao.glb",
	"res://assets/characters/char_05_huangmao.glb",
	"res://assets/characters/char_06_hemao.glb",
]

var selected_character := 0
var selected_tool := 0
var _active_scene: Node
var _run_overlay: CanvasLayer


func _ready() -> void:
	_show_character_select()


func _clear_stage() -> void:
	if _run_overlay != null:
		remove_child(_run_overlay)
		_run_overlay.queue_free()
		_run_overlay = null
	if _active_scene != null:
		remove_child(_active_scene)
		_active_scene.queue_free()
		_active_scene = null


func _show_character_select() -> void:
	_clear_stage()
	var selection := CHARACTER_SELECT.instantiate()
	_active_scene = selection
	add_child(selection)
	selection.confirmed_requested.connect(_on_character_confirmed)
	var back_button := selection.get_node("BtnBack") as Button
	back_button.text = "退出游戏"
	back_button.pressed.connect(func() -> void: get_tree().quit())


func _on_character_confirmed(character_index: int, tool_index: int) -> void:
	selected_character = character_index
	selected_tool = tool_index
	_start_game.call_deferred()


func _start_game() -> void:
	_clear_stage()
	var mine := MINE_PLAYGROUND.instantiate()
	_active_scene = mine
	add_child(mine)
	mine.get_node("Mining").set_tool(0, mini(selected_tool, 3))
	# Single-player prototype: carry the selected character into the mine.
	var players := get_tree().get_nodes_in_group("player")
	for i in players.size():
		var node := players[i]
		if not node.has_method("set_character_model"):
			continue
		var pick := (selected_character + i) % CHARACTER_MODELS.size()
		node.set_character_model(load(CHARACTER_MODELS[pick]) as PackedScene)
	_add_end_run_button()


func _add_end_run_button() -> void:
	_run_overlay = CanvasLayer.new()
	_run_overlay.name = "RunControls"
	add_child(_run_overlay)
	var button := Button.new()
	button.text = "结束本局"
	button.custom_minimum_size = Vector2(150, 48)
	button.position = Vector2(24, 24)
	_run_overlay.add_child(button)
	button.pressed.connect(_on_end_run)


func _on_end_run() -> void:
	var mining := _active_scene.get_node("Mining")
	var cart := _active_scene.get_node("MineCart") as Node3D
	var result_data := {
		"character": selected_character,
		"tool": selected_tool,
		"ore_counts": mining.broken_by_type.duplicate(),
		"distance": maxi(0, roundi(3.0 - cart.global_position.z)),
		"inventory_counts": _active_scene.get_node("Player1/Inventory").counts(),
		"furnace_count": mining.furnace.total_absorbed if is_instance_valid(mining.furnace) else 0,
	}
	_show_result.call_deferred(result_data)


func _show_result(result_data: Dictionary) -> void:
	_clear_stage()
	var result := RESULT_FAIL.instantiate()
	result.run_character_index = int(result_data.character)
	result.run_distance = int(result_data.distance)
	result.run_ore_counts = result_data.ore_counts
	result.run_inventory_counts = result_data.inventory_counts
	result.run_furnace_count = int(result_data.furnace_count)
	_active_scene = result
	add_child(result)
	result.back_requested.connect(func() -> void: _show_character_select.call_deferred())
