class_name NativeAdventure
extends Node3D
## Native project entry. Legacy rules/UI observe projected coordinates; collision,
## elevation and actors are owned by SpatialWorld3D in the spatial viewport.

signal quit_requested
signal restart_requested
signal reload_requested
var simulation: Node2D


func _ready() -> void:
	simulation = preload("res://scripts/game.gd").new()
	simulation.quit_requested.connect(func(): quit_requested.emit())
	simulation.restart_requested.connect(func(): restart_requested.emit())
	simulation.reload_requested.connect(func(): reload_requested.emit())
	add_child(simulation)
