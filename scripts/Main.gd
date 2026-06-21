extends Node2D

const PlayerShipScript := preload("res://scripts/PlayerShip.gd")
const BulletScript := preload("res://scripts/Bullet.gd")
const StarfieldScript := preload("res://scripts/Starfield.gd")
const IslandScript := preload("res://scripts/Island.gd")
const TurretScript := preload("res://scripts/Turret.gd")
const RouteBeaconScript := preload("res://scripts/RouteBeacon.gd")
const SeaMineScript := preload("res://scripts/SeaMine.gd")

const ARENA_SIZE := Vector2(1280, 720)
const WORLD_SIZE := Vector2(1280, 3600)
const MAP_BOUNDS := Rect2(Vector2(50, 70), Vector2(1180, 3460))
const START_POSITION := Vector2(640, 3460)
const EXIT_RECT := Rect2(Vector2(500, 35), Vector2(280, 95))
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
	{"id": "lock_jammer", "name": "迷雾干扰", "desc": "炮台锁定变慢"},
	{"id": "broadside", "name": "月弧侧舷", "desc": "侧舷伤害 +45%，射程 +15%"},
	{"id": "mine", "name": "星潮尾雷", "desc": "航行时自动布置尾雷"},
	{"id": "mine_core", "name": "深海雷核", "desc": "尾雷伤害与爆炸范围提升"},
	{"id": "vanguard", "name": "破浪船首", "desc": "船首射界更强，主炮伤害 +18%"}
]

var player: Node2D
var turrets: Array = []
var bullets: Array = []
var islands: Array = []
var route_beacons: Array = []
var mines: Array = []
var level := 1
var state := "combat"
var selected_upgrade_ids: Array[String] = []
var upgrade_family_counts := {"炮击": 0, "防御": 0, "机动": 0}
var turret_bullet_speed_factor := 1.0
var turret_lock_factor := 1.0
var aura_timer := 0.0
var chosen_route_groups: Dictionary = {}
var elite_alive := false
var current_route_name := "未选择"

var ui_layer: CanvasLayer
var hud_label: Label
var notice_label: Label
var notice_timer := 0.0
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
	_handle_player_side_fire()
	_handle_player_mines()
	_handle_player_aura(delta)
	_tick_turrets(delta)
	_check_collisions()
	_check_route_beacons()
	_check_exit()
	_cleanup_bullets()
	_update_notice(delta)
	_update_hud()

func _build_world() -> void:
	var ocean := StarfieldScript.new()
	ocean.setup(WORLD_SIZE)
	add_child(ocean)
	player = PlayerShipScript.new()
	player.position = START_POSITION
	player.navigation_bounds = MAP_BOUNDS
	player.died.connect(_on_player_died)
	add_child(player)
	var camera := Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_left = 0
	camera.limit_right = int(WORLD_SIZE.x)
	camera.limit_top = 0
	camera.limit_bottom = int(WORLD_SIZE.y)
	player.add_child(camera)
	queue_redraw()

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	hud_label = Label.new()
	hud_label.position = Vector2(24, 18)
	hud_label.add_theme_font_size_override("font_size", 20)
	hud_label.add_theme_color_override("font_color", Color(0.9, 0.96, 1.0))
	ui_layer.add_child(hud_label)

	notice_label = Label.new()
	notice_label.position = Vector2(340, 58)
	notice_label.custom_minimum_size = Vector2(600, 50)
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.add_theme_font_size_override("font_size", 22)
	notice_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	ui_layer.add_child(notice_label)

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
	upgrade_family_counts = {"炮击": 0, "防御": 0, "机动": 0}
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
	for beacon in route_beacons:
		if is_instance_valid(beacon):
			beacon.queue_free()
	route_beacons.clear()
	for mine in mines:
		if is_instance_valid(mine):
			mine.queue_free()
	mines.clear()
	chosen_route_groups.clear()
	elite_alive = false
	current_route_name = "未选择"
	player.position = START_POSITION
	_build_seaway_level()
	_update_hud()

