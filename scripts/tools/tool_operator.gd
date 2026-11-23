class_name MineToolOperator
extends RefCounted
## P03: an operation snapshot is also the preview. No grid mutation here.

const Tool = preload("res://scripts/tools/tool_definition.gd")
const CATALOG = [
	preload("res://resources/tools/pickaxe.tres"),
	preload("res://resources/tools/heavy_pickaxe.tres"),
	preload("res://resources/tools/blade.tres"),
	preload("res://resources/tools/pistol.tres"),
]

var tool_index: int = 0
var cooldown: float = 0.0
var aim_height: int = 1
var vertical: bool = true
var range_seconds: float = 0.0
var golden_seconds: float = 0.0
var longblade_seconds: float = 0.0


func advance(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	range_seconds = maxf(0.0, range_seconds - delta)
	golden_seconds = maxf(0.0, golden_seconds - delta)
	longblade_seconds = maxf(0.0, longblade_seconds - delta)


func tool() -> Resource:
	return CATALOG[tool_index]


func equip(index: int) -> void:
	tool_index = posmod(index, CATALOG.size())
	# Preserve cooldown, including across a weapon switch.


func grant_range_swing(seconds: float = 20.0) -> void:
	range_seconds = maxf(range_seconds, seconds)


func grant_golden_mining(seconds: float = 20.0) -> void:
	golden_seconds = maxf(golden_seconds, seconds)


func grant_longblade(seconds: float = 15.0) -> void:
	longblade_seconds = maxf(longblade_seconds, seconds)


func preview(world: Node3D, player: Node3D, selection: Dictionary = {}) -> Dictionary:
	var definition: Resource = tool()
	var facing: Vector3 = player.facing_dir()
	var along_x: bool = absf(facing.x) >= absf(facing.z)
	var forward: Vector3i = Vector3i(1 if facing.x > 0 else -1, 0, 0) if along_x else Vector3i(0, 0, 1 if facing.z > 0 else -1)
	var side: Vector3i = Vector3i(0, 0, 1) if along_x else Vector3i(1, 0, 0)
	var origin: Vector3 = world.to_local(player.global_position)
	origin.y = float(aim_height) * world.block_size().y
	var cast: Dictionary = world.raycast_block(origin, Vector3(forward), definition.reach)
	var mouse: bool = selection.get("mouse", false)
	var reason: String = ""
	var allowed := true
	if mouse:
		cast = selection
		allowed = false
		reason = selection.get("reason", "将光标移到矿块上")
		if cast.get("hit", false):
			var selected: Vector3i = cast.pos
			var point: Vector3 = Vector3(selected) * world.block_size()
			var delta: Vector3 = point - origin
			var normal: Vector3i = cast.get("normal", Vector3i.ZERO)
			if normal.x != 0 or normal.z != 0:
				forward = -normal
			else:
				forward = Vector3i(1 if delta.x > 0 else -1, 0, 0) if absf(delta.x) >= absf(delta.z) else Vector3i(0, 0, 1 if delta.z > 0 else -1)
			side = Vector3i(0, 0, 1) if forward.x != 0 else Vector3i(1, 0, 0)
			origin.y = point.y
			var hand: Vector3 = world.to_local(player.global_position + Vector3.UP)
			var half: Vector3 = world.block_size() * 0.5
			var closest: Vector3 = hand.clamp(point - half, point + half)
			if not world.is_breakable(selected):
				reason = "结构不能开采"
			elif hand.distance_to(closest) > definition.reach:
				reason = "距离太远，请靠近"
			elif not world.visible_mining_face(origin, selected):
				reason = "被前方矿块遮挡"
			else:
				allowed = true
				reason = "按住鼠标左键开采" if definition.mining_rate > 0.0 else "普通枪械不能开采矿石"
	var cells: Array[Vector3i] = []
	var footprint: Array[Vector3i] = []
	var shape: String = "单格"
	var golden: bool = not definition.ranged and golden_seconds > 0.0 and tool_index <= 1
	var wide: bool = not definition.ranged and range_seconds > 0.0 and tool_index <= 1
	var longblade: bool = tool_index == 2 and longblade_seconds > 0.0
	if golden:
		shape = "黄金 3×3×3"
	elif wide:
		shape = "竖向 3 格" if vertical else "横向 3 格"
	elif longblade:
		shape = "长刀 2 格"
	if allowed and cast.get("hit", false) and world.is_breakable(cast.pos):
		var aim: Vector3i = cast.pos
		if golden:
			for depth in 3:
				for offset in range(-1, 2):
					for row in range(-1, 2):
						var cell: Vector3i = aim + forward * depth + side * offset + Vector3i.UP * row
						# Never drill through a structural cell in an inner layer.
						var blocked := false
						for previous in depth:
							var before: Vector3i = aim + forward * previous + side * offset + Vector3i.UP * row
							if world.has_block(before) and not world.is_breakable(before):
								blocked = true
						if not blocked and world.is_breakable(cell):
							cells.append(cell)
						if not blocked:
							footprint.append(cell)
		elif wide:
			for offset in range(-1, 2):
				var cell: Vector3i = aim + (Vector3i.UP if vertical else side) * offset
				if world.is_breakable(cell) and world.visible_mining_face(origin, cell):
					cells.append(cell)
				footprint.append(cell)
		else:
			cells.append(aim)
			footprint.append(aim)
			if longblade:
				var next_cell: Vector3i = aim + forward
				footprint.append(next_cell)
				if world.is_breakable(next_cell):
					cells.append(next_cell)
	return {"tool": definition, "cells": cells, "footprint": footprint, "origin": origin,
		"facing": Vector3(forward), "side": side, "shape": shape,
		"aim_height": int(cast.pos.y) if mouse and cast.get("hit", false) else aim_height,
		"mouse": mouse, "allowed": allowed, "reason": reason,
		"golden": golden, "wide": wide, "longblade": longblade,
		"hit": cast.get("hit", false), "aim": cast.get("pos", Vector3i.ZERO)}


func begin_operation(snapshot: Dictionary, effective: bool) -> bool:
	if cooldown > 0.00001:
		return false
	cooldown = snapshot.tool.interval
	# Empty swings cost time, but do not consume the one-shot talent.
	if effective and snapshot.get("golden", false):
		golden_seconds = 0.0
	return true
