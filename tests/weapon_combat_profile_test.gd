extends SceneTree

const WeaponCatalogData = preload("res://gameplay/weapon_catalog.gd")
const WeaponCombatProfileData = preload("res://gameplay/weapon_combat_profile.gd")

func _init() -> void:
	var errors := WeaponCombatProfileData.validate()
	assert(errors.is_empty(), "\n".join(errors))
	var vanguard := WeaponCombatProfileData.from_catalog("vanguard_556")
	var sidearm := WeaponCombatProfileData.from_catalog("sidearm_9")
	var longshot := WeaponCombatProfileData.from_catalog("longshot_338")
	assert(vanguard.damage == 18)
	assert(sidearm.damage == 28)
	assert(longshot.damage == 95)
	assert(vanguard.fire_interval < sidearm.fire_interval)
	assert(longshot.magazine_capacity == 4)
	assert(sidearm.reload_seconds < vanguard.reload_seconds)
	assert(sidearm.recoil_impulse < vanguard.recoil_impulse)
	assert(longshot.recoil_impulse > vanguard.recoil_impulse)
	for weapon_id in WeaponCatalogData.WEAPON_IDS:
		var profile := WeaponCombatProfileData.from_catalog(weapon_id)
		assert(profile.starting_reserve == profile.magazine_capacity * 6)
		assert(profile.maximum_reserve == profile.magazine_capacity * 9)
	quit()
