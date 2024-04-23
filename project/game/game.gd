extends Node2D

signal player_finished_moving

const TOTAL_BOARD_POSITIONS := 10

var turn_order :Array
var current_player_node :Node


func _ready():
	Lobby.player_loaded.rpc_id(1)
	%PlayerSpawner.add_spawnable_scene("res://player/player.tscn")


# The client receives the randomized turn order from the server on setup
@rpc("authority", "call_remote", "reliable")
func _send_turn_order(order: Array)->void:
	turn_order = order


# The server starts the next player's turn and notifies all clients whose turn it is
@rpc("authority", "call_remote", "reliable")
func _start_player_turn(player_id)->void:
	_set_player_camera(player_id) # Show the player's camera to all clients
	if multiplayer.get_unique_id() == player_id: 
		_start_turn()
	else:
		print("%s's turn started." % Lobby.players.get(player_id)["name"])


func _set_player_camera(player_id)->void:
	# Doing %Players.find_child(str(player_id)) returns null so we loop through 
	# all the players until we find one with a matching name
	for child in %Players.get_children():
		if child.name == str(player_id):
			current_player_node = child # Set the current player node for future reference
			child.call("set_player_camera")
			break


# Only called on the player whose turn it is
func _start_turn():
	print("Turn started")
	_show_player_controls()


func _show_player_controls()->void:
	current_player_node.call("show_controls")


# This notifies the server to start the next player's turn when the current turn finishes. 
# It is currently called in player.gd when the end turn button is pressed.
@rpc("any_peer", "call_remote", "reliable")
func turn_finished()->void:
	pass


# Client should call this when they want to start an action. This tells the server
# which action to process and which data to send for that action. If a player requests
# an action, the server will only process the action if it is that player's turn
@rpc("any_peer", "call_remote", "reliable")
func action_started(_action_name)->void:
	pass


# Server processes actions requested by players and tells all clients what action
# was requested, which player requested it, and any data necessary to complete the
# action.
@rpc("authority", "call_remote", "reliable")
func _action_processed(action_name, action_result: Variant, player_id)->void:
	match action_name:
		"ROLL":
			var roll : int = action_result
			if multiplayer.get_unique_id() == player_id: # If this client is the player, do the action
				for i in range(roll):
					# Wait for each loop iteration to finish so the player visits every board position
					# if await is removed, the player will travel to the final position immediately
					await _move_player_to_next_board_position(player_id)
				current_player_node.call("on_finished_moving")
			else:
				var current_position = Lobby.players.get(player_id)["board_position"]
				Lobby.players.get(player_id)["board_position"] = (
										(current_position + roll)  % TOTAL_BOARD_POSITIONS)


func _move_player_to_next_board_position(player_id)->void:
	if multiplayer.get_unique_id() == player_id:
		var next_position := _calc_next_board_position()
		var tween = current_player_node.create_tween()
		# Gradually move to the next position with a property tweener over 2.5 seconds.
		tween.tween_property(current_player_node, "position", 
								next_position, 2.5)
		# Wait for a timer signal to ensure processing is stopped until the next position is reached
		# If await is removed here or in the previous method, the players will not go to
		# each position and will instead go directly to the final one.
		await get_tree().create_timer(2.5).timeout


func _calc_next_board_position()->Vector2:
	var board_position_index = Lobby.player_info["board_position"]
	var next_position_index = (board_position_index + 1) % TOTAL_BOARD_POSITIONS
	Lobby.player_info["board_position"] = next_position_index
	return %BoardPositions.get_child(next_position_index).position


# The server determines when the round finishes and rpc's the clients
@rpc("authority", "call_local", "reliable")
func _round_finished()->void:
	pass


# The server determines when the game finishes and rpc's the clients
@rpc("authority", "call_local", "reliable")
func _game_finished()->void:
	pass


func _on_player_spawner_spawned(node):
	var spawned_player = node
	spawned_player.position = %BoardPositions.get_child(0).position
