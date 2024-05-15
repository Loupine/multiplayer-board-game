extends Node2D

const _TOTAL_BOARD_POSITIONS := 10

var _unique_id: int
var _current_player_node: Node
var _round_number := 1
var _turn_number := 0
var _actions: Node


func _ready():
	_unique_id = multiplayer.get_unique_id()
	Lobby.player_loaded.rpc_id(1)
	_actions = Actions.new(get_tree(), _unique_id, _TOTAL_BOARD_POSITIONS, %BoardPositions, %ControlsUI)
	%LocalPlayerName.text = Lobby.player_info["name"]


func _physics_process(_delta: float):
	if _current_player_node != null:
		%Camera2D.position = _current_player_node.position


# Called on clients when a player is reconnecting. Ensures the old player id is
# replaced with the new one and the player's body is named properly.
# Is required for player bodies to update correctly
func replace_old_player_id(old_id: int, new_id: int)->void:
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


# Reconnecting client receives positional data from the server, reconstructs
# the other players' nodes, and updates the active player body.
@rpc("authority", "call_remote", "reliable")
func _send_reconnect_data(player_data: Dictionary, player_turn_id: int, round_num: int)->void:
	_update_round_text(round_num)
	for id in player_data:
		# Spawn the player body
		var player_body = _create_player(id)
		%Players.add_child(player_body)
		# Update the player body's position based on the player data
		var board_position_index = player_data.get(id)["board_position"]
		player_body.position = %BoardPositions.get_child(board_position_index).position

		if id == _unique_id:
			Lobby.player_info["board_position"] = board_position_index # Update client's player data
		if id == player_turn_id:
			# Update the active player node
			_current_player_node = player_body
			_actions.update_current_player_node(_current_player_node)
			_update_turn_text(id, _turn_number)


# The server starts the next player's turn and notifies all clients whose turn it is
@rpc("authority", "call_remote", "reliable")
func _start_player_turn(player_id: int, actions_taken: Array)->void:
	_update_current_player_node(player_id)
	if _unique_id == player_id:
		_turn_number += 1
		_update_turn_text(player_id, _turn_number)
		%ControlsUI.show_controls(actions_taken)
	else:
		_update_turn_text(player_id, -1)


func _update_current_player_node(player_id: int)->void:
	# Doing %Players.find_child(str(player_id)) returns null so we loop through 
	# all the players until we find one with a matching name
	for child in %Players.get_children():
		if child.name == str(player_id):
			_current_player_node = child # Set the current player node for future reference
			_actions.update_current_player_node(_current_player_node)
			break


# Updates GameUI to reflect the current turn's information.
func _update_turn_text(player_id: int, number: int)->void:
	if _unique_id == player_id: 
		%TurnNumber.text = "Turn: " + str(number)
		%CurrentPlayerName.text = "Your turn"
	else:
		%CurrentPlayerName.text = "%s's turn" % Lobby.players.get(player_id)["name"]


func _update_round_text(round_num: int)->void:
	_round_number = round_num
	%RoundNumber.text = "Round: " + str(_round_number)


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


# Server processes _actions requested by players and tells all clients what action
# was requested, which player requested it, and any data necessary to complete the
# action.
@rpc("authority", "call_remote", "reliable")
func _action_processed(action_name: String, action_result: Variant, player_id: int)->void:
	match action_name:
		"ROLL":
			_actions.move_player(action_result, player_id)


# The server determines when the round finishes and rpc's the clients
@rpc("authority", "call_local", "reliable")
func _round_finished()->void:
	_update_round_text(_round_number + 1)
	# Sync turn number with round number if offset at the end of the round
	# _turn_number should always be 1 less than _round_number when a round starts
	if _round_number > _turn_number + 1:
		_turn_number = _round_number - 1
		_update_turn_text(_unique_id, _turn_number)


# The server determines when the game finishes and rpc's the clients. Currently
# the server calls Lobby.load_lobby.rpc on all clients in its _game_finished rpc
# so this will be bypassed on clients and the lobby will load instead. This could
# be changed if custom logic is desired when the game ends besides just loading the
# lobby
@rpc("authority", "call_local", "reliable")
func _game_finished()->void:
	pass
