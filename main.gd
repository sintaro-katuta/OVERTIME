extends Node3D

const START_TIME := 30.0
const STAGE_ONE_CAP := 45.0
const STAGE_TWO_CAP := 60.0
const STAGE_ONE_KILLS := 8
const STAGE_TWO_KILLS := 14
const NEON_CYAN := Color("72a6a0")
const NEON_PURPLE := Color("8e87a6")
const NEON_RED := Color("c96f55")
const GRAPPLE_RANGE := 32.0
const GRAPPLE_SPEED := 38.0
const HEADSHOT_HEIGHT := 1.38
const MAGAZINE_SIZE := 18
const RELOAD_DURATION := 1.35
const START_RESERVE_AMMO := 72
const MAX_RESERVE_AMMO := 108
const STAGE_ORIGINS := [Vector3(0, 0, 0), Vector3(0, 0, -76)]
const STAGE_START_LOCAL := Vector3(0, 1.0, 17)
const STAGE_ONE_COVERS := [Vector3(-10, 0, -8), Vector3(9, 0, -3), Vector3(-5, 0, 10), Vector3(10, 0, 12), Vector3(-14, 0, 6), Vector3(14, 0, 6)]
const STAGE_TWO_COVERS := [Vector3(-12, 0, -11), Vector3(8, 0, -9), Vector3(-5, 0, 6), Vector3(11, 0, 9), Vector3(-15, 0, 2), Vector3(15, 0, 3)]
const COVER_HALF_EXTENTS := [Vector2(1.5, 1.5), Vector2(1.5, 1.5), Vector2(1.5, 1.5), Vector2(1.5, 1.5), Vector2(2.4, 2.4), Vector2(2.4, 2.4)]
const FALLBACK_SPAWNS := [Vector3(-18, 0, -18), Vector3(18, 0, -18), Vector3(-18, 0, 18), Vector3(18, 0, 18), Vector3(-18, 0, 0), Vector3(18, 0, 0), Vector3(0, 0, -18)]
const HEADSHOT_DAMAGE_MULTIPLIER := 3
const WeaponExperienceLedger = preload("res://gameplay/weapon_experience.gd")
const ProgressionStateData = preload("res://gameplay/progression_state.gd")
const WeaponCatalogData = preload("res://gameplay/weapon_catalog.gd")
const WeaponCombatProfileData = preload("res://gameplay/weapon_combat_profile.gd")
const TitleBackgroundScene = preload("res://gameplay/title_background.tscn")
const WeaponSelectionViewData = preload("res://gameplay/weapon_selection_view.gd")
const AttachmentEditorViewData = preload("res://gameplay/attachment_editor_view.gd")
const WeaponLevelViewData = preload("res://gameplay/weapon_level_view.gd")

var player: CharacterBody3D
var camera: Camera3D
var weapon: Node3D
var muzzle_light: OmniLight3D
var weapon_model_node: Node3D
var muzzle_marker: Marker3D
var weapon_model_index := 0
var weapon_model_id := "vanguard_556"
var weapon_skin_id := "default"
var weapon_visual_data: Dictionary = {}
var weapon_combat_profile: Dictionary = WeaponCombatProfileData.from_catalog("vanguard_556")
var weapon_damage_multiplier := 1.0
var weapon_experience := WeaponExperienceLedger.new()
var progression = ProgressionStateData.new()
var weapon_recoil := 0.0
var weapon_bob := 0.0
var aiming := false
var ammo := MAGAZINE_SIZE
var reserve_ammo := START_RESERVE_AMMO
var reserve_ammo_limit := MAX_RESERVE_AMMO
var fire_rate_multiplier := 1.0
var kill_time_bonus := 0.0
var dash_speed := 22.0
var dash_cooldown_duration := 1.0
var damage_time_loss := 4.0
var owned_rewards: Dictionary = {}
var reward_choices: Array[Dictionary] = []
var reloading := false
var reload_timer := 0.0
var hit_marker_timer := 0.0
var time_left := START_TIME
var time_cap := STAGE_ONE_CAP
var current_stage := 1
var kills := 0
var stage_target := STAGE_ONE_KILLS
var game_active := true
var shop_open := false
var has_grapple := false
var dash_cooldown := 0.0
var shot_cooldown := 0.0
var grapple_cooldown := 0.0
var grapple_time := 0.0
var grapple_target: Enemy
var grapple_kill_window := 0.0
var grapple_kill_target_id := 0
var combo := 0
var combo_timer := 0.0
var hit_invulnerability := 0.0
var spawned_enemies := 0
var stage_wave := 1
var wave_two_spawned := false
var game_paused := false
var pitch := 0.0
var ui_time: Label
var ui_status: Label
var ui_combo: Label
var ui_crosshair: Label
var ui_ammo: Label
var ui_weapon_title: Label
var ui_time_bar: ProgressBar
var ui_grapple: Label
var ui_damage_indicator: Label
var ui_reload_prompt: Label
var ui_event_labels: Array[Label] = []
var ui_time_ring: Control
var ui_minimap: Control
var time_fill_style: StyleBoxFlat
var toast_panel: PanelContainer
var toast_timer := 0.0
var event_messages: Array[String] = ["", "", ""]
var event_timers: Array[float] = [0.0, 0.0, 0.0]
var damage_indicator_timer := 0.0
var damage_source_direction := Vector3.ZERO
var shop: PanelContainer
var reward_title: Label
var reward_body: Label
var reward_buttons: Array[Button] = []
var pause_panel: PanelContainer
var gameplay_hud: Control
var preparation_layer: CanvasLayer
var preparation_panel: PanelContainer
var preparation_tab_buttons: Dictionary = {}
var preparation_content: VBoxContainer
var preparation_level_label: Label
var preparation_action_area: CenterContainer
var preparation_tab := "play"
var preparation_open := false
var weapon_selection_view: Control
var attachment_editor_view: Control
var weapon_level_view: Control
var title_background: Node3D
var title_camera: Camera3D
var title_layer: CanvasLayer
var title_start_button: Button
var title_open := true
var enemy_root: Node3D
var projectile_root: Node3D
var player_bullet_root: Node3D
var pickup_root: Node3D
var rng := RandomNumberGenerator.new()
var stage_origin := STAGE_ORIGINS[0]
var cover_positions: Array[Vector3] = []

class Enemy extends CharacterBody3D:
	var main: Node3D
	var speed := 3.0
	var is_ranger := false
	var health := 2
	var pulse := 0.0
	var dead := false
	var attack_cooldown := 0.8
	var charge_time := 0.0
	var last_position := Vector3.ZERO
	var stuck_time := 0.0
	var body_mesh: MeshInstance3D
	var head_mesh: MeshInstance3D
	var eye_light: OmniLight3D
	func _physics_process(delta: float) -> void:
		if dead or not is_instance_valid(main.player): return
		pulse += delta
		var target: Vector3 = main.player.global_position
		var direction: Vector3 = target - global_position
		direction.y = 0
		var distance := direction.length()
		var move_direction := Vector3.ZERO
		if is_ranger and distance < 9.0: move_direction = -direction.normalized()
		elif distance > (12.0 if is_ranger else 3.4): move_direction = direction.normalized()
		if move_direction.length() > 0.0:
			if global_position.distance_to(last_position) < 0.02: stuck_time += delta
			else: stuck_time = 0.0
			if stuck_time > 0.45:
				move_direction = move_direction.rotated(Vector3.UP, 0.9 if get_instance_id() % 2 == 0 else -0.9)
			velocity = move_direction * speed
			move_and_slide()
		else: velocity = Vector3.ZERO
		last_position = global_position
		attack_cooldown -= delta
		if charge_time > 0.0:
			charge_time -= delta
			if distance > (31.0 if is_ranger else 21.0):
				charge_time = 0.0
				attack_cooldown = 0.35
				eye_light.light_energy = 2.0
				eye_light.light_color = NEON_PURPLE if is_ranger else NEON_RED
				head_mesh.material_override = main.material(NEON_PURPLE if is_ranger else NEON_RED, 4.0)
			elif charge_time <= 0.0:
				eye_light.light_energy = 2.0
				eye_light.light_color = NEON_PURPLE if is_ranger else NEON_RED
				head_mesh.material_override = main.material(NEON_PURPLE if is_ranger else NEON_RED, 4.0)
				var fired: bool = main.spawn_projectile(global_position + Vector3(0, 1.15, 0), main.player.global_position + Vector3(0, 0.55, 0), 21.0 if is_ranger else 15.0)
				attack_cooldown = (main.rng.randf_range(1.65, 2.25) if is_ranger else main.rng.randf_range(1.05, 1.55)) if fired else 0.25
		elif distance < (27.0 if is_ranger else 18.0) and attack_cooldown <= 0.0:
			charge_time = 0.65 if is_ranger else 0.35
			eye_light.light_energy = 5.0
			eye_light.light_color = NEON_CYAN if is_ranger else Color("ffb84d")
			head_mesh.material_override = main.material(NEON_PURPLE if is_ranger else Color("ffb84d"), 6.0)
	func die(headshot: bool, air_kill: bool) -> void:
		if dead: return
		dead = true
		main.on_enemy_killed(self, headshot, air_kill)
		queue_free()
	func take_damage(amount: int, headshot: bool, air_kill: bool) -> bool:
		if dead: return false
		if headshot:
			die(true, air_kill)
			return true
		health -= amount
		main.on_enemy_damaged(health)
		if health <= 0:
			die(false, air_kill)
			return true
		return false

