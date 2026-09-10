extends CanvasLayer
const Catalog = preload("res://gameplay/skills/skill_catalog.gd")
var controller
var backdrop: ColorRect
var title_label: Label
var tag_label: Label
var description: Label
var cooldown_label: Label
var accept_button: Button
var skip_button: Button
var emblem: Control
var panel: PanelContainer

class Emblem extends Control:
	var id := "grapple"
	var tint := Color.WHITE
	func _draw() -> void:
		var c := size/2
		draw_circle(c,92,Color(tint,.06))
		draw_arc(c,94,.2,TAU-.2,64,Color(tint,.4),2,true)
		for i in 12:
			var v:=Vector2.from_angle(i*TAU/12)
			draw_line(c+v*103,c+v*109,tint,2,true)
		match id:
			"grapple":
				for i in 5: draw_arc(c+Vector2(-40+i*16,40-i*16),12,0,TAU,20,tint,4,true)
				draw_polyline(PackedVector2Array([c+Vector2(10,-60),c+Vector2(48,-60),c+Vector2(48,-22),c+Vector2(30,-10)]),tint,5,true)
			"repulse":
				for r in [24,44,64]: draw_arc(c,r,-2.5,-.65,28,tint,5,true)
				draw_line(c+Vector2(0,55),c+Vector2(0,-5),tint,6,true)
				draw_polyline(PackedVector2Array([c+Vector2(-17,12),c+Vector2(0,-5),c+Vector2(17,12)]),tint,5,true)
			"rewind":
				draw_arc(c,54,-1.5,3.7,40,tint,5,true)
				draw_polyline(PackedVector2Array([c+Vector2(-62,-4),c+Vector2(-46,-29),c+Vector2(-22,-14)]),tint,5,true)
				draw_polyline(PackedVector2Array([c+Vector2(0,-30),c,c+Vector2(25,12)]),tint,5,true)
			"vortex":
				var points:=PackedVector2Array()
				for i in 100:
					var t:=float(i)/99; points.append(c+Vector2.from_angle(t*TAU*2.5)*(8+t*59))
				draw_polyline(points,tint,4,true)
			"chrono":
				draw_arc(c,60,0,TAU,48,tint,3,true)
				for x in [-15,15]: draw_line(c+Vector2(x,-28),c+Vector2(x,28),tint,9,true)
			"aegis":
				draw_polyline(PackedVector2Array([c+Vector2(0,-60),c+Vector2(47,-40),c+Vector2(40,22),c+Vector2(0,60),c+Vector2(-40,22),c+Vector2(-47,-40),c+Vector2(0,-60)]),tint,5,true)
				draw_line(c+Vector2(0,-28),c+Vector2(0,30),tint,3,true)

func text(parent: Node, value: String, size_value: int, color: Color) -> Label:
	var label := Label.new(); label.text=value; label.add_theme_font_size_override("font_size",size_value); label.add_theme_color_override("font_color",color); parent.add_child(label); return label

func setup(owner_controller) -> void:
	controller=owner_controller; layer=20
	backdrop=ColorRect.new(); backdrop.color=Color("08111bed"); backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(backdrop)
	var center:=CenterContainer.new(); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); backdrop.add_child(center)
	panel=PanelContainer.new(); panel.custom_minimum_size=Vector2(840,490); center.add_child(panel)
	var style:=StyleBoxFlat.new(); style.bg_color=Color("142634"); style.border_color=Color("70949d"); style.set_border_width_all(1); style.border_width_left=5; style.set_content_margin_all(32); panel.add_theme_stylebox_override("panel",style)
	var column:=VBoxContainer.new(); column.add_theme_constant_override("separation",16); panel.add_child(column)
	text(column,"希少スキル発見",18,Color("e8c787"))
	var row:=HBoxContainer.new(); row.add_theme_constant_override("separation",36); column.add_child(row)
	emblem=Emblem.new(); emblem.custom_minimum_size=Vector2(236,240); row.add_child(emblem)
	var body:=VBoxContainer.new(); body.size_flags_horizontal=Control.SIZE_EXPAND_FILL; body.add_theme_constant_override("separation",12); row.add_child(body)
	tag_label=text(body,"",15,Color("9fb3bf"))
	title_label=text(body,"",36,Color("eff6f8"))
	description=text(body,"",18,Color("dae5e9")); description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; description.custom_minimum_size.x=448
	cooldown_label=text(body,"",15,Color("9fb3bf"))
	column.add_child(HSeparator.new())
	text(column,"取得すると、このランのスキルが確定します。変更・追加取得はできません。",16,Color("e8c787"))
	var actions:=HBoxContainer.new(); actions.add_theme_constant_override("separation",20); column.add_child(actions)
	accept_button=Button.new(); accept_button.text="このスキルを取得"; accept_button.custom_minimum_size=Vector2(370,52); actions.add_child(accept_button)
	skip_button=Button.new(); skip_button.text="見送る"; skip_button.custom_minimum_size=Vector2(370,52); actions.add_child(skip_button)
	for button in [accept_button,skip_button]:
		button.add_theme_font_size_override("font_size",18)
		var normal:=StyleBoxFlat.new(); normal.bg_color=Color("284857"); normal.set_content_margin_all(12); normal.set_border_width_all(1); normal.border_color=Color("6c919e"); button.add_theme_stylebox_override("normal",normal)
		var hover:=normal.duplicate(); hover.bg_color=Color("396377"); button.add_theme_stylebox_override("hover",hover)
		var focus:=StyleBoxFlat.new(); focus.bg_color=Color.TRANSPARENT; focus.set_border_width_all(3); focus.border_color=Color("f5dfac"); button.add_theme_stylebox_override("focus",focus)
	text(column,"見送った場合、次の出現は保証されません。通常の強化報酬はこの後に選べます。",14,Color("aabdc6"))
	accept_button.pressed.connect(resolve.bind(true)); skip_button.pressed.connect(resolve.bind(false))
	visible=false

func show_offer() -> void:
	var data: Dictionary=Catalog.DATA[controller.offered]
	title_label.text=data.name; tag_label.text=data.tag; description.text=data.description
	cooldown_label.text="再使用 %.1f 秒  /  %s キーで発動" % [data.cooldown,controller.main.control_settings.key_name("grapple")]
	emblem.id=controller.offered; emblem.tint=data.color; emblem.queue_redraw()
	panel.get_theme_stylebox("panel").border_color=data.color
	visible=true; accept_button.grab_focus()

func hide_offer() -> void:
	visible=false

func resolve(accept: bool) -> void:
	if not visible or not controller.choose(accept): return
	visible=false
	controller.main.shop.visible=true
	controller.main.reward_buttons[0].grab_focus()
	controller.main.update_ui()
