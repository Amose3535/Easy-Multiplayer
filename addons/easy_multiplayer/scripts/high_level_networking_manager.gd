# high_level_networking.gd (autoload)
extends Node

signal on_peer_connected(id: int)
signal on_peer_disconnected(id: int)
signal on_peer_connected_to_server
signal on_peer_connection_failed
signal updated_peer_count

## The IP address which will be used by clients to search for the host
@export var ip_address : String = "localhost"
## The port on which the server and the clients will communicate. Please note that if this is change donly client-side, then the host and clients won't be able to connect so make sure to leave it as is or change it on both sides.
@export var port : int = 61679
## The max number of network peers connected to the host at one time <-> This is the number of CLIENTS allowed on the server. (total peers = max_network_peers + 1)
@export var max_network_peers: int = 10
## The compression used to send packets across the network. Please note that like the port, this must be the same on both clients and server, so either leave as is or change accordingly.
@export var compression_method: ENetConnection.CompressionMode = ENetConnection.COMPRESS_RANGE_CODER
## Wether this peer accepts new incoming connections or not. Useful when the lobby / room is full and you want the server to ignore new clients trying to connect.
@export var accepts_incoming_connections: bool = true:
	set(new_accepts_connections_state):
		accepts_incoming_connections = new_accepts_connections_state
		if !peer: return
		peer.refuse_new_connections = !accepts_incoming_connections

enum PeerType {
	## When the peer is on a default state and ready to be set either as a SERVER or CLIENT.
	UNINITIALIZED = -1,
	## When creating a client, this is set as the "type".
	CLIENT = 0,
	## When creating a server, this is set as the "type".
	SERVER = 1
}

## The tpye of this peer. By default itìs UNINITIALIZED (-1)
var type : PeerType = PeerType.UNINITIALIZED
## The actual peer object of this instance. By default it's null and it's created through start_client() / start_server()
var peer: ENetMultiplayerPeer = null
# On Server: Stores the number of connected CLIENTS (excluding the host).
# On Client: Stores the number of OTHER PEERS (received via RPC, excluding the client itself).
var current_connected_peers : int = 0

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
		_update_and_notify_peer_count()

## Function called when a peer connects to the network.[br]
## This gets called on servers and clients
func _on_peer_connected(id: int) -> void:
	print("Player connected. Peer id: {id}".format({"id":id}))
	on_peer_connected.emit(id)
	
	# Only the server must broadcast the new count
	if multiplayer.is_server():
		_update_and_notify_peer_count()

## Function called when a peer disconnects from the network.[br]
## This gets called on servers and clients
func _on_peer_disconnected(id: int) -> void:
	print("Player disconnected. Peer id: {id}".format({"id":id}))
	on_peer_disconnected.emit(id)
	
	if id == 1: # if the id of the disconnected peer is 1 (server), end session and reset everything
		end_session()
	
	# Only the server must broadcast the new count
	if multiplayer && multiplayer.multiplayer_peer && multiplayer.is_server():
		_update_and_notify_peer_count()

## Function called when a peer connects to the server.[br]
## This gets called on clients only
func _on_peer_connected_to_server() -> void:
	print("Peer connected to server!")
	on_peer_connected_to_server.emit()

## Function called when a peer connection fails.[br]
## This gets called on clients only
func _on_peer_connection_failed() -> void:
	print("Couldn't connect!")
	end_session()
	on_peer_connection_failed.emit()

## Function used to start a server
func start_server() -> void:
	peer = ENetMultiplayerPeer.new()
	var error : Error = peer.create_server(port, max_network_peers)
	if (error != OK):
		print("Couldn't create server: ", error_string(error))
		return
	peer.host.compress(compression_method)
	multiplayer.multiplayer_peer = peer
	print("Server ready! Waiting for connections.")
	type = PeerType.SERVER
	
	# Initial update for the host itself
	_update_and_notify_peer_count()

## Function used to start a client
func start_client() -> void:
	peer = ENetMultiplayerPeer.new()
	var error : Error = peer.create_client(ip_address, port)
	if (error != OK):
		print("Couldn't create client: ", error_string(error))
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
	peer = null
	type = PeerType.UNINITIALIZED
	current_connected_peers = 0
	
	# Note: Signals will remain connected. The system is ready for start_server/start_client again.
	print("Network state reset. Ready for a new session.")

## Function used to terminate the current network session, acting differently based on peer type.
func end_session() -> void:
	if type == PeerType.UNINITIALIZED:
		print("Attempted to end session, but no session was active.")
		return
	
	var old_type = type
	
	print("Ending network session as [{type}]...".format({"type": "SERVER" if old_type == PeerType.SERVER else "CLIENT"}))
	
	# --- Client Behavior ---
	if old_type == PeerType.CLIENT:
		# A client simply calls disconnect and resets its own state.
		# The server's peer_disconnected signal will handle the server-side update.
		if peer:
			peer.close() # Close the connection
		# Client resets itself immediately
		reset_network_state()
		
	# --- Server Behavior ---
	elif old_type == PeerType.SERVER:
		# A server must reset all clients and then reset its own state.
		
		# 1. Inform all clients to leave/reset (Optional, but good practice).
		#    However, as you correctly noted, relying on this is tricky if the connection breaks.
		#    ENetMultiplayerPeer's close() on the host automatically informs all connected clients.
		
		# 2. Close the server peer
		if peer:
			peer.close() # This will force-disconnect all clients.
			
		# 3. Server resets itself.
		reset_network_state()

## SERVER ONLY: Calculates the current client count and notifies all peers to update their values.
func _update_and_notify_peer_count():
	# 1. Calculate the number of connected CLIENTS (peers, excluding host)
	var peer_count : int = multiplayer.get_peers().size()
	
	# 2. Update the host's local state (called DIRECTLY)
	current_connected_peers = peer_count
	updated_peer_count.emit() # Triggers UI/logic update for the host
	
	# 3. Broadcast the RPC to all CLIENTS
	# 'peer_count' is the number of OTHER PEERS (which is correct for clients/host)
	rpc("recieve_peer_count", peer_count)
	

## Function for the current number of TOTAL PLAYERS (Clients + Host)
func get_current_player_count() -> int:
	# The count of total players is the number of other peers + 1 (yourself)
	
	if multiplayer.is_server():
		# Server (Host): Get real-time count from the ENet peer
		# get_peers().size() is the number of clients, so add 1 for the host
		return multiplayer.get_peers().size() + 1
	else:
		# Client: Return the ASYNCHRONOUS count received from the server
		# current_connected_peers is the number of other peers (clients + host)
		return current_connected_peers + 1

## Function for the maximum number of TOTAL PLAYERS (Clients + Host)
func get_max_player_count() -> int:
	# max_network_peers is the max number of CLIENTS, so add 1 for the host
	return max_network_peers + 1

@rpc("reliable")
## This function is called by the server on all peers (including itself) to update the count.
func recieve_peer_count(count: int) -> void:
	# This 'count' represents the number of OTHER PEERS (excluding the current peer).
	
	# The server already updated its count via _update_and_notify_peer_count() direct call,
	# but it's safe to update here too, or you can skip it:
	if !multiplayer.is_server():
		current_connected_peers = count
		updated_peer_count.emit() # Triggers UI/logic update for clients