class Projectile extends Area3D:
	var main: Node3D
	var velocity := Vector3.ZERO
	var lifetime := 3.0
	func _physics_process(delta: float) -> void:
		lifetime -= delta
		if lifetime <= 0.0:
			queue_free()
			return
		var next_position := global_position + velocity * delta
		var wall_query := PhysicsRayQueryParameters3D.create(global_position, next_position)
		wall_query.exclude = [main.player.get_rid()]
		wall_query.collision_mask = 1
		if not main.get_world_3d().direct_space_state.intersect_ray(wall_query).is_empty():
			queue_free()
			return
		global_position = next_position
		if is_instance_valid(main.player) and global_position.distance_to(main.player.global_position + Vector3(0, 0.55, 0)) < 0.72:
			main.on_player_hit(-velocity.normalized())
			queue_free()

class PlayerBullet extends MeshInstance3D:
	var main: Node3D
	var velocity := Vector3.ZERO
	var weapon_index := 0
	var direct_damage := 1
	var lifetime := 0.70
	func _physics_process(delta: float) -> void:
		lifetime -= delta
		if lifetime <= 0.0:
			queue_free()
			return
		var next_position := global_position + velocity * delta
		var query := PhysicsRayQueryParameters3D.create(global_position, next_position)
		query.exclude = [main.player.get_rid()]
		query.collision_mask = 1 | 2
		var hit := main.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			global_position = hit.position
			var collider = hit.collider
			if collider is Enemy:
				var is_head: bool = hit.position.y > collider.global_position.y + main.HEADSHOT_HEIGHT
				var effective_damage: int = direct_damage
				if is_head:
					effective_damage *= int(main.HEADSHOT_DAMAGE_MULTIPLIER)
				# Award the calculated hit damage before applying it. This preserves
				# overkill damage, while non-weapon damage never enters this path.
				main.record_weapon_direct_damage(weapon_index, effective_damage)
				collider.take_damage(effective_damage, is_head, false)
			queue_free()
			return
		global_position = next_position

class ShotTracer extends MeshInstance3D:
	var lifetime := 0.055
	func _process(delta: float) -> void:
		lifetime -= delta
		if lifetime <= 0.0: queue_free()

class TimeRing extends Control:
	var remaining_fraction := 1.0
	func _draw() -> void:
		if remaining_fraction <= 0.0: return
		var center := size * 0.5
		draw_arc(center, 36.0, -PI * 0.5, -PI * 0.5 + TAU * remaining_fraction, 40, Color("d96e58"), 3.0, true)

class MiniMap extends Control:
	var main: Node3D
	func map_point(world: Vector3) -> Vector2:
		var local: Vector3 = world - main.stage_origin
		return Vector2((local.x + 30.0) / 60.0 * size.x, (local.z + 30.0) / 60.0 * size.y)
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("111923e8"), true)
		draw_rect(Rect2(Vector2(5, 5), size - Vector2(10, 10)), Color("82939a"), false, 1.0)
		for grid in range(1, 4):
			var offset := size.x * float(grid) / 4.0
			draw_line(Vector2(offset, 5), Vector2(offset, size.y - 5), Color("34424a"), 1.0)
			draw_line(Vector2(5, offset), Vector2(size.x - 5, offset), Color("34424a"), 1.0)
		for cover in main.cover_positions:
			var point := map_point(cover)
			draw_rect(Rect2(point - Vector2(5, 5), Vector2(10, 10)), Color("788078"), true)
		for child in main.enemy_root.get_children():
			var enemy := child as Enemy
			if enemy and not enemy.dead:
				draw_circle(map_point(enemy.global_position), 3.0, Color("9b857c") if enemy.is_ranger else Color("c96f55"))
		var player_point := map_point(main.player.global_position)
		var forward: Vector3 = -main.player.global_transform.basis.z
		var facing: Vector2 = Vector2(forward.x, forward.z).normalized()
		var side: Vector2 = Vector2(-facing.y, facing.x)
		draw_colored_polygon(PackedVector2Array([player_point + facing * 7.0, player_point - facing * 4.0 + side * 4.0, player_point - facing * 4.0 - side * 4.0]), NEON_CYAN)

class PreparationCharacterPreview extends Control:
	func _draw() -> void:
		var center := size * 0.5
		draw_circle(center + Vector2(0, -54), 29, Color("d8e7e5"))
		draw_circle(center + Vector2(-10, -62), 5, Color("1b2731"))
		draw_circle(center + Vector2(10, -62), 5, Color("1b2731"))
		draw_rect(Rect2(center + Vector2(-40, -20), Vector2(80, 94)), Color("263a44"), true)
		draw_rect(Rect2(center + Vector2(-34, -13), Vector2(68, 76)), Color("42636a"), true)
		draw_rect(Rect2(center + Vector2(-30, 4), Vector2(60, 14)), Color("72a6a0"), true)
		draw_line(center + Vector2(-40, -8), center + Vector2(-72, 44), Color("42636a"), 20.0)
		draw_line(center + Vector2(40, -8), center + Vector2(72, 44), Color("42636a"), 20.0)
		draw_line(center + Vector2(-20, 72), center + Vector2(-25, 130), Color("263a44"), 24.0)
		draw_line(center + Vector2(20, 72), center + Vector2(25, 130), Color("263a44"), 24.0)

class AmmoPickup extends Node3D:
	var main: Node3D
	var lifetime := 14.0
	var base_y := 0.45
	func _physics_process(delta: float) -> void:
		if not main.game_active or main.shop_open: return
		lifetime -= delta
		if lifetime <= 0.0:
			queue_free()
			return
		rotation.y += delta * 2.5
		position.y = base_y + sin(Time.get_ticks_msec() * 0.004) * 0.12
		if global_position.distance_to(main.player.global_position) < 1.25:
			main.collect_ammo_cell(main.active_ammo_cell_amount())
			queue_free()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	# Progression is independent from a run, so a retry never erases it.
	progression.load_from_file()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	build_world()
	build_player()
	build_ui()
	build_preparation_ui()
	build_title_background()
	build_title_ui()
	preparation_layer.visible = false
	gameplay_hud.visible = false
	game_active = false
	if OS.get_cmdline_user_args().has("--capture-weapons-screen"):
		call_deferred("_open_weapon_selection_for_capture")

func _open_weapon_selection_for_capture() -> void:
	# Capture the first-run state independently from any local playtest save.
	progression = ProgressionStateData.new()
	start_from_title()
	var capture_args := OS.get_cmdline_user_args()
	if capture_args.has("--capture-sidearm-screen") or capture_args.has("--capture-custom-screen"):
		progression.select_weapon("sidearm_9")
	if capture_args.has("--capture-attachment-loadout"):
		progression.select_weapon("sidearm_9")
		progression.award_weapon_direct_damage("sidearm_9", 10000000)
		progression.set_equipped_attachments("sidearm_9", ["sidearm_9_sight_01", "sidearm_9_laser_common_01", "sidearm_9_magazine_common_01", "sidearm_9_muzzle_common_01"])
	select_preparation_tab("weapons")
	if capture_args.has("--capture-custom-screen") or capture_args.has("--capture-attachment-loadout"):
		show_attachment_placeholder("sidearm_9")

func build_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("17202a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("718092")
	env.ambient_light_energy = 0.9
	env.glow_enabled = false
	environment.environment = env
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -35, 0)
	light.light_color = Color("ffe2b8")
	light.light_energy = 1.5
	add_child(light)
	build_arena(STAGE_ORIGINS[0], 1)
	build_arena(STAGE_ORIGINS[1], 2)
	enemy_root = Node3D.new(); enemy_root.name = "Enemies"; enemy_root.process_mode = Node.PROCESS_MODE_PAUSABLE; add_child(enemy_root)
	projectile_root = Node3D.new(); projectile_root.name = "Projectiles"; projectile_root.process_mode = Node.PROCESS_MODE_PAUSABLE; add_child(projectile_root)
	player_bullet_root = Node3D.new(); player_bullet_root.name = "PlayerBullets"; player_bullet_root.process_mode = Node.PROCESS_MODE_PAUSABLE; add_child(player_bullet_root)
	pickup_root = Node3D.new(); pickup_root.name = "Pickups"; pickup_root.process_mode = Node.PROCESS_MODE_PAUSABLE; add_child(pickup_root)

func build_arena(origin: Vector3, stage: int) -> void:
	var floor := StaticBody3D.new()
	floor.position = origin + Vector3(0, -0.3, 0)
	var floor_mesh := MeshInstance3D.new()
	var box := BoxMesh.new(); box.size = Vector3(60, 0.5, 60)
	floor_mesh.mesh = box; floor_mesh.material_override = material(Color("34404a") if stage == 1 else Color("30394b"))
	floor.add_child(floor_mesh)
	var floor_collision := CollisionShape3D.new(); var floor_shape := BoxShape3D.new(); floor_shape.size = Vector3(60, 0.5, 60); floor_collision.shape = floor_shape; floor.add_child(floor_collision)
	add_child(floor)
	for x in range(-24, 25, 6):
		for z in range(-24, 25, 6):
			if abs(x) == 24 or abs(z) == 24:
				add_block(origin + Vector3(x, 2.2, z), Vector3(5.8, 4.5, 0.35), Color("4a555d") if stage == 1 else Color("484c63"))
			else:
				add_neon_tile(origin + Vector3(x, 0.01, z), NEON_CYAN if stage == 1 else NEON_PURPLE)
	var covers := get_stage_cover_positions(stage)
	for index in covers.size():
		var cover := covers[index]
		var is_low := index >= 4
		add_block(origin + cover + Vector3(0, 0.6 if is_low else 2.0, 0), Vector3(4.8, 1.2, 4.8) if is_low else Vector3(3.0, 4.0, 3.0), Color("65716f") if is_low else (Color("59646a") if stage == 1 else Color("5b5872")))

