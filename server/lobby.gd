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
var players = {}

# This is the local player info. This should be modified locally
# before the connection is made. It will be passed to every other peer.
# For example, the value of "name" can be set to something the player
# entered in a UI scene.
var player_info = {
	"name": "Name",
	"board_position": "Position"
}
var players_loaded = 0


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
func _server_receive_player_info(new_player_info)-> void:
	var sender_id = multiplayer.get_remote_sender_id()
	if players.has(sender_id):
		pass
	else:
		_send_new_player_info_to_players(sender_id, new_player_info)
		players[sender_id] = new_player_info


# Server method, called above, that sends new player info to other players
func _send_new_player_info_to_players(new_player_id, info)->void:
	for player in players:
		_register_player.rpc_id(player, new_player_id, info)


# Client method that adds new players with info sent from server
@rpc("authority", "call_remote", "reliable")
func _register_player(_new_player_id, _new_player_info):
	pass


func _on_player_connected(id):
	print("Player %d connected!" % id)


func _on_player_disconnected(id):
	print("Player %d, disconnected!" % id)


func _on_connected_fail():
	print("Connection failed. Please try again.")
