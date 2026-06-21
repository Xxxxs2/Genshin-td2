extends Node2D

const PlayerShipScript := preload("res://scripts/PlayerShip.gd")
const BulletScript := preload("res://scripts/Bullet.gd")
const StarfieldScript := preload("res://scripts/Starfield.gd")
const IslandScript := preload("res://scripts/Island.gd")
const TurretScript := preload("res://scripts/Turret.gd")
const EnemyScript := preload("res://scripts/Enemy.gd")
const SeaMineScript := preload("res://scripts/SeaMine.gd")

const ARENA_SIZE := Vector2(1280, 720)
const ROOM_BOUNDS := Rect2(Vector2(74, 82), Vector2(1132, 556))
const START_POSITION := Vector2(640, 540)
const UPGRADE_POOL := [
	{"id": "damage", "name": "星轨主炮", "desc": "主炮伤害 +25%", "family": "炮击"},
	{"id": "rate", "name": "辉光装填", "desc": "开火速度 +18%", "family": "炮击"},
	{"id": "range", "name": "星象透镜", "desc": "武器射程 +20%", "family": "炮击"},
	{"id": "multishot", "name": "棱光齐射", "desc": "投射物 +1", "family": "炮击"},
	{"id": "pierce", "name": "彗星穿透", "desc": "穿透 +1", "family": "炮击"},
	{"id": "speed", "name": "风帆机动", "desc": "航速与转向 +12%", "family": "机动"},
	{"id": "heal", "name": "潮汐护核", "desc": "生命上限 +10，回复 35", "family": "防御"},
	{"id": "shield", "name": "镜光屏障", "desc": "可再生护盾 +1", "family": "防御"},
	{"id": "aura", "name": "回旋星刃", "desc": "获得近身周期伤害", "family": "防御"},
	{"id": "broadside", "name": "月弧侧舷", "desc": "侧舷伤害 +45%", "family": "炮击"},
	{"id": "mine", "name": "星潮尾雷", "desc": "解锁自动尾雷", "family": "机动"},
	{"id": "mine_core", "name": "深海雷核", "desc": "尾雷范围和伤害提升", "family": "机动"}
]

const ROOM_GRAPH := {
	0: {"type": "start", "name": "漂流起点", "doors": [{"side": "north", "target": 1, "label": "战斗海域"}]},
	1: {"type": "combat", "name": "碎星浅湾", "doors": [
		{"side": "west", "target": 2, "label": "宝藏舱", "key": 1},
		{"side": "east", "target": 3, "label": "战斗海域"}
	]},
	2: {"type": "treasure", "name": "沉星宝藏舱", "doors": [{"side": "north", "target": 4, "label": "精英海域"}]},
	3: {"type": "combat", "name": "巡猎航道", "doors": [
		{"side": "north", "target": 4, "label": "精英海域"},
		{"side": "west", "target": 8, "label": "可疑礁壁", "bomb": 1}
	]},
	4: {"type": "elite", "name": "赤潮伏击区", "doors": [
		{"side": "west", "target": 5, "label": "漂流商店"},
		{"side": "east", "target": 6, "label": "神秘事件"}
	]},
	5: {"type": "shop", "name": "漂流商店", "doors": [{"side": "north", "target": 7, "label": "首领海域"}]},
	6: {"type": "event", "name": "星潮祭坛", "doors": [{"side": "north", "target": 7, "label": "首领海域"}]},
	7: {"type": "boss", "name": "深海王庭", "doors": []},
	8: {"type": "secret", "name": "隐秘星湾", "doors": [{"side": "north", "target": 4, "label": "精英海域"}]}
}

var player: Node2D
var enemies: Array = []
var turrets: Array = []
var bullets: Array = []
var islands: Array = []
var mines: Array = []
var available_doors: Array = []
var door_labels: Array = []

