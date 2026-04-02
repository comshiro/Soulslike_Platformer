extends Node2D


const LIMIT_LEFT = -315
const LIMIT_TOP = -250
const LIMIT_RIGHT = 2620
const LIMIT_BOTTOM = 690

@onready var _boss_trigger := $RightExpansion/BossTrigger as Area2D
@onready var _boss_gate_collision := $RightExpansion/BossGate/CollisionShape2D as CollisionShape2D
@onready var _boss := $RightExpansion/ForestBoss as ForestBoss
@onready var _boss_banner := $ArenaUi/BossBanner as Label
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
	_boss_gate_collision.disabled = true


func _on_boss_trigger_body_entered(body: Node2D) -> void:
	if _boss_started or not body is Player:
		return
	_boss_started = true
	_play_boss_intro_feedback(body as Player)
	# Close the gate after the player is inside the arena checkpoint.
	await get_tree().physics_frame
	_boss_gate_collision.disabled = false
	_boss_trigger.queue_free()


func _on_boss_defeated() -> void:
	_boss_gate_collision.disabled = true


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
