extends Node

# Autoload called PlayerReconnector

func try_player_reconnect(id: int, info: Dictionary)->void:
	var player_reconnected := false
	# Make sure the player isn't already connected!
	for player in Lobby.players:
		var connected_player_info :Dictionary= Lobby.players.get(player)
		if connected_player_info["name"] == info["name"]:
			# Disconnect peer if a player with the same name already exists.
			# Could potentially cause issues if two players joined a lobby with
			# the same name and one has to reconnect during the game.
			multiplayer.multiplayer_peer.disconnect_peer(id)
			return

	# Validate the player was disconnected and try reconnecting them
	for player in Lobby.disconnected_players:
		if Lobby.disconnected_players.get(player) == null:
			break
		var disconnected_player_info :Dictionary= Lobby.disconnected_players.get(player)
		if disconnected_player_info["name"] == info["name"]:
			info["board_position"] = disconnected_player_info["board_position"]
			_reconnect_clients(player, id, info)
			Lobby.players[id] = info
			$/root/Game.update_turn_order_ids(player, id)
			Lobby.disconnected_players.erase(player)
			player_reconnected = true
			print("%s successfully reconnected" % info["name"])
			break

	# If reconnect attempt fails, disconnect the peer
	if !player_reconnected:
		multiplayer.multiplayer_peer.disconnect_peer(id)


# Server sends data to reconnecting clients with necessary data to correct their
# game board
@rpc("authority", "call_remote", "reliable")
func process_reconnection(_player_data: Dictionary, _player_turn_id: int, _round_num: int)->void:
	pass


func _reconnect_clients(old_id: int, new_id: int, info: Dictionary)->void:
	for player in Lobby.players:
		# Notify existing players that the player has reconnected
		_reconnect_player.rpc_id(player, old_id, new_id, info)

		# Re-register existing players with the reconnected one.
		var existing_player_info = Lobby.players.get(player)
		Lobby.register_player.rpc_id(new_id, player, existing_player_info)
	_reconnect_player(old_id, new_id, info)


# Method that handles player reconnection, also called from the server on clients
@rpc("authority", "call_remote", "reliable")
func _reconnect_player(old_id: int, new_id: int, _info: Dictionary)->void:
	# We have to loop through all players because 
	# $/root/Game.find_child("Players").find_child(str(old_id))
	# returns null
	for child in $/root/Game.find_child("Players").get_children():
		if child.name == str(old_id):
			child.name = str(new_id) # Update the old name with the new id
			Lobby.load_game.rpc_id(new_id, "res://game/game.tscn")
			break
