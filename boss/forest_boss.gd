class_name ForestBoss extends CharacterBody2D


signal defeated
signal health_changed(current: int, maximum: int)


@export var max_health := 13
@export var walk_speed := 82.0
@export var dash_speed := 300.0
@export var dash_duration := 0.26
@export var dash_windup_time := 0.24
@export var dash_recover_time := 0.28
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
@export var spray_pattern_cooldown := 3.0
@export var spray_count := 4
@export var spray_speed := 245.0
@export var spray_jump_height := -450.0
@export var spray_fire_interval := 0.16
@export var projectile_spawn_offset := Vector2(-46.0, -22.0)

enum MoveState {
	APPROACH,
	STRAFE,
	BACKSTEP,
	DASH_WINDUP,
	DASH,
	DASH_RECOVER,
	PATTERN_SPRAY,
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
var _dash_direction := 1.0
var _sprite_base_scale := Vector2.ONE
var _spray_cooldown_left := 0.0
var _spray_tick := 0
var _spray_fire_time_left := 0.0
var _last_facing_direction := 1.0
var _target_player: Player

@onready var gravity: int = ProjectSettings.get("physics/2d/default_gravity")
@onready var sprite := $Sprite2D as Sprite2D
@onready var animation_player := $AnimationPlayer as AnimationPlayer


func _ready() -> void:
	_health = max_health
	_sprite_base_scale = sprite.scale
	health_changed.emit(_health, max_health)
	_set_state(MoveState.APPROACH, 0.45)


func _physics_process(delta: float) -> void:
	if _is_dead or not _is_active:
		return

	_dash_cooldown_left = maxf(0.0, _dash_cooldown_left - delta)
	_contact_hit_cooldown_left = maxf(0.0, _contact_hit_cooldown_left - delta)
	_platform_jump_cooldown_left = maxf(0.0, _platform_jump_cooldown_left - delta)
	_spray_cooldown_left = maxf(0.0, _spray_cooldown_left - delta)
	_state_time_left = maxf(0.0, _state_time_left - delta)
	velocity.y += gravity * delta

	var player := _get_player()
	if player:
		var direction := signf(player.global_position.x - global_position.x)
		if is_zero_approx(direction):
			direction = 1.0
		
		_last_facing_direction = direction

		var distance := absf(player.global_position.x - global_position.x)
		var vertical_delta := absf(player.global_position.y - global_position.y)
		var player_is_above := player.global_position.y < global_position.y - platform_chase_jump_threshold
		if _state_time_left == 0.0:
			if _state == MoveState.DASH_WINDUP:
				_set_state(MoveState.DASH, dash_duration)
			elif _state == MoveState.DASH_RECOVER:
				_set_state(MoveState.APPROACH, 0.35)
			else:
				_choose_next_state(distance, direction)

		if is_on_floor() and _platform_jump_cooldown_left == 0.0 and player_is_above:
			velocity.y = platform_jump_velocity
			velocity.x += direction * platform_jump_horizontal_boost
			_platform_jump_cooldown_left = platform_jump_cooldown

		_match_state_movement(direction, distance, delta)

		var hit_range := contact_hit_range + (14.0 if _state == MoveState.DASH else 0.0)
		if _contact_hit_cooldown_left == 0.0 and distance <= hit_range and vertical_delta <= contact_hit_vertical_tolerance:
			if player.has_method("boss_hit"):
				player.call("boss_hit", global_position.x)
			sprite.modulate = Color(1.0, 0.78, 0.78, 1.0)
			var hit_fx := create_tween()
			hit_fx.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.12)
			_contact_hit_cooldown_left = contact_hit_cooldown

	move_and_slide()

	if _last_facing_direction > 0.0:
		sprite.scale.x = absf(_sprite_base_scale.x)
	elif _last_facing_direction < 0.0:
		sprite.scale.x = -absf(_sprite_base_scale.x)

	if animation_player.current_animation != "walk":
		animation_player.play("walk")


func set_active(active: bool) -> void:
	_is_active = active
	if not _is_active:
		velocity = Vector2.ZERO


func _choose_next_state(distance: float, direction: float) -> void:
	_pattern_step += 1

	if _spray_cooldown_left == 0.0 and _pattern_step % 5 == 0:
		_spray_cooldown_left = spray_pattern_cooldown
		_spray_tick = 0
		_set_state(MoveState.PATTERN_SPRAY, 0.6)
		return

	if _dash_cooldown_left == 0.0 and distance <= dash_trigger_distance and _pattern_step % 3 == 0:
		_dash_direction = direction
		_set_state(MoveState.DASH_WINDUP, dash_windup_time)
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
	if new_state == MoveState.DASH_WINDUP:
		sprite.modulate = Color(1.0, 0.7, 0.7, 1.0)
	elif sprite.modulate != Color(1, 1, 1, 1):
		sprite.modulate = Color(1, 1, 1, 1)

	if new_state == MoveState.DASH:
		_dash_time_left = dash_duration
		_dash_cooldown_left = dash_cooldown
	if new_state == MoveState.BACKSTEP:
		_did_backstep_hop = false
	if new_state == MoveState.PATTERN_SPRAY:
		_spray_tick = 0
		_spray_fire_time_left = 0.0


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

		MoveState.DASH_WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, 920.0 * delta)

		MoveState.DASH:
			_dash_time_left = maxf(0.0, _dash_time_left - delta)
			velocity.x = _dash_direction * dash_speed
			if _dash_time_left == 0.0:
				_set_state(MoveState.DASH_RECOVER, dash_recover_time)

		MoveState.DASH_RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 840.0 * delta)

		MoveState.PATTERN_SPRAY:
			velocity.x = move_toward(velocity.x, 0.0, 920.0 * delta)
			if is_on_floor():
				velocity.y = spray_jump_height
			_spray_projectiles(delta)


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
	sprite.texture = preload("res://boss/TheForestSpirit-Death-cropped.png")
	sprite.hframes = 13
	sprite.vframes = 1
	sprite.frame = 0
	defeated.emit()
	if animation_player.current_animation != "destroy":
		animation_player.play("destroy")


func _spray_projectiles(delta: float) -> void:
	_spray_fire_time_left -= delta
	if _spray_fire_time_left > 0.0:
		return

	_spray_tick += 1
	if _spray_tick > spray_count:
		return

	_spray_fire_time_left = spray_fire_interval
	var player := _get_player()
	if not player:
		return

	var projectile := Node2D.new()
	projectile.global_position = global_position + projectile_spawn_offset + Vector2(_last_facing_direction * 18.0, 0.0)

	var direction := projectile.global_position.direction_to(player.global_position + Vector2(0.0, -20.0))
	var fan_offset := (_spray_tick - (spray_count + 1) * 0.5) * 0.18
	direction = direction.rotated(fan_offset)

	var script := load("res://boss/projectile.gd") as GDScript
	projectile.set_script(script)
	projectile.speed = spray_speed
	projectile.lifetime = 4.0
	projectile.damage = 1
	projectile.hit_range = 22.0
	projectile.set_direction(direction)

	get_parent().add_child(projectile)


func _get_player() -> Player:
	if is_instance_valid(_target_player):
		return _target_player

	_target_player = get_tree().root.find_child("Player", true, false) as Player
	return _target_player
