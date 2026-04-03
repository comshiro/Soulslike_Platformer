class_name Player extends CharacterBody2D


signal coin_collected()
signal dash_unlocked_changed(unlocked: bool)
signal form_changed(form: int)
signal sword_unlocked_changed(unlocked: bool)
signal attack_charge_changed(charge: int)
signal hp_changed(current: int, maximum: int)


enum Form {
	GROUND,
	WIND,
	CLAW,
}

const WALK_SPEED = 300.0
const ACCELERATION_SPEED = WALK_SPEED * 6.0
const JUMP_VELOCITY = -725.0
## Maximum speed at which the player can fall.
const TERMINAL_VELOCITY = 700
const DASH_SPEED = 900.0
const DASH_DURATION = 0.14
const DASH_COOLDOWN = 0.45
const ROLL_SPEED = 650.0
const ROLL_DURATION = 0.1
const ROLL_COOLDOWN = 0.35
const MELEE_RANGE = 40.0
const MELEE_RADIUS = 24.0
const MELEE_COOLDOWN = 0.2
const WALL_JUMP_PUSH = 430.0
const MAX_ATTACK_CHARGE = 12
const CHARGED_WAVE_COST = MAX_ATTACK_CHARGE

## The player listens for input actions appended with this suffix.[br]
## Used to separate controls for multiple players in splitscreen.
@export var action_suffix := ""
@export var dash_unlocked := true
@export var claw_form_unlocked := true
@export var sword_unlocked := false
@export var max_hp := 5

var gravity: int = ProjectSettings.get("physics/2d/default_gravity")
@onready var platform_detector := $PlatformDetector as RayCast2D
@onready var animation_player := $AnimationPlayer as AnimationPlayer
@onready var shoot_timer := $ShootAnimation as Timer
@onready var sprite := $Sprite2D as Sprite2D
@onready var jump_sound := $Jump as AudioStreamPlayer2D
@onready var gun = sprite.get_node(^"Gun") as Gun
@onready var sword_in_hand := sprite.get_node(^"SwordInHand") as Sprite2D
@onready var charge_bar := $UI/ChargeBar as ProgressBar
@onready var hp_bar := $UI/HpBar as ProgressBar
@onready var hp_label := $UI/HpLabel as Label
@onready var camera := $Camera as Camera2D
var _double_jump_charged := false
var _dash_direction := 1.0
var _dash_time_left := 0.0
var _dash_cooldown_left := 0.0
var _is_dashing := false
var _dash_speed := DASH_SPEED
var _is_rolling := false
var _melee_cooldown_left := 0.0
var _current_form := Form.GROUND
var _attack_display_time_left := 0.0
var _attack_charge := 0
var _boss_hit_invuln_left := 0.0
var _hp := 0
var _spawn_position := Vector2.ZERO


func _physics_process(delta: float) -> void:
	_dash_cooldown_left = maxf(0.0, _dash_cooldown_left - delta)
	_melee_cooldown_left = maxf(0.0, _melee_cooldown_left - delta)
	_attack_display_time_left = maxf(0.0, _attack_display_time_left - delta)
	_boss_hit_invuln_left = maxf(0.0, _boss_hit_invuln_left - delta)
	sword_in_hand.visible = sword_unlocked

	if Input.is_action_just_pressed("switch_form" + action_suffix):
		switch_to_next_form()

	if _is_dashing:
		_dash_time_left -= delta
		velocity.y = 0.0
		velocity.x = _dash_direction * _dash_speed
		floor_stop_on_slope = false
		move_and_slide()
		if _dash_time_left <= 0.0:
			_is_dashing = false
			_is_rolling = false
		return

	if is_on_floor():
		_double_jump_charged = true

	if can_use_wind_form() and _dash_cooldown_left == 0.0 and Input.is_action_just_pressed("dash" + action_suffix):
		if is_on_floor():
			start_roll()
		else:
			start_dash()
		return

	if Input.is_action_just_pressed("jump" + action_suffix):
		try_jump()
	elif Input.is_action_just_released("jump" + action_suffix) and velocity.y < 0.0:
		# The player let go of jump early, reduce vertical momentum.
		velocity.y *= 0.6
	# Fall.
	velocity.y = minf(TERMINAL_VELOCITY, velocity.y + gravity * delta)

	var direction := Input.get_axis("move_left" + action_suffix, "move_right" + action_suffix) * WALK_SPEED
	velocity.x = move_toward(velocity.x, direction, ACCELERATION_SPEED * delta)

	if not is_zero_approx(velocity.x):
		if velocity.x > 0.0:
			sprite.scale.x = 1.0
		else:
			sprite.scale.x = -1.0

	floor_stop_on_slope = not platform_detector.is_colliding()
	move_and_slide()

	var is_attacking := false
	if sword_unlocked and Input.is_action_just_pressed("charge_attack" + action_suffix):
		if _attack_charge >= CHARGED_WAVE_COST:
			_attack_charge -= CHARGED_WAVE_COST
			attack_charge_changed.emit(_attack_charge)
			is_attacking = gun.shoot(sprite.scale.x, true)
	if sword_unlocked and Input.is_action_just_pressed("wave_attack" + action_suffix):
		is_attacking = gun.shoot(sprite.scale.x, false) or is_attacking
	if sword_unlocked and Input.is_action_just_pressed("shoot" + action_suffix):
		is_attacking = perform_melee_attack()
	if is_attacking:
		_attack_display_time_left = 0.16

	var animation := get_new_animation(is_attacking)
	if animation != animation_player.current_animation and shoot_timer.is_stopped():
		if is_attacking:
			shoot_timer.start()
		animation_player.play(animation)


