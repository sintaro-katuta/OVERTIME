extends Node3D
const Catalog=preload("res://gameplay/skills/skill_catalog.gd")
const G=preload("res://gameplay/skills/skill_geometry.gd")
const Sound=preload("res://gameplay/skills/skill_sound.gd")
var controller
var chain:Node3D
var links:Array[MeshInstance3D]=[]
var hook:Node3D
var launcher:Node3D
var muzzle:Node3D
var marker:Node3D
var vortex:Node3D
var chrono:Node3D
var dome:MeshInstance3D
var motes:Array[MeshInstance3D]=[]
var shield_surface:MeshInstance3D
var shield_impact_age:=10.0
var chrono_core:Node3D
var buff_caption:Label
var shield:Node3D
var shield_panels:Array[Node3D]=[]
var device:Node3D
var transients:Array[Dictionary]=[]
var sounds:Dictionary={}
var audio_player:AudioStreamPlayer
var impact_player:AudioStreamPlayer
var chain_end:=Vector3.ZERO
var chain_age:=0.0
var chain_return:=0.0
var chain_hit:=false
var phase:=0.0
var effect_age:=0.0
var flash_left:=0.0
var shake:=0.0
var impact_cooldown:=0.0
var previous_remaining:=0.0
var recall_hiding_weapon:=false
var weapon_was_visible:=true
var base_camera_offset:=Vector2.ZERO
var overlay:CanvasLayer
var edge:Control

class EdgeFlash extends Control:
	var tint:=Color.WHITE
	var strength:=0.0
	var streaks:=false
	var travel:=0.0
	func _draw() -> void:
		if strength<=0:return
		# Diagonal peripheral streaks leave the center and HUD untouched.
		for i in 24:
			var angle:=float(i)*TAU/24+.035
			var direction:=Vector2(cos(angle),sin(angle))
			var radius:=.57+fposmod(travel+float(i)*.137,.2)
			var start:=size*.5+direction*size*radius
			var finish:=size*.5+direction*size*(radius-.065 if streaks else radius-.02)
			draw_line(start,finish,Color(tint,strength*.38),2 if streaks else 1,true)

func node(parent:Node3D) -> Node3D:
	var n:=Node3D.new();parent.add_child(n);return n
