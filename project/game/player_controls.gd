extends Control


func show_controls(actions_taken: Array)->void:
	show()
	if actions_taken.has("ROLL"):
		%RollForMovementButton.hide()
		%EndTurnButton.show()
	else:
		%RollForMovementButton.show()
		%EndTurnButton.hide()


func on_finished_moving()->void:
	%EndTurnButton.show()


func _on_roll_for_movement_button_pressed():
	%RollForMovementButton.hide()
	# Request server to start 'ROLL' action
	$/root/Game.action_started.rpc_id(1, "ROLL")


func _on_end_turn_button_pressed():
	hide()
	# Notify server turn is finished
	$/root/Game.turn_finished.rpc_id(1)
