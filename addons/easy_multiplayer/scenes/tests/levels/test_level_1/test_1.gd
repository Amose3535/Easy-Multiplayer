extends Node

@export var level_path : NodePath = ^""
@export var players_path : NodePath = ^""

@onready var play_menu: Control = $PlayMenu

func _ready() -> void:
	if play_menu.has_signal(&"start_requested"): play_menu.start_requested.connect(_on_start_requested)
	

func _on_start_requested() -> void:
	start_game.rpc()
	pass

@rpc("any_peer","call_local")
func start_game() -> void:
	# If the SENDER of the RPC isn't the server skip since it's supposed to be called from server ONLY
	if multiplayer.get_remote_sender_id() != 1: return 
	
	# Hide menu (all peers) ----------------------------------------------------
	var modulate_tween : Tween = get_tree().create_tween()
	modulate_tween.set_ease(Tween.EASE_IN)
	modulate_tween.tween_property(play_menu,"modulate",Color(1.0, 1.0, 1.0, 0.0),0.15)
	await modulate_tween.finished
	play_menu.hide()
	$Messenger.start_messenger()
	
	#if !multiplayer.is_server(): return
	## Instantiate level 
	#var level : PackedScene = load("res://addons/easy_multiplayer/scenes/tests/levels/test_level_1/level_world.tscn")
	#get_node(level_path).add_child(level.instantiate())
	#
	## Enable players
	#for player in get_node(players_path).get_children():
		#if player is MultiplayerCharacterBody2D:
			#player.enable_player.rpc()