var floor_index := 1
var current_room_id := 0
var rooms_cleared := 0
var state := "combat"
var room_cleared := false
var reward_claimed := false
var coins := 0
var keys := 1
var bombs := 1
var selected_upgrade_ids: Array[String] = []
var upgrade_family_counts := {"炮击": 0, "防御": 0, "机动": 0}
var aura_timer := 0.0
var notice_timer := 0.0

var ui_layer: CanvasLayer
var hud_label: Label
var map_label: Label
var notice_label: Label
var center_panel: PanelContainer
var choice_row: HBoxContainer

func _ready() -> void:
	randomize()
	_build_world()
	_build_ui()
	_start_run()

func _process(delta: float) -> void:
	if state == "combat":
		_handle_player_auto_fire()
		_handle_player_side_fire()
		_handle_player_mines()
		_handle_player_aura(delta)
		_tick_hostiles(delta)
		_check_collisions()
		_check_room_clear()
		_check_doors()
		_cleanup_objects()
	_update_notice(delta)
	_update_hud()
	queue_redraw()

func _build_world() -> void:
	var ocean := StarfieldScript.new()
	ocean.setup(ARENA_SIZE)
	ocean.z_index = -10
	add_child(ocean)
	player = PlayerShipScript.new()
	player.position = START_POSITION
	player.navigation_bounds = ROOM_BOUNDS
	player.died.connect(_on_player_died)
	add_child(player)

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	hud_label = Label.new()
	hud_label.position = Vector2(24, 18)
	hud_label.add_theme_font_size_override("font_size", 18)
	hud_label.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	ui_layer.add_child(hud_label)
	map_label = Label.new()
	map_label.position = Vector2(760, 18)
	map_label.size = Vector2(490, 80)
	map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	map_label.add_theme_font_size_override("font_size", 15)
	map_label.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0))
	ui_layer.add_child(map_label)
	notice_label = Label.new()
	notice_label.position = Vector2(300, 62)
	notice_label.size = Vector2(680, 48)
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.add_theme_font_size_override("font_size", 22)
	notice_label.add_theme_constant_override("outline_size", 5)
	notice_label.add_theme_color_override("font_outline_color", Color(0.02, 0.08, 0.12, 0.9))
	ui_layer.add_child(notice_label)
	center_panel = PanelContainer.new()
	center_panel.visible = false
	center_panel.set_anchors_preset(Control.PRESET_CENTER)
	center_panel.offset_left = -430
	center_panel.offset_top = -155
	center_panel.offset_right = 430
	center_panel.offset_bottom = 155
	ui_layer.add_child(center_panel)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	center_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.name = "Stack"
	stack.add_theme_constant_override("separation", 16)
	margin.add_child(stack)
	var title := Label.new()
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 27)
	stack.add_child(title)
	choice_row = HBoxContainer.new()
	choice_row.name = "Choices"
	choice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	choice_row.add_theme_constant_override("separation", 12)
	stack.add_child(choice_row)

func _start_run() -> void:
	floor_index = 1
	coins = 0
	keys = 1
	bombs = 1
	selected_upgrade_ids.clear()
	upgrade_family_counts = {"炮击": 0, "防御": 0, "机动": 0}
	player.health = player.max_health
	_enter_room(0)

func _enter_room(room_id: int) -> void:
	_clear_room_objects()
	current_room_id = room_id
	state = "combat"
	room_cleared = false
	reward_claimed = false
	center_panel.visible = false
	player.movement_enabled = true
	player.position = START_POSITION
	player.reset_navigation_state()
	var room: Dictionary = ROOM_GRAPH[current_room_id]
	_show_notice("进入：%s" % room["name"])
	_build_room_geometry(room["type"])
	_spawn_room_content(room["type"])
	if room["type"] in ["start", "treasure", "shop", "event", "secret"]:
		room_cleared = true
		_open_room_reward(room["type"])
	else:
		available_doors.clear()

