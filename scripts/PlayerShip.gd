extends Node2D
class_name PlayerShip

signal died

var forward_speed := 180.0
var boost_multiplier := 1.7
var forward_acceleration := 320.0
var turn_speed := 3.8
var navigation_bounds := Rect2(Vector2(50, 50), Vector2(1180, 3500))
var movement_enabled := true
var max_health := 120.0
var health := 120.0
var radius := 26.0
var weapon_damage := 18.0
var weapon_range := 310.0
var fire_interval := 0.48
var bullet_speed := 600.0
var bullet_count := 1
var pierce := 0
var side_damage := 11.0
var side_range := 245.0
var side_fire_interval := 1.05
var mine_damage := 0.0
var mine_radius := 96.0
var mine_interval := 1.65
var max_shield_charges := 0
var shield_charges := 0
var shield_recharge_interval := 7.5
var aura_damage := 0.0
var aura_radius := 118.0

var _fire_timer := 0.0
var _side_fire_timer := 0.0
var _mine_timer := 0.0
var _invulnerable_timer := 0.0
var _shield_timer := 0.0
var _current_forward_speed := 180.0
var _steering_direction := Vector2.UP
var _is_boosting := false

func _process(delta: float) -> void:
	if movement_enabled:
		var direction_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if direction_input.length_squared() > 0.01:
			_steering_direction = direction_input.normalized()
			var target_rotation := _steering_direction.angle() + PI * 0.5
			rotation = lerp_angle(rotation, target_rotation, turn_speed * delta)
		_is_boosting = Input.is_action_pressed("boost")
		var target_forward_speed := forward_speed * (boost_multiplier if _is_boosting else 1.0)
		_current_forward_speed = move_toward(_current_forward_speed, target_forward_speed, forward_acceleration * delta)
		position += forward_vector() * _current_forward_speed * delta
		position.x = clamp(position.x, navigation_bounds.position.x, navigation_bounds.end.x)
		position.y = clamp(position.y, navigation_bounds.position.y, navigation_bounds.end.y)
	else:
		_is_boosting = false
	_fire_timer = maxf(0.0, _fire_timer - delta)
	_side_fire_timer = maxf(0.0, _side_fire_timer - delta)
	_mine_timer = maxf(0.0, _mine_timer - delta)
	_invulnerable_timer = maxf(0.0, _invulnerable_timer - delta)
	if max_shield_charges > 0 and shield_charges < max_shield_charges:
		_shield_timer -= delta
		if _shield_timer <= 0.0:
			shield_charges += 1
			_shield_timer = shield_recharge_interval
	queue_redraw()

func can_fire() -> bool:
	return _fire_timer <= 0.0

func mark_fired() -> void:
	_fire_timer = fire_interval

func can_side_fire() -> bool:
	return _side_fire_timer <= 0.0

func mark_side_fired() -> void:
	_side_fire_timer = side_fire_interval

func can_drop_mine() -> bool:
	return mine_damage > 0.0 and _mine_timer <= 0.0

func mark_mine_dropped() -> void:
	_mine_timer = mine_interval

func forward_vector() -> Vector2:
	return Vector2.UP.rotated(rotation)

func current_forward_speed() -> float:
	return _current_forward_speed

func is_boosting() -> bool:
	return _is_boosting

func reset_navigation_state() -> void:
	_current_forward_speed = forward_speed
	_steering_direction = Vector2.UP
	_is_boosting = false
	rotation = 0.0

func take_damage(amount: float) -> void:
	if _invulnerable_timer > 0.0:
		return
	if shield_charges > 0:
		shield_charges -= 1
		_invulnerable_timer = 0.2
		queue_redraw()
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
	if aura_damage > 0.0:
		draw_arc(Vector2.ZERO, aura_radius, 0.0, TAU, 96, Color(0.55, 0.92, 1.0, 0.18), 3.0)
	if shield_charges > 0:
		draw_arc(Vector2.ZERO, 47.0, -PI * 0.75, PI * 0.75, 48, Color(0.55, 0.88, 1.0, 0.76), 4.0)
	draw_circle(Vector2.ZERO, 36.0, Color(0.16, 0.43, 0.68, 0.22))
	draw_polygon([
		Vector2(0, -42),
		Vector2(-24, 22),
		Vector2(0, 34),
		Vector2(24, 22)
	], [hull])
	draw_polyline([
		Vector2(0, -37),
		Vector2(-19, 18),
		Vector2(0, 28),
		Vector2(19, 18),
		Vector2(0, -37)
	], Color(0.94, 0.88, 0.58, 1.0), 3.0)
	draw_circle(Vector2(0, 2), 11.0, Color(0.96, 0.75, 0.28, 1.0))
	draw_line(Vector2(-29, 7), Vector2(-5, -12), Color(0.86, 0.95, 1.0, 0.85), 3.0)
	draw_line(Vector2(29, 7), Vector2(5, -12), Color(0.86, 0.95, 1.0, 0.85), 3.0)
	draw_circle(Vector2(-29, 5), 5.0, Color(1.0, 0.82, 0.42, 0.95))
	draw_circle(Vector2(29, 5), 5.0, Color(1.0, 0.82, 0.42, 0.95))
	var wake_length := 32.0 + (_current_forward_speed / maxf(1.0, forward_speed) - 1.0) * 30.0
	var wake_color := Color(0.56, 0.94, 1.0, 0.78 if _is_boosting else 0.42)
	draw_line(Vector2(-12, 28), Vector2(-18, 28 + wake_length), wake_color, 4.0)
	draw_line(Vector2(12, 28), Vector2(18, 28 + wake_length), wake_color, 4.0)
