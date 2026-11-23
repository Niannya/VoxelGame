extends Node
const Catalog = preload("res://scripts/items/mineral_catalog.gd")
var miner: Node3D
var inventory: Node
var notice: String = ""
var _notice_time := 0.0
var _cooldown := 0.0


func _ready() -> void:
	var action: String = miner.action_prefix + "_pickup"
	if not InputMap.has_action(action):
		InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode = KEY_E
		InputMap.action_add_event(action, key)


func _physics_process(delta: float) -> void:
	_notice_time = maxf(0.0, _notice_time - delta)
	_cooldown = maxf(0.0, _cooldown - delta)
	if is_instance_valid(miner) and not miner.is_down and _cooldown == 0.0 and Input.is_action_pressed(miner.action_prefix + "_pickup"):
		pickup_nearest()
		_cooldown = 0.18


func nearest() -> Node3D:
	if not is_instance_valid(miner) or miner.is_down:
		return null
	var found: Node3D
	var best := INF
	for node in get_tree().get_nodes_in_group("mineral_drop"):
		if not node.can_pick_up(miner):
			continue
		var distance: float = node.global_position.distance_squared_to(miner.global_position)
		if distance < best:
			best = distance
			found = node
	return found


func pickup_nearest() -> bool:
	var drop := nearest()
	if drop == null:
		return false
	var label: String = Catalog.NAMES.get(drop.mineral_key, drop.mineral_key)
	if not inventory.can_add(drop.mineral_key, drop.amount):
		notice = "背包已满，%s留在地上" % label
		_notice_time = 0.8
		return false
	if drop.collect(miner):
		notice = "已拾取 %s ×%d" % [label, drop.amount]
		_notice_time = 0.8
		return true
	return false


func prompt() -> String:
	if _notice_time > 0.0:
		return notice
	var drop := nearest()
	if drop == null:
		return "靠近高级矿石，按 E 拾取"
	var mineral_name: String = Catalog.NAMES.get(drop.mineral_key, drop.mineral_key)
	return "E 拾取 %s ×%d" % [mineral_name, drop.amount] if inventory.can_add(drop.mineral_key, drop.amount) else "背包已满 · %s ×%d" % [mineral_name, drop.amount]
