extends Node3D
## 胡闹矿洞 P0 特效验收台。
##
## 1:1 复原游戏里的俯视视角（相机高度约 8m、42° FOV）和一个小矿洞场景，
## 左边点按钮就地播特效，右边立刻给出该条的触发 / 持续 / 范围 / 清理条件。
## 这一屏就是交给策划和程序的验收依据，也是接进主工程时的参照。

const FONT_PATH := "res://preview/fonts/PreviewSansSC.otf"

const GROUPS := [
	{"title": "① 挖矿链", "ids": ["FX001", "FX002", "FX005", "FX006", "FX007", "FX008"]},
	{"title": "② 绳索", "ids": ["FX009", "FX010"]},
	{"title": "③ 战斗 / 受击", "ids": ["FX011", "FX012", "FX013", "FX014"]},
	{"title": "④ 支撑", "ids": ["FX015", "FX016", "FX017"]},
	{"title": "⑤ 危险 / 坍塌", "ids": ["FX018", "FX019", "FX020", "FX021", "FX022", "FX023"]},
	{"title": "⑥ 救援 / 遮挡", "ids": ["FX024", "FX025", "FX033"]},
]

var _cam: Camera3D
var _world: Node3D
var _ui: CanvasLayer
var _info: RichTextLabel

var _player: Node3D
var _monster: Node3D
var _furnace: Node3D
var _feed_item: Node3D
var _ore := {}
var _posts := []
var _front_wall: Node3D
var _occ_target: Node3D
var _support_pos := Vector3(0.8, 0.0, 3.5)

var _mats := {}
var _hl: FxPickupHighlight
var _rope: FxRope
var _preview: FxPlacementPreview
var _dust: FxDustField
var _dust_level := 0.0
var _danger: FxScreenDanger
var _danger_level := 0.0
var _trans: FxScreenTransition
var _rescue: FxRescue
var _rescue_tw: Tween
var _occ: FxWallOccluder


func _ready() -> void:
	_build_world()
	_build_ui()
	if "--selftest" in OS.get_cmdline_args() or "--selftest" in OS.get_cmdline_user_args():
		_run_selftest.call_deferred()
	if "--shots" in OS.get_cmdline_args() or "--shots" in OS.get_cmdline_user_args():
		_run_shots.call_deferred()


func _run_selftest() -> void:
	## 无头自检：把 24 条全部触发一遍，看有没有脚本错误 / 空节点 / 补间崩溃。
	print("[SELFTEST] start, ids=%d" % FxManager.ids().size())
	var n := 0
	for id in FxManager.ids():
		_trigger(String(id))
		n += 1
		await get_tree().create_timer(0.12).timeout
	print("[SELFTEST] triggered %d / %d" % [n, FxManager.ids().size()])
	await get_tree().create_timer(0.6).timeout
	# 再跑一轮，检查重复触发（打断补间、复用控制器）不会报错
	for id in FxManager.ids():
		_trigger(String(id))
		await get_tree().create_timer(0.06).timeout
	await get_tree().create_timer(0.5).timeout
	FxManager.reset_all()
	await get_tree().process_frame
	print("[SELFTEST] ok")
	get_tree().quit(0)


func _run_shots() -> void:
	## 出图模式：逐条触发并在最精彩的时刻截屏，用于交付前的肉眼验收。
	## 运行：godot --path . --resolution 1600x900 -- --shots
	var out_dir := ProjectSettings.globalize_path("res://preview/_shots_out")
	DirAccess.make_dir_recursive_absolute(out_dir)
	# 每条特效的"最佳帧"等待时长（短生命特效要在消失前抓到）
	var delays := {
		"FX001": 0.08, "FX002": 0.22, "FX005": 0.9, "FX006": 0.14,
		"FX007": 0.28, "FX008": 0.28, "FX009": 0.9, "FX010": 0.9,
		"FX011": 0.14, "FX012": 0.08, "FX013": 0.08, "FX014": 0.5,
		"FX015": 0.5, "FX016": 0.5, "FX017": 0.4, "FX018": 1.1,
		"FX019": 0.75, "FX020": 0.9, "FX021": 0.9, "FX022": 0.9,
		"FX023": 1.15, "FX024": 1.4, "FX025": 0.6, "FX033": 0.9,
	}
	for id in FxManager.ids():
		var key := String(id)
		_reset_all()
		await get_tree().create_timer(0.25).timeout
		_trigger(key)
		await get_tree().create_timer(float(delays.get(key, 0.6))).timeout
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s.png" % [out_dir, key])
		print("[SHOTS] %s" % key)
		await get_tree().create_timer(0.1).timeout
	_reset_all()
	await get_tree().create_timer(0.2).timeout
	print("[SHOTS] done")
	get_tree().quit(0)


