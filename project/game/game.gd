extends Node2D

const TOTAL_BOARD_POSITIONS := 10

var current_player_node
var round_number := 1
var turn_number := 0
var actions: Node


func _ready():
	Lobby.player_loaded.rpc_id(1)
	actions = Actions.new(get_tree(), multiplayer.get_unique_id(), TOTAL_BOARD_POSITIONS, $BoardPositions)
	%LocalPlayerName.text = Lobby.player_info["name"]


func _physics_process(_delta: float):
	if current_player_node != null:
		%Camera2D.position = current_player_node.position


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
	_find_player_node(player_id)
	if multiplayer.get_unique_id() == player_id:
		turn_number += 1
		%CurrentPlayerName.text = "%s's turn" % %LocalPlayerName.text
		%TurnNumber.text = "Turn: " + str(turn_number)
		current_player_node.call("show_controls", actions_taken)
	else:
		var player_name :String= Lobby.players.get(player_id)["name"]
		%CurrentPlayerName.text = "%s's turn" % player_name
		print("%s's turn started." % player_name)


func _find_player_node(player_id: int)->void:
	# Doing %Players.find_child(str(player_id)) returns null so we loop through 
	# all the players until we find one with a matching name
	for child in %Players.get_children():
		if child.name == str(player_id):
			current_player_node = child # Set the current player node for future reference
			actions.update_current_player_node(current_player_node)
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
			actions.move_player(action_result, player_id)


# The server determines when the round finishes and rpc's the clients
@rpc("authority", "call_local", "reliable")
func _round_finished()->void:
	round_number += 1
	%RoundNumber.text = "Round: " + str(round_number)


# The server determines when the game finishes and rpc's the clients. Currently
# the server calls Lobby.load_lobby.rpc on all clients in its _game_finished rpc
# so this will be bypassed on clients and the lobby will load instead. This could
# be changed if custom logic is desired when the game ends besides just loading the
# lobby
@rpc("authority", "call_local", "reliable")
func _game_finished()->void:
	pass
