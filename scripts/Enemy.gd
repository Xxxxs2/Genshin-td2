extends Node2D
class_name Enemy

signal killed(enemy)

const BulletScript := preload("res://scripts/Bullet.gd")

var enemy_type := "boat"
var max_health := 60.0
var health := 60.0
var speed := 95.0
var radius := 22.0
var preferred_range := 250.0
var fire_interval := 1.45
var bullet_speed := 250.0
var bullet_damage := 11.0
var contact_damage := 14.0
var room_bounds := Rect2(Vector2(80, 90), Vector2(1120, 540))
var is_boss := false

var _fire_timer := 0.0
var _phase := 0.0
var _charge_timer := 1.4

func setup(level: int, spawn_position: Vector2, new_type: String = "boat", boss: bool = false) -> void:
	position = spawn_position
	enemy_type = new_type
	is_boss = boss
	max_health = 38.0 + level * 13.0
	speed = 72.0 + level * 4.0
	fire_interval = maxf(0.68, 1.7 - level * 0.06)
	bullet_speed = 220.0 + level * 9.0
	bullet_damage = 7.0 + level * 1.5
	contact_damage = 10.0 + level * 1.7
	if enemy_type == "monster":
		max_health *= 1.18
		speed *= 1.25
		radius = 25.0
		preferred_range = 70.0
	elif enemy_type == "skirmisher":
		max_health *= 0.82
		speed *= 1.1
		fire_interval *= 0.72
		radius = 19.0
		preferred_range = 300.0
	if is_boss:
		max_health *= 5.2
		speed *= 0.8
		radius = 48.0
		fire_interval *= 0.72
		bullet_damage *= 1.25
	health = max_health
	_phase = randf() * TAU
	_fire_timer = randf_range(0.2, fire_interval)
	_charge_timer = randf_range(0.8, 1.8)

func tick(delta: float, player: Node2D) -> Array:
	var created: Array = []
	var to_player: Vector2 = player.position - position
	var distance := maxf(1.0, to_player.length())
	var direction := to_player / distance
	if enemy_type == "monster":
		_tick_monster(delta, direction, distance)
	else:
		_tick_boat(delta, direction, distance)
		_fire_timer -= delta
		if _fire_timer <= 0.0:
			_fire_timer = fire_interval
			var shot_count := 5 if is_boss else 1
			var spread := deg_to_rad(14.0 if is_boss else 0.0)
			var start_offset := -spread * float(shot_count - 1) * 0.5
			for i in range(shot_count):
				var shot_direction := direction.rotated(start_offset + spread * i)
				var bullet := BulletScript.new()
				bullet.setup(position + shot_direction * (radius + 8.0), shot_direction * bullet_speed, bullet_damage, 1, 8.0, 0)
				created.append(bullet)
	position.x = clamp(position.x, room_bounds.position.x, room_bounds.end.x)
	position.y = clamp(position.y, room_bounds.position.y, room_bounds.end.y)
	queue_redraw()
	return created

func _tick_boat(delta: float, direction: Vector2, distance: float) -> void:
	var tangent := Vector2(-direction.y, direction.x)
	var drift := tangent * sin(Time.get_ticks_msec() * 0.0018 + _phase)
	var desired := drift
	if distance > preferred_range + 55.0:
		desired += direction
	elif distance < preferred_range - 55.0:
		desired -= direction
	if desired.length_squared() > 0.01:
		position += desired.normalized() * speed * delta
		rotation = lerp_angle(rotation, direction.angle() + PI * 0.5, 5.0 * delta)

func _tick_monster(delta: float, direction: Vector2, distance: float) -> void:
	_charge_timer -= delta
	var move_speed := speed
	if _charge_timer <= 0.0:
		move_speed *= 2.15
		if _charge_timer <= -0.42:
			_charge_timer = randf_range(1.0, 1.8)
	var orbit := Vector2(-direction.y, direction.x) * sin(Time.get_ticks_msec() * 0.0024 + _phase) * 0.35
	var desired := direction + orbit
	if distance < 48.0:
		desired = -direction
	position += desired.normalized() * move_speed * delta
	rotation = lerp_angle(rotation, direction.angle() + PI * 0.5, 8.0 * delta)

func take_damage(amount: float) -> void:
	health -= amount
	queue_redraw()
	if health <= 0.0:
		killed.emit(self)
		queue_free()

func _draw() -> void:
	if enemy_type == "monster":
		var monster_color := Color(0.34, 0.76, 0.58, 0.96)
		if is_boss:
			monster_color = Color(0.46, 0.18, 0.54, 0.98)
		draw_circle(Vector2.ZERO, radius + 9.0, Color(monster_color, 0.16))
		draw_circle(Vector2.ZERO, radius, monster_color)
		for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
			draw_circle(Vector2.from_angle(angle) * radius * 0.78, radius * 0.34, Color(monster_color, 0.9))
		draw_circle(Vector2(-8, -5), 5.0, Color(0.95, 0.96, 0.68))
		draw_circle(Vector2(8, -5), 5.0, Color(0.95, 0.96, 0.68))
	else:
		var hull := Color(0.78, 0.24, 0.42, 0.96)
		if enemy_type == "skirmisher":
			hull = Color(0.93, 0.56, 0.22, 0.96)
		if is_boss:
			hull = Color(0.56, 0.16, 0.32, 1.0)
		draw_circle(Vector2.ZERO, radius + 8.0, Color(hull, 0.16))
		draw_polygon([
			Vector2(0, -radius - 10),
			Vector2(-radius, radius * 0.7),
			Vector2(0, radius),
			Vector2(radius, radius * 0.7)
		], [hull])
		draw_circle(Vector2.ZERO, radius * 0.38, Color(1.0, 0.75, 0.38))
	draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU * (health / max_health), 40, Color(1.0, 0.88, 0.46, 0.95), 3.0)
	if is_boss:
		draw_arc(Vector2.ZERO, radius + 14.0, 0.0, TAU, 64, Color(1.0, 0.32, 0.48, 0.8), 4.0)
