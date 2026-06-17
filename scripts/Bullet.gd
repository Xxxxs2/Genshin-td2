extends Node2D
class_name Bullet

enum Owner { PLAYER, ENEMY }

var velocity := Vector2.ZERO
var damage := 10.0
var radius := 6.0
var bullet_owner := Owner.PLAYER
var pierce_left := 0
var lifetime := 2.5

func setup(start_position: Vector2, new_velocity: Vector2, new_damage: float, new_owner: Owner, new_radius: float = 6.0, new_pierce: int = 0) -> void:
	position = start_position
	velocity = new_velocity
	damage = new_damage
	bullet_owner = new_owner
	radius = new_radius
	pierce_left = new_pierce

func _process(delta: float) -> void:
	position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
	queue_redraw()

func consume_hit() -> bool:
	if pierce_left > 0:
		pierce_left -= 1
		return false
	return true

func _draw() -> void:
	if bullet_owner == Owner.PLAYER:
		draw_circle(Vector2.ZERO, radius + 5.0, Color(0.25, 0.79, 1.0, 0.18))
		draw_circle(Vector2.ZERO, radius, Color(0.78, 0.96, 1.0, 1.0))
	else:
		draw_circle(Vector2.ZERO, radius + 6.0, Color(0.95, 0.28, 0.62, 0.18))
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.35, 0.56, 1.0))
