extends Node2D

const PlayerShipScript := preload("res://scripts/PlayerShip.gd")
const BulletScript := preload("res://scripts/Bullet.gd")
const StarfieldScript := preload("res://scripts/Starfield.gd")
const IslandScript := preload("res://scripts/Island.gd")
const TurretScript := preload("res://scripts/Turret.gd")

const ARENA_SIZE := Vector2(1280, 720)
const MAP_BOUNDS := Rect2(Vector2(50, 50), Vector2(1180, 620))
const EXIT_RECT := Rect2(Vector2(520, 42), Vector2(240, 58))
const UPGRADE_POOL := [
	{"id": "damage", "name": "星轨主炮", "desc": "武器伤害 +25%"},
	{"id": "rate", "name": "辉光装填", "desc": "开火速度 +18%"},
	{"id": "range", "name": "星象透镜", "desc": "武器射程 +20%"},
	{"id": "multishot", "name": "棱光侧舷", "desc": "投射物 +1"},
	{"id": "pierce", "name": "彗星穿透", "desc": "穿透 +1"},
	{"id": "speed", "name": "风帆机动", "desc": "横向机动 +15%"},
	{"id": "heal", "name": "潮汐护核", "desc": "回复 35，生命上限 +10"},
	{"id": "shield", "name": "镜光屏障", "desc": "获得可再生护盾"},
	{"id": "aura", "name": "回旋星刃", "desc": "船周围周期伤害"},
	{"id": "slow_bullets", "name": "干扰旗语", "desc": "炮台弹速 -15%"},
	{"id": "lock_jammer", "name": "迷雾干扰", "desc": "炮台锁定变慢"}
]

var player: Node2D
var turrets: Array = []
var bullets: Array = []
var islands: Array = []
var level := 1
var state := "combat"
var selected_upgrade_ids: Array[String] = []
var turret_bullet_speed_factor := 1.0
var turret_lock_factor := 1.0
var aura_timer := 0.0

var ui_layer: CanvasLayer
var hud_label: Label
var center_panel: PanelContainer
var upgrade_row: HBoxContainer

func _ready() -> void:
	randomize()
	_build_world()
	_build_ui()
	_start_run()

func _process(delta: float) -> void:
	if state != "combat":
		return
	_handle_player_auto_fire()
	_handle_player_aura(delta)
	_tick_turrets(delta)
	_check_collisions()
	_check_exit()
	_cleanup_bullets()
	_update_hud()

func _build_world() -> void:
	add_child(StarfieldScript.new())
	player = PlayerShipScript.new()
	player.position = Vector2(ARENA_SIZE.x * 0.5, ARENA_SIZE.y - 105.0)
	player.died.connect(_on_player_died)
	add_child(player)

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	hud_label = Label.new()
	hud_label.position = Vector2(24, 18)
	hud_label.add_theme_font_size_override("font_size", 20)
	hud_label.add_theme_color_override("font_color", Color(0.9, 0.96, 1.0))
	ui_layer.add_child(hud_label)

	center_panel = PanelContainer.new()
	center_panel.visible = false
	center_panel.set_anchors_preset(Control.PRESET_CENTER)
	center_panel.offset_left = -420
	center_panel.offset_top = -150
	center_panel.offset_right = 420
	center_panel.offset_bottom = 150
	ui_layer.add_child(center_panel)

	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	center_panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.name = "VBoxContainer"
	stack.add_theme_constant_override("separation", 16)
	margin.add_child(stack)

	var title := Label.new()
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	stack.add_child(title)

	upgrade_row = HBoxContainer.new()
	upgrade_row.alignment = BoxContainer.ALIGNMENT_CENTER
	upgrade_row.add_theme_constant_override("separation", 12)
	stack.add_child(upgrade_row)

func _start_run() -> void:
	level = 1
	player.health = player.max_health
	selected_upgrade_ids.clear()
	_start_level()

func _start_level() -> void:
	state = "combat"
	center_panel.visible = false
	for turret in turrets:
		if is_instance_valid(turret):
			turret.queue_free()
	turrets.clear()
	for bullet in bullets:
		if is_instance_valid(bullet):
			bullet.queue_free()
	bullets.clear()
	for island in islands:
		if is_instance_valid(island):
			island.queue_free()
	islands.clear()
	player.position = Vector2(ARENA_SIZE.x * 0.5, ARENA_SIZE.y - 88.0)
	_build_seaway_level()
	_update_hud()

