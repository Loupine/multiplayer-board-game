extends Node2D


func _ready():
	Lobby.player_loaded.rpc_id(1)


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
