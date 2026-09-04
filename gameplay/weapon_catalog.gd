## Shared, adjustment-friendly weapon and attachment contract.
## UI (#4/#6), progression (#5), and combat systems consume this file; it owns no state.
class_name WeaponCatalog
extends RefCounted

const WEAPON_IDS := [
	"vanguard_556", "kestrel_762", "bastion_556", "sentinel_762", "sidearm_9",
	"viper_9", "longshot_338", "marksman_65", "breach_12",
]
const SIGHT_LEVELS := [1, 6, 11, 16, 21, 26, 31, 36, 41, 46]
const SPECIAL_LEVELS := [12, 17, 22, 27, 32, 37, 42, 47]
const SKINS_BY_WEAPON := {
	"vanguard_556": [{
		"id": "obsidian_circuit",
		"display_name": "Obsidian Circuit",
		"unlock_player_level": 2,
		"model_path": "res://assets/styloo_guns/ak47.glb",
		"hip_position": Vector3(0.30, -0.24, -0.52),
		"ads_position": Vector3(0.02, -0.05, -0.42),
		"model_position": Vector3(0.0, -0.10, 0.0),
		"model_rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"model_scale": 0.50,
		"muzzle_position": Vector3(0.78, 0.0, 0.0),
		"muzzle_rotation_degrees": Vector3(0.0, -90.0, 0.0),
	}],
}

static var _weapons: Dictionary = {}
static var _attachments: Dictionary = {}

static func weapons() -> Dictionary:
	_ensure_built()
	return _weapons

static func weapon(weapon_id: String) -> Dictionary:
	_ensure_built()
	return _weapons.get(weapon_id, {})

