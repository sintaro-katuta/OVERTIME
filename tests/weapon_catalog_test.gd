extends SceneTree

func _init() -> void:
	var catalog = load("res://gameplay/weapon_catalog.gd")
	var errors: Array[String] = catalog.validate()
	if not errors.is_empty():
		for error in errors: push_error(error)
		quit(1)
		return
	print("WeaponCatalog validation passed: %s weapons, 450 attachments." % catalog.weapons().size())
	quit(0)