func material(color: Color, emission_strength := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = color; m.metallic = 0.05; m.roughness = 0.9; m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	if emission_strength > 0:
		m.emission_enabled = true; m.emission = color.darkened(0.35); m.emission_energy_multiplier = minf(emission_strength * 0.12, 0.55)
	return m

func hud_style(border: Color, background := Color("0b1120cc")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new(); style.bg_color=background; style.border_color=border; style.set_border_width_all(1); style.corner_radius_top_left=6; style.corner_radius_top_right=6; style.corner_radius_bottom_left=6; style.corner_radius_bottom_right=6
	style.content_margin_left=14; style.content_margin_right=14; style.content_margin_top=8; style.content_margin_bottom=8
	return style

func add_block(pos: Vector3, size: Vector3, color: Color) -> void:
	var block := StaticBody3D.new(); block.collision_layer = 1; block.position = pos
	var mesh := MeshInstance3D.new(); var b := BoxMesh.new(); b.size = size; mesh.mesh = b; mesh.material_override = material(color); block.add_child(mesh)
	var collision := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size = size; collision.shape = shape; block.add_child(collision)
	add_child(block)

func add_neon_tile(pos: Vector3, color := Color("778e8a")) -> void:
	var mesh := MeshInstance3D.new(); var b := BoxMesh.new(); b.size = Vector3(0.07,0.03,5.0); mesh.mesh = b; mesh.material_override = material(color); mesh.position = pos + Vector3(0,0.01,0); add_child(mesh)

func get_stage_cover_positions(stage: int) -> Array[Vector3]:
	var covers: Array[Vector3] = []
	if stage == 1:
		for cover in STAGE_ONE_COVERS: covers.append(cover)
	else:
		for cover in STAGE_TWO_COVERS: covers.append(cover)
	return covers

func build_player() -> void:
	player = CharacterBody3D.new(); player.name = "Player"; player.position = stage_origin + STAGE_START_LOCAL
	var collider := CollisionShape3D.new(); var shape := CapsuleShape3D.new(); shape.radius = 0.42; shape.height = 1.7; collider.shape = shape; player.add_child(collider)
	camera = Camera3D.new(); camera.name = "Camera3D"; camera.position = Vector3(0,0.6,0); camera.current = false; camera.fov = 82; camera.near = 0.03; player.add_child(camera)
	build_weapon()
	add_child(player)

func build_title_background() -> void:
	title_background = TitleBackgroundScene.instantiate()
	add_child(title_background)
	title_camera = Camera3D.new()
	title_camera.name = "TitleCamera"
	title_camera.position = Vector3(21, 15, 25)
	title_camera.fov = 67.0
	title_camera.cull_mask = 2
	add_child(title_camera)
	title_camera.look_at(Vector3(0, 1.2, -3.0))
	title_camera.current = true

func build_title_ui() -> void:
	title_layer = CanvasLayer.new()
	title_layer.layer = 3
	add_child(title_layer)
	var overlay := ColorRect.new()
	overlay.color = Color("030814b8")
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_layer.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 18)
	center.add_child(layout)
	var title := Label.new()
	title.text = "OVERTIME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color("e7fbff"))
	title.add_theme_color_override("font_shadow_color", NEON_CYAN)
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	layout.add_child(title)
	var tagline := Label.new()
	tagline.text = "TIME IS YOUR LIFE."
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", 21)
	tagline.add_theme_color_override("font_color", NEON_PURPLE.lightened(0.35))
	layout.add_child(tagline)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 42)
	layout.add_child(spacer)
	title_start_button = Button.new()
	title_start_button.text = "RUN START"
	title_start_button.custom_minimum_size = Vector2(270, 58)
	title_start_button.focus_mode = Control.FOCUS_ALL
	title_start_button.add_theme_font_size_override("font_size", 24)
	title_start_button.add_theme_color_override("font_color", NEON_CYAN.lightened(0.4))
	title_start_button.add_theme_stylebox_override("normal", hud_style(NEON_CYAN, Color("0b1520dd")))
	title_start_button.add_theme_stylebox_override("focus", hud_style(NEON_PURPLE, Color("132033ee")))
	title_start_button.pressed.connect(start_from_title)
	layout.add_child(title_start_button)
	title_start_button.call_deferred("grab_focus")

func start_from_title() -> void:
	if not title_open:
		return
	title_open = false
	title_layer.visible = false
	title_background.visible = false
	title_camera.current = false
	camera.current = true
	show_preparation_screen()

func _process(_delta: float) -> void:
	if title_open and is_instance_valid(title_start_button):
		# Keep the action readable while giving it a continuous invitation pulse.
		title_start_button.modulate.a = 0.68 + (sin(Time.get_ticks_msec() * 0.005) + 1.0) * 0.16

func build_weapon() -> void:
	# ビューモデルの前方軸をカメラへ一致させ、右下に構えた状態でも銃口が
	# クロスヘアと敵の方向を向くようにする。
	weapon = Node3D.new(); weapon.name = "PulseRifle"; weapon.position = get_weapon_hip_position(); weapon.rotation = Vector3.ZERO; camera.add_child(weapon)
	var receiver := MeshInstance3D.new(); var receiver_mesh := BoxMesh.new(); receiver_mesh.size = Vector3(0.18, 0.16, 0.55); receiver.mesh = receiver_mesh; receiver.material_override = material(Color("4a5053")); weapon.add_child(receiver)
	var barrel := MeshInstance3D.new(); var barrel_mesh := CylinderMesh.new(); barrel_mesh.top_radius = 0.045; barrel_mesh.bottom_radius = 0.065; barrel_mesh.height = 0.52; barrel_mesh.radial_segments = 6; barrel.mesh = barrel_mesh; barrel.rotation_degrees.x = 90; barrel.position = Vector3(0, 0.015, -0.48); barrel.material_override = material(Color("2d3438")); weapon.add_child(barrel)
	var rail := MeshInstance3D.new(); var rail_mesh := BoxMesh.new(); rail_mesh.size = Vector3(0.11, 0.045, 0.42); rail.mesh = rail_mesh; rail.position = Vector3(0, 0.11, -0.08); rail.material_override = material(Color("9f9d7c")); weapon.add_child(rail)
	var grip := MeshInstance3D.new(); var grip_mesh := BoxMesh.new(); grip_mesh.size = Vector3(0.11, 0.25, 0.13); grip.mesh = grip_mesh; grip.position = Vector3(0, -0.18, 0.12); grip.rotation_degrees.x = -18; grip.material_override = material(Color("252b2e")); weapon.add_child(grip)
	muzzle_light = OmniLight3D.new(); muzzle_light.light_color = NEON_CYAN; muzzle_light.light_energy = 0.0; muzzle_light.omni_range = 4.0; muzzle_light.position = Vector3(0, 0.015, -0.74); weapon.add_child(muzzle_light)
	equip_weapon_model("vanguard_556")

func equip_weapon_model(weapon_id: String) -> void:
	var weapon_data := WeaponCatalogData.weapon(weapon_id)
	if weapon_data.is_empty(): return
	weapon_model_id = weapon_id
	weapon_combat_profile = WeaponCombatProfileData.from_catalog(weapon_id)
	weapon_skin_id = progression.selected_skin_id_for(weapon_id)
	weapon_visual_data = WeaponCatalogData.skin(weapon_id, weapon_skin_id)
	weapon_model_index = 1 if weapon_id == "sidearm_9" else 0
	if is_instance_valid(weapon_model_node): weapon_model_node.queue_free()
	var model_path := str(weapon_visual_data.get("model_path", weapon_data.model_path))
	var model_scene := load(model_path) as PackedScene
	if not model_scene: return
	weapon_model_node = model_scene.instantiate() as Node3D
	if not weapon_model_node: return
	# GLBモデルの原点は一人称武器用ではないため、腰だめ用に補正する。
	weapon_model_node.position = weapon_visual_data.get("model_position", Vector3(0.0, -0.07 if weapon_id == "vanguard_556" else -0.10, 0.0))
	# AR は -Z 前方のまま、ピストルは元モデルの横向き軸を補正して
	# 現在の向きから逆方向へ90度回す。
	weapon_model_node.rotation_degrees = weapon_visual_data.get("model_rotation_degrees", Vector3(0, 90 if weapon_id == "sidearm_9" else 0, 0))
	# 元アセットの実寸が大きく異なるため、実プレイ画面で右手の視界を
	# 占有しすぎない個別スケールにする。
	weapon_model_node.scale = Vector3.ONE * float(weapon_visual_data.get("model_scale", 1.45 if weapon_id == "vanguard_556" else 0.30 if weapon_id == "sidearm_9" else 0.50))
	weapon.add_child(weapon_model_node)
	# 銃身のローカル軸が異なるため、モデルごとに銃口の位置と向きを明示する。
	muzzle_marker = Marker3D.new()
	muzzle_marker.name = "Muzzle"
	muzzle_marker.position = weapon_visual_data.get("muzzle_position", Vector3(1.15, 0, 0) if weapon_id == "sidearm_9" else Vector3(0, 0, -0.72))
	muzzle_marker.rotation_degrees = weapon_visual_data.get("muzzle_rotation_degrees", Vector3(0, -90, 0) if weapon_id == "sidearm_9" else Vector3.ZERO)
	weapon_model_node.add_child(muzzle_marker)
	muzzle_light.reparent(muzzle_marker, false)
	muzzle_light.position = Vector3.ZERO
	for child in weapon.get_children():
		if child is MeshInstance3D and child != weapon_model_node: child.visible = false

