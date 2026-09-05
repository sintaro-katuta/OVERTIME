# Run with a rendering display; writes a 10-row HIP/ADS contact sheet to /tmp by default.
extends SceneTree
class MemoryProgression extends "res://gameplay/progression_state.gd":
	func load_from_file(_path := "user://progression.save") -> Error: return OK
	func save_to_file(_path := "user://progression.save") -> Error: return OK
func _init() -> void: call_deferred("capture")
func capture() -> void:
	var game = load("res://main.tscn").instantiate()
	game.progression = MemoryProgression.new()
	root.add_child(game)
	game.start_from_title()
	game.progression.select_weapon("vanguard_556")
	game.begin_run_from_preparation()
	game.set_physics_process(false)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var sheet := Image.create(960, 270 * 10, false, Image.FORMAT_RGB8)
	var ids = game.WeaponCatalogData.WEAPON_IDS.duplicate()
	ids.append("vanguard_556")
	for i in ids.size():
		if i == 9:
			game.progression.player_level = 2
			game.progression.select_skin("vanguard_556", "obsidian_circuit")
		game.equip_weapon_model(ids[i])
		game.ammo = game.active_magazine_capacity()
		game.reserve_ammo = int(game.weapon_combat_profile.starting_reserve)
		await process_frame
		for ads in 2:
			game.aiming = ads == 1
			game.weapon.position = game.get_weapon_ads_position() if ads else game.get_weapon_hip_position()
			game.weapon.rotation = Vector3.ZERO
			game.camera.fov = float(game.WeaponCatalogData.weapon(ids[i]).ads.fov) if ads else 82.0
			game.update_ui()
			game.ui_weapon_title.text = ids[i] + (" ADS" if ads else " HIP") + (" SKIN" if i == 9 else "")
			await process_frame
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			img.resize(480,270)
			img.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(img,Rect2i(0,0,480,270),Vector2i(ads*480,i*270))
	var args := OS.get_cmdline_user_args()
	var dest := args[0] if not args.is_empty() else "/tmp/overtime-weapons.png"
	sheet.save_png(dest)
	print("Saved ", dest)
	game.free()
	quit()
