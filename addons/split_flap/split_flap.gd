@tool
@icon("split_flap.svg")
class_name SplitFlap extends Control

#region SIGNALS
signal flipped
signal finished
#endregion

#region ENUMS
enum Presets {
	NUMERIC    = 0,
	ALPHABETIC = 1,
	CUSTOM     = 2
}
#endregion

#region CONSTANTS
const NUMERIC_SEQUENCE : Array[String] = [
	"0", "1", "2", "3", "4", "5", "6", "7", "8", "9"
]
const ALPHABETIC_SEQUENCE : Array[String] = [
	"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
	"N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"
]
#endregion

#region EXPORT VARIABLES
#region EXPORT VARIABLES: CHARACTER SET
@export_group("Character Set")

@export var preset := Presets.NUMERIC:
	set(value):
		preset = value
		match preset:
			Presets.NUMERIC:
				flap_sequence = NUMERIC_SEQUENCE
			Presets.ALPHABETIC:
				flap_sequence = ALPHABETIC_SEQUENCE
			Presets.CUSTOM:
				flap_sequence = []

@export var flap_sequence : Array[String]:
	set(value):
		for element in value:
			if element.length() > 1:
				return
		flap_sequence = value
		notify_property_list_changed()
		if is_inside_tree():
			for child in get_children():
				_apply_text(child)

@export_range(-1, 10, 1) var current_char_id := -1:
	set(value):
		current_char_id = wrapi(value, 0, flap_sequence.size() - 1)
		if is_inside_tree():
			for child in get_children():
				_apply_text(child)
#endregion

#region EXPORT VARIABLES: APPEARANCE
@export_group("Appearance")

@export var font : Font:
	set(value):
		font = value
		update_minimum_size()
		if is_inside_tree():
			for child in get_children():
				_apply_font_settings.call_deferred(child)

@export_range(8, 128, 1, "or_greater", "suffix:pixels") var font_size := 64:
	set(value):
		font_size = value
		update_minimum_size()
		if is_inside_tree():
			for child in get_children():
				_apply_font_settings.call_deferred(child)

@export var upper_segment : StyleBox:
	set(value):
		upper_segment = value
		if is_inside_tree():
			for child in get_children():
				_apply_stylebox(child)

@export var lower_segment : StyleBox:
	set(value):
		lower_segment = value
		if is_inside_tree():
			for child in get_children():
				_apply_stylebox(child)

@export_range(0, 6, 2, "or_greater", "suffix:pixels") var segment_separation := 2:
	set(value):
		segment_separation = value
		update_minimum_size()
		if is_inside_tree():
			for child in get_children():
				_apply_separation(child)
#endregion

#region EXPORT VARIABLES: ANIMATION
@export_group("Animation")

@export_range(0.0, 1.0, 0.1, "or_greater", "suffix:seconds") var flip_time := 0.3

@export var drop_shadow := true
#endregion

func _validate_property(property : Dictionary) -> void:
	if property.name == "flap_sequence":
		if preset != Presets.CUSTOM:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			property.usage = PROPERTY_USAGE_DEFAULT
	elif property.name == "current_char_id":
		property.hint_string = "-1, %s, 1" % (flap_sequence.size() - 1)
#endregion

var font_height := 0

var flip_tween : Tween


func _get_minimum_size() -> Vector2:
	if font:
		font_height = int(font.get_height(font_size))
	else:
		font_height = int(get_theme_default_font().get_height(font_size))

	# round to even number
	if font_height % 2 == 1:
		font_height += 1

	return Vector2(font_height, font_height + segment_separation)

func _enter_tree() -> void:
	if preset != Presets.CUSTOM:
		preset = preset # manually trigger setter

	_create_segment("UpperSegment")
	_create_segment("LowerSegment")
	_create_segment("MovingSegment")


func _create_segment(segment_name : String) -> void:
	var segment = Panel.new()
	segment.name = segment_name
	segment.clip_contents = true
	add_child(segment)

	var label = Label.new()
	label.name = "Label"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	segment.add_child(label)

	_apply_text(segment)
	_apply_stylebox(segment)
	_apply_font_settings(segment)