func setup(owner_controller) -> void:
	controller=owner_controller;name="SkillEffects"
	base_camera_offset=Vector2(controller.main.camera.h_offset,controller.main.camera.v_offset)
	var metal:=G.material(Color("273b49"),1,true)
	var trim:=G.material(Color("708690"),1,true)
	var teal:=G.material(Catalog.DATA.grapple.color)
	chain=node(self)
	for i in 160: links.append(G.ring(chain,.041,.010,metal))
	hook=node(self)
	G.box(hook,Vector3.ZERO,Vector3(.12,.35,.12),trim)
	for i in 3:
		var a:=Vector3(cos(i*TAU/3),0,sin(i*TAU/3))*.18
		G.line(hook,a+Vector3.DOWN*.12,a+Vector3.UP*.18,.065,trim)
		G.line(hook,a+Vector3.UP*.18,Vector3.UP*.32,.045,teal)
	launcher=node(self)
	G.box(launcher,Vector3(0,-.04,.28),Vector3(.25,.22,.52),metal)
	G.box(launcher,Vector3(0,.04,.13),Vector3(.29,.13,.32),trim)
	for side in [-1,1]:
		G.box(launcher,Vector3(side*.12,.04,.14),Vector3(.028,.018,.36),teal)
		var spool:=G.ring(launcher,.13,.028,trim);spool.rotation.z=PI/2;spool.position=Vector3(side*.15,-.015,.24)
	var mouth:=G.ring(launcher,.10,.024,trim);mouth.rotation.x=PI/2
	muzzle=node(launcher);G.sphere(muzzle,Vector3.ZERO,.095,G.material(Catalog.DATA.grapple.color,.6))
	marker=node(self);G.hexagon(marker,Vector3.ZERO,.63,.018,teal)
	vortex=node(self)
	var ribbon_mat:=G.material(Color("b082ff"),.58)
	ribbon_mat.vertex_color_use_as_albedo=true
	for i in 3:G.spiral(vortex,i,ribbon_mat)
	G.sphere(vortex,Vector3.ZERO,.44,G.material(Color("111025")))
	for i in 3:
		var halo:=G.ring(vortex,.52+i*.13,.02 if i==0 else .007,G.material(Color("dcc5ff"),.7-i*.18));halo.rotation.x=PI/2
	for i in 64:
		var mote:=G.box(vortex,Vector3.ZERO,Vector3(.025,.025,.20),G.material(Color("dac0ff"),.8));motes.append(mote)
	chrono=node(self)
	dome=G.sphere(chrono,Vector3.ZERO,6,G.dome_material(Catalog.DATA.chrono.color))
	dome.scale.y=.3
	var equator:=G.ring(chrono,6,.032,G.material(Catalog.DATA.chrono.color,.8))
	equator.position.y=0
	for i in 48:
		var a:=float(i)*TAU/48
		var tick:=G.box(chrono,Vector3(cos(a)*6,0,sin(a)*6),Vector3(.045,.22 if i%4 else .55,.06),G.material(Catalog.DATA.chrono.color,.55))
		tick.rotation.y=-a
	chrono_core=node(chrono)
	G.box(chrono_core,Vector3(0,.1,0),Vector3(.65,.16,.65),metal)
	G.sphere(chrono_core,Vector3(0,.38,0),.17,G.material(Catalog.DATA.chrono.color))
	for i in 3:
		var orbit:=G.ring(chrono_core,.45+i*.12,.025,G.material(Catalog.DATA.chrono.color,.8))
		orbit.position.y=.2+i*.12;orbit.rotation=Vector3(i*.4,0,i*.5)
	for i in 12:
		var a:=float(i)*TAU/12
		G.line(chrono,Vector3(cos(a)*5.8,.04,sin(a)*5.8),Vector3(cos(a)*5.8,.8,sin(a)*5.8),.014,G.material(Catalog.DATA.chrono.color,.5))
	shield=node(self)
	var membrane:=QuadMesh.new();membrane.size=G.SHIELD_HALF*2
	shield_surface=G.mesh(shield,membrane,G.shield_material())
	device=node(self);G.sphere(device,Vector3.ZERO,.14,metal)
	for i in 3:
		var band:=G.ring(device,.19,.018,G.material(Catalog.DATA.vortex.color));band.rotation=Vector3(i*PI/3,i*.8,0)
	overlay=CanvasLayer.new();overlay.layer=7;add_child(overlay)
	edge=EdgeFlash.new();overlay.add_child(edge);edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);edge.mouse_filter=Control.MOUSE_FILTER_IGNORE
	buff_caption=Label.new();overlay.add_child(buff_caption);buff_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	buff_caption.offset_left=-160;buff_caption.offset_right=160;buff_caption.offset_top=152;buff_caption.offset_bottom=181
	buff_caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;buff_caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	buff_caption.text="連射ブースト ×1.5";buff_caption.add_theme_font_size_override("font_size",18)
	buff_caption.add_theme_color_override("font_color",Catalog.DATA.chrono.color);buff_caption.add_theme_constant_override("outline_size",4)
	buff_caption.add_theme_color_override("font_outline_color",Color("18251e"));buff_caption.visible=false
	audio_player=AudioStreamPlayer.new();audio_player.volume_db=-10;add_child(audio_player)
	impact_player=AudioStreamPlayer.new();impact_player.volume_db=-13;add_child(impact_player)
	# Sound is supplied by the shared CC0 audio manager.
	clear_effects()

