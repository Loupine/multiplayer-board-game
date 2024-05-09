class_name MoveAction
extends Node

var _scene_tree: SceneTree
var _multiplayer_id: int
var _total_board_positions: int
var _board_positions_node: Node
var _player_controls_node: Node
var _current_player_node: Node


func _init(scene_tree: SceneTree, multiplayer_id: int, total_board_positions: int, board_positions_node: Node, player_controls_node: Node)->void:
	_scene_tree = scene_tree
	_multiplayer_id = multiplayer_id
	_total_board_positions = total_board_positions
	_board_positions_node = board_positions_node
	_player_controls_node = player_controls_node


func update_current_player_node(current_player_node: Node)->void:
	_current_player_node = current_player_node


func move_player(action_result: int, player_id: int)->void:
	var roll :int= action_result
	if _multiplayer_id == player_id: # If this client is the player, do the action
		await _move_player_to_next_board_position(player_id, roll)
		_player_controls_node.call("on_finished_moving")
	else:
		await _move_player_to_next_board_position(player_id, roll)


func _move_player_to_next_board_position(player_id: int, roll: int)->void:
	for i in range(roll):
		var next_position := _calc_next_board_position(player_id)
		var tween := _current_player_node.create_tween()
		# Gradually move to the next position with a property tweener over 2.5 seconds.
		tween.tween_property(_current_player_node, "position",
								next_position, 1.0)
		# Wait for a timer signal to ensure processing is stopped until the next 
		# position is reached. If await is removed here or in the 'ROLL' action, 
		# the players will skip to the final position w/o visiting the other ones.
		await _scene_tree.create_timer(1.0).timeout


func _calc_next_board_position(player_id: int)->Vector2:
	var board_position_index: int
	var next_position_index: int
	if player_id == _multiplayer_id:
		board_position_index = Lobby.player_info["board_position"]
		next_position_index = (board_position_index + 1) % _total_board_positions
		Lobby.player_info["board_position"] = next_position_index
	else:
		board_position_index = Lobby.players.get(player_id)["board_position"]
		next_position_index = (board_position_index + 1) % _total_board_positions
		Lobby.players.get(player_id)["board_position"] = next_position_index
	return _board_positions_node.get_child(next_position_index).position