func _clear_room_objects() -> void:
	for collection in [enemies, turrets, bullets, islands, mines]:
		for item in collection:
			if is_instance_valid(item):
				item.queue_free()
		collection.clear()
	for label in door_labels:
		if is_instance_valid(label):
			label.queue_free()
	door_labels.clear()
	available_doors.clear()

func _build_room_geometry(room_type: String) -> void:
	var layouts := {
		"combat": [Vector2(350, 260), Vector2(930, 440)],
		"elite": [Vector2(270, 220), Vector2(1010, 220), Vector2(640, 470)],
		"boss": [Vector2(270, 360), Vector2(1010, 360)],
		"treasure": [Vector2(300, 250), Vector2(980, 250)],
		"shop": [Vector2(240, 520), Vector2(1040, 520)],
		"event": [Vector2(360, 420), Vector2(920, 420)],
		"secret": [Vector2(320, 260), Vector2(960, 460)]
	}
	for pos in layouts.get(room_type, []):
		var island := IslandScript.new()
		island.setup(pos, 62.0 if room_type != "boss" else 82.0)
		islands.append(island)
		add_child(island)

func _spawn_room_content(room_type: String) -> void:
	match room_type:
		"combat":
			_spawn_enemy(Vector2(330, 190), "boat")
			_spawn_enemy(Vector2(950, 190), "monster")
			if current_room_id == 3 or floor_index > 1:
				_spawn_enemy(Vector2(640, 250), "skirmisher")
			_spawn_turret(Vector2(640, 150), "aimed")
		"elite":
			_spawn_enemy(Vector2(420, 190), "monster")
			_spawn_enemy(Vector2(860, 190), "skirmisher")
			_spawn_turret(Vector2(640, 220), "spread", true)
		"boss":
			_spawn_enemy(Vector2(640, 220), "monster", true)
			_spawn_enemy(Vector2(390, 190), "boat")
			_spawn_enemy(Vector2(890, 190), "boat")

func _spawn_enemy(pos: Vector2, enemy_type: String, boss: bool = false) -> void:
	var enemy := EnemyScript.new()
	enemy.setup(floor_index, pos, enemy_type, boss)
	enemy.room_bounds = ROOM_BOUNDS
	enemy.killed.connect(_on_enemy_killed)
	enemies.append(enemy)
	add_child(enemy)

func _spawn_turret(pos: Vector2, attack_type: String, elite: bool = false) -> void:
	var turret := TurretScript.new()
	turret.setup(pos, floor_index, attack_type, elite)
	turret.destroyed.connect(_on_turret_destroyed)
	turrets.append(turret)
	add_child(turret)

func _all_targets() -> Array:
	var targets: Array = []
	for target in enemies + turrets:
		if is_instance_valid(target):
			targets.append(target)
	return targets

func _handle_player_auto_fire() -> void:
	if not player.can_fire():
		return
	var target := _find_target_in_arc(player.forward_vector(), player.weapon_range, 0.05)
	if target == null:
		return
	var base_direction: Vector2 = (target.position - player.position).normalized()
	var spread_step := deg_to_rad(9.0)
	var start_offset := -spread_step * float(player.bullet_count - 1) * 0.5
	for i in range(player.bullet_count):
		var direction := base_direction.rotated(start_offset + spread_step * i)
		_spawn_player_bullet(player.position + direction * 40.0, direction, player.weapon_damage, 6.0, player.pierce)
	player.mark_fired()

func _handle_player_side_fire() -> void:
	if not player.can_side_fire():
		return
	var forward: Vector2 = player.forward_vector()
	var right := forward.rotated(PI * 0.5)
	var fired := false
	for side in [-1.0, 1.0]:
		var side_direction: Vector2 = right * side
		var target := _find_target_in_arc(side_direction, player.side_range, 0.45)
		if target == null:
			continue
		var direction: Vector2 = (target.position - player.position).normalized()
		for raw_offset in [-0.08, 0.08]:
			var offset: float = raw_offset
			_spawn_player_bullet(player.position + side_direction * 31.0, direction.rotated(offset), player.side_damage, 5.0, 0)
		fired = true
	if fired:
		player.mark_side_fired()

