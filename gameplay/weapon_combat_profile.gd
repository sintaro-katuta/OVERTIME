## Runtime-safe combat values derived exclusively from WeaponCatalog entries.
class_name WeaponCombatProfile
extends RefCounted

const RECOIL_IMPULSES := {
	"small": 0.38,
	"baseline_vertical": 0.70,
	"medium": 0.82,
	"strong_vertical_horizontal": 0.96,
	"large_single": 1.00,
	"very_large_single": 1.00,
	"burst_recovery": 0.74,
	"pump_recovery": 0.90,
}

static func from_catalog(weapon_id: String) -> Dictionary:
	var data := WeaponCatalog.weapon(weapon_id)
	if data.is_empty():
		return {}
	var recoil_profile := str(data.recoil.get("profile", ""))
	return {
		"id": weapon_id,
		"display_name": str(data.display_name),
		"damage": maxi(1, roundi(float(data.damage.get("body", 0.0)))),
		"fire_interval": 1.0 / maxf(0.01, float(data.fire_rate.get("shots_per_second", 0.0))),
		"magazine_capacity": maxi(1, int(data.magazine.get("capacity", 0))),
		"reload_seconds": maxf(0.01, float(data.reload.get("seconds", 0.0))),
		"recoil_impulse": float(RECOIL_IMPULSES.get(recoil_profile, 0.0)),
		"starting_reserve": maxi(0, int(data.ammo.get("starting_reserve", 0))),
		"maximum_reserve": maxi(0, int(data.ammo.get("maximum_reserve", 0))),
		"cell_amount": maxi(1, roundi(float(data.ammo.get("cell_amount", 0.0)))),
	}

static func validate() -> Array[String]:
	var errors: Array[String] = []
	for weapon_id in WeaponCatalog.WEAPON_IDS:
		var profile := from_catalog(weapon_id)
		for key in ["damage", "fire_interval", "magazine_capacity", "reload_seconds", "recoil_impulse", "starting_reserve", "maximum_reserve", "cell_amount"]:
			if not profile.has(key) or float(profile[key]) <= 0.0:
				errors.append("%s has invalid combat %s." % [weapon_id, key])
		if not profile.is_empty() and int(profile.starting_reserve) > int(profile.maximum_reserve):
			errors.append("%s starting reserve exceeds maximum reserve." % weapon_id)
	return errors
