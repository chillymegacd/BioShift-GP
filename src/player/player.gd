extends CharacterBody3D

enum {
	GROUND,
	JUMP,
	FALL
}

@onready var tp_camera := $Camera3D
@onready var camera = tp_camera
@onready var raycast := $Model/RayCast3D

@export var max_speeds := [0.0, 50.0, 100.0, 150.0, 200.0]
@export var accel := 0.5
@export var brake_speed := 0.7
@export var air_drag := 0.2
@export var turn_speeds := [0.0, 2.0, 1.5, 1.25, 1.0]
@export var jump_speed := 15.0
@export var final_check := 0

var final_turn_axis := 0.0
var state := GROUND
var gear := 1
var speed := 0.0
var final_speed := 0.0
var rpm := 0.0
var max_rpms := [max_speeds[1]]
var thrust_str := 0.0
var turn_anim_pos := 0.5
var current_check := 0
var next_check := 1
var on_final_check := false
var timer_started := false
var current_time := 0.0
var best_time := 99.99
var last_lap := 0.0

func align_with_y(xform, new_y):
	xform.basis.y = new_y
	xform.basis.x = -xform.basis.z.cross(new_y)
	xform.basis = xform.basis.orthonormalized()
	return xform

func model_control(xform, delta: float, final_turn_axis: float, accel_str: float) -> void:
	if !is_on_floor():
		$Model.rotation.x = lerp(rotation.x, velocity.y / 5.0, 15 * delta)
		$Model.rotation.x = clamp($Model.rotation.x, deg_to_rad(-45), deg_to_rad(45))
	$Model.global_transform = $Model.global_transform.interpolate_with(xform, 12 * delta)
	$Model.rotation.y = final_turn_axis * deg_to_rad(360)
	turn_anim_pos = final_turn_axis * -30 + $Model/AnimationPlayer.current_animation_length / 2
	if $Model/AnimationPlayer.current_animation == "Turn": $Model/AnimationPlayer.seek(turn_anim_pos)
	#$Model/Armature/Skeleton3D/Eye_r.get_surface_override_material(0).uv1_offset.x = -speed / max_speeds[5]
	#$Model/Armature/Skeleton3D/Eye_l.get_surface_override_material(0).uv1_offset.x = -speed / max_speeds[5]
	#for i in range(0, 2):
	thrust_str = lerp(thrust_str, accel_str, 15 * delta)
	thrust_str = clamp(thrust_str, 0.0, 1.0)
	for i in 2:
		get_node("Model/Armature/Skeleton3D/BoneAttachment3D/thrust" + str(i)).rotation.z += thrust_str
		if get_node("Model/Armature/Skeleton3D/BoneAttachment3D/thrust" + str(i)).rotation.z > deg_to_rad(360):
			get_node("Model/Armature/Skeleton3D/BoneAttachment3D/thrust" + str(i)).rotation.z = 0.0
		get_node("Model/Armature/Skeleton3D/BoneAttachment3D/thrust" + str(i)).scale = Vector3(1,1,1) * ((thrust_str) * 1.5) * (rpm * (gear / 4.0))
		get_node("Model/Armature/Skeleton3D/BoneAttachment3D/thrustlight" + str(i)).light_energy = thrust_str * 0.5 * (rpm * (gear / 4.0))

func sound_control() -> void:
	#$AudioStreamPlayer.volume_db = -80.0 + (thrust_str * 80.0)
	$AudioStreamPlayer.pitch_scale = ((rpm) * (gear / 4.0)) + 0.01 if thrust_str > 0.01 else 0.01

func camera_control(final_turn_axis: float, delta: float) -> void:
	camera.rotation.x = lerp(camera.rotation.x, velocity.y * .025, 15 * delta)
	camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-45), deg_to_rad(45))
	camera.rotation.z = lerp(camera.rotation.z, final_turn_axis * 2, 15 * delta)
	camera.rotation.y = lerp(camera.rotation.y, final_turn_axis, 15 * delta)
	camera.position.y = lerp(camera.position.y, 1.5 + velocity.y * .1, 15 * delta)
	camera.position.y = clamp(camera.position.y, 0, 5)
	camera.position.z = 4 + ((final_speed / max_speeds[-1]) * 2.0)

