extends CanvasLayer
## 右下角面板：推进距离 + 已挖总数 + 各类矿石分项。

const TYPE_NAMES := {
	"stone_a": "岩石", "stone_b": "岩石",
	"gold": "黄金",
	"quartz": "石英",
	"diamond": "钻石",
	"emerald": "绿宝石",
}

@onready var _head: Label = $Panel/VBox/Total
@onready var _detail: Label = $Panel/VBox/Detail

var _broken := 0
var _by_type: Dictionary = {}
var _distance := 0.0
var _summary: Label
var _cards: Array = []
var _workbench := false
var _pointer_panels: Array[Control] = []
var _furnace_count: Label
var _bag_status: Button
var _pickup_hint: Label
var _bag_panel: PanelContainer
var _bag_title: Label
var _bag_cells: Array = []


func _ready() -> void:
	$Panel.hide()
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	var top := _panel(screen, Vector2(28, 24), Vector2(1864, 78))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	top.add_child(row)
	var title := _label("胡闹矿洞  /  矿洞试采", 27, Color("f5c460"))
	row.add_child(title)
	var help := _label("鼠标指向选块 · 按住左键开采", 19, Color("a9adba"))
	help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(help)
	_summary = _label("已挖 0", 23, Color("f0ece3"))
	row.add_child(_summary)
	for i in 1:
		var panel := _panel(screen, Vector2(28, -205), Vector2(820, 177))
		panel.anchor_top = 1.0
		panel.anchor_bottom = 1.0
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		panel.add_child(box)
		var heading := _label("矿工", 23, Color("f5c460"))
		box.add_child(heading)
		var state := _label("", 17, Color("d4d5dc"))
		box.add_child(state)
		var progress := ProgressBar.new()
		progress.custom_minimum_size.y = 8
		progress.show_percentage = false
		progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
		progress.max_value = 1.0
		box.add_child(progress)
		var talent := _label("", 17, Color("f5c460"))
		box.add_child(talent)
		var controls := _label("WASD 移动 · 长按左键开采 · E 拾取 · Tab 背包\nQ 换工具 · R 切换范围方向 · F 范围天赋 · G 黄金大开采", 16, Color("9ca4b5"))
		box.add_child(controls)
		_cards.append({"heading": heading, "state": state, "progress": progress, "talent": talent})
	_build_loot_ui(screen)


func _build_loot_ui(screen: Control) -> void:
	var resources := _panel(screen, Vector2(-680, -174), Vector2(652, 146))
	resources.anchor_left = 1.0
	resources.anchor_right = 1.0
	resources.anchor_top = 1.0
	resources.anchor_bottom = 1.0
	var status := VBoxContainer.new()
	status.add_theme_constant_override("separation", 8)
	resources.add_child(status)
	_furnace_count = _label("熔炉 · 已吸收岩石 ×0", 22, Color("ffc982"))
	status.add_child(_furnace_count)
	_bag_status = Button.new()
	_bag_status.text = "矿物背包  0 / 8 格  [Tab]"
	_bag_status.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_bag_status.add_theme_font_size_override("font_size", 21)
	_bag_status.pressed.connect(_toggle_bag)
	status.add_child(_bag_status)
	_pickup_hint = _label("靠近高级矿石，按 E 拾取", 18, Color("cad3de"))
	status.add_child(_pickup_hint)
	_bag_panel = _panel(screen, Vector2(-618, 200), Vector2(590, 440))
	_bag_panel.anchor_left = 1.0
	_bag_panel.anchor_right = 1.0
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	_bag_panel.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	_bag_title = _label("矿物背包", 25, Color("f5c460"))
	_bag_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_bag_title)
	var close := Button.new()
	close.text = "关闭 [Tab]"
	close.pressed.connect(_toggle_bag)
	header.add_child(close)
	content.add_child(_label("高级矿石手动拾取 · 同类矿石自动堆叠", 17, Color("9ca4b5")))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	content.add_child(grid)
	for i in 8:
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(128, 136)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("202635")
		style.set_corner_radius_all(6)
		style.set_content_margin_all(10)
		cell.add_theme_stylebox_override("panel", style)
		grid.add_child(cell)
		var box := VBoxContainer.new()
		cell.add_child(box)
		box.add_child(_label(str(i + 1), 13, Color("6b7587")))
		var name_label := _label("空", 21, Color("7c8493"))
		box.add_child(name_label)
		var quantity := _label("", 23, Color("f5c460"))
		box.add_child(quantity)
		_bag_cells.append({"name": name_label, "quantity": quantity})
	_bag_panel.hide()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_TAB or event.physical_keycode == KEY_TAB):
		_toggle_bag()
		get_viewport().set_input_as_handled()