static func skins_for(weapon_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in SKINS_BY_WEAPON.get(weapon_id, []):
		result.append((entry as Dictionary).duplicate(true))
	return result

static func skin(weapon_id: String, skin_id: String) -> Dictionary:
	for entry in skins_for(weapon_id):
		if str(entry.id) == skin_id:
			return entry
	return {}

static func attachments_for(weapon_id: String) -> Array[Dictionary]:
	_ensure_built()
	return _attachments.get(weapon_id, [])

static func attachment(weapon_id: String, attachment_id: String) -> Dictionary:
	for entry in attachments_for(weapon_id):
		if entry.id == attachment_id:
			return entry
	return {}

static func loadout_rules() -> Dictionary:
	return {
		"equipped_weapon_count": 1,
		"weapon_change_contexts": ["preparation"],
		"allow_in_run_weapon_change": false,
		"functional_attachment_slots": 3,
		"same_category_limit": 1,
		"sight_slot_limit": 1,
		"sight_uses_functional_slot": false,
	}

static func validate() -> Array[String]:
	_ensure_built()
	var errors: Array[String] = []
	if _weapons.size() != 9:
		errors.append("Expected 9 weapons.")
	for weapon_id in WEAPON_IDS:
		var data := weapon(weapon_id)
		if data.is_empty():
			errors.append("Missing weapon: %s" % weapon_id)
			continue
		for required_key in ["id", "display_name", "initially_unlocked", "fire_mode", "damage", "headshot_multiplier", "fire_rate", "magazine", "reload", "recoil", "falloff", "ballistics", "ads", "ammo", "model_path"]:
			if not data.has(required_key): errors.append("%s missing %s" % [weapon_id, required_key])
		if data.headshot_multiplier != 2.0: errors.append("%s headshot multiplier must be 2." % weapon_id)
		if data.ammo.starting_reserve != data.magazine.capacity * 6: errors.append("%s reserve must be 6 magazines." % weapon_id)
		if data.ammo.maximum_reserve != data.magazine.capacity * 9: errors.append("%s reserve max must be 9 magazines." % weapon_id)
		if data.ammo.cell_amount != data.magazine.capacity * 1.5: errors.append("%s cell amount must be 1.5 magazines." % weapon_id)
		var entries := attachments_for(weapon_id)
		if entries.size() != 50: errors.append("%s must have 50 attachments." % weapon_id)
		var sights := 0
		var functional := 0
		var levels: Dictionary = {}
		var category_counts: Dictionary = {}
		for entry in entries:
			if levels.has(entry.unlock_level): errors.append("%s has duplicate unlock level %s." % [weapon_id, entry.unlock_level])
			levels[entry.unlock_level] = true
			if entry.cosmetic_only:
				sights += 1
				if not SIGHT_LEVELS.has(entry.unlock_level): errors.append("%s sight has invalid unlock level." % weapon_id)
			else:
				functional += 1
				if not data.functional_categories.has(entry.category): errors.append("%s invalid category %s." % [weapon_id, entry.category])
				category_counts[entry.category] = category_counts.get(entry.category, 0) + 1
				if entry.effect.is_empty() or entry.tradeoff.is_empty(): errors.append("%s attachment needs an effect and tradeoff." % entry.id)
		if sights != 10 or functional != 40: errors.append("%s needs 10 sights and 40 functional attachments." % weapon_id)
		for level in SPECIAL_LEVELS:
			if not levels.has(level): errors.append("%s missing specialist level %s." % [weapon_id, level])
		for category in data.functional_categories:
			if category_counts.get(category, 0) != 10 and data.functional_categories.size() == 4: errors.append("%s needs 10 items in %s." % [weapon_id, category])
		for level in range(1, 51):
			if not levels.has(level): errors.append("%s missing unlock level %s." % [weapon_id, level])
	return errors

static func _ensure_built() -> void:
	if not _weapons.is_empty(): return
	_add_weapon("vanguard_556", "Vanguard 5.56", true, "full_auto", 18.0, 7.5, 20, 1.5, ["stock", "magazine", "muzzle", "foregrip"], "res://assets/viewmodels/assault_rifle_west.glb", 25, 45, 0.75, 110, 0.7, 120, "medium", "baseline_vertical")
	_add_weapon("kestrel_762", "Kestrel 7.62", false, "full_auto", 24.0, 6.0, 20, 1.7, ["stock", "magazine", "muzzle", "foregrip"], "res://assets/styloo_guns/ak47.glb", 22, 40, 0.70, 105, 0.75, 120, "medium", "strong_vertical_horizontal")
	_add_weapon("bastion_556", "Bastion 5.56", false, "burst_3", 20.0, 9.0, 18, 1.4, ["laser", "magazine", "muzzle", "foregrip"], "res://assets/styloo_guns/pew.glb", 20, 38, 0.75, 110, 0.7, 110, "medium", "burst_recovery", {"burst_size": 3, "burst_interval": 0.4})
	_add_weapon("sentinel_762", "Sentinel 7.62", false, "semi_auto", 34.0, 4.0, 12, 1.8, ["stock", "magazine", "muzzle", "foregrip"], "res://assets/styloo_guns/awp.glb", 35, 55, 0.85, 110, 0.65, 140, "precision", "large_single")
	_add_weapon("sidearm_9", "Sidearm 9", true, "semi_auto", 28.0, 4.5, 10, 1.1, ["laser", "magazine", "muzzle"], "res://assets/viewmodels/scifi_pistol.glb", 15, 30, 0.65, 70, 1.0, 80, "close", "small")
	_add_weapon("viper_9", "Viper 9", false, "full_auto", 11.0, 12.0, 20, 1.6, ["laser", "stock", "magazine", "muzzle"], "res://assets/styloo_guns/mac10.glb", 10, 22, 0.45, 80, 1.0, 70, "close", "strong_vertical_horizontal")
	_add_weapon("longshot_338", "Longshot .338", false, "bolt_action", 95.0, 0.7, 4, 2.2, ["stock", "magazine", "muzzle"], "res://assets/styloo_guns/awp.glb", 42, 60, 0.90, 170, 0.4, 200, "precision", "very_large_single", {"bolt_cycle_seconds": 1.43})
	_add_weapon("marksman_65", "Marksman 6.5", false, "semi_auto", 40.0, 3.5, 8, 1.6, ["stock", "magazine", "muzzle", "foregrip"], "res://assets/styloo_guns/pew.glb", 30, 50, 0.80, 130, 0.55, 150, "precision", "medium")
	_add_weapon("breach_12", "Breach 12", false, "pump_action", 15.0, 1.0, 6, 0.55, ["laser", "stock", "magazine", "muzzle"], "res://assets/styloo_guns/shotgun.glb", 7, 18, 0.25, 55, 1.2, 35, "close", "pump_recovery", {"pellets": 8, "reload_style": "tube_per_shell", "shoot_after_shell_loaded": true})
	for weapon_id in WEAPON_IDS: _attachments[weapon_id] = _build_attachments(_weapons[weapon_id])

static func _add_weapon(id: String, display_name: String, initially_unlocked: bool, fire_mode: String, damage: float, fire_rate: float, capacity: int, reload_seconds: float, categories: Array, model_path: String, falloff_start: float, falloff_min_distance: float, falloff_min_multiplier: float, velocity: float, gravity_multiplier: float, max_range: float, ads_role: String, recoil_profile: String, extra: Dictionary = {}) -> void:
	_weapons[id] = {
		"id": id, "display_name": display_name, "initially_unlocked": initially_unlocked, "fire_mode": fire_mode,
		"damage": {"body": damage, "pellets": extra.get("pellets", 1)}, "headshot_multiplier": 2.0, "fire_rate": {"shots_per_second": fire_rate, "burst_size": extra.get("burst_size", 1), "burst_interval": extra.get("burst_interval", 0.0), "bolt_cycle_seconds": extra.get("bolt_cycle_seconds", 0.0)},
		"magazine": {"capacity": capacity, "manual_reload_discards_remaining": true},
		"reload": {"seconds": reload_seconds, "automatic_on_empty": true, "automatic_reload_setting": true, "style": extra.get("reload_style", "magazine"), "shoot_after_shell_loaded": extra.get("shoot_after_shell_loaded", false)},
		"recoil": {"profile": recoil_profile, "camera_pitch_yaw_synced": true},
		"falloff": {"start_meters": falloff_start, "minimum_damage_distance_meters": falloff_min_distance, "minimum_multiplier": falloff_min_multiplier},
		"ballistics": {"muzzle_velocity_mps": velocity, "gravity_multiplier": gravity_multiplier, "maximum_range_meters": max_range, "spawn": "muzzle_to_crosshair_target", "collision": "first_enemy_wall_or_cover_no_penetration"},
		"ads": _ads(ads_role), "ammo": {"shared_pool": true, "starting_reserve": capacity * 6, "maximum_reserve": capacity * 9, "cell_amount": capacity * 1.5, "magazine_modifiers_affect_reserve": false},
		"model_path": model_path, "functional_categories": categories,
	}

static func _ads(role: String) -> Dictionary:
	var presets := {"close": [74.0, 0.93, 0.78, 0.13], "medium": [68.0, 0.86, 0.62, 0.18], "precision": [58.0, 0.72, 0.35, 0.24]}
	var values: Array = presets[role]
	return {"role": role, "fov": values[0], "move_speed_multiplier": values[1], "spread_multiplier": values[2], "transition_seconds": values[3], "sight_appearance_changes_stats": false}

static func _build_attachments(data: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var sight_names := ["Iron", "Reflex", "Holo", "Green Dot", "Amber Dot", "Prism", "Circle Dot", "Chevron", "Crosshair", "Precision"]
	for index in SIGHT_LEVELS.size():
		entries.append({"id": "%s_sight_%02d" % [data.id, index + 1], "weapon_id": data.id, "category": "sight", "unlock_level": SIGHT_LEVELS[index], "cosmetic_only": true, "name": sight_names[index] + " Sight", "reticle_color": ["white", "red", "green", "amber"][index % 4], "effect": {}, "tradeoff": {}})
	var regular_levels: Array[int] = []
	for level in range(2, 51):
		if not SIGHT_LEVELS.has(level) and not SPECIAL_LEVELS.has(level): regular_levels.append(level)
	var categories: Array = data.functional_categories
	var common_counts: Array[int] = []
	var special_counts: Array[int] = []
	if categories.size() == 4:
		common_counts = [8, 8, 8, 8]; special_counts = [2, 2, 2, 2]
	else:
		common_counts = [11, 11, 10]; special_counts = [3, 3, 2]
	var level_index := 0
	var special_index := 0
	for category_index in categories.size():
		for item_index in common_counts[category_index]:
			entries.append(_functional_entry(data.id, categories[category_index], item_index, regular_levels[level_index], false))
			level_index += 1
		for item_index in special_counts[category_index]:
			entries.append(_functional_entry(data.id, categories[category_index], item_index, SPECIAL_LEVELS[special_index], true))
			special_index += 1
	return entries

static func _functional_entry(weapon_id: String, category: String, variant: int, unlock_level: int, specialist: bool) -> Dictionary:
	var names := {"laser": "Laser", "stock": "Stock", "magazine": "Magazine", "muzzle": "Muzzle", "foregrip": "Foregrip"}
	var effect := _attachment_effect(category, variant, specialist)
	return {"id": "%s_%s_%s_%02d" % [weapon_id, category, "special" if specialist else "common", variant + 1], "weapon_id": weapon_id, "category": category, "unlock_level": unlock_level, "cosmetic_only": false, "name": ("Special " if specialist else "") + names[category] + " %02d" % (variant + 1), "effect": effect.effect, "tradeoff": effect.tradeoff}

static func _attachment_effect(category: String, variant: int, specialist: bool) -> Dictionary:
	if category == "laser": return {"effect": {"hip_spread_multiplier": 0.75 - minf(variant, 3) * 0.03}, "tradeoff": {"ads_transition_multiplier": 1.05 + (0.05 if specialist else 0.0)}}
	if category == "stock": return {"effect": {"vertical_recoil_multiplier": 0.80 - minf(variant, 3) * 0.02}, "tradeoff": {"move_speed_multiplier": 0.95 - (0.02 if specialist else 0.0)}}
	if category == "magazine":
		if variant % 2 == 0: return {"effect": {"magazine_capacity_multiplier": 1.50}, "tradeoff": {"reload_time_multiplier": 1.25}}
		return {"effect": {"magazine_capacity_multiplier": 0.75}, "tradeoff": {"reload_time_multiplier": 0.75}}
	if category == "muzzle": return {"effect": {"horizontal_recoil_multiplier": 0.80 - minf(variant, 3) * 0.02}, "tradeoff": {"vertical_recoil_multiplier": 1.05 + (0.03 if specialist else 0.0)}}
	# The baseline foregrip's only cost is consuming one of the three functional slots.
	if variant == 0 and not specialist: return {"effect": {"movement_and_sustained_spread_growth_multiplier": 0.75}, "tradeoff": {"functional_slot_cost": 1}}
	return {"effect": {"movement_and_sustained_spread_growth_multiplier": 0.75 - minf(variant, 3) * 0.02}, "tradeoff": {"ads_move_speed_multiplier": 0.95 - (0.02 if specialist else 0.0)}}
