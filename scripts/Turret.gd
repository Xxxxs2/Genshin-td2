extends Node2D
class_name Turret

signal destroyed(turret)

const BulletScript := preload("res://scripts/Bullet.gd")

var max_health := 70.0
var health := 70.0
var radius := 18.0
var attack_range := 275.0
var lock_time := 0.75
var fire_interval := 1.35
var bullet_speed := 330.0
var bullet_damage := 13.0

var _lock_progress := 0.0
var _fire_timer := 0.35
var _is_locking := false

func setup(spawn_position: Vector2, level: int) -> void:
	position = spawn_position
	max_health = 56.0 + level * 18.0
	health = max_health
	attack_range = 245.0 + level * 12.0
	fire_interval = maxf(0.72, 1.45 - level * 0.06)
	bullet_speed = 300.0 + level * 12.0
	bullet_damage = 9.0 + level * 2.1
	_lock_progress = 0.0
	_fire_timer = randf_range(0.2, 0.8)

func tick(delta: float, player: Node2D, bullet_speed_factor: float = 1.0) -> Array:
	var created: Array = []
	var to_player: Vector2 = player.position - position
	var distance := to_player.length()
	_is_locking = distance <= attack_range
	if _is_locking:
		_lock_progress = minf(lock_time, _lock_progress + delta)
		_fire_timer -= delta
		rotation = lerp_angle(rotation, to_player.angle() + PI * 0.5, 10.0 * delta)
		if _lock_progress >= lock_time and _fire_timer <= 0.0:
			_fire_timer = fire_interval
			var direction := to_player.normalized()
			var bullet := BulletScript.new()
			bullet.setup(position + direction * 25.0, direction * bullet_speed * bullet_speed_factor, bullet_damage, 1, 8.0, 0)
			created.append(bullet)
	else:
		_lock_progress = maxf(0.0, _lock_progress - delta * 1.4)
	queue_redraw()
	return created

func take_damage(amount: float) -> void:
	health -= amount
	queue_redraw()
	if health <= 0.0:
		destroyed.emit(self)
		queue_free()

func _draw() -> void:
	draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 96, Color(1.0, 0.42, 0.36, 0.10), 2.0)
	draw_circle(Vector2.ZERO, radius + 7.0, Color(0.98, 0.54, 0.25, 0.18))
	draw_circle(Vector2.ZERO, radius, Color(0.58, 0.28, 0.24, 1.0))
	draw_rect(Rect2(Vector2(-5, -radius - 12), Vector2(10, 25)), Color(0.94, 0.74, 0.38, 1.0))
	draw_circle(Vector2.ZERO, radius * 0.38, Color(1.0, 0.82, 0.48, 1.0))
	if _is_locking:
		var progress := 0.0
		if lock_time > 0.0:
			progress = _lock_progress / lock_time
		draw_arc(Vector2.ZERO, radius + 13.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, Color(1.0, 0.24, 0.22, 0.95), 4.0)
	draw_arc(Vector2.ZERO, radius + 4.0, 0.0, TAU * (health / max_health), 32, Color(0.95, 0.88, 0.52, 0.95), 3.0)
