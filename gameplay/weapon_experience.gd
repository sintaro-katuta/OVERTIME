extends RefCounted

## Holds earned experience by weapon. Weapon levels and persistence deliberately
## live elsewhere; this ledger only records direct weapon damage.
var totals: Dictionary = {}

func award_direct_damage(weapon_index: int, damage: int) -> int:
	if weapon_index < 0 or damage <= 0:
		return 0
	var awarded := damage
	totals[weapon_index] = get_experience(weapon_index) + awarded
	return awarded

func get_experience(weapon_index: int) -> int:
	return int(totals.get(weapon_index, 0))

func reset() -> void:
	totals.clear()
