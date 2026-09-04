extends SceneTree

const ProgressionStateData = preload("res://gameplay/progression_state.gd")
const WeaponCatalogData = preload("res://gameplay/weapon_catalog.gd")

func _init() -> void:
	var state := ProgressionStateData.new()
	state.award_weapon_direct_damage("vanguard_556", 10000000)
	var entries := WeaponCatalogData.attachments_for("vanguard_556")
	var sight := str(entries[0].id)
	var stock := "vanguard_556_stock_common_01"
	var magazine := "vanguard_556_magazine_common_01"
	var muzzle := "vanguard_556_muzzle_common_01"
	assert(state.set_equipped_attachments("vanguard_556", [sight, stock, magazine, muzzle]))
	assert(not state.set_equipped_attachments("vanguard_556", [stock, "vanguard_556_stock_common_02"]))
	assert(not state.set_equipped_attachments("vanguard_556", [stock, magazine, muzzle, "vanguard_556_foregrip_common_01"]))
	var saved := state.to_save_data()
	var restored := ProgressionStateData.new()
	assert(restored.load_save_data(saved) == OK)
	assert(restored.weapon_progress("vanguard_556").equipped_attachment_ids == [sight, stock, magazine, muzzle])
	quit()
