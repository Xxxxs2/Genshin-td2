extends Node2D
class_name Starfield

var stars: Array[Dictionary] = []
var world_size := Vector2(1280, 3600)

func setup(new_world_size: Vector2) -> void:
	world_size = new_world_size
	for i in range(520):
		stars.append({
			"position": Vector2(randf_range(0.0, world_size.x), randf_range(0.0, world_size.y)),
			"size": randf_range(1.0, 3.2),
			"phase": randf() * TAU,
			"color": Color.from_hsv(randf_range(0.5, 0.64), randf_range(0.1, 0.32), randf_range(0.72, 1.0), randf_range(0.45, 0.85))
		})

func _ready() -> void:
	if stars.is_empty():
		setup(world_size)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, world_size), Color(0.035, 0.18, 0.25, 1.0))
	draw_rect(Rect2(Vector2(85, 0), Vector2(world_size.x - 170, world_size.y)), Color(0.04, 0.27, 0.34, 1.0))
	for y in range(180, int(world_size.y), 620):
		var band_index := int(y / 620)
		var side := -1.0 if band_index % 2 == 0 else 1.0
		draw_circle(Vector2(world_size.x * 0.5 + side * 350.0, y), 230.0, Color(0.3, 0.78, 0.9, 0.065))
	for star in stars:
		var pulse: float = 0.55 + sin(Time.get_ticks_msec() * 0.0018 + star.phase) * 0.32
		draw_circle(star.position, star.size * pulse, star.color)
	for y in range(80, int(world_size.y), 120):
		draw_line(Vector2(110, y), Vector2(world_size.x - 110, y + 28), Color(0.68, 0.95, 1.0, 0.045), 1.0)
