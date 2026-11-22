extends AnimatableBody3D
## 移动平台式矿车：自动向前推进，前方有矿则停下，玩家挖开后继续走。
## 平台顶面（本节点原点所在的 y）就是玩家站立面。

@export var world_path: NodePath
@export var speed: float = 2.2
@export var deck_half_width: float = 0.8
@export var deck_half_depth: float = 1.0
@export var clearance_height: float = 2.45

var blocked: bool = false

var _world: Node3D
var _last_cut_z: float = 1e9


func _ready() -> void:
	_world = get_node_or_null(world_path)
	if _world:
		_world.update_cutaway(global_position, deck_half_depth)


func _physics_process(delta: float) -> void:
	if _world == null:
		return

	var step := speed * delta
	var next := global_position + Vector3(0, 0, -step)

	# 用车身包围盒探前方一格，有矿就停住，等玩家挖开
	blocked = _world.is_blocked_at(
		next,
		deck_half_width,
		deck_half_depth,
		global_position.y + 0.05,
		global_position.y + clearance_height)

	if not blocked:
		global_position = next

	# 走出一段就重算虚化范围
	if absf(global_position.z - _last_cut_z) > 0.5:
		_last_cut_z = global_position.z
		_world.update_cutaway(global_position, deck_half_depth)
