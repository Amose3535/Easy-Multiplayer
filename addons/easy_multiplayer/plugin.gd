@tool
extends EditorPlugin


func _enable_plugin() -> void:
	add_autoload_singleton("HighLevelNetworking","res://addons/easy_multiplayer/scenes/autoloads/HighLevelNetworkingManager.tscn")
	add_autoload_singleton("LowLevelNetworking","res://addons/easy_multiplayer/scenes/autoloads/LowLevelNetworkingManager.tscn")
	pass


func _disable_plugin() -> void:
	remove_autoload_singleton("HighLevelNetworking")
	remove_autoload_singleton("LowLevelNetworking")
	pass


func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	pass


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	pass
