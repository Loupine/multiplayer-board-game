extends Node2D

signal action_finished()
signal turn_finsihed()
signal round_finished()
signal game_finished()

const MAX_ROUNDS := 2 # How many times will each player have a turn

var turn_order :Array= []
var current_turn_index := 0
var round_number := 1
var players :Dictionary= Lobby.players


func _ready():
	%PlayerSpawner.add_spawnable_scene("res://player/player.tscn")
	connect("round_finished", _on_round_finished)
	connect("game_finished", _on_game_finished)
	randomize()


# Called exclusively on the server to determine player order and start the game
func start_game()->void:
	spawn_players()
	_determine_player_turn_order()
	_send_turn_order.rpc(turn_order)
	_start_player_turn.rpc(turn_order[current_turn_index])


# Player spawning is synced via the PlayerSpawner node in the game scene.
# Adding players directly to the Players node automatically spawns them on any
# connected clients.
func spawn_players()->void:
	for player in players:
		var player_body := create_player(player)
		%Players.add_child(player_body)


func create_player(player_id: int)->CharacterBody2D:
	var player_body := preload("res://player/player.tscn").instantiate()
	player_body.name = str(player_id)
	return player_body


# The server sends the randomized turn order to clients
@rpc("authority", "call_remote", "reliable")
func _send_turn_order(_order: Array)->void:
	pass


# The server starts the next player's turn and notifies all clients whose turn it is
@rpc("authority", "call_local", "reliable")
func _start_player_turn(player_id: int)->void:
	# Set player camera on the server. Useful for developmental debugging.
	# Should be removed for production ready builds.
	_set_player_camera(player_id)


func _set_player_camera(player_id: int)->void:
	# Doing %Players.find_child(str(player_id)) erroneously returns null so we 
	# unfortunately have to loop through all the players
	for child in %Players.get_children():
		if child.name == str(player_id):
			child.call("set_player_camera")
			break


# This notifies the server to start the next player's turn when the current one finishes. 
@rpc("any_peer", "call_remote", "reliable")
func turn_finished()->void:
	# Continue only if it is the sender's turn
	if multiplayer.get_remote_sender_id() == turn_order[current_turn_index]:
		current_turn_index = (current_turn_index + 1) % turn_order.size()
		turn_finsihed.emit()
		if current_turn_index == 0:
			round_finished.emit()
		
		_start_player_turn.rpc(turn_order[current_turn_index]) # Start the next player's turn


# Client should call this when they want to start an action. This tells the server
# which action to process and which data to send for that action. If a player requests
# an action, the server will only process the action if it is that player's turn
@rpc("any_peer", "call_remote", "reliable")
func action_started(action_name: String)->void:
	var player_id := multiplayer.get_remote_sender_id()
	if player_id == turn_order[current_turn_index]:
		match action_name:
			"ROLL":
				# Determine a number of spaces for the player to move
				var random_roll := randi_range(1, 6)
				_action_processed.rpc(action_name, random_roll, player_id)
	else:
		print("It is not this player's turn.")


# Server processes actions requested by players and tells all clients what action
# was requested, which player requested it, and any data necessary to complete the
# action. Called in the above action_started method
@rpc("authority", "call_remote", "reliable")
func _action_processed(_action_name: String, _action_result: Variant, _player_id: int)->void:
	pass


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


func _determine_player_turn_order():
	for player in players:
		turn_order.append(player)
	turn_order.shuffle()


func _on_round_finished()->void:
	_round_finished.rpc()


func _on_game_finished()->void:
	_game_finished.rpc()
