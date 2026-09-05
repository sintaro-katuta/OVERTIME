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
	var action = game.preparation_action_area.get_child(0)
	assert(action.text == "武器を選択")
	action.pressed.emit()
	assert(game.preparation_tab == "weapons")
	game.progression.select_weapon("sidearm_9")
	game.begin_run_from_preparation()
	assert(game.preparation_open and not game.game_active)
	game.select_preparation_tab("settings")
	game.begin_run_from_preparation()
	assert(game.preparation_open and not game.game_active)
	game.select_preparation_tab("play")
	action = game.preparation_action_area.get_child(0)
	assert(action.text == "出撃" and not action.disabled)
	action.pressed.emit()
	assert(game.game_active and not game.preparation_open)
	assert(game.weapon_model_id == "sidearm_9")
	game.queue_free()
	await process_frame
	print("preparation_launch_test: PASS")
	quit()
