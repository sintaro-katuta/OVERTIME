## Read-only battle-pass-style weapon unlock track (Issue #13).
class_name WeaponLevelView
extends VBoxContainer

signal close_requested

const WeaponCatalogData = preload("res://gameplay/weapon_catalog.gd")
const ProgressionConfigData = preload("res://gameplay/progression_config.gd")
const LEVELS_PER_PAGE := 10
const PAGE_WIDTH := 1160.0

var progression: RefCounted
var weapon_id := ""
var unlock_scroll: ScrollContainer

func setup(state: RefCounted, target_weapon_id: String) -> void:
	progression = state
	weapon_id = target_weapon_id
	refresh()

static func page_start_level(level: int) -> int:
	return clampi(((clampi(level, 1, 50) - 1) / LEVELS_PER_PAGE) * LEVELS_PER_PAGE + 1, 1, 41)

func refresh() -> void:
	if not is_node_ready() or progression == null: return
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var weapon: Dictionary = WeaponCatalogData.weapon(weapon_id)
	var state: Dictionary = progression.weapon_progress(weapon_id)
	var level := int(state.level)
	var header := HBoxContainer.new()
	add_child(header)
	var title := _label("武器レベル  ／  %s" % str(weapon.display_name), 26, Color("72a6a0"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_label("Lv.%02d  ／  XP %d / %d" % [level, int(state.xp), ProgressionConfigData.weapon_xp_required(level)], 16, Color("d7e6ff")))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.max_value = maxf(1.0, ProgressionConfigData.weapon_xp_required(level))
	bar.value = int(state.xp)
	add_child(bar)
	add_child(_label("解除トラック  ／  10レベルごとに横スクロール　　● 解放済み　◆ 現在レベル　🔒 未解放", 15, Color("c7d2e0")))
	_add_unlock_track(state)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	add_child(footer)
	var back := Button.new()
	back.text = "アタッチメント編集へ戻る"
	back.custom_minimum_size = Vector2(220, 42)
	back.pressed.connect(close_requested.emit)
	footer.add_child(back)

func _add_unlock_track(state: Dictionary) -> void:
	unlock_scroll = ScrollContainer.new()
	unlock_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	unlock_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	unlock_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	unlock_scroll.custom_minimum_size = Vector2(0, 400)
	add_child(unlock_scroll)
	var pages := HBoxContainer.new()
	pages.add_theme_constant_override("separation", 28)
	unlock_scroll.add_child(pages)
	for first_level in range(1, 51, LEVELS_PER_PAGE): pages.add_child(_unlock_page(first_level, state))
	call_deferred("_focus_level_page", int(state.level))

func _unlock_page(first_level: int, state: Dictionary) -> Control:
	var page := VBoxContainer.new()
	page.custom_minimum_size = Vector2(PAGE_WIDTH, 0)
	page.add_theme_constant_override("separation", 10)
	var heading := _label("Lv.%02d  —  Lv.%02d     ／     UNLOCK TRACK" % [first_level, first_level + 9], 20, Color("d7e6ff"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(heading)
	var timeline := HBoxContainer.new()
	timeline.add_theme_constant_override("separation", 8)
	timeline.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(timeline)
	for unlock_level in range(first_level, first_level + LEVELS_PER_PAGE): timeline.add_child(_unlock_card(_attachment_at_level(unlock_level), state))
	return page

func _attachment_at_level(unlock_level: int) -> Dictionary:
	for attachment in WeaponCatalogData.attachments_for(weapon_id):
		if int(attachment.unlock_level) == unlock_level: return attachment
	return {}

func _unlock_card(attachment: Dictionary, state: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(108, 300)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	card.add_child(content)
	var level := int(attachment.unlock_level)
	var unlocked := int(state.level) >= level
	var current := int(state.level) == level
	var color := Color("a9e5db") if unlocked else Color("626a78")
	if current: color = Color("58e4ff")
	var level_label := _label("◆ LV.%02d" % level if current else "LV.%02d" % level, 15, color)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(level_label)
	var icon := _label(_category_icon(str(attachment.category)), 42, color)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(icon)
	var category := _label(_category_label(str(attachment.category)).to_upper(), 12, color)
	category.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(category)
	var name := _label(str(attachment.name), 14, Color("ffffff") if unlocked else Color("87909c"))
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(name)
	var status := "● 解放済み" if unlocked else "🔒 LOCK"
	var status_label := _label(status, 13, Color("9dd8ad") if unlocked else Color("747d8b"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(status_label)
	return card

func _focus_level_page(level: int) -> void:
	if unlock_scroll != null:
		unlock_scroll.scroll_horizontal = roundi(((clampi(level, 1, 50) - 1) / LEVELS_PER_PAGE) * (PAGE_WIDTH + 28.0))

func _category_label(category: String) -> String:
	return {"sight":"サイト", "laser":"レーザー", "stock":"ストック", "magazine":"マガジン", "muzzle":"マズル", "foregrip":"フォアグリップ"}.get(category, category)

func _category_icon(category: String) -> String:
	return {"sight":"◉", "laser":"⌁", "stock":"◢", "magazine":"▥", "muzzle":"◌", "foregrip":"┗"}.get(category, "◇")

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
