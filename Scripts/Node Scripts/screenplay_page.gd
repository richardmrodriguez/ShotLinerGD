extends Control

@export_multiline var raw_screenplay_content: String = "INT. HOUSE - DAY"
@export var SP_ACTION_WIDTH: int = 61
@export var SP_DIALOGUE_WIDTH: int = 36
@export var SP_FONT_SIZE: int = 20
@export var font_ratio: float = 0.725

@onready var SP_CHARACTER_SPACING: float = SP_FONT_SIZE * font_ratio * 10
@onready var SP_PARENTHETICAL_SPACING: float = SP_FONT_SIZE * font_ratio * 5
@onready var page_panel: Panel = %ScreenplayPagePanel
@onready var page_container: Node = %ScreenplayPageContentVBox

const uuid_util = preload ("res://addons/uuid/uuid.gd")

var current_page_number: int = 0
var shotlines_for_pages: Dictionary = {}

signal created_new_shotline(shotline_struct: Shotline)
signal shotline_clicked
signal last_hovered_line_idx(last_ine_idx: int)
signal page_lines_populated

# TODO
# - This logic needs to be abstracted into another file;
# - This needs another piece to break up an FNLineGD array into
# Pages, which are arrays with a maximum size and also
# special logic to ensure CHARACTER headings are not orphaned
# at the bottom of a page

## - DRAWING LOGIC - need to get the following:
## 1. mouse click down - which row of the page does the mouse click into?
## 2. mouse click up - which row of the page does the mouse release its click?
## using those two data points, we can create a ShotLine which concretely correlates
## to a start and end position on a page, then draw it accordingly

## EMPHASIS is not handled here -- asterisks need to be removed from the fountain screenplay.

# Called when the node enters the scene tree for the first time.

func _ready() -> void:
	page_panel.shotline_clicked.connect(_on_shotline_clicked)

func replace_current_page(page_content: PageContent, new_page_number: int=0) -> void:
	for child in page_container.get_children():
		page_container.remove_child(child)
	for shotline: Node in page_panel.get_children():
		if shotline is ShotLine2D:
			page_panel.remove_child(shotline)
			shotline.queue_free()
			#print("lmao", shotline)
	#await get_tree().process_frame
	# ^^^ There appear to be rendering issues when navigating back and forth
	# between pages. Even though there are other parts of relevant functions
	# which already have an await get_tree().process_frame line,
	# it appears to be not quite enough sometimes. It appears random.
	populate_container_with_page_lines(page_content, new_page_number)

func populate_container_with_page_lines(cur_page_content: PageContent, page_number: int=0) -> void:
	current_page_number = page_number
	var line_counter: int = 0
	for fnline: FNLineGD in cur_page_content.lines:

		var screenplay_line: Label = construct_screenplay_line(fnline, line_counter)
		page_container.add_child(screenplay_line)

		# adds a toggleable highlight to text lines
		var line_bg := ColorRect.new()
		screenplay_line.add_child(line_bg)
		line_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line_bg.color = Color(1, .8, 1, 0.125)
		line_bg.set_size(line_bg.get_parent_area_size())
		line_bg.set_size(Vector2(500, line_bg.get_rect().size.y))
		line_bg.set_position(screenplay_line.position)

		screenplay_line.z_index = 0
		line_bg.z_index = 1
		line_bg.visible = false
		line_counter += 1

	page_lines_populated.emit()

func construct_screenplay_line(fnline: FNLineGD, idx: int) -> Label:

	var screenplay_line := Label.new()
	screenplay_line.set_script(preload ("res://Scripts/Node Scripts/LabelWithVars.gd"))
	screenplay_line.fnline = fnline
	screenplay_line.line_index = idx
	screenplay_line.autowrap_mode = TextServer.AUTOWRAP_OFF
	screenplay_line.add_theme_font_size_override("font_size", SP_FONT_SIZE)

	match fnline.fn_type:
		"Heading":
			screenplay_line.add_theme_font_override("font",
				load("res://Fonts/Courier Prime Bold.ttf"))
			screenplay_line.text = fnline.string
			#print("Heading: ", fnline.string)
		"Character":
			screenplay_line.text = " ".repeat(20) + fnline.string
		"Parenthetical":
			screenplay_line.text = " ".repeat(15) + fnline.string
		"TransitionLine":
			
			screenplay_line.text = " ".repeat(50) + fnline.string
		_:
			if fnline.fn_type.begins_with("Dialog"):
				screenplay_line.text = " ".repeat(10) + fnline.string
			else:
				screenplay_line.text = fnline.string
	
	return screenplay_line

