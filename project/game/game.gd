extends Node2D

const TOTAL_BOARD_POSITIONS := 10

var current_player_node :Node
var round_number := 1


func _ready():
	Lobby.player_loaded.rpc_id(1)


# Called on clients when a player is reconnecting. Ensures the old player id is
# replaced with the new and that the player can control their body again.
func restore_player_functionality(old_id: int, new_id: int)->void:
	for child in %Players.get_children():
		if child.name == str(old_id):
			child.set_name(str(new_id))
			break


# Called by the server to signal clients to spawn player bodies.
@rpc("authority", "call_local", "reliable")
func _spawn_players(players_dictionary: Dictionary)->void:
	for id in players_dictionary:
		var player_body := _create_player(id)
		player_body.position = %BoardPositions/Pos1.position
		%Players.add_child(player_body)


func _create_player(player_id: int)->CharacterBody2D:
	var player_body := preload("res://player/player.tscn").instantiate()
	player_body.name = str(player_id)
	return player_body


# Reconnecting client receives positional data from the server and reconstructs
# the other players' nodes and updates the active player body if it's their turn.
@rpc("authority", "call_remote", "reliable")
func _send_reconnect_data(player_data: Dictionary, player_turn_id: int)->void:
	for id in player_data:
		var player_body = _create_player(id)
		%Players.add_child(player_body)
		var board_position_index = player_data.get(id)["board_position"]
		player_body.position = %BoardPositions.get_child(board_position_index).position

		if id == multiplayer.get_unique_id():
			Lobby.player_info["board_position"] = board_position_index
		if id == player_turn_id:
			current_player_node = player_body


# The server starts the next player's turn and notifies all clients whose turn it is
@rpc("authority", "call_remote", "reliable")
func _start_player_turn(player_id: int, actions_taken: Array)->void:
	_set_player_camera(player_id) # Show the player's camera to all clients
	if multiplayer.get_unique_id() == player_id:
		current_player_node.call("show_controls", actions_taken)
	else:
		print("%s's turn started." % Lobby.players.get(player_id)["name"])


func _set_player_camera(player_id: int)->void:
	# Doing %Players.find_child(str(player_id)) returns null so we loop through 
	# all the players until we find one with a matching name
	for child in %Players.get_children():
		if child.name == str(player_id):
			current_player_node = child # Set the current player node for future reference
			child.call("set_player_camera")
			break


# This notifies the server to start the next player's turn when the current turn finishes. 
# It is currently called in player.gd when the end turn button is pressed.
@rpc("any_peer", "call_remote", "reliable")
func turn_finished()->void:
	pass


# Client should call this when they want to start an action. This tells the server
# which action to process and which data to send for that action. If a player requests
# an action, the server will only process the action if it is that player's turn
@rpc("any_peer", "call_remote", "reliable")
func action_started(_action_name: String)->void:
	pass


# Server processes actions requested by players and tells all clients what action
# was requested, which player requested it, and any data necessary to complete the
# action.
@rpc("authority", "call_remote", "reliable")
func _action_processed(action_name: String, action_result: Variant, player_id: int)->void:
	match action_name:
		"ROLL":
			var roll :int= action_result
			if multiplayer.get_unique_id() == player_id: # If this client is the player, do the action
				await _move_player_to_next_board_position(player_id, roll)
				current_player_node.call("on_finished_moving")
			else:
				await _move_player_to_next_board_position(player_id, roll)


func _move_player_to_next_board_position(player_id: int, roll: int)->void:
	for i in range(roll):
		var next_position := _calc_next_board_position(player_id)
		var tween := current_player_node.create_tween()
		# Gradually move to the next position with a property tweener over 2.5 seconds.
		tween.tween_property(current_player_node, "position",
								next_position, 1.0)
		# Wait for a timer signal to ensure processing is stopped until the next 
		# position is reached. If await is removed here or in the 'ROLL' action, 
		# the players will skip to the final position w/o visiting the other ones.
		await get_tree().create_timer(1.0).timeout


func _calc_next_board_position(player_id: int)->Vector2:
	var board_position_index: int
	var next_position_index: int
	if player_id == multiplayer.get_unique_id():
		board_position_index = Lobby.player_info["board_position"]
		next_position_index = (board_position_index + 1) % TOTAL_BOARD_POSITIONS
		Lobby.player_info["board_position"] = next_position_index
	else:
		board_position_index = Lobby.players.get(player_id)["board_position"]
		next_position_index = (board_position_index + 1) % TOTAL_BOARD_POSITIONS
		Lobby.players.get(player_id)["board_position"] = next_position_index
	return %BoardPositions.get_child(next_position_index).position


# The server determines when the round finishes and rpc's the clients
@rpc("authority", "call_local", "reliable")
func _round_finished()->void:
	round_number += 1


# The server determines when the game finishes and rpc's the clients. Currently
# the server calls Lobby.load_lobby.rpc on all clients in its _game_finished rpc
# so this will be bypassed on clients and the lobby will load instead. This could
# be changed if custom logic is desired when the game ends besides just loading the
# lobby
@rpc("authority", "call_local", "reliable")
func _game_finished()->void:
	pass
