extends RefCounted
## Compatibility accessor for the adopted CC0 recordings (no synthesis).
const FILES := {
	"grapple": "laserLarge_000", "repulse": "explosionCrunch_000",
	"rewind": "forceField_004", "vortex": "forceField_003",
	"chrono": "forceField_001", "aegis": "forceField_000", "impact": "impactMetal_000"
}
static func create(id: String) -> AudioStreamWAV:
	return load("res://assets/audio/scifi/" + str(FILES.get(id, "impactMetal_000")) + ".wav") as AudioStreamWAV
