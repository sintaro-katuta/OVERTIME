extends Node
## CC0 asset playback, isolated from game rules. No procedural sound generation.
const ROOT := "res://assets/audio/"
const CUES := {
	"empty": ["ui/click_001", -13.0], "reload_start": ["reload/mag_out", -15.0],
	"reload_end": ["reload/mag_in", -14.0], "shell": ["reload/shell", -14.0], "cycle": ["reload/pump", -16.0],
	"aim": ["reload/pistol", -23.0], "jump": ["impact/impactSoft_medium_000", -15.0],
	"land": ["impact/impactPunch_heavy_000", -13.0], "dash": ["scifi/thrusterFire_000", -18.0],
	"slide": ["ui/scratch_001", -16.0], "stand": ["reload/pistol", -23.0],
	"hit": ["impact/impactMetal_light_000", -15.0], "headshot": ["headshot/thwack-01", -3.5],
	"kill": ["scifi/explosionCrunch_000", -13.0], "bonus": ["ui/confirmation_002", -20.0],
	"hurt": ["impact/impactPunch_heavy_000", -7.0], "charge": ["scifi/laserRetro_001", -17.0],
	"enemy_fire": ["scifi/laserSmall_000", -13.0], "wall": ["impact/impactMetal_light_001", -20.0],
	"pickup_spawn": ["ui/scroll_001", -24.0], "pickup": ["ui/confirmation_001", -14.0],
	"grapple": ["scifi/laserLarge_000", -13.0], "repulse": ["scifi/explosionCrunch_000", -8.0],
	"rewind": ["scifi/forceField_004", -12.0], "vortex": ["scifi/forceField_003", -14.0],
	"chrono": ["scifi/forceField_001", -14.0], "aegis": ["scifi/forceField_000", -13.0],
	"impact": ["scifi/impactMetal_000", -15.0], "skill_end": ["scifi/forceField_002", -21.0],
	"deploy": ["scifi/forceField_002", -15.0], "buff_on": ["ui/maximize_001", -19.0],
	"buff_off": ["ui/minimize_001", -22.0], "ready": ["ui/tick_001", -19.0],
	"skill_error": ["ui/error_001", -20.0], "stage_start": ["ui/open_001", -12.0],
	"wave": ["scifi/computerNoise_000", -12.0], "warning": ["ui/error_003", -12.0],
	"clear": ["ui/confirmation_002", -10.0], "door": ["scifi/doorOpen_000", -10.0],
	"door_stop": ["scifi/doorClose_000", -18.0], "reward": ["ui/confirmation_001", -12.0],
	"level": ["ui/maximize_001", -15.0], "lose": ["ui/error_003", -9.0],
	"win": ["ui/confirmation_002", -8.0], "ui_click": ["ui/click_001", -19.0],
	"ui_hover": ["ui/select_001", -29.0], "ui_back": ["ui/back_001", -18.0],
	"ui_open": ["ui/open_001", -20.0], "ui_toggle": ["ui/switch_001", -21.0],
	"ui_tick": ["ui/tick_001", -27.0], "ui_error": ["ui/error_001", -15.0],
	"equip": ["reload/mag_in", -15.0]
}
var main: Node3D
var streams: Dictionary = {}
var voices: Array[Node] = []
var pending: Array[Dictionary] = []
var last_play: Dictionary = {}
var played: Dictionary = {} # Bounded by cue/source names, useful for integration assertions.
var clock := 0.0
var random := RandomNumberGenerator.new()
var last_position := Vector3.ZERO
var foot_distance := 0.0
var grounded := false
var last_vertical := 0.0
var sliding := false
var low := false
var ads := false
var old_remaining := 0.0
var old_cooldown := 0.0
var old_device := 0.0
var old_grapple := 0.0
var old_rewind := false
var old_buff := false
var hold_time := 0.0
var slide_time := 0.0
var warning_band := 2
var warning_wait := 0.0
var enemy_step_time := 0.0
var player_level := 1
var weapon_level := 1
var weapon_id := ""

