extends Control
## Combat-only presentation. Gameplay state remains owned by main.
const INK=Color("0b1722df")
const TEXT=preload("res://gameplay/ui/interface_theme.gd").TEXT
const MUTED=preload("res://gameplay/ui/interface_theme.gd").MUTED
const TEAL=preload("res://gameplay/ui/interface_theme.gd").ACCENT
const WARN=Color("e9bb72")
const DANGER=Color("f08a78")
var stage_label:Label
var time_caption:Label
var reserve_label:Label
var capacity_label:Label
var ability_panel:PanelContainer
var reload_bar:ProgressBar
var gain_label:Label
var gain_remaining:=0.0
var stage_seen:=-1
var second_heading:Label
var second_status:Label
var grapple_heading:Label
var passive_labels:Dictionary={}
const PASSIVES={"overclock":"連射強化", "time_siphon":"時間報酬強化", "ammo_rig":"予備弾拡張", "chrono_drive":"クロノ・ドライブ", "phase_shell":"被弾軽減", "dash_core":"ダッシュ強化"}

func panel(where:int,offset:Vector2,dimensions:Vector2) -> PanelContainer:
	var p:=PanelContainer.new();p.set_anchors_preset(where);p.position=offset;p.size=dimensions
	var gradient:=Gradient.new();gradient.set_color(0,Color("09151f96"));gradient.set_color(1,Color("09151f00"))
	var texture:=GradientTexture2D.new();texture.gradient=gradient;texture.width=256;texture.height=8
	texture.fill_from=Vector2(0,.5);texture.fill_to=Vector2(1,.5)
	var style:=StyleBoxTexture.new();style.texture=texture;style.content_margin_left=12;style.content_margin_right=12;style.content_margin_top=7;style.content_margin_bottom=7
	p.add_theme_stylebox_override("panel",style);add_child(p);return p

func label(parent:Node,text_value:String,font_size:int,color:=TEXT) -> Label:
	var l:=Label.new();l.text=text_value;l.add_theme_font_size_override("font_size",font_size);l.add_theme_color_override("font_color",color)
	l.add_theme_constant_override("outline_size",2);l.add_theme_color_override("font_outline_color",Color("09121bbb"));parent.add_child(l);return l
func bar(parent:Node,color:Color,height:=3.0) -> ProgressBar:
	var b:=ProgressBar.new();b.show_percentage=false;b.custom_minimum_size.y=height
	var fill:=StyleBoxFlat.new();fill.bg_color=color;b.add_theme_stylebox_override("fill",fill)
	var bg:=StyleBoxFlat.new();bg.bg_color=Color("33434c");b.add_theme_stylebox_override("background",bg);parent.add_child(b);return b
func setup(main:Node) -> void:
	name="CombatHUD";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_IGNORE
	var objective:=panel(Control.PRESET_TOP_LEFT,Vector2(24,24),Vector2(310,80));var objective_content:=VBoxContainer.new();objective.add_child(objective_content)
	stage_label=label(objective_content,"",13,MUTED)
	main.ui_status=label(objective_content,"",21)
	var timer:=panel(Control.PRESET_CENTER_TOP,Vector2(-110,20),Vector2(220,94));var timer_content:=VBoxContainer.new();timer_content.add_theme_constant_override("separation",0);timer.add_child(timer_content)
	time_caption=label(timer_content,"残り時間",12,MUTED);time_caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	main.ui_time=label(timer_content,"",42,TEXT);main.ui_time.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	main.ui_time_bar=bar(timer_content,TEAL);main.time_fill_style=main.ui_time_bar.get_theme_stylebox("fill")
	gain_label=label(self,"",19,TEAL);gain_label.set_anchors_preset(Control.PRESET_CENTER_TOP);gain_label.offset_left=-140;gain_label.offset_right=140;gain_label.offset_top=118;gain_label.offset_bottom=148;gain_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;gain_label.visible=false
	var ammo:=panel(Control.PRESET_BOTTOM_RIGHT,Vector2(-264,-130),Vector2(240,106));var ammo_content:=VBoxContainer.new();ammo_content.add_theme_constant_override("separation",1);ammo.add_child(ammo_content)
	main.ui_weapon_title=label(ammo_content,"",13,MUTED)
	var ammo_row:=HBoxContainer.new();ammo_row.add_theme_constant_override("separation",12);ammo_content.add_child(ammo_row)
	main.ui_ammo=label(ammo_row,"",38);capacity_label=label(ammo_row,"",15,MUTED);capacity_label.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	reserve_label=label(ammo_content,"",13,MUTED)
	reload_bar=bar(ammo_content,TEAL,3);reload_bar.visible=false
	main.ui_reload_prompt=label(self,"",16,WARN);main.ui_reload_prompt.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT);main.ui_reload_prompt.offset_left=-264;main.ui_reload_prompt.offset_top=-160;main.ui_reload_prompt.offset_right=-24;main.ui_reload_prompt.offset_bottom=-136
	ability_panel=panel(Control.PRESET_BOTTOM_LEFT,Vector2(24,-205),Vector2(350,181));var ability_content:=VBoxContainer.new();ability_panel.add_child(ability_content)
	grapple_heading=label(ability_content,"Q  グラップル",13,MUTED);main.ui_grapple=label(ability_content,"",17,TEAL)
	second_heading=label(ability_content,"",13,MUTED)
	second_status=label(ability_content,"",17,TEAL)
	var passive_grid:=GridContainer.new();passive_grid.columns=2;passive_grid.add_theme_constant_override("h_separation",20);ability_content.add_child(passive_grid)
	for id in PASSIVES:
		var passive:=HBoxContainer.new();passive.add_theme_constant_override("separation",6);passive_grid.add_child(passive)
		var icon:=TextureRect.new();icon.texture=load("res://assets/ui-interface/"+id+".svg");icon.custom_minimum_size=Vector2(18,18);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;passive.add_child(icon)
		label(passive,PASSIVES[id],13,MUTED);passive.visible=false;passive_labels[id]=passive
	main.ui_crosshair=label(self,"+",24);main.ui_crosshair.set_anchors_preset(Control.PRESET_CENTER);main.ui_crosshair.offset_left=-12;main.ui_crosshair.offset_top=-17;main.ui_crosshair.offset_right=12;main.ui_crosshair.offset_bottom=17;main.ui_crosshair.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	main.ui_damage_indicator=label(self,"▲",28,DANGER);main.ui_damage_indicator.visible=false;main.ui_damage_indicator.set_anchors_preset(Control.PRESET_CENTER);main.ui_damage_indicator.offset_left=-18;main.ui_damage_indicator.offset_top=-105;main.ui_damage_indicator.offset_right=18;main.ui_damage_indicator.offset_bottom=-69;main.ui_damage_indicator.pivot_offset=Vector2(18,18);main.ui_damage_indicator.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var events:=VBoxContainer.new();events.set_anchors_preset(Control.PRESET_BOTTOM_LEFT);events.position=Vector2(24,-310);events.size=Vector2(440,92);events.add_theme_constant_override("separation",6);add_child(events)
	for i in 3:
		var event:=label(events,"",15);event.visible=false;main.ui_event_labels.append(event)
	# Legacy combo data is still maintained by gameplay, but no duplicate toast is shown.
	main.toast_panel=PanelContainer.new();main.toast_panel.visible=false;add_child(main.toast_panel);main.ui_combo=Label.new();main.toast_panel.add_child(main.ui_combo)
	ignore_mouse(self)
