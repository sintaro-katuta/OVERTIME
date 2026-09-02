## Central, adjustment-friendly values for Issue #5 progression.
class_name ProgressionConfig
extends RefCounted

const PLAYER_LEVEL_CAP := 50
const WEAPON_LEVEL_CAP := 50
const PLAYER_XP_BASE := 300
const WEAPON_XP_BASE := 2000
const LEVEL_XP_GROWTH := 1.05
const UNLOCK_KEY_LEVELS := [5, 10, 15, 20, 30, 40, 50]

static func player_xp_required(current_level: int) -> int:
	return _xp_required(PLAYER_XP_BASE, current_level, PLAYER_LEVEL_CAP)

static func weapon_xp_required(current_level: int) -> int:
	return _xp_required(WEAPON_XP_BASE, current_level, WEAPON_LEVEL_CAP)

static func stage_completion_xp(stage_number: int, remaining_seconds: float) -> int:
	return maxi(0, stage_number + 1) * maxi(0, floori(remaining_seconds))

static func earned_unlock_keys(player_level: int) -> int:
	var count := 0
	for level in UNLOCK_KEY_LEVELS:
		if player_level >= level:
			count += 1
	return count

static func _xp_required(base_xp: int, current_level: int, level_cap: int) -> int:
	if current_level >= level_cap:
		return 0
	return ceili(float(base_xp) * pow(LEVEL_XP_GROWTH, current_level - 1))
