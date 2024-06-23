@tool
@icon("split_flap.svg")
class_name SplitFlap extends Control
## A control that emulates a split-flap display.
##
## A control that emulates a split-flap display. It steps through a fixed array of characters
## (predefined by the user) until it reaches the target character. Each character gets vertically
## split into two halves, and when the current character changes, the upper half will drop down.

#region SIGNALS
## Emitted when the upper flap dropped down.
signal flipped
## Emitted when the target flap is reached.
signal finished
#endregion

#region ENUMS
enum SequencePresets {
	## The [member flap_sequence] of the [b]SplitFlap[/b] will be equal to
	## [constant NUMERIC_SEQUENCE].
	NUMERIC    = 0,
	## The [member flap_sequence] of the [b]SplitFlap[/b] will be equal to
	## [constant ALPHABETIC_SEQUENCE].
	ALPHABETIC = 1,
	## The [member flap_sequence] of the [b]SplitFlap[/b] will be initially empty, but can be
	## edited.
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

## Preset used to initialize the [member flap_sequence] of the [b]SplitFlap[/b]. See
## [enum SequencePresets] for options.
## [br][br]
## [b]Note:[/b] Using a preset will [i]not[/i] stop the user from changing the
## [member flap_sequence] via code.
@export var preset := SequencePresets.NUMERIC:
	set(value):
		preset = value
		match preset:
			SequencePresets.NUMERIC:
				flap_sequence = NUMERIC_SEQUENCE
			SequencePresets.ALPHABETIC:
				flap_sequence = ALPHABETIC_SEQUENCE
			SequencePresets.CUSTOM:
				flap_sequence = []

## Characters printed on the flaps of the [b]SplitFlap[/b]. Will only appear in the inspector if
## [member preset] is [constant CUSTOM].
@export var flap_sequence : Array[String]:
	set(value):
		for element in value:
			if element.length() > 1:
				return # reject changes to any strings with more than one character
		flap_sequence = value
		notify_property_list_changed() # triggers [method _validate_property]
		if is_inside_tree():
			for flap in get_children():
				_apply_text(flap)

## Position of the currently shown flap inside the [member flap_sequence] of the [b]SplitFlap[/b].
## [br][br]
## Set this to [code]-1[/code] to show an empty flap.
@export_range(-1, 10, 1) var current_flap_id := -1:
	set(value):
		current_flap_id = value
		if is_inside_tree():
			for flap in get_children():
				_apply_text(flap)
#endregion

#region EXPORT VARIABLES: APPEARANCE
@export_group("Appearance")

## Font used for the characters on the [b]SplitFlap[/b]'s flaps.
@export var font : Font:
	set(value):
		font = value
		update_minimum_size()
		if is_inside_tree():
			for flap in get_children():
				_apply_font_settings.call_deferred(flap)

## Font size of the characters on the [b]SplitFlap[/b]'s flaps.
## [br][br]
## [b]Note:[/b] This directly affects the [b]SplitFlap[/b]'s minimum size!
@export_range(8, 128, 1, "or_greater", "suffix:pixels") var font_size := 64:
	set(value):
		font_size = value
		update_minimum_size()
		if is_inside_tree():
			for flap in get_children():
				_apply_font_settings.call_deferred(flap)

## The [StyleBox] for the upper flaps of this [b]SplitFlap[/b]. If [member lower_flap] is not set,
## this will also be used as the style box for the lower flaps.
@export var upper_flap : StyleBox:
	set(value):
		upper_flap = value
		if is_inside_tree():
			for flap in get_children():
				_apply_stylebox(flap)

## The [StyleBox] for the lower flaps of this [b]SplitFlap[/b]. If [member upper_flap] is not set,
## this will also be used as the style box for the upper flaps.
@export var lower_flap : StyleBox:
	set(value):
		lower_flap = value
		if is_inside_tree():
			for flap in get_children():
				_apply_stylebox(flap)

## The vertical separation between the upper and lower flaps of the [b]SplitFlap[/b] in pixels.
@export_range(0, 6, 2, "or_greater", "suffix:pixels") var flap_separation := 2:
	set(value):
		flap_separation = value
		update_minimum_size()
		if is_inside_tree():
			for flap in get_children():
				_apply_separation(flap)
#endregion

#region EXPORT VARIABLES: ANIMATION
@export_group("Animation")

## The time it takes for a flap of the [b]SplitFlap[/b] to drop down/change characters in seconds.
@export_range(0.0, 1.0, 0.1, "or_greater", "suffix:seconds") var flip_time := 0.3

## If [code]true[/code], the moving flap will modulate the flap underneath in
## [constant Color.DARK_GRAY].
@export var drop_shadow := true
#endregion

func _validate_property(property : Dictionary) -> void:
	if property.name == "flap_sequence":
		if preset != SequencePresets.CUSTOM:
			# hide "flap_sequence" property in the inspector
			property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			# show "flap_sequence" property in the inspector
			property.usage = PROPERTY_USAGE_DEFAULT
	elif property.name == "current_flap_id":
		# adjust the allowed range for "current_flap_id" in the inspector
		property.hint_string = "-1, %s, 1" % (flap_sequence.size() - 1)
#endregion

#region INTERNAL VARIABLES
# Used as the minimum width/height of the SplitFlap, computed in [method _get_minimum_size].
var _font_height := 0

# Tween used for the animation of the moving flap in [method flip_forward].
var _flip_tween : Tween
#endregion


func _get_minimum_size() -> Vector2:
	if font:
		_font_height = int(font.get_height(font_size))
	else:
		_font_height = int(get_theme_default_font().get_height(font_size))

