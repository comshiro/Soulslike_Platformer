extends Node2D


const LIMIT_LEFT = -700
const LIMIT_TOP = -760
const LIMIT_RIGHT = 3250
const LIMIT_BOTTOM = 690
const ARENA_RESPAWN_FALL_MARGIN = 240.0
const ARENA_LOCK_LEFT_X = 1590.0
const ARENA_LOCK_RIGHT_X = 2530.0
const BOSS_LOCK_LEFT_X = 1605.0
const BOSS_LOCK_RIGHT_X = 2515.0

@onready var _boss_trigger := $RightExpansion/BossTrigger as Area2D
@onready var _boss_gate_collision := $RightExpansion/BossGate/CollisionShape2D as CollisionShape2D
@onready var _boss := $RightExpansion/ForestBoss as ForestBoss
@onready var _tilemap := $TileMap as TileMap
@onready var _arena_checkpoint := $RightExpansion/ArenaCheckpoint as Marker2D
@onready var _boss_banner := $ArenaUi/BossBanner as Label
@onready var _respawn_flash := $ArenaUi/RespawnFlash as ColorRect
@onready var _boss_hp_bar := $ArenaUi/BossHpBar as ProgressBar
@onready var _boss_hp_label := $ArenaUi/BossHpLabel as Label
@onready var _boss_gate_sfx := $RightExpansion/BossGateSfx as AudioStreamPlayer2D

var _boss_started := false


func _ready():
	for child in get_children():
		if child is Player:
			var camera = child.get_node("Camera")
			camera.limit_left = LIMIT_LEFT
			camera.limit_top = LIMIT_TOP
			camera.limit_right = LIMIT_RIGHT
			camera.limit_bottom = LIMIT_BOTTOM

	_boss_trigger.body_entered.connect(_on_boss_trigger_body_entered)
	_boss.defeated.connect(_on_boss_defeated)
	_boss.health_changed.connect(_on_boss_health_changed)
	_boss.set_active(false)
	_boss_gate_collision.disabled = true
	_boss_hp_bar.visible = false
	_boss_hp_label.visible = false
	_clear_tile_patch_around(Vector2(445, 197), 2, 1)


func _on_boss_trigger_body_entered(body: Node2D) -> void:
	if _boss_started or not body is Player:
		return
	_boss_started = true
	_play_boss_intro_feedback(body as Player)
	_boss_hp_bar.visible = true
	_boss_hp_label.visible = true
	# Invisible lock-in wall: activate gate collider once player enters arena.
	await get_tree().physics_frame
	_boss_gate_collision.disabled = false
	await get_tree().create_timer(2.0).timeout
	_boss.set_active(true)
	_boss_trigger.queue_free()


func _on_boss_defeated() -> void:
	_boss_gate_collision.disabled = true
	_boss_hp_bar.visible = false
	_boss_hp_label.visible = false


func _on_boss_health_changed(current: int, maximum: int) -> void:
	_boss_hp_bar.max_value = maximum
	_boss_hp_bar.value = current
	_boss_hp_label.text = "Boss HP: %d/%d" % [current, maximum]


func _physics_process(_delta: float) -> void:
	if not _boss_started or _boss_gate_collision.disabled:
		return

	if is_instance_valid(_boss):
		_boss.global_position.x = clampf(_boss.global_position.x, BOSS_LOCK_LEFT_X, BOSS_LOCK_RIGHT_X)

	for child in get_children():
		var player := child as Player
		if not player:
			continue

		# Hard lock inside arena during boss phase, even if player reaches high external platforms.
		player.global_position.x = clampf(player.global_position.x, ARENA_LOCK_LEFT_X, ARENA_LOCK_RIGHT_X)

		if player.global_position.y > LIMIT_BOTTOM + ARENA_RESPAWN_FALL_MARGIN:
			_respawn_player_at_arena_checkpoint(player)


func _play_boss_intro_feedback(player: Player) -> void:
	_boss_gate_sfx.play()

	_boss_banner.visible = true
	_boss_banner.modulate = Color(1, 1, 1, 0)
	_boss_banner.scale = Vector2(0.9, 0.9)
	var banner_tween := create_tween()
	banner_tween.tween_property(_boss_banner, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	banner_tween.parallel().tween_property(_boss_banner, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	banner_tween.tween_interval(0.65)
	banner_tween.tween_property(_boss_banner, "modulate:a", 0.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	banner_tween.tween_callback(_boss_banner.hide)

	var camera := player.get_node_or_null("Camera") as Camera2D
	if camera:
		var rest_offset := camera.offset
		var shake_tween := create_tween()
		shake_tween.tween_property(camera, "offset", rest_offset + Vector2(7, -2), 0.03)
		shake_tween.tween_property(camera, "offset", rest_offset + Vector2(-6, 2), 0.04)
		shake_tween.tween_property(camera, "offset", rest_offset + Vector2(4, -1), 0.03)
		shake_tween.tween_property(camera, "offset", rest_offset, 0.05)


func _respawn_player_at_arena_checkpoint(player: Player) -> void:
	player.global_position = _arena_checkpoint.global_position
	player.velocity = Vector2.ZERO
	_play_respawn_flash()


func _play_respawn_flash() -> void:
	_respawn_flash.visible = true
	_respawn_flash.color = Color(0.9, 0.98, 1.0, 0.0)
	var flash_tween := create_tween()
	flash_tween.tween_property(_respawn_flash, "color:a", 0.26, 0.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	flash_tween.tween_property(_respawn_flash, "color:a", 0.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	flash_tween.tween_callback(_respawn_flash.hide)


func _clear_tile_patch_around(world_pos: Vector2, half_width: int, half_height: int) -> void:
	if not _tilemap:
		return

	var center_cell := _tilemap.local_to_map(_tilemap.to_local(world_pos))
	for y in range(center_cell.y - half_height, center_cell.y + half_height + 1):
		for x in range(center_cell.x - half_width, center_cell.x + half_width + 1):
			_tilemap.set_cell(0, Vector2i(x, y), -1)
