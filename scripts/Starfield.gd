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
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color(0.035, 0.055, 0.11, 1.0))
	draw_circle(Vector2(1040, 130), 180.0, Color(0.25, 0.48, 0.72, 0.13))
	draw_circle(Vector2(260, 560), 230.0, Color(0.47, 0.26, 0.56, 0.10))
	for star in stars:
		var pulse: float = 0.55 + sin(Time.get_ticks_msec() * 0.0018 + star.phase) * 0.32
		draw_circle(star.position, star.size * pulse, star.color)
	for x in range(80, 1280, 160):
		draw_line(Vector2(x, 0), Vector2(x - 90, 720), Color(0.35, 0.72, 0.95, 0.035), 1.0)
