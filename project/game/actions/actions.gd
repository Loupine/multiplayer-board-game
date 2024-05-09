class_name Actions
extends Node

var _move_action: MoveAction


func _init(scene_tree: SceneTree, multiplayer_id: int, total_board_positions: int, board_positions_node: Node, player_controls_node: Node)->void:
	_move_action = MoveAction.new(scene_tree, multiplayer_id, total_board_positions, board_positions_node, player_controls_node)


func update_current_player_node(current_player_node: Node)->void:
	_move_action.update_current_player_node(current_player_node)


func move_player(action_result: int, player_id: int)->void:
	_move_action.move_player(action_result, player_id)
