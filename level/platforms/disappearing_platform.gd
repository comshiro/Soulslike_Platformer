class_name DisappearingPlatform extends StaticBody2D

@export var visible_duration := 2.0
@export var hidden_duration := 1.5
@export var start_hidden := false

@onready var sprite := $Sprite2D as Sprite2D
@onready var collision := $CollisionPolygon2D as CollisionPolygon2D

var _time_left := 0.0
var _is_visible := true


func _ready() -> void:
	_is_visible = not start_hidden
	_time_left = visible_duration if _is_visible else hidden_duration
	_apply_state()


func _physics_process(delta: float) -> void:
	_time_left -= delta
	
	if _is_visible and _time_left <= 0.0:
		# Switch to hidden
		_is_visible = false
		_time_left = hidden_duration
		_apply_state()
	elif not _is_visible and _time_left <= 0.0:
		# Switch to visible
		_is_visible = true
		_time_left = visible_duration
		_apply_state()


func _apply_state() -> void:
	sprite.modulate.a = 1.0 if _is_visible else 0.3
	collision.disabled = not _is_visible
