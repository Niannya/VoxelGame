extends Node3D
## P03/P04 integration; the voxel world remains the owner of cells and progress.
signal operation_requested(player_index: int, operation: Dictionary)
signal mining_resolved(player_index: int, results: Array)
const Operator = preload("res://scripts/tools/tool_operator.gd")
const Resolver = preload("res://scripts/systems/mining_resolver.gd")
const Drop = preload("res://scripts/world/mineral_drop.gd")
const Furnace = preload("res://scripts/world/mineral_furnace.gd")
const PLAYER_COLORS := [Color(1.0, 0.78, 0.22), Color(0.30, 0.85, 1.0)]
@export var player_paths: Array[NodePath] = []
@export var world_path: NodePath
@export var hud_path: NodePath
@export var demo_talents: bool = false
@export var mouse_aim: bool = false
## Turn this off when P05 takes over operation_requested to avoid double damage.
@export var resolve_prototype_combat: bool = true
var total_broken: int = 0
var broken_by_type: Dictionary = {}
var operators: Array = []
var _players: Array[Node3D] = []
var _world: Node3D
var _hud: CanvasLayer
var _resolver = Resolver.new()
var _targets: Array = []
var _outlines: Array = []
var _previews: Array = []
var _invalid_material: StandardMaterial3D
var _drop_direction := Vector3.BACK
var _pointer_position := Vector2.ZERO
var _has_pointer := false
var _hint_clock := 0.0
var last_result: Array = []
var furnace: Node3D


func _ready() -> void:
	_world = get_node_or_null(world_path)
	_hud = get_node_or_null(hud_path)
	if _world == null:
		push_error("Mining requires a voxel world")
		set_physics_process(false)
		return
	_world.block_broken.connect(_on_block_broken)
	_world.drop_spawned.connect(_on_drop_spawned)
	for path in player_paths:
		var player := get_node_or_null(path) as Node3D
		if player == null:
			continue
		_players.append(player)
		operators.append(Operator.new())
		_targets.append([])
		_previews.append({})
		_outlines.append(_build_outlines(_players.size() - 1))
		_register_inputs(player.action_prefix, _players.size() - 1)
	_setup_furnace()
	_refresh_hud.call_deferred()


func _setup_furnace() -> void:
	if _players.is_empty() or _players[0].get("platform_path") == null:
		return
	var cart := _players[0].get_node_or_null(_players[0].platform_path) as Node3D
	if cart == null:
		return
	furnace = cart.get_node_or_null("Furnace") as Node3D
	if furnace == null:
		furnace = Node3D.new()
		furnace.name = "Furnace"
		furnace.set_script(Furnace)
		furnace.position = Vector3(-1.7, 0.9, 2.7)
		cart.add_child(furnace)


func _register_inputs(prefix: String, index: int) -> void:
	var keys: Array = [KEY_Q, KEY_R, KEY_T, KEY_F, KEY_G] if index == 0 else [KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5]
	var suffixes: Array[String] = ["tool", "axis", "height", "range", "golden"]
	for i in suffixes.size():
		var action := prefix + "_" + suffixes[i]
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = keys[i]
		InputMap.action_add_event(action, event)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_pointer_position = event.position
		_has_pointer = true