# ── 场景 ─────────────────────────────────────────────────────
func _build_world() -> void:
	_world = Node3D.new()
	_world.name = "Mine"
	add_child(_world)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.055, 0.062, 0.078)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.52, 0.58, 0.74)
	env.ambient_light_energy = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 38, 0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 26.0
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-24, -130, 0)
	fill.light_energy = 0.35
	fill.light_color = Color(0.55, 0.68, 1.0)
	add_child(fill)

	_cam = Camera3D.new()
	_cam.position = Vector3(0, 8.0, 7.2)
	_cam.fov = 42.0
	add_child(_cam)
	_cam.look_at(Vector3(0, 0.5, 0.4))
	_cam.current = true

	# 地面：11×11 块棋盘格地砖
	for x in 11:
		for z in 11:
			var px := float(x) - 5.0
			var pz := float(z) - 5.0
			var tone := Color("#3A3D44") if (x + z) % 2 == 0 else Color("#33363C")
			_voxel(Vector3(1, 0.5, 1), tone, Vector3(px, -0.25, pz))

	# 后墙 / 左墙，用深一档的岩色框住构图
	for x in 11:
		_voxel(Vector3(1, 1, 1), Color("#43464E"), Vector3(float(x) - 5.0, 0.5, -5.5))
		_voxel(Vector3(1, 1, 1), Color("#3E4148"), Vector3(float(x) - 5.0, 1.5, -5.5))
	for z in 6:
		_voxel(Vector3(1, 1, 1), Color("#3E4148"), Vector3(-5.5, 0.5, float(z) - 2.0))

	# 三种矿物
	_ore["copper"] = _ore_block(Vector3(-2.6, 0.5, -0.4), FxPalette.ORE_COPPER)
	_ore["iron"] = _ore_block(Vector3(-0.2, 0.5, -2.2), FxPalette.ORE_IRON)
	_ore["crystal"] = _ore_block(Vector3(2.4, 0.5, -1.2), FxPalette.ORE_CRYSTAL)

	# 炉子
	_furnace = Node3D.new()
	_furnace.name = "Furnace"
	_furnace.position = Vector3(3.6, 0.0, 1.6)
	_world.add_child(_furnace)
	var fbody := _voxel(Vector3(1.2, 0.9, 1.2), Color("#5C4A3D"), Vector3(0, 0.45, 0), _furnace)
	fbody.name = "FurnaceBody"
	_voxel(Vector3(0.5, 0.22, 0.02), Color("#FF7A28"), Vector3(0, 0.42, 0.61), _furnace)
	_voxel(Vector3(0.7, 0.14, 1.3), Color("#4A3B31"), Vector3(0, 0.93, 0), _furnace)

	# 绳索两根桩
	for i in 2:
		var post := _voxel(Vector3(0.18, 1.2, 0.18), Color("#6B5A45"),
			Vector3(-3.9 + float(i) * 1.6, 0.6, 2.6))
		post.name = "RopePost%d" % i
		_posts.append(post)

	# 玩家：体素矿工（脚底在原点，接入时把角色根节点对准这里即可）
	# 站在开阔位，保证受击 / 救援等载体特效不被前墙挡住
	_player = Node3D.new()
	_player.name = "Player"
	_player.position = Vector3(-2.0, 0.0, 2.0)
	_world.add_child(_player)
	_voxel(Vector3(0.46, 0.5, 0.32), Color("#3D7BEA"), Vector3(0, 0.55, 0), _player)
	_voxel(Vector3(0.34, 0.34, 0.34), Color("#F0C49B"), Vector3(0, 0.95, 0), _player)
	_voxel(Vector3(0.5, 0.14, 0.5), Color("#E0A63C"), Vector3(0, 1.16, 0), _player)
	_voxel(Vector3(0.14, 0.32, 0.14), Color("#2C3550"), Vector3(-0.12, 0.16, 0), _player)
	_voxel(Vector3(0.14, 0.32, 0.14), Color("#2C3550"), Vector3(0.12, 0.16, 0), _player)

	_monster = _make_monster()

	# 遮挡演示用的前墙：正好挡在相机与专用靶点之间（触发 FX033 才淡出）
	_front_wall = Node3D.new()
	_front_wall.name = "FrontWall"
	_world.add_child(_front_wall)
	for i in 2:
		for h in 2:
			_voxel(Vector3(1, 1, 0.5), Color("#4B4F58"),
				Vector3(float(i) - 0.5, 0.5 + float(h), 1.95), _front_wall)
	# FX033 的射线靶点：放在墙后，专用于演示"墙挡住角色→自动淡出"
	_occ_target = Node3D.new()
	_occ_target.name = "OcclusionTarget"
	_occ_target.position = Vector3(-0.2, 0.0, 1.4)
	_world.add_child(_occ_target)

	# 投炉用的物件：每次演示都会重置
	_spawn_feed_item()


