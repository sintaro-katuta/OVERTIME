extends SceneTree
const G=preload("res://gameplay/skills/skill_geometry.gd")
class MemoryProgression extends "res://gameplay/progression_state.gd":
	func load_from_file(_path:="user://progression.save") -> Error:return OK
	func save_to_file(_path:="user://progression.save") -> Error:return OK
func _init() -> void:call_deferred("run")
func run() -> void:
	var game=load("res://main.tscn").instantiate();game.progression=MemoryProgression.new();root.add_child(game)
	game.start_from_title();game.progression.select_weapon("vanguard_556");game.skills.selected = ["repulse", "aegis"]; game.begin_run_from_preparation();game.set_physics_process(false)
	for enemy in game.enemy_root.get_children():enemy.set_physics_process(false)
	await physics_frame
	var s=game.skills;s.equipped="chrono";assert(s.activate())
	var fixed_center:Vector3=s.center
	assert(s.fire_rate_bonus()==1.5 and s.time_scale_at(s.center)==1)
	game.fire_rate_multiplier=1.25
	game.shot_cooldown=0;game.shoot();var boosted:float=game.shot_cooldown
	assert(is_equal_approx(boosted,maxf(game.active_fire_interval(),game.weapon_combat_profile.bolt_cycle_seconds)/(1.25*1.5)))
	game.player.global_position=s.center+Vector3(6.1,1,0);assert(s.fire_rate_bonus()==1)
	game.shot_cooldown=0;game.shoot();assert(is_equal_approx(game.shot_cooldown,boosted*1.5))
	assert(s.center==fixed_center,"field stays where placed")
	game.player.global_position=s.center+Vector3(5.9,1,0);assert(s.fire_rate_bonus()==1.5)
	game.player.global_position=s.center+Vector3(0,4,0);assert(s.fire_rate_bonus()==1)
	game.player.global_position=s.center+Vector3(0,1,0)
	for i in 10:
		game.player.position.x=s.center.x+7;s.tick(.01);game.player.position.x=s.center.x;s.tick(.01)
	assert(game.fire_rate_multiplier==1.25 and s.fire_rate_bonus()==1.5,"entry never mutates passive multiplier")
	s.tick(5);assert(s.fire_rate_bonus()==1 and game.fire_rate_multiplier==1.25)
	s.clear_stage();s.equipped="aegis";s.cooldown=0;assert(s.activate())
	assert(G.shield_contains(Vector2.ZERO));assert(G.shield_contains(Vector2(1.5,0)));assert(not G.shield_contains(Vector2(1.59,.94)));assert(not G.shield_contains(Vector2(1.7,0)))
	var eye:Vector3=game.camera.global_position;var forward:Vector3=-game.camera.global_basis.z;var right:Vector3=game.camera.global_basis.x;var up:Vector3=game.camera.global_basis.y
	assert(s.shield_blocks(eye+forward*4,eye))
	assert(not s.shield_blocks(eye-forward*4,eye))
	var cut_corner:=eye+right*1.59+up*.94
	assert(not s.shield_blocks(cut_corner+forward*4,cut_corner))
	var edge:=eye+right*1.5
	assert(s.shield_blocks(edge+forward*4,edge))
	s.fx._process(.3);assert(s.fx.shield_surface.visible);assert(s.fx.shield_surface.material_override.get_shader_parameter("impact_age")<1)
	s.clear_stage();assert(s.fire_rate_bonus()==1 and not s.fx.buff_caption.visible and not s.fx.shield.visible)
	game.free();await process_frame
	print("PASS: buff entry/exit/reentry/height/expiry, actual fire cadence, passive stacking without drift, fixed field, no enemy slow, rounded shield center/edge/corner/back, reset");quit()