func _physics_process(delta: float) -> void:
	for i in _players.size():
		var player := _players[i]
		var operator = operators[i]
		operator.advance(delta)
		if player.is_down:
			_targets[i] = []
			_show(i, [])
			continue
		var prefix: String = player.action_prefix
		if Input.is_action_just_pressed(prefix + "_tool"):
			operator.equip(operator.tool_index + 1)
		if Input.is_action_just_pressed(prefix + "_axis"):
			operator.vertical = not operator.vertical
		if Input.is_action_just_pressed(prefix + "_height"):
			operator.aim_height = (operator.aim_height + 1) % _world.interior_height
		if demo_talents and Input.is_action_just_pressed(prefix + "_range"):
			if operator.tool_index == 2:
				operator.grant_longblade()
			else:
				operator.grant_range_swing()
		if demo_talents and Input.is_action_just_pressed(prefix + "_golden"):
			operator.grant_golden_mining()
		_refresh_targets(i)
		if mouse_aim and i == 0 and _previews[i].get("hit", false) and player.has_method("face_target"):
			player.face_target(_world.cell_to_global(_previews[i].aim), delta)
		if Input.is_action_pressed(prefix + "_interact") or (mouse_aim and i == 0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
			perform(i)
	_hint_clock -= delta
	if _hint_clock <= 0.0:
		_hint_clock = 0.08
		_refresh_hud()


func targets_of(index: int) -> Array:
	return _targets[index] if index >= 0 and index < _targets.size() else []


func set_tool(index: int, tool_index: int) -> void:
	if index >= 0 and index < operators.size():
		operators[index].equip(tool_index)


func _refresh_targets(index: int) -> void:
	var snapshot: Dictionary = _snapshot(index)
	_previews[index] = snapshot
	_targets[index] = snapshot.cells
	if mouse_aim and snapshot.get("hit", false) and _world.is_breakable(snapshot.aim) and snapshot.cells.is_empty():
		_show(index, [snapshot.aim], false)
	else:
		_show(index, snapshot.cells)


func _snapshot(index: int) -> Dictionary:
	var pointer := _pointer_position if _has_pointer else get_viewport().get_mouse_position()
	var selection: Dictionary = mouse_selection(pointer) if mouse_aim and index == 0 else {}
	return operators[index].preview(_world, _players[index], selection)


func mouse_selection(pointer: Vector2) -> Dictionary:
	var empty := {"mouse": true, "hit": false}
	if not get_viewport().get_visible_rect().has_point(pointer):
		return empty
	var control := get_viewport().gui_get_hovered_control()
	if control != null and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return empty
	if _hud != null and _hud.has_method("pointer_blocked") and _hud.pointer_blocked(pointer):
		empty.reason = "移到矿区选块"
		return empty
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return empty
	var origin: Vector3 = _world.to_local(camera.project_ray_origin(pointer))
	var direction: Vector3 = _world.global_basis.inverse() * camera.project_ray_normal(pointer)
	var selection: Dictionary = _world.raycast_block(origin, direction, 100.0)
	selection.mouse = true
	return selection


func perform(index: int) -> bool:
	if index < 0 or index >= _players.size() or _players[index].is_down:
		return false
	var operator = operators[index]
	if operator.cooldown > 0.00001:
		return false
	var snapshot: Dictionary = _snapshot(index)
	var enemies: Array[Node3D] = _enemy_targets(snapshot) if resolve_prototype_combat else []
	if mouse_aim and snapshot.cells.is_empty() and enemies.is_empty():
		return false
	var effective: bool = (not snapshot.cells.is_empty() and snapshot.tool.mining_rate > 0.0) or not enemies.is_empty()
	if not operator.begin_operation(snapshot, effective):
		return false
	operation_requested.emit(index, snapshot)
	_drop_direction = -snapshot.facing
	# The same swing affects both enemy and mineral systems.
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.has_method("take_hit"):
			enemy.take_hit(snapshot.tool.damage)
	last_result = _resolver.resolve(_world, snapshot)
	mining_resolved.emit(index, last_result)
	if _players[index].has_method("show_tool_swing"):
		_players[index].show_tool_swing(snapshot.tool)
	_refresh_targets(index)
	_refresh_hud()
	return true


func _enemy_targets(snapshot: Dictionary) -> Array[Node3D]:
	## Compatibility adapter for P05; P04 itself has no enemy dependency.
	var result: Array[Node3D] = []
	var definition: Resource = snapshot.tool
	var origin: Vector3 = _world.to_global(snapshot.origin)
	var facing: Vector3 = snapshot.facing
	var reach: float = definition.reach
	if snapshot.longblade:
		reach += _world.block_size()[0 if absf(facing.x) > 0.5 else 2]
	var nearest: Node3D
	var nearest_distance: float = INF
	for node in get_tree().get_nodes_in_group("crawler"):
		var enemy := node as Node3D
		if enemy == null or enemy.is_queued_for_deletion():
			continue
		var offset: Vector3 = enemy.global_position - origin
		var distance: float = offset.dot(facing)
		var sideways: float = absf(offset.dot(Vector3(snapshot.side)))
		var width: float = 0.65
		if snapshot.golden or (snapshot.wide and snapshot.shape.begins_with("横")):
			width = 1.5 * _world.block_size()[2 if absf(facing.x) > 0.5 else 0]
		if distance <= 0.0 or distance > reach or sideways > width:
			continue
		var target: Vector3 = _world.to_local(enemy.global_position)
		var line: Vector3 = target - snapshot.origin
		var obstacle: Dictionary = _world.raycast_block(snapshot.origin, line, maxf(0.0, line.length() - 0.35))
		if obstacle.get("hit", false):
			continue
		if snapshot.wide or snapshot.golden or snapshot.longblade:
			result.append(enemy)
		elif distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	if nearest != null:
		result.append(nearest)
	return result


func _build_outlines(index: int) -> Array:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = PLAYER_COLORS[index % PLAYER_COLORS.size()]
	if _invalid_material == null:
		_invalid_material = StandardMaterial3D.new()
		_invalid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_invalid_material.albedo_color = Color("f07865")
	var wire := ImmediateMesh.new()
	wire.surface_begin(Mesh.PRIMITIVE_LINES, material)
	var points := [Vector3(-.5,-.5,-.5), Vector3(.5,-.5,-.5), Vector3(.5,-.5,.5), Vector3(-.5,-.5,.5), Vector3(-.5,.5,-.5), Vector3(.5,.5,-.5), Vector3(.5,.5,.5), Vector3(-.5,.5,.5)]
	for edge in [[0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],[0,4],[1,5],[2,6],[3,7]]:
		wire.surface_add_vertex(points[edge[0]])
		wire.surface_add_vertex(points[edge[1]])
	wire.surface_end()
	var holders: Array = []
	for i in 27:
		var holder := MeshInstance3D.new()
		holder.mesh = wire
		holder.scale = _world.block_size() * 1.025
		holder.visible = false
		holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(holder)
		var fill := MeshInstance3D.new()
		fill.name = "Fill"
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		fill.mesh = box
		var tint := StandardMaterial3D.new()
		tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tint.albedo_color = Color(material.albedo_color, 0.10)
		fill.material_override = tint
		fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(fill)
		holders.append(holder)
	return holders


func _show(index: int, cells: Array, valid: bool = true) -> void:
	for i in _outlines[index].size():
		var holder: MeshInstance3D = _outlines[index][i]
		holder.visible = i < cells.size()
		if holder.visible:
			holder.global_position = _world.cell_to_global(cells[i])
			holder.material_override = null if valid else _invalid_material
			var fill: MeshInstance3D = holder.get_node("Fill")
			fill.material_override.albedo_color = Color(PLAYER_COLORS[index % PLAYER_COLORS.size()] if valid else Color("f07865"), 0.10)


func _on_block_broken(_cell: Vector3i, key: String) -> void:
	total_broken += 1
	broken_by_type[key] = int(broken_by_type.get(key, 0)) + 1


func _on_drop_spawned(cell: Vector3i, key: String, amount: int) -> void:
	var drop := Node3D.new()
	drop.set_script(Drop)
	drop.mineral_key = key
	drop.amount = amount
	drop.world = _world
	drop.furnace = furnace
	drop.launch_direction = _drop_direction
	if not _players.is_empty() and _players[0].get("platform_path") != null:
		drop.landing_platform = _players[0].get_node_or_null(_players[0].platform_path)
	var half: Vector3 = _world.block_size() * 0.5
	var offset: float = absf(_drop_direction.x) * half.x + absf(_drop_direction.z) * half.z + 0.16
	drop.position = to_local(_world.cell_to_global(cell) + _drop_direction * offset)
	add_child(drop)


func _refresh_hud() -> void:
	if _hud == null:
		return
	_hud.update_counts(total_broken, broken_by_type)
	if not _hud.has_method("update_tools"):
		return
	var states: Array = []
	for i in operators.size():
		var operator = operators[i]
		var preview: Dictionary = _previews[i]
		var progress: float = _world.mining_progress(_targets[i][0]) if not _targets[i].is_empty() else 0.0
		states.append({"name": operator.tool().display_name, "height": operator.aim_height + 1,
			"axis": "竖" if operator.vertical else "横", "cooldown": operator.cooldown,
			"interval": operator.tool().interval, "progress": progress,
			"range": operator.range_seconds, "golden": operator.golden_seconds,
			"longblade": operator.longblade_seconds,
			"mouse": mouse_aim, "reason": preview.get("reason", ""),
			"name_key": _world.block_key(preview.aim) if preview.get("hit", false) else "",
			"selected_height": int(preview.get("aim_height", operator.aim_height)) + 1,
			"targets": _targets[i].size(), "down": _players[i].is_down, "hp": _players[i].hp})
	_hud.update_tools(states, demo_talents)
	if not _players.is_empty() and _hud.has_method("update_loot"):
		var bag := _players[0].get_node_or_null("Inventory")
		var collector := _players[0].get_node_or_null("LootCollector")
		if bag != null:
			_hud.update_loot(bag.slots(), bag.used_slots(), bag.slot_limit, bag.stack_limit,
				furnace.total_absorbed if is_instance_valid(furnace) else 0,
				collector.prompt() if collector != null else "")
