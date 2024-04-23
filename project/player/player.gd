extends CharacterBody2D

signal rolled_for_movement


func _enter_tree():
	# Set multiplayer authority of synchronizer node so values can be synced between
	# peers
	%MultiplayerSynchronizer.set_multiplayer_authority(name.to_int())


func set_player_camera()->void:
	%Camera2D.make_current()


func show_controls()->void:
	%Controls.show()
	%RollForMovementButton.show()
	%EndTurnButton.hide()


func on_finished_moving()->void:
	%EndTurnButton.show()


func _on_roll_for_movement_button_pressed():
	%RollForMovementButton.hide()
	# Request server to start 'ROLL' action
	$/root/Game.action_started.rpc_id(1, "ROLL")


func _on_end_turn_button_pressed():
	%Controls.hide()
	# Notify server turn is finished
	$/root/Game.turn_finished.rpc_id(1)
