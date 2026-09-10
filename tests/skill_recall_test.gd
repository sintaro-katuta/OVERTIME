extends SceneTree
class MemoryProgression extends "res://gameplay/progression_state.gd":
	func load_from_file(_path:="user://progression.save") -> Error:return OK
	func save_to_file(_path:="user://progression.save") -> Error:return OK
var game
func _init() -> void:call_deferred("run")
func wall(pos:Vector3,size:Vector3) -> StaticBody3D:
	var n:=StaticBody3D.new();var c:=CollisionShape3D.new();var s:=BoxShape3D.new();s.size=size;c.shape=s;n.add_child(c);game.add_child(n);n.global_position=pos;return n
func set_path(points:Array[Vector3]) -> void:
	game.skills.clear_stage();game.skills.equipped="rewind";game.skills.cooldown=0;game.skills.elapsed=3.2
	for i in points.size():game.skills.history.append({"time":float(i)*3.2/(points.size()-1),"position":points[i],"yaw":0.0})
	game.player.global_position=points[-1];game.player.velocity=Vector3.ZERO
func run() -> void:
	game=load("res://main.tscn").instantiate();game.progression=MemoryProgression.new();root.add_child(game)
	game.start_from_title();game.progression.select_weapon("vanguard_556");game.skills.selected = ["repulse", "aegis"]; game.begin_run_from_preparation();game.set_physics_process(false)
	for enemy in game.enemy_root.get_children():enemy.set_physics_process(false)
	var s=game.skills
	var a:=Vector3(0,10,5);var b:=Vector3(0,10,10);var c:=Vector3(5,10,10)
	# The direct diagonal intersects this block; the recorded corner path does not.
	var block:=wall(Vector3(2.5,10,7.5),Vector3(2,4,2))
	set_path([a,b,c]);await physics_frame
	assert(s.activate());assert(game.player.global_position==c,"cast is not a teleport")
	s.update_rewind(.4);assert(game.player.global_position.distance_to(b+Vector3.UP*.08)<.03,"midpoint follows corner")
	var ammo:int=game.ammo;var reserve:int=game.reserve_ammo;var remaining:float=game.time_left
	game.shoot();game.begin_reload();assert(game.ammo==ammo and not game.reloading);assert(not s.activate())
	game._physics_process(.2);assert(game.time_left<remaining and game.ammo==ammo and game.reserve_ammo==reserve)
	s.update_rewind(.2);assert(not s.rewinding and game.player.global_position.distance_to(a)<.03)
	block.free()
	# A new wall across the return route must stop the swept capsule.
	set_path([a,b,c]);block=wall(Vector3(0,10,7.5),Vector3(3,4,.3));await physics_frame
	assert(s.activate());s.update_rewind(.8);assert(not s.rewinding and game.player.global_position.z>7.5)
	block.free()
	set_path([a,b,c]);await physics_frame;assert(s.activate());s.update_rewind(.2)
	game.game_paused=true;var paused_pos:Vector3=game.player.position;s.tick(.5);assert(game.player.position==paused_pos);game.game_paused=false
	s.fx._process(.1);assert(not game.weapon.visible)
	s.clear_stage();assert(not s.rewinding and game.weapon.visible and s.rewind_path.is_empty())
	# Actual pull: stationary player, enemy moving, wall blocking, and target deletion.
	s.equipped="grapple";s.cooldown=0;game.has_grapple=true;game.grapple_cooldown=0
	game.player.position=Vector3(0,10,12);game.camera.rotation=Vector3.ZERO
	var enemy=game.enemy_root.get_child(0);enemy.global_position=Vector3(0,9.15,4)
	await physics_frame;assert(s.activate())
	block=wall(Vector3(0,10,8),Vector3(3,4,.3));await physics_frame
	var origin:Vector3=game.player.position
	for i in 30:s.tick(1.0/60)
	assert(game.player.position==origin and enemy.position.z<8 and game.grapple_time==0 and game.grapple_kill_window==0)
	block.free();enemy.position=Vector3(0,9.15,4);s.cooldown=0;game.grapple_cooldown=0
	await physics_frame;assert(s.activate());enemy.free();s.tick(.1);assert(game.grapple_target==null and game.grapple_time==0)
	game.free();await process_frame;print("PASS: reverse curved path, no instant teleport, swept collision, input lock, timer continues, ammo stable, pause, visual restore, pull obstruction, target deletion");quit()
