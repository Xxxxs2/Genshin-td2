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
var attack_type := "aimed"
var is_elite := false

var _lock_progress := 0.0
var _fire_timer := 0.35
var _is_locking := false
var _aim_point := Vector2.ZERO

func setup(spawn_position: Vector2, level: int, new_attack_type: String = "aimed", elite: bool = false) -> void:
	position = spawn_position
	attack_type = new_attack_type
	is_elite = elite
	max_health = 56.0 + level * 18.0
	health = max_health
	attack_range = 245.0 + level * 12.0
	fire_interval = maxf(0.72, 1.45 - level * 0.06)
	bullet_speed = 300.0 + level * 12.0
	bullet_damage = 9.0 + level * 2.1
	if attack_type == "sniper":
		attack_range += 110.0
		lock_time = 1.35
		fire_interval += 0.45
		bullet_speed *= 1.55
		bullet_damage *= 1.35
	elif attack_type == "spread":
		attack_range -= 25.0
		lock_time = 0.55
		bullet_damage *= 0.62
	if is_elite:
		max_health *= 3.4
		health = max_health
		radius = 27.0
		attack_range += 80.0
		fire_interval *= 0.78
		bullet_damage *= 1.2
	_lock_progress = 0.0
	_fire_timer = randf_range(0.2, 0.8)

func tick(delta: float, player: Node2D, bullet_speed_factor: float = 1.0) -> Array:
	var created: Array = []
	var to_player: Vector2 = player.position - position
	var distance := to_player.length()
	_aim_point = player.position
	_is_locking = distance <= attack_range
	if _is_locking:
		_lock_progress = minf(lock_time, _lock_progress + delta)
		_fire_timer -= delta
		rotation = lerp_angle(rotation, to_player.angle() + PI * 0.5, 10.0 * delta)
		if _lock_progress >= lock_time and _fire_timer <= 0.0:
			_fire_timer = fire_interval
			var direction := to_player.normalized()
			var shot_count := 1
			var spread_step := 0.0
			if attack_type == "spread":
				shot_count = 5
				spread_step = deg_to_rad(12.0)
			elif is_elite:
				shot_count = 3
				spread_step = deg_to_rad(9.0)
			var start_offset := -spread_step * float(shot_count - 1) * 0.5
			for i in range(shot_count):
				var shot_direction := direction.rotated(start_offset + spread_step * i)
				var bullet := BulletScript.new()
				var shot_radius := 7.0 if attack_type == "spread" else 8.0
				bullet.setup(position + shot_direction * 25.0, shot_direction * bullet_speed * bullet_speed_factor, bullet_damage, 1, shot_radius, 0)
				created.append(bullet)
			_lock_progress = 0.0
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
	var glow := Color(0.98, 0.54, 0.25, 0.18)
	var body := Color(0.58, 0.28, 0.24, 1.0)
	if attack_type == "sniper":
		glow = Color(0.9, 0.28, 0.72, 0.2)
		body = Color(0.48, 0.22, 0.46, 1.0)
	elif attack_type == "spread":
		glow = Color(1.0, 0.72, 0.2, 0.2)
		body = Color(0.62, 0.4, 0.18, 1.0)
	if is_elite:
		glow = Color(1.0, 0.2, 0.32, 0.3)
		body = Color(0.38, 0.16, 0.24, 1.0)
	draw_circle(Vector2.ZERO, radius + 10.0, glow)
	draw_circle(Vector2.ZERO, radius, body)
	draw_rect(Rect2(Vector2(-5, -radius - 12), Vector2(10, 25)), Color(0.94, 0.74, 0.38, 1.0))
	draw_circle(Vector2.ZERO, radius * 0.38, Color(1.0, 0.82, 0.48, 1.0))
	if _is_locking:
		var progress := 0.0
		if lock_time > 0.0:
			progress = _lock_progress / lock_time
		var warning_color := Color(1.0, 0.24, 0.22, 0.28 + progress * 0.65)
		draw_dashed_line(Vector2.ZERO, to_local(_aim_point), warning_color, 3.0, 14.0)
		draw_arc(Vector2.ZERO, radius + 13.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, Color(1.0, 0.24, 0.22, 0.95), 4.0)
	draw_arc(Vector2.ZERO, radius + 4.0, 0.0, TAU * (health / max_health), 32, Color(0.95, 0.88, 0.52, 0.95), 3.0)
	if is_elite:
		draw_arc(Vector2.ZERO, radius + 17.0, 0.0, TAU, 48, Color(1.0, 0.78, 0.28, 0.85), 4.0)
