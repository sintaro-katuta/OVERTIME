# OVERTIME operator — preparation preview

Original Blender-authored armored operator, slate ceramic armor, charcoal undersuit, smoked visor, pouches, gloves and boots. Source: source/operator.blend. Rebuild with scripts/blender/build_player_operator.py, which creates a dedicated new scene without deleting existing scenes.

The GLB is displayed by gameplay/preparation_character_preview.gd in an isolated SubViewport. Gentle turntable movement comes from the preview, not skeletal animation. This asset currently replaces the preparation screen's 2D placeholder; it does not replace first-person hands or change player collision/movement. No rig or walk/run animation in this initial preview asset.

Issue #37 also removes the minimap's class, HUD container and redraw calls. Validation: run_result_flow_test and captured preparation/gameplay screens in docs/screenshots/player-operator/.