func _spawn_player_bullet(pos: Vector2, direction: Vector2, damage: float, radius: float, pierce: int) -> void:
	var bullet := BulletScript.new()
	bullet.setup(pos, direction * player.bullet_speed, damage, 0, radius, pierce)
	bullets.append(bullet)
	add_child(bullet)

func _handle_player_mines() -> void:
	if not player.can_drop_mine():
		return
	var rear: Vector2 = -player.forward_vector()
	if _find_target_in_arc(rear, 185.0, 0.15) == null:
		return
	var mine := SeaMineScript.new()
	mine.setup(player.position + rear * 52.0, player.mine_damage, player.mine_radius)
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
	for target in _all_targets():
		if player.position.distance_to(target.position) <= player.aura_radius + target.radius:
			target.take_damage(player.aura_damage)

func _find_target_in_arc(direction: Vector2, max_range: float, min_dot: float) -> Node2D:
	var best: Node2D = null
	var best_distance := max_range
	for target in _all_targets():
		var offset: Vector2 = target.position - player.position
		var distance := offset.length()
		if distance <= best_distance and distance > 0.01 and direction.dot(offset / distance) >= min_dot:
			best = target
			best_distance = distance
	return best

func _tick_hostiles(delta: float) -> void:
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		for bullet in enemy.tick(delta, player):
			bullets.append(bullet)
			add_child(bullet)
	for turret in turrets:
		if not is_instance_valid(turret):
			continue
		for bullet in turret.tick(delta, player):
			bullets.append(bullet)
			add_child(bullet)

func _check_collisions() -> void:
	for bullet in bullets:
		if not is_instance_valid(bullet):
			continue
		if bullet.bullet_owner == 0:
			for target in _all_targets():
				if bullet.position.distance_to(target.position) <= bullet.radius + target.radius:
					target.take_damage(bullet.damage)
					if bullet.consume_hit():
						bullet.queue_free()
					break
		elif bullet.position.distance_to(player.position) <= bullet.radius + player.radius:
			player.take_damage(bullet.damage)
			bullet.queue_free()
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.position.distance_to(player.position) <= enemy.radius + player.radius:
			player.take_damage(enemy.contact_damage)
	for island in islands:
		if not is_instance_valid(island):
			continue
		var offset: Vector2 = player.position - island.position
		var min_distance: float = player.radius + island.radius
		if offset.length() < min_distance and offset.length() > 0.01:
			player.position = island.position + offset.normalized() * min_distance
	for mine in mines:
		if not is_instance_valid(mine):
			continue
		for target in _all_targets():
			if mine.position.distance_to(target.position) <= mine.trigger_radius + target.radius:
				for blast_target in _all_targets():
					if mine.position.distance_to(blast_target.position) <= mine.blast_radius + blast_target.radius:
						blast_target.take_damage(mine.damage)
				mine.queue_free()
				break
	player.position.x = clamp(player.position.x, ROOM_BOUNDS.position.x, ROOM_BOUNDS.end.x)
	player.position.y = clamp(player.position.y, ROOM_BOUNDS.position.y, ROOM_BOUNDS.end.y)

func _check_room_clear() -> void:
	enemies = enemies.filter(func(item) -> bool:
		return is_instance_valid(item) and not item.is_queued_for_deletion()
	)
	turrets = turrets.filter(func(item) -> bool:
		return is_instance_valid(item) and not item.is_queued_for_deletion()
	)
	if room_cleared or not enemies.is_empty() or not turrets.is_empty():
		return
	room_cleared = true
	rooms_cleared += 1
	var room_type: String = ROOM_GRAPH[current_room_id]["type"]
	if room_type == "boss":
		_show_boss_reward()
		return
	coins += 2 + floor_index
	if rooms_cleared % 3 == 0:
		bombs += 1
		_show_notice("房间清理：获得星币和星爆弹")
	elif rooms_cleared % 2 == 0:
		keys += 1
		_show_notice("房间清理：获得星币和钥匙")
	else:
		_show_notice("房间清理：获得 %d 星币" % (2 + floor_index))
	_build_available_doors()

