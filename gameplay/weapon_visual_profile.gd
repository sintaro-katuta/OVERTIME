## Model-space measurements; Styloo barrels point along +X, viewmodels along -Z.
extends RefCounted

const STYLOO_MODELS := {
	"ak47.glb": {"scale": 0.95, "muzzle": Vector3(0.477, 0.0274, 0), "top": 0.0693},
	"awp.glb": {"scale": 0.80, "muzzle": Vector3(0.7842, 0.0418, 0), "top": 0.1424},
	"pew.glb": {"scale": 4.50, "muzzle": Vector3(0.0566, 0.0278, 0.00018), "top": 0.0479},
	"shotgun.glb": {"scale": 1.15, "muzzle": Vector3(0.3171, 0.0427, 0), "top": 0.0652},
	"mac10.glb": {"scale": 2.20, "muzzle": Vector3(0.124, -0.0025, 0), "top": 0.0291},
}

static func for_model(model_path: String) -> Dictionary:
	var preset: Dictionary = STYLOO_MODELS.get(model_path.get_file(), {})
	if preset.is_empty(): return {}
	return {
		"model_rotation_degrees": Vector3(0, 90, 0),
		"model_position": Vector3(0, -0.10, 0),
		"model_scale": preset.scale,
		"muzzle_position": preset.muzzle,
		"muzzle_rotation_degrees": Vector3(0, -90, 0),
		"hip_position": Vector3(0.28, -0.20, -0.48),
		# Keep opaque sights below the crosshair; only the initial AR has usable irons.
		"ads_position": Vector3(0, 0.10 - float(preset.top) * float(preset.scale) - 0.015, -0.38),
	}