func _build_seaway_level() -> void:
	# Edge archipelagos keep the player inside a readable seaway without making a straight corridor.
	for y in range(260, 3460, 310):
		var wave := sin(float(y) * 0.0047) * 58.0
		_spawn_island(Vector2(8 + wave, y), 150.0, false)
		_spawn_island(Vector2(1272 + wave, y + 120), 155.0, false)

	var mirror := -1.0 if level % 2 == 0 else 1.0
	var layout := [
		# First fork: short defended left channel or longer open right channel.
		{"pos": Vector2(640, 3060), "r": 190.0, "turret": true, "type": "spread"},
		{"pos": Vector2(355, 2850), "r": 112.0, "turret": true, "type": "aimed"},
		{"pos": Vector2(885, 2730), "r": 145.0, "turret": false},
		# Bent middle section with three navigable gaps.
		{"pos": Vector2(600, 2390), "r": 155.0, "turret": true, "type": "sniper"},
		{"pos": Vector2(930, 2240), "r": 135.0, "turret": true, "type": "spread"},
		{"pos": Vector2(300, 2100), "r": 125.0, "turret": false},
		{"pos": Vector2(650, 1880), "r": 205.0, "turret": true, "type": "aimed"},
		# Second fork: outer routes curve around a central fortress island.
		{"pos": Vector2(380, 1540), "r": 130.0, "turret": true, "type": "spread"},
		{"pos": Vector2(735, 1450), "r": 175.0, "turret": true, "type": "sniper"},
		{"pos": Vector2(1015, 1270), "r": 105.0, "turret": false},
		{"pos": Vector2(520, 1050), "r": 145.0, "turret": true, "type": "aimed"},
		# Final S bend before the exit.
		{"pos": Vector2(850, 790), "r": 160.0, "turret": true, "type": "spread"},
		{"pos": Vector2(390, 610), "r": 135.0, "turret": false},
		{"pos": Vector2(650, 350), "r": 120.0, "turret": true, "type": "sniper", "elite": true}
	]
	for item in layout:
		var pos: Vector2 = item["pos"]
		pos.x = 640.0 + (pos.x - 640.0) * mirror
		_spawn_island(pos, item["r"], item["turret"], item.get("type", "aimed"), item.get("elite", false))
	if level > 2:
		var extra_count := mini(level - 2, 4)
		for i in range(extra_count):
			var extra_y := 2750.0 - i * 570.0
			var extra_x := 210.0 if (i + level) % 2 == 0 else 1070.0
			_spawn_island(Vector2(extra_x, extra_y), 82.0, true, "aimed")
	_spawn_route_beacon(Vector2(205, 2670), 1, "risk")
	_spawn_route_beacon(Vector2(1070, 2600), 1, "safe")
	_spawn_route_beacon(Vector2(620, 1250), 2, "rare")
	_spawn_route_beacon(Vector2(205, 1220), 2, "safe")

func _spawn_island(pos: Vector2, radius: float, has_turret: bool = true, attack_type: String = "aimed", elite: bool = false) -> void:
	var island := IslandScript.new()
	island.setup(pos, radius)
	islands.append(island)
	add_child(island)
	if not has_turret:
		return
	var turret := TurretScript.new()
	var turret_offset := Vector2(0, -radius * 0.3)
	turret.setup(pos + turret_offset, level, attack_type, elite)
	turret.lock_time *= turret_lock_factor
	turret.destroyed.connect(_on_turret_destroyed)
	turrets.append(turret)
	add_child(turret)
	if elite:
		elite_alive = true

func _spawn_route_beacon(pos: Vector2, group_id: int, route_type: String) -> void:
	var beacon := RouteBeaconScript.new()
	beacon.setup(pos, group_id, route_type)
	route_beacons.append(beacon)
	add_child(beacon)

func _handle_player_auto_fire() -> void:
	if not player.can_fire():
		return
	var target := _find_turret_in_arc(player.forward_vector(), player.weapon_range, 0.05)
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

