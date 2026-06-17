extends Node2D
class_name Enemy

signal killed(enemy)

const BulletScript := preload("res://scripts/Bullet.gd")

var max_health := 60.0
var health := 60.0
var speed := 95.0
var radius := 22.0
var preferred_range := 250.0
var fire_interval := 1.45
var bullet_speed := 250.0
var bullet_damage := 11.0
var drift_speed := 70.0

var _fire_timer := 0.0
var _phase := 0.0

func setup(level: int, spawn_position: Vector2) -> void:
	position = spawn_position
	max_health = 42.0 + level * 16.0
	health = max_health
	speed = 72.0 + level * 5.0
	drift_speed = 52.0 + level * 4.5
	fire_interval = maxf(0.62, 1.65 - level * 0.08)
	bullet_speed = 220.0 + level * 9.0
	bullet_damage = 8.0 + level * 1.8
	_phase = randf() * TAU
	_fire_timer = randf_range(0.25, fire_interval)

func tick(delta: float, player: Node2D) -> Array:
	var created: Array = []
	var to_player := player.position - position
	var distance := maxf(1.0, to_player.length())
	var direction := to_player / distance
	var tangent := Vector2(-direction.y, direction.x) * sin(Time.get_ticks_msec() * 0.0015 + _phase)
	var desired := Vector2.DOWN * 0.82 + tangent * 0.42
	if distance < preferred_range - 42.0:
		desired -= direction * 0.38
	if desired.length_squared() > 0.01:
		position += desired.normalized() * drift_speed * delta
		rotation = lerp_angle(rotation, direction.angle(), 8.0 * delta)
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = fire_interval
		var bullet := BulletScript.new()
		bullet.setup(position + direction * 24.0, direction * bullet_speed, bullet_damage, 1, 7.5, 0)
		created.append(bullet)
	queue_redraw()
	return created

func take_damage(amount: float) -> void:
	health -= amount
	queue_redraw()
	if health <= 0.0:
		killed.emit(self)
		queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius + 8.0, Color(0.8, 0.18, 0.44, 0.16))
	draw_circle(Vector2.ZERO, radius, Color(0.72, 0.2, 0.45, 0.95))
	draw_circle(Vector2(8, 0), 7.0, Color(1.0, 0.77, 0.5, 1.0))
	draw_arc(Vector2.ZERO, radius + 4.0, 0.0, TAU * (health / max_health), 32, Color(1.0, 0.86, 0.44, 0.9), 3.0)
