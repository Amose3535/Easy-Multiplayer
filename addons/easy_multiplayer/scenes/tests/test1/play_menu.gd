extends Control

@onready var server_button: Button = $PanelContainer/MarginContainer/VBoxContainer/PanelContainer/MarginContainer/CenterContainer/HBoxContainer/VBoxContainer/Server
@onready var client_button: Button = $PanelContainer/MarginContainer/VBoxContainer/PanelContainer/MarginContainer/CenterContainer/HBoxContainer/VBoxContainer/Client
@onready var start_game_button: Button = $PanelContainer/MarginContainer/VBoxContainer/PanelContainer/MarginContainer/CenterContainer/HBoxContainer/StartGame
@onready var buttons_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/PanelContainer/MarginContainer/CenterContainer/HBoxContainer/VBoxContainer
@onready var tooltip: Label = $Tooltip

var hint_text: String

func _ready() -> void:
	HighLevelNetworking.updated_peer_count.connect(_update_tooltip_display)
	HighLevelNetworking.on_peer_connected_to_server.connect(_update_tooltip_display)
	_update_tooltip_display()
	
	HighLevelNetworking.on_peer_connected.connect(_on_peer_connected)
	HighLevelNetworking.on_peer_disconnected.connect(_on_peer_disconnected)
	HighLevelNetworking.on_peer_connected_to_server.connect(_on_peer_connected_to_server)
	HighLevelNetworking.on_peer_connection_failed.connect(_on_peer_connection_failed)

#region Peer connections

func _on_peer_connected(id: int) -> void:
	# Update 
	pass

func _on_peer_disconnected(id: int) -> void:
	pass

func _on_peer_connected_to_server() -> void:
	pass

func _on_peer_connection_failed() -> void:
	pass
#endregion

## Creates a server and awaits for incoming connections
func _on_server_pressed() -> void:
	disable_connect_buttons()
	HighLevelNetworking.start_server()
	show_start_game()

## Creates a client connects to the server
func _on_client_pressed() -> void:
	disable_connect_buttons()
	HighLevelNetworking.start_client()

## Starts the game
func _on_start_game_pressed() -> void:
	HighLevelNetworking.accepts_incoming_connections = false
	start_game_button.disabled = true
	var start_game_tween : Tween = get_tree().create_tween()
	start_game_tween.set_ease(Tween.EASE_IN)
	start_game_tween.tween_property(start_game_button,"custom_minimum_size:x",0,0.3)
	await start_game_tween.finished
	start_game_button.hide()
	print("Starting game")

## Disables buttons to prevent double presses
func disable_connect_buttons() -> void:
	server_button.disabled = true
	client_button.disabled = true
	var buttons_tween : Tween = get_tree().create_tween()
	buttons_tween.set_ease(Tween.EASE_IN)
	buttons_tween.tween_property(buttons_container,"custom_minimum_size:x",0,0.3)
	await buttons_tween.finished
	buttons_container.hide()

## Shows start game button through animation
func show_start_game() -> void:
	start_game_button.show()
	start_game_button.custom_minimum_size.x = 0
	var tween : Tween = get_tree().create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(start_game_button,"custom_minimum_size:x",172.0,0.3)


## Function to update the tooltip text based on the current peer count and role.
func _update_tooltip_display() -> void:
	# We must ensure the network peer is actually set before reading its state.
	if HighLevelNetworking.type == HighLevelNetworking.PeerType.UNINITIALIZED:
		tooltip.text = "Press 'Server' or 'Client' to begin."
		return
	
	# Use the public getters from the Autoload
	var current_players = HighLevelNetworking.get_current_player_count()
	var max_players = HighLevelNetworking.get_max_player_count()
	
	var status_text: String
	var action_text: String
	
	# Check the peer's role to determine the message logic
	if HighLevelNetworking.multiplayer.is_server():
		status_text = "{curr}/{max} players connected.".format({"curr": current_players, "max": max_players})
		action_text = "Start the game when ready."
	else:
		status_text = "Waiting for host. ({curr}/{max})".format({"curr": current_players, "max": max_players})
		action_text = ""
	
	tooltip.text = status_text + "\n" + action_text
