extends Control

# FIXME: only capital letters work!
var test_string = "SPLITFLAP"


func _ready() -> void:
	for letter in test_string.split():
		var split_flap := SplitFlap.new()
		split_flap.preset = split_flap.Presets.ALPHABETIC
		var style_box := StyleBoxFlat.new()
		style_box.bg_color = Color.MEDIUM_VIOLET_RED
		style_box.corner_radius_top_left = 12
		style_box.corner_radius_top_right = 12
		style_box.corner_radius_bottom_left = 12
		style_box.corner_radius_bottom_right = 12
		split_flap.segment_stylebox = style_box
		split_flap.font_size = 128
		split_flap.segment_separation = 6
		$HBoxContainer.add_child(split_flap)

	await get_tree().create_timer(1.0).timeout

	for i in test_string.length():
		$HBoxContainer.get_child(i).flip_to(test_string[i])

	# TODO: emit signal when flip_to target was reached
	await get_tree().create_timer(8.0).timeout

	get_tree().reload_current_scene() # restart the demo
