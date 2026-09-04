## Persistent player, weapon, unlock, and attachment progression for Issue #5.
## Presentation code consumes the read-only snapshots returned by this class.
class_name ProgressionState
extends RefCounted

const ProgressionConfigData = preload("res://gameplay/progression_config.gd")
const WeaponCatalogData = preload("res://gameplay/weapon_catalog.gd")
const SAVE_VERSION := 1

var player_level := 1
var player_xp := 0
var unlock_keys_used := 0
var selected_weapon_id := "vanguard_556"
var has_selected_weapon := false
var weapon_states: Dictionary = {}

func _init() -> void:
	_reset_weapon_states()

func award_stage_completion(stage_number: int, remaining_seconds: float) -> int:
	var awarded := ProgressionConfigData.stage_completion_xp(stage_number, remaining_seconds)
	award_player_xp(awarded)
	return awarded

func award_player_xp(amount: int) -> int:
	if amount <= 0 or player_level >= ProgressionConfigData.PLAYER_LEVEL_CAP:
		return 0
	player_xp += amount
	_advance_player_levels()
	return amount

func award_weapon_direct_damage(weapon_id: String, damage: int) -> int:
	if damage <= 0 or not weapon_states.has(weapon_id):
		return 0
	var state: Dictionary = weapon_states[weapon_id]
	if state.level >= ProgressionConfigData.WEAPON_LEVEL_CAP:
		return 0
	state.xp += damage
	_advance_weapon_levels(state)
	weapon_states[weapon_id] = state
	return damage

func available_unlock_keys() -> int:
	return ProgressionConfigData.earned_unlock_keys(player_level) - unlock_keys_used

func unlock_weapon(weapon_id: String) -> bool:
	if not weapon_states.has(weapon_id) or is_weapon_unlocked(weapon_id) or available_unlock_keys() <= 0:
		return false
	var state: Dictionary = weapon_states[weapon_id]
	state.unlocked = true
	weapon_states[weapon_id] = state
	unlock_keys_used += 1
	return true

func is_weapon_unlocked(weapon_id: String) -> bool:
	return weapon_states.has(weapon_id) and bool(weapon_states[weapon_id].unlocked)

func select_weapon(weapon_id: String) -> bool:
	if not is_weapon_unlocked(weapon_id):
		return false
	selected_weapon_id = weapon_id
	has_selected_weapon = true
	return true

func selected_skin_id_for(weapon_id: String) -> String:
	if not weapon_states.has(weapon_id):
		return "default"
	return str(weapon_states[weapon_id].get("selected_skin_id", "default"))

func is_skin_unlocked(weapon_id: String, skin_id: String) -> bool:
	if skin_id == "default":
		return true
	var skin := WeaponCatalogData.skin(weapon_id, skin_id)
	return not skin.is_empty() and player_level >= int(skin.unlock_player_level)

func available_skin_ids(weapon_id: String) -> Array[String]:
	var result: Array[String] = ["default"]
	for skin in WeaponCatalogData.skins_for(weapon_id):
		if is_skin_unlocked(weapon_id, str(skin.id)):
			result.append(str(skin.id))
	return result

func select_skin(weapon_id: String, skin_id: String) -> bool:
	if not is_weapon_unlocked(weapon_id) or not is_skin_unlocked(weapon_id, skin_id):
		return false
	var state: Dictionary = weapon_states[weapon_id]
	state.selected_skin_id = skin_id
	weapon_states[weapon_id] = state
	return true

func set_equipped_attachments(weapon_id: String, attachment_ids: Array[String]) -> bool:
	if not is_weapon_unlocked(weapon_id) or not _is_valid_attachment_loadout(weapon_id, attachment_ids):
		return false
	var state: Dictionary = weapon_states[weapon_id]
	state.equipped_attachment_ids = attachment_ids.duplicate()
	weapon_states[weapon_id] = state
	return true

func weapon_progress(weapon_id: String) -> Dictionary:
	if not weapon_states.has(weapon_id):
		return {}
	var state: Dictionary = weapon_states[weapon_id].duplicate(true)
	state.unlocked_attachment_ids = unlocked_attachment_ids(weapon_id)
	return state

func unlocked_attachment_ids(weapon_id: String) -> Array[String]:
	var result: Array[String] = []
	if not weapon_states.has(weapon_id):
		return result
	var level: int = weapon_states[weapon_id].level
	for attachment in WeaponCatalogData.attachments_for(weapon_id):
		if level >= int(attachment.unlock_level):
			result.append(str(attachment.id))
	return result

func preparation_view() -> Dictionary:
	var weapons: Array[Dictionary] = []
	for weapon_id in WeaponCatalogData.WEAPON_IDS:
		var weapon: Dictionary = WeaponCatalogData.weapon(weapon_id).duplicate(true)
		weapon.progress = weapon_progress(weapon_id)
		weapon.selected_skin_id = selected_skin_id_for(weapon_id)
		weapon.available_skin_ids = available_skin_ids(weapon_id)
		weapons.append(weapon)
	return {
		"player_level": player_level,
		"player_xp": player_xp,
		"player_xp_required": ProgressionConfigData.player_xp_required(player_level),
		"available_unlock_keys": available_unlock_keys(),
		"selected_weapon_id": selected_weapon_id if has_selected_weapon else "",
		"loadout_rules": WeaponCatalogData.loadout_rules(),
		"weapons": weapons,
	}