func _make_monster() -> Node3D:
	var m := Node3D.new()
	m.name = "Monster"
	m.position = Vector3(1.9, 0.0, 1.0)
	_world.add_child(m)
	_voxel(Vector3(0.52, 0.46, 0.5), Color("#8C6BC8"), Vector3(0, 0.28, 0), m)
	_voxel(Vector3(0.4, 0.34, 0.4), Color("#9D7DD8"), Vector3(0, 0.68, 0), m)
	_voxel(Vector3(0.08, 0.08, 0.04), Color("#FFE86B"), Vector3(-0.1, 0.7, 0.2), m)
	_voxel(Vector3(0.08, 0.08, 0.04), Color("#FFE86B"), Vector3(0.1, 0.7, 0.2), m)
	return m


func _spawn_feed_item() -> void:
	if is_instance_valid(_feed_item):
		_feed_item.queue_free()
	_feed_item = Node3D.new()
	_feed_item.name = "FeedItem"
	_feed_item.position = _furnace.global_position + Vector3(0, 1.15, 0.9)
	_world.add_child(_feed_item)
	_voxel(Vector3(0.26, 0.26, 0.26), FxPalette.ORE_IRON, Vector3.ZERO, _feed_item)


func _respawn_monster() -> void:
	if is_instance_valid(_monster):
		_monster.queue_free()
	await get_tree().create_timer(0.6).timeout
	_monster = _make_monster()


