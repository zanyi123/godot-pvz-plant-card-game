## 全局入口脚本（备用）
## 目前主场景直接是 main_menu.tscn，此脚本保留用于后续全局管理
extends Node


func _ready() -> void:
	if OS.has_feature("debug"):
		print("[Main] PVZ Plant Card Game - Godot 4.6.2")
	# 强制保持宽高比，防止手机宽屏上 UI 偏移
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
