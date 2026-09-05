extends SceneTree

const Catalog = preload("res://gameplay/weapon_catalog.gd")
const Combat = preload("res://gameplay/weapon_combat_profile.gd")
class MemoryProgression extends "res://gameplay/progression_state.gd":
	func load_from_file(_path := "user://progression.save") -> Error: return OK
	func save_to_file(_path := "user://progression.save") -> Error: return OK

var game
func _init() -> void: call_deferred("run_tests")

func equip(id: String) -> void:
	for bullet in game.player_bullet_root.get_children(): bullet.free()
	game.equip_weapon_model(id)
	game.ammo = game.active_magazine_capacity()
	game.reserve_ammo = int(game.weapon_combat_profile.starting_reserve)
	game.reloading = false
	game.reload_timer = 0.0
	game.aiming = false
	game.camera.rotation = Vector3.ZERO
	game.pitch = 0.0
	game.rng.seed = 16

func run_tests() -> void:
	game = load("res://main.tscn").instantiate()
	game.progression = MemoryProgression.new()
	root.add_child(game)
	game.start_from_title()
	game.progression.select_weapon("vanguard_556")
	game.begin_run_from_preparation()
	game.set_physics_process(false)
	for enemy in game.enemy_root.get_children(): enemy.free()
	# Isolated high-altitude space keeps ballistic tests clear of the arena.
	game.player.position = Vector3(0, 100, 0)
	for id in Catalog.WEAPON_IDS:
		equip(id)
		var data := Catalog.weapon(id)
		var forward: Vector3 = -game.muzzle_marker.global_basis.z.normalized()
		assert(forward.dot(-game.camera.global_basis.z) > 0.999, id + " muzzle must face forward")
		assert(game.camera.to_local(game.muzzle_marker.global_position).z < 0.0)
		if id == "vanguard_556":
			assert(game.weapon_model_node.rotation_degrees == Vector3.ZERO)
			assert(game.weapon_model_node.scale.is_equal_approx(Vector3.ONE * 1.45))
			assert(game.get_weapon_hip_position() == Vector3(0.28, -0.20, -0.48))
			assert(game.get_weapon_ads_position() == Vector3(0, -0.038, -0.38))
		elif id == "sidearm_9":
			assert(game.weapon_model_node.scale.is_equal_approx(Vector3.ONE * 0.30))
			assert(game.get_weapon_ads_position() == Vector3(0.30, -0.25, -0.52))
		var muzzle_before: Vector3 = game.muzzle_marker.global_position
		var before: int = game.ammo
		game.shoot()
		assert(game.ammo == before - 1, id + " one round per trigger")
		assert(game.player_bullet_root.get_child_count() == int(data.damage.pellets))
		assert(game.camera.rotation.x > 0, id + " camera recoil")
		var bullet = game.player_bullet_root.get_child(0)
		assert(is_equal_approx(bullet.velocity.length(), float(data.ballistics.muzzle_velocity_mps)))
		assert(bullet.position.is_equal_approx(muzzle_before))
		assert(is_equal_approx(bullet.profile.gravity, 9.8 * float(data.ballistics.gravity_multiplier)))
		game.shoot()
		assert(game.ammo == before - 1, "cooldown must block duplicate trigger")
		game.shot_cooldown = 0.0
		game.shoot(false)
		var repeats := str(data.fire_mode) in ["full_auto", "burst_3"]
		assert(game.ammo == before - (2 if repeats else 1), id + " hold behavior")
		var profile := Combat.from_catalog(id)
		assert(Combat.damage_at_distance(profile, int(data.damage.body), 0, false) == int(data.damage.body))
		assert(Combat.damage_at_distance(profile, int(data.damage.body), 0, true) == int(data.damage.body) * 2)
		assert(Combat.damage_at_distance(profile, 100, float(data.falloff.minimum_damage_distance_meters), false) == roundi(100 * float(data.falloff.minimum_multiplier)))
		Input.action_press("aim")
		game._physics_process(float(data.ads.transition_seconds))
		assert(is_equal_approx(game.camera.fov, float(data.ads.fov)), id + " ADS FOV")
		Input.action_release("aim")
		game.player.position = Vector3(0,100,0)
		game.player.velocity = Vector3.ZERO
		await process_frame

	equip("bastion_556")
	game.shoot()
	for i in 2:
		game.shot_cooldown = 0.0
		game.shoot(false)
	assert(game.ammo == 15 and game.burst_remaining == 0)
	assert(is_equal_approx(game.shot_cooldown, 0.4))
	game.shot_cooldown = 0.0
	game.shoot(false)
	assert(game.ammo == 15, "held burst cannot start a new burst")
	game.ammo = 2
	game.shoot()
	game.shot_cooldown = 0.0
	game.shoot(false)
	assert(game.ammo == 0 and game.burst_remaining == 0)

	equip("longshot_338")
	game.shoot()
	assert(is_equal_approx(game.shot_cooldown, 1.43))
	var bullet = game.player_bullet_root.get_child(0)
	var start: Vector3 = bullet.position
	var initial_velocity: Vector3 = bullet.velocity
	bullet._physics_process(0.1)
	assert(bullet.position.y < start.y + initial_velocity.y * 0.1, "gravity drops the projectile below a straight trajectory")
	assert(bullet.distance_travelled > 16.0)
	bullet._physics_process(2.0)
	assert(bullet.is_queued_for_deletion())
	assert(bullet.distance_travelled <= 200.001, "range must clip the final segment")

	equip("breach_12")
	game.shoot()
	var directions: Array[Vector3] = []
	for pellet in game.player_bullet_root.get_children():
		var direction: Vector3 = pellet.velocity.normalized()
		assert(not directions.has(direction), "pellets must spread")
		directions.append(direction)
	assert(directions.size() == 8)
	var hip := Combat.pellet_direction(Vector3.FORWARD, 1, 8, 1.0)
	var ads := Combat.pellet_direction(Vector3.FORWARD, 1, 8, 0.78)
	assert(ads.angle_to(Vector3.FORWARD) < hip.angle_to(Vector3.FORWARD))
	game.ammo = 0
	game.reserve_ammo = 3
	game.begin_reload()
	game.update_reload(0.54)
	assert(game.ammo == 0)
	game.update_reload(0.02)
	assert(game.ammo == 1 and game.reserve_ammo == 2 and game.reloading)
	game.shot_cooldown = 0
	game.shoot()
	assert(game.ammo == 0 and not game.reloading, "loaded shell can interrupt reload")
	game.ammo = 2
	game.begin_reload()
	assert(game.ammo == 2, "tube reload preserves shells")
	game.update_reload(1.2)
	assert(game.ammo == 4 and game.reserve_ammo == 0 and not game.reloading)

	equip("vanguard_556")
	game.ammo = 5
	game.reserve_ammo = 7
	game.begin_reload()
	assert(game.ammo == 0 and game.reserve_ammo == 7)
	game.update_reload(1.49)
	assert(game.ammo == 0)
	game.update_reload(0.02)
	assert(game.ammo == 7 and game.reserve_ammo == 0 and not game.reloading)
	game.ammo = 0
	game.reserve_ammo = 20
	game.automatic_reload_enabled = false
	game._physics_process(0.01)
	assert(not game.reloading)
	game.automatic_reload_enabled = true
	game._physics_process(0.01)
	assert(game.reloading)
	game.update_reload(1.5)
	assert(game.ammo == 20)
	game.game_paused = true
	game.shoot()
	assert(game.ammo == 20)
	game.game_paused = false
	game.shop_open = true
	game.shoot()
	assert(game.ammo == 20)
	game.shop_open = false

	# Actual enemy HP responds to body/head damage rather than unconditional head kills.
	game.spawn_enemy(Vector3(0,100,-10))
	var enemy = game.enemy_root.get_child(0)
	assert(enemy.health == 100)
	assert(not enemy.take_damage(36, true, false))
	assert(enemy.health == 64)
	enemy.free()
	# Swept collision must stop at the nearest wall, including on the final range segment.
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.position = Vector3(0, 100, -5)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4,4,0.2)
	collision.shape = box
	wall.add_child(collision)
	game.add_child(wall)
	await physics_frame
	equip("vanguard_556")
	game.shoot()
	var blocked_bullet = game.player_bullet_root.get_child(0)
	blocked_bullet.position = Vector3(0,100,0)
	blocked_bullet.velocity = Vector3(0,0,-110)
	blocked_bullet._physics_process(0.1)
	assert(blocked_bullet.is_queued_for_deletion(), "wall must stop projectile")
	assert(blocked_bullet.position.z > -5.1, "projectile must not penetrate wall")
	wall.free()
	# The same collision path must apply headshot damage and award that exact XP.
	equip("vanguard_556")
	game.spawn_enemy(Vector3(0, 100, -5))
	var target = game.enemy_root.get_child(0)
	target.set_physics_process(false)
	await physics_frame
	var xp_before: int = game.weapon_experience.get_experience(0)
	game.shoot()
	var hit_bullet = game.player_bullet_root.get_child(0)
	hit_bullet.position = Vector3(0,101.6,0)
	hit_bullet.velocity = Vector3(0,0,-110)
	hit_bullet._physics_process(0.1)
	assert(hit_bullet.is_queued_for_deletion())
	assert(target.health == 64, "near head hit must apply 18 x 2 damage")
	assert(game.weapon_experience.get_experience(0) - xp_before == 36)
	target.free()
	game.progression.player_level = 2
	game.progression.select_skin("vanguard_556", "obsidian_circuit")
	equip("vanguard_556")
	assert((-game.muzzle_marker.global_basis.z.normalized()).dot(-game.camera.global_basis.z) > 0.999)
	assert(game.get_weapon_direct_damage(0) == 18, "skin must not change damage")
	game.select_preparation_tab("settings")
	var toggle = game.preparation_content.get_child(0)
	toggle.button_pressed = false
	assert(not game.automatic_reload_enabled)
	game.free()
	await process_frame
	print("weapon_runtime_test: PASS (9 weapons, skin, fire modes, ballistics, damage, ADS, reload)")
	quit()