func setup(host: Node3D) -> void:
	main = host
	main.control_settings.volume_changed.connect(apply_volume)
	add_to_group("game_audio")
	process_mode = Node.PROCESS_MODE_ALWAYS
	random.seed = 5801
	last_position = main.player.global_position
	for cue in CUES.values(): cache(str(cue[0]))
	for id in main.WeaponCatalogData.WEAPON_IDS: cache(firearm_path(id))
	for surface in ["concrete", "grass", "wood", "snow"]:
		for i in 3: cache("impact/footstep_%s_%03d" % [surface, i])
	for path in ["scifi/engineCircular_000", "scifi/spaceEngineLow_000", "scifi/spaceEngineSmall_000"]: cache(path)
	get_tree().node_added.connect(_node_added)
	_bind_tree(main)

func cache(path: String) -> AudioStream:
	if not streams.has(path): streams[path] = load(ROOT + path + ".wav")
	return streams[path]

func _bind_tree(node: Node) -> void:
	_bind_ui(node)
	for child in node.get_children(): _bind_tree(child)

func _node_added(node: Node) -> void:
	if node is BaseButton or node is Slider: _bind_ui_id.call_deferred(node.get_instance_id())

func _bind_ui_id(id: int) -> void:
	if is_instance_id_valid(id): _bind_ui(instance_from_id(id))

func _bind_ui(node: Node) -> void:
	if not is_instance_valid(node) or node.is_queued_for_deletion() or not main.is_ancestor_of(node): return
	if node.has_meta("sfx_bound"): return
	if node is BaseButton:
		node.set_meta("sfx_bound", true)
		node.pressed.connect(func(): emit("ui_click"))
		node.mouse_entered.connect(func():
			if is_instance_valid(node) and node.is_visible_in_tree() and not node.disabled: emit("ui_hover"))
		node.focus_entered.connect(func():
			if is_instance_valid(node) and node.is_visible_in_tree() and not node.disabled: emit("ui_hover"))
	elif node is Slider:
		node.set_meta("sfx_bound", true)
		node.value_changed.connect(func(_value): emit("ui_tick"))

func emit(id: String, at := Vector3.INF, gain := 0.0) -> bool:
	if not CUES.has(id): push_warning("Unknown sound cue: " + id); return false
	var interval := .055
	if id in ["empty", "skill_error", "ui_error", "warning"]: interval = .3
	if id == "ui_hover": interval = .09
	if clock - float(last_play.get(id, -100.0)) < interval: return false
	if id == "headshot":
		stop_event("hit")
		stop_event("bonus")
	var cue: Array = CUES[id]
	var accepted := play_file(str(cue[0]), float(cue[1]) + gain, at, id.begins_with("ui_"), id)
	if accepted: last_play[id] = clock
	return accepted

func play_file(path: String, db: float, at := Vector3.INF, ui := false, event := "", looping := false) -> bool:
	if not ui and main.game_paused: return false
	if at != Vector3.INF and at.distance_to(main.player.global_position) > 40: return false
	# UI has reserved capacity; gameplay cannot steal feedback or menu sounds.
	var group := "ui" if ui else "world" if at != Vector3.INF else "local"
	var count := 0
	for voice in voices:
		if is_instance_valid(voice) and voice.get_meta("group") == group: count += 1
	var limit := 6 if ui else 18 if group == "world" else 18
	if count >= limit: return false
	var speaker: Node
	if at == Vector3.INF:
		speaker = AudioStreamPlayer.new()
	else:
		speaker = AudioStreamPlayer3D.new()
		speaker.unit_size = 6.0; speaker.max_distance = 40.0
		speaker.attenuation_filter_cutoff_hz = 12000
	speaker.stream = cache(path)
	if speaker.stream == null: speaker.free(); return false
	if looping:
		speaker.stream = speaker.stream.duplicate()
		speaker.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		speaker.stream.loop_begin = 0
		speaker.stream.loop_end = speaker.stream.data.size() / 2
	speaker.set_meta("base_db", db)
	set_voice_volume(speaker)
	speaker.set_meta("group", group)
	speaker.set_meta("event", event)
	add_child(speaker)
	if at != Vector3.INF: speaker.global_position = at
	speaker.finished.connect(func():
		voices.erase(speaker)
		speaker.queue_free())
	voices.append(speaker)
	# Headless tests have no audio device: retain routing/lifetime without starting the dummy mixer.
	speaker.set_meta("remaining", INF if looping else speaker.stream.get_length())
	if DisplayServer.get_name() != "headless": speaker.play()
	played[event] = int(played.get(event, 0)) + 1
	return true

