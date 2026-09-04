## Preparation-only attachment editing presentation (Issue #6).
class_name AttachmentEditorView
extends VBoxContainer

signal close_requested

const WeaponCatalogData = preload("res://gameplay/weapon_catalog.gd")
const ProgressionConfigData = preload("res://gameplay/progression_config.gd")

var progression: RefCounted
var weapon_id := ""

func setup(state: RefCounted, target_weapon_id: String) -> void:
	progression = state
	weapon_id = target_weapon_id
	refresh()

func refresh() -> void:
	if not is_node_ready() or progression == null:
		return
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var data := WeaponCatalogData.weapon(weapon_id)
	var state: Dictionary = progression.weapon_progress(weapon_id)
	var level := int(state.level)
	var xp := int(state.xp)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	add_child(header)
	var title := _label("カスタム  ／  %s" % str(data.display_name), 26, Color("72a6a0"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_label("Lv.%02d  ／  XP %d / %d" % [level, xp, ProgressionConfigData.weapon_xp_required(level)], 16, Color("d7e6ff")))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.max_value = maxf(1.0, ProgressionConfigData.weapon_xp_required(level))
	bar.value = xp
	add_child(bar)
	add_child(_label("サイト: 外観枠1個（機能枠を消費しません）　／　機能: 最大3個・同カテゴリ1個", 15, Color("c7d2e0")))
	var changes := _label("性能差分  ／  " + _change_summary(state.equipped_attachment_ids as Array), 15, Color("8ed6ce"))
	changes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(changes)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(tabs)
	_add_attachment_tab(tabs, "サイト", "sight", state)
	for category in data.functional_categories:
		_add_attachment_tab(tabs, _category_label(str(category)), str(category), state)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	add_child(footer)
	var back := Button.new()
	back.text = "武器一覧へ戻る"
	back.custom_minimum_size = Vector2(220, 42)
	back.pressed.connect(close_requested.emit)
	footer.add_child(back)

func _add_attachment_tab(tabs: TabContainer, title: String, category: String, state: Dictionary) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = title
	tabs.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for attachment in WeaponCatalogData.attachments_for(weapon_id):
		if str(attachment.category) != category:
			continue
		list.add_child(_attachment_row(attachment, state))

func _attachment_row(attachment: Dictionary, state: Dictionary) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var unlocked := int(state.level) >= int(attachment.unlock_level)
	var selected := (state.equipped_attachment_ids as Array).has(str(attachment.id))
	var choose := Button.new()
	choose.text = ("✓  " if selected else "") + str(attachment.name) + ("  ／  LOCK Lv.%d" % int(attachment.unlock_level) if not unlocked else "")
	choose.disabled = not unlocked
	choose.alignment = HORIZONTAL_ALIGNMENT_LEFT
	choose.pressed.connect(_toggle_attachment.bind(str(attachment.id)))
	row.add_child(choose)
	var details := "カテゴリ: %s　必要Lv.%d" % [_category_label(str(attachment.category)), int(attachment.unlock_level)]
	if bool(attachment.cosmetic_only):
		details += "　外観のみ・性能変化なし"
	else:
		details += "　効果: %s　／　トレードオフ: %s" % [_dictionary_text(attachment.effect), _dictionary_text(attachment.tradeoff)]
	var info := _label(details, 14, Color("9caeca") if unlocked else Color("677282"))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(info)
	return row

func _toggle_attachment(attachment_id: String) -> void:
	var attachment := WeaponCatalogData.attachment(weapon_id, attachment_id)
	if attachment.is_empty() or int(progression.weapon_progress(weapon_id).level) < int(attachment.unlock_level):
		return
	var equipped: Array[String] = []
	for id in progression.weapon_progress(weapon_id).equipped_attachment_ids:
		equipped.append(str(id))
	if equipped.has(attachment_id):
		equipped.erase(attachment_id)
	elif bool(attachment.cosmetic_only):
		for id in equipped.duplicate():
			if bool(WeaponCatalogData.attachment(weapon_id, id).cosmetic_only):
				equipped.erase(id)
		equipped.append(attachment_id)
	else:
		for id in equipped.duplicate():
			var current := WeaponCatalogData.attachment(weapon_id, id)
			if not bool(current.cosmetic_only) and str(current.category) == str(attachment.category):
				equipped.erase(id)
		var functional := 0
		for id in equipped:
			if not bool(WeaponCatalogData.attachment(weapon_id, id).cosmetic_only): functional += 1
		if functional < 3: equipped.append(attachment_id)
	if progression.set_equipped_attachments(weapon_id, equipped):
		progression.save_to_file()
		refresh()

func _change_summary(equipped: Array) -> String:
	var entries: Array[String] = []
	for id in equipped:
		var attachment := WeaponCatalogData.attachment(weapon_id, str(id))
		if bool(attachment.cosmetic_only):
			continue
		entries.append(_dictionary_text(attachment.effect))
		entries.append(_dictionary_text(attachment.tradeoff))
	return "変更なし" if entries.is_empty() else "  ／  ".join(entries)

func _dictionary_text(values: Dictionary) -> String:
	var entries: Array[String] = []
	for key in values:
		entries.append("%s ×%.2f" % [_stat_label(str(key)), float(values[key])])
	return "、".join(entries)

func _category_label(category: String) -> String:
	return {"sight":"サイト", "laser":"レーザー", "stock":"ストック", "magazine":"マガジン", "muzzle":"マズル", "foregrip":"フォアグリップ"}.get(category, category)

func _stat_label(key: String) -> String:
	return {"hip_spread_multiplier":"腰だめ拡散", "ads_transition_multiplier":"ADS移行", "vertical_recoil_multiplier":"縦反動", "horizontal_recoil_multiplier":"横反動", "move_speed_multiplier":"移動速度", "ads_move_speed_multiplier":"ADS移動", "magazine_capacity_multiplier":"弾倉", "reload_time_multiplier":"リロード", "movement_and_sustained_spread_growth_multiplier":"連射・移動拡散", "functional_slot_cost":"機能枠"}.get(key, key)

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
