extends Node2D
class_name Island

var radius := 86.0
var label := ""

func setup(spawn_position: Vector2, new_radius: float, new_label: String = "") -> void:
	position = spawn_position
	radius = new_radius
	label = new_label

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius + 18.0, Color(0.17, 0.73, 0.78, 0.14))
	draw_circle(Vector2.ZERO, radius, Color(0.25, 0.55, 0.42, 1.0))
	draw_circle(Vector2(-radius * 0.26, -radius * 0.14), radius * 0.48, Color(0.34, 0.68, 0.48, 0.94))
	draw_circle(Vector2(radius * 0.22, radius * 0.1), radius * 0.34, Color(0.72, 0.66, 0.4, 0.9))
	draw_arc(Vector2.ZERO, radius + 4.0, 0.0, TAU, 96, Color(0.91, 0.86, 0.62, 0.8), 4.0)
	draw_circle(Vector2(radius * 0.2, -radius * 0.32), radius * 0.08, Color(0.92, 0.98, 0.74, 0.78))