func clear_effects() -> void:
	restore_recall_view()
	if is_instance_valid(buff_caption):buff_caption.visible=false
	shield_impact_age=10
	for item in transients:
		if is_instance_valid(item.node):item.node.queue_free()
	transients.clear()
	for n in [chain,hook,launcher,marker,vortex,chrono,shield,device]:
		if is_instance_valid(n):n.visible=false
	chain_return=0;chain_age=0;flash_left=0;shake=0;previous_remaining=0;effect_age=0;impact_cooldown=0
	if is_instance_valid(edge):edge.strength=0;edge.queue_redraw()
	if is_instance_valid(audio_player):audio_player.stop();impact_player.stop()
	if controller!=null and is_instance_valid(controller.main.camera):
		controller.main.camera.h_offset=base_camera_offset.x;controller.main.camera.v_offset=base_camera_offset.y

func play(id:String,impact:=false) -> void:
	controller.main.sfx.emit(id, controller.center if id in ["chrono","vortex"] else Vector3.INF)
func flash(color:Color) -> void:
	flash_left=.35;edge.tint=color;effect_age=0
	shake=.024 if controller.equipped=="repulse" else .012
	play(controller.equipped)
func transient(n:Node3D,life:float,velocity:=Vector3.ZERO,growth:=0.0,delay:=0.0) -> void:
	transients.append({"node":n,"age":-delay,"life":life,"velocity":velocity,"growth":growth,"initial":n.scale})
	n.visible=delay<=0
func fade(n:Node3D,amount:float) -> void:
	if n is GeometryInstance3D:n.transparency=amount
	for child in n.get_children():
		if child is Node3D:fade(child,amount)
func burst(pos:Vector3,color:Color,radius:float,waves:=true) -> void:
	if transients.size()>160:return
	for i in (2 if waves else 0):
		var wave:=G.ring(self,.35,.018,G.material(color,.55));wave.global_position=pos;wave.quaternion=Quaternion(Vector3.UP,(controller.main.camera.global_position-pos).normalized())
		wave.scale=Vector3.ONE*(1+float(i)*.15)
		transient(wave,.4,Vector3.ZERO,radius*2)
	for i in 18:
		var spark:=G.box(self,pos,Vector3(.024,.024,.16),G.material(color))
		var heading:=Vector3(sin(i*2.4),cos(i*1.7)*.7,cos(i*2.4)).normalized()
		spark.quaternion=Quaternion(Vector3.BACK,heading);transient(spark,.22+float(i%4)*.07,heading*maxf(radius,2)*3)
func repulse(origin:Vector3,forward:Vector3) -> void:
	var color:Color=Catalog.DATA.repulse.color
	for i in 4:
		var wave:=G.ring(self,.36,.026,G.material(color,.8-float(i)*.12))
		wave.global_position=origin+forward*(.8+i*.5)
		wave.quaternion=Quaternion(Vector3.UP,forward)
		transient(wave,.36,forward*(13+i*2),8.0,float(i)*.035)
	var cone:=CylinderMesh.new();cone.top_radius=2.2;cone.bottom_radius=.12;cone.height=4;cone.radial_segments=48
	var pressure:=G.mesh(self,cone,G.material(color,.065));pressure.global_position=origin+forward*2.4;pressure.quaternion=Quaternion(Vector3.UP,forward)
	transient(pressure,.22,forward*10,1)
	burst(origin+forward*2,color,1.5,false)
func start_chain(target:Vector3) -> void:
	chain_age=0;chain_return=0;chain_end=target;chain_hit=false
func shield_impact(pos:Vector3) -> void:
	shield_impact_age=0
	var origin:Vector3=controller.main.camera.global_position-controller.main.camera.global_basis.z*G.SHIELD_DISTANCE
	var local:Vector3=controller.main.camera.global_basis.inverse()*(pos-origin)
	shield_surface.material_override.set_shader_parameter("impact_point",Vector2(local.x,local.y))
	if transients.size()>160:return
	var impact:=node(self);impact.global_transform=controller.main.camera.global_transform;impact.global_position=pos
	G.hexagon(impact,Vector3.ZERO,.12,.015,G.material(Color("d9faff"),.9))
	G.hexagon(impact,Vector3.ZERO,.22,.006,G.material(Catalog.DATA.aegis.color,.65))
	transient(impact,.38,Vector3.ZERO,5)
	burst(pos,Catalog.DATA.aegis.color,.22,false)
	if impact_cooldown<=0:play("impact",true);impact_cooldown=.1;shake=maxf(shake,.009)
