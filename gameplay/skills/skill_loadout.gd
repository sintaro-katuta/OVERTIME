extends "res://gameplay/skills/skill_controller.gd"
## Two independent runtimes; the inherited runtime owns slot 1.
const Runtime = preload("res://gameplay/skills/skill_controller.gd")
var second = Runtime.new()
var selected: Array = ["", ""]
var path := "user://skill_loadout.cfg"

func setup(host: Node3D) -> void:
	super.setup(host)
	second.setup(host)
	load_selection()

func valid_selection() -> bool:
	return selected.size() == 2 and Catalog.IDS.has(selected[0]) and Catalog.IDS.has(selected[1]) and selected[0] != selected[1]

func select_skill(slot: int, id: String) -> Error:
	if not main.preparation_open or slot < 0 or slot > 1: return ERR_UNAUTHORIZED
	if not id.is_empty() and (not Catalog.IDS.has(id) or selected[1-slot] == id): return ERR_INVALID_PARAMETER
	selected[slot] = id
	var config := ConfigFile.new()
	config.set_value("loadout", "skills", selected)
	return config.save(path)

func load_selection() -> void:
	selected = ["", ""]
	var config := ConfigFile.new()
	if config.load(path) != OK: return
	var value = config.get_value("loadout", "skills", [])
	if not (value is Array or value is PackedStringArray) or value.size() != 2: return
	for i in 2:
		if value[i] is String and Catalog.IDS.has(value[i]) and not selected.has(value[i]): selected[i] = value[i]

func reset_run() -> void:
	super.reset_run()
	second.reset_run()
	if valid_selection():
		equipped = selected[0]
		second.equipped = selected[1]
	main.has_grapple = equipped == "grapple" or second.equipped == "grapple"

func clear_stage() -> void:
	super.clear_stage()
	second.clear_stage()

func is_rewinding() -> bool:
	return rewinding or second.rewinding

func activate_slot(slot: int) -> bool:
	if is_rewinding(): return false
	return activate() if slot == 0 else second.activate() if slot == 1 else false

func tick(delta: float) -> void:
	super.tick(delta)
	second.tick(delta)

func fire_rate_bonus() -> float:
	return maxf(super.fire_rate_bonus(), second.fire_rate_bonus())

func enemy_force(enemy: Node3D) -> Vector3:
	return super.enemy_force(enemy) + second.enemy_force(enemy)

func shield_blocks(from: Vector3, to: Vector3) -> bool:
	return super.shield_blocks(from, to) or second.shield_blocks(from, to)

# Run rewards no longer offer or replace loadout skills.
func roll_offer(_stage: int, _random: RandomNumberGenerator) -> String:
	return ""

func choose(_accept: bool) -> bool:
	return false
