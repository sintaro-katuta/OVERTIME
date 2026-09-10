extends RefCounted
const Design=preload("res://gameplay/ui/interface_theme.gd")
static func build(main:Node) -> void:
	main.preparation_layer=CanvasLayer.new();main.preparation_layer.layer=2;main.add_child(main.preparation_layer)
	var overlay:=Control.new();overlay.theme=Design.create();overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);main.preparation_layer.add_child(overlay)
	var background:=TextureRect.new();background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var gradient:=Gradient.new();gradient.set_color(0,Color("253b40"));gradient.set_color(1,Color("09151c"));var texture:=GradientTexture2D.new();texture.gradient=gradient;texture.width=1280;texture.height=720;texture.fill_from=Vector2(0,1);texture.fill_to=Vector2(1,0);background.texture=texture;overlay.add_child(background)
	var header:=HBoxContainer.new();overlay.add_child(header);header.set_anchors_preset(Control.PRESET_TOP_WIDE);header.offset_left=38;header.offset_right=-38;header.offset_top=22;header.offset_bottom=82;header.add_theme_constant_override("separation",28)
	var brand:=VBoxContainer.new();brand.size_flags_horizontal=Control.SIZE_EXPAND_FILL;brand.add_theme_constant_override("separation",0);header.add_child(brand)
	Design.text(brand,"OVERTIME",32)
	for data in [["play","出撃準備"],["weapons","武器"],["skills","スキル"],["settings","設定"]]:
		var button:=Button.new();button.text=data[1];button.custom_minimum_size=Vector2(136,50);button.size_flags_vertical=Control.SIZE_SHRINK_CENTER;button.pressed.connect(main.select_preparation_tab.bind(data[0]));header.add_child(button);main.preparation_tab_buttons[data[0]]=button
	main.preparation_panel=PanelContainer.new();overlay.add_child(main.preparation_panel);main.preparation_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);main.preparation_panel.offset_left=38;main.preparation_panel.offset_right=-38;main.preparation_panel.offset_top=110;main.preparation_panel.offset_bottom=-52
	main.preparation_panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	main.preparation_content=VBoxContainer.new();main.preparation_content.size_flags_vertical=Control.SIZE_EXPAND_FILL;main.preparation_panel.add_child(main.preparation_content)
	main.preparation_level_label=Label.new();main.preparation_level_label.visible=false;overlay.add_child(main.preparation_level_label)
	main.preparation_action_area=CenterContainer.new();overlay.add_child(main.preparation_action_area);main.preparation_action_area.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT);main.preparation_action_area.offset_left=-420;main.preparation_action_area.offset_right=-58;main.preparation_action_area.offset_top=-130;main.preparation_action_area.offset_bottom=-66
	main.select_preparation_tab("play")
static func play(main:Node) -> void:
	var state:Dictionary=main.progression.preparation_view()
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",24);row.size_flags_vertical=Control.SIZE_EXPAND_FILL;main.preparation_content.add_child(row)
	var studio:=PanelContainer.new();studio.size_flags_horizontal=Control.SIZE_EXPAND_FILL;studio.add_theme_stylebox_override("panel",Design.plate(Color("13282c80"),Color("3d5657")));row.add_child(studio)
	var model_column:=VBoxContainer.new();model_column.add_theme_constant_override("separation",0);studio.add_child(model_column)
	var caption:=HBoxContainer.new();model_column.add_child(caption);Design.text(caption,"OPERATOR",14,Design.ACCENT);var level:=Design.text(caption,"PLAYER LEVEL  %02d"%int(state.player_level),14,Design.MUTED);level.size_flags_horizontal=Control.SIZE_EXPAND_FILL;level.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var preview:=preload("res://gameplay/preparation_character_preview.gd").new();preview.custom_minimum_size=Vector2(420,420);preview.size_flags_vertical=Control.SIZE_EXPAND_FILL;model_column.add_child(preview)
	var detail:=PanelContainer.new();detail.custom_minimum_size.x=380;detail.add_theme_stylebox_override("panel",Design.plate(Color("142329ec"),Color("344b4f"),1,20));row.add_child(detail)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",10);detail.add_child(column)
	Design.text(column,"装備",25,Design.TEXT)
	var id:=str(state.selected_weapon_id);var weapon_name:="未選択"
	for weapon in state.weapons:
		if str(weapon.id)==id:weapon_name=str(weapon.display_name);break
	Design.text(column,weapon_name,23)
	if not id.is_empty():
		var data:Dictionary=main.WeaponCatalogData.weapon(id)
		var weapon_preview=main.WeaponSelectionViewData.WeaponPreview.new();weapon_preview.weapon_id=id;var skin:Dictionary=main.WeaponCatalogData.skin(id,main.progression.selected_skin_id_for(id));weapon_preview.model_path=str(skin.get("model_path",data.model_path));weapon_preview.custom_minimum_size=Vector2(320,120);column.add_child(weapon_preview)
	var change:=Button.new();change.text="装備を変更  →";change.custom_minimum_size.y=40;change.pressed.connect(main.select_preparation_tab.bind("weapons"));column.add_child(change)
	for slot in 2:
		var skill_id: String = main.skills.selected[slot]
		Design.text(column, "%s  %s" % [main.control_settings.key_name("grapple" if slot == 0 else "skill_2"), main.skills.Catalog.DATA[skill_id].name if not skill_id.is_empty() else "スキル未装備"], 16, Design.ACCENT)
	var skill_change := Button.new();skill_change.text="スキルを変更  →";skill_change.pressed.connect(main.select_preparation_tab.bind("skills"));column.add_child(skill_change)
	var launch:=Button.new();launch.text="出撃する  →" if not id.is_empty() else "武器を選択  →";launch.custom_minimum_size=Vector2(338,58);Design.primary(launch)
	if id.is_empty():launch.pressed.connect(main.select_preparation_tab.bind("weapons"))
	elif not main.skills.valid_selection():
		launch.text="スキルを2個選択  →"
		launch.pressed.connect(main.select_preparation_tab.bind("skills"))
	else:launch.pressed.connect(main.begin_run_from_preparation)
	main.preparation_action_area.add_child(launch);launch.grab_focus()
