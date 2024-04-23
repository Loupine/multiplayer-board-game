extends Node2D

signal player_finished_moving

const TOTAL_BOARD_POSITIONS := 10

var turn_order :Array
var current_player_node :Node


func _ready():
	Lobby.player_loaded.rpc_id(1)
	%PlayerSpawner.add_spawnable_scene("res://player/player.tscn")


# The server sends the generated turn order to clients
@rpc("authority", "call_remote", "reliable")
func _send_turn_order(order: Array)->void:
	turn_order = order


# The server starts the next player's turn
@rpc("authority", "call_remote", "reliable")
func _start_player_turn(player_id)->void:
	_set_player_camera(player_id)
	if multiplayer.get_unique_id() == player_id:
		_start_turn()
	else:
		print("%s's turn started." % Lobby.players.get(player_id)["name"])


func _set_player_camera(player_id)->void:
	# Doing %Players.find_child(str(player_id)) erroneously returns null so we 
	# unfortunately have to loop through all the players
	for child in %Players.get_children():
		if child.name == str(player_id):
			current_player_node = child
			child.call("set_player_camera")
			break


func _start_turn():
	print("Turn started")
	_show_player_controls()


func _show_player_controls()->void:
	current_player_node.call("show_controls")


# Client should call this once their turn is over and all turn actions are finished or skipped
@rpc("any_peer", "call_remote", "reliable")
func turn_finished()->void:
	pass


# Client should call this when certain actions finish during their turn
@rpc("any_peer", "call_remote", "reliable")
func action_started(_action_name, _player_id)->void:
	pass


# Server calls this when an action is started by the client and should send the 
# action result to all clients
@rpc("authority", "call_remote", "reliable")
func _action_processed(action_name, action_result: Variant, player_id)->void:
	match action_name:
		"ROLL":
			var roll : int = action_result
			print("Roll: %d" % roll)
			if multiplayer.get_unique_id() == player_id:
				for i in range(roll):
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
		tween.tween_property(current_player_node, "position", 
								next_position, 2.5)
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
