extends SceneTree

const ProgressionStateData = preload("res://gameplay/progression_state.gd")
const WeaponLevelViewData = preload("res://gameplay/weapon_level_view.gd")

func _init() -> void:
	for level in range(1, 51):
		assert(WeaponLevelViewData.page_start_level(level) <= level)
		assert(level < WeaponLevelViewData.page_start_level(level) + 10)
	assert(WeaponLevelViewData.page_start_level(1) == 1)
	assert(WeaponLevelViewData.page_start_level(10) == 1)
	assert(WeaponLevelViewData.page_start_level(11) == 11)
	assert(WeaponLevelViewData.page_start_level(50) == 41)
	call_deferred("_verify_unlock_track")

func _verify_unlock_track() -> void:
	var state := ProgressionStateData.new()
	var view := WeaponLevelViewData.new()
	root.add_child(view)
	view.setup(state, "vanguard_556")
	var track := view.get_child(3) as ScrollContainer
	var pages := track.get_child(0) as HBoxContainer
	assert(pages.get_child_count() == 5)
	for page in pages.get_children():
		assert((page.get_child(1) as HBoxContainer).get_child_count() == 10)
	view.queue_free()
	quit()
