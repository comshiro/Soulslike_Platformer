class_name ForestBoss extends CharacterBody2D


signal defeated
signal health_changed(current: int, maximum: int)


@export var max_health := 13
@export var walk_speed := 82.0
@export var dash_speed := 300.0
@export var dash_cooldown := 2.0
@export var preferred_distance := 170.0
@export var backstep_distance := 100.0
@export var dash_trigger_distance := 240.0
@export var contact_hit_range := 44.0
@export var contact_hit_vertical_tolerance := 58.0
@export var contact_hit_cooldown := 0.8
@export var close_range_brake_distance := 58.0
@export var platform_chase_jump_threshold := 95.0
@export var platform_jump_velocity := -540.0
@export var platform_jump_horizontal_boost := 190.0
@export var platform_jump_cooldown := 1.1

enum MoveState {
	APPROACH,
	STRAFE,
	BACKSTEP,
	DASH,
}

var _health := 0
var _dash_cooldown_left := 0.0
var _contact_hit_cooldown_left := 0.0
var _platform_jump_cooldown_left := 0.0
var _is_dead := false
var _is_active := true
var _state := MoveState.APPROACH
var _state_time_left := 0.0
var _dash_time_left := 0.0
var _pattern_step := 0
var _did_backstep_hop := false

@onready var gravity: int = ProjectSettings.get("physics/2d/default_gravity")
@onready var sprite := $Sprite2D as Sprite2D
@onready var animation_player := $AnimationPlayer as AnimationPlayer


func _ready() -> void:
	_health = max_health
	health_changed.emit(_health, max_health)
	_set_state(MoveState.APPROACH, 0.45)


func _physics_process(delta: float) -> void:
	if _is_dead or not _is_active:
		return

	_dash_cooldown_left = maxf(0.0, _dash_cooldown_left - delta)
	_contact_hit_cooldown_left = maxf(0.0, _contact_hit_cooldown_left - delta)
	_platform_jump_cooldown_left = maxf(0.0, _platform_jump_cooldown_left - delta)
	_state_time_left = maxf(0.0, _state_time_left - delta)
	velocity.y += gravity * delta

	var player := get_parent().get_parent().get_node_or_null("Player") as Player
	if player:
		var direction := signf(player.global_position.x - global_position.x)
		if is_zero_approx(direction):
			direction = 1.0

		var distance := absf(player.global_position.x - global_position.x)
		var vertical_delta := absf(player.global_position.y - global_position.y)
		var player_is_above := player.global_position.y < global_position.y - platform_chase_jump_threshold
		if _state_time_left == 0.0:
			_choose_next_state(distance)

		if is_on_floor() and _platform_jump_cooldown_left == 0.0 and player_is_above:
			velocity.y = platform_jump_velocity
			velocity.x += direction * platform_jump_horizontal_boost
			_platform_jump_cooldown_left = platform_jump_cooldown

		_match_state_movement(direction, distance, delta)

		if _contact_hit_cooldown_left == 0.0 and distance <= contact_hit_range and vertical_delta <= contact_hit_vertical_tolerance:
			if player.has_method("boss_hit"):
				player.call("boss_hit", global_position.x)
			sprite.modulate = Color(1.0, 0.82, 0.82, 1.0)
			var hit_fx := create_tween()
			hit_fx.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.12)
			_contact_hit_cooldown_left = contact_hit_cooldown

	move_and_slide()

	if velocity.x > 0.0:
		sprite.scale.x = 1.15
	elif velocity.x < 0.0:
		sprite.scale.x = -1.15

	if animation_player.current_animation != "walk":
		animation_player.play("walk")


func set_active(active: bool) -> void:
	_is_active = active
	if not _is_active:
		velocity = Vector2.ZERO


func _choose_next_state(distance: float) -> void:
	_pattern_step += 1

	if _dash_cooldown_left == 0.0 and distance <= dash_trigger_distance and _pattern_step % 3 == 0:
		_set_state(MoveState.DASH, 0.26)
		return

	if distance < backstep_distance:
		_set_state(MoveState.BACKSTEP, 0.42)
		return

	if distance > preferred_distance + 55.0:
		_set_state(MoveState.APPROACH, 0.55)
		return

	_set_state(MoveState.STRAFE, 0.62)


func _set_state(new_state: MoveState, duration: float) -> void:
	_state = new_state
	_state_time_left = duration
	if new_state == MoveState.DASH:
		_dash_time_left = duration
		_dash_cooldown_left = dash_cooldown
	if new_state == MoveState.BACKSTEP:
		_did_backstep_hop = false


func _match_state_movement(direction: float, distance: float, delta: float) -> void:
	match _state:
		MoveState.APPROACH:
			if distance <= close_range_brake_distance:
				velocity.x = move_toward(velocity.x, 0.0, 920.0 * delta)
			else:
				velocity.x = move_toward(velocity.x, direction * walk_speed, 560.0 * delta)

		MoveState.STRAFE:
			if distance <= close_range_brake_distance:
				velocity.x = move_toward(velocity.x, -direction * walk_speed * 0.5, 760.0 * delta)
				return
			var strafe_dir := direction if distance > preferred_distance else -direction
			velocity.x = move_toward(velocity.x, strafe_dir * walk_speed * 0.65, 520.0 * delta)

		MoveState.BACKSTEP:
			velocity.x = move_toward(velocity.x, -direction * walk_speed * 0.95, 700.0 * delta)
			if is_on_floor() and not _did_backstep_hop:
				velocity.y = -355.0
				_did_backstep_hop = true

		MoveState.DASH:
			_dash_time_left = maxf(0.0, _dash_time_left - delta)
			velocity.x = direction * dash_speed
			if _dash_time_left == 0.0:
				_set_state(MoveState.APPROACH, 0.35)


func take_damage(amount: int = 1) -> void:
	if _is_dead:
		return
	_health -= amount
	health_changed.emit(maxi(_health, 0), max_health)
	if _health <= 0:
		die()


func die() -> void:
	_is_dead = true
	velocity = Vector2.ZERO
	sprite.texture = preload("res://boss/TheForestSpirit-Death.png")
	sprite.hframes = 13
	sprite.vframes = 1
	sprite.frame = 0
	defeated.emit()
	if animation_player.current_animation != "destroy":
		animation_player.play("destroy")