func _ready() -> void:
	coin_collected.connect(_on_coin_collected)
	attack_charge_changed.connect(_on_attack_charge_changed)
	if dash_unlocked:
		_current_form = Form.WIND
	update_form_visual()
	sword_in_hand.visible = sword_unlocked
	_spawn_position = global_position
	_hp = max_hp
	hp_bar.max_value = max_hp
	hp_bar.value = _hp
	hp_changed.emit(_hp, max_hp)
	charge_bar.max_value = MAX_ATTACK_CHARGE
	charge_bar.value = _attack_charge
	attack_charge_changed.emit(_attack_charge)
	hp_changed.connect(_on_hp_changed)


func _on_coin_collected() -> void:
	_attack_charge = min(MAX_ATTACK_CHARGE, _attack_charge + 1)
	attack_charge_changed.emit(_attack_charge)


func _on_attack_charge_changed(charge: int) -> void:
	charge_bar.value = charge


func _on_hp_changed(current: int, maximum: int) -> void:
	hp_bar.max_value = maximum
	hp_bar.value = current
	hp_label.text = "HP: %d/%d" % [current, maximum]


func perform_melee_attack() -> bool:
	if _melee_cooldown_left > 0.0:
		return false

	_melee_cooldown_left = MELEE_COOLDOWN
	var attack_shape := CircleShape2D.new()
	attack_shape.radius = MELEE_RADIUS

	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = attack_shape
	params.transform = Transform2D(0.0, global_position + Vector2(MELEE_RANGE * sprite.scale.x, -8.0))
	params.collision_mask = 2
	params.exclude = [self]

	var results := get_world_2d().direct_space_state.intersect_shape(params, 8)
	for hit in results:
		var collider := hit.collider as Node
		var enemy := collider as Enemy
		if enemy:
			enemy.destroy()
		elif collider and collider.has_method("take_damage"):
			collider.call("take_damage", 1)

	return true


func boss_hit(hit_from_x: float) -> void:
	if _boss_hit_invuln_left > 0.0:
		return

	_boss_hit_invuln_left = 0.65
	_is_dashing = false
	_is_rolling = false

	var push_dir := signf(global_position.x - hit_from_x)
	if is_zero_approx(push_dir):
		push_dir = -signf(sprite.scale.x)
	if is_zero_approx(push_dir):
		push_dir = 1.0

	velocity.x = push_dir * 430.0
	velocity.y = -230.0
	_hp = max(0, _hp - 1)
	hp_changed.emit(_hp, max_hp)
	if _hp <= 0:
		_respawn_after_death()

	sprite.modulate = Color(1.0, 0.55, 0.55, 1.0)
	var hurt_tween := create_tween()
	hurt_tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.32)

	if camera:
		var rest_offset := camera.offset
		var shake := create_tween()
		shake.tween_property(camera, "offset", rest_offset + Vector2(8, -3), 0.03)
		shake.tween_property(camera, "offset", rest_offset + Vector2(-7, 3), 0.04)
		shake.tween_property(camera, "offset", rest_offset, 0.06)


