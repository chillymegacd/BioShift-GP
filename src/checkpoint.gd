extends Area3D

@export var checkpoint_no := 0
@export var final_check := false

func _on_area_entered(area: Area3D) -> void:
	area.owner.checkpoint(checkpoint_no, final_check)