func get_weapon_hip_position() -> Vector3:
	if weapon_visual_data.has("hip_position"):
		return weapon_visual_data.hip_position
	return Vector3(0.28, -0.20, -0.48) if weapon_model_index == 0 else Vector3(0.45, -0.36, -0.40)

func get_weapon_ads_position() -> Vector3:
	if weapon_visual_data.has("ads_position"):
		return weapon_visual_data.ads_position
	# AR の照門・照星が画面中央のレティクルと重なる位置。
	# 腰だめとは別に、わずかに左・上へ寄せてアイアンサイトを覗き込む。
	return Vector3(0.0, -0.038, -0.38) if weapon_model_index == 0 else Vector3(0.30, -0.25, -0.52)

func build_ui() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	var root := Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; layer.add_child(root)
	gameplay_hud = root
	var minimap_frame := PanelContainer.new(); minimap_frame.set_anchors_preset(Control.PRESET_TOP_LEFT); minimap_frame.position=Vector2(24,20); minimap_frame.size=Vector2(184,184); minimap_frame.add_theme_stylebox_override("panel",hud_style(Color("82939a"),Color("10171ee8"))); root.add_child(minimap_frame)
	ui_minimap = MiniMap.new(); ui_minimap.main=self; ui_minimap.custom_minimum_size=Vector2(156,156); ui_minimap.mouse_filter=Control.MOUSE_FILTER_IGNORE; minimap_frame.add_child(ui_minimap)
	var life_panel := PanelContainer.new(); life_panel.set_anchors_preset(Control.PRESET_CENTER_TOP); life_panel.position=Vector2(-190,98); life_panel.size=Vector2(380,78); life_panel.add_theme_stylebox_override("panel",hud_style(NEON_CYAN)); root.add_child(life_panel)
	var life_content := VBoxContainer.new(); life_content.add_theme_constant_override("separation",2); life_panel.add_child(life_content)
	var life_title := Label.new(); life_title.text="残り時間"; life_title.add_theme_font_size_override("font_size",12); life_title.add_theme_color_override("font_color",Color("9caeca")); life_content.add_child(life_title)
	ui_time = Label.new(); ui_time.add_theme_font_size_override("font_size",34); ui_time.add_theme_color_override("font_color",NEON_CYAN); life_content.add_child(ui_time)
	ui_time_bar = ProgressBar.new(); ui_time_bar.show_percentage=false; ui_time_bar.custom_minimum_size=Vector2(0,8); time_fill_style=StyleBoxFlat.new(); time_fill_style.bg_color=NEON_CYAN; time_fill_style.corner_radius_top_left=3; time_fill_style.corner_radius_top_right=3; time_fill_style.corner_radius_bottom_left=3; time_fill_style.corner_radius_bottom_right=3; ui_time_bar.add_theme_stylebox_override("fill",time_fill_style); ui_time_bar.add_theme_stylebox_override("background",hud_style(Color("273b59"),Color("101827"))); life_content.add_child(ui_time_bar)
	var objective_panel := PanelContainer.new(); objective_panel.set_anchors_preset(Control.PRESET_CENTER_TOP); objective_panel.position=Vector2(-190,20); objective_panel.size=Vector2(380,70); objective_panel.add_theme_stylebox_override("panel",hud_style(NEON_PURPLE)); root.add_child(objective_panel)
	var objective_content := VBoxContainer.new(); objective_content.alignment=BoxContainer.ALIGNMENT_CENTER; objective_panel.add_child(objective_content)
	var objective_title := Label.new(); objective_title.text="現在の目標"; objective_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; objective_title.add_theme_font_size_override("font_size",11); objective_title.add_theme_color_override("font_color",Color("9caeca")); objective_content.add_child(objective_title)
	ui_status = Label.new(); ui_status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; ui_status.add_theme_font_size_override("font_size",18); ui_status.add_theme_color_override("font_color",Color("f0f6ff")); objective_content.add_child(ui_status)
	toast_panel = PanelContainer.new(); toast_panel.visible=false; root.add_child(toast_panel)
	ui_combo = Label.new(); toast_panel.add_child(ui_combo)
	var ammo_panel := PanelContainer.new(); ammo_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT); ammo_panel.position=Vector2(-270,-125); ammo_panel.size=Vector2(246,88); ammo_panel.add_theme_stylebox_override("panel",hud_style(Color("d7e6ff"))); root.add_child(ammo_panel)
	var ammo_content := VBoxContainer.new(); ammo_panel.add_child(ammo_content)
	ui_weapon_title = Label.new(); ui_weapon_title.text="パルスライフル  ／  弾薬"; ui_weapon_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; ui_weapon_title.add_theme_font_size_override("font_size",11); ui_weapon_title.add_theme_color_override("font_color",Color("9caeca")); ammo_content.add_child(ui_weapon_title)
	ui_ammo = Label.new(); ui_ammo.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; ui_ammo.add_theme_font_size_override("font_size",28); ui_ammo.add_theme_color_override("font_color",Color("d7e6ff")); ammo_content.add_child(ui_ammo)
	var ability_panel := PanelContainer.new(); ability_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT); ability_panel.position=Vector2(-354,-125); ability_panel.size=Vector2(72,88); ability_panel.add_theme_stylebox_override("panel",hud_style(NEON_CYAN)); root.add_child(ability_panel)
	var ability_content := VBoxContainer.new(); ability_content.alignment=BoxContainer.ALIGNMENT_CENTER; ability_panel.add_child(ability_content)
	ui_grapple = Label.new(); ui_grapple.text="⌁"; ui_grapple.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; ui_grapple.add_theme_font_size_override("font_size",30); ability_content.add_child(ui_grapple)
	var ability_key := Label.new(); ability_key.text="Q"; ability_key.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; ability_key.add_theme_font_size_override("font_size",16); ability_key.add_theme_color_override("font_color",Color("f0f6ff")); ability_content.add_child(ability_key)
	ui_crosshair = Label.new(); ui_crosshair.text = "+"; ui_crosshair.set_anchors_preset(Control.PRESET_CENTER); ui_crosshair.position=Vector2(-13,-20); ui_crosshair.size=Vector2(26,40); ui_crosshair.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; ui_crosshair.add_theme_font_size_override("font_size",30); ui_crosshair.add_theme_color_override("font_color",Color.WHITE); root.add_child(ui_crosshair)
	ui_time_ring = TimeRing.new(); ui_time_ring.visible=false; ui_time_ring.set_anchors_preset(Control.PRESET_CENTER); ui_time_ring.position=Vector2(-42,-42); ui_time_ring.size=Vector2(84,84); ui_time_ring.mouse_filter=Control.MOUSE_FILTER_IGNORE; root.add_child(ui_time_ring)
	ui_damage_indicator = Label.new(); ui_damage_indicator.visible=false; ui_damage_indicator.text="▲"; ui_damage_indicator.set_anchors_preset(Control.PRESET_CENTER); ui_damage_indicator.position=Vector2(-18,-120); ui_damage_indicator.size=Vector2(36,36); ui_damage_indicator.pivot_offset=ui_damage_indicator.size*0.5; ui_damage_indicator.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; ui_damage_indicator.add_theme_font_size_override("font_size",30); ui_damage_indicator.add_theme_color_override("font_color",NEON_RED); root.add_child(ui_damage_indicator)
	var event_stack := VBoxContainer.new(); event_stack.set_anchors_preset(Control.PRESET_CENTER); event_stack.position=Vector2(-180,34); event_stack.size=Vector2(360,118); event_stack.alignment=BoxContainer.ALIGNMENT_CENTER; event_stack.mouse_filter=Control.MOUSE_FILTER_IGNORE; root.add_child(event_stack)
	ui_reload_prompt = Label.new(); ui_reload_prompt.visible=false; ui_reload_prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; ui_reload_prompt.add_theme_font_size_override("font_size",18); ui_reload_prompt.add_theme_color_override("font_color",Color("f1e4ba")); event_stack.add_child(ui_reload_prompt)
	for index in 3:
		var event_label := Label.new(); event_label.visible=false; event_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; event_label.add_theme_font_size_override("font_size",15); event_label.add_theme_color_override("font_color",Color("f0f6ff")); event_stack.add_child(event_label); ui_event_labels.append(event_label)
	pause_panel = PanelContainer.new(); pause_panel.visible=false; pause_panel.set_anchors_preset(Control.PRESET_CENTER); pause_panel.position=Vector2(-210,-110); pause_panel.size=Vector2(420,220); pause_panel.mouse_filter=Control.MOUSE_FILTER_STOP
	var pause_style := StyleBoxFlat.new(); pause_style.bg_color=Color("0b1120f5"); pause_style.border_color=NEON_CYAN; pause_style.set_border_width_all(2); pause_style.corner_radius_top_left=10; pause_style.corner_radius_top_right=10; pause_style.corner_radius_bottom_left=10; pause_style.corner_radius_bottom_right=10; pause_panel.add_theme_stylebox_override("panel",pause_style); root.add_child(pause_panel)
	var pause_content := VBoxContainer.new(); pause_content.alignment=BoxContainer.ALIGNMENT_CENTER; pause_content.add_theme_constant_override("separation",14); pause_panel.add_child(pause_content)
	var pause_title := Label.new(); pause_title.text="ポーズ中"; pause_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; pause_title.add_theme_font_size_override("font_size",32); pause_title.add_theme_color_override("font_color",NEON_CYAN); pause_content.add_child(pause_title)
	var pause_text := Label.new(); pause_text.text="ESC でゲームに戻る\nR：リロード　Q：グラップル"; pause_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; pause_text.add_theme_font_size_override("font_size",17); pause_content.add_child(pause_text)
	shop = PanelContainer.new(); shop.visible = false; shop.set_anchors_preset(Control.PRESET_CENTER); shop.position = Vector2(-280,-180); shop.size = Vector2(560,360); shop.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new(); style.bg_color = Color("111a2bf2"); style.border_color = NEON_CYAN; style.set_border_width_all(2); style.corner_radius_top_left=10; style.corner_radius_top_right=10; style.corner_radius_bottom_left=10; style.corner_radius_bottom_right=10; shop.add_theme_stylebox_override("panel",style); root.add_child(shop)
	var content := VBoxContainer.new(); content.add_theme_constant_override("separation",12); shop.add_child(content)
	reward_title = Label.new(); reward_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; reward_title.add_theme_font_size_override("font_size",21); reward_title.add_theme_color_override("font_color",NEON_CYAN); content.add_child(reward_title)
	reward_body = Label.new(); reward_body.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; reward_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; reward_body.add_theme_font_size_override("font_size",15); content.add_child(reward_body)
	for index in 3:
		var reward_button := Button.new(); reward_button.add_theme_font_size_override("font_size",16); reward_button.pressed.connect(select_reward.bind(index)); content.add_child(reward_button); reward_buttons.append(reward_button)

