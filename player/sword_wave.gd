class_name SwordWave extends RigidBody2D


@export var damage := 1
@export var charged := false

@onready var sprite := $Sprite2D as Sprite2D


func _ready() -> void:
	if charged:
		sprite.modulate = Color(0.6, 1.0, 1.0, 1.0)


func _on_body_entered(body: Node) -> void:
	if body is Enemy:
		(body as Enemy).destroy()
	elif body.has_method("take_damage"):
		body.call("take_damage", damage)
	queue_free()


func _on_timer_timeout() -> void:
	queue_free()
