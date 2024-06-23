extends Control

var test_string = "SplitFlap"

var flaps_finished := 0


func _ready() -> void:
	for letter in test_string.split():
		var split_flap := SplitFlap.new()
		split_flap.preset = split_flap.SequencePresets.ALPHABETIC
		var random_color := Color(
			randf_range(0.3, 0.7),
			randf_range(0.3, 0.7),
			randf_range(0.3, 0.7)
		)
		var style_box := StyleBoxFlat.new()
		style_box.bg_color = random_color
		style_box.corner_radius_top_left = 12
		style_box.corner_radius_top_right = 12
		split_flap.upper_flap = style_box
		style_box = StyleBoxFlat.new()
		style_box.bg_color = random_color
		style_box.corner_radius_bottom_left = 12
		style_box.corner_radius_bottom_right = 12
		split_flap.lower_flap = style_box
		split_flap.font_size = 128
		split_flap.flap_separation = 6
		$HBoxContainer.add_child(split_flap)

	await get_tree().create_timer(0.5).timeout

	for i in test_string.length():
		var child := $HBoxContainer.get_child(i)
		child.flip_to(test_string[i])
		child.finished.connect(_on_split_flap_finished)
		await child.flipped


func _on_split_flap_finished() -> void:
	flaps_finished += 1

	if flaps_finished == $HBoxContainer.get_child_count():
		await get_tree().create_timer(3.0).timeout
		get_tree().reload_current_scene() # restart the demo
