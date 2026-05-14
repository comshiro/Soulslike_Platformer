extends Node2D

@export var speed := 250.0
@export var lifetime := 3.0
@export var damage := 1
@export var hit_range := 16.0

var velocity := Vector2.ZERO
var time_alive := 0.0
var has_hit := false


func _ready() -> void:
	_setup_visuals()


func _setup_visuals() -> void:
	# Create a simple visual: colored square
	var rect = ColorRect.new()
	rect.color = Color.YELLOW
	rect.size = Vector2(12, 12)
	rect.position = Vector2(-6, -6)
	rect.self_modulate = Color(1.0, 0.85, 0.0, 1.0)
	add_child(rect)


func _process(delta: float) -> void:
	time_alive += delta
	if time_alive >= lifetime:
		queue_free()
	
	global_position += velocity * speed * delta
	
	if not has_hit:
		_check_collision()


func set_direction(dir: Vector2) -> void:
	velocity = dir.normalized()


func _check_collision() -> void:
	var player := get_tree().root.find_child("Player", true, false) as Node
	if not player:
		return
	
	var distance := global_position.distance_to(player.global_position)
	if distance <= hit_range:
		if player.has_method("take_damage"):
			player.call("take_damage", damage)
		has_hit = true
		queue_free()