func ignore_mouse(node:Node) -> void:
	if node is Control:node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():ignore_mouse(child)
func refresh(main:Node) -> void:
	var second = main.skills.second
	second_heading.visible = not second.equipped.is_empty()
	second_status.visible = second_heading.visible
	if second_heading.visible:
		second_heading.text = main.control_settings.key_name("skill_2") + "  " + str(second.Catalog.DATA[second.equipped].name)
		second_status.text = second.hud_text() + ("  /  再使用 %.1f秒" % second.cooldown if second.cooldown > 0 and second.remaining > 0 else "")
		second_status.add_theme_color_override("font_color", second.Catalog.DATA[second.equipped].color)
	var has_skill: bool = not main.skills.equipped.is_empty()
	grapple_heading.text=main.control_settings.key_name("grapple")+"  "+(str(main.skills.Catalog.DATA[main.skills.equipped].name) if has_skill else "グラップル")
	main.ui_time.add_theme_color_override("font_color",DANGER if main.time_left<8 and not main.stage_cleared else TEXT)
	stage_label.text="%02d  /  %s%s"%[main.current_stage,main.STAGE_NAMES[main.current_stage-1],"  ·  WAVE %d/2"%main.stage_wave if main.current_stage>=2 else ""]
	time_caption.text="時間停止" if main.stage_cleared else "残り時間わずか" if main.time_left<8 else "残り時間"
	capacity_label.text="/ %02d"%main.active_magazine_capacity()
	reserve_label.text="予備弾  %03d"%main.reserve_ammo
	var any_passive:=false
	for id in passive_labels:
		passive_labels[id].visible=main.owned_rewards.has(id)
		any_passive=any_passive or passive_labels[id].visible
	ability_panel.visible=has_skill or second_heading.visible or main.has_grapple or any_passive
	grapple_heading.visible=has_skill or main.has_grapple
	main.ui_grapple.visible=has_skill or main.has_grapple
	if stage_seen!=main.current_stage:
		stage_seen=main.current_stage;gain_remaining=0;gain_label.visible=false
	main.ui_grapple.text=main.skills.hud_text() if has_skill else ("使用可能" if main.grapple_cooldown<=0 else "あと %.1f 秒"%main.grapple_cooldown)
	if has_skill and main.skills.cooldown > 0 and main.skills.remaining > 0: main.ui_grapple.text += "  /  再使用 %.1f秒" % main.skills.cooldown
	if has_skill: main.ui_grapple.add_theme_color_override("font_color",main.skills.Catalog.DATA[main.skills.equipped].color)
	reload_bar.visible=main.reloading
	if main.reloading:reload_bar.value=clampf(1.0-main.reload_timer/maxf(main.active_reload_duration(),.01),0,1)*100
	main.ui_reload_prompt.visible=main.game_active and (main.reloading or main.ammo<=0 or main.ammo<=int(main.active_magazine_capacity()*.2))
	main.ui_reload_prompt.text="装填中…" if main.reloading else "弾薬なし" if main.ammo<=0 and main.reserve_ammo<=0 else main.control_settings.key_name("reload")+"  リロード" if main.ammo<=0 else "残弾わずか  ·  "+main.control_settings.key_name("reload")+" リロード"

func show_time_change(amount:float) -> void:
	if absf(amount)<.005:return
	gain_label.text=("+%.2f 秒" if amount>0 else "−%.2f 秒")%absf(amount)
	gain_label.add_theme_color_override("font_color",TEAL if amount>0 else DANGER)
	gain_remaining=1.6;gain_label.modulate.a=1.0;gain_label.visible=true
func _process(delta:float) -> void:
	if not is_visible_in_tree():return
	gain_remaining=maxf(0,gain_remaining-delta)
	if is_instance_valid(gain_label):
		gain_label.visible=gain_remaining>0
		gain_label.modulate.a=minf(1,gain_remaining/.4)
		gain_label.offset_top=118-(1.0-gain_remaining/1.6)*8;gain_label.offset_bottom=gain_label.offset_top+30
