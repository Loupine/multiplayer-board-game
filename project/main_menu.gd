extends Node2D


func _ready():
	Lobby.player_connected.connect(add_connected_player_name)
	Lobby.player_disconnected.connect(_remove_disconnected_player_name)


func set_player_name()->bool:
	var player_name :String= %NameTextEdit.text
	player_name = player_name.replace(" ", "")
	player_name = player_name.replace("\n", "")
	if !player_name.is_empty():
		Lobby.player_info["name"] = player_name
		return true
	else:
		%InvalidNameDialog.show()
		return false


func add_connected_player_name(_id: int, info: Dictionary)->void:
	var text_edit :TextEdit= %ConnectedPlayersTextEdit
	var player_name :String= info["name"]
	if text_edit.text.find(player_name) == -1:
		text_edit.text += player_name + "\n"


func _remove_disconnected_player_name(id: int)->void:
	var text_edit :TextEdit= %ConnectedPlayersTextEdit
	var text :String= text_edit.text
	print(Lobby.players.has(id))
	var player_name = Lobby.players.get(id)["name"]
	if text.find(player_name) != -1:
		text_edit.text = text.replace(player_name + "\n", "")


func _on_name_text_changed()->void:
	var textEdit :TextEdit= %NameTextEdit
	var text :String= textEdit.text
	if text.length() > 15:
		textEdit.text = text.substr(0, 15)


func _on_connect_button_pressed()->void:
	if set_player_name():
		Lobby.join_game()
	else:
		pass
