class_name OreInventory
extends Node
## Atomic, stackable inventory. One failed request never partially adds an item.
signal changed
const Catalog = preload("res://scripts/items/mineral_catalog.gd")
@export_range(1, 32) var slot_limit: int = 8
@export_range(1, 999) var stack_limit: int = 99
var _slots: Array[Dictionary] = []


func _ready() -> void:
	_ensure_slots()


func _ensure_slots() -> void:
	while _slots.size() < slot_limit:
		_slots.append({"key": "", "count": 0})


func can_add(key: String, amount: int) -> bool:
	if not Catalog.is_rare(key) or amount <= 0:
		return false
	_ensure_slots()
	var space := 0
	for i in mini(slot_limit, _slots.size()):
		var slot := _slots[i]
		if slot.key == key or slot.count == 0:
			space += maxi(0, stack_limit - int(slot.count))
	return space >= amount


func try_add(key: String, amount: int) -> bool:
	if not can_add(key, amount):
		return false
	var remaining := amount
	# Fill matching stacks before using an empty slot.
	for empty_pass in [false, true]:
		for i in mini(slot_limit, _slots.size()):
			var slot := _slots[i]
			if (not empty_pass and slot.key != key) or (empty_pass and slot.count != 0):
				continue
			var added := mini(remaining, stack_limit - int(slot.count))
			if added <= 0:
				continue
			slot.key = key
			slot.count += added
			remaining -= added
			if remaining == 0:
				changed.emit()
				return true
	return false


func counts() -> Dictionary:
	var result: Dictionary = {}
	for slot in _slots:
		if slot.count > 0:
			result[slot.key] = int(result.get(slot.key, 0)) + int(slot.count)
	return result


func slots() -> Array[Dictionary]:
	_ensure_slots()
	return _slots.duplicate(true)


func used_slots() -> int:
	var used := 0
	for slot in _slots:
		if slot.count > 0:
			used += 1
	return used
