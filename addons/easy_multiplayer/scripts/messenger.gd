extends PanelContainer

@onready var message_edit: LineEdit = %SendMessage
@onready var chat_log: RichTextLabel = %ChatLog

func _ready() -> void:
	chat_log.text = ""
	message_edit.text_submitted.connect((func _on_text_submitted(text): message_edit.text = ""; _recieve_message.rpc(text)))

func start_messenger() -> void:
	message_edit.editable = true

#func _on_message_submitted(text: String) -> void:
	#_recieve_message.rpc(text)

@rpc("any_peer","call_local","reliable")
func _recieve_message(content: String) -> void:
	var sender: int =  multiplayer.get_remote_sender_id()
	var is_sender: bool = multiplayer.get_unique_id() == sender
	var sender_name: String = ""
	if is_sender: sender_name = "You"
	elif multiplayer.get_remote_sender_id() == 1: sender_name = "SERVER"
	else: sender_name = HighLevelNetworking.player_dict[sender]
	
	chat_log.text += "[color={user_color}]".format({"user_color":("red"if is_sender else"white")})+sender_name+"[/color]: "+content+"\n"
