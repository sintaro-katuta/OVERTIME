extends SceneTree
const Sound=preload("res://gameplay/skills/skill_sound.gd")
class MemoryProgression extends "res://gameplay/progression_state.gd":
	func load_from_file(_path:="user://progression.save") -> Error:return OK
	func save_to_file(_path:="user://progression.save") -> Error:return OK
func _init() -> void:call_deferred("run")
func run() -> void:
	var game=load("res://main.tscn").instantiate();game.progression=MemoryProgression.new();root.add_child(game)
	game.start_from_title();game.progression.select_weapon("vanguard_556");game.skills.selected = ["repulse", "aegis"]; game.begin_run_from_preparation();game.set_physics_process(false)
	for enemy in game.enemy_root.get_children():enemy.set_physics_process(false)
	await physics_frame
	var fx=game.skills.fx
	var hashes:Dictionary={}
	for id in game.skills.Catalog.IDS:
		var sound=Sound.create(id);assert(sound.data.size()>10000);hashes[hash(sound.data)]=true
		game.skills.equipped=id;fx.flash(game.skills.Catalog.DATA[id].color)
		fx.burst(game.player.position,Color.WHITE,1)
		fx._process(.05)
		assert(absf(game.camera.h_offset)<.03 and absf(game.camera.v_offset)<.03)
		var phase:float=fx.phase;game.game_paused=true;fx._process(1);assert(fx.phase==phase);game.game_paused=false
		fx._process(1);assert(fx.transients.is_empty(),"short effects expire")
		game.skills.clear_stage();assert(game.camera.h_offset==0 and game.camera.v_offset==0)
		for n in [fx.launcher,fx.chain,fx.hook,fx.marker,fx.shield,fx.vortex,fx.chrono,fx.device]:assert(not n.visible)
	assert(hashes.size()==6,"distinct skill waveforms")
	game.skills.equipped="aegis";game.skills.cooldown=0;assert(game.skills.activate());fx._process(.3);assert(fx.shield.visible and is_equal_approx(fx.shield.scale.x,1))
	fx.shield_impact(game.camera.global_position-Vector3(0,0,1.65));assert(not fx.transients.is_empty())
	game.skills.tick(4.1);fx._process(.1);assert(not fx.shield.visible);fx._process(1);assert(fx.transients.is_empty())
	game.skills.equipped="chrono";game.skills.cooldown=0;assert(game.skills.activate());fx._process(.3);assert(fx.chrono.visible and not fx.vortex.visible)
	game.skills.clear_stage();assert(not fx.chrono.visible)
	game.free();await process_frame;print("PASS: six distinct sounds, bounded camera reaction, pause freeze, effect expiry, transition cleanup, shield deployment/hit/end, chrono visibility");quit()
