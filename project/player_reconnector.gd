extends Node

# Autoload called PlayerReconnector

@rpc("authority", "call_remote", "reliable")
func _reconnect_player(old_id: int, new_id: int, info: Dictionary)->void:
	$/root/Game.restore_player_functionality(old_id, new_id)
	Lobby.players.erase(old_id)
	Lobby.players[new_id] = info
