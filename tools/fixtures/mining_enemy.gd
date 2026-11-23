extends Node3D
var hp := 10


func take_hit(amount: int) -> void:
	hp -= amount
