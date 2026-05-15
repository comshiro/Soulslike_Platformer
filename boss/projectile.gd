extends Node2D

@export var speed := 330.0
@export var lifetime := 3.2
@export var damage := 1
@export var hit_range := 20.0
@export var spin_speed := 9.0

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
	var points := PackedVector2Array([
		Vector2(18, 0),
		Vector2(6, 6),
		Vector2(0, 18),
		Vector2(-6, 6),
		Vector2(-18, 0),
		Vector2(-6, -6),
		Vector2(0, -18),
		Vector2(6, -6),
	])
	draw_colored_polygon(points, Color(0.42, 1.0, 0.72, 0.34))
	draw_circle(Vector2.ZERO, 9.0, Color(0.92, 1.0, 0.58, 0.88))
	draw_circle(Vector2(3, -3), 3.0, Color(1.0, 1.0, 0.88, 1.0))
	draw_arc(Vector2.ZERO, 16.0, 0.2, 2.9, 16, Color(0.24, 0.92, 0.66, 0.86), 2.0)


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



