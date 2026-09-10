extends RefCounted
const TEXT=Color("e4ece7")
const MUTED=Color("9eafb0")
const ACCENT=Color("92c8b7")
const PANEL=Color("17282e")
static func plate(bg:Color,border:Color=Color("30464a"),width:=1,padding:=12) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new();s.bg_color=bg;s.border_color=border;s.set_border_width_all(width);s.corner_radius_top_left=3;s.corner_radius_top_right=3;s.corner_radius_bottom_left=3;s.corner_radius_bottom_right=3;s.content_margin_left=padding;s.content_margin_right=padding;s.content_margin_top=8;s.content_margin_bottom=8;return s
static func create() -> Theme:
	var t:=Theme.new();t.default_font_size=16
	t.set_color("font_color","Label",TEXT)
	for type in ["Button","CheckButton","OptionButton"]:
		t.set_stylebox("normal",type,plate(Color("1b2b31")))
		t.set_stylebox("hover",type,plate(Color("2b454b"),ACCENT))
		t.set_stylebox("pressed",type,plate(Color("3b605f"),ACCENT,2))
		t.set_stylebox("disabled",type,plate(Color("142127"),Color("26383d")))
		t.set_stylebox("focus",type,plate(Color("00000000"),Color("c1e1bd"),2))
		t.set_color("font_color",type,TEXT);t.set_color("font_hover_color",type,Color.WHITE);t.set_color("font_pressed_color",type,Color.WHITE);t.set_color("font_disabled_color",type,Color("73868a"))
	t.set_stylebox("background","ProgressBar",plate(Color("23393e"),Color.TRANSPARENT,0,0));t.set_stylebox("fill","ProgressBar",plate(ACCENT,Color.TRANSPARENT,0,0))
	t.set_stylebox("slider","HSlider",plate(Color("33494d"),Color.TRANSPARENT,0,0));t.set_stylebox("grabber_area","HSlider",plate(ACCENT,Color.TRANSPARENT,0,0))
	t.set_stylebox("panel","PanelContainer",plate(PANEL));t.set_constant("separation","VBoxContainer",10)
	return t
static func text(parent:Node,value:String,size:int,color:=TEXT) -> Label:
	var l:=Label.new();l.text=value;l.add_theme_font_size_override("font_size",size);l.add_theme_color_override("font_color",color);parent.add_child(l);return l
static func primary(button:Button) -> void:
	button.add_theme_stylebox_override("normal",plate(ACCENT,ACCENT,1,20));button.add_theme_color_override("font_color",Color("10292b"));button.add_theme_font_size_override("font_size",22)
