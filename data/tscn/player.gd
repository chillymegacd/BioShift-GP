extends "res://src/character.gd"

func _physics_process(delta: float) -> void:
	forward_influence = Input.get_action_strength("accel1")
	speed -= move_speed * Input.get_action_strength("brake1") * delta * .25
	turn_influence = Input.get_axis("turn_r1", "turn_l1") * ( 1 - ((speed / move_speed) * 0.8))
	update_character(delta)
	$Camera3D.fov = 75 + ((speed / move_speed) * 10)
	$CanvasLayer/Speedometer.rotation = deg_to_rad(((abs(speed) / move_speed) * 90) - 90)
	$CanvasLayer/Label.text = str(Engine.get_frames_per_second())
