extends SceneTree

const ProgressionStateData = preload("res://gameplay/progression_state.gd")
const WeaponSelectionViewData = preload("res://gameplay/weapon_selection_view.gd")

func _init() -> void:
	var state := ProgressionStateData.new()
	var view := WeaponSelectionViewData.new()
	root.add_child.call_deferred(view)
	await process_frame
	view.setup(state)
	await process_frame

	var buttons := _descendants(view, Button)
	var locked := 0
	var selectable := 0
	var has_launch := false
	var has_custom := false
	for button in buttons:
		if button.text.begins_with("LOCK"):
			locked += 1
			assert(button.disabled)
		elif button.text.contains("Lv."):
			selectable += 1
		if button.text == "出撃":
			has_launch = true
		if button.text == "アタッチメント編集":
			has_custom = true
	assert(locked == 7)
	assert(selectable == 2)
	assert(not has_launch)
	assert(has_custom)

	assert(state.select_weapon("sidearm_9"))
	view.refresh()
	await process_frame
	for button in _descendants(view, Button):
		assert(button.text != "出撃")
	view.queue_free()
	quit()

func _descendants(parent: Node, type: Variant) -> Array:
	var result: Array = []
	for child in parent.get_children():
		if is_instance_of(child, type):
			result.append(child)
		result.append_array(_descendants(child, type))
	return result