func ui_control() -> void:
	$CanvasLayer/Time.text = "TIME: " + str(snapped(current_time, 0.01)) + "\nBEST TIME: " + str(best_time) + "\nFPS: " + str(Engine.get_frames_per_second())
	$CanvasLayer/Speed.text = "SPEED: %03d" % (roundi(final_speed)) + "\nGEAR: " + str(gear)
	$CanvasLayer/TextureProgressBar.value = int(rpm * 75)

func checkpoint(chk: int, final: bool) -> void:
	if on_final_check:
		print("lap")
		on_final_check = false
		if snapped(current_time, 0.01) < best_time:
			best_time = snapped(current_time, 0.01)
		current_time = 0
		current_check = 1
		next_check = 2
	elif chk == next_check:
		if !timer_started:
			timer_started = true
		current_check = chk
		if next_check != final_check:
			next_check += 1
			print("next_checkpoint")
		else:
			on_final_check = true
			print("final_checkpoint")

func _ready() -> void:
	$Model/AnimationPlayer.play("Turn")
	$Model/AnimationPlayer.seek(turn_anim_pos)
	max_rpms.append(max_rpms[0] + max_speeds[2])
	max_rpms.append(max_rpms[1] + max_speeds[3])
	max_rpms.append(max_rpms[2] + max_speeds[4])

func _physics_process(delta: float) -> void:
	var turn_axis := Input.get_axis("right_turn", "left_turn")
	final_turn_axis = move_toward(final_turn_axis, turn_axis * (turn_speeds[gear] * delta), 0.25 * delta)
	var accel_str := -Input.get_action_strength("accel") + Input.get_action_strength("brake")
	rotate_y(final_turn_axis)
	var n = Vector3.UP
	if is_on_floor():
		if raycast.is_colliding():
			n = raycast.get_collision_normal()
		if Input.is_action_just_pressed("jump"):
			$Model/AnimationPlayer.play("Backflip")
			velocity.x += -n.x * jump_speed * 100
			velocity.y += n.y * jump_speed
			velocity.z += -n.z * jump_speed * 100
			state = JUMP
		if state == FALL:
			$Model/AnimationPlayer.play("Turn")
			$Model/AnimationPlayer.seek(turn_anim_pos)
	else:
		velocity.y -= 16 * delta
		if velocity.y <= 0:
			state = FALL 
	var xform = align_with_y(global_transform, n)
	if -speed >= max_speeds[gear - 1] * .85 and speed <= max_speeds[gear]:
		speed = move_toward(speed, (max_speeds[gear] * accel_str), accel * 60 * delta)
	else:
		speed = move_toward(speed, 0.0, brake_speed * 30 * delta)
	if Input.is_action_pressed("brake"):
		speed += (brake_speed * 30 * delta) + accel_str
	speed = clamp(speed, -max_speeds[-1], 0.0)
	var move_dir = transform.basis * Vector3(final_turn_axis * speed, 0, speed)
	velocity.x = move_dir.x + (n.x * 2.5)
	velocity.z = move_dir.z + (n.z * 2.5)
	final_speed = -global_transform.basis.z.dot(velocity)
	rpm = snapped(final_speed / max_speeds[gear], 0.01)
	rpm = clamp(rpm, 0.0, 1.0)
	if Input.is_action_just_pressed("up_shift") and gear < turn_speeds.size() - 1:
		gear += 1
	elif Input.is_action_just_pressed("down_shift") and gear > 1:
		gear -= 1
	if is_on_wall():
		var speed_reduction = rad_to_deg(abs(atan2(get_wall_normal().x, get_wall_normal().z) - rotation.y)) / 90.0
		speed *= speed_reduction * 0.5
		velocity.x += (get_wall_normal().x * -speed * 10)
		velocity.z += (get_wall_normal().z * -speed * 10)
	elif is_on_ceiling():
		velocity.y += -n.y * jump_speed / 4
		var speed_reduction = rad_to_deg(abs(atan2(get_wall_normal().x, get_wall_normal().z) - rotation.y)) / 90.0
		speed *= speed_reduction * 0.5
		velocity.x += (get_wall_normal().x * -speed * 10)
		velocity.z += (get_wall_normal().z * -speed * 10)
	move_and_slide()
	camera_control(final_turn_axis, delta)
	model_control(xform, delta, final_turn_axis, -accel_str)
	sound_control()
	ui_control()
	if timer_started:
		current_time += delta


func _on_checkpoint_area_entered(area: Area3D) -> void:
	pass # Replace with function body.
