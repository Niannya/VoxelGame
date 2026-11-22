extends Node
## 一局的规则：矿车推进的距离就是分数；爬虫定时从矿车后方刷出；
## 全员倒地就结束本局。

const CRAWLER := preload("res://scenes/world/crawler.tscn")

@export var cart_path: NodePath
@export var hud_path: NodePath
## 每隔多少秒刷一只
@export var spawn_interval: float = 8.0
## 刷在矿车后方多远
@export var spawn_behind: float = 15.0
@export var max_alive: int = 5

var distance: float = 0.0
var running := true

var _cart: Node3D
var _hud: CanvasLayer
var _start_z := 0.0
var _timer := 0.0
var _overlay: Label


func _ready() -> void:
	_cart = get_node_or_null(cart_path)
	_hud = get_node_or_null(hud_path)
	if _cart != null:
		_start_z = _cart.global_position.z

	for p in get_tree().get_nodes_in_group("player"):
		p.downed.connect(_on_downed)

	_build_overlay()
	# 开局给一点缓冲，别一上来就挨打
	_timer = spawn_interval * 0.5


func _process(delta: float) -> void:
	if not running or _cart == null:
		return

	distance = maxf(distance, _start_z - _cart.global_position.z)
	if _hud and _hud.has_method("set_distance"):
		_hud.set_distance(distance)

	_timer -= delta
	if _timer <= 0.0:
		_timer = spawn_interval
		_spawn_crawler()


func _spawn_crawler() -> void:
	var alive := get_tree().get_nodes_in_group("crawler")
	if alive.size() >= max_alive:
		return

	var c := CRAWLER.instantiate() as Node3D
	c.add_to_group("crawler")
	add_child(c)
	# 从矿车后方、两侧墙之间冒出来
	c.global_position = Vector3(
		randf_range(-2.0, 2.0),
		_cart.global_position.y + 1.0,
		_cart.global_position.z + spawn_behind)


func _on_downed(_player: Node) -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if not p.is_down:
			return
	_end_run()


func _end_run() -> void:
	if not running:
		return
	running = false
	if _cart != null:
		_cart.set_physics_process(false)
	if _overlay != null:
		_overlay.visible = true
		_overlay.text = "全员倒地\n矿车推进 %.0f 米" % distance


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)

	_overlay = Label.new()
	_overlay.visible = false
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overlay.add_theme_font_size_override("font_size", 48)
	_overlay.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	layer.add_child(_overlay)