func _voxel(size: Vector3, color: Color, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _mat(color)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.name = "Voxel"
	var p := parent if parent else _world
	p.add_child(mi)
	return mi


func _ore_block(pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := _voxel(Vector3(0.9, 0.9, 0.9), Color("#7A7C80"), pos)
	# 矿脉：在石头表面贴几粒身份色，本体仍是石头色
	for i in 4:
		var s := 0.16 + 0.06 * float(i % 2)
		var off := Vector3(
			-0.28 + 0.2 * float(i % 2),
			0.3 - 0.16 * float(i / 2),
			0.46)
		var nugget := BoxMesh.new()
		nugget.size = Vector3(s, s, 0.06)
		nugget.material = _mat(color, 1.2)
		var n := MeshInstance3D.new()
		n.mesh = nugget
		n.position = off
		mi.add_child(n)
	return mi


func _mat(color: Color, emissive := 0.0) -> StandardMaterial3D:
	var key := "%s_%.2f" % [color.to_html(false), emissive]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	m.metallic_specular = 0.2
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emissive
	_mats[key] = m
	return m


# ── UI ───────────────────────────────────────────────────────
func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 4
	add_child(_ui)

	var theme := Theme.new()
	if ResourceLoader.exists(FONT_PATH):
		var f = load(FONT_PATH)
		if f:
			theme.default_font = f
	theme.default_font_size = 15

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	margin.theme = theme
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	# 左：特效清单
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", _panel_style())
	left.custom_minimum_size = Vector2(258, 0)
	left.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(left)

	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	left.add_child(lv)

	var title := Label.new()
	title.text = "胡闹矿洞 · P0 特效验收台"
	title.add_theme_font_size_override("font_size", 18)
	lv.add_child(title)

	var sub := Label.new()
	sub.text = "24 项 P0 · Godot 4.7 · 俯视体素"
	sub.add_theme_font_size_override("font_size", 12)
	sub.modulate = Color(1, 1, 1, 0.55)
	lv.add_child(sub)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(250, 500)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for g in GROUPS:
		var gl := Label.new()
		gl.text = g["title"]
		gl.add_theme_font_size_override("font_size", 13)
		gl.modulate = Color(0.62, 0.86, 0.95)
		list.add_child(gl)
		for id in g["ids"]:
			var sp: Dictionary = FxManager.spec(id)
			var b := Button.new()
			b.text = "%s  %s" % [id, sp.get("name", "")]
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.custom_minimum_size = Vector2(0, 29)
			b.add_theme_font_size_override("font_size", 13)
			b.pressed.connect(_trigger.bind(String(id)))
			list.add_child(b)

	var reset := Button.new()
	reset.text = "清场 / 复位（reset_all）"
	reset.custom_minimum_size = Vector2(0, 30)
	reset.pressed.connect(_reset_all)
	lv.add_child(reset)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	# 右：该条的交付信息
	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", _panel_style())
	right.custom_minimum_size = Vector2(392, 0)
	right.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(right)

	var rv := VBoxContainer.new()
	right.add_child(rv)
	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = true
	_info.custom_minimum_size = Vector2(370, 0)
	_info.add_theme_font_size_override("normal_font_size", 13)
	_info.text = "[color=#8FD6E8]点左边的按钮触发特效。[/color]\n这里会显示该条的触发条件、持续时间、作用范围与清理条件。"
	rv.add_child(_info)


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.065, 0.085, 0.88)
	sb.border_color = Color(0.35, 0.45, 0.55, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


func _show_info(id: String) -> void:
	var s: Dictionary = FxManager.spec(id)
	if s.is_empty():
		return
	var dur := float(s.get("duration", 0.0))
	var dur_txt := "持续型（需显式 stop / reset）" if dur <= 0.0 else "%.2fs" % dur
	var rad := float(s.get("radius", 0.0))
	var rad_txt := "—" if rad <= 0.0 else "%.1fm" % rad
	_info.text = "[b][color=#FFD98A]%s · %s[/color][/b]  [color=#9AA6B2]%s / %s[/color]\n\n" % [
			id, s.get("name", ""), s.get("mode", ""), s.get("kind", "")]
	_info.text += "[color=#7FD1C4]触发[/color]  %s\n" % s.get("trigger", "")
	_info.text += "[color=#7FD1C4]持续[/color]  %s      [color=#7FD1C4]范围[/color]  %s\n" % [dur_txt, rad_txt]
	_info.text += "[color=#7FD1C4]清理[/color]  %s\n" % s.get("cleanup", "")
	_info.text += "[color=#7FD1C4]调用[/color]  [code]%s[/code]\n" % s.get("api", "")
	_info.text += "[color=#9AA6B2]说明[/color]  %s" % s.get("note", "")


# ── 触发 ─────────────────────────────────────────────────────
func _trigger(id: String) -> void:
	_show_info(id)
	match id:
		"FX001":
			FxManager.play("FX001", _ore["copper"].global_position, {
				"target": _ore["copper"], "ore_color": FxPalette.ORE_COPPER})
		"FX002":
			FxManager.play("FX002", _ore["copper"].global_position, {
				"ore_color": FxPalette.ORE_COPPER, "ground_y": -0.5})
		"FX005":
			if is_instance_valid(_hl):
				_hl.stop()
				_hl = null
			else:
				_hl = FxManager.attach("FX005", _ore["crystal"])
		"FX006":
			FxManager.play("FX006", _feed_item.global_position + Vector3(0, 0.2, 0))
		"FX007":
			var fx := FxManager.play("FX007", _furnace.global_position, {
				"mouth_offset": Vector3(0, 1.05, 0.6), "item": _feed_item})
			if fx:
				fx.connect("item_consumed", func(): _spawn_feed_item(), CONNECT_ONE_SHOT)
		"FX008":
			FxManager.play("FX008", _player.global_position + Vector3(0, 0.8, 0), {"amount": 12})
		"FX009", "FX010":
			if not is_instance_valid(_rope):
				_rope = FxManager.rope(_posts[0], _posts[1], id == "FX010")
			_rope.set_taut(id == "FX010")
		"FX011":
			FxManager.play("FX011", _monster.global_position + Vector3(0, 0.6, 0),
				{"normal": Vector3(0, 0.6, 1)})
		"FX012":
			FxManager.flash(_player, 0.9)
		"FX013":
			FxManager.flash_monster(_monster, 0.8)
		"FX014":
			var fx14 := FxManager.play("FX014", _monster.global_position, {
				"body": _monster, "tint": Color("#8C6BC8"), "ground_y": 0.02})
			if fx14:
				fx14.connect("body_gone", _respawn_monster, CONNECT_ONE_SHOT)
		"FX015", "FX016":
			if not is_instance_valid(_preview):
				_preview = FxManager.placement_preview(id == "FX015")
			_preview.set_target(Transform3D(Basis.IDENTITY, _support_pos))
			_preview.set_valid(id == "FX015")
		"FX017":
			FxManager.play("FX017", _support_pos, {"footprint": 1.6})
		"FX018":
			if not is_instance_valid(_dust):
				_dust = FxManager.play("FX018", _player.global_position,
					{"ceiling_height": 3.4, "area_radius": 2.4}) as FxDustField
			_dust_level = fmod(_dust_level + 0.34, 1.05)
			if _dust:
				_dust.set_intensity(_dust_level)
		"FX019":
			FxManager.play("FX019", _player.global_position + Vector3(0.8, 0, -0.2))
		"FX020":
			if not is_instance_valid(_danger):
				_danger = FxManager.screen("FX020") as FxScreenDanger
			_danger_level = fmod(_danger_level + 0.34, 1.05)
			_danger.set_intensity(_danger_level)
			_danger.set_critical(_danger_level)
		"FX021":
			var fx21 := FxManager.play("FX021", _player.global_position + Vector3(0, 0, -0.4))
			if fx21:
				fx21.connect("camera_shake", _shake, CONNECT_ONE_SHOT)
		"FX022":
			FxManager.play("FX022", Vector3(0, 0, -0.6), {"area": 4.2})
		"FX023":
			if not is_instance_valid(_trans):
				_trans = FxManager.screen("FX023") as FxScreenTransition
			_trans.reset()
			_trans.play(1.0)
			_trans.transition_finished.connect(func(): _trans.reset(), CONNECT_ONE_SHOT)
		"FX024":
			var res := FxManager.attach("FX024", _player, {"offset": Vector3(0, 0.02, 0)}) as FxRescue
			_rescue = res
			if res:
				if _rescue_tw and _rescue_tw.is_valid():
					_rescue_tw.kill()
				_rescue_tw = create_tween()
				# 复位后控制器会被释放，补间回调必须自己守住有效性
				_rescue_tw.tween_method(func(v):
					if is_instance_valid(res):
						res.set_progress(v), 0.0, 1.0, 2.2)
		"FX025":
			FxManager.play("FX025", _player.global_position, {"player": _player})
		"FX033":
			if is_instance_valid(_occ):
				_occ.stop()
				_occ = null
			else:
				_occ = FxManager.wall_occluder([_front_wall], _occ_target, _cam)


func _shake(strength: float) -> void:
	## 震屏信号的最小实现：玩法侧一般交给自己的相机控制器。
	var base := _cam.position
	var tw := create_tween()
	for i in 5:
		var off := Vector3(randf_range(-1, 1), randf_range(-0.3, 0.3), randf_range(-1, 1)) * strength * 0.14
		tw.tween_property(_cam, "position", base + off, 0.04)
	tw.tween_property(_cam, "position", base, 0.08)


func _reset_all() -> void:
	if _rescue_tw and _rescue_tw.is_valid():
		_rescue_tw.kill()
	FxManager.reset_all()
	_hl = null
	_rope = null
	_preview = null
	_dust = null
	_danger = null
	_trans = null
	_rescue = null
	_occ = null
	_dust_level = 0.0
	_danger_level = 0.0
	_spawn_feed_item()
	_info.text = "[color=#8FD6E8]已清场。[/color] 全屏层已 reset，一次性特效已停止。"
