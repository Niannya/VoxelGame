extends SceneTree
const Bag = preload("res://scripts/items/ore_inventory.gd")
const Drop = preload("res://scripts/world/mineral_drop.gd")
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)


func spawn_drop(scene: Node3D, key: String, amount: int, point: Vector3) -> Node3D:
	var drop := Node3D.new()
	drop.set_script(Drop)
	drop.mineral_key = key
	drop.amount = amount
	drop.position = point
	drop.world = scene.get_node("VoxelWorld")
	drop.landing_platform = scene.get_node("MineCart")
	drop.furnace = scene.get_node("Mining").furnace
	root.add_child(drop)
	return drop


func run() -> void:
	var bag = Bag.new()
	bag.slot_limit = 2
	bag.stack_limit = 3
	root.add_child(bag)
	check(not bag.try_add("stone_a", 1), "ordinary stone must not be storable in the rare inventory")
	check(not bag.try_add("unknown", 1), "unknown minerals must not be accepted")
	check(not bag.try_add("gold", 0) and not bag.try_add("gold", -2), "invalid amounts must not corrupt stacks")
	check(bag.try_add("gold", 4), "large amounts must split across available stacks")
	check(bag.slots()[0].count == 3 and bag.slots()[1].count == 1, "stack splitting must preserve quantity")
	check(bag.try_add("gold", 2) and bag.counts().gold == 6, "matching stacks must fill before allocating new slots")
	var before: Dictionary = bag.counts()
	check(not bag.try_add("quartz", 1) and bag.counts() == before, "full bag must reject atomically")
	var copy: Array = bag.slots()
	copy[0].count = 999
	check(bag.counts().gold == 6, "UI snapshots must not mutate the inventory")
	bag.queue_free()
	await process_frame
	var scene: Node3D = load("res://scenes/levels/tool_mining_demo.tscn").instantiate()
	root.add_child(scene)
	for frame in 5:
		await physics_frame
	var player: Node3D = scene.get_node("Player1")
	var inventory: Node = player.get_node("Inventory")
	var collector: Node = player.get_node("LootCollector")
	var furnace: Node3D = scene.get_node("Mining").furnace
	var hud: CanvasLayer = scene.get_node("MiningHUD")
	check(furnace.accepts("stone_a") and furnace.accepts("stone_b") and not furnace.accepts("diamond"), "furnace routing must accept only both ordinary stone variants")
	check(not furnace.receive("gold", 1) and not furnace.receive("stone_a", 0), "furnace must reject rare minerals and invalid quantities")
	var common := spawn_drop(scene, "stone_a", 2, player.global_position + Vector3(0, 0.7, -0.5))
	check(not common.collect(player), "common stone must never be manually added to the backpack")
	await create_timer(0.24).timeout
	check(common.transfer_kind == "furnace", "common stone must start automatic magnetic flight")
	check(not common.absorb_into(furnace), "an active transfer must not be started twice")
	# Move the destination after flight starts; arrival must use its current position.
	furnace.position.x += 0.8
	await create_timer(1.4).timeout
	check(not is_instance_valid(common) and furnace.total_absorbed == 2, "magnet flight must finish at a moving furnace and credit the exact amount")
	check(inventory.counts().is_empty(), "furnace uptake must not credit the backpack")
	var exact := spawn_drop(scene, "stone_b", 1, player.global_position + Vector3.UP)
	check(exact.absorb_into(furnace), "second common variant must use the furnace")
	exact._update_transfer(2.0)
	exact._update_transfer(2.0)
	check(furnace.total_absorbed == 3, "arrival must credit once even if completion is evaluated twice")
	await process_frame
	var rare := spawn_drop(scene, "gold", 2, player.global_position + Vector3(0.6, 1.0, 0))
	check(not rare.absorb_into(furnace), "rare mineral must not be magnetized by furnace")
	await create_timer(1.5).timeout
	check(is_instance_valid(rare) and rare.transfer_kind.is_empty() and rare.is_landed, "uncollected rare ore must finish its drop animation and remain in the world")
	check(rare.get_parent() == scene.get_node("MineCart"), "landed rare ore must attach to the moving cart")
	rare.global_position = player.global_position + Vector3(0.5, 0.3, 0)
	check(collector.pickup_nearest(), "nearby rare ore must be picked up")
	check(inventory.counts().get("gold") == 2 and rare.transfer_kind == "backpack", "manual pickup must commit to inventory before pickup animation")
	check(not rare.collect(player), "one collectible must not enter inventory twice")
	await create_timer(0.5).timeout
	check(not is_instance_valid(rare), "pickup flight must remove the reserved visual after arrival")
	var far := spawn_drop(scene, "quartz", 1, player.global_position + Vector3(5, 0.3, 0))
	check(not far.collect(player), "pickup must enforce player distance")
	far.global_position = player.global_position + Vector3(0.4, 0.3, 0)
	far.velocity = Vector3.ZERO
	far.is_landed = true
	player.is_down = true
	check(not far.collect(player), "downed players must not collect loot")
	player.is_down = false
	# Fill the remaining seven slots to force rejection of a different ore.
	check(inventory.try_add("gold", inventory.slot_limit * inventory.stack_limit - 2), "test bag must fill all remaining capacity")
	var full_counts: Dictionary = inventory.counts()
	check(not collector.pickup_nearest() and not far._taken and inventory.counts() == full_counts, "full bag must leave the collectible intact and unchanged")
	check(collector.prompt().contains("背包已满"), "full bag must explain why pickup failed")
	# A fresh bag demonstrates the actual E input action and Tab UI toggle.
	for slot in inventory._slots:
		slot.key = ""
		slot.count = 0
	Input.action_press("p1_pickup")
	await create_timer(0.25).timeout
	Input.action_release("p1_pickup")
	check(inventory.counts().get("quartz") == 1, "E pickup action must put nearby rare ore into inventory")
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	root.push_input(tab, true)
	check(hud._bag_panel.visible and hud.pointer_blocked(Vector2(1000, 500)), "Tab must open the inventory and block mining through the panel")
	root.push_input(tab, true)
	check(not hud._bag_panel.visible, "Tab must close the inventory")
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("LOOT_ROUTING_OK ", checks, " checks")
		quit(0)
	else:
		print("LOOT_ROUTING_FAILED ", failures.size(), "/", checks)
		quit(1)
