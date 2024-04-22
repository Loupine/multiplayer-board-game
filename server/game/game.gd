extends Node2D

signal action_finished()
signal turn_finsihed()
signal round_finished(number)
signal game_finished()

var turn_order : Array = []
var current_turn_index := 0
var round_number := 1
var players = Lobby.players
var random_generator = RandomNumberGenerator.new()


func _ready():
	%PlayerSpawner.add_spawnable_scene("res://player/player.tscn")
	random_generator.randomize()


func start_game()->void:
	spawn_players()
	_determine_player_turn_order()
	_send_turn_order.rpc(turn_order)
	_start_player_turn.rpc(turn_order[current_turn_index])


func spawn_players()->void:
	for player in players:
		var player_body := create_player(player)
		%Players.add_child(player_body)
		player_body.set_multiplayer_authority(player)


func create_player(player_id)->CharacterBody2D:
	var player_body := preload("res://player/player.tscn").instantiate()
	player_body.name = str(player_id)
	player_body.position = %BoardPositions.get_child(0).position + (
							Vector2(random_generator.randi_range(-100, 100),
									random_generator.randi_range(-100, 100)))
	var modulate_color := Color("blue")
	player_body.set_modulate(modulate_color)
	return player_body


# The server sends the generated turn order to clients
@rpc("authority", "call_remote", "reliable")
func _send_turn_order(_order)->void:
	pass


# The server starts the next player's turn
@rpc("authority", "call_remote", "reliable")
func _start_player_turn(_player_id)->void:
	pass


# Client should call this when certain actions finish during their turn
@rpc("any_peer", "call_remote", "reliable")
func _action_finished()->void:
	pass


# Client should call this once their turn is over and all turn actions are finished or skipped
@rpc("any_peer", "call_remote", "reliable")
func _turn_finished()->void:
	turn_finsihed.emit()


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
