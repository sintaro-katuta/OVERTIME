extends SceneTree
const Loadout = preload("res://gameplay/skills/skill_loadout.gd")
class MemoryProgression extends "res://gameplay/progression_state.gd":
	func load_from_file(_path := "user://progression.save") -> Error: return OK
	func save_to_file(_path := "user://progression.save") -> Error: return OK
func _init() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.progression = MemoryProgression.new()
	game.skills.path = "/tmp/overtime-loadout-test.cfg"
	root.add_child(game)
	game.start_from_title()
	game.control_settings.reset()
	var skills = game.skills
	skills.selected = ["", ""]
	assert(not skills.valid_selection())
	assert(skills.select_skill(0, "invalid") == ERR_INVALID_PARAMETER)
	assert(skills.select_skill(0, "chrono") == OK)
	assert(not skills.valid_selection())
	assert(skills.select_skill(1, "chrono") == ERR_INVALID_PARAMETER)
	assert(skills.select_skill(1, "aegis") == OK)
	var loaded = Loadout.new(); loaded.path = skills.path; loaded.load_selection()
	assert(loaded.selected == skills.selected and loaded.valid_selection())
	game.progression.select_weapon("vanguard_556")
	game.begin_run_from_preparation()
	game.set_physics_process(false)
	for enemy in game.enemy_root.get_children(): enemy.set_physics_process(false)
	await physics_frame
	assert(skills.equipped == "chrono" and skills.second.equipped == "aegis")
	assert(skills.select_skill(0, "repulse") == ERR_UNAUTHORIZED)
	for key in [KEY_Q, KEY_E]:
		var event := InputEventKey.new(); event.physical_keycode = key; event.pressed = true; game._input(event)
	assert(skills.remaining == 5 and skills.second.remaining == 4)
	assert(skills.cooldown == 12 and skills.second.cooldown == 10)
	assert(skills.fire_rate_bonus() == 1.5)
	var eye: Vector3 = game.camera.global_position
	var forward: Vector3 = -game.camera.global_basis.z
	assert(skills.shield_blocks(eye+forward*3, eye))
	assert(not skills.activate_slot(0) and not skills.activate_slot(1))
	game.game_paused = true; skills.tick(1)
	assert(skills.cooldown == 12 and skills.second.cooldown == 10)
	game.game_paused = false; skills.tick(1)
	assert(skills.cooldown == 11 and skills.second.cooldown == 9)
	game.update_ui()
	assert(game.gameplay_hud.second_heading.text.begins_with("E"))
	game.open_shop()
	assert(skills.offered.is_empty() and game.shop.visible)
	game.shop_open = false
	skills.clear_stage()
	assert(skills.remaining == 0 and skills.second.remaining == 0)
	assert(skills.equipped == "chrono" and skills.second.equipped == "aegis")
	game.restart_run()
	assert(skills.cooldown == 0 and skills.second.cooldown == 0)
	assert(skills.selected == ["chrono", "aegis"])
	# Rewind in slot 2 blocks both inputs, shooting and reload.
	skills.second.equipped = "rewind"
	game.player.global_position = Vector3(0, 20, 12)
	await physics_frame
	for i in 34: skills.tick(.1)
	assert(skills.activate_slot(1) and skills.is_rewinding())
	assert(not skills.activate_slot(0))
	var ammo: int = game.ammo; game.shoot(); game.begin_reload()
	assert(game.ammo == ammo and not game.reloading)
	skills.tick(.8); assert(not skills.is_rewinding())
	# Slot 2 also owns grapple movement and its chain; slot 1 must not double-update it.
	skills.clear_stage(); skills.equipped = "repulse"; skills.second.equipped = "grapple"
	skills.second.cooldown = 0; game.has_grapple = true; game.grapple_cooldown = 0
	game.player.global_position = Vector3(0, 20, 12); game.camera.rotation = Vector3.ZERO
	var enemy = game.enemy_root.get_child(0); enemy.set_physics_process(false)
	enemy.global_position = Vector3(0, 19.6, 4)
	await physics_frame
	assert(skills.activate_slot(1) and game.grapple_target == enemy)
	skills.tick(.05)
	assert(is_equal_approx(game.grapple_time, 1.25), "grapple updates once per frame")
	skills.fx._process(.01); skills.second.fx._process(.01)
	assert(not skills.fx.chain.visible and skills.second.fx.chain.visible)
	for i in 24: skills.tick(1.0/60)
	assert(game.grapple_kill_window > 0)
	game.show_preparation_screen()
	skills.selected = ["aegis", ""]
	game.restart_run(); assert(not game.game_active and game.preparation_tab == "skills")
	print("PASS: required slots, duplicates, persistence, Q/E, independent cooldowns, combined chrono/shield, pause, no offers, retry, slot-2 rewind")
	game.free(); quit()