func _handle_player_side_fire() -> void:
	if not player.can_side_fire():
		return
	var forward: Vector2 = player.forward_vector()
	var right := forward.rotated(PI * 0.5)
	var fired := false
	for side in [-1.0, 1.0]:
		var side_direction: Vector2 = right * side
		var target := _find_turret_in_arc(side_direction, player.side_range, 0.45)
		if target == null:
			continue
		var direction: Vector2 = (target.position - player.position).normalized()
		for raw_offset in [-0.08, 0.08]:
			var offset: float = raw_offset
			var bullet := BulletScript.new()
			var muzzle: Vector2 = player.position + side_direction * 31.0 + forward * offset * 80.0
			bullet.setup(muzzle, direction.rotated(offset) * player.bullet_speed * 0.82, player.side_damage, 0, 5.0, 0)
			bullets.append(bullet)
			add_child(bullet)
		fired = true
	if fired:
		player.mark_side_fired()

func _handle_player_mines() -> void:
	if not player.can_drop_mine():
		return
	var rear_direction: Vector2 = -player.forward_vector()
	var target := _find_turret_in_arc(rear_direction, 185.0, 0.15)
	if target == null:
		return
	var mine := SeaMineScript.new()
	mine.setup(player.position + rear_direction * 52.0, player.mine_damage, player.mine_radius)
	mines.append(mine)
	add_child(mine)
	player.mark_mine_dropped()

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

func _find_turret_in_arc(direction: Vector2, max_range: float, min_dot: float) -> Node2D:
	var best: Node2D = null
	var best_distance := max_range
	for turret in turrets:
		if not is_instance_valid(turret):
			continue
		var to_turret: Vector2 = turret.position - player.position
		var distance := to_turret.length()
		if distance <= best_distance and distance > 0.01 and direction.dot(to_turret / distance) >= min_dot:
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
	for mine in mines:
		if not is_instance_valid(mine):
			continue
		var triggered := false
		for turret in turrets:
			if not is_instance_valid(turret):
				continue
			if mine.position.distance_to(turret.position) <= mine.trigger_radius + turret.radius:
				triggered = true
				for blast_target in turrets:
					if is_instance_valid(blast_target) and mine.position.distance_to(blast_target.position) <= mine.blast_radius + blast_target.radius:
						blast_target.take_damage(mine.damage)
				break
		if triggered:
			mine.queue_free()
	player.position.x = clamp(player.position.x, MAP_BOUNDS.position.x, MAP_BOUNDS.end.x)
	player.position.y = clamp(player.position.y, MAP_BOUNDS.position.y, MAP_BOUNDS.end.y)

func _check_route_beacons() -> void:
	for beacon in route_beacons:
		if not is_instance_valid(beacon) or not beacon.active:
			continue
		if chosen_route_groups.has(beacon.group_id):
			beacon.deactivate()
			continue
		if player.position.distance_to(beacon.position) > beacon.radius:
			continue
		chosen_route_groups[beacon.group_id] = beacon.route_type
		current_route_name = beacon.route_name
		_apply_route_reward(beacon.route_type)
		for sibling in route_beacons:
			if is_instance_valid(sibling) and sibling.group_id == beacon.group_id:
				sibling.deactivate()

func _apply_route_reward(route_type: String) -> void:
	match route_type:
		"risk":
			player.weapon_damage *= 1.12
			player.side_damage *= 1.12
			_show_notice("赤潮捷径：本次远航主炮与侧舷伤害 +12%")
		"rare":
			player.bullet_count = mini(player.bullet_count + 1, 5)
			player.max_shield_charges = mini(player.max_shield_charges + 1, 3)
			player.shield_charges = player.max_shield_charges
			_show_notice("辉金秘航：投射物 +1，并补满护盾")
		_:
			player.heal(24.0)
			player.speed *= 1.04
			player.forward_speed *= 1.04
			_show_notice("澄蓝稳流：修复 24 船体，本次远航机动 +4%")

func _check_exit() -> void:
	if EXIT_RECT.has_point(player.position):
		if elite_alive:
			_show_notice("出口被星潮堡垒封锁，先摧毁精英炮台")
			return
		_show_upgrade_choices()

func _cleanup_bullets() -> void:
	bullets = bullets.filter(func(bullet) -> bool:
		return is_instance_valid(bullet) and bullet.is_inside_tree()
	)
	mines = mines.filter(func(mine) -> bool:
		return is_instance_valid(mine) and mine.is_inside_tree()
	)

