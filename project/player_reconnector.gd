extends Node

# Autoload called PlayerReconnector

@rpc("authority", "call_remote", "reliable")
func _reconnect_player(old_id: int, new_id: int, info: Dictionary)->void:
	$/root/Game.replace_old_player_id(old_id, new_id)
	Lobby.players.erase(old_id)
	Lobby.players[new_id] = info