static func firearm_path(id: String) -> String:
	match id:
		"vanguard_556": return "vanguard_candidates/04"
		"breach_12": return "vanguard_candidates/12"
		"kestrel_762", "bastion_556", "sentinel_762", "sidearm_9", "viper_9", "longshot_338", "marksman_65":
			return "firearms_refined/" + id
	return "firearms/" + id

func shot(id: String) -> void:
	play_file(firearm_path(id), -12.0, Vector3.INF, false, "shot_" + id)
	if id in ["longshot_338", "breach_12"]: later("cycle", .28)

func later(id: String, seconds: float, at := Vector3.INF) -> void:
	pending.append({"id": id, "wait": seconds, "at": at})

func stop_event(event: String) -> void:
	for voice in voices.duplicate():
		if is_instance_valid(voice) and voice.get_meta("event") == event:
			voice.stop(); voices.erase(voice); voice.queue_free()

func reset_gameplay() -> void:
	for voice in voices.duplicate():
		if is_instance_valid(voice) and voice.get_meta("group") != "ui":
			voice.stop(); voices.erase(voice); voice.queue_free()
	pending.clear()
	foot_distance = 0; grounded = false; last_vertical = 0
	sliding = false; low = false; ads = false
	old_remaining = 0; old_cooldown = 0; old_device = 0; old_grapple = 0; old_rewind = false; old_buff = false
	hold_time = 0; slide_time = 0; warning_band = 2; warning_wait = 0
	last_position = main.player.global_position
	player_level = main.progression.player_level
	weapon_id = main.weapon_model_id
	weapon_level = int(main.progression.weapon_progress(weapon_id).level)

func _process(delta: float) -> void:
	clock += delta
	for voice in voices.duplicate():
		if not is_instance_valid(voice): continue
		var paused_voice: bool = main.game_paused and voice.get_meta("group") != "ui"
		voice.set_meta("paused", paused_voice)
		if voice.get_meta("group") != "ui": voice.stream_paused = main.game_paused
		if DisplayServer.get_name() == "headless" and not paused_voice:
			voice.set_meta("remaining", float(voice.get_meta("remaining")) - delta)
			if voice.get_meta("remaining") <= 0:
				voices.erase(voice); voice.queue_free()
	if main.game_paused: return
	for i in range(pending.size() - 1, -1, -1):
		pending[i].wait -= delta
		if pending[i].wait <= 0:
			var item: Dictionary = pending[i]; pending.remove_at(i); emit(item.id, item.at)
	if not main.game_active or main.shop_open: return
	movement(delta)
	skill_state(delta)
	if not main.stage_cleared:
		warning_wait = maxf(0, warning_wait - delta)
		var band := 0 if main.time_left <= 5 else 1 if main.time_left <= 10 else 2
		if band < warning_band and warning_wait <= 0: emit("warning"); warning_wait = 3
		warning_band = band
		var level_now := int(main.progression.weapon_progress(main.weapon_model_id).level)
		if main.progression.player_level > player_level or (weapon_id == main.weapon_model_id and level_now > weapon_level): emit("level")
		player_level = main.progression.player_level; weapon_level = level_now; weapon_id = main.weapon_model_id
		enemy_step_time -= delta
		if enemy_step_time <= 0:
			enemy_step_time = .55
			for enemy in main.enemy_root.get_children():
				if enemy.velocity.length() > 1 and enemy.global_position.distance_to(main.player.global_position) < 15:
					play_file("impact/footstep_concrete_%03d" % random.randi_range(0,2), -28, enemy.global_position, false, "enemy_step")

