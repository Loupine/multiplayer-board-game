extends Node

# Autoload named Lobby

# These signals can be connected to by a UI lobby scene or the game scene.
signal player_connected_to_lobby()
signal player_disconnected(peer_id)

const PORT = 6029
const DEFAULT_SERVER_IP = "localhost" # IPv4 localhost
const MAX_CONNECTIONS = 3

# This will contain player info for every player,
# with the keys being each player's unique IDs.
var players : Dictionary = {}
var disconnected_players : Dictionary = {}
var players_loaded := 0
var game_started := false


func _ready():
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	player_connected_to_lobby.connect(_on_player_connected_to_lobby)

	create_game()


func create_game():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_CONNECTIONS)
	if error:
		return error
	multiplayer.multiplayer_peer = peer


# When the server decides to start the game from a UI scene,
# do Lobby.load_game.rpc(filepath)
@rpc("authority", "call_local", "reliable")
func load_game(game_scene_path)->void:
	get_tree().change_scene_to_file(game_scene_path)


# Every peer will call this when they have loaded the game scene.
@rpc("any_peer", "call_local", "reliable")
func player_loaded()->void:
	players_loaded += 1
	if players_loaded == players.size():
		$/root/Game.start_game()
		players_loaded = 0


# When server receives new player info from a client, send that info to all other players
@rpc("any_peer", "call_remote", "reliable")
func _server_receive_player_info(new_player_info: Dictionary)->void:
	var sender_id = multiplayer.get_remote_sender_id()
	if players.has(sender_id):
		pass
	else:
		if game_started:
			if !disconnected_players.is_empty():
				# Try reconnection only if game is started and there are disconnected players
				print("Trying player reconnect")
				_try_player_reconnect(sender_id, new_player_info)
			else:
				print("Game started and no players are disconnected")
				multiplayer.multiplayer_peer.disconnect_peer(sender_id)
		elif multiplayer.get_peers().size() > MAX_CONNECTIONS:
			print("Server is full. New connection denied.")
			multiplayer.multiplayer_peer.disconnect_peer(sender_id, true)
		else:
			# If game is not started and the lobby is not full, allow the connection
			print("%s has connected!" % new_player_info["name"])
			_send_new_player_info_to_players(sender_id, new_player_info)
			players[sender_id] = new_player_info
			player_connected_to_lobby.emit()


# Server method, called above, that sends new player info to existing players and
# existing player info to new players
func _send_new_player_info_to_players(new_player_id, info)->void:
	for player in players:
		# Sends new player info to existing players
		_register_player.rpc_id(player, new_player_id, info)

		# Send existing player info to new players
		var existing_player_info = players.get(player)
		_register_player.rpc_id(new_player_id, player, existing_player_info)


func _try_player_reconnect(id, info)->void:
	var player_reconnected := false
	# Make sure the player isn't already connected!
	for player in players:
		var connected_player_info = players.get(player)
		if connected_player_info["name"] == info["name"]:
			print("This player is already connected!")
			multiplayer.multiplayer_peer.disconnect_peer(id, true)
			return

	# Validate the player was disconnected and try reconnecting them
	for player in disconnected_players:
		var disconnected_player_info = disconnected_players.get(player)
		if disconnected_player_info["name"] == info["name"]:
			info["board_position"] = disconnected_player_info["board_position"]
			_reconnect_clients(player, id, info)
			players[id] = info
			disconnected_players.erase(player)
			player_reconnected = true
			print("%s successfully reconnected" % info["name"])
			break

	# If reconnect attempts fail, disconnect the peer
	if !player_reconnected:
		multiplayer.multiplayer_peer.disconnect_peer(id, true)


func _reconnect_clients(old_id, new_id, info)->void:
	for player in players:
		# Notify existing players that the player has reconnected
		_reconnect_player.rpc_id(player, old_id, new_id, info)

		# Re-register existing players with the reconnected one.
		var existing_player_info = players.get(player)
		_register_player.rpc_id(new_id, player, existing_player_info)


# Client method that handles player reconnection
@rpc("authority", "call_remote", "reliable")
func _reconnect_player(_old_id, _new_id, _info)->void:
	pass


# Client method that adds new players with info sent from server
@rpc("authority", "call_remote", "reliable")
func _register_player(_new_player_id, _new_player_info)->void:
	pass


func _reset_server()->void:
	get_tree().change_scene_to_file("res://main_menu.tscn")
	game_started = false
	players_loaded = 0
	players.clear()
	disconnected_players.clear()


func _on_player_connected_to_lobby()->void:
	if players.size() == MAX_CONNECTIONS:
		load_game.rpc("res://game/game.tscn")


func _on_player_disconnected(id)->void:
	print("Player %d, disconnected!" % id)
	if game_started:
		if players.is_empty():
			_reset_server()
		else:
			disconnected_players[id] = players.get(id)
			disconnected_players.get(id)["connection_status"] = "Disconnected"
	players.erase(id)