# -------- FOUNTAIN / STRING MANIPULATION --------

func split_string_by_newline(string: String) -> PackedStringArray:
	var split := string.split("\n", true, ) as PackedStringArray
	return split

func get_parsed_lines(screenplay_as_str: String) -> Array:
	var pre_paginated_string := pre_paginate_lines_from_raw_string(screenplay_as_str)
	var parsed_lines := FountainParser.get_parsed_lines_from_raw_string(pre_paginated_string)

	var fnline_arr := construct_fnline_arr(parsed_lines)

	for ln: FNLineGD in fnline_arr:
		if ln.is_type_forced == "true":
			ln.string = ln.string.erase(0)

	return fnline_arr

func pre_paginate_lines_from_raw_string(screenplay_str: String) -> String:
	var preparsed_lines := FountainParser.get_parsed_lines_from_raw_string(screenplay_str)
	var pre_fnline_arr: Array[FNLineGD] = construct_fnline_arr(preparsed_lines)
	var paginated_lines: Array[String] = get_paginated_lines_from_fnline_arr(pre_fnline_arr)
	var paginated_multiline_str: String = ""
	for pgln: String in paginated_lines:
		paginated_multiline_str += pgln + "\n"
	return paginated_multiline_str

func construct_fnline_arr(lines_dict: Dictionary) -> Array[FNLineGD]:
	var linekeys := lines_dict.keys()
	var fnline_arr: Array[FNLineGD] = []
	linekeys.sort()
	for key: int in linekeys:

		var fnline_struct := FNLineGD.new()
		fnline_struct.pos = key
		fnline_struct.string = lines_dict[key][0]
		fnline_struct.fn_type = lines_dict[key][1]
		fnline_struct.is_type_forced = lines_dict[key][2]
		fnline_arr.append(fnline_struct)
	return fnline_arr

func get_paginated_lines_from_fnline_arr(fnline_arr: Array) -> Array[String]:
	var new_arr: Array[String] = []
	var forced_type_offset: int = 0

	for ln: FNLineGD in fnline_arr:
		if ln.is_type_forced == "true":
			forced_type_offset = 1
		else:
			forced_type_offset = 0
		var s := ln.string
		var sub_arr := []
		if not ln.fn_type.begins_with("Dialog"):
			sub_arr = recursive_line_splitter(s, SP_ACTION_WIDTH + forced_type_offset)
		else:
			sub_arr = recursive_line_splitter(s, SP_DIALOGUE_WIDTH + forced_type_offset)
		for sub_s: String in sub_arr:
			new_arr.append(sub_s)
	return new_arr

func recursive_line_splitter(line: String, max_length: int) -> Array:
	var final_arr: Array = []
	if line.length() <= max_length:
			final_arr.append(line)
	else:
		var words := line.split(" ")
		var cur_substring := ""
		var next_substring := ""
		var cur_line_full: bool = false
		for word: String in words:
			if word.length() + cur_substring.length() <= max_length and not cur_line_full:
					cur_substring += word + " "
			else:
				cur_line_full = true
				next_substring += word + " "

		final_arr.append(cur_substring)
		var new_arr := recursive_line_splitter(next_substring, max_length)
		for nl: String in new_arr:
			final_arr.append(nl)
		 
	return final_arr

# ------------ SIGNAL HANDLING ---------

func _on_screenplay_page_content_v_box_screenplay_line_hovered_over(last_line_idx: int) -> void:
	last_hovered_line_idx.emit(last_line_idx)

func _on_shotline_clicked(shotline_node: ShotLine2D, button_index: int) -> void:
	shotline_clicked.emit(shotline_node, button_index)
