extends AnimatableBody3D
## 移动平台式矿车：自动向前推进，前方有矿则停下，玩家挖开后继续走。
## 平台顶面（本节点原点所在的 y）就是玩家站立面。

@export var world_path: NodePath
@export var speed: float = 2.2
@export var deck_half_width: float = 3.0
@export var deck_half_depth: float = 4.5
## 停在矿前面留出的空档（格）
@export var stop_gap: float = 1.0
@export var body_below: float = 0.95
@export var clearance_height: float = 1.95

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

	# 探测范围比车身多出一格：矿车停在矿的前一格，不贴着矿面
	blocked = _world.is_blocked_at(
		next,
		deck_half_width,
		deck_half_depth + stop_gap,
		global_position.y - body_below,
		global_position.y + clearance_height)

	if not blocked:
		global_position = next

	# 走出一段就重算虚化范围
	if absf(global_position.z - _last_cut_z) > 0.5:
		_last_cut_z = global_position.z
		_world.update_cutaway(global_position, deck_half_depth)
