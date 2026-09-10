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
	game.skills.path = "/tmp/overtime-preparation-skills.cfg"
	game.control_settings.path = "/tmp/overtime-preparation-controls.cfg"
	root.add_child(game)
	game.skills.selected = ["", ""]
	game.start_from_title()
	var action = game.preparation_action_area.get_child(0)
	assert(action.text == "武器を選択  →")
	action.pressed.emit()
	assert(game.preparation_tab == "weapons")
	game.progression.select_weapon("sidearm_9")
	game.begin_run_from_preparation()
	assert(game.preparation_open and not game.game_active)
	game.select_preparation_tab("settings")
	var settings = game.preparation_content.get_child(0)
	assert(settings.buttons.has("grapple") and settings.buttons.has("skill_2"))
	game.control_settings.reset()
	settings.begin_capture("skill_2")
	var key := InputEventKey.new(); key.physical_keycode = KEY_G; key.pressed = true
	settings._input(key)
	assert(game.control_settings.bindings.skill_2 == KEY_G and settings.waiting.is_empty())
	game.begin_run_from_preparation()
	assert(game.preparation_open and not game.game_active)
	game.select_preparation_tab("play")
	action = game.preparation_action_area.get_child(0)
	assert(action.text == "スキルを2個選択  →")
	game.begin_run_from_preparation()
	assert(game.preparation_tab == "skills" and not game.game_active)
	await process_frame; await process_frame
	var view = game.preparation_content.get_child(0)
	assert(view.name_buttons.size() == 6)
	assert(view.video_frame.size.y >= 160, "video must have visible area")

	assert(game.skills.select_skill(0, "chrono") == OK)
	game.select_preparation_tab("play")
	game.begin_run_from_preparation()
	assert(not game.game_active)
	assert(game.skills.select_skill(1, "chrono") == ERR_INVALID_PARAMETER)
	assert(game.skills.select_skill(1, "aegis") == OK)
	game.select_preparation_tab("play")
	action = game.preparation_action_area.get_child(0)
	assert(action.text == "出撃する  →" and not action.disabled)
	action.pressed.emit()
	assert(game.game_active and not game.preparation_open)
	assert(game.weapon_model_id == "sidearm_9")
	game.queue_free()
	await process_frame
	print("preparation_launch_test: PASS")
	quit()
