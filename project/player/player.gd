extends CharacterBody2D

signal rolled_for_movement


func _enter_tree():
	%MultiplayerSynchronizer.set_multiplayer_authority(name.to_int())


func set_player_camera()->void:
	%Camera2D.make_current()
	print("Camera set")


func show_controls()->void:
	%Controls.show()
	%RollForMovementButton.show()
	%EndTurnButton.hide()


func on_finished_moving()->void:
	print("finished moving")
	%EndTurnButton.show()


func _on_roll_for_movement_button_pressed():
	print("Running")
	%RollForMovementButton.hide()
	$/root/Game.action_started.rpc_id(1, "ROLL")


func _on_end_turn_button_pressed():
	%Controls.hide()
	$/root/Game.turn_finished.rpc_id(1)
