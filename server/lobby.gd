extends Node

# Autoload named Lobby

# These signals can be connected to by a UI lobby scene or the game scene.
signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected

const PORT = 6029
const DEFAULT_SERVER_IP = "localhost" # IPv4 localhost
const MAX_CONNECTIONS = 20

# This will contain player info for every player,
# with the keys being each player's unique IDs.
var players : Dictionary = {}
var disconnected_players = {}
var players_loaded : int = 0
var game_started := false


func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connection_failed.connect(_on_connected_fail)

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
func load_game(game_scene_path):
	get_tree().change_scene_to_file(game_scene_path)


# Every peer will call this when they have loaded the game scene.
@rpc("any_peer", "call_local", "reliable")
func player_loaded():
	players_loaded += 1
	if players_loaded == players.size():
		$/root/Game.start_game()
		players_loaded = 0


# When server receives new player info from a client, send that info to all other players
@rpc("any_peer", "call_remote", "reliable")
func _server_receive_player_info(new_player_info: Dictionary)-> void:
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
		elif multiplayer.get_peers().size() == MAX_CONNECTIONS:
			print("Server is full. New connection denied.")
			multiplayer.multiplayer_peer.disconnect_peer(sender_id)
		else:
			# If game is not started and the lobby is not full, allow the connection
			print("%s has connected!" % new_player_info["name"])
			_send_new_player_info_to_players(sender_id, new_player_info)
			players[sender_id] = new_player_info


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


func _reconnect_clients(old_id, new_id, info):
	for player in players:
		# Notify existing players that the player has reconnected
		_reconnect_player.rpc_id(player, old_id, new_id, info)

		# Re-register existing players with the reconnected one.
		var existing_player_info = players.get(player)
		_register_player.rpc_id(new_id, player, existing_player_info)


# Client method that handles player reconnection
@rpc("authority", "call_remote", "reliable")
func _reconnect_player(_old_id, _new_id, _info):
	pass


# Client method that adds new players with info sent from server
@rpc("authority", "call_remote", "reliable")
func _register_player(_new_player_id, _new_player_info):
	pass


func _on_player_connected(id):
	print("Player %d connected!" % id)


func _on_player_disconnected(id):
	print("Player %d, disconnected!" % id)
	if game_started and !players.is_empty():
		disconnected_players[id] = players.get(id)
		disconnected_players.get(id)["connection_status"] = "Disconnected"
	players.erase(id)


func _on_connected_fail():
	print("Connection failed. Please try again.")
