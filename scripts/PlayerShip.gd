extends Node2D
class_name PlayerShip

signal died

const ARENA_SIZE := Vector2(1280, 720)

var speed := 240.0
var max_health := 120.0
var health := 120.0
var radius := 26.0
var weapon_damage := 18.0
var weapon_range := 310.0
var fire_interval := 0.48
var bullet_speed := 600.0
var bullet_count := 1
var pierce := 0

var _fire_timer := 0.0
var _invulnerable_timer := 0.0

func _process(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	position += direction * speed * delta
	position.x = clamp(position.x, 60.0, ARENA_SIZE.x - 60.0)
	position.y = clamp(position.y, 80.0, ARENA_SIZE.y - 60.0)
	if direction.length_squared() > 0.01:
		rotation = lerp_angle(rotation, direction.angle(), 10.0 * delta)
	_fire_timer = maxf(0.0, _fire_timer - delta)
	_invulnerable_timer = maxf(0.0, _invulnerable_timer - delta)
	queue_redraw()

func can_fire() -> bool:
	return _fire_timer <= 0.0

func mark_fired() -> void:
	_fire_timer = fire_interval

func take_damage(amount: float) -> void:
	if _invulnerable_timer > 0.0:
		return
	health = maxf(0.0, health - amount)
	_invulnerable_timer = 0.25
	queue_redraw()
	if health <= 0.0:
		died.emit()

func heal(amount: float) -> void:
	health = minf(max_health, health + amount)
	queue_redraw()

func _draw() -> void:
	var blink := _invulnerable_timer > 0.0 and int(_invulnerable_timer * 30.0) % 2 == 0
	var hull := Color(0.25, 0.72, 1.0, 0.95)
	if blink:
		hull = Color(1.0, 1.0, 1.0, 0.85)
	draw_circle(Vector2.ZERO, 36.0, Color(0.16, 0.43, 0.68, 0.22))
	draw_polygon([
		Vector2(42, 0),
		Vector2(-22, -24),
		Vector2(-34, 0),
		Vector2(-22, 24)
	], [hull])
	draw_polyline([
		Vector2(37, 0),
		Vector2(-18, -19),
		Vector2(-28, 0),
		Vector2(-18, 19),
		Vector2(37, 0)
	], Color(0.94, 0.88, 0.58, 1.0), 3.0)
	draw_circle(Vector2(-4, 0), 11.0, Color(0.96, 0.75, 0.28, 1.0))
	draw_line(Vector2(-7, -29), Vector2(12, -5), Color(0.86, 0.95, 1.0, 0.85), 3.0)
	draw_line(Vector2(-7, 29), Vector2(12, 5), Color(0.86, 0.95, 1.0, 0.85), 3.0)
