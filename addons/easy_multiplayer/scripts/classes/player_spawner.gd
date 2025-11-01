extends MultiplayerSpawner
class_name PlayerSpawner
## A class specifically made to spawn players over the network. Please note that these players MUST in their root node a script with a property called "player_id" or this won't work

@export var net_player : PackedScene = null

## How will the players be positioned after spawning. 
@export var spawn_mode : SpawnMode = SpawnMode.LINE_OFFSET
## The offset added along a line
@export var line_offset: float = 30


var cumulative_offset_line : float = 0.0

enum SpawnMode {
	## Spawns the players in the same spot
	IN_PLACE,
	## Spawns the next player with an offset along a line
	LINE_OFFSET,
	## Spawns the next player with an offset along a grid (wraps the players aftrer reachign the end of a row)
	GRID_OFFSET
}

func _ready() -> void:
	multiplayer.peer_connected.connect(_spawn_player)

# Executed on clients and servers
func _spawn_player(id: int) -> void:
	if !multiplayer.is_server(): return # Only server will handle spawning
	
	var player : Node = net_player.instantiate()
	player.enabled = false
	player.player_id = id
	get_node(spawn_path).add_child.call_deferred(player,true)
	
	# Positioning
	if spawn_mode == SpawnMode.LINE_OFFSET:
		cumulative_offset_line += line_offset
		player.position.x = cumulative_offset_line


func _despawn_player(id: int) -> void:
	pass
