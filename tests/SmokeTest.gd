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

	print("Smoke test passed: route reward -> elite unlock -> upgrade choice")
	quit(0)