func rewind_trail(history:Array[Dictionary]) -> void:
	var color:Color=Catalog.DATA.rewind.color
	for i in range(0,history.size(),5):
		if (history[i].position as Vector3).distance_to(history[0].position)<1.6:continue
		var ghost:=node(self);ghost.global_position=history[i].position;ghost.rotation.y=float(history[i].get("yaw",0))
		G.silhouette(ghost,G.material(color,.3))
		var delay:=float(history.size()-i)/float(maxi(1,history.size()))*.24
		transient(ghost,.55,Vector3.ZERO,0,delay)
		if i+5<history.size():
			for side in [-1,1]:
				var start:Vector3=history[i].position+Vector3(side*.32,0,0)
				var end:Vector3=history[i+5].position+Vector3(side*.32,0,0)
				var trail:=G.line(self,start,end,.023,G.material(color,.65));transient(trail,.5,Vector3.ZERO,0,delay)

func _process(delta:float) -> void:
	if controller==null:return
	audio_player.stream_paused=controller.main.game_paused;impact_player.stream_paused=controller.main.game_paused
	if not controller.is_running():return
	shield_impact_age+=delta
	phase+=delta;effect_age+=delta;impact_cooldown=maxf(0,impact_cooldown-delta)
	flash_left=maxf(0,flash_left-delta);shake=move_toward(shake,0,delta*.085)
	# Only the runtime with an active shake owns camera offsets.
	if shake > 0 or controller == controller.main.skills:
		controller.main.camera.h_offset=base_camera_offset.x+sin(phase*137)*shake
		controller.main.camera.v_offset=base_camera_offset.y+cos(phase*111)*shake*.65
	edge.strength=flash_left/.35;edge.streaks=controller.equipped in ["grapple","rewind"];edge.travel=phase*.5;edge.queue_redraw()
	for i in range(transients.size()-1,-1,-1):
		var item:Dictionary=transients[i];item.age+=delta
		if item.age<0:continue
		item.node.visible=true
		if item.age>=item.life:item.node.queue_free();transients.remove_at(i);continue
		var fraction:float=item.age/item.life
		item.node.scale=item.initial*(1+item.growth*(1-pow(1-fraction,2)))
		item.node.position+=item.velocity*delta
		fade(item.node,pow(fraction,1.5))
	if controller.rewinding:
		if not recall_hiding_weapon:
			weapon_was_visible=controller.main.weapon.visible
			recall_hiding_weapon=true
		controller.main.weapon.visible=false
		controller.main.ui_crosshair.visible=false
		var progress:float=controller.rewind_age/controller.RECALL_DURATION
		controller.main.camera.fov=82+sin(progress*PI)*16
		edge.strength=maxf(edge.strength,.65*sin(progress*PI));edge.streaks=true;edge.travel=-phase*1.8
	else:restore_recall_view()
	update_chain(delta)
	marker.visible=false
	if controller.equipped == "grapple" and controller.main.grapple_kill_window>0 and is_instance_id_valid(controller.main.grapple_kill_target_id):
		var target=instance_from_id(controller.main.grapple_kill_target_id)
		if is_instance_valid(target):
			marker.visible=true;marker.global_position=target.global_position+Vector3.UP
			marker.look_at(controller.main.camera.global_position);marker.scale=Vector3.ONE*(1+sin(phase*13)*.04)
	device.visible=controller.device_time>0
	if device.visible:
		device.global_position=controller.device_from.lerp(controller.center,1-controller.device_time/.45);device.rotate_y(delta*12)
	var active:bool=controller.remaining>0
	if previous_remaining>0 and not active:
		burst(controller.center,Catalog.DATA[controller.equipped].color,.7) if controller.equipped!="aegis" else burst(shield.global_position,Catalog.DATA.aegis.color,.4)
	previous_remaining=controller.remaining
	var reveal:=clampf((effect_age-(.45 if controller.equipped=="vortex" else 0))/.24,0,1)*minf(1,controller.remaining/.3)
	vortex.visible=active and controller.equipped=="vortex"
	chrono.visible=active and controller.equipped=="chrono"
	if vortex.visible:
		vortex.global_position=controller.center;vortex.look_at(controller.main.camera.global_position);vortex.rotate_object_local(Vector3.BACK,phase*1.5);vortex.scale=Vector3.ONE*maxf(.001,reveal)
		for i in motes.size():
			var t:=fposmod(float(i)/64-phase*.6,1);var angle:=i*2.4+t*TAU
			motes[i].position=Vector3(cos(angle),sin(angle),.05)*(.6+t*5.8)
			motes[i].quaternion=Quaternion(Vector3.BACK,Vector3(-sin(angle),cos(angle),.1).normalized());motes[i].scale=Vector3(1,1,1+t*3)
	buff_caption.visible=controller.equipped == "chrono" and controller.fire_rate_bonus()>1
	if chrono.visible:
		chrono.global_position=controller.center;chrono.scale=Vector3.ONE*maxf(.001,reveal)
		dome.material_override.set_shader_parameter("clock",phase)
		chrono_core.rotation.y=phase*2.5
		chrono_core.scale=Vector3.ONE*(1+sin(phase*5)*.06)
	shield.visible=active and controller.equipped=="aegis"
	if shield.visible:
		shield.global_transform=controller.main.camera.global_transform;shield.global_position-=controller.main.camera.global_basis.z*G.SHIELD_DISTANCE
		shield.scale=Vector3.ONE*maxf(.001,reveal)
		shield_surface.material_override.set_shader_parameter("clock",phase)
		shield_surface.material_override.set_shader_parameter("impact_age",shield_impact_age)

