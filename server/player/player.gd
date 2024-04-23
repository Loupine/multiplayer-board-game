extends CharacterBody2D

signal rolled_for_movement


func _enter_tree():
	# Set multiplayer authority of synchronizer node so values can be synced between
	# peers
	%MultiplayerSynchronizer.set_multiplayer_authority(name.to_int())


func set_player_camera()->void:
	%Camera2D.make_current()
