extends Node2D

signal action_finished()
signal turn_finsihed()
signal round_finished(number)
signal game_finished()

var turn_order : Array = []
var current_turn_index := 0
var round_number := 1
var players = Lobby.players
var current_player_node: Node


func _ready():
	%PlayerSpawner.add_spawnable_scene("res://player/player.tscn")
	randomize()


func start_game()->void:
	spawn_players()
	_determine_player_turn_order()
	_send_turn_order.rpc(turn_order)
	_start_player_turn.rpc(turn_order[current_turn_index])


func spawn_players()->void:
	for player in players:
		var player_body := create_player(player)
		%Players.add_child(player_body)


func create_player(player_id)->CharacterBody2D:
	var player_body := preload("res://player/player.tscn").instantiate()
	player_body.name = str(player_id)
	return player_body


# The server sends the generated turn order to clients
@rpc("authority", "call_remote", "reliable")
func _send_turn_order(_order)->void:
	pass


# The server starts the next player's turn
@rpc("authority", "call_local", "reliable")
func _start_player_turn(player_id)->void:
	_set_player_camera(player_id)


func _set_player_camera(player_id)->void:
	# Doing %Players.find_child(str(player_id)) erroneously returns null so we 
	# unfortunately have to loop through all the players
	for child in %Players.get_children():
		if child.name == str(player_id):
			current_player_node = child
			child.call("set_player_camera")
			break


# Client should call this once their turn is over and all turn actions are finished or skipped
@rpc("any_peer", "call_remote", "reliable")
func turn_finished()->void:
	if multiplayer.get_remote_sender_id() == turn_order[current_turn_index]:
		current_turn_index = 0 if current_turn_index == turn_order.size() -1 else current_turn_index + 1
		turn_finsihed.emit()
		_start_player_turn.rpc(turn_order[current_turn_index])


# Client should call this when certain actions finish during their turn
@rpc("any_peer", "call_remote", "reliable")
func action_started(action_name, player_id)->void:
	if player_id == turn_order[current_turn_index]:
		match action_name:
			"ROLL":
				var random_roll = randi_range(1, 6)
				_action_processed.rpc(action_name, random_roll, player_id)
	else:
		print("It is not this player's turn.")


# Server calls this when an action is started by the client and should send the 
# action result to all clients
@rpc("authority", "call_remote", "reliable")
func _action_processed(_action_name, _action_result: Variant, _player_id)->void:
	pass


# The server determines when the round finishes and rpc's the clients
@rpc("authority", "call_local", "reliable")
func _round_finished()->void:
	pass


# The server determines when the game finishes and rpc's the clients
@rpc("authority", "call_local", "reliable")
func _game_finished()->void:
	Lobby.load_lobby.rpc("res://main_menu.tscn")


func _determine_player_turn_order():
	for player in players:
		turn_order.append(player)
	turn_order.shuffle()