func _apply_text(segment : Panel) -> void:
	if current_char_id == -1 or current_char_id > flap_sequence.size() - 1:
		segment.get_node("Label").text = ""
	else:
		segment.get_node("Label").text = flap_sequence[current_char_id]


func _apply_stylebox(segment : Panel) -> void:
	if upper_segment and lower_segment:
		if segment.name == "LowerSegment":
			segment.add_theme_stylebox_override("panel", lower_segment)
		else:
			segment.add_theme_stylebox_override("panel", upper_segment)
	elif upper_segment and not lower_segment:
		segment.add_theme_stylebox_override("panel", upper_segment)
	elif lower_segment and not upper_segment:
		segment.add_theme_stylebox_override("panel", lower_segment)
	else:
		segment.add_theme_stylebox_override("panel", StyleBoxFlat.new())


func _apply_separation(segment : Panel) -> void:
	if segment.name == "LowerSegment":
		segment.position.y = 0.5 * font_height + segment_separation
	if segment.name == "MovingSegment":
		segment.pivot_offset.y = 0.5 * (font_height + segment_separation)


func _apply_font_settings(segment : Panel) -> void:
	segment.size = Vector2(font_height, 0.5 * font_height)
	segment.pivot_offset.y = 0.5 * font_height

	_apply_separation(segment)

	var label = segment.get_node("Label")
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)

	if segment.name == "LowerSegment":
		label.position.y = -0.5 * font_height
	label.size.x = segment.size.x


func flip_to(flap : String):
	if not flap in flap_sequence and not flap.to_upper() in flap_sequence:
		push_error("Cannot flip to '%s': There is no flap with that label" % flap)
		return

	var current_flap := flap_sequence[current_char_id]

	if current_flap == flap or current_flap == flap.to_upper():
		return

	while current_flap != flap and current_flap != flap.to_upper():
		await flip_forward()
		current_flap = flap_sequence[current_char_id]

	finished.emit()


func flip_forward():
	if flip_tween and flip_tween.is_running():
		return

	var next_char_id = wrapi(current_char_id + 1, 0, flap_sequence.size())
	$UpperSegment/Label.text = flap_sequence[next_char_id]
	if drop_shadow:
		$UpperSegment.modulate = Color.DARK_GRAY

	flip_tween = create_tween()
	flip_tween.tween_property($MovingSegment, "scale:y", 0.0, 0.5 * flip_time)
	if drop_shadow:
		flip_tween.parallel().tween_property($UpperSegment, "modulate", Color.WHITE, 0.5 * flip_time)

	flip_tween.tween_callback(func():
		$MovingSegment.position.y = 0.5 * font_height + segment_separation
		$MovingSegment.pivot_offset.y = -0.5 * segment_separation
		$MovingSegment/Label.text = flap_sequence[next_char_id]
		$MovingSegment/Label.position.y = -0.5 * font_height
		if lower_segment:
			$MovingSegment.add_theme_stylebox_override("panel", lower_segment)

		var random_color := Color(randf(), randf(), randf())
	)

	flip_tween.tween_property($MovingSegment, "scale:y", 1.0, 0.5 * flip_time)
	if drop_shadow:
		flip_tween.parallel().tween_property($LowerSegment, "modulate", Color.DARK_GRAY, 0.5 * flip_time)

	await flip_tween.finished

	if drop_shadow:
		$LowerSegment.modulate = Color.WHITE
	$LowerSegment/Label.text = flap_sequence[current_char_id]
	$MovingSegment.position.y = 0
	$MovingSegment.pivot_offset.y = 0.5 * (font_height + segment_separation)
	$MovingSegment/Label.position.y = 0
	if upper_segment:
		$MovingSegment.add_theme_stylebox_override("panel", upper_segment)

	current_char_id = wrapi(current_char_id + 1, 0, flap_sequence.size())
	flipped.emit()