func _build_seaway_level() -> void:
	var layouts := [
		[
			{"pos": Vector2(300, 470), "r": 92, "turret": Vector2(300, 430)},
			{"pos": Vector2(760, 405), "r": 116, "turret": Vector2(725, 365)},
			{"pos": Vector2(1015, 235), "r": 88, "turret": Vector2(990, 200)}
		],
		[
			{"pos": Vector2(430, 520), "r": 108, "turret": Vector2(465, 480)},
			{"pos": Vector2(850, 495), "r": 96, "turret": Vector2(815, 455)},
			{"pos": Vector2(650, 245), "r": 125, "turret": Vector2(650, 205)}
		],
		[
			{"pos": Vector2(245, 360), "r": 104, "turret": Vector2(280, 320)},
			{"pos": Vector2(650, 450), "r": 112, "turret": Vector2(650, 405)},
			{"pos": Vector2(1020, 345), "r": 106, "turret": Vector2(980, 300)},
			{"pos": Vector2(520, 175), "r": 76, "turret": Vector2(520, 145)}
		]
	]
	var layout: Array = layouts[(level - 1) % layouts.size()]
	for item in layout:
		_spawn_island(item["pos"], item["r"], item["turret"])
	if level > 3:
		_spawn_island(Vector2(350 + (level % 3) * 260, 300), 78.0, Vector2(350 + (level % 3) * 260, 265))

func _spawn_island(pos: Vector2, radius: float, turret_pos: Vector2) -> void:
	var island := IslandScript.new()
	island.setup(pos, radius)
	islands.append(island)
	add_child(island)
	var turret := TurretScript.new()
	turret.setup(turret_pos, level)
	turret.lock_time *= turret_lock_factor
	turret.destroyed.connect(_on_turret_destroyed)
	turrets.append(turret)
	add_child(turret)

func _handle_player_auto_fire() -> void:
	if not player.can_fire():
		return
	var target := _find_nearest_turret(player.weapon_range)
	if target == null:
		return
	var base_direction := (target.position - player.position).normalized()
	var spread_step := deg_to_rad(9.0)
	var start_offset := -spread_step * float(player.bullet_count - 1) * 0.5
	for i in range(player.bullet_count):
		var direction := base_direction.rotated(start_offset + spread_step * i)
		var bullet := BulletScript.new()
		bullet.setup(player.position + direction * 40.0, direction * player.bullet_speed, player.weapon_damage, 0, 6.0, player.pierce)
		bullets.append(bullet)
		add_child(bullet)
	player.mark_fired()

func _handle_player_aura(delta: float) -> void:
	if player.aura_damage <= 0.0:
		return
	aura_timer -= delta
	if aura_timer > 0.0:
		return
	aura_timer = 0.72
	for turret in turrets:
		if is_instance_valid(turret) and player.position.distance_to(turret.position) <= player.aura_radius + turret.radius:
			turret.take_damage(player.aura_damage)

func _find_nearest_turret(max_range: float) -> Node2D:
	var best: Node2D = null
	var best_distance := max_range
	for turret in turrets:
		if not is_instance_valid(turret):
			continue
		var distance := player.position.distance_to(turret.position)
		if distance <= best_distance:
			best = turret
			best_distance = distance
	return best

func _tick_turrets(delta: float) -> void:
	for turret in turrets:
		if not is_instance_valid(turret):
			continue
		for bullet in turret.tick(delta, player, turret_bullet_speed_factor):
			bullets.append(bullet)
			add_child(bullet)

func _check_collisions() -> void:
	for bullet in bullets:
		if not is_instance_valid(bullet):
			continue
		if bullet.bullet_owner == 0:
			for turret in turrets:
				if not is_instance_valid(turret):
					continue
				if bullet.position.distance_to(turret.position) <= bullet.radius + turret.radius:
					turret.take_damage(bullet.damage)
					if bullet.consume_hit():
						bullet.queue_free()
					break
		else:
			if bullet.position.distance_to(player.position) <= bullet.radius + player.radius:
				player.take_damage(bullet.damage)
				bullet.queue_free()
	for island in islands:
		if not is_instance_valid(island):
			continue
		var offset: Vector2 = player.position - island.position
		var min_distance: float = player.radius + island.radius
		var distance: float = offset.length()
		if distance < min_distance and distance > 0.01:
			player.position = island.position + offset.normalized() * min_distance
			player.position.x = clamp(player.position.x, MAP_BOUNDS.position.x, MAP_BOUNDS.end.x)
			player.position.y = clamp(player.position.y, MAP_BOUNDS.position.y, MAP_BOUNDS.end.y)
	player.position.x = clamp(player.position.x, MAP_BOUNDS.position.x, MAP_BOUNDS.end.x)
	player.position.y = clamp(player.position.y, MAP_BOUNDS.position.y, MAP_BOUNDS.end.y)

