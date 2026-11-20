extends SceneTree
## 烘焙矿洞示例场景。
## 用法：Godot_v4.6.2-stable_win64_console.exe --headless --path <项目> --script res://tools/bake_mine_demo.gd

const SCENE_PATH := "res://scenes/levels/mine_demo.tscn"


func _initialize() -> void:
	var root := Node3D.new()
	root.name = "MineDemo"

	root.add_child(_make_environment())
	root.add_child(_make_fill_light())
	root.add_child(_make_camera())

	var gen = load("res://scripts/tools/mine_generator.gd").new()
	gen.build(root)

	_ensure_dir(SCENE_PATH.get_base_dir())
	_set_owner_recursive(root, root)

	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("pack 失败：%s" % err)
		quit(1)
		return

	err = ResourceSaver.save(packed, SCENE_PATH)
	if err != OK:
		push_error("保存失败：%s" % err)
		quit(1)
		return

	print("已生成 %s" % SCENE_PATH)
	print("节点数：%d" % _count(root))
	root.free()
	quit(0)


func _ensure_dir(res_dir: String) -> void:
	var abs_dir := ProjectSettings.globalize_path(res_dir)
	DirAccess.make_dir_recursive_absolute(abs_dir)


func _count(n: Node) -> int:
	var total := 1
	for c in n.get_children():
		total += _count(c)
	return total


func _set_owner_recursive(node: Node, owner_node: Node) -> void:
	## PackedScene.pack() 只会收录 owner 指向根节点的子节点，程序化建树必须显式设置。
	for child in node.get_children():
		child.owner = owner_node
		_set_owner_recursive(child, owner_node)


func _make_environment() -> WorldEnvironment:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.018, 0.020, 0.028)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.20, 0.22, 0.30)
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.15
	env.ssao_enabled = true
	env.ssao_radius = 2.0
	env.ssao_intensity = 2.2
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.06, 0.09)
	env.fog_density = 0.014
	we.environment = env
	return we


func _make_fill_light() -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.name = "FillLight"
	light.rotation_degrees = Vector3(-62, -38, 0)
	light.light_color = Color(0.62, 0.72, 1.0)
	light.light_energy = 0.45
	light.shadow_enabled = true
	return light


func _make_camera() -> Camera3D:
	## 机位对准通道中段：中心射线在 y=-0.5 处落在 z≈-5.6，
	## 视野下缘 55°、上缘 5°，刚好把矿车（近景）到尽头矿壁整条收入画面。
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.position = Vector3(0, 9.5, 13.0)
	cam.rotation_degrees = Vector3(-30, 0, 0)
	cam.fov = 50.0
	cam.near = 0.1
	cam.far = 200.0
	cam.current = true
	return cam
