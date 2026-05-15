extends CharacterBody2D

const SPEED = 150.0
const DETECTION_RANGE = 250.0
const COOLDOWN_TIME = 2.0
const WINDUP_TIME = 0.22
const LEAP_SPEED_X = 260.0
const LEAP_SPEED_Y = -360.0
const GRAVITY = 900.0
const FRAMES_PER_ROW = 5
const FLOOR_CHECK_X = 20.0
const FLOOR_CHECK_Y = 24.0

@onready var sprite := $Sprite2D as Sprite2D
@onready var collision := $CollisionShape2D as CollisionShape2D
@onready var floor_detector := $FloorDetector as RayCast2D

var player: Node2D = null
var facing_right := true
var state := "patrol"  # patrol, windup, jumping, cooldown
var windup_timer := 0.0
var cooldown_timer := 0.0
var velocity_x := 0.0
var _sprite_base_scale := Vector2.ONE
var _anim_frame := 0
var _anim_timer := 0.0

func _ready() -> void:
	player = get_tree().root.find_child("Player", true, false)
	if sprite:
		_sprite_base_scale = sprite.scale
		sprite.frame = 0
	_update_floor_detector()

func _physics_process(delta: float) -> void:
	# Update player reference
	if not is_instance_valid(player):
		player = get_tree().root.find_child("Player", true, false)

	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	# State machine
	match state:
		"patrol":
			_patrol(delta)
		"windup":
			_windup(delta)
		"jumping":
			_jumping(delta)
		"cooldown":
			_cooldown(delta)

	_update_animation(delta)

	velocity.x = velocity_x
	move_and_slide()

func _patrol(delta: float) -> void:
	velocity_x = SPEED * (1.0 if facing_right else -1.0)

	if is_on_floor() and floor_detector and not floor_detector.is_colliding():
		_update_facing(!facing_right)
		velocity_x = 0.0
		return

	# Check for player in range
	if player and is_instance_valid(player):
		var dist_to_player = abs(player.global_position.x - global_position.x)
		if dist_to_player < DETECTION_RANGE:
			# Windup before the leap attack.
			state = "windup"
			windup_timer = WINDUP_TIME
			velocity_x = 0.0
			_update_facing(player.global_position.x > global_position.x)
			return

	# Basic patrol: reverse at edge (simple)
	if randf() < 0.01:  # Occasional direction change
		_update_facing(!facing_right)

func _windup(delta: float) -> void:
	velocity_x = 0.0
	windup_timer -= delta
	if windup_timer <= 0.0:
		state = "jumping"
		velocity_x = LEAP_SPEED_X * (1.0 if facing_right else -1.0)
		velocity.y = LEAP_SPEED_Y


func _jumping(_delta: float) -> void:
	# Keep horizontal momentum while in air.
	velocity_x = LEAP_SPEED_X * (1.0 if facing_right else -1.0)

	# Landed after leap -> cooldown.
	if is_on_floor() and velocity.y >= 0.0:
		state = "cooldown"
		cooldown_timer = COOLDOWN_TIME
		velocity_x = 0.0

func _cooldown(delta: float) -> void:
	cooldown_timer -= delta
	velocity_x = 0.0

	if cooldown_timer <= 0.0:
		state = "patrol"


func _update_animation(delta: float) -> void:
	if not sprite:
		return

	var row := 0
	var fps := 8.0

	match state:
		"patrol":
			row = 0
			fps = 7.0
		"windup":
			row = 1
			fps = 4.0
		"jumping":
			row = 1
			fps = 12.0
		"cooldown":
			row = 2
			fps = 5.0

	_anim_timer += delta
	if _anim_timer >= 1.0 / fps:
		_anim_timer = 0.0
		_anim_frame = (_anim_frame + 1) % FRAMES_PER_ROW

	sprite.frame = row * FRAMES_PER_ROW + _anim_frame

func _update_facing(target_right: bool) -> void:
	if facing_right != target_right:
		facing_right = target_right
		if sprite:
			sprite.scale = Vector2(-_sprite_base_scale.x, _sprite_base_scale.y) if facing_right else _sprite_base_scale
	_update_floor_detector()


func _update_floor_detector() -> void:
	if not floor_detector:
		return
	var dir := 1.0 if facing_right else -1.0
	floor_detector.position = Vector2(FLOOR_CHECK_X * dir, 2.0)
	floor_detector.target_position = Vector2(0.0, FLOOR_CHECK_Y)

func take_damage(_amount: int = 1) -> void:
	queue_free()
