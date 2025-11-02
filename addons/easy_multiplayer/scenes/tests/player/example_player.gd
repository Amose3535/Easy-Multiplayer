extends MultiplayerCharacterBody2D

var speed : float = 10.0
const OUTLINEMAT = preload("res://addons/easy_multiplayer/assets/outline shader/outline_material.tres")
const PROJECTILE_SCENE = preload("")

@onready var sprite: Sprite2D = $Sprite2D
var last_dir : Vector2 = Vector2.ZERO

func _ready() -> void:
	player_enabled.connect(on_player_enabled)

func on_player_enabled() -> void:
	print("Player {id} enabled".format({"id":player_id}))

func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority(): return
	if !enabled: return
	
	sprite.material = OUTLINEMAT
	var input : Vector2 = Input.get_vector("ui_left","ui_right","ui_up","ui_down")
	if !is_equal_approx(input.length(),0):
		velocity +=  input * speed
		last_dir = lerp(last_dir, velocity.normalized(), delta*10)
	else:
		velocity = lerp(velocity,Vector2.ZERO,delta*0.5)
	rotation = lerp_angle(rotation, last_dir.angle(), delta*3)
	
	if Input.is_action_just_pressed("ui_accept"):
		shoot.rpc()
	
	move_and_slide()

@rpc("any_peer","call_local")
func shoot() -> void:
	PROJECTILE_SCENE.instantiate()
