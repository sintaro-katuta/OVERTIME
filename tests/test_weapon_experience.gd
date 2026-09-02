extends SceneTree

const WeaponExperienceLedger = preload("res://gameplay/weapon_experience.gd")

func _init() -> void:
	var ledger = WeaponExperienceLedger.new()

	# A headshot's already-calculated direct damage is awarded in full.
	assert(ledger.award_direct_damage(0, 3) == 3)
	assert(ledger.get_experience(0) == 3)

	# Overkill uses the hit amount, not the target's remaining health.
	assert(ledger.award_direct_damage(1, 20) == 20)
	assert(ledger.get_experience(1) == 20)

	# Non-direct damage must not be able to increase the ledger.
	assert(ledger.award_direct_damage(0, 0) == 0)
	assert(ledger.get_experience(0) == 3)

	quit()
