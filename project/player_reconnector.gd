extends Node

# Autoload called PlayerReconnector

@rpc("authority", "call_remote", "reliable")
func _reconnect_player(old_id: int, new_id: int, info: Dictionary)->void:
	$/root/Game.replace_old_player_id(old_id, new_id)
	Lobby.players.erase(old_id)
	Lobby.players[new_id] = info


# Reconnecting client receives positional data from the server, reconstructs
# the other players' nodes, and updates the active player body.
@rpc("authority", "call_remote", "reliable")
func process_player_reconnection(player_data: Dictionary, player_turn_id: int, round_num: int)->void:
	$/root/Game.update_round_text(round_num)
	for id in player_data:
		# Spawn the player body
		var player_body = $/root/Game.create_player(id)
		# Update the player body's position based on the player data
		var board_position_index = player_data.get(id)["board_position"]
		player_body.position = $/root/Game/BoardPositions.get_child(board_position_index).position

		if id == multiplayer.get_unique_id():
			Lobby.player_info["board_position"] = board_position_index # Update client's player data
		if id == player_turn_id:
			# Update the active player node
			$/root/Game.current_player_node = player_body
			$/root/Game.actions.update_current_player_node(player_body)
			$/root/Game.update_turn_text(id, round_num)