func _check_exit() -> void:
	if EXIT_RECT.has_point(player.position):
		_show_upgrade_choices()

func _cleanup_bullets() -> void:
	bullets = bullets.filter(func(bullet) -> bool:
		return is_instance_valid(bullet) and bullet.is_inside_tree()
	)

func _on_turret_destroyed(turret) -> void:
	turrets.erase(turret)
	_update_hud()

func _show_upgrade_choices() -> void:
	state = "upgrade"
	center_panel.visible = true
	var title := center_panel.get_node("MarginContainer/VBoxContainer/Title") as Label
	title.text = "第 %d 段海道通过 - 选择一项强化" % level
	for child in upgrade_row.get_children():
		child.queue_free()
	var choices := _roll_upgrade_choices()
	for choice in choices:
		var button := Button.new()
		button.custom_minimum_size = Vector2(245, 116)
		button.text = "%s\n%s" % [choice["name"], choice["desc"]]
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(func() -> void:
			_apply_upgrade(choice["id"])
		)
		upgrade_row.add_child(button)

func _roll_upgrade_choices() -> Array:
	var pool := UPGRADE_POOL.duplicate()
	pool.shuffle()
	return pool.slice(0, 3)

func _apply_upgrade(upgrade_id: String) -> void:
	match upgrade_id:
		"damage":
			player.weapon_damage *= 1.25
		"rate":
			player.fire_interval = maxf(0.16, player.fire_interval * 0.82)
		"range":
			player.weapon_range *= 1.2
		"multishot":
			player.bullet_count = mini(player.bullet_count + 1, 5)
		"pierce":
			player.pierce = mini(player.pierce + 1, 4)
		"speed":
			player.speed *= 1.15
			player.forward_speed *= 1.12
		"heal":
			player.max_health += 10.0
			player.heal(35.0)
		"shield":
			player.max_shield_charges = mini(player.max_shield_charges + 1, 3)
			player.shield_charges = player.max_shield_charges
		"aura":
			player.aura_damage += 8.0 + level * 1.5
			player.aura_radius += 10.0
		"slow_bullets":
			turret_bullet_speed_factor = maxf(0.55, turret_bullet_speed_factor * 0.85)
		"lock_jammer":
			turret_lock_factor *= 1.25
	selected_upgrade_ids.append(upgrade_id)
	level += 1
	_start_level()

func _on_player_died() -> void:
	if state == "failed":
		return
	state = "failed"
	center_panel.visible = true
	for child in upgrade_row.get_children():
		child.queue_free()
	var title := center_panel.get_node("MarginContainer/VBoxContainer/Title") as Label
	title.text = "远航在第 %d 段失败" % level
	var restart := Button.new()
	restart.custom_minimum_size = Vector2(260, 80)
	restart.text = "重新开始"
	restart.add_theme_font_size_override("font_size", 22)
	restart.pressed.connect(_reset_player_stats_and_restart)
	upgrade_row.add_child(restart)

func _reset_player_stats_and_restart() -> void:
	player.speed = 240.0
	player.forward_speed = 180.0
	player.max_health = 120.0
	player.health = 120.0
	player.weapon_damage = 18.0
	player.weapon_range = 310.0
	player.fire_interval = 0.48
	player.bullet_speed = 600.0
	player.bullet_count = 1
	player.pierce = 0
	player.max_shield_charges = 0
	player.shield_charges = 0
	player.aura_damage = 0.0
	player.aura_radius = 118.0
	turret_bullet_speed_factor = 1.0
	turret_lock_factor = 1.0
	aura_timer = 0.0
	player.position = Vector2(ARENA_SIZE.x * 0.5, ARENA_SIZE.y - 88.0)
	_start_run()

func _update_hud() -> void:
	var upgrades := "none"
	if not selected_upgrade_ids.is_empty():
		upgrades = ", ".join(selected_upgrade_ids)
	hud_label.text = "海道 %d  炮台 %d  船体 %.0f/%.0f  护盾 %d/%d  伤害 %.0f  间隔 %.2fs  弹数 %d  强化: %s" % [
		level,
		turrets.size(),
		player.health,
		player.max_health,
		player.shield_charges,
		player.max_shield_charges,
		player.weapon_damage,
		player.fire_interval,
		player.bullet_count,
		upgrades
	]
