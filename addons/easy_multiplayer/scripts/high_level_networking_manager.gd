# high_level_networking_manager.gd (autoload)
extends Node

signal on_peer_connected(id: int)
signal on_peer_disconnected(id: int)
signal on_peer_connected_to_server
signal on_peer_connection_failed
signal updated_peer_count

@export var ip_address : String = "localhost"
@export var port : int = 61679
@export var max_network_peers: int = 10 # Max number of CLIENTS allowed on the server.
@export var compression_method: ENetConnection.CompressionMode = ENetConnection.COMPRESS_RANGE_CODER

enum PeerType {
	UNINITIALIZED = -1,
	CLIENT = 0,
	SERVER = 1
}

var type : PeerType = -1
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
	
	# Only the server must broadcast the new count
	if multiplayer.is_server():
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


## SERVER ONLY: Calculates the current client count and notifies all peers.
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