func build_preparation_ui() -> void:
	preparation_layer = CanvasLayer.new()
	preparation_layer.layer = 2
	add_child(preparation_layer)
	var overlay := ColorRect.new()
	overlay.color = Color("071019f2")
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	preparation_layer.add_child(overlay)
	preparation_panel = PanelContainer.new()
	preparation_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 36)
	preparation_panel.add_theme_stylebox_override("panel", hud_style(NEON_CYAN, Color("0d1724f5")))
	overlay.add_child(preparation_panel)
	preparation_level_label = Label.new()
	preparation_level_label.position = Vector2(62, 52)
	preparation_level_label.size = Vector2(280, 40)
	preparation_level_label.add_theme_font_size_override("font_size", 21)
	preparation_level_label.add_theme_color_override("font_color", Color("f0f6ff"))
	overlay.add_child(preparation_level_label)
	preparation_action_area = CenterContainer.new()
	preparation_action_area.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	preparation_action_area.offset_top = -148
	preparation_action_area.offset_bottom = -68
	overlay.add_child(preparation_action_area)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 20)
	preparation_panel.add_child(layout)
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	layout.add_child(header)
	var title := Label.new()
	title.text = "RUN PREPARATION"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", NEON_CYAN)
	header.add_child(title)
	var tab_row := HBoxContainer.new()
	tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_row.add_theme_constant_override("separation", 12)
	header.add_child(tab_row)
	for tab_data in [["play", "プレイ"], ["weapons", "武器"], ["settings", "設定"]]:
		var tab_button := Button.new()
		tab_button.custom_minimum_size = Vector2(150, 42)
		tab_button.text = tab_data[1]
		tab_button.add_theme_font_size_override("font_size", 18)
		tab_button.pressed.connect(select_preparation_tab.bind(tab_data[0]))
		tab_row.add_child(tab_button)
		preparation_tab_buttons[tab_data[0]] = tab_button
	var divider := HSeparator.new()
	layout.add_child(divider)
	preparation_content = VBoxContainer.new()
	preparation_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preparation_content.alignment = BoxContainer.ALIGNMENT_CENTER
	preparation_content.add_theme_constant_override("separation", 14)
	layout.add_child(preparation_content)
	select_preparation_tab("play")

func select_preparation_tab(tab: String) -> void:
	preparation_tab = tab
	for key in preparation_tab_buttons:
		var tab_button := preparation_tab_buttons[key] as Button
		tab_button.disabled = key == tab
		tab_button.add_theme_color_override("font_color", NEON_CYAN if key == tab else Color("c7d2e0"))
	for child in preparation_content.get_children():
		preparation_content.remove_child(child)
		child.queue_free()
	for child in preparation_action_area.get_children():
		preparation_action_area.remove_child(child)
		child.queue_free()
	preparation_level_label.visible = tab == "play"
	match tab:
		"play": build_preparation_play_tab()
		"weapons": build_preparation_weapons_tab()
		"settings": build_preparation_placeholder("設定", "設定項目は後続タスクで追加されます。")

func build_preparation_weapons_tab() -> void:
	weapon_selection_view = WeaponSelectionViewData.new()
	weapon_selection_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	weapon_selection_view.custom_requested.connect(show_attachment_placeholder)
	weapon_selection_view.launch_requested.connect(begin_run_from_preparation)
	preparation_content.add_child(weapon_selection_view)
	weapon_selection_view.setup(progression)

func show_attachment_placeholder(weapon_id: String) -> void:
	for child in preparation_content.get_children():
		preparation_content.remove_child(child)
		child.queue_free()
	attachment_editor_view = AttachmentEditorViewData.new()
	attachment_editor_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	attachment_editor_view.close_requested.connect(select_preparation_tab.bind("weapons"))
	attachment_editor_view.level_requested.connect(show_weapon_level_view)
	preparation_content.add_child(attachment_editor_view)
	attachment_editor_view.setup(progression, weapon_id)

func show_weapon_level_view(weapon_id: String) -> void:
	for child in preparation_content.get_children():
		preparation_content.remove_child(child)
		child.queue_free()
	weapon_level_view = WeaponLevelViewData.new()
	weapon_level_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	weapon_level_view.close_requested.connect(show_attachment_placeholder.bind(weapon_id))
	preparation_content.add_child(weapon_level_view)
	weapon_level_view.setup(progression, weapon_id)

func build_preparation_play_tab() -> void:
	var view := progression.preparation_view()
	preparation_level_label.text = "PLAYER LEVEL  %02d" % int(view.player_level)
	var preview := PreparationCharacterPreview.new()
	preview.custom_minimum_size = Vector2(220, 250)
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preparation_content.add_child(preview)
	var operator_label := Label.new()
	operator_label.text = "OPERATOR  //  PLAYER"
	operator_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	operator_label.add_theme_font_size_override("font_size", 16)
	operator_label.add_theme_color_override("font_color", Color("9caeca"))
	preparation_content.add_child(operator_label)
	var selected_weapon_id := str(view.selected_weapon_id)
	if selected_weapon_id.is_empty():
		var choose_weapon := Button.new()
		choose_weapon.text = "武器を選択"
		choose_weapon.custom_minimum_size = Vector2(280, 52)
		choose_weapon.focus_mode = Control.FOCUS_ALL
		choose_weapon.add_theme_font_size_override("font_size", 20)
		choose_weapon.pressed.connect(select_preparation_tab.bind("weapons"))
		preparation_action_area.add_child(choose_weapon)
		choose_weapon.grab_focus()
		return
	var weapon_name := selected_weapon_id
	for weapon_data in view.weapons:
		if str(weapon_data.id) == selected_weapon_id:
			weapon_name = str(weapon_data.display_name)
			break
	var selected_weapon := Label.new()
	selected_weapon.text = "選択中の武器  //  %s" % weapon_name
	selected_weapon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_weapon.add_theme_font_size_override("font_size", 20)
	selected_weapon.add_theme_color_override("font_color", NEON_CYAN)
	preparation_content.add_child(selected_weapon)
	var launch_hint := Label.new()
	launch_hint.text = "出撃は［武器］タブの「出撃」操作から開始します。"
	launch_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	launch_hint.add_theme_font_size_override("font_size", 16)
	launch_hint.add_theme_color_override("font_color", Color("c7d2e0"))
	preparation_content.add_child(launch_hint)

func build_preparation_placeholder(title_text: String, body_text: String) -> void:
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", NEON_CYAN)
	preparation_content.add_child(title)
	var body := Label.new()
	body.text = body_text
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(560, 0)
	body.add_theme_font_size_override("font_size", 17)
	body.add_theme_color_override("font_color", Color("c7d2e0"))
	preparation_content.add_child(body)

func show_preparation_screen() -> void:
	select_preparation_tab("play")
	preparation_open = true
	game_active = false
	shop_open = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	gameplay_hud.visible = false
	preparation_layer.visible = true

func begin_run_from_preparation() -> void:
	# Issue #4 owns the UI action that calls this once a weapon has been selected.
	if str(progression.preparation_view().selected_weapon_id).is_empty():
		select_preparation_tab("weapons")
		return
	preparation_open = false
	preparation_layer.visible = false
	gameplay_hud.visible = true
	restart_run()