func movement(delta: float) -> void:
	var pos: Vector3 = main.player.global_position
	var distance := Vector2(pos.x-last_position.x, pos.z-last_position.z).length()
	last_position = pos
	var floor_now: bool = main.player.is_on_floor()
	if floor_now and not grounded and last_vertical < -2: emit("land", Vector3.INF, clampf((-last_vertical-5)*.3,-4,3))
	grounded = floor_now; last_vertical = main.player.velocity.y
	if main.aiming != ads: emit("aim"); ads = main.aiming
	if main.slide_controller.active and not sliding: emit("slide"); slide_time = .18
	if not main.slide_controller.active and sliding: stop_event("slide")
	if not main.slide_controller.low and low: emit("stand")
	sliding = main.slide_controller.active; low = main.slide_controller.low
	if sliding:
		slide_time -= delta
		if slide_time <= 0: emit("slide", Vector3.INF, -5); slide_time = .18
	if floor_now and not sliding and not main.skills.rewinding and distance < 1.5:
		foot_distance += distance
		if foot_distance >= 2.6:
			foot_distance = fmod(foot_distance, 2.6)
			var surface := "grass" if main.current_stage in [2,7] else "snow" if main.current_stage in [3,6,9] else "wood" if main.current_stage == 8 else "concrete"
			play_file("impact/footstep_%s_%03d" % [surface,random.randi_range(0,2)], -20, Vector3.INF, false, "footstep")
	elif not floor_now: foot_distance = 0

func skill_state(delta: float) -> void:
	var s = main.skills
	if old_cooldown > 0 and s.cooldown <= 0: emit("ready")
	if old_device > 0 and s.device_time <= 0 and s.remaining > 0: emit("deploy", s.center)
	if old_remaining > 0 and s.remaining <= 0:
		stop_event("skill_hold"); emit("skill_end")
	if old_grapple > 0 and main.grapple_time <= 0:
		stop_event("skill_hold"); emit("skill_end")
	if old_rewind and not s.rewinding:
		stop_event("skill_hold"); emit("skill_end")
	var buff: bool = s.fire_rate_bonus() > 1
	if buff != old_buff: emit("buff_on" if buff else "buff_off")
	var active: bool = s.remaining > 0 or s.rewinding or main.grapple_time > 0
	if active:
		hold_time -= delta
		if hold_time <= 0:
			var file := "engineCircular_000" if s.equipped == "grapple" else "spaceEngineSmall_000" if s.equipped == "rewind" else "spaceEngineLow_000"
			stop_event("skill_hold")
			play_file("scifi/"+file, -31, s.center if s.equipped in ["vortex","chrono"] else Vector3.INF, false, "skill_hold", true)
			hold_time = 1000.0
	else: hold_time = 0
	old_remaining = s.remaining; old_cooldown = s.cooldown; old_device = s.device_time
	old_grapple = main.grapple_time; old_rewind = s.rewinding; old_buff = buff

func _exit_tree() -> void:
	for voice in voices:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null
	voices.clear()
	streams.clear()

func set_voice_volume(voice: Node) -> void:
	var gain: float = main.control_settings.master_volume * main.control_settings.effects_volume
	voice.volume_linear = db_to_linear(float(voice.get_meta("base_db"))) * gain

func apply_volume() -> void:
	for voice in voices:
		if is_instance_valid(voice): set_voice_volume(voice)
