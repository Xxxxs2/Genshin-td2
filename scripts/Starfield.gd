extends Node2D
class_name Starfield

var stars: Array[Dictionary] = []

func _ready() -> void:
	for i in range(130):
		stars.append({
			"position": Vector2(randf_range(0.0, 1280.0), randf_range(0.0, 720.0)),
			"size": randf_range(1.0, 3.2),
			"phase": randf() * TAU,
			"color": Color.from_hsv(randf_range(0.5, 0.64), randf_range(0.1, 0.32), randf_range(0.72, 1.0), randf_range(0.45, 0.85))
		})

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color(0.035, 0.18, 0.25, 1.0))
	draw_rect(Rect2(Vector2(170, 0), Vector2(940, 720)), Color(0.04, 0.27, 0.34, 1.0))
	draw_circle(Vector2(1010, 140), 190.0, Color(0.35, 0.8, 0.92, 0.09))
	draw_circle(Vector2(230, 560), 230.0, Color(0.24, 0.68, 0.74, 0.08))
	for star in stars:
		var pulse: float = 0.55 + sin(Time.get_ticks_msec() * 0.0018 + star.phase) * 0.32
		draw_circle(star.position, star.size * pulse, star.color)
	for y in range(80, 720, 120):
		draw_line(Vector2(190, y), Vector2(1090, y + 28), Color(0.68, 0.95, 1.0, 0.045), 1.0)
