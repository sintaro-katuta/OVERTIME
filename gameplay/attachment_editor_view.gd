## Equipped-attachment editing only (Issue #13).
class_name AttachmentEditorView
extends VBoxContainer

signal close_requested
signal level_requested(weapon_id: String)

const WeaponCatalogData = preload("res://gameplay/weapon_catalog.gd")
const ProgressionConfigData = preload("res://gameplay/progression_config.gd")

var progression: RefCounted
var weapon_id := ""

func setup(state: RefCounted, target_weapon_id: String) -> void:
	progression = state
	weapon_id = target_weapon_id
	refresh()

func refresh() -> void:
	if not is_node_ready() or progression == null: return
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var weapon: Dictionary = WeaponCatalogData.weapon(weapon_id)
	var state: Dictionary = progression.weapon_progress(weapon_id)
	var header := HBoxContainer.new()
	add_child(header)
	var title := _label("アタッチメント編集  ／  %s" % str(weapon.display_name), 26, Color("72a6a0"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_label("Lv.%02d" % int(state.level), 16, Color("d7e6ff")))
	add_child(_label("装備中の性能  ／  " + _change_summary(state.equipped_attachment_ids as Array), 15, Color("8ed6ce")))
	add_child(_label("サイトは1個、機能アタッチメントは最大3個・同カテゴリ1個", 14, Color("c7d2e0")))
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(tabs)
	_add_category(tabs, "サイト", "sight", state)
	for category in weapon.functional_categories:
		_add_category(tabs, _category_label(str(category)), str(category), state)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	add_child(footer)
	var level_screen := Button.new()
	level_screen.text = "武器レベルを見る"
	level_screen.custom_minimum_size = Vector2(190, 42)
	level_screen.pressed.connect(level_requested.emit.bind(weapon_id))
	footer.add_child(level_screen)
	var back := Button.new()
	back.text = "武器一覧へ戻る"
	back.custom_minimum_size = Vector2(220, 42)
	back.pressed.connect(close_requested.emit)
	footer.add_child(back)

func _add_category(tabs: TabContainer, title: String, category: String, state: Dictionary) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = title
	tabs.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for attachment in WeaponCatalogData.attachments_for(weapon_id):
		if str(attachment.category) == category:
			list.add_child(_attachment_row(attachment, state))

func _attachment_row(attachment: Dictionary, state: Dictionary) -> Control:
	var row := VBoxContainer.new()
	var unlocked := int(state.level) >= int(attachment.unlock_level)
	var selected := (state.equipped_attachment_ids as Array).has(str(attachment.id))
	var choose := Button.new()
	choose.text = ("✓  " if selected else "") + str(attachment.name) + ("  ／  LOCK Lv.%d" % int(attachment.unlock_level) if not unlocked else "")
	choose.disabled = not unlocked
	choose.alignment = HORIZONTAL_ALIGNMENT_LEFT
	choose.pressed.connect(_toggle_attachment.bind(str(attachment.id)))
	row.add_child(choose)
	var detail := "必要Lv.%d　%s" % [int(attachment.unlock_level), _attachment_effect_text(attachment)]
	var info := _label(detail, 14, Color("9caeca") if unlocked else Color("677282"))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(info)
	return row

func _toggle_attachment(attachment_id: String) -> void:
	var attachment := WeaponCatalogData.attachment(weapon_id, attachment_id)
	if attachment.is_empty() or int(progression.weapon_progress(weapon_id).level) < int(attachment.unlock_level): return
	var equipped: Array[String] = []
	for id in progression.weapon_progress(weapon_id).equipped_attachment_ids: equipped.append(str(id))
	if equipped.has(attachment_id):
		equipped.erase(attachment_id)
	elif bool(attachment.cosmetic_only):
		for id in equipped.duplicate():
			if bool(WeaponCatalogData.attachment(weapon_id, id).cosmetic_only): equipped.erase(id)
		equipped.append(attachment_id)
	else:
		for id in equipped.duplicate():
			var current := WeaponCatalogData.attachment(weapon_id, id)
			if not bool(current.cosmetic_only) and str(current.category) == str(attachment.category): equipped.erase(id)
		var functional := 0
		for id in equipped:
			if not bool(WeaponCatalogData.attachment(weapon_id, id).cosmetic_only): functional += 1
		if functional < 3: equipped.append(attachment_id)
	if progression.set_equipped_attachments(weapon_id, equipped):
		progression.save_to_file()
		refresh()

func _attachment_effect_text(attachment: Dictionary) -> String:
	if bool(attachment.cosmetic_only): return "外観のみ・性能変化なし"
	return "効果: %s　／　代償: %s" % [_stats_text(attachment.effect), _stats_text(attachment.tradeoff)]

func _change_summary(equipped: Array) -> String:
	var entries: Array[String] = []
	for id in equipped:
		var attachment := WeaponCatalogData.attachment(weapon_id, str(id))
		if not bool(attachment.cosmetic_only): entries.append(_stats_text(attachment.effect))
	return "変更なし" if entries.is_empty() else "  ／  ".join(entries)

func _stats_text(values: Dictionary) -> String:
	var labels := {"hip_spread_multiplier":"腰だめ精度", "ads_transition_multiplier":"ADS速度", "vertical_recoil_multiplier":"縦反動", "horizontal_recoil_multiplier":"横反動", "move_speed_multiplier":"移動速度", "ads_move_speed_multiplier":"ADS移動", "magazine_capacity_multiplier":"弾倉", "reload_time_multiplier":"リロード", "movement_and_sustained_spread_growth_multiplier":"連射安定性", "functional_slot_cost":"機能枠"}
	var entries: Array[String] = []
	for key in values: entries.append("%s ×%.2f" % [str(labels.get(str(key), key)), float(values[key])])
	return "、".join(entries)

func _category_label(category: String) -> String:
	return {"sight":"サイト", "laser":"レーザー", "stock":"ストック", "magazine":"マガジン", "muzzle":"マズル", "foregrip":"フォアグリップ"}.get(category, category)

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
