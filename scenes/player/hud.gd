extends CanvasLayer


### BUG: Unique names aren't valid anymore after reparenting
### https://github.com/godotengine/godot/pull/81506
### supposedly fixed in 4.3dev3 but doesn't seem to be the case here...
### regression ? https://github.com/godotengine/godot/issues/88146

@onready var laptimes: VBoxContainer = $MarginContainer/RaceResults/LapTimes
@onready var racetime: Label = $MarginContainer/RaceResults/RaceTime
@onready var lapnumber: Label = $MarginContainer/LapsInfos/LapNumber
@onready var results: VBoxContainer = $MarginContainer/RaceResults
@onready var rank: Label = $MarginContainer/PosInfos/Rank
@onready var timeout: Label = $MarginContainer/Timeout

func _ready():
	show_results(false)

func failed(_node: Node3D, _id: int, _reason: String):
	timeout.visible = false

func update_rank(value: int, total: int):
	rank.text = "%d / %d" % [value, total]

func update_laps(value: int, total: int):
	lapnumber.text = "%d / %d" % [value, total]

func update_lap_time(_value: int):
	pass

func add_lap_time(value: int):
	var i = laptimes.get_child_count()
	var lt = Label.new()
	lt.add_theme_font_size_override("font_size", 24)
	lt.text = "Lap %s: %s" % [i + 1, Globals.usec_to_str(value)]
	laptimes.add_child(lt)

func update_timeout(value: float):
	if not timeout.visible:
		timeout.visible = true
	timeout.text = Globals.usec_to_str(int(value * 1000 * 1000))
	if value < 5.0:
		timeout.add_theme_color_override("font_color", Color(Color.RED))
	elif value < 10.0:
		timeout.add_theme_color_override("font_color", Color(Color.ORANGE))
	else:
		timeout.add_theme_color_override("font_color", Color(Color.WHITE))

func update_speed(_value: float):
	pass

func update_energy(_value: float):
	pass

func update_racetime(value: int):
	racetime.text = Globals.usec_to_str(value)

func on_race_reset():
	show_results(false)
	for child in laptimes.find_children("*", "", true, false):
		laptimes.remove_child(child)
		child.queue_free()
	if timeout:
		timeout.text = ""
		timeout.visible = true

func show_results(do_show: bool = true):
	results.visible = do_show
	timeout.visible = false