func _build_available_doors() -> void:
	for label in door_labels:
		if is_instance_valid(label):
			label.queue_free()
	door_labels.clear()
	available_doors.clear()
	for door_data in ROOM_GRAPH[current_room_id]["doors"]:
		var door: Dictionary = door_data.duplicate()
		door["rect"] = _door_rect(door["side"])
		available_doors.append(door)
		_add_door_label(door)

func _add_door_label(door: Dictionary) -> void:
	var label := Label.new()
	var rect: Rect2 = door["rect"]
	label.size = Vector2(220, 28)
	match door["side"]:
		"north":
			label.position = Vector2(rect.get_center().x - 110, rect.end.y + 8)
		"south":
			label.position = Vector2(rect.get_center().x - 110, rect.position.y - 34)
		"west":
			label.position = Vector2(rect.end.x + 8, rect.get_center().y - 14)
		_:
			label.position = Vector2(rect.position.x - 228, rect.get_center().y - 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = door["label"]
	if int(door.get("key", 0)) > 0:
		label.text += "  [钥匙]"
	if int(door.get("bomb", 0)) > 0:
		label.text += "  [星爆弹]"
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.08, 0.12, 0.95))
	door_labels.append(label)
	add_child(label)

func _door_rect(side: String) -> Rect2:
	match side:
		"west":
			return Rect2(Vector2(45, 300), Vector2(78, 120))
		"east":
			return Rect2(Vector2(1157, 300), Vector2(78, 120))
		"south":
			return Rect2(Vector2(580, 610), Vector2(120, 78))
		_:
			return Rect2(Vector2(580, 32), Vector2(120, 92))

func _check_doors() -> void:
	if not room_cleared or state != "combat":
		return
	for door in available_doors:
		if not door["rect"].has_point(player.position):
			continue
		var key_cost: int = door.get("key", 0)
		var bomb_cost: int = door.get("bomb", 0)
		if keys < key_cost:
			_show_notice("需要 %d 把钥匙" % key_cost)
			return
		if bombs < bomb_cost:
			_show_notice("需要 %d 枚星爆弹" % bomb_cost)
			return
		keys -= key_cost
		bombs -= bomb_cost
		_enter_room(door["target"])
		return

func _open_room_reward(room_type: String) -> void:
	match room_type:
		"start":
			_build_available_doors()
		"treasure":
			_show_single_relic()
		"shop":
			_show_shop()
		"event":
			_show_event()
		"secret":
			_show_secret_room()

func _show_secret_room() -> void:
	_show_choice_panel("隐秘星湾", [{
		"label": "拾取秘密补给\n星币 +8 / 钥匙 +1 / 修复 20",
		"action": Callable(self, "_claim_secret_reward")
	}])

func _claim_secret_reward() -> void:
	coins += 8
	keys += 1
	player.heal(20.0)
	_close_reward_and_open_doors("发现了隐秘星湾的储藏")

func _show_single_relic() -> void:
	var relic: Dictionary = UPGRADE_POOL.pick_random()
	_show_choice_panel("宝藏房：发现遗物", [{
		"label": "%s\n%s" % [relic["name"], relic["desc"]],
		"action": Callable(self, "_claim_relic").bind(relic["id"], relic["name"])
	}])

func _claim_relic(upgrade_id: String, relic_name: String) -> void:
	_apply_upgrade(upgrade_id)
	reward_claimed = true
	_close_reward_and_open_doors("获得遗物：%s" % relic_name)

