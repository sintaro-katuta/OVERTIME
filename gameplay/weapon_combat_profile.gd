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

# Degrees per shot, mapped from the authored recoil roles.
const CAMERA_KICKS := {
	"small": Vector2(0.35, 0.08), "baseline_vertical": Vector2(0.70, 0.10),
	"medium": Vector2(0.82, 0.20), "strong_vertical_horizontal": Vector2(0.96, 0.65),
	"large_single": Vector2(1.20, 0.15), "very_large_single": Vector2(2.0, 0.20),
	"burst_recovery": Vector2(0.50, 0.10), "pump_recovery": Vector2(1.40, 0.20),
}

static func from_catalog(weapon_id: String) -> Dictionary:
	var data := WeaponCatalog.weapon(weapon_id)
	if data.is_empty():
		return {}
	var recoil_profile := str(data.recoil.get("profile", ""))
	return {
		"id": weapon_id,
		"display_name": str(data.display_name),
		"fire_mode": str(data.fire_mode),
		"burst_size": int(data.fire_rate.burst_size),
		"burst_interval": float(data.fire_rate.burst_interval),
		"bolt_cycle_seconds": float(data.fire_rate.bolt_cycle_seconds),
		"pellets": int(data.damage.pellets),
		"headshot_multiplier": float(data.headshot_multiplier),
		"muzzle_velocity": float(data.ballistics.muzzle_velocity_mps),
		"gravity": 9.8 * float(data.ballistics.gravity_multiplier),
		"maximum_range": float(data.ballistics.maximum_range_meters),
		"falloff": data.falloff.duplicate(true),
		"ads": data.ads.duplicate(true),
		"hip_spread_degrees": {"close": 1.5, "medium": 0.8, "precision": 0.5}[str(data.ads.role)],
		"reload_style": str(data.reload.style),
		"shoot_after_shell_loaded": bool(data.reload.shoot_after_shell_loaded),
		"automatic_reload": bool(data.reload.automatic_on_empty),
		"discard_remaining": bool(data.magazine.manual_reload_discards_remaining),
		"damage": maxi(1, roundi(float(data.damage.get("body", 0.0)))),
		"fire_interval": 1.0 / maxf(0.01, float(data.fire_rate.get("shots_per_second", 0.0))),
		"magazine_capacity": maxi(1, int(data.magazine.get("capacity", 0))),
		"reload_seconds": maxf(0.01, float(data.reload.get("seconds", 0.0))),
		"recoil_impulse": float(RECOIL_IMPULSES.get(recoil_profile, 0.0)),
		"camera_kick": CAMERA_KICKS.get(recoil_profile, Vector2.ZERO),
		"starting_reserve": maxi(0, int(data.ammo.get("starting_reserve", 0))),
		"maximum_reserve": maxi(0, int(data.ammo.get("maximum_reserve", 0))),
		"cell_amount": maxi(1, roundi(float(data.ammo.get("cell_amount", 0.0)))),
	}

static func validate() -> Array[String]:
	var errors: Array[String] = []
	for weapon_id in WeaponCatalog.WEAPON_IDS:
		var profile := from_catalog(weapon_id)
		for key in ["damage", "fire_interval", "magazine_capacity", "reload_seconds", "recoil_impulse", "starting_reserve", "maximum_reserve", "cell_amount", "pellets", "headshot_multiplier", "muzzle_velocity", "gravity", "maximum_range"]:
			if not profile.has(key) or float(profile[key]) <= 0.0:
				errors.append("%s has invalid combat %s." % [weapon_id, key])
		if not profile.is_empty() and int(profile.starting_reserve) > int(profile.maximum_reserve):
			errors.append("%s starting reserve exceeds maximum reserve." % weapon_id)
	return errors

static func damage_at_distance(profile: Dictionary, base_damage: int, distance: float, headshot: bool) -> int:
	var falloff: Dictionary = profile.falloff
	var fraction := clampf(inverse_lerp(float(falloff.start_meters), float(falloff.minimum_damage_distance_meters), distance), 0.0, 1.0)
	var multiplier := lerpf(1.0, float(falloff.minimum_multiplier), fraction)
	if headshot: multiplier *= float(profile.headshot_multiplier)
	return maxi(1, roundi(base_damage * multiplier))

## Eight reproducible, distinct pellet rays in a cone. ADS narrows the cone.
## The catalog has no absolute spread value; 4 degrees is the baseline half-angle.
static func pellet_direction(forward: Vector3, index: int, count: int, ads_multiplier: float) -> Vector3:
	if count <= 1: return forward.normalized()
	var axis := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var right := forward.cross(axis).normalized()
	var up := right.cross(forward).normalized()
	var angle := TAU * float(index) / float(count)
	var radius := tan(deg_to_rad(4.0) * ads_multiplier) * (0.5 if index % 2 == 0 else 1.0)
	return (forward + (right * cos(angle) + up * sin(angle)) * radius).normalized()

static func spread_direction(forward: Vector3, radius: float, angle: float) -> Vector3:
	var axis := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var right := forward.cross(axis).normalized()
	var up := right.cross(forward).normalized()
	return (forward + (right * cos(angle) + up * sin(angle)) * radius).normalized()