func _input(event: InputEvent) -> void:
	if preparation_open:
		return
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		if game_active and not shop_open: set_game_pause(not game_paused)
		return
	if event is InputEventKey and event.keycode == KEY_R and event.pressed and not event.echo:
		if not game_active: restart_run()
		elif not shop_open and not game_paused: begin_reload()
		return
	if not game_active or shop_open or game_paused: return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x * 0.0028)
		pitch = clamp(pitch - event.relative.y * 0.0028, -1.35, 1.35); camera.rotation.x = pitch
	if event.is_action_pressed("shoot"): shoot()
	if event.is_action_pressed("grapple"): grapple()

func _physics_process(delta: float) -> void:
	if not game_active or shop_open or game_paused: return
	shot_cooldown = max(0.0, shot_cooldown-delta); dash_cooldown=max(0.0,dash_cooldown-delta); grapple_cooldown=max(0.0,grapple_cooldown-delta); grapple_kill_window=max(0.0,grapple_kill_window-delta); hit_invulnerability=max(0.0,hit_invulnerability-delta)
	weapon_recoil = max(0.0, weapon_recoil - delta * 7.0)
	aiming = Input.is_action_pressed("aim")
	weapon_bob += Vector2(player.velocity.x, player.velocity.z).length() * delta * 0.55
	var bob_offset := Vector3(sin(weapon_bob) * 0.012, abs(cos(weapon_bob * 2.0)) * 0.01, 0) if not aiming else Vector3.ZERO
	var weapon_target := (get_weapon_ads_position() if aiming else get_weapon_hip_position()) + bob_offset + Vector3(0, 0, weapon_recoil * 0.18)
	weapon.position = weapon.position.lerp(weapon_target, minf(1.0, delta * 14.0))
	# ADS 中は横方向・ロール方向の傾きをゼロにして、照門、照星、
	# 画面中央のレティクルが一直線になる姿勢へ補間する。
	# モデルはカメラ前方に揃える。反動の上向きピッチだけを残し、腰だめ時の
	# 固定ヨー／ロールによって銃口が照準から外れないようにする。
	var weapon_rotation_target := Vector3(deg_to_rad(-weapon_recoil * 12.0), 0.0, 0.0)
	weapon.rotation = weapon.rotation.lerp(weapon_rotation_target, minf(1.0, delta * 14.0))
	# ピストルには覗けるアイアンサイトがないため、過度に画面を拡大しない。
	var target_fov := 64.0 if weapon_model_index == 0 else 74.0
	camera.fov = lerpf(camera.fov, target_fov if aiming else 82.0, minf(1.0, delta * 13.0))
	muzzle_light.light_energy = max(0.0, muzzle_light.light_energy - delta * 26.0)
	if reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			reloading = false
			if game_active:
				var loaded := mini(active_magazine_capacity() - ammo, reserve_ammo)
				ammo += loaded; reserve_ammo -= loaded
				add_time(0.0, "リロード完了")
	if grapple_kill_window <= 0.0: grapple_kill_target_id = 0
	combo_timer = max(0.0, combo_timer-delta)
	hit_marker_timer = max(0.0, hit_marker_timer-delta)
	toast_timer = max(0.0, toast_timer-delta)
	damage_indicator_timer = max(0.0, damage_indicator_timer-delta)
	for index in 3: event_timers[index] = maxf(0.0, event_timers[index] - delta)
	if combo_timer <= 0.0 and combo > 0:
		combo = 0
	time_left -= delta
	if time_left <= 0.0: end_run(); return
	if grapple_time > 0.0 and is_instance_valid(grapple_target) and not grapple_target.dead:
		grapple_time -= delta
		var pull := grapple_target.global_position + Vector3(0, 0.85, 0) - player.global_position
		player.velocity = pull.normalized() * GRAPPLE_SPEED
		if pull.length() < 1.8: finish_grapple(true)
		elif grapple_time <= 0.0: finish_grapple(false)
	else:
		if grapple_time > 0.0: finish_grapple(false)
		var input := Input.get_vector("move_left","move_right","move_forward","move_back")
		var direction := (player.global_transform.basis * Vector3(input.x,0,input.y)); direction.y=0; direction=direction.normalized()
		var speed := 6.2 if aiming else 8.0
		if Input.is_action_just_pressed("dash") and dash_cooldown <= 0 and direction.length() > 0:
			speed = dash_speed; dash_cooldown=dash_cooldown_duration; add_time(0.0,"ダッシュ")
		player.velocity.x = direction.x * speed; player.velocity.z = direction.z * speed
		if not player.is_on_floor(): player.velocity.y -= 22.0*delta
		if Input.is_action_just_pressed("jump") and player.is_on_floor(): player.velocity.y=8.5
	player.move_and_slide()
	if Input.is_action_pressed("shoot") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: shoot()
	update_ui()

func shoot() -> void:
	if shot_cooldown > 0: return
	if reloading: return
	if ammo <= 0:
		shot_cooldown=0.2
		add_time(0.0, "弾倉が空です　Rでリロード")
		return
	shot_cooldown = active_fire_interval() / fire_rate_multiplier; ammo -= 1
	weapon_recoil = min(1.0, weapon_recoil + active_recoil_impulse()); muzzle_light.light_energy = 7.0
	spawn_player_bullet()

func spawn_player_bullet() -> void:
	if not is_instance_valid(muzzle_marker): return
	# まずカメラ中央（クロスヘア）の狙い地点を求め、そこへ銃口から実弾を飛ばす。
	# これにより、弾は見た目には銃口から出つつ、必ずクロスヘアの中心へ収束する。
	var ray_from := camera.global_position
	var ray_direction := -camera.global_transform.basis.z
	var aim_query := PhysicsRayQueryParameters3D.create(ray_from, ray_from + ray_direction * 70.0)
	aim_query.exclude = [player.get_rid()]
	aim_query.collision_mask = 1 | 2
	var aim_hit := get_world_3d().direct_space_state.intersect_ray(aim_query)
	var aim_point: Vector3 = aim_hit.position if not aim_hit.is_empty() else ray_from + ray_direction * 70.0
	var direction := aim_point - muzzle_marker.global_position
	if direction.length_squared() < 0.001: return
	var bullet := PlayerBullet.new()
	bullet.main = self
	bullet.weapon_index = weapon_model_index
	bullet.direct_damage = get_weapon_direct_damage(weapon_model_index)
	bullet.global_position = muzzle_marker.global_position
	bullet.velocity = direction.normalized() * 96.0
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.025; mesh.bottom_radius = 0.045; mesh.height = 0.42; mesh.radial_segments = 6
	bullet.mesh = mesh
	bullet.material_override = material(NEON_CYAN, 10.0)
	bullet.look_at(bullet.global_position + direction, Vector3.UP)
	bullet.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
	var light := OmniLight3D.new()
	light.light_color = NEON_CYAN; light.light_energy = 1.8; light.omni_range = 1.3
	bullet.add_child(light)
	player_bullet_root.add_child(bullet)

func grapple() -> void:
	if not has_grapple or grapple_cooldown > 0.0: return
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from + -camera.global_transform.basis.z * GRAPPLE_RANGE)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider is Enemy:
		add_time(0.0, "グラップル：照準内に敵が必要です")
		return
	grapple_target = hit.collider
	grapple_time = 0.9
	grapple_cooldown = 2.5
	add_time(0.0, "グラップル起動")

func finish_grapple(reached_target: bool) -> void:
	grapple_time = 0.0
	if reached_target and is_instance_valid(grapple_target):
		grapple_kill_target_id = grapple_target.get_instance_id()
		grapple_kill_window = 1.5
		add_time(0.0, "グラップルキル受付中")
	grapple_target = null

func spawn_enemy(pos: Vector3, ranger := false) -> void:
	var e := Enemy.new(); e.main=self; e.position=pos; e.is_ranger=ranger; e.health=3 if ranger else 2; e.speed=2.35 if ranger else 3.0; e.collision_layer=2; e.collision_mask=1; e.attack_cooldown=rng.randf_range(0.7,1.6)
	var collider := CollisionShape3D.new(); var capsule := CapsuleShape3D.new(); capsule.radius=0.45; capsule.height=1.8; collider.shape=capsule; collider.position.y=0.9; e.add_child(collider)
	var body := MeshInstance3D.new(); var torso := BoxMesh.new(); torso.size=Vector3(0.7,0.72,0.34); body.mesh=torso; body.position.y=1.0; body.material_override=material(Color("4b4741")); e.body_mesh=body; e.add_child(body)
	for side in [-1.0, 1.0]:
		var arm := MeshInstance3D.new(); var arm_mesh := BoxMesh.new(); arm_mesh.size=Vector3(0.16,0.62,0.2); arm.mesh=arm_mesh; arm.position=Vector3(side*0.47, 1.0, 0); arm.rotation_degrees.z=side*12; arm.material_override=material(Color("716958")); e.add_child(arm)
		var leg := MeshInstance3D.new(); var leg_mesh := BoxMesh.new(); leg_mesh.size=Vector3(0.2,0.6,0.23); leg.mesh=leg_mesh; leg.position=Vector3(side*0.2, 0.35, 0); leg.material_override=material(Color("353a3b")); e.add_child(leg)
	var head := MeshInstance3D.new(); var sphere:=SphereMesh.new(); sphere.radius=0.29 if ranger else 0.24; sphere.height=0.48; sphere.radial_segments=6; sphere.rings=3; head.mesh=sphere; head.position.y=1.63; head.material_override=material(Color("7a7784") if ranger else Color("b06d4f")); e.head_mesh=head; e.add_child(head)
	var eye := OmniLight3D.new(); eye.light_color=NEON_PURPLE if ranger else NEON_RED; eye.light_energy=2.0; eye.omni_range=2.8; eye.position.y=1.63; e.eye_light=eye; e.add_child(eye)
	enemy_root.add_child(e)

