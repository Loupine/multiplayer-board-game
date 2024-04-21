extends Node2D

signal turn_finsihed()
signal round_finished(number)

var turn_order : Array[String] = []
var round_number := 1
var players = Lobby.players
var random_generator = RandomNumberGenerator.new()


func _ready():
	random_generator.randomize()


func start_game()->void:
	_determine_player_turn_order()


@rpc("any_peer", "call_remote", "reliable")
func _action_finished()->void:
	pass


@rpc("any_peer", "call_remote", "reliable")
func _turn_finished()->void:
	turn_finsihed.emit()


@rpc("authority", "call_local", "reliable")
func _round_finished()->void:
	pass


@rpc("authority", "call_local", "reliable")
func _game_finished()->void:
	pass


func _determine_player_turn_order():
	for player in players:
		turn_order.append(player)
	turn_order.shuffle()
