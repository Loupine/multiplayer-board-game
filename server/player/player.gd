extends CharacterBody2D

signal rolled_for_movement


func set_player_camera()->void:
	%Camera2D.make_current()
