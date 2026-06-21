extends Node2D
class_name RouteBeacon

var group_id := 0
var route_type := "safe"
var radius := 76.0
var active := true
var route_name := "稳流航道"
var reward_text := "修复船体"
var info_label: Label

func setup(spawn_position: Vector2, new_group_id: int, new_type: String) -> void:
	position = spawn_position
	group_id = new_group_id
	route_type = new_type
	match route_type:
		"risk":
			route_name = "赤潮捷径"
			reward_text = "主炮伤害提升"
		"rare":
			route_name = "辉金秘航"
			reward_text = "获得稀有强化"
		_:
			route_name = "澄蓝稳流"
			reward_text = "修复并加速"
	_build_label()
	queue_redraw()

func _build_label() -> void:
	if info_label == null:
		info_label = Label.new()
		info_label.position = Vector2(-100, -132)
		info_label.size = Vector2(200, 58)
		info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_label.add_theme_font_size_override("font_size", 18)
		info_label.add_theme_constant_override("outline_size", 5)
		info_label.add_theme_color_override("font_outline_color", Color(0.02, 0.1, 0.15, 0.9))
		add_child(info_label)
	info_label.text = "%s\n%s" % [route_name, reward_text]

func deactivate() -> void:
	active = false
	if info_label != null:
		info_label.visible = false
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not active:
		return
	var color := Color(0.35, 0.82, 1.0, 0.9)
	if route_type == "risk":
		color = Color(1.0, 0.34, 0.3, 0.92)
	elif route_type == "rare":
		color = Color(1.0, 0.82, 0.26, 0.95)
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.004) * 0.08
	draw_circle(Vector2.ZERO, radius * pulse, Color(color, 0.08))
	draw_arc(Vector2.ZERO, radius * pulse, 0.0, TAU, 64, color, 5.0)
	draw_arc(Vector2.ZERO, radius * 0.62, -PI * 0.75, PI * 0.75, 40, Color(color, 0.65), 3.0)
	draw_polygon([
		Vector2(0, -34),
		Vector2(-18, 4),
		Vector2(0, 28),
		Vector2(18, 4)
	], [Color(color, 0.75)])