func spawn_projectile(from: Vector3, target: Vector3, projectile_speed := 15.0) -> bool:
	if not game_active or shop_open or projectile_root.get_child_count() >= 18: return false
	var projectile := Projectile.new(); projectile.main = self; projectile.position = from; projectile.collision_layer = 4; projectile.collision_mask = 1
	projectile.velocity = (target - from).normalized() * projectile_speed
	var collider := CollisionShape3D.new(); var shape := SphereShape3D.new(); shape.radius = 0.18; collider.shape = shape; projectile.add_child(collider)
	var visual := MeshInstance3D.new(); visual.name="Mesh"; var sphere := SphereMesh.new(); sphere.radius=0.16; sphere.height=0.32; sphere.radial_segments=6; sphere.rings=3; visual.mesh=sphere; visual.material_override=material(NEON_RED, 5.0); projectile.add_child(visual)
	var glow := OmniLight3D.new(); glow.name="Glow"; glow.light_color=NEON_RED; glow.light_energy=1.8; glow.omni_range=2.4; projectile.add_child(glow)
	projectile_root.add_child(projectile)
	return true

func clear_projectiles() -> void:
	for projectile in projectile_root.get_children(): projectile.queue_free()
	for bullet in player_bullet_root.get_children(): bullet.queue_free()

func clear_pickups() -> void:
	for pickup in pickup_root.get_children(): pickup.queue_free()

func set_game_pause(should_pause: bool) -> void:
	game_paused = should_pause
	get_tree().paused = should_pause
	pause_panel.visible = should_pause
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if should_pause else Input.MOUSE_MODE_CAPTURED)

func spawn_ammo_cell(pos: Vector3) -> void:
	var pickup := AmmoPickup.new(); pickup.main=self; pickup.position=pos + Vector3(0, 0.45, 0)
	var visual := MeshInstance3D.new(); var cube := BoxMesh.new(); cube.size=Vector3(0.34, 0.34, 0.34); visual.mesh=cube; visual.material_override=material(NEON_CYAN, 3.5); pickup.add_child(visual)
	var light := OmniLight3D.new(); light.light_color=NEON_CYAN; light.light_energy=1.2; light.omni_range=2.2; pickup.add_child(light)
	pickup_root.add_child(pickup)

func collect_ammo_cell(amount: int) -> void:
	var before := reserve_ammo
	reserve_ammo = mini(reserve_ammo_limit, reserve_ammo + amount)
	if reserve_ammo > before: add_time(0.0, "弾薬セル  +%d" % (reserve_ammo - before))

func begin_reload() -> void:
	if reloading or ammo >= active_magazine_capacity(): return
	if reserve_ammo <= 0:
		add_time(0.0, "予備弾薬がありません")
		return
	reloading = true
	reload_timer = active_reload_duration()
	add_time(0.0, "リロード中")

func start_stage(stage: int) -> void:
	current_stage=stage; kills=0; stage_target=STAGE_ONE_KILLS if stage==1 else STAGE_TWO_KILLS
	spawned_enemies=0; stage_wave=1; wave_two_spawned=false
	stage_origin = STAGE_ORIGINS[stage - 1]
	cover_positions = []
	var local_covers := get_stage_cover_positions(stage)
	for cover in local_covers: cover_positions.append(stage_origin + cover)
	player.position = stage_origin + STAGE_START_LOCAL
	player.velocity = Vector3.ZERO
	pitch = 0.0
	camera.rotation.x = pitch
	time_cap=STAGE_ONE_CAP if stage==1 else STAGE_TWO_CAP
	if stage == 1: time_left=min(time_left,time_cap)
	else: time_left=min(time_left+5.0,time_cap)
	for child in enemy_root.get_children(): child.queue_free()
	clear_projectiles()
	clear_pickups()
	spawn_wave(STAGE_ONE_KILLS if stage == 1 else 7)
	add_time(0.0,"ステージ%d　開始　／　%s" % [stage, "初期アリーナ" if stage == 1 else "新エリアへ移動"])

func spawn_wave(count: int) -> void:
	for i in count:
		var enemy_index := spawned_enemies
		var spawn_pos := Vector3.ZERO
		var found_spawn := false
		for attempt in 8:
			var angle := float(enemy_index)/float(stage_target)*TAU + rng.randf_range(-0.18,0.18)
			var radius := rng.randf_range(10.0,20.0)
			spawn_pos = stage_origin + Vector3(cos(angle)*radius,0,sin(angle)*radius)
			if is_spawn_clear(spawn_pos):
				found_spawn = true
				break
		if not found_spawn:
			for offset in FALLBACK_SPAWNS.size():
				var fallback: Vector3 = stage_origin + FALLBACK_SPAWNS[(enemy_index + offset) % FALLBACK_SPAWNS.size()]
				if is_spawn_clear(fallback):
					spawn_pos = fallback
					break
		var ranger := current_stage == 2 and enemy_index % 3 == 0
		spawn_enemy(spawn_pos, ranger)
		spawned_enemies += 1

func is_spawn_clear(pos: Vector3) -> bool:
	for index in cover_positions.size():
		var cover: Vector3 = cover_positions[index]
		var half_extent: Vector2 = COVER_HALF_EXTENTS[index]
		if abs(pos.x - cover.x) < half_extent.x + 0.7 and abs(pos.z - cover.z) < half_extent.y + 0.7: return false
	return true

func on_enemy_killed(enemy: Enemy, headshot: bool, air_kill: bool) -> void:
	hit_marker_timer = 0.13
	kills += 1
	combo += 1
	combo_timer = 3.5
	var gain := 0.5 + kill_time_bonus; var label := "撃破  +%.2f秒" % gain
	if headshot: gain += 1.0; label="ヘッドショット  +%.2f秒" % gain
	if air_kill: gain += 1.5; label=("空中 " + label)
	if grapple_kill_window > 0.0 and enemy.get_instance_id() == grapple_kill_target_id:
		gain += 2.0; label="グラップルキル  +%.1f秒" % gain; grapple_kill_window=0.0; grapple_kill_target_id=0
	var multiplier: float = 1.0 + minf(0.75, float(combo - 1) * 0.05)
	gain *= multiplier
	if combo >= 2: label = "%s　／　コンボ x%.2f" % [label, multiplier]
	add_time(gain,label)
	if enemy.is_ranger or rng.randf() < 0.3: spawn_ammo_cell(enemy.global_position)
	if current_stage == 1 and kills >= stage_target:
		open_shop()
	elif current_stage == 2 and kills >= 7 and not wave_two_spawned:
		wave_two_spawned = true; stage_wave = 2
		clear_projectiles()
		spawn_wave(7)
		add_time(0.0, "ウェーブ2　増援接近")
	elif current_stage == 2 and kills >= stage_target:
		victory()

func on_enemy_damaged(remaining_health: int) -> void:
	hit_marker_timer = 0.08
	add_time(0.0, "装甲命中　残り耐久 %d" % max(0, remaining_health))

func active_magazine_capacity() -> int:
	return int(weapon_combat_profile.get("magazine_capacity", MAGAZINE_SIZE))

func active_fire_interval() -> float:
	return float(weapon_combat_profile.get("fire_interval", 0.16))

func active_reload_duration() -> float:
	return float(weapon_combat_profile.get("reload_seconds", RELOAD_DURATION))

func active_recoil_impulse() -> float:
	return float(weapon_combat_profile.get("recoil_impulse", 0.7))

func active_ammo_cell_amount() -> int:
	return int(weapon_combat_profile.get("cell_amount", 12))

func get_weapon_direct_damage(_weapon_index: int) -> int:
	return maxi(1, roundi(float(weapon_combat_profile.get("damage", 1)) * weapon_damage_multiplier))

func record_weapon_direct_damage(weapon_index: int, damage: int) -> void:
	var awarded := weapon_experience.award_direct_damage(weapon_index, damage)
	progression.award_weapon_direct_damage(progression.selected_weapon_id, damage)
	if awarded > 0:
		push_event("%s XP +%d　合計 %d" % [str(WeaponCatalogData.weapon(weapon_model_id).get("display_name", weapon_model_id)), awarded, weapon_experience.get_experience(weapon_index)])

func add_time(amount: float, message: String) -> void:
	time_left=clamp(time_left+amount,0.0,time_cap)
	push_event(message)

func push_event(message: String, duration := 2.7) -> void:
	for index in range(2, 0, -1):
		event_messages[index] = event_messages[index - 1]
		event_timers[index] = event_timers[index - 1]
	event_messages[0] = message
	event_timers[0] = duration

func open_shop() -> void:
	var earned_xp := progression.award_stage_completion(current_stage, time_left)
	progression.save_to_file()
	set_game_pause(false); reloading=false; reload_timer=0.0; toast_timer=0.0; toast_panel.visible=false; event_messages=["", "", ""]; event_timers=[0.0, 0.0, 0.0]; clear_projectiles(); clear_pickups(); shop_open=true; shop.visible=true; roll_reward_choices(); Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	push_event("ステージXP +%d　Lv.%d" % [earned_xp, progression.player_level])

