extends Node2D


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
