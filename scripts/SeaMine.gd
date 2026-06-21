extends Node2D
class_name SeaMine

var damage := 34.0
var blast_radius := 96.0
var trigger_radius := 70.0
var lifetime := 7.0

func setup(spawn_position: Vector2, new_damage: float, new_radius: float) -> void:
	position = spawn_position
	damage = new_damage
	blast_radius = new_radius

func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.12
	draw_circle(Vector2.ZERO, 20.0 * pulse, Color(0.26, 0.82, 0.95, 0.16))
	draw_circle(Vector2.ZERO, 10.0, Color(0.24, 0.55, 0.72, 1.0))
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		draw_line(Vector2.from_angle(angle) * 8.0, Vector2.from_angle(angle) * 17.0, Color(0.92, 0.82, 0.42, 0.9), 3.0)
	draw_arc(Vector2.ZERO, trigger_radius, 0.0, TAU, 40, Color(0.35, 0.9, 1.0, 0.12), 2.0)
