extends SceneTree
class MemoryProgression extends "res://gameplay/progression_state.gd":
	func load_from_file(_path := "user://progression.save") -> Error: return OK
	func save_to_file(_path := "user://progression.save") -> Error: return OK
func _init() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.progression = MemoryProgression.new()
	game.skills.path = "/tmp/skill-selection-video-test.cfg"
	game.control_settings.path = "/tmp/skill-selection-video-controls.cfg"
	root.add_child(game)
	game.start_from_title()
	game.skills.selected = ["", ""]
	game.control_settings.reset()
	game.select_preparation_tab("skills")
	var view = game.preparation_content.get_child(0)
	var original: Array = game.skills.selected.duplicate()
	for id in view.Catalog.IDS:
		assert(view.name_buttons[id].text == view.Catalog.DATA[id].name)
		view.name_buttons[id].pressed.emit()
		assert(view.focused_skill == id and view.detail_title.text == view.Catalog.DATA[id].name)
		assert(view.detail_description.text == view.Catalog.DATA[id].description)
		assert(view.video.stream.resource_path.ends_with("/"+id+".ogv"))
		assert(view.video.is_playing() and view.video.loop)
		await create_timer(.3).timeout
		assert(view.video.stream_position > .1, "actual decoder advances: " + id)
		assert(view.video.get_video_texture().get_width() == 960)
		assert(view.name_buttons[id].get_global_rect().end.y < 668)
		assert(game.skills.selected == original, "browsing never equips")
		if DisplayServer.get_name() != "headless":
			await create_timer(4.3 if id == "rewind" else 1.1).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/skill-browser-"+id+".png")
	view.pause_button.pressed.emit()
	var position: float = view.video.stream_position
	await create_timer(.2).timeout
	assert(is_equal_approx(view.video.stream_position, position))
	assert(view.pause_button.text == "再生")
	view.pause_button.pressed.emit()
	await create_timer(.2).timeout
	assert(view.video.stream_position > position)
	assert(view.get_child(1).name == "SkillBrowser", "no slot bar above the browser")
	view.show_skill("grapple")
	view.equip_buttons[0].pressed.emit()
	assert(game.skills.selected == ["grapple", ""])
	assert(view.equip_buttons[1].disabled and not view.equip_buttons[0].disabled)
	view.show_skill("repulse")
	view.equip_buttons[1].pressed.emit()
	assert(game.skills.valid_selection())
	assert(view.equip_buttons[0].disabled)
	view.show_skill("chrono")
	view.equip_buttons[0].pressed.emit()
	assert(game.skills.selected == ["chrono", "repulse"])
	view.equip_buttons[0].pressed.emit()
	assert(game.skills.selected == ["", "repulse"] and not game.skills.valid_selection())
	assert(not view.equip_buttons[0].disabled and not view.equip_buttons[1].disabled)
	view.equip_buttons[0].pressed.emit()
	view.show_skill("repulse")
	view.equip_buttons[1].pressed.emit()
	assert(game.skills.selected == ["chrono", ""])
	view.equip_buttons[1].pressed.emit()
	assert(game.control_settings.assign("skill_2", KEY_G).is_empty())
	view.refresh_equipment()
	assert(view.equip_buttons[1].text.begins_with("G"))
	var saved = load("res://gameplay/skills/skill_loadout.gd").new()
	saved.path = game.skills.path; saved.load_selection()
	assert(saved.selected == game.skills.selected)
	# Observe a real end-of-stream wrap, not just the loop flag.
	view.show_skill("grapple")
	var previous := 0.0
	var wrapped := false
	for i in 90:
		await create_timer(.1).timeout
		var current: float = view.video.stream_position
		if previous > 1.0 and current < previous:
			wrapped = true
			break
		previous = current
	assert(wrapped and view.video.is_playing(), "preview loops after EOF")
	var player = view.video
	game.select_preparation_tab("play")
	assert(not player.is_playing(), "leaving the tab stops playback immediately")
	game.free(); print("PASS: six name-only entries, matching descriptions/videos, real decoding, pause/resume, EOF loop, equipment/persistence, exit cleanup"); quit()
