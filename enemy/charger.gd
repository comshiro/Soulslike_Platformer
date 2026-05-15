extends CharacterBody2D

const SPEED = 150.0
const CHARGE_SPEED = 350.0
const CHARGE_DISTANCE = 200.0
const DETECTION_RANGE = 250.0
const COOLDOWN_TIME = 2.0
const ACCELERATION = 1200.0

@onready var sprite := $Sprite2D as Sprite2D
@onready var animation := $AnimationPlayer as AnimationPlayer
@onready var collision := $CollisionShape2D as CollisionShape2D

var player: Node2D = null
var facing_right := true
var state := "patrol"  # patrol, charging, cooldown
var charge_target_x := 0.0
var cooldown_timer := 0.0
var velocity_x := 0.0

func _ready() -> void:
	player = get_tree().root.find_child("Player", true, false)
	if animation:
		animation.play("walk")

func _physics_process(delta: float) -> void:
	# Update player reference
	if not is_instance_valid(player):
		player = get_tree().root.find_child("Player", true, false)

	# Gravity
	if not is_on_floor():
		velocity.y += 500.0 * delta
	else:
		velocity.y = 0.0

	# State machine
	match state:
		"patrol":
			_patrol(delta)
		"charging":
			_charging(delta)
		"cooldown":
			_cooldown(delta)

	velocity.x = velocity_x
	move_and_slide()

func _patrol(delta: float) -> void:
	velocity_x = SPEED * (1.0 if facing_right else -1.0)

	# Check for player in range
	if player and is_instance_valid(player):
		var dist_to_player = abs(player.global_position.x - global_position.x)
		if dist_to_player < DETECTION_RANGE:
			# Start charging toward player
			state = "charging"
			charge_target_x = player.global_position.x
			velocity_x = 0.0
			_update_facing(player.global_position.x > global_position.x)
			return

	# Basic patrol: reverse at edge (simple)
	if randf() < 0.01:  # Occasional direction change
		facing_right = !facing_right

func _charging(delta: float) -> void:
	velocity_x = CHARGE_SPEED * (1.0 if facing_right else -1.0)

	# Check if we've reached target or overshot
	if facing_right and global_position.x >= charge_target_x:
		state = "cooldown"
		cooldown_timer = COOLDOWN_TIME
		velocity_x = 0.0
		return
	elif not facing_right and global_position.x <= charge_target_x:
		state = "cooldown"
		cooldown_timer = COOLDOWN_TIME
		velocity_x = 0.0
		return

	# Safety: stop if charged too far
	if abs(global_position.x - charge_target_x) > CHARGE_DISTANCE * 1.5:
		state = "cooldown"
		cooldown_timer = COOLDOWN_TIME
		velocity_x = 0.0

func _cooldown(delta: float) -> void:
	cooldown_timer -= delta
	velocity_x = 0.0

	if cooldown_timer <= 0.0:
		state = "patrol"

func _update_facing(target_right: bool) -> void:
	if facing_right != target_right:
		facing_right = target_right
		if sprite:
			sprite.scale.x = -1.0 if facing_right else 1.0

func take_damage(_amount: int = 1) -> void:
	queue_free()
