extends RefCounted
const Geometry = preload("res://gameplay/skills/skill_geometry.gd")
const Catalog = preload("res://gameplay/skills/skill_catalog.gd")
var main: Node3D
var equipped := ""
var offered := ""
var rolled_stages: Dictionary = {}
var cooldown := 0.0
var remaining := 0.0
var center := Vector3.ZERO
var history: Array[Dictionary] = []
var elapsed := 0.0
var sample_time := 0.0
var impulses: Dictionary = {}
var device_time := 0.0
var device_from := Vector3.ZERO
var fx: Node3D
var offer_view: CanvasLayer
const RECALL_DURATION := .8
var rewinding := false
var rewind_age := 0.0
var rewind_path: Array[Dictionary] = []
var rewind_index := 0
var rewind_start_time := 0.0
var rewind_end_time := 0.0
var rewind_destination:=Vector3.ZERO
var pull_heading := Vector3.FORWARD
var pull_age := 0.0
var chrono_buff_was_active:=false

func setup(host: Node3D) -> void:
	main = host
	fx = preload("res://gameplay/skills/skill_effects.gd").new()
	main.add_child(fx)
	fx.setup(self)
	offer_view = preload("res://gameplay/skills/skill_offer_view.gd").new()
	main.add_child(offer_view)
	offer_view.setup(self)

func roll_offer(stage: int, random: RandomNumberGenerator) -> String:
	if not equipped.is_empty() or rolled_stages.has(stage) or stage >= 10: return ""
	rolled_stages[stage] = true
	if random.randf() >= Catalog.OFFER_CHANCE: return ""
	offered = Catalog.IDS[random.randi_range(0, Catalog.IDS.size()-1)]
	return offered

func choose(accept: bool) -> bool:
	if offered.is_empty() or not equipped.is_empty(): return false
	if accept:
		main.sfx.emit("reward")
		equipped = offered
		main.has_grapple = equipped == "grapple"
		main.push_event(Catalog.DATA[equipped].name + " を獲得")
	offered = ""
	return true

func reset_run() -> void:
	clear_stage()
	equipped = ""
	offered = ""
	rolled_stages.clear()
	cooldown = 0
	main.has_grapple = false

func clear_stage() -> void:
	main.sfx.stop_event("skill_hold")
	finish_rewind(false)
	remaining = 0
	chrono_buff_was_active=false
	device_time = 0
	history.clear()
	impulses.clear()
	elapsed = 0
	sample_time = 0
	if is_instance_valid(main.grapple_target):main.grapple_target.velocity=Vector3.ZERO
	main.grapple_time = 0
	main.grapple_target = null
	main.grapple_kill_window = 0
	main.grapple_kill_target_id = 0
	if is_instance_valid(fx): fx.clear_effects()
	if is_instance_valid(offer_view): offer_view.hide_offer()
	offered = ""

func is_running() -> bool:
	return main.game_active and not main.game_paused and not main.shop_open and not main.stage_cleared

func tick(delta: float) -> void:
	if not is_running(): return
	cooldown = maxf(0, cooldown-delta)
	remaining = maxf(0, remaining-delta)
	var buff_active:=equipped == "chrono" and fire_rate_bonus()>1
	if buff_active!=chrono_buff_was_active:
		main.push_event("クロノ：連射速度 ×1.5" if buff_active else "クロノ：連射強化解除")
		chrono_buff_was_active=buff_active
	update_grapple(delta)
	if rewinding:
		update_rewind(delta)
		return
	if device_time > 0:
		device_time = maxf(0, device_time-delta)
		if device_time == 0:
			remaining = 4.0
			fx.burst(center, Catalog.DATA.vortex.color, 2.0)
	elapsed += delta
	sample_time -= delta
	if sample_time <= 0:
		sample_time = .04
		if safe_position(main.player.global_position):
			history.append({"time":elapsed, "position":main.player.global_position,"yaw":main.player.rotation.y})
	while not history.is_empty() and elapsed-float(history[0].time) > 3.5: history.pop_front()
	for id in impulses.keys():
		impulses[id] = (impulses[id] as Vector3).move_toward(Vector3.ZERO, delta*22)
		if not is_instance_id_valid(id) or impulses[id].length()<.05: impulses.erase(id)

func safe_position(pos: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new(); capsule.radius = .42; capsule.height = 1.7
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, pos+Vector3(0,.03,0))
	query.collision_mask = 1
	query.exclude = [main.player.get_rid()]
	return main.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func target_point(distance: float) -> Vector3:
	var start: Vector3 = main.camera.global_position
	var end: Vector3 = start-main.camera.global_basis.z*distance
	var query := PhysicsRayQueryParameters3D.create(start, end, 1)
	query.exclude = [main.player.get_rid()]
	var hit: Dictionary = main.get_world_3d().direct_space_state.intersect_ray(query)
	return end if hit.is_empty() else hit.position + hit.normal*.35

