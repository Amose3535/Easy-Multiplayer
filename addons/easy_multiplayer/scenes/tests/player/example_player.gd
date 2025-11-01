extends MultiplayerCharacterBody2D

var speed : float = 10.0
const OUTLINEMAT = preload("res://addons/easy_multiplayer/assets/outline shader/outline_material.tres")


func _ready() -> void:
	player_enabled.connect(on_player_enabled)

func on_player_enabled() -> void:
	print("Player {id} enabled".format({"id":player_id}))

func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority(): return
	if !enabled: return
	material = OUTLINEMAT
	velocity += Input.get_vector("ui_left","ui_right","ui_up","ui_down") * speed
	move_and_slide()
