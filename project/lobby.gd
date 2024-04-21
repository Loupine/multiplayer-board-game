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

# This is the local player info. This should be modified locally
# before the connection is made. It will be passed to every other peer.
# For example, the value of "name" can be set to something the player
# entered in a UI scene.
var player_info = {
	"name": "Name",
	"board_position": "Position",
	"connection_status": "Status"
}
var game_started := false


func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func join_game(address = ""):
	if address.is_empty():
		address = DEFAULT_SERVER_IP
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	if error:
		return error
	multiplayer.multiplayer_peer = peer


# When the server decides to start the game from a UI scene,
# do Lobby.load_game.rpc(filepath)
@rpc("authority", "call_local", "reliable")
func load_game(game_scene_path)->void:
	get_tree().change_scene_to_file(game_scene_path)


# When the server ends the game, it should do Lobby.load_lobby(filepath) to reset players
# back to the lobby.
@rpc("authority", "call_local", "reliable")
func load_lobby(lobby_scene_path)->void:
	get_tree().change_scene_to_file(lobby_scene_path)
	for player in players:
		$/root/MainMenu.add_connected_player_name(players.get(player)["name"])


# Every peer will call this when they have loaded the game scene.
@rpc("any_peer", "call_local", "reliable")
func player_loaded():
	pass


# When a client connects to a server, send player info to the server
func _on_connected_to_server():
	player_info["connection_status"] = "Connected"
	_server_receive_player_info.rpc_id(1, player_info)


# When server receives new player info from a client, send that info to all other players
@rpc("any_peer", "call_remote", "reliable")
func _server_receive_player_info(_new_player_info)-> void:
	pass


# Client method that adds new players with info sent from server
@rpc("authority", "call_remote", "reliable")
func _register_player(new_player_id, new_player_info):
	players[new_player_id] = new_player_info
	player_connected.emit(new_player_id, new_player_info)


@rpc("authority", "call_remote", "reliable")
func _reconnect_player(old_id, new_id, info):
	$/root/Game.restore_player_functionality(old_id, new_id)
	players.erase(old_id)
	players[new_id] = info


func _on_player_connected(id):
	print("Player %d, connected!" % id)


func _on_player_disconnected(id):
	print("Player %d, disconnected!" % id)
	player_disconnected.emit(id)
	if !game_started:
		players.erase(id)
	


func _on_connected_fail():
	print("Connection failed. Please try again.")
	multiplayer.multiplayer_peer = null


func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	players.clear()
