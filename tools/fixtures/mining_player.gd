extends Node3D
var action_prefix := "p1"
var is_down := false
var hp := 3
var facing := Vector3.FORWARD


func facing_dir() -> Vector3:
	return facing