func _respawn_after_death() -> void:
	_hp = max_hp
	hp_changed.emit(_hp, max_hp)
	var checkpoint := get_parent().get_node_or_null("RightExpansion/ArenaCheckpoint") as Marker2D
	if checkpoint:
		global_position = checkpoint.global_position
	else:
		global_position = _spawn_position
	velocity = Vector2.ZERO


func start_dash() -> void:
	_is_rolling = false
	_is_dashing = true
	_dash_speed = DASH_SPEED
	_dash_time_left = DASH_DURATION
	_dash_cooldown_left = DASH_COOLDOWN

	var direction := Input.get_axis("move_left" + action_suffix, "move_right" + action_suffix)
	if is_zero_approx(direction):
		_dash_direction = signf(sprite.scale.x)
	else:
		_dash_direction = signf(direction)

	if is_zero_approx(_dash_direction):
		_dash_direction = 1.0


func start_roll() -> void:
	_is_rolling = true
	_is_dashing = true
	_dash_speed = ROLL_SPEED
	_dash_time_left = ROLL_DURATION
	_dash_cooldown_left = ROLL_COOLDOWN

	var direction := Input.get_axis("move_left" + action_suffix, "move_right" + action_suffix)
	if is_zero_approx(direction):
		_dash_direction = signf(sprite.scale.x)
	else:
		_dash_direction = signf(direction)

	if is_zero_approx(_dash_direction):
		_dash_direction = 1.0


func unlock_dash() -> void:
	if dash_unlocked:
		return
	dash_unlocked = true
	unlock_form(Form.WIND)
	dash_unlocked_changed.emit(true)


func unlock_sword() -> void:
	if sword_unlocked:
		return
	sword_unlocked = true
	sword_unlocked_changed.emit(true)


func unlock_claw_form() -> void:
	if claw_form_unlocked:
		return
	claw_form_unlocked = true
	unlock_form(Form.CLAW)


func unlock_form(form: Form) -> void:
	if form == Form.WIND:
		dash_unlocked = true
	elif form == Form.CLAW:
		claw_form_unlocked = true
	set_form(form)


func switch_to_next_form() -> void:
	var forms := get_unlocked_forms()
	if forms.size() < 2:
		return
	var current_index := forms.find(_current_form)
	if current_index == -1:
		set_form(forms[0])
		return
	var next_index := (current_index + 1) % forms.size()
	set_form(forms[next_index])


func get_unlocked_forms() -> Array[Form]:
	var forms: Array[Form] = [Form.GROUND]
	if dash_unlocked:
		forms.append(Form.WIND)
	if claw_form_unlocked:
		forms.append(Form.CLAW)
	return forms


func set_form(form: Form) -> void:
	if _current_form == form:
		return
	_current_form = form
	update_form_visual()
	form_changed.emit(_current_form)


func update_form_visual() -> void:
	match _current_form:
		Form.GROUND:
			sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		Form.WIND:
			sprite.modulate = Color(0.75, 1.0, 1.0, 1.0)
		Form.CLAW:
			sprite.modulate = Color(1.0, 0.85, 0.7, 1.0)


func can_use_wind_form() -> bool:
	return _current_form == Form.WIND and dash_unlocked


func can_use_claw_form() -> bool:
	return _current_form == Form.CLAW and claw_form_unlocked


func get_new_animation(is_shooting := false) -> String:
	var animation_new: String
	if is_on_floor():
		if absf(velocity.x) > 0.1:
			animation_new = "run"
		else:
			animation_new = "idle"
	else:
		if velocity.y > 0.0:
			animation_new = "falling"
		else:
			animation_new = "jumping"
	if is_shooting:
		animation_new += "_weapon"
	return animation_new


func try_jump() -> void:
	if is_on_floor():
		jump_sound.pitch_scale = 1.0
	elif can_use_claw_form() and is_on_wall_only():
		velocity.x = get_wall_jump_direction() * WALL_JUMP_PUSH
		jump_sound.pitch_scale = 1.25
	elif _double_jump_charged:
		_double_jump_charged = false
		velocity.x *= 1.45
		jump_sound.pitch_scale = 1.5
	else:
		return
	velocity.y = JUMP_VELOCITY
	jump_sound.play()


func get_wall_jump_direction() -> float:
	var wall_normal := get_wall_normal()
	if not is_zero_approx(wall_normal.x):
		return wall_normal.x
	return -signf(sprite.scale.x)
