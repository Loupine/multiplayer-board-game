extends Node2D

var turn_order :Array


func _ready():
	Lobby.player_loaded.rpc_id(1)
	%PlayerSpawner.add_spawnable_scene("res://player/player.tscn")


func spawn_player()->void:
	pass


# The server sends the generated turn order to clients
@rpc("authority", "call_remote", "reliable")
func _send_turn_order(order: Array)->void:
	turn_order = order


# The server starts the next player's turn
@rpc("authority", "call_remote", "reliable")
func _start_player_turn(player_id)->void:
	if multiplayer.get_unique_id() == player_id:
		_start_turn()
	else:
		print("%s's turn started." % Lobby.players.get(player_id)["name"])


func _start_turn():
	print("Turn started")


# Client should call this when certain actions finish during their turn
@rpc("any_peer", "call_remote", "reliable")
func _action_finished()->void:
	pass


# Client should call this once their turn is over and all turn actions are finished or skipped
@rpc("any_peer", "call_remote", "reliable")
func _turn_finished()->void:
	pass


# The server determines when the round finishes and rpc's the clients
@rpc("authority", "call_local", "reliable")
func _round_finished()->void:
	pass


# The server determines when the game finishes and rpc's the clients
@rpc("authority", "call_local", "reliable")
func _game_finished()->void:
	pass
