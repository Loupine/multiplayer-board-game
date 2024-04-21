extends Node2D


func _ready():
	Lobby.player_loaded.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _action_finished()->void:
	pass


@rpc("any_peer", "call_remote", "reliable")
func _turn_finished()->void:
	pass


@rpc("authority", "call_local", "reliable")
func _round_finished()->void:
	pass


@rpc("authority", "call_local", "reliable")
func _game_finished()->void:
	pass