func activate() -> bool:
	var success := _try_activate()
	if not success and is_running(): main.sfx.emit("skill_error")
	return success

func _try_activate() -> bool:
	if not is_running() or rewinding or equipped.is_empty() or cooldown > 0: return false
	var color: Color = Catalog.DATA[equipped].color
	match equipped:
		"grapple":
			main.grapple()
			if main.grapple_time <= 0: return false
			pull_heading = -main.player.global_basis.z
			pull_heading.y = 0
			pull_heading = pull_heading.normalized()
			pull_age = 0
			fx.start_chain(main.grapple_target.global_position+Vector3(0,.9,0))
		"repulse":
			var forward: Vector3 = -main.camera.global_basis.z
			center = main.player.global_position
			for enemy in main.enemy_root.get_children():
				var offset: Vector3 = enemy.global_position+Vector3(0,.8,0)-main.camera.global_position
				if offset.length()<7 and (offset.normalized().dot(forward)>.35 or (forward.y<-.55 and offset.length()<4)) and main.enemy_has_sight(enemy.global_position, main.player.global_position):
					var push := Vector3(offset.x,0,offset.z).normalized()*19
					impulses[enemy.get_instance_id()] = push
					fx.burst(enemy.global_position+Vector3(0,1,0), color, .7)
			if forward.y<-.55 and main.slide_controller.can_stand():
				main.slide_controller.stop()
				main.player.velocity.y = 12.0
			fx.repulse(main.camera.global_position, forward)
		"rewind":
			if not begin_rewind(): return false
		"vortex":
			center = target_point(15)
			device_from = main.camera.global_position-main.camera.global_basis.y*.25
			device_time = .45
		"chrono":
			var point:=target_point(4)
			var query:=PhysicsRayQueryParameters3D.create(point,point+Vector3.DOWN*12,1)
			query.exclude=[main.player.get_rid()]
			var hit:Dictionary=main.get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty():
				main.push_event("クロノ：設置できる足場が必要です")
				return false
			center=hit.position+Vector3.UP*.06
			remaining = 5.0
			fx.burst(center, color, 1)
		"aegis":
			remaining = 4.0
	cooldown = float(Catalog.DATA[equipped].cooldown)
	fx.flash(color)
	main.push_event(Catalog.DATA[equipped].name + " 起動")
	return true

func time_scale_at(_pos: Vector3) -> float:
	return 1.0

func fire_rate_bonus() -> float:
	if equipped!="chrono" or remaining<=0:return 1.0
	var offset:Vector3=main.player.global_position-center
	return 1.5 if Vector2(offset.x,offset.z).length()<=6 and absf(offset.y)<=3 else 1.0

func enemy_force(enemy: Node3D) -> Vector3:
	var force: Vector3 = impulses.get(enemy.get_instance_id(), Vector3.ZERO)
	if equipped=="vortex" and remaining>0:
		var offset := center-enemy.global_position
		if offset.length()<7 and offset.length()>.8:
			# Keep the pull behind walls from dragging enemies through cover.
			var query := PhysicsRayQueryParameters3D.create(enemy.global_position+Vector3.UP, center, 1)
			if main.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				offset.y=0
				force += offset.normalized()*minf(12, offset.length()*3)
	return force

func shield_blocks(from: Vector3, to: Vector3) -> bool:
	if equipped!="aegis" or remaining<=0: return false
	var normal: Vector3 = -main.camera.global_basis.z
	var origin: Vector3 = main.camera.global_position+normal*Geometry.SHIELD_DISTANCE
	var a := (from-origin).dot(normal)
	var b := (to-origin).dot(normal)
	if a<0 or b>0 or is_equal_approx(a,b): return false
	var hit := from.lerp(to, a/(a-b))
	var local: Vector3 = main.camera.global_basis.inverse()*(hit-origin)
	if not Geometry.shield_contains(Vector2(local.x,local.y)): return false
	fx.shield_impact(hit)
	return true

func hud_text() -> String:
	if rewinding: return "巻き戻し中"
	if equipped=="grapple" and main.grapple_time>0: return "敵を引き寄せ中"
	if equipped=="grapple" and main.grapple_kill_window>0: return "追撃チャンス  %.1f 秒" % main.grapple_kill_window
	if equipped=="chrono" and remaining>0:
		return ("連射速度 ×1.5  /  %.1f 秒" if fire_rate_bonus()>1 else "範囲内で連射強化  /  %.1f 秒") % remaining
	if remaining>0: return "展開中  %.1f 秒" % remaining
	if device_time>0: return "装置を投射中"
	return "使用可能" if cooldown<=0 else "あと %.1f 秒" % cooldown