func update_chain(delta:float) -> void:
	var main:Node3D=controller.main
	var pulling:bool=controller.equipped == "grapple" and main.grapple_time>0 and is_instance_valid(main.grapple_target)
	if pulling:
		chain_age+=delta;chain_return=.22;chain_end=main.grapple_target.global_position+Vector3(0,.9,0)
		if chain_age>=.075 and not chain_hit:
			chain_hit=true;burst(chain_end,Catalog.DATA.grapple.color,.5,false);play("impact",true);shake=maxf(shake,.015)
	else:chain_return=maxf(0,chain_return-delta)
	chain.visible=pulling or chain_return>0;hook.visible=chain.visible
	launcher.visible=controller.equipped=="grapple" and (chain.visible or effect_age<.55)
	if not chain.visible and not launcher.visible:return
	launcher.global_transform=main.camera.global_transform
	launcher.scale=Vector3.ONE*.65
	launcher.global_position=main.camera.global_position-main.camera.global_basis.x*.40-main.camera.global_basis.y*(.33+minf(.18,maxf(0,effect_age-.4)))-main.camera.global_basis.z*.8
	muzzle.visible=pulling and chain_age<.11
	if not chain.visible:return
	var start:Vector3=launcher.global_position
	var end:=start.lerp(chain_end,minf(1,chain_age/.075) if pulling else chain_return/.22)
	var direction:=end-start
	var count:=mini(links.size(),maxi(2,int(direction.length()/.115)))
	for i in links.size():
		links[i].visible=i<count
		if i>=count:continue
		var t:=float(i)/maxf(1,count-1)
		links[i].global_position=start.lerp(end,t)+Vector3.DOWN*sin(t*PI)*(.025 if pulling else .18)
		links[i].quaternion=Quaternion(Vector3.FORWARD,direction.normalized()) if direction.length()>.001 else Quaternion.IDENTITY
		links[i].rotate_object_local(Vector3.FORWARD,PI/2 if i%2==0 else 0);links[i].scale=Vector3(1,1,1.55)
	hook.global_position=end
	if direction.length()>.001:hook.quaternion=Quaternion(Vector3.UP,direction.normalized())

func restore_recall_view() -> void:
	if recall_hiding_weapon and controller!=null and is_instance_valid(controller.main.weapon):
		controller.main.weapon.visible=weapon_was_visible
		controller.main.camera.fov=82
	recall_hiding_weapon=false
