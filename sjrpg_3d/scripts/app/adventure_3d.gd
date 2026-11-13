class_name Adventure3D
extends Node3D
## 모험 진입점. 진행·UI는 투영 좌표를 사용하고 실제 몸체·높이·충돌은 SpatialWorld3D가 소유한다.

signal quit_requested
signal restart_requested
signal reload_requested
var simulation: Node2D


func _ready() -> void:
	simulation = preload("res://scripts/gameplay/game.gd").new()
	simulation.quit_requested.connect(func(): quit_requested.emit())
	simulation.restart_requested.connect(func(): restart_requested.emit())
	simulation.reload_requested.connect(func(): reload_requested.emit())
	add_child(simulation)
