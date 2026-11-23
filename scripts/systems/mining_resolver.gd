class_name MiningResolver
extends RefCounted
## P04: consumes the exact P03 snapshot and delegates grid ownership to L01.

func resolve(world: Node3D, snapshot: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var definition: Resource = snapshot.tool
	if definition.mining_rate <= 0.0:
		return result
	var visited: Dictionary = {}
	for cell in snapshot.cells:
		if visited.has(cell):
			continue
		visited[cell] = true
		var hit: Dictionary = world.apply_mining_work(cell, definition.work_per_swing())
		if hit.get("accepted", false):
			result.append(hit)
	return result
