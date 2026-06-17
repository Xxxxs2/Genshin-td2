extends Node2D

const PlayerShipScript := preload("res://scripts/PlayerShip.gd")
const EnemyScript := preload("res://scripts/Enemy.gd")
const BulletScript := preload("res://scripts/Bullet.gd")
const StarfieldScript := preload("res://scripts/Starfield.gd")

const ARENA_SIZE := Vector2(1280, 720)
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
	{"id": "slow_bullets", "name": "航线偏转", "desc": "敌方弹幕速度 -15%"}
]

var player: Node2D
var enemies: Array = []
var bullets: Array = []
var level := 1
var state := "combat"
var selected_upgrade_ids: Array[String] = []
var enemy_bullet_speed_factor := 1.0
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
	_tick_enemies(delta)
	_check_collisions()
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
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()
	for bullet in bullets:
		if is_instance_valid(bullet):
			bullet.queue_free()
	bullets.clear()
	var enemy_count := 4 + level * 2
	for i in range(enemy_count):
		_spawn_enemy(i, enemy_count)
	_update_hud()

func _spawn_enemy(index: int, total: int) -> void:
	var lane_width := (ARENA_SIZE.x - 180.0) / maxf(1.0, float(total - 1))
	var spawn := Vector2(90.0 + lane_width * index + randf_range(-36.0, 36.0), -70.0 - float(index % 5) * 68.0)
	spawn.x = clamp(spawn.x, 90.0, ARENA_SIZE.x - 90.0)
	var enemy := EnemyScript.new()
	enemy.setup(level, spawn)
	enemy.killed.connect(_on_enemy_killed)
	enemies.append(enemy)
	add_child(enemy)

func _handle_player_auto_fire() -> void:
	if not player.can_fire():
		return
	var target := _find_nearest_enemy(player.weapon_range)
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
	for enemy in enemies:
		if is_instance_valid(enemy) and player.position.distance_to(enemy.position) <= player.aura_radius + enemy.radius:
			enemy.take_damage(player.aura_damage)

func _find_nearest_enemy(max_range: float) -> Node2D:
	var best: Node2D = null
	var best_distance := max_range
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var distance := player.position.distance_to(enemy.position)
		if distance <= best_distance:
			best = enemy
			best_distance = distance
	return best

func _tick_enemies(delta: float) -> void:
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		for bullet in enemy.tick(delta, player):
			bullet.velocity *= enemy_bullet_speed_factor
			bullets.append(bullet)
			add_child(bullet)
		if enemy.position.y > ARENA_SIZE.y + 70.0:
			player.take_damage(enemy.bullet_damage * 1.5)
			enemies.erase(enemy)
			enemy.queue_free()
	if enemies.is_empty() and state == "combat":
		_show_upgrade_choices()

func _check_collisions() -> void:
	for bullet in bullets:
		if not is_instance_valid(bullet):
			continue
		if bullet.bullet_owner == 0:
			for enemy in enemies:
				if not is_instance_valid(enemy):
					continue
				if bullet.position.distance_to(enemy.position) <= bullet.radius + enemy.radius:
					enemy.take_damage(bullet.damage)
					if bullet.consume_hit():
						bullet.queue_free()
					break
		else:
			if bullet.position.distance_to(player.position) <= bullet.radius + player.radius:
				player.take_damage(bullet.damage)
				bullet.queue_free()

func _cleanup_bullets() -> void:
	bullets = bullets.filter(func(bullet) -> bool:
		return is_instance_valid(bullet) and bullet.is_inside_tree()
	)

func _on_enemy_killed(enemy) -> void:
	enemies.erase(enemy)
	_update_hud()
	if enemies.is_empty() and state == "combat":
		_show_upgrade_choices()

func _show_upgrade_choices() -> void:
	state = "upgrade"
	center_panel.visible = true
	var title := center_panel.get_node("MarginContainer/VBoxContainer/Title") as Label
	title.text = "第 %d 段航线完成 - 选择一项强化" % level
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
			enemy_bullet_speed_factor = maxf(0.55, enemy_bullet_speed_factor * 0.85)
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
	enemy_bullet_speed_factor = 1.0
	aura_timer = 0.0
	player.position = Vector2(ARENA_SIZE.x * 0.5, ARENA_SIZE.y - 105.0)
	_start_run()

func _update_hud() -> void:
	var upgrades := "none"
	if not selected_upgrade_ids.is_empty():
		upgrades = ", ".join(selected_upgrade_ids)
	hud_label.text = "航线 %d  敌人 %d  船体 %.0f/%.0f  护盾 %d/%d  伤害 %.0f  间隔 %.2fs  弹数 %d  强化: %s" % [
		level,
		enemies.size(),
		player.health,
		player.max_health,
		player.shield_charges,
		player.max_shield_charges,
		player.weapon_damage,
		player.fire_interval,
		player.bullet_count,
		upgrades
	]
