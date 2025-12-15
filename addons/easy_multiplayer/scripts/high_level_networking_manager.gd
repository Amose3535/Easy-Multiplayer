# high_level_networking.gd (autoload)
extends Node

## Emitted when a peer connects
signal on_peer_connected(id: int)
## Emitted when a peer disconnects
signal on_peer_disconnected(id: int)
signal on_peer_connected_to_server
signal on_peer_connection_failed
## Updated when the player_dict list changes.
signal updated_peer_list




## The IP address which will be used by clients to search for the host
@export var ip_address : String = "localhost"
## The port on which the server and the clients will communicate. Please note that if this is change donly client-side, then the host and clients won't be able to connect so make sure to leave it as is or change it on both sides.
@export var port : int = 61679
## The max number of network peers connected to the host at one time <-> This is the number of CLIENTS allowed on the server.
@export var max_network_peers: int = 10:
	get = get_max_player_count
## The compression used to send packets across the network. Please note that like the port, this must be the same on both clients and server, so either leave as is or change accordingly.
@export var compression_method: ENetConnection.CompressionMode = ENetConnection.COMPRESS_RANGE_CODER
## Wether this peer accepts new incoming connections or not. Useful when the lobby / room is full and you want the server to ignore new clients trying to connect.
@export var accepts_incoming_connections: bool = true:
	set(new_accepts_connections_state):
		accepts_incoming_connections = new_accepts_connections_state
		if !multiplayer.multiplayer_peer: return
		multiplayer.multiplayer_peer.refuse_new_connections = !accepts_incoming_connections
## The nickname that defines this client. When a server is started, the nick for the server peer is ignored.
@export var player_nickname: String = &""
## DEBUG
@export var debug: bool = false




const SERVER_ID: int = 1
const ILLEGAL_NICK_CHARS: String = "#()[]{}<>\\|/"

enum PeerType {
	## When the peer is on a default state and ready to be set either as a SERVER or CLIENT.
	UNINITIALIZED = -1,
	## When creating a client, this is set as the "type".
	CLIENT = 0,
	## When creating a server, this is set as the "type".
	SERVER = 1
}

## The tpye of this peer. By default itìs UNINITIALIZED (-1)
var type: PeerType = PeerType.UNINITIALIZED
## A dictionary what contains all client peers with their own nickname
var player_dict: Dictionary[int, String]:
	set(new_dict):
		player_dict = new_dict
		updated_peer_list.emit()




func _ready() -> void:
	# Connect signals for general networking events
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_peer_connected_to_server)
	multiplayer.connection_failed.connect(_on_peer_connection_failed)
	
	# Connect local signals for server-specific logic if we become the server later
	# Note: These connections must exist before creating the server/client peer.
	if multiplayer.is_server():
		# Initial update for the host itself
		_update_and_notify_players_list()



#region Network management

## Function called when a peer connects to the network.[br]
## This gets called on servers and clients
func _on_peer_connected(id: int) -> void:
	if debug: print("Player connected. Peer id: {id}".format({"id":id}))
	on_peer_connected.emit(id)
	
	# Only the server must broadcast the new count
	if multiplayer.is_server():
		_update_and_notify_players_list()




## Function called when a peer disconnects from the network.[br]
## This gets called on servers and clients
func _on_peer_disconnected(id: int) -> void:
	if debug: print("Player disconnected. Peer id: {id}".format({"id":id}))
	
	# Only the server must broadcast the new count
	if multiplayer.is_server():
		player_dict.erase(id)
		print("Ereased %d. Now: %s"%[id, str(player_dict)])
		_update_and_notify_players_list()
	
	
	on_peer_disconnected.emit(id)
	
	if id == SERVER_ID : # if the id of the disconnected peer is 1 (server), end session and reset everything
		end_session()
	




## Function called when a peer connects to the server.[br]
## This gets called on clients only
func _on_peer_connected_to_server() -> void:
	if debug: print("Peer connected to server!")
	on_peer_connected_to_server.emit()




## Function called when a peer connection fails.[br]
## This gets called on clients only
func _on_peer_connection_failed() -> void:
	if debug: print("Couldn't connect!")
	end_session()
	on_peer_connection_failed.emit()




## Function used to start a server
func start_server() -> void:
	var peer = ENetMultiplayerPeer.new()
	var error : Error = peer.create_server(port, max_network_peers)
	if (error != OK):
		if debug: print("Couldn't create server: ", error_string(error))
		return
	peer.host.compress(compression_method)
	multiplayer.multiplayer_peer = peer
	if debug: print("Server ready! Waiting for connections.")
	type = PeerType.SERVER
	
	# Initial update for the host itself
	_update_and_notify_players_list()
	updated_peer_list.emit()




## Function used to start a client
func start_client() -> void:
	var peer = ENetMultiplayerPeer.new()
	var error : Error = peer.create_client(ip_address, port)
	if (error != OK):
		if debug: print("Couldn't create client: ", error_string(error))
		return
	peer.host.compress(compression_method)
	multiplayer.multiplayer_peer = peer
	type = PeerType.CLIENT




