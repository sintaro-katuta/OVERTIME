extends SceneTree
const Catalog=preload("res://gameplay/skills/skill_catalog.gd")
const Controller=preload("res://gameplay/skills/skill_controller.gd")
class MemoryProgression extends "res://gameplay/progression_state.gd":
	func load_from_file(_path:="user://progression.save") -> Error: return OK
	func save_to_file(_path:="user://progression.save") -> Error: return OK
func _init() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://main.tscn").instantiate(); game.progression=MemoryProgression.new(); root.add_child(game)
	game.start_from_title(); game.progression.select_weapon("vanguard_556"); game.skills.selected = ["aegis", "repulse"]; game.begin_run_from_preparation(); game.set_physics_process(false)
	for enemy in game.enemy_root.get_children(): enemy.set_physics_process(false)
	await physics_frame
	var skills=game.skills
	for reward in game.get_reward_pool(false): assert(not reward.id in Catalog.IDS)
	assert(skills.activate()); assert(not skills.activate()); assert(skills.remaining==4)
	var eye:Vector3=game.camera.global_position; var forward:Vector3=-game.camera.global_basis.z
	assert(skills.shield_blocks(eye+forward*3,eye))
	assert(not skills.shield_blocks(eye-forward*3,eye))
	assert(not skills.shield_blocks(eye+game.camera.global_basis.x*4+forward*3,eye+game.camera.global_basis.x*4))
	game.game_paused=true; var before:float=skills.remaining; skills.tick(1); assert(skills.remaining==before); game.game_paused=false
	skills.clear_stage(); assert(not skills.shield_blocks(eye+forward*3,eye))
	skills.equipped="chrono"; skills.cooldown=0; assert(skills.activate()); assert(skills.time_scale_at(skills.center)==1); assert(skills.fire_rate_bonus()==1.5); assert(skills.time_scale_at(skills.center+Vector3(8,0,0))==1)
	skills.tick(5.1); assert(skills.time_scale_at(skills.center)==1)
	skills.equipped="rewind"; skills.cooldown=0; assert(not skills.activate())
	await physics_frame
	var start:Vector3=game.player.global_position
	for i in 34: skills.tick(.1)
	game.player.position.x+=1
	var time_before:float=game.time_left; var ammo_before:int=game.ammo
	assert(skills.activate()); assert(skills.rewinding); skills.update_rewind(.8); assert(not skills.rewinding); assert(game.player.global_position.distance_to(start)<.02); assert(game.time_left==time_before and game.ammo==ammo_before)
	var wall:=StaticBody3D.new(); var collider:=CollisionShape3D.new(); var shape:=BoxShape3D.new(); shape.size=Vector3(2,3,2); collider.shape=shape; wall.add_child(collider); game.add_child(wall); wall.global_position=start
	await physics_frame; assert(not skills.safe_position(start)); wall.free(); await physics_frame
	skills.equipped="repulse"; skills.cooldown=0; game.camera.rotation.x=-1.0
	assert(skills.activate()); assert(game.player.velocity.y==12)
	game.camera.rotation.x=0
	skills.equipped="vortex"; skills.cooldown=0; assert(skills.activate()); assert(skills.device_time>0 and skills.remaining==0); skills.tick(.5); assert(skills.remaining==4)
	var enemy=game.enemy_root.get_child(0); enemy.global_position=skills.center+Vector3(3,-1,0)
	assert(skills.enemy_force(enemy).x<0)
	skills.clear_stage(); assert(skills.enemy_force(enemy)==Vector3.ZERO and skills.history.is_empty())
	# Exercise the actual grapple ray and movement, including its shared input cooldown.
	skills.equipped="grapple"; skills.cooldown=0; game.grapple_cooldown=0; game.has_grapple=true
	game.player.global_position=Vector3(0,10,12); game.player.velocity=Vector3.ZERO; game.camera.rotation=Vector3.ZERO
	enemy.global_position=Vector3(0,9.6,4)
	await physics_frame
	var player_start:Vector3=game.player.global_position
	assert(skills.activate() and game.grapple_target==enemy)
	assert(not skills.activate())
	for i in 18:
		await physics_frame
		skills.tick(1.0/60)
	assert(game.grapple_kill_window>0 and game.grapple_kill_target_id==enemy.get_instance_id())
	assert(game.player.global_position==player_start,"grapple must not move player")
	assert(enemy.global_position.distance_to(player_start+Vector3(0,-.85,-2))<.16,"enemy arrives in front")
	game.grapple_kill_window=0; game.grapple_kill_target_id=0
	game.player.global_position=Vector3(0,10,12); game.player.velocity=Vector3.ZERO
	game.camera.rotation.y=PI; skills.cooldown=0; game.grapple_cooldown=0
	assert(not skills.activate() and skills.cooldown==0,"miss does not consume cooldown")
	skills.clear_stage()
	game.restart_run(); assert(skills.equipped == "aegis" and skills.second.equipped == "repulse" and not game.has_grapple)
	print("PASS: reward separation, cooldown, pause, directional shield, chrono, rewind collision, repulse, vortex, grapple movement and miss, retry loadout")
	game.free(); quit()
