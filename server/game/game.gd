extends Node2D

signal action_finished()
signal turn_finsihed()
signal round_finished(number)
signal game_finished()

var turn_order : Array[String] = []
var round_number := 1
var players = Lobby.players
var random_generator = RandomNumberGenerator.new()


func _ready():
	random_generator.randomize()


func start_game()->void:
	_determine_player_turn_order()


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
