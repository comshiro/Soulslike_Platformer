extends Node2D

@export var speed := 250.0
@export var lifetime := 3.0
@export var damage := 1
@export var hit_range := 16.0
@export var spin_speed := 7.0

var velocity := Vector2.ZERO
var time_alive := 0.0
var has_hit := false


func _ready() -> void:
	z_index = 3


func _process(delta: float) -> void:
	time_alive += delta
	if time_alive >= lifetime:
		queue_free()

	rotation += spin_speed * delta
	global_position += velocity * speed * delta

	if not has_hit:
		_check_collision()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 12.0, Color(0.53, 1.0, 0.5, 0.28))
	draw_circle(Vector2.ZERO, 8.0, Color(0.92, 1.0, 0.48, 0.9))
	draw_circle(Vector2(4, -3), 3.0, Color(1.0, 1.0, 0.82, 1.0))
	draw_arc(Vector2.ZERO, 14.0, 0.2, 2.8, 14, Color(0.2, 0.9, 0.45, 0.8), 2.0)


func set_direction(dir: Vector2) -> void:
	velocity = dir.normalized()


func _check_collision() -> void:
	var player := get_tree().root.find_child("Player", true, false) as Node
	if not player:
		return

	var distance := global_position.distance_to(player.global_position)
	if distance <= hit_range:
		if player.has_method("boss_hit"):
			player.call("boss_hit", global_position.x)
		elif player.has_method("take_damage"):
			player.call("take_damage", damage)
		has_hit = true
		queue_free()