## Resets the state of the autoload, making it ready to be a server or client again.
## This is called *after* a session is terminated (either by client choosing to leave, or server closing).
func reset_network_state() -> void:
	# 1. Clear the network peer (this also disconnects if connected)
	multiplayer.multiplayer_peer = null
	
	# 2. Reset the local state variables
	type = PeerType.UNINITIALIZED
	player_dict = {}
	
	# Note: Signals will remain connected. The system is ready for start_server/start_client again.
	if debug: print("Network state reset. Ready for a new session.")




## Function used to terminate the current network session, acting differently based on peer type.
func end_session() -> void:
	if type == PeerType.UNINITIALIZED:
		if debug: print("Attempted to end session, but no session was active.")
		return
	
	var old_type = type
	
	if debug: print("Ending network session as [{type}]...".format({"type": "SERVER" if old_type == PeerType.SERVER else "CLIENT"}))
	
	# --- Client Behavior ---
	if old_type == PeerType.CLIENT:
		# A client simply calls disconnect and resets its own state.
		# The server's peer_disconnected signal will handle the server-side update.
		if multiplayer.multiplayer_peer: multiplayer.multiplayer_peer = null # Close the connection
		# Client resets itself immediately
		reset_network_state()
		
	# --- Server Behavior ---
	elif old_type == PeerType.SERVER:
		
		# 1. Inform all clients to leave/reset. 
		
		
		# 2. Close the server peer
		if multiplayer.multiplayer_peer: multiplayer.multiplayer_peer = null # Force-disconnect all clients
			
		# 3. Server resets itself.
		reset_network_state()
#endregion Network management






#region Nickname Handshake
## SERVER ONLY: Calculates the current client count and notifies all peers to update their values.
func _update_and_notify_players_list():
	if !multiplayer.is_server(): return # Ensures this runs on the SERVER ONLY
	print("Server requires player names")
	# Asks the peers to answer with their names
	_get_client_nick.rpc()


@rpc("reliable")
## RPC function that runs on CLIENTS ONLY, used to answer the server to recieve this peer's nickname
func _get_client_nick() -> void:
	if multiplayer.is_server(): return # Ensures this runs on CLIENTS ONLY
	print("Client %d answers with %s"%[multiplayer.get_unique_id(), player_nickname])
	# Call on the server (id 1) the rpc "_recieve_nickname" with the provided nickname
	_recieve_nickname.rpc_id(SERVER_ID, player_nickname)


@rpc("any_peer","reliable")
## RPC function that runs on the SERVER ONLY. This function is called from peers on the server to recieve the nicknames.
func _recieve_nickname(nickname:String) -> void:
	if !multiplayer.is_server(): return # Ensures this runs on the SERVER ONLY
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == SERVER_ID: return
	print("Server recieved the nickname from %d: %s"%[sender, nickname])
	var current_players: Dictionary[int, String] = player_dict.duplicate()
	
	## Check for multiple occurrences of the same name ( unused ) 
	#var names: Array[String] = current_players.values()
	#var occurrences: int = 0
	#for nick:String in names:
		#if ((nick == nickname) || ((nick.begins_with(nickname)) && (nick.ends_with(")")))):
			#occurrences += 1
	# nickname = nickname + ("" if occurrences == 0 else " (%d)"%occurrences)
	
	# Apply nickname
	current_players[sender] = nickname
	#if player_dict != current_players: # Change dict and call rpc only when necessary
	player_dict = current_players # This triggers the setter
	print("Calling rpc")
	sync_player_dict.rpc(current_players)


@rpc("reliable")
## RPC function that runs on CLIENTS ONLY. This function is responsible for updating the client-side players list
func sync_player_dict(new_players: Dictionary[int, String]) -> void:
	if multiplayer.is_server(): return # Ensures this runs on CLIENTS ONLY
	if multiplayer.get_remote_sender_id() != SERVER_ID: return# Ensures that ONLY if the server has sent the new list, the peer will accept it.
	player_dict = new_players # Applies the recieved, server-issued player_dict
	print("Client %d recieved notification from server to update its player list copy. Now: %s"%[multiplayer.get_unique_id(),str(new_players)])
	
#endregion Nickname Handshake






#region Network Utilities
## Returns the player count, using the local copy of the server-issued player list
func get_current_player_count() -> int:
	print("Player list: %s"%str(player_dict))
	print("Player list size: %d"%player_dict.size())
	return player_dict.size()

func get_max_player_count() -> int:
	return max_network_peers

## To be used only on the BASE nickname. AKA the nickname the user WANTS to insert, not an in-game nickname
## as the game could use "illegal" characters ONLY to clarify or differentiate different players
func is_valid_nickname(nick: String) -> bool:
	if nick.length() == 0: return false
	for letter:String in ILLEGAL_NICK_CHARS:
		if letter in nick: return false
	return true

#endregion