func _show_shop() -> void:
	var pool := UPGRADE_POOL.duplicate()
	pool.shuffle()
	var options: Array = []
	for i in range(3):
		var item: Dictionary = pool[i]
		var price := 5 + i * 2
		options.append({
			"label": "%s\n%s\n%d 星币" % [item["name"], item["desc"], price],
			"action": Callable(self, "_buy_shop_item").bind(item["id"], item["name"], price)
		})
	options.append({
		"label": "离开商店\n保留星币",
		"action": Callable(self, "_close_reward_and_open_doors").bind("离开漂流商店")
	})
	_show_choice_panel("漂流商店", options)

func _buy_shop_item(upgrade_id: String, item_name: String, price: int) -> void:
	if coins < price:
		_show_notice("星币不足")
		return
	coins -= price
	_apply_upgrade(upgrade_id)
	reward_claimed = true
	_close_reward_and_open_doors("购买：%s" % item_name)

func _show_event() -> void:
	_show_choice_panel("星潮祭坛", [
		{
			"label": "献出 25 船体\n随机强化两次",
			"action": Callable(self, "_event_sacrifice")
		},
		{
			"label": "平静祈愿\n回复 30 船体",
			"action": Callable(self, "_event_heal")
		}
	])

func _event_sacrifice() -> void:
	player.health = maxf(1.0, player.health - 25.0)
	for i in range(2):
		_apply_upgrade(UPGRADE_POOL.pick_random()["id"])
	_close_reward_and_open_doors("祭坛回应了你的冒险")

func _event_heal() -> void:
	player.heal(30.0)
	_close_reward_and_open_doors("潮声抚平了船体裂痕")

func _show_boss_reward() -> void:
	var choices := _roll_upgrade_choices()
	var options: Array = []
	for choice in choices:
		options.append({
			"label": "%s\n%s" % [choice["name"], choice["desc"]],
			"action": Callable(self, "_claim_boss_reward").bind(choice["id"])
		})
	_show_choice_panel("第 %d 层首领击破 - 选择遗物" % floor_index, options)

func _claim_boss_reward(upgrade_id: String) -> void:
	_apply_upgrade(upgrade_id)
	floor_index += 1
	player.heal(30.0)
	_enter_room(0)

func _show_choice_panel(title_text: String, options: Array) -> void:
	state = "reward"
	player.movement_enabled = false
	center_panel.visible = true
	center_panel.get_node("Margin/Stack/Title").text = title_text
	for child in choice_row.get_children():
		child.queue_free()
	for option in options:
		var button := Button.new()
		button.custom_minimum_size = Vector2(190, 112)
		button.text = option["label"]
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(option["action"])
		choice_row.add_child(button)

func _close_reward_and_open_doors(message: String) -> void:
	state = "combat"
	player.movement_enabled = true
	center_panel.visible = false
	_build_available_doors()
	_show_notice(message)

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
			player.forward_speed *= 1.12
			player.turn_speed *= 1.12
		"heal":
			player.max_health += 10.0
			player.heal(35.0)
		"shield":
			player.max_shield_charges = mini(player.max_shield_charges + 1, 3)
			player.shield_charges = player.max_shield_charges
		"aura":
			player.aura_damage += 9.0 + floor_index
			player.aura_radius += 10.0
		"broadside":
			player.side_damage *= 1.45
			player.side_range *= 1.15
		"mine":
			player.mine_damage = maxf(player.mine_damage, 36.0)
		"mine_core":
			player.mine_damage = maxf(36.0, player.mine_damage * 1.55)
			player.mine_radius += 24.0
	selected_upgrade_ids.append(upgrade_id)
	var family := "机动"
	for item in UPGRADE_POOL:
		if item["id"] == upgrade_id:
			family = item["family"]
			break
	upgrade_family_counts[family] += 1
	if upgrade_family_counts[family] == 3:
		_apply_family_resonance(family)

