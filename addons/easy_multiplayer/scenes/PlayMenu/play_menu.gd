extends Control

@onready var server_button: Button = $PanelContainer/MarginContainer/VBoxContainer/PanelContainer/MarginContainer/CenterContainer/VBoxContainer/Server
@onready var client_button: Button = $PanelContainer/MarginContainer/VBoxContainer/PanelContainer/MarginContainer/CenterContainer/VBoxContainer/Client


func _on_server_pressed() -> void:
	disable_play_buttons()


func _on_client_pressed() -> void:
	disable_play_buttons()

func disable_play_buttons() -> void:
	server_button.disabled = true
	client_button.disabled = true
