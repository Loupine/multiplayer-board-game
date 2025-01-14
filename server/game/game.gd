extends Node2D

signal action_finished()
signal turn_finsihed()
signal round_finished()
signal game_finished()

const MAX_ROUNDS := 3 # How many times will each player have a turn

var turn_order :Array= []
var turn_actions_taken :Array= []
var current_turn_index := 0
var round_number := 1


func _ready()->void:
	connect("round_finished", _on_round_finished)
	connect("game_finished", _on_game_finished)
	randomize()


# Used if a player is reconnecting to the server and their old id needs to be updated
func update_turn_order_ids(old_id: int, new_id: int)->void:
	var player_index := turn_order.find(old_id)
	turn_order[player_index] = new_id


# Called in lobby.gd player_loaded() func only if the game has started and a player
# has begun the reconnection process
func handle_reconnection(id: int)->void:
	var player_data :Dictionary= Lobby.players
	# Sends all other client data and the round number to the reconnecting player
	PlayerReconnector.process_reconnection.rpc_id(id, player_data, turn_order[current_turn_index], round_number)
	if turn_order[current_turn_index] == id: # If it's the reconnecting player's turn, start their turn again
		_start_player_turn.rpc(id, turn_actions_taken)


# Called exclusively on the server to determine player order and start the game
func start_game()->void:
	Lobby.game_started = true
	_spawn_players.rpc(Lobby.players)
	_determine_player_turn_order()
	_start_player_turn.rpc(turn_order[current_turn_index], turn_actions_taken)


# Client should call this when they want to start an action. This tells the server
# which action to process and which data to send for that action. If a player requests
# an action, the server will only process the action if it is that player's turn
@rpc("any_peer", "call_remote", "reliable")
func action_started(action_name: String)->void:
	var player_id := multiplayer.get_remote_sender_id()
	if player_id == turn_order[current_turn_index]:
		match action_name:
			"ROLL":
				if not turn_actions_taken.has(action_name):
					# Determine a number of spaces for the player to move
					var random_roll := randi_range(1, 6)
					_action_granted.rpc(action_name, random_roll, player_id)
					_update_player_board_position(player_id, random_roll)
					turn_actions_taken.append(action_name)
	else:
		print("It is not this player's turn.")


# Called by the server to signal clients to spawn player bodies.
@rpc("authority", "call_local", "reliable")
func _spawn_players(players_dictionary: Dictionary)->void:
	for id in players_dictionary:
		var player_body := _create_player(id)
		%Players.add_child(player_body)


func _create_player(player_id: int)->CharacterBody2D:
	var player_body := preload("res://player/player.tscn").instantiate()
	player_body.name = str(player_id)
	return player_body


func _determine_player_turn_order()->void:
	for player in Lobby.players:
		turn_order.append(player)
	turn_order.shuffle()


# The server starts the next player's turn and notifies all clients whose turn it is
@rpc("authority", "call_local", "reliable")
func _start_player_turn(_player_id: int, _actions_taken: Array)->void:
	# If custom server logic is required when starting a player's turn, put it here
	# in place of 'pass'
	pass


# This notifies the server to start the next player's turn when the current one finishes. 
@rpc("any_peer", "call_local", "reliable")
func _turn_finished()->void:
	# Continue only if it is the sender's turn
	if multiplayer.get_remote_sender_id() == turn_order[current_turn_index]:
		current_turn_index = (current_turn_index + 1) % turn_order.size()
		turn_finsihed.emit()
		if current_turn_index == 0:
			round_finished.emit()
		turn_actions_taken.clear()
		# Start the next player's turn
		_start_player_turn.rpc(turn_order[current_turn_index], turn_actions_taken)


func _update_player_board_position(player_id: int, roll: int)->void:
	var board_position_index = Lobby.players.get(player_id)["board_position"]
	var next_position_index = (board_position_index + roll) % %BoardPositions.get_children().size()
	Lobby.players.get(player_id)["board_position"] = next_position_index


# The server determines when the round finishes and rpc's the clients
@rpc("authority", "call_local", "reliable")
func _round_finished()->void:
	if round_number == MAX_ROUNDS:
		game_finished.emit()
	round_number += 1
	print("Round %d started" % round_number)


# The server determines when the game finishes and rpc's the clients.
@rpc("authority", "call_local", "reliable")
func _game_finished()->void:
	# Load the lobby for all peers. Should be changed if custom logic is desired
	# on the clients when a game ends. This custom logic should replace the pass
	# line on clients and the below rpc call should be moved elsewhere
	Lobby.load_lobby.rpc("res://main_menu.tscn")


# Server processes player actions and tells all clients what action was requested, 
# which player requested it, and any data necessary to complete the action. Called 
# in the action_started method
@rpc("authority", "call_remote", "reliable")
func _action_granted(_action_name: String, _action_result: Variant, _player_id: int)->void:
	pass


func _on_round_finished()->void:
	_round_finished.rpc()


func _on_game_finished()->void:
	_game_finished.rpc()
