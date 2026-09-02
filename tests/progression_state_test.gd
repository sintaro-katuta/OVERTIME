extends SceneTree

const ProgressionStateData = preload("res://gameplay/progression_state.gd")
const ProgressionConfigData = preload("res://gameplay/progression_config.gd")

func _init() -> void:
	assert(ProgressionConfigData.stage_completion_xp(1, 30.9) == 60)
	assert(ProgressionConfigData.stage_completion_xp(2, 15.2) == 45)
	assert(ProgressionConfigData.player_xp_required(1) == 300)
	assert(ProgressionConfigData.player_xp_required(2) == 315)
	assert(ProgressionConfigData.player_xp_required(3) == 331)
	var state = ProgressionStateData.new()
	state.award_player_xp(300 + 315 + 331)
	assert(state.player_level == 4)
	assert(state.award_weapon_direct_damage("vanguard_556", 2000) == 2000)
	assert(state.weapon_progress("vanguard_556").level == 2)
	assert(state.weapon_progress("sidearm_9").level == 1)
	state.award_player_xp(10000000)
	assert(state.player_level == 50)
	assert(state.available_unlock_keys() == 7)
	assert(state.unlock_weapon("kestrel_762"))
	assert(state.select_weapon("kestrel_762"))
	state.award_weapon_direct_damage("kestrel_762", 10000000)
	var attachment_ids: Array[String] = ["kestrel_762_sight_01", "kestrel_762_stock_common_01", "kestrel_762_magazine_common_01", "kestrel_762_muzzle_common_01"]
	assert(state.set_equipped_attachments("kestrel_762", attachment_ids))
	assert(not state.set_equipped_attachments("kestrel_762", ["kestrel_762_stock_common_01", "kestrel_762_stock_common_02"]))
	var path := "user://progression_state_test.save"
	assert(state.save_to_file(path) == OK)
	var restored = ProgressionStateData.new()
	assert(restored.load_from_file(path) == OK)
	assert(restored.selected_weapon_id == "kestrel_762")
	assert(restored.weapon_progress("kestrel_762").equipped_attachment_ids == attachment_ids)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	quit()
