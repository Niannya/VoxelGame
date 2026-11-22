extends Node3D
## 矿道爬虫：从矿车后方飘过来，贴上人扣血，然后自己消失。
## 不做寻路 —— 直接朝目标飘，原型阶段够用。

@export var speed: float = 2.6
@export var damage: int = 1
@export var hit_range: float = 1.0

var _target: Node3D


func _ready() -> void:
	_target = _nearest_player()


func _process(delta: float) -> void:
	if not is_instance_valid(_target) or _target.is_down:
		_target = _nearest_player()
		if _target == null:
			return

	var to := (_target.global_position + Vector3(0, 1.0, 0)) - global_position
	if to.length() <= hit_range:
		if _target.has_method("take_hit"):
			_target.take_hit(damage)
		queue_free()
		return

	global_position += to.normalized() * speed * delta
	rotate_y(delta * 2.0)


func _nearest_player() -> Node3D:
	var best: Node3D = null
	var best_d := 1e9
	for p in get_tree().get_nodes_in_group("player"):
		if p.is_down:
			continue
		var d: float = (p as Node3D).global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = p
	return best
