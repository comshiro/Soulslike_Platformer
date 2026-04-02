class_name ForestBoss extends CharacterBody2D


signal defeated


@export var max_health := 14
@export var walk_speed := 90.0
@export var dash_speed := 320.0
@export var dash_cooldown := 1.8

var _health := 0
var _dash_cooldown_left := 0.0
var _is_dead := false

@onready var gravity: int = ProjectSettings.get("physics/2d/default_gravity")
@onready var sprite := $Sprite2D as Sprite2D
@onready var animation_player := $AnimationPlayer as AnimationPlayer


func _ready() -> void:
	_health = max_health


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	_dash_cooldown_left = maxf(0.0, _dash_cooldown_left - delta)
	velocity.y += gravity * delta

	var player := get_parent().get_parent().get_node_or_null("Player") as Player
	if player:
		var direction := signf(player.global_position.x - global_position.x)
		if is_zero_approx(direction):
			direction = 1.0
		velocity.x = move_toward(velocity.x, direction * walk_speed, 500.0 * delta)

		var distance := absf(player.global_position.x - global_position.x)
		if distance < 190.0 and _dash_cooldown_left == 0.0:
			velocity.x = direction * dash_speed
			_dash_cooldown_left = dash_cooldown

	move_and_slide()

	if velocity.x > 0.0:
		sprite.scale.x = 1.15
	elif velocity.x < 0.0:
		sprite.scale.x = -1.15

	if animation_player.current_animation != "walk":
		animation_player.play("walk")


func take_damage(amount: int = 1) -> void:
	if _is_dead:
		return
	_health -= amount
	if _health <= 0:
		die()


func die() -> void:
	_is_dead = true
	velocity = Vector2.ZERO
	defeated.emit()
	if animation_player.current_animation != "destroy":
		animation_player.play("destroy")
