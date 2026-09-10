extends VBoxContainer
var main:Node
var waiting:=""
var buttons:Dictionary={}
var message:Label
var sensitivity_label:Label
var volume_sliders: Dictionary = {}
var volume_labels: Dictionary = {}
func setup(owner_main:Node) -> void:
	main=owner_main;custom_minimum_size.x=1100;size_flags_horizontal=Control.SIZE_SHRINK_CENTER;add_theme_constant_override("separation",12)
	var design=preload("res://gameplay/ui/interface_theme.gd")
	design.text(self,"設定",28)
	var layout:=HBoxContainer.new();layout.add_theme_constant_override("separation",36);add_child(layout)
	var controls:=VBoxContainer.new();controls.custom_minimum_size.x=728;controls.add_theme_constant_override("separation",10);layout.add_child(controls)
	var groups:=HBoxContainer.new();groups.add_theme_constant_override("separation",24);controls.add_child(groups)
	for category in [["移動",["move_forward","move_back","move_left","move_right","jump","slide","dash"]],["戦闘",["shoot","aim","reload","grapple","skill_2"]]]:
		var column:=VBoxContainer.new();groups.add_child(column);design.text(column,category[0],18,design.ACCENT)
		var grid:=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",4);column.add_child(grid)
		for action in category[1]:
			var title:=Label.new();title.text=main.control_settings.ACTIONS[action];title.custom_minimum_size.x=150;grid.add_child(title)
			var button:=Button.new();button.custom_minimum_size=Vector2(160,32);button.text=main.control_settings.key_name(action);button.pressed.connect(begin_capture.bind(action));grid.add_child(button);buttons[action]=button
	var row:=HBoxContainer.new();controls.add_child(row)
	sensitivity_label=Label.new();sensitivity_label.custom_minimum_size.x=200;row.add_child(sensitivity_label)
	var slider:=HSlider.new();slider.min_value=.2;slider.max_value=3;slider.step=.05;slider.value=main.control_settings.sensitivity;slider.custom_minimum_size.x=300;row.add_child(slider)
	slider.value_changed.connect(func(value:float):main.control_settings.sensitivity=value;sensitivity_label.text="マウス感度  %.2f"%value;persist())
	sensitivity_label.text="マウス感度  %.2f"%slider.value
	var toggle:=CheckButton.new();toggle.name="AutomaticReload";toggle.text="弾切れ時に自動リロード";toggle.button_pressed=main.control_settings.automatic_reload;controls.add_child(toggle)
	toggle.toggled.connect(func(value:bool):main.control_settings.automatic_reload=value;main.automatic_reload_enabled=value;persist())
	var audio:=VBoxContainer.new();audio.custom_minimum_size.x=300;audio.add_theme_constant_override("separation",16);layout.add_child(audio)
	design.text(audio,"音量",22,design.ACCENT)
	for entry in [["master_volume","全体音量"],["effects_volume","効果音音量"]]:
		var id:String=entry[0]
		var label:=Label.new();audio.add_child(label);volume_labels[id]=label
		var volume:=HSlider.new();volume.name=id;volume.min_value=0;volume.max_value=100;volume.step=1;volume.custom_minimum_size=Vector2(300,32);volume.value=float(main.control_settings.get(id))*100;volume.tooltip_text=entry[1]+"：0%で消音";audio.add_child(volume);volume_sliders[id]=volume
		label.text="%s  %d%%"%[entry[1],roundi(volume.value)]
		volume.value_changed.connect(func(value:float):
			main.control_settings.set(id,value/100.0)
			label.text="%s  %d%%"%[entry[1],roundi(value)]
			persist())
	var hint:=Label.new();hint.text="効果音には操作音も含まれます。\n0%で消音 / 変更は自動保存";hint.add_theme_font_size_override("font_size",14);hint.add_theme_color_override("font_color",design.MUTED);audio.add_child(hint)
	var preview:=Button.new();preview.name="PreviewSound";preview.text="効果音を試聴";preview.custom_minimum_size.y=40;preview.pressed.connect(func():play_ui_sound("repulse"));audio.add_child(preview)
	var reset:=Button.new();reset.name="ResetSettings";reset.text="すべて初期設定に戻す";reset.custom_minimum_size.y=34;add_child(reset)
	reset.pressed.connect(func():
		waiting="";main.control_settings.reset();main.automatic_reload_enabled=true
		slider.set_value_no_signal(1);sensitivity_label.text="マウス感度  1.00";toggle.set_pressed_no_signal(true)
		for id in volume_sliders:
			volume_sliders[id].set_value_no_signal(100)
			volume_labels[id].text=("全体音量" if id=="master_volume" else "効果音音量")+"  100%"
		refresh();persist())
	message=Label.new();message.text="変更は自動で保存されます";add_child(message)
func begin_capture(action:String) -> void:
	play_ui_sound("ui_open")
	waiting=action;refresh();buttons[action].text="入力待ち…";message.text="割り当てるキーを押してください。Escで取消";buttons[action].add_theme_stylebox_override("normal",preload("res://gameplay/ui/interface_theme.gd").plate(Color("3b605f"),Color("b4e0c7"),2))
func refresh() -> void:
	for action in buttons:
		buttons[action].text=main.control_settings.key_name(action);buttons[action].remove_theme_stylebox_override("normal")
func persist() -> void:
	var result:int=main.control_settings.save()
	if result != OK: play_ui_sound("ui_error")
	if is_instance_valid(message):message.text="保存しました" if result==OK else "保存できませんでした（この起動中のみ反映）"
func _input(event:InputEvent) -> void:
	if waiting.is_empty() or not is_visible_in_tree():return
	var code:=0
	if event is InputEventKey and event.pressed and not event.echo:
		code=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if code==KEY_ESCAPE:
			play_ui_sound("ui_back")
			waiting="";refresh();message.text="割り当てを取り消しました";get_viewport().set_input_as_handled();return
	elif event is InputEventMouseButton and event.pressed:code=-event.button_index
	if code==0:return
	get_viewport().set_input_as_handled()
	var error:String=main.control_settings.assign(waiting,code)
	if not error.is_empty():play_ui_sound("ui_error");message.text=error+"。別のキーを押してください（Escで取消）";return
	waiting="";refresh();persist();play_ui_sound("ui_toggle")

func play_ui_sound(id: String) -> void:
	var audio = get_tree().get_first_node_in_group("game_audio")
	if is_instance_valid(audio): audio.emit(id)
