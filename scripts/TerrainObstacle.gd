extends Node2D
class_name TerrainObstacle

var radius := 42.0
var drift_speed := 62.0
var damage := 10.0
var wobble_phase := 0.0
var wobble_amount := 18.0
var base_x := 0.0

func setup(spawn_position: Vector2, new_radius: float, new_speed: float, new_damage: float) -> void:
	position = spawn_position
	base_x = spawn_position.x
	radius = new_radius
	drift_speed = new_speed
	damage = new_damage
	wobble_phase = randf() * TAU
	wobble_amount = randf_range(8.0, 26.0)

func _process(delta: float) -> void:
	position.y += drift_speed * delta
	position.x = base_x + sin(Time.get_ticks_msec() * 0.0013 + wobble_phase) * wobble_amount
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius + 11.0, Color(0.24, 0.72, 0.9, 0.13))
	draw_polygon([
		Vector2(0, -radius),
		Vector2(radius * 0.72, -radius * 0.34),
		Vector2(radius * 0.58, radius * 0.54),
		Vector2(-radius * 0.15, radius * 0.86),
		Vector2(-radius * 0.78, radius * 0.28),
		Vector2(-radius * 0.58, -radius * 0.55)
	], [Color(0.17, 0.34, 0.47, 0.92)])
	draw_polyline([
		Vector2(0, -radius),
		Vector2(radius * 0.72, -radius * 0.34),
		Vector2(radius * 0.58, radius * 0.54),
		Vector2(-radius * 0.15, radius * 0.86),
		Vector2(-radius * 0.78, radius * 0.28),
		Vector2(-radius * 0.58, -radius * 0.55),
		Vector2(0, -radius)
	], Color(0.83, 0.91, 0.96, 0.66), 2.5)
	draw_circle(Vector2(radius * 0.24, -radius * 0.18), radius * 0.13, Color(0.74, 0.93, 1.0, 0.58))
