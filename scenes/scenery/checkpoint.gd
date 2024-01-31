extends Node3D

signal passed(node, id)

func _on_area_3d_body_entered(body):
	if body.is_in_group("Opponents"):
		emit_signal("passed", self, body.player_id)