	# round to an even number (so it can be divided into two equal integer sized halves)
	if _font_height % 2 == 1:
		_font_height += 1

	return Vector2(_font_height, _font_height + flap_separation)


func _enter_tree() -> void:
	if preset != SequencePresets.CUSTOM:
		preset = preset # manually trigger setter

	_create_flap("UpperFlap")
	_create_flap("LowerFlap")
	_create_flap("MovingFlap")


func _create_flap(flap_name : String) -> void:
	var flap = Panel.new()
	flap.name = flap_name
	flap.clip_contents = true
	add_child(flap)

	var label = Label.new()
	label.name = "Label"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flap.add_child(label)

	_apply_text(flap)
	_apply_stylebox(flap)
	_apply_font_settings(flap)


func _apply_text(flap : Panel) -> void:
	if current_flap_id == -1 or current_flap_id > flap_sequence.size() - 1:
		flap.get_node("Label").text = ""
	else:
		flap.get_node("Label").text = flap_sequence[current_flap_id]


func _apply_stylebox(flap : Panel) -> void:
	if upper_flap and lower_flap:
		if flap.name == "LowerFlap":
			flap.add_theme_stylebox_override("panel", lower_flap)
		else:
			flap.add_theme_stylebox_override("panel", upper_flap)
	elif upper_flap and not lower_flap:
		flap.add_theme_stylebox_override("panel", upper_flap)
	elif lower_flap and not upper_flap:
		flap.add_theme_stylebox_override("panel", lower_flap)
	else:
		flap.add_theme_stylebox_override("panel", StyleBoxFlat.new())


func _apply_separation(flap : Panel) -> void:
	if flap.name == "LowerFlap":
		flap.position.y = 0.5 * _font_height + flap_separation
	if flap.name == "MovingFlap":
		flap.pivot_offset.y = 0.5 * (_font_height + flap_separation)


func _apply_font_settings(flap : Panel) -> void:
	flap.size = Vector2(_font_height, 0.5 * _font_height)
	flap.pivot_offset.y = 0.5 * _font_height

	_apply_separation(flap)

	var label = flap.get_node("Label")
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)

	if flap.name == "LowerFlap":
		label.position.y = -0.5 * _font_height
	label.size.x = flap.size.x


## Flip to the next flap in the [b]SplitFlap[/b]'s [member flap_sequence].
## [br][br]
## Emits [signal flipped] when the next flap has been reached.
func flip_forward():
	if _flip_tween and _flip_tween.is_running():
		return

	var next_char_id = wrapi(current_flap_id + 1, 0, flap_sequence.size())
	$UpperFlap/Label.text = flap_sequence[next_char_id]
	if drop_shadow:
		$UpperFlap.modulate = Color.DARK_GRAY

	_flip_tween = create_tween()
	_flip_tween.tween_property($MovingFlap, "scale:y", 0.0, 0.5 * flip_time)
	if drop_shadow:
		_flip_tween.parallel().tween_property($UpperFlap, "modulate", Color.WHITE, 0.5 * flip_time)

	_flip_tween.tween_callback(func():
		$MovingFlap.position.y = 0.5 * _font_height + flap_separation
		$MovingFlap.pivot_offset.y = -0.5 * flap_separation
		$MovingFlap/Label.text = flap_sequence[next_char_id]
		$MovingFlap/Label.position.y = -0.5 * _font_height
		if lower_flap:
			$MovingFlap.add_theme_stylebox_override("panel", lower_flap)

		var random_color := Color(randf(), randf(), randf())
	)

	_flip_tween.tween_property($MovingFlap, "scale:y", 1.0, 0.5 * flip_time)
	if drop_shadow:
		_flip_tween.parallel().tween_property(
			$LowerFlap, "modulate", Color.DARK_GRAY, 0.5 * flip_time
		)

	await _flip_tween.finished

	if drop_shadow:
		$LowerFlap.modulate = Color.WHITE
	$LowerFlap/Label.text = flap_sequence[current_flap_id]
	$MovingFlap.position.y = 0
	$MovingFlap.pivot_offset.y = 0.5 * (_font_height + flap_separation)
	$MovingFlap/Label.position.y = 0
	if upper_flap:
		$MovingFlap.add_theme_stylebox_override("panel", upper_flap)

	current_flap_id = wrapi(current_flap_id + 1, 0, flap_sequence.size())
	flipped.emit()


## Flip through the flaps in the [b]SplitFlap[/b]'s [member flap_sequence] until [param target_flap]
## is reached.
## [br][br]
## Emits [signal flipped] when [param target_flap] has been reached.
func flip_to(target_flap : String):
	if not target_flap in flap_sequence and not target_flap.to_upper() in flap_sequence:
		push_error("Cannot flip to '%s': There is no flap with that label" % target_flap)
		return

	var current_flap := flap_sequence[current_flap_id]

	if current_flap == target_flap or current_flap == target_flap.to_upper():
		return

	while current_flap != target_flap and current_flap != target_flap.to_upper():
		await flip_forward()
		current_flap = flap_sequence[current_flap_id]

	finished.emit()
