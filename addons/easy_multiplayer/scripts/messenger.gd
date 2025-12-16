extends PanelContainer

@onready var message_edit: LineEdit = %SendMessage
@onready var chat_log: RichTextLabel = %ChatLog

func _ready() -> void:
	chat_log.text = ""
	message_edit.text_submitted.connect((func _on_text_submitted(text): message_edit.text = ""; _recieve_message.rpc(text)))
	HighLevelNetworking.on_peer_disconnection.connect(_on_peer_disconnection)

func start_messenger() -> void:
	message_edit.editable = true

#func _on_message_submitted(text: String) -> void:
	#_recieve_message.rpc(text)

func _on_peer_disconnection(id: int) -> void:
	if !multiplayer.is_server(): return # ONLY RUNS ON SERVER SIDE
	var departing_player: String = HighLevelNetworking.get_nickname(id)
	var quit_message: String = "{player} has quit.".format({"player":departing_player})
	_recieve_message.rpc(quit_message)


@rpc("any_peer","call_local","reliable")
func _recieve_message(content: String) -> void:
	var sender_id: int =  multiplayer.get_remote_sender_id()
	var is_sender: bool = multiplayer.get_unique_id() == sender_id
	var sender_name: String = ""
	var user_color: String = "white"
	if is_sender: 
		sender_name = "You"
		user_color = "red"
		if multiplayer.is_server():
			user_color = "orange"
	elif multiplayer.get_remote_sender_id() == 1:
		sender_name = "SERVER"
		user_color = "orange"
	else:
		sender_name = HighLevelNetworking.get_nickname(sender_id)
	chat_log.text += "[color={user_color}]".format({"user_color":user_color})+sender_name+"[/color]: "+content+"\n"
