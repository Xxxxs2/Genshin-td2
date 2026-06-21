extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _run() -> void:
	var scene := load("res://scenes/Main.tscn")
	var main = scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	if not InputMap.has_action("boost"):
		_fail("项目没有配置 Shift 加速动作")
		return
	var has_shift_binding := false
	for event in InputMap.action_get_events("boost"):
		if event is InputEventKey and event.keycode == KEY_SHIFT:
			has_shift_binding = true
			break
	if not has_shift_binding:
		_fail("加速动作没有绑定到 Shift 键")
		return

	main.player.set_process(false)
	main.player.position = main.START_POSITION
	main.player.reset_navigation_state()
	var cruise_start_y: float = main.player.position.y
	main.player._process(0.25)
	var cruise_distance: float = cruise_start_y - main.player.position.y
	if cruise_distance <= 0.0:
		_fail("航船在无输入时没有沿船头自动前进")
		return

	main.player.position = main.START_POSITION
	main.player.reset_navigation_state()
	Input.action_press("boost")
	var boost_start_y: float = main.player.position.y
	main.player._process(0.25)
	Input.action_release("boost")
	var boost_distance: float = boost_start_y - main.player.position.y
	if boost_distance <= cruise_distance:
		_fail("按住 Shift 后航船没有加速")
		return

	main.player.position = main.START_POSITION
	main.player.reset_navigation_state()
	Input.action_press("move_right")
	for i in range(8):
		main.player._process(0.1)
	Input.action_release("move_right")
	if main.player.position.x <= main.START_POSITION.x or absf(main.player.rotation) < 0.2:
		_fail("WASD 没有改变航向并带动船体转弯")
		return

	if main.current_room_id != 0 or not main.room_cleared or main.available_doors.is_empty():
		_fail("起始房没有正确生成已开启的出口")
		return

	main._enter_room(1)
	main.player.set_process(false)
	if main.room_cleared or main.enemies.size() < 2 or main.turrets.is_empty():
		_fail("战斗房没有锁门或没有生成混合敌人")
		return
	var enemy_types: Array[String] = []
	for enemy in main.enemies.duplicate():
		enemy_types.append(enemy.enemy_type)
	if not enemy_types.has("boat") or not enemy_types.has("monster"):
		_fail("战斗房没有同时生成敌船和海怪")
		return

	for enemy in main.enemies.duplicate():
		enemy.take_damage(enemy.max_health + 1.0)
	for turret in main.turrets.duplicate():
		turret.take_damage(turret.max_health + 1.0)
	await process_frame
	await process_frame
	if not main.room_cleared or main.available_doors.size() != 2 or main.coins <= 0:
		_fail("清怪后没有开门或发放资源")
		return

	var treasure_door: Dictionary = {}
	for door in main.available_doors:
		if door["target"] == 2:
			treasure_door = door
			break
	if treasure_door.is_empty():
		_fail("战斗房没有通往宝藏房的钥匙门")
		return
	var keys_before: int = main.keys
	main.player.position = treasure_door["rect"].get_center()
	await process_frame
	if main.current_room_id != 2 or main.keys != keys_before - 1 or main.state != "reward":
		_fail("钥匙门没有消耗钥匙并进入宝藏房")
		return

	var upgrades_before: int = main.selected_upgrade_ids.size()
	main._claim_relic("damage", "测试遗物")
	if main.state != "combat" or main.available_doors.is_empty() or main.selected_upgrade_ids.size() != upgrades_before + 1:
		_fail("领取宝藏后没有应用遗物并开启出口")
		return

	main._enter_room(3)
	main.player.set_process(false)
	for enemy in main.enemies.duplicate():
		enemy.take_damage(enemy.max_health + 1.0)
	for turret in main.turrets.duplicate():
		turret.take_damage(turret.max_health + 1.0)
	await process_frame
	await process_frame
	var secret_door: Dictionary = {}
	for door in main.available_doors:
		if door["target"] == 8:
			secret_door = door
			break
	if secret_door.is_empty():
		_fail("战斗房没有生成消耗星爆弹的隐藏房入口")
		return
	main.bombs = 1
	main.player.position = secret_door["rect"].get_center()
	main._check_doors()
	if main.current_room_id != 8 or main.bombs != 0 or main.state != "reward":
		_fail("隐藏房入口没有消耗星爆弹并进入奖励房")
		return
	var secret_coins_before: int = main.coins
	main._claim_secret_reward()
	if main.coins <= secret_coins_before or main.available_doors.is_empty():
		_fail("隐藏房奖励没有生效")
		return

	main.coins = 10
	main._enter_room(5)
	var damage_before: float = main.player.weapon_damage
	main._buy_shop_item("damage", "星轨主炮", 5)
	if main.coins != 5 or main.player.weapon_damage <= damage_before:
		_fail("商店没有正确消费星币并给予强化")
		return

	main._enter_room(6)
	main.player.health = 50.0
	main._event_heal()
	if main.player.health <= 50.0 or main.available_doors.is_empty():
		_fail("事件房选择没有生效")
		return

	main._enter_room(7)
	main.player.set_process(false)
	var found_boss := false
	for enemy in main.enemies.duplicate():
		if enemy.is_boss:
			found_boss = true
		enemy.take_damage(enemy.max_health + 1.0)
	if not found_boss:
		_fail("首领房没有生成首领海怪")
		return
	await process_frame
	await process_frame
	if main.state != "reward":
		_fail("首领击破后没有出现三选一遗物")
		return
	var floor_before: int = main.floor_index
	main._claim_boss_reward("shield")
	if main.floor_index != floor_before + 1 or main.current_room_id != 0:
		_fail("首领奖励后没有进入下一层起始房")
		return

	print("Smoke test passed: steering -> combat lock -> mixed enemies -> key treasure -> shop -> event -> boss -> next floor")
	quit(0)