func update_grapple(delta: float) -> void:
	if equipped != "grapple" or main.grapple_time<=0: return
	var enemy=main.grapple_target
	if not is_instance_valid(enemy) or enemy.dead:
		main.finish_grapple(false)
		return
	main.grapple_time=maxf(0,main.grapple_time-delta)
	pull_age+=delta
	if pull_age<.075: return
	var destination:Vector3=main.player.global_position+pull_heading*2.0-Vector3.UP*.85
	var offset:Vector3=destination-enemy.global_position
	if Vector2(offset.x,offset.z).length()<.15 and absf(offset.y)<.65:
		enemy.velocity=Vector3.ZERO
		enemy.attack_cooldown=maxf(enemy.attack_cooldown,.5)
		main.finish_grapple(true)
		return
	var motion:=offset.limit_length(main.GRAPPLE_SPEED*delta)
	enemy.velocity=motion/maxf(.001,delta)
	var blocked:=false
	for iteration in 3:
		if motion.length()<.001:break
		var collision=enemy.move_and_collide(motion)
		if collision==null:break
		if collision.get_normal().y<.55:
			blocked=true
			break
		motion=collision.get_remainder().slide(collision.get_normal())+Vector3.UP*.003
	if is_instance_valid(enemy.visual):enemy.visual.update_visual(delta,enemy.velocity,main.player.global_position,false)
	if blocked or main.grapple_time<=0:
		enemy.velocity=Vector3.ZERO
		main.finish_grapple(false)

func begin_rewind() -> bool:
	var chosen:=-1
	# Pick the newest safe sample at least three seconds old.
	for i in range(history.size()-1,-1,-1):
		if elapsed-float(history[i].time)>=3 and safe_position(history[i].position):
			chosen=i
			break
	if chosen<0 or not main.slide_controller.can_stand():
		main.push_event("リワインド：3秒前の安全な位置を記録中")
		return false
	rewind_path.clear()
	rewind_destination=history[chosen].position
	for i in range(chosen,history.size()):
		var sample:Dictionary=history[i].duplicate()
		# A small hover clearance prevents reverse interpolation from catching the ground.
		sample.position+=Vector3.UP*.08
		rewind_path.append(sample)
	# The cast position is part of the path, even between recorder samples.
	rewind_path.append({"time":elapsed+.001,"position":main.player.global_position,"yaw":main.player.rotation.y})
	rewind_index=rewind_path.size()-1
	rewind_start_time=float(rewind_path[-1].time)
	rewind_end_time=float(rewind_path[0].time)
	rewind_age=0
	rewinding=true
	main.slide_controller.reset()
	main.player.velocity=Vector3.ZERO
	main.reloading=false
	main.reload_timer=0
	main.burst_remaining=0
	fx.rewind_trail(rewind_path)
	return true

func rewind_move(destination:Vector3) -> bool:
	var motion:Vector3=destination-main.player.global_position
	if motion.length()<.0001:return true
	# Swept capsule, not just a destination test: newly placed walls cannot be crossed.
	var hit=main.player.move_and_collide(motion,false,.001)
	return hit==null or main.player.global_position.distance_to(destination)<.015

func update_rewind(delta:float) -> void:
	if not rewinding:return
	rewind_age=minf(RECALL_DURATION,rewind_age+delta)
	var fraction:=rewind_age/RECALL_DURATION
	var source_time:=lerpf(rewind_start_time,rewind_end_time,smoothstep(0,1,fraction))
	# Visit every crossed sample so a fast frame cannot shortcut a corner.
	while rewind_index>0 and float(rewind_path[rewind_index-1].time)>=source_time:
		if not rewind_move(rewind_path[rewind_index-1].position):
			finish_rewind(true)
			return
		rewind_index-=1
	if rewind_index>0:
		var newer:Dictionary=rewind_path[rewind_index]
		var older:Dictionary=rewind_path[rewind_index-1]
		var weight:=clampf((float(newer.time)-source_time)/maxf(.001,float(newer.time)-float(older.time)),0,1)
		if not rewind_move((newer.position as Vector3).lerp(older.position,weight)):
			finish_rewind(true)
			return
	main.player.velocity=Vector3.ZERO
	if fraction>=1:
		rewind_move(rewind_destination)
		finish_rewind(true)

func finish_rewind(show_effect:bool) -> void:
	if not rewinding:return
	rewinding=false
	rewind_path.clear()
	history.clear()
	sample_time=0
	main.player.velocity=Vector3.ZERO
	if show_effect:
		fx.burst(main.player.global_position-Vector3.UP*.6,Catalog.DATA.rewind.color,.5,false)
		main.push_event("リワインド：復帰")