func _apply_family_resonance(family: String) -> void:
	match family:
		"炮击":
			player.bullet_count = mini(player.bullet_count + 1, 5)
			player.pierce = mini(player.pierce + 1, 4)
		"防御":
			player.max_health += 18.0
			player.max_shield_charges = mini(player.max_shield_charges + 1, 3)
			player.shield_charges = player.max_shield_charges
		_:
			player.forward_speed *= 1.12
			player.turn_speed *= 1.12
			player.mine_damage = maxf(player.mine_damage, 36.0)
	_show_notice("构筑共鸣：%s系质变已激活" % family)

func _on_enemy_killed(enemy) -> void:
	enemies.erase(enemy)
	call_deferred("_check_room_clear")

func _on_turret_destroyed(turret) -> void:
	turrets.erase(turret)
	call_deferred("_check_room_clear")

func _on_player_died() -> void:
	if state == "failed":
		return
	state = "failed"
	player.movement_enabled = false
	_show_choice_panel("航行失败：第 %d 层 · %s" % [floor_index, ROOM_GRAPH[current_room_id]["name"]], [{
		"label": "重新开始",
		"action": _reset_player_stats_and_restart
	}])
	state = "failed"

func _reset_player_stats_and_restart() -> void:
	player.forward_speed = 180.0
	player.turn_speed = 3.8
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
	player.mine_damage = 0.0
	player.mine_radius = 96.0
	player.max_shield_charges = 0
	player.shield_charges = 0
	player.aura_damage = 0.0
	player.aura_radius = 118.0
	rooms_cleared = 0
	_start_run()

func _cleanup_objects() -> void:
	bullets = bullets.filter(func(item) -> bool:
		return is_instance_valid(item) and item.is_inside_tree()
	)
	mines = mines.filter(func(item) -> bool:
		return is_instance_valid(item) and item.is_inside_tree()
	)

func _show_notice(text: String) -> void:
	notice_label.text = text
	notice_label.modulate = Color.WHITE
	notice_timer = 2.2

func _update_notice(delta: float) -> void:
	if notice_timer <= 0.0:
		notice_label.text = ""
		return
	notice_timer -= delta
	if notice_timer < 0.4:
		notice_label.modulate.a = maxf(0.0, notice_timer / 0.4)

func _update_hud() -> void:
	var room: Dictionary = ROOM_GRAPH[current_room_id]
	hud_label.text = "第 %d 层  %s  船体 %.0f/%.0f  护盾 %d/%d  星币 %d  钥匙 %d  星爆弹 %d  敌人 %d" % [
		floor_index,
		room["name"],
		player.health,
		player.max_health,
		player.shield_charges,
		player.max_shield_charges,
		coins,
		keys,
		bombs,
		enemies.size() + turrets.size()
	]
	map_label.text = "房间图\n起点 → 战斗 → 宝藏/战斗/隐藏 → 精英 → 商店/事件 → 首领"

func _draw() -> void:
	draw_rect(Rect2(Vector2(42, 50), Vector2(1196, 620)), Color(0.08, 0.34, 0.4, 0.42))
	draw_rect(ROOM_BOUNDS, Color(0.04, 0.22, 0.29, 0.26))
	draw_line(Vector2(74, 82), Vector2(1206, 82), Color(0.65, 0.9, 0.92, 0.7), 5.0)
	draw_line(Vector2(74, 638), Vector2(1206, 638), Color(0.65, 0.9, 0.92, 0.7), 5.0)
	draw_line(Vector2(74, 82), Vector2(74, 638), Color(0.65, 0.9, 0.92, 0.7), 5.0)
	draw_line(Vector2(1206, 82), Vector2(1206, 638), Color(0.65, 0.9, 0.92, 0.7), 5.0)
	for door in available_doors:
		var locked := keys < int(door.get("key", 0)) or bombs < int(door.get("bomb", 0))
		var color := Color(0.95, 0.38, 0.32, 0.72) if locked else Color(0.38, 0.92, 1.0, 0.78)
		draw_rect(door["rect"], Color(color, 0.18))
		draw_rect(door["rect"], color, false, 5.0)
