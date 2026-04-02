class_name DashShard extends Area2D
## Grants the player a dash ability once collected.


@export var float_height := 8.0
@export var float_speed := 4.0

var _base_y := 0.0


func _ready() -> void:
	_base_y = position.y


func _process(delta: float) -> void:
	rotation += delta * 1.4
	position.y = _base_y + sin(Time.get_ticks_msec() * 0.001 * float_speed) * float_height


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		(body as Player).unlock_dash()
		queue_free()
