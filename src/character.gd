extends RigidBody3D

@export var move_speed := 100.0
@export var accel_speed := 15.0
@export var turn_speed := 3.0
@export var jump_speed := 25.0

@onready var floor_raycast := $RayCast3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity") * 2
var forward_influence : float
var turn_influence : float
var speed : float
var velocity : Vector3

func update_character(delta: float) -> void:
	rotation.y += turn_influence * turn_speed * delta
	var forward_direction: Vector3 = -transform.basis.z
	forward_direction.y = 0.0
	forward_direction = forward_direction.normalized()
	velocity = linear_velocity
	speed = move_toward(speed, forward_influence * move_speed, accel_speed * delta)
	speed = clamp(speed, 0.0, move_speed)
	velocity.x = forward_direction.x * speed
	velocity.z = forward_direction.z * speed
	velocity.y -= gravity * delta
	if floor_raycast and floor_raycast.is_colliding():
		if Input.is_action_just_pressed("jump1"):
			velocity.y += jump_speed
	linear_velocity = velocity
