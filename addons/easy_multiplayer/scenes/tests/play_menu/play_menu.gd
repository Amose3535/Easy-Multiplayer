extends Control

signal start_requested

@onready var server_button: Button = %Server
@onready var client_button: Button = %Client
@onready var start_game_button: Button = %StartGame
@onready var buttons_container: VBoxContainer = %ConnectionButtons
@onready var ip_line_edit: LineEdit = %IP
@onready var nick_line_edit: LineEdit = %Nickname
@onready var player_tooltip: Label = $PlayerCountTooltip

@export var debug: bool = false

var hint_text: String
var ip_address: String = "":
	## Only get ip_line_edit.text if ip_address is empty
	get:
		if ip_address == "":
			ip_address = ip_line_edit.text
		return ip_address
	set(new_ip):
		ip_address = new_ip


var nickname: String = "":
	## Only get ip_line_edit.text if nickname is empty
	get:
		if nickname == "":
			nickname = nick_line_edit.text
		return nickname
	set(new_ip):
		nickname = new_ip

func _ready() -> void:
	HighLevelNetworking.updated_peer_list.connect(_update_tooltip_display) # Peer count changed
	HighLevelNetworking.on_peer_connected_to_server.connect(_update_tooltip_display) # Peer connected to server (client side)
	HighLevelNetworking.on_peer_connected.connect(_on_peer_connected)
	HighLevelNetworking.on_peer_disconnected.connect(_on_peer_disconnected)
	HighLevelNetworking.on_peer_connected_to_server.connect(_on_peer_connected_to_server)
	HighLevelNetworking.on_peer_connection_failed.connect(_on_peer_connection_failed)
	_update_tooltip_display()

#region Peer connections

func _on_peer_connected(id: int) -> void:
	if debug: _notify("[Peer connected]","Peer connected with id {id}".format({"id":id}))
	_update_tooltip_display()

func _on_peer_disconnected(id: int) -> void:
	if debug: _notify("[Peer disconnected]","Peer disconnected with id {id}".format({"id":id}))
	_update_tooltip_display()

func _on_peer_connected_to_server() -> void:
	if debug: _notify("[Connection successful!]","Successfully connected to server")

func _on_peer_connection_failed() -> void:
	if debug: _notify("[Connection failed!]","Couldn't connect to server")
	# If the connection fails, then re enable buttons and reset network stats
	enable_connect_buttons()
	HighLevelNetworking.reset_network_state()
#endregion

## Creates a server and awaits for incoming connections
func _on_server_pressed() -> void:
	disable_connect_buttons()
	HighLevelNetworking.start_server()
	show_start_game()

## Creates a client connects to the server
func _on_client_pressed() -> void:
	if !ip_address.is_valid_ip_address() && (ip_address != "localhost"):
		OS.alert("The provided IP is not a valid IP address. Make sure to insert a correct one and retry.","WRONG IP")
		return
	if !HighLevelNetworking.is_valid_nickname(nickname):
		OS.alert("The provided nickname isn't valid. Make sure to insert one containing only letters, numbers. Not all symbols are supported.","WRONG NICKNAME")
		return
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
	start_requested.emit()

## Called when the ip line edit 's text changes. it sets the ip_address to the new text if it's a valid address and then clone the copy onto HighLevelNetworking.ip_address
func _on_ip_text_changed(new_text: String) -> void:
	ip_address = new_text if new_text.is_valid_ip_address() || new_text == "localhost" else ""
	HighLevelNetworking.ip_address = ip_address # gets set to "" or to new_text depending on the output

## Called when the nickname line edit's text changes. It sets the nickname to the new text if it's a valid nickname.
func _on_nickname_text_changed(new_text: String) -> void:
	nickname = new_text if HighLevelNetworking.is_valid_nickname(new_text) else ""
	HighLevelNetworking.player_nickname = nickname

## Disables buttons to prevent double presses
func disable_connect_buttons() -> void:
	server_button.disabled = true
	client_button.disabled = true
	var buttons_tween : Tween = get_tree().create_tween()
	buttons_tween.set_ease(Tween.EASE_IN)
	buttons_tween.tween_property(buttons_container,"custom_minimum_size:x",0,0.3)
	await buttons_tween.finished
	buttons_container.hide()

## Opposite of disable_connect_buttons
func enable_connect_buttons() -> void:
	buttons_container.show()
	server_button.disabled = false
	client_button.disabled = false
	var buttons_tween : Tween = get_tree().create_tween()
	buttons_tween.set_ease(Tween.EASE_IN)
	buttons_tween.tween_property(buttons_container,"custom_minimum_size:x",400.0,0.3)
	await buttons_tween.finished

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
		player_tooltip.text = "Press 'Server' or 'Client' to begin."
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
	
	player_tooltip.text = status_text + "\n" + action_text




func _notify(title: String, body: String):
	if get_tree().root.has_node("/root/NotificationEngine"):
		var notification_ref := get_tree().root.get_node("/root/NotificationEngine")
		if notification_ref.has_method(&"notify"):
			notification_ref.notify({"title":title,"body":body})
	else:
		print(title," ",body)
