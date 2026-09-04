extends SceneTree

const ProgressionStateData = preload("res://gameplay/progression_state.gd")
const WeaponCatalogData = preload("res://gameplay/weapon_catalog.gd")

func _init() -> void:
	var skin := WeaponCatalogData.skin("vanguard_556", "obsidian_circuit")
	assert(not skin.is_empty())
	assert(int(skin.unlock_player_level) == 2)
	assert(str(skin.model_path).begins_with("res://assets/"))
	for key in ["hip_position", "ads_position", "muzzle_position", "muzzle_rotation_degrees", "model_position", "model_rotation_degrees", "model_scale"]:
		assert(skin.has(key), "Skin missing visual adjustment: %s" % key)
	var state := ProgressionStateData.new()
	assert(state.selected_skin_id_for("vanguard_556") == "default")
	assert(not state.select_skin("vanguard_556", "obsidian_circuit"))
	state.player_level = 2
	assert(state.is_skin_unlocked("vanguard_556", "obsidian_circuit"))
	assert(state.select_skin("vanguard_556", "obsidian_circuit"))
	var saved := state.to_save_data()
	var restored := ProgressionStateData.new()
	assert(restored.load_save_data(saved) == OK)
	assert(restored.selected_skin_id_for("vanguard_556") == "obsidian_circuit")
	var downgraded := state.to_save_data()
	downgraded.player_level = 1
	var locked_restore := ProgressionStateData.new()
	assert(locked_restore.load_save_data(downgraded) == OK)
	assert(locked_restore.selected_skin_id_for("vanguard_556") == "default")
	quit()