func _toggle_bag() -> void:
	if _bag_panel != null:
		_bag_panel.visible = not _bag_panel.visible


func update_loot(slots: Array, used: int, limit: int, stack_limit: int, absorbed: int, hint: String) -> void:
	if _furnace_count == null:
		return
	_furnace_count.text = "熔炉 · 已吸收岩石 ×%d" % absorbed
	_bag_status.text = "矿物背包  %d / %d 格  [Tab]" % [used, limit]
	_bag_title.text = "矿物背包  %d/%d · 每格 %d" % [used, limit, stack_limit]
	_pickup_hint.text = hint
	var catalog = preload("res://scripts/items/mineral_catalog.gd")
	for i in _bag_cells.size():
		var slot: Dictionary = slots[i] if i < slots.size() else {"key": "", "count": 0}
		_bag_cells[i].name.text = catalog.NAMES.get(slot.key, "空")
		_bag_cells[i].name.add_theme_color_override("font_color", catalog.COLORS.get(slot.key, Color("7c8493")))
		_bag_cells[i].quantity.text = "×%d" % slot.count if slot.count > 0 else ""


func set_workbench(enabled: bool) -> void:
	_workbench = enabled


func pointer_blocked(pointer: Vector2) -> bool:
	if _bag_panel != null and _bag_panel.visible:
		return true
	for panel in _pointer_panels:
		if panel.is_visible_in_tree() and panel.get_global_rect().has_point(pointer):
			return true
	return false


func update_tools(states: Array, demo: bool) -> void:
	for i in mini(states.size(), _cards.size()):
		var state: Dictionary = states[i]
		var card: Dictionary = _cards[i]
		card.heading.text = "%s  ·  生命 %d" % [state.name, state.hp]
		var target_name: String = TYPE_NAMES.get(state.name_key, "未选择矿块")
		var action: String = state.reason if state.mouse else "面向矿壁出手"
		if state.down:
			action = "倒地，不能出手"
		elif state.cooldown > 0.05:
			action = "冷却 %.1fs" % state.cooldown
		card.state.text = "%s  ·  第 %d 层  ·  %d 个目标  ·  %s" % [target_name, state.selected_height, state.targets, action]
		card.progress.value = state.progress
		card.talent.text = "目标破岩 %d%%" % roundi(state.progress * 100.0)
		if state.range > 0.0:
			card.talent.text += "  |  范围挥镐 %.0fs" % state.range
		if state.golden > 0.0:
			card.talent.text += "  |  黄金大开采待用"
		if state.longblade > 0.0:
			card.talent.text += "  |  长刀 %.0fs" % state.longblade
		if demo and state.range <= 0.0 and state.golden <= 0.0:
			card.talent.text += "  |  " + ("F 试用范围 · G 黄金" if i == 0 else "小键盘4 范围 · 5 黄金")


func _panel(parent: Control, position: Vector2, dimensions: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = position
	panel.size = dimensions
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.064, 0.085, 0.94)
	style.border_color = Color(0.6, 0.49, 0.28, 0.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	_pointer_panels.append(panel)
	return panel


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func update_counts(total: int, by_type: Dictionary) -> void:
	_broken = total
	_by_type = by_type
	_render()


func set_distance(metres: float) -> void:
	_distance = metres
	_render()


func _render() -> void:
	if _summary != null:
		_summary.text = "已挖 %d  ·  %d 种矿物%s" % [_broken, _by_type.size(), "  ·  F8 重置" if _workbench else "  ·  %.0f 米" % _distance]
	if _head == null:
		return
	_head.text = "%.0f 米 · 已挖 %d" % [_distance, _broken]

	var parts: Array[String] = []
	for key in ["gold", "quartz", "diamond", "emerald"]:
		var n: int = _by_type.get(key, 0)
		if n > 0:
			parts.append("%s %d" % [TYPE_NAMES[key], n])

	if parts.is_empty():
		_detail.text = "WASD 移动 · 鼠标指向选块 · 长按左键开采"
	else:
		_detail.text = "  ".join(parts)
