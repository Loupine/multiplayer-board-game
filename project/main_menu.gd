extends Node2D


func _ready():
	Lobby.player_connected.connect(_add_connected_player_name)
	Lobby.player_disconnected.connect(_remove_disconnected_player_name)


func set_player_name()->bool:
	var player_name : String = %NameTextEdit.text
	player_name = player_name.replace(" ", "")
	player_name = player_name.replace("\n", "")
	if !player_name.is_empty():
		Lobby.player_info["name"] = player_name
		return true
	else:
		%InvalidNameDialog.show()
		return false


func _add_connected_player_name(_id, info)->void:
	var text_edit : TextEdit = %ConnectedPlayersTextEdit
	var player_name = info["name"]
	if text_edit.text.find(player_name) == -1:
		text_edit.text += player_name + "\n"


func _remove_disconnected_player_name(id)->void:
	var text_edit : TextEdit = %ConnectedPlayersTextEdit
	var text = text_edit.text
	var player_name = Lobby.players.get(id)["name"]
	if text.find(player_name) != -1:
		text_edit.text = text.replace(player_name + "\n", "")


func _on_name_text_changed():
	var textEdit: TextEdit = %NameTextEdit
	var text :String= textEdit.text
	if text.length() > 15:
		textEdit.text = text.substr(0, 15)


func _on_connect_button_pressed():
	if set_player_name():
		print(Lobby.player_info["name"])
		Lobby.join_game()
	else:
		pass
