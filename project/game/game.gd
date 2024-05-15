extends Node2D

const _TOTAL_BOARD_POSITIONS := 10

var current_player_node: Node
var actions: Node

var _unique_id: int
var _round_number := 1
var _turn_number := 0


func _ready()->void:
	_unique_id = multiplayer.get_unique_id()
	Lobby.player_loaded.rpc_id(1)
	actions = Actions.new(get_tree(), _unique_id, _TOTAL_BOARD_POSITIONS, %BoardPositions, %ControlsUI)
	%LocalPlayerName.text = Lobby.player_info["name"]


func _physics_process(_delta: float)->void:
	if current_player_node != null:
		%Camera2D.position = current_player_node.position


# Updates GameUI to reflect the current turn's information.
func update_turn_text(player_id: int, number: int)->void:
	if _unique_id == player_id: 
		%TurnNumber.text = "Turn: " + str(number)
		%CurrentPlayerName.text = "Your turn"
	else:
		%CurrentPlayerName.text = "%s's turn" % Lobby.players.get(player_id)["name"]


func update_round_text(round_num: int)->void:
	_round_number = round_num
	%RoundNumber.text = "Round: " + str(_round_number)


# Client should call this when they want to start an action. This tells the server
# which action to process and which data to send for that action. If a player requests
# an action, the server will only grant permission if it is that player's turn
@rpc("any_peer", "call_remote", "reliable")
func action_started(_action_name: String)->void:
	pass


# Called on clients when a player is reconnecting. Ensures the old player id is
# replaced with the new one and the player's body is named properly.
# Is required for player bodies to process actions correctly
func replace_old_player_id(old_id: int, new_id: int)->void:
	for child in %Players.get_children():
		if child.name == str(old_id):
			child.set_name(str(new_id))
			break


func create_player(player_id: int)->CharacterBody2D:
	var player_body := preload("res://player/player.tscn").instantiate()
	player_body.name = str(player_id)
	%Players.add_child(player_body)
	return player_body


# Called by the server to signal clients to spawn player bodies.
@rpc("authority", "call_local", "reliable")
func _spawn_players(players_dictionary: Dictionary)->void:
	for id in players_dictionary:
		var player_body := create_player(id)
		player_body.position = %BoardPositions/Pos1.position


# The server starts the next player's turn and notifies all clients whose turn it is
@rpc("authority", "call_remote", "reliable")
func _start_player_turn(player_id: int, actions_taken: Array)->void:
	_update_current_player_node(player_id)
	if _unique_id == player_id:
		_turn_number += 1
		update_turn_text(player_id, _turn_number)
		%ControlsUI.show_controls(actions_taken)
	else:
		update_turn_text(player_id, -1)


func _update_current_player_node(player_id: int)->void:
	# Doing %Players.find_child(str(player_id)) returns null so we loop through 
	# all the players until we find one with a matching name
	for child in %Players.get_children():
		if child.name == str(player_id):
			current_player_node = child # Set the current player node for future reference
			actions.update_current_player_node(current_player_node)
			break


# Server processes actions requested by players and tells all clients what action
# was requested, which player requested it, and any data necessary to complete the
# action.
@rpc("authority", "call_remote", "reliable")
func _action_granted(action_name: String, action_result: Variant, player_id: int)->void:
	match action_name:
		"ROLL":
			actions.move_player(action_result, player_id)


# The server determines when the round finishes and rpc's the clients
@rpc("authority", "call_local", "reliable")
func _round_finished()->void:
	update_round_text(_round_number + 1)
	# Sync turn number with round number if offset at the end of the round
	# _turn_number should always be 1 less than _round_number when a round starts
	if _round_number > _turn_number + 1:
		_turn_number = _round_number - 1
		update_turn_text(_unique_id, _turn_number)


# The server determines when the game finishes and rpc's the clients. Currently
# the server calls Lobby.load_lobby.rpc on all clients in its _game_finished rpc
# so this will be bypassed on clients and the lobby will load instead. This could
# be changed if custom logic is desired when the game ends besides just loading the
# lobby
@rpc("authority", "call_local", "reliable")
func _game_finished()->void:
	pass


# This notifies the server to start the next player's turn when the current turn finishes.
# Connected via the turn finished signal in controls_ui.gd
@rpc("any_peer", "call_local", "reliable")
func _turn_finished()->void:
	# Call on server to notify
	_turn_finished.rpc_id(1)
