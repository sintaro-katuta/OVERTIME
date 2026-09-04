extends SceneTree

const WeaponCatalogData = preload("res://gameplay/weapon_catalog.gd")
const WeaponSelectionViewData = preload("res://gameplay/weapon_selection_view.gd")

func _init() -> void:
	for weapon_id in WeaponCatalogData.WEAPON_IDS:
		var data := WeaponCatalogData.weapon(weapon_id)
		var scene := load(str(data.model_path)) as PackedScene
		assert(scene != null, "%s model must load" % weapon_id)
		var model := scene.instantiate() as Node3D
		assert(model != null, "%s model must be a Node3D" % weapon_id)
		var preview := WeaponSelectionViewData.WeaponPreview.new()
		var bounds := preview._model_bounds(model)
		var span := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
		assert(span > 0.0001, "%s model needs visible geometry" % weapon_id)
		var normalized_span := span * (WeaponSelectionViewData.PREVIEW_SPAN / span)
		assert(is_equal_approx(normalized_span, WeaponSelectionViewData.PREVIEW_SPAN), "%s preview must normalize to the shared span" % weapon_id)
		print("%s: %.2f" % [weapon_id, normalized_span])
		model.free()
		preview.free()
	print("Weapon preview bounds passed: %d models." % WeaponCatalogData.WEAPON_IDS.size())
	quit()
