extends CharacterBody2D
class_name MultiplayerCharacterBody2D

signal player_enabled

@export_group("DO NOT TOUCH")
@export var player_id : int = 0
@export var enabled: bool = false



@rpc("call_local","reliable")
func enable_player() -> void:
	if multiplayer.get_remote_sender_id() != 1: return # Something other than the server tried to enable the player: skip
	set_multiplayer_authority(player_id) # Clients have no authority on the characters until they are enabled
	enabled = true
	player_enabled.emit()
