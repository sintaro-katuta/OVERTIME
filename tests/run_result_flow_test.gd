extends SceneTree

class MemoryProgression extends "res://gameplay/progression_state.gd":
	func load_from_file(_path := "user://progression.save") -> Error:
		return OK
	func save_to_file(_path := "user://progression.save") -> Error:
		return OK

func _init() -> void:
	call_deferred("_test")

func _test() -> void:
	var game = load("res://main.tscn").instantiate()
	game.progression = MemoryProgression.new()
	root.add_child(game)
	game.start_from_title()
	game.progression.select_weapon("sidearm_9")
	game.skills.selected = ["repulse", "aegis"]; game.begin_run_from_preparation()
	game.has_grapple = true
	game.time_left = 0.0
	game.end_run()
	assert(not game.game_active)
	assert(game.run_result_view.visible)
	assert(game.run_result_view.retry_button.visible)
	assert(game.run_result_view.preparation_button.visible)
	var stopped_time = game.time_left
	await physics_frame
	assert(game.time_left == stopped_time)
	game.run_result_view.retry_button.pressed.emit()
	assert(game.game_active and not game.run_result_view.visible)
	assert(game.current_stage == 1 and game.time_left == game.START_TIME)
	assert(not game.has_grapple and game.weapon_model_id == "sidearm_9")
	game.end_run()
	game.run_result_view.preparation_button.pressed.emit()
	assert(game.preparation_open and game.preparation_layer.visible)
	assert(not game.game_active and not game.gameplay_hud.visible)
	assert(not game.run_result_view.visible)
	game.progression.select_weapon("vanguard_556")
	game.skills.selected = ["repulse", "aegis"]; game.begin_run_from_preparation()
	assert(game.game_active and game.weapon_model_id == "vanguard_556")
	game.current_stage = 2
	game.victory()
	assert(not game.game_active and game.run_result_view.visible)
	var saved = game.progression.to_save_data()
	game.victory()
	assert(game.progression.to_save_data() == saved)
	game.run_result_view.preparation_button.pressed.emit()
	assert(game.progression.to_save_data() == saved)
	game.skills.selected = ["repulse", "aegis"]; game.begin_run_from_preparation()
	game.end_run()
	var key := InputEventKey.new()
	key.keycode = KEY_R
	key.physical_keycode = KEY_R
	key.pressed = true
	game._input(key)
	assert(not game.game_active and game.run_result_view.visible)
	assert(game.run_result_view.retry_button.text == "リトライ")
	assert(game.run_result_view.retry_button.focus_mode == Control.FOCUS_NONE)
	game.run_result_view.retry_button.pressed.emit()
	assert(game.game_active and game.current_stage == 1)
	game.ammo = 0
	game._input(key)
	assert(game.reloading)
	game.set_game_pause(true)
	assert(paused and game.pause_panel.visible)
	var return_button = game.pause_panel.get_child(0).get_child(2)
	assert(return_button is Button)
	return_button.pressed.emit()
	assert(not paused and not game.game_paused and not game.pause_panel.visible)
	assert(game.preparation_open and game.preparation_layer.visible)
	assert(not game.game_active and not game.gameplay_hud.visible)
	game.skills.selected = ["repulse", "aegis"]; game.begin_run_from_preparation()
	assert(game.game_active and not game.preparation_open and not paused)
	assert(not game.reloading and game.time_left == game.START_TIME)
	game.queue_free()
	await process_frame
	print("run_result_flow_test: PASS")
	quit()
