extends Node3D
## A self-contained single-player mouse-aim workbench for P03/P04.
const Art = preload("res://scripts/world/mine_art.gd")


func _ready() -> void:
	$Mining.demo_talents = true
	$RunManager.set_process(false)
	$Player1.set_character_model(preload("res://assets/characters/char_01_cuntou.glb"))
	$Player1/Visual.rotation.y = 0.0
	var art := Node3D.new()
	art.set_script(Art)
	add_child(art)
	art.install($MineCart, $VoxelWorld)
	# Teach the 3-layer clear-to-proceed loop from the first visible wall.
	$Mining.set_tool(0, 0)
	$MiningHUD.set_workbench(true)
	var camera: Camera3D = $MineCart/Camera3D
	camera.position = Vector3(12, 10, 8)
	camera.look_at($MineCart.to_global(Vector3(0, 0.8, -3.5)))
	camera.fov = 48.0


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		get_tree().reload_current_scene()
