class_name SwordPickup extends Area2D
## Unlocks sword attacks when picked up.


@export var float_height := 10.0
@export var float_speed := 3.5

var _base_y := 0.0


func _ready() -> void:
	_base_y = position.y


func _process(delta: float) -> void:
	rotation += delta * 0.8
	position.y = _base_y + sin(Time.get_ticks_msec() * 0.001 * float_speed) * float_height


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		(body as Player).unlock_sword()
		queue_free()
