extends SceneTree
class MemoryProgression extends "res://gameplay/progression_state.gd":
	func load_from_file(_path := "user://progression.save") -> Error: return OK
	func save_to_file(_path := "user://progression.save") -> Error: return OK
func _init() -> void: call_deferred("run")
func capture(id: String) -> void:
	await create_timer(.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/skill-loadout-"+id+".png")
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.progression = MemoryProgression.new()
	game.skills.path = "/tmp/skill-capture-loadout.cfg"
	game.control_settings.path = "/tmp/skill-capture-controls.cfg"
	root.add_child(game)
	game.start_from_title()
	game.progression.select_weapon("vanguard_556")
	game.skills.selected = ["chrono", "aegis"]
	game.select_preparation_tab("skills")
	await capture("selection")
	game.select_preparation_tab("settings")
	await capture("settings")
	game.select_preparation_tab("play")
	await capture("preparation")
	game.begin_run_from_preparation()
	game.set_physics_process(false)
	for enemy in game.enemy_root.get_children(): enemy.set_physics_process(false)
	await physics_frame
	game.skills.activate_slot(0); game.skills.activate_slot(1); game.update_ui()
	await capture("hud")
	game.free(); print("PASS: captured skill selection, settings, preparation and dual-skill HUD"); quit()