func _on_turret_destroyed(turret) -> void:
	if turret.is_elite:
		elite_alive = false
		_show_notice("星潮堡垒已解除，海道出口开放")
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
		"broadside":
			player.side_damage *= 1.45
			player.side_range *= 1.15
		"mine":
			player.mine_damage = maxf(player.mine_damage, 36.0)
		"mine_core":
			player.mine_damage = maxf(36.0, player.mine_damage * 1.55)
			player.mine_radius += 26.0
		"vanguard":
			player.weapon_damage *= 1.18
			player.weapon_range *= 1.08
	_register_upgrade_family(upgrade_id)
	selected_upgrade_ids.append(upgrade_id)
	level += 1
	_start_level()

func _register_upgrade_family(upgrade_id: String) -> void:
	var family := "机动"
	if upgrade_id in ["damage", "rate", "range", "multishot", "pierce", "broadside", "vanguard"]:
		family = "炮击"
	elif upgrade_id in ["heal", "shield", "aura"]:
		family = "防御"
	upgrade_family_counts[family] += 1
	if upgrade_family_counts[family] != 3:
		return
	match family:
		"炮击":
			player.bullet_count = mini(player.bullet_count + 1, 5)
			player.pierce = mini(player.pierce + 1, 4)
			_show_notice("构筑共鸣：星轨齐射已激活，投射物与穿透 +1")
		"防御":
			player.max_shield_charges = mini(player.max_shield_charges + 1, 3)
			player.shield_charges = player.max_shield_charges
			player.max_health += 18.0
			player.heal(45.0)
			_show_notice("构筑共鸣：潮汐壁垒已激活，护盾与船体强化")
		"机动":
			player.speed *= 1.12
			player.forward_speed *= 1.12
			player.mine_damage = maxf(player.mine_damage, 36.0)
			_show_notice("构筑共鸣：风帆雷迹已激活，提速并自动布雷")

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
	player.side_damage = 11.0
	player.side_range = 245.0
	player.side_fire_interval = 1.05
	player.mine_damage = 0.0
	player.mine_radius = 96.0
	player.mine_interval = 1.65
	player.max_shield_charges = 0
	player.shield_charges = 0
	player.aura_damage = 0.0
	player.aura_radius = 118.0
	turret_bullet_speed_factor = 1.0
	turret_lock_factor = 1.0
	aura_timer = 0.0
	upgrade_family_counts = {"炮击": 0, "防御": 0, "机动": 0}
	player.position = START_POSITION
	_start_run()

func _update_hud() -> void:
	var progress := clampf((START_POSITION.y - player.position.y) / (START_POSITION.y - EXIT_RECT.end.y), 0.0, 1.0)
	var fortress_status := "封锁" if elite_alive else "开放"
	hud_label.text = "海道 %d  航程 %d%%  航线:%s  出口:%s  炮台 %d  船体 %.0f/%.0f  护盾 %d/%d  共鸣 炮%d 防%d 机%d" % [
		level,
		int(progress * 100.0),
		current_route_name,
		fortress_status,
		turrets.size(),
		player.health,
		player.max_health,
		player.shield_charges,
		player.max_shield_charges,
		upgrade_family_counts["炮击"],
		upgrade_family_counts["防御"],
		upgrade_family_counts["机动"]
	]

func _show_notice(text: String) -> void:
	notice_label.text = text
	notice_label.modulate = Color.WHITE
	notice_timer = 2.4

func _update_notice(delta: float) -> void:
	if notice_timer <= 0.0:
		notice_label.text = ""
		return
	notice_timer -= delta
	if notice_timer < 0.45:
		notice_label.modulate.a = notice_timer / 0.45

func _draw() -> void:
	draw_rect(EXIT_RECT, Color(0.48, 0.94, 1.0, 0.16))
	draw_arc(EXIT_RECT.get_center(), 92.0, PI, TAU, 64, Color(0.72, 0.98, 1.0, 0.9), 6.0)
	draw_line(Vector2(500, 128), Vector2(780, 128), Color(0.88, 0.83, 0.48, 0.8), 4.0)
	draw_circle(START_POSITION, 78.0, Color(0.38, 0.88, 1.0, 0.08))
