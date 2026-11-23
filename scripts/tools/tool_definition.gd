class_name MineToolDefinition
extends Resource
## Shared immutable tool data. Cooldown and talents belong to each operator.

@export var id: StringName
@export var display_name: String
@export_range(0.05, 5.0) var interval: float = 0.6
@export_range(0.0, 20.0) var mining_rate: float = 1.0
@export_range(0, 100) var damage: int = 1
@export_range(0.1, 20.0) var reach: float = 3.0
@export var ranged: bool = false
@export var tint: Color = Color(1.0, 0.78, 0.22)


func work_per_swing() -> float:
	return mining_rate * interval