func save_to_file(path := "user://progression.save") -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_save_data()))
	file.close()
	return OK

func load_from_file(path := "user://progression.save") -> Error:
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK or not json.data is Dictionary:
		return ERR_PARSE_ERROR
	return load_save_data(json.data)

func to_save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"player_level": player_level,
		"player_xp": player_xp,
		"unlock_keys_used": unlock_keys_used,
		"selected_weapon_id": selected_weapon_id,
		"has_selected_weapon": has_selected_weapon,
		"weapon_states": weapon_states.duplicate(true),
	}

func load_save_data(data: Dictionary) -> Error:
	if int(data.get("version", 0)) != SAVE_VERSION:
		return ERR_FILE_UNRECOGNIZED
	_reset_weapon_states()
	player_level = clampi(int(data.get("player_level", 1)), 1, ProgressionConfigData.PLAYER_LEVEL_CAP)
	player_xp = maxi(0, int(data.get("player_xp", 0)))
	unlock_keys_used = clampi(int(data.get("unlock_keys_used", 0)), 0, ProgressionConfigData.earned_unlock_keys(player_level))
	var saved_states: Dictionary = data.get("weapon_states", {})
	for weapon_id in WeaponCatalogData.WEAPON_IDS:
		if not saved_states.has(weapon_id) or not saved_states[weapon_id] is Dictionary:
			continue
		var saved: Dictionary = saved_states[weapon_id]
		var state: Dictionary = weapon_states[weapon_id]
		state.level = clampi(int(saved.get("level", 1)), 1, ProgressionConfigData.WEAPON_LEVEL_CAP)
		state.xp = maxi(0, int(saved.get("xp", 0)))
		state.unlocked = bool(saved.get("unlocked", state.unlocked))
		state.equipped_attachment_ids = _string_array(saved.get("equipped_attachment_ids", []))
		state.selected_skin_id = str(saved.get("selected_skin_id", "default"))
		if not _is_valid_attachment_loadout(weapon_id, state.equipped_attachment_ids):
			state.equipped_attachment_ids = []
		if not is_skin_unlocked(weapon_id, str(state.selected_skin_id)):
			state.selected_skin_id = "default"
		weapon_states[weapon_id] = state
	# Saves made before the preparation screen used selected_weapon_id as the
	# selection contract. Preserve that intent when migrating the old schema.
	has_selected_weapon = bool(data.get("has_selected_weapon", false)) if data.has("has_selected_weapon") else data.has("selected_weapon_id")
	selected_weapon_id = str(data.get("selected_weapon_id", selected_weapon_id))
	if not is_weapon_unlocked(selected_weapon_id):
		selected_weapon_id = "vanguard_556"
		has_selected_weapon = false
	_advance_player_levels()
	for weapon_id in WeaponCatalogData.WEAPON_IDS:
		var state: Dictionary = weapon_states[weapon_id]
		_advance_weapon_levels(state)
		weapon_states[weapon_id] = state
	return OK

func _reset_weapon_states() -> void:
	weapon_states.clear()
	for weapon_id in WeaponCatalogData.WEAPON_IDS:
		var data: Dictionary = WeaponCatalogData.weapon(weapon_id)
		weapon_states[weapon_id] = {"level": 1, "xp": 0, "unlocked": bool(data.initially_unlocked), "equipped_attachment_ids": [], "selected_skin_id": "default"}

func _advance_player_levels() -> void:
	while player_level < ProgressionConfigData.PLAYER_LEVEL_CAP:
		var required := ProgressionConfigData.player_xp_required(player_level)
		if player_xp < required:
			break
		player_xp -= required
		player_level += 1
	if player_level >= ProgressionConfigData.PLAYER_LEVEL_CAP:
		player_xp = 0

func _advance_weapon_levels(state: Dictionary) -> void:
	while int(state.level) < ProgressionConfigData.WEAPON_LEVEL_CAP:
		var required := ProgressionConfigData.weapon_xp_required(int(state.level))
		if int(state.xp) < required:
			break
		state.xp = int(state.xp) - required
		state.level = int(state.level) + 1
	if int(state.level) >= ProgressionConfigData.WEAPON_LEVEL_CAP:
		state.xp = 0

func _is_valid_attachment_loadout(weapon_id: String, attachment_ids: Array[String]) -> bool:
	var rules := WeaponCatalogData.loadout_rules()
	var functional_count := 0
	var sight_count := 0
	var categories: Dictionary = {}
	var unlocked: Dictionary = {}
	for id in unlocked_attachment_ids(weapon_id):
		unlocked[id] = true
	for id in attachment_ids:
		if not unlocked.has(id):
			return false
		var attachment := WeaponCatalogData.attachment(weapon_id, id)
		if attachment.is_empty():
			return false
		if bool(attachment.cosmetic_only):
			sight_count += 1
		else:
			functional_count += 1
			if categories.has(attachment.category):
				return false
			categories[attachment.category] = true
	return sight_count <= int(rules.sight_slot_limit) and functional_count <= int(rules.functional_attachment_slots)

func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for item in value:
		result.append(str(item))
	return result
