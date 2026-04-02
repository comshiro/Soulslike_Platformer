extends Node2D


const LIMIT_LEFT = -315
const LIMIT_TOP = -250
const LIMIT_RIGHT = 2620
const LIMIT_BOTTOM = 690

@onready var _boss_trigger := $RightExpansion/BossTrigger as Area2D
@onready var _boss_gate_collision := $RightExpansion/BossGate/CollisionShape2D as CollisionShape2D
@onready var _boss := $RightExpansion/ForestBoss as ForestBoss

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
	# Close the gate after the player is inside the arena checkpoint.
	await get_tree().physics_frame
	_boss_gate_collision.disabled = false
	_boss_trigger.queue_free()


func _on_boss_defeated() -> void:
	_boss_gate_collision.disabled = true
