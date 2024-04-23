extends CharacterBody2D

signal rolled_for_movement


func _enter_tree():
	%MultiplayerSynchronizer.set_multiplayer_authority(name.to_int())


func set_player_camera()->void:
	%Camera2D.make_current()
	print("Camera set")
