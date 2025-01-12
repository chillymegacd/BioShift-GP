extends CharacterBody3D

@onready var tp_camera := $Camera3D
@onready var fp_camera := $Model/Camera3D
@onready var camera = tp_camera

@export var max_speeds := [0.0, 10.0, 25.0, 35.0, 50.0]
@export var accel := 0.25
@export var brake_speed := 0.25
@export var air_drag := 0.1
@export var turn_speeds := [0.0, 2.5, 1.5, 1.0, 0.5]
@export var jump_speed := 7.5

var gear := 1
var speed := 0.0
var final_speed := 0.0
var rpm := 0.0
var max_rpms := [max_speeds[1]]
var bounce := 0.0
var bounce_reduction := 0.0
var will_add_bounce := true
var timer_started := false
var current_time := 0.0
var best_time := 99.99
var last_lap := 0.0

func align_with_y(xform, new_y):
	xform.basis.y = new_y
	xform.basis.x = -xform.basis.z.cross(new_y)
	xform.basis = xform.basis.orthonormalized()
	return xform

func model_control(xform, delta: float) -> void:
	if !is_on_floor():
		$Model.rotation.x = lerp(rotation.x, velocity.y / 5.0, 15 * delta)
		$Model.rotation.x = clamp($Model.rotation.x, deg_to_rad(-45), deg_to_rad(45))
	$Model.global_transform = $Model.global_transform.interpolate_with(xform, 12 * delta)

func camera_control(final_turn_axis: float, delta: float) -> void:
	camera.rotation.x = lerp(camera.rotation.x, velocity.y * .025, 15 * delta)
	camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-45), deg_to_rad(45))
	camera.rotation.z = lerp(camera.rotation.z, final_turn_axis, 15 * delta)
	camera.rotation.y = lerp(camera.rotation.y, final_turn_axis, 15 * delta)
	camera.position.y = lerp(camera.position.y, 1.5 + velocity.y * .1, 15 * delta)
	camera.position.y = clamp(camera.position.y, 0, 5)

func ui_control() -> void:
	$CanvasLayer/ColorRect.position.y = 224 - int(speed * -1)
	$CanvasLayer/RPM.position.y = 224 - (rpm * 50)
	$CanvasLayer/RPM.size.y = rpm * 50
	$CanvasLayer/ColorRect.size.y = int(speed * -1)
	$CanvasLayer/Label.text = "TIME: " + str(snapped(current_time, 0.01)) + "\nRECORD: " + str(snapped(best_time, 0.01)) + "\nLAST: " + str(last_lap)
	$CanvasLayer/Gear.text = str(roundi(final_speed))

func checkpoint() -> void:
	if !timer_started:
		timer_started = true
	else:
		last_lap = snapped(current_time - best_time, 0.01)
		if snapped(current_time, 0.01) < snapped(best_time, 0.01): best_time = current_time
		current_time = 0.0

func _ready() -> void:
	max_rpms.append(max_rpms[0] + max_speeds[2])
	max_rpms.append(max_rpms[1] + max_speeds[3])
	max_rpms.append(max_rpms[2] + max_speeds[4])

func _physics_process(delta: float) -> void:
	var turn_axis := Input.get_axis("right_turn", "left_turn")
	var final_turn_axis = turn_axis * (turn_speeds[gear] * delta)
	var shift_axis := Input.get_axis("shift_down", "shift_up")
	var accel_str := -Input.get_action_strength("accel") + Input.get_action_strength("brake")
	rotate_y(final_turn_axis)
	var n = Vector3.UP
	if is_on_floor():
		if $RayCast3D.is_colliding(): n = $RayCast3D.get_collision_normal()
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_speed
		#if bounce > 0.0:
			#will_add_bounce = false
			#if bounce_reduction == 0.0:
				#bounce_reduction = bounce / 3.0
			#velocity += bounce * n
			#bounce -= bounce_reduction
		#else:
			#bounce_reduction = 0.0
			#will_add_bounce = true
	else:
		velocity.y -= 9.8 * delta
		#if will_add_bounce:
			#bounce += delta * 2
	var xform = align_with_y(global_transform, n)
	speed = move_toward(speed, (max_speeds[gear] * accel_str), accel * 60 * delta)
	if Input.is_action_pressed("brake"):
		speed += (brake_speed * 30 * delta) + accel_str
	speed = clamp(speed, -max_speeds[-1], 0.0)
	var shift_reduction = (abs(shift_axis) * 5) if final_speed > 5 else 0
	var move_dir = transform.basis * Vector3(shift_axis * 20, 0, speed + shift_reduction)
	velocity.x = move_dir.x + (n.x * 2.5)
	velocity.z = move_dir.z + (n.z * 2.5)
	final_speed = -global_transform.basis.z.dot(velocity)
	rpm = snapped(final_speed / max_speeds[gear], 0.01)
	rpm = clamp(rpm, 0.0, 1.0)
	if accel_str < 0:
		if rpm >= 1 and gear < turn_speeds.size() - 1:
			gear += 1
	elif rpm < 1 and gear > 1:
		gear -= 1
	if is_on_wall():
		velocity = (get_wall_normal() * -speed * 10)
		speed = 0
	move_and_slide()
	camera_control(final_turn_axis, delta)
	model_control(xform, delta)
	ui_control()
	if timer_started:
		current_time += delta
