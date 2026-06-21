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

	main.player.set_process(false)
	main.player.position = main.START_POSITION
	main.player.reset_navigation_state()
	var cruise_start_y: float = main.player.position.y
	main.player._process(0.25)
	var cruise_distance: float = cruise_start_y - main.player.position.y
	if cruise_distance <= 0.0:
		_fail("航船在无输入时没有自动向前巡航")
		return

	main.player.position = main.START_POSITION
	main.player.reset_navigation_state()
	Input.action_press("move_up")
	var boost_start_y: float = main.player.position.y
	main.player._process(0.25)
	Input.action_release("move_up")
	var boost_distance: float = boost_start_y - main.player.position.y
	main.player.set_process(true)
	if boost_distance <= cruise_distance:
		_fail("按住前进键后航船没有加速")
		return

	var base_damage: float = main.player.weapon_damage
	var risk_beacon = null
	for beacon in main.route_beacons:
		if beacon.route_type == "risk":
			risk_beacon = beacon
			break
	if risk_beacon == null:
		_fail("没有生成赤潮捷径信标")
		return
	main.player.position = risk_beacon.position
	await process_frame
	if main.player.weapon_damage <= base_damage or not main.chosen_route_groups.has(risk_beacon.group_id):
		_fail("路线选择没有应用奖励")
		return

	var elite = null
	for turret in main.turrets:
		if turret.is_elite:
			elite = turret
			break
	if elite == null or not main.elite_alive:
		_fail("没有生成封锁出口的精英炮台")
		return
	elite.take_damage(elite.max_health + 1.0)
	await process_frame
	if main.elite_alive:
		_fail("精英炮台被摧毁后出口仍处于封锁状态")
		return

	main.player.position = main.EXIT_RECT.get_center()
	await process_frame
	if main.state != "upgrade":
		_fail("进入开放出口后没有触发三选一强化")
		return
	var stopped_y: float = main.player.position.y
	for i in range(5):
		await process_frame
	if not is_equal_approx(main.player.position.y, stopped_y):
		_fail("三选一界面出现后航船仍在移动")
		return

	print("Smoke test passed: cruise -> boost -> route reward -> elite unlock -> stopped upgrade choice")
	quit(0)