func get_reward_pool(premium: bool) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	if premium:
		pool = [
			{"id":"chrono_drive", "name":"クロノ・ドライブ", "description":"射撃間隔を40%短縮し、キル時間報酬も増加。", "cost":7.0},
			{"id":"phase_shell", "name":"フェーズ・シェル", "description":"被弾時の時間損失を4秒から2秒へ軽減。", "cost":8.0},
			{"id":"dash_core", "name":"ダッシュ・コア", "description":"ダッシュ速度を上げ、再使用時間を40%短縮。", "cost":7.0}
		]
	else:
		pool = [
			{"id":"grapple", "name":"グラップル", "description":"敵へ高速接近。直後のキルで+2.0秒。", "cost":0.0},
			{"id":"overclock", "name":"パルス・オーバークロック", "description":"パルスライフルの連射速度を25%上昇。", "cost":0.0},
			{"id":"time_siphon", "name":"タイムサイフォン", "description":"すべての通常キルの時間報酬が+0.25秒。", "cost":0.0},
			{"id":"ammo_rig", "name":"拡張アモリグ", "description":"予備弾薬の上限+36、即座に弾薬+24。", "cost":0.0}
		]
	var available: Array[Dictionary] = []
	for choice in pool:
		if not owned_rewards.has(choice["id"]): available.append(choice)
	return available

func roll_reward_choices() -> void:
	reward_choices = []
	var free_pool := get_reward_pool(false); free_pool.shuffle()
	for choice in free_pool:
		if reward_choices.size() >= 2: break
		reward_choices.append(choice)
	var premium_pool := get_reward_pool(true); premium_pool.shuffle()
	if not premium_pool.is_empty(): reward_choices.append(premium_pool[0])
	reward_title.text = "ステージ%d突破　／　ロードアウトを選択" % current_stage
	reward_body.text = "2つの無料スキルと、残り時間で交換する高出力スキルから1つ選択。\n選択後、第%dアリーナへ移動します。" % (current_stage + 1)
	for index in reward_buttons.size():
		var button := reward_buttons[index]
		if index >= reward_choices.size():
			button.visible = false
			continue
		var choice: Dictionary = reward_choices[index]
		var cost: float = choice.get("cost", 0.0)
		button.visible = true
		button.disabled = cost > 0.0 and time_left <= cost
		button.text = "%s%s\n%s" % [choice["name"], "　−%.0f秒" % cost if cost > 0.0 else "　無料", choice["description"]]

func select_reward(index: int) -> void:
	if index < 0 or index >= reward_choices.size(): return
	var choice: Dictionary = reward_choices[index]
	var cost: float = choice.get("cost", 0.0)
	if time_left <= cost: return
	if cost > 0.0: time_left -= cost
	apply_reward(str(choice["id"]))
	owned_rewards[choice["id"]] = true
	add_time(0.0, "%s を獲得%s" % [choice["name"], "　−%.0f秒" % cost if cost > 0.0 else ""])
	shop.visible=false; shop_open=false; Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED); start_stage(current_stage + 1)

func apply_reward(id: String) -> void:
	match id:
		"grapple": has_grapple = true
		"overclock": fire_rate_multiplier *= 1.25
		"time_siphon": kill_time_bonus += 0.25
		"ammo_rig":
			reserve_ammo_limit += 36
			reserve_ammo = mini(reserve_ammo_limit, reserve_ammo + 24)
		"chrono_drive":
			fire_rate_multiplier *= 1.4
			kill_time_bonus += 0.2
		"phase_shell": damage_time_loss = maxf(2.0, damage_time_loss - 2.0)
		"dash_core":
			dash_speed += 5.0
			dash_cooldown_duration *= 0.6

func end_run() -> void:
	set_game_pause(false); reloading=false; reload_timer=0.0; damage_indicator_timer=0.0; ui_damage_indicator.visible=false; clear_projectiles(); clear_pickups(); game_active=false; Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE); push_event("時間切れ　／　Rで再挑戦", 999.0); update_ui()

func on_player_hit(source_direction := Vector3.ZERO) -> void:
	if not game_active or hit_invulnerability > 0.0: return
	hit_invulnerability = 0.65
	damage_source_direction = source_direction
	damage_source_direction.y = 0.0
	damage_indicator_timer = 0.55 if damage_source_direction.length() > 0.01 else 0.0
	time_left = max(0.0, time_left - damage_time_loss)
	combo = 0; combo_timer = 0.0
	add_time(0.0, "被弾　−%.1f秒" % damage_time_loss)
	if time_left <= 0.0: end_run()

func victory() -> void:
	var earned_xp := progression.award_stage_completion(current_stage, time_left)
	progression.save_to_file()
	set_game_pause(false); reloading=false; reload_timer=0.0; damage_indicator_timer=0.0; push_event("オーバータイム達成　／　ステージXP +%d　Lv.%d　／　Rで再挑戦" % [earned_xp, progression.player_level], 999.0); update_ui()

func restart_run() -> void:
	set_game_pause(false)
	game_active = true
	var selected_id := str(progression.preparation_view().selected_weapon_id)
	# Only the preparation loadout determines the run's weapon; hot swapping is unavailable.
	equip_weapon_model(selected_id)
	shop_open = false
	has_grapple = false
	owned_rewards = {}
	weapon_damage_multiplier = 1.0
	weapon_experience.reset()
	reward_choices = []
	reserve_ammo_limit = int(weapon_combat_profile.get("maximum_reserve", MAX_RESERVE_AMMO)); fire_rate_multiplier = 1.0; kill_time_bonus = 0.0; dash_speed = 22.0; dash_cooldown_duration = 1.0; damage_time_loss = 4.0
	time_left = START_TIME
	time_cap = STAGE_ONE_CAP
	stage_origin = STAGE_ORIGINS[0]
	player.position = stage_origin + STAGE_START_LOCAL
	player.velocity = Vector3.ZERO
	grapple_time = 0.0; grapple_kill_window = 0.0; grapple_kill_target_id = 0; grapple_cooldown = 0.0; hit_invulnerability = 0.0
	combo = 0; combo_timer = 0.0
	ammo = active_magazine_capacity(); reserve_ammo = int(weapon_combat_profile.get("starting_reserve", START_RESERVE_AMMO)); reloading = false; reload_timer = 0.0
	toast_timer = 0.0
	damage_indicator_timer = 0.0
	event_messages = ["", "", ""]
	event_timers = [0.0, 0.0, 0.0]
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	start_stage(1)

func update_ui() -> void:
	ui_time.text="%05.1f 秒" % time_left
	ui_time.add_theme_color_override("font_color", NEON_RED if time_left < 8.0 else NEON_CYAN)
	ui_time_bar.value = clampf(time_left / maxf(time_cap, 0.01) * 100.0, 0.0, 100.0)
	time_fill_style.bg_color = NEON_RED if time_left < 8.0 else Color("ffb84d") if time_left < 15.0 else NEON_CYAN
	toast_panel.visible = false
	ui_crosshair.text = "×" if hit_marker_timer > 0.0 else "+"
	ui_crosshair.add_theme_color_override("font_color", Color("ffdc6b") if hit_marker_timer > 0.0 else Color.WHITE)
	# AR はアイアンサイトだけで狙う。サイトを持たないピストルは中央照準を残す。
	var using_iron_sight := aiming and weapon_model_index == 0
	ui_crosshair.visible = game_active and not using_iron_sight
	ui_reload_prompt.visible = not reloading and ammo <= 0 and game_active
	ui_reload_prompt.text = "［R］ リロード"
	for index in 3:
		var event_label := ui_event_labels[index]
		var event_time := event_timers[index]
		event_label.visible = event_time > 0.0
		if event_label.visible:
			event_label.text = event_messages[index]
			event_label.modulate = Color(1, 1, 1, minf(1.0, event_time / 1.2))
	# 中央リングもARのアイアンサイトを隠すため、上部の残り時間表示に集約する。
	ui_time_ring.visible = time_left <= 10.0 and game_active and not using_iron_sight
	if ui_time_ring.visible:
		ui_time_ring.remaining_fraction = clampf(time_left / 10.0, 0.0, 1.0)
		ui_time_ring.queue_redraw()
	ui_damage_indicator.visible = damage_indicator_timer > 0.0
	if ui_damage_indicator.visible:
		var local_damage := camera.global_transform.basis.inverse() * damage_source_direction.normalized()
		ui_damage_indicator.rotation = atan2(local_damage.x, -local_damage.z)
	ui_weapon_title.text = "%s　／　%.0f DMG ・ %.1f/s" % [str(weapon_combat_profile.get("display_name", weapon_model_id)), float(weapon_combat_profile.get("damage", 0)), 1.0 / active_fire_interval()]
	ui_ammo.text = "装填中…" if reloading else "%02d/%02d  ／  %03d" % [ammo, active_magazine_capacity(), reserve_ammo]
	ui_ammo.add_theme_color_override("font_color", NEON_PURPLE if reloading else NEON_RED if ammo == 0 else Color("d7e6ff"))
	ui_status.text="ステージ%d%s　・　%s　・　撃破 %d / %d" % [current_stage,"　ウェーブ %d/2" % stage_wave if current_stage == 2 else "", "初期アリーナ" if current_stage == 1 else "第2アリーナ",kills,stage_target]
	ui_grapple.text = "⌁"
	ui_grapple.add_theme_color_override("font_color", NEON_CYAN if has_grapple and grapple_cooldown <= 0.0 else Color("62728e"))
	ui_minimap.queue_redraw()
