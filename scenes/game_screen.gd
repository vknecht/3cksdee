extends Node

@onready var levelScene = load(Globals.level).instantiate()
@onready var checkpointScene = load("res://scenes/scenery/checkpoint.tscn")
@onready var rm = load("res://scripts/race_manager.gd")
var paths
var starts
var checkpoints
var raceManager

func _ready():
	add_child(levelScene)
	paths = get_tree().get_nodes_in_group("Path")
	starts = get_tree().get_nodes_in_group("Start")
	checkpoints = get_tree().get_nodes_in_group("Checkpoints")
	raceManager = rm.new()
	add_child(raceManager)
	
	# Set splitscreen grid separation pixels according to the Options setting
	$ShipsViewports.add_theme_constant_override("separation", Globals.separation)
	# Create the splitscreen subviewports for all players
	var subvp = setup_subviewports($ShipsViewports, Globals.players.size())
	
	# FIXME? Move start & checkpoints setup to raceManager ?
	# Set start nodes direction/orientation to be the same as closest Curve3D point
	for start in starts:
		var t = Globals.find_closest_curve_transform(paths[0], start.position)
		start.global_transform.basis = t.basis
		start.position = t.origin + Vector3(0, 0.1, 0)
		var cpScene = checkpointScene.instantiate()
		cpScene.global_transform = start.global_transform
		levelScene.add_child(cpScene)
		raceManager.add_checkpoint(paths[0], cpScene) #starts[0])
	
	for cp in checkpoints:
		cp.global_transform = Globals.find_closest_curve_transform(paths[0], cp.position)
		var cpScene = checkpointScene.instantiate()
		cpScene.global_transform = cp.global_transform
		levelScene.add_child(cpScene)
		raceManager.add_checkpoint(paths[0], cpScene)
	
	var shipStarts = Globals.find_curve_start_points(paths[0], starts[0].position, Globals.players.size(), 0.5)
	
	for player in Globals.players:
		# Load player ship, instantiate, assign input device and subviewport
		var shipName = PlayerManager.get_player_data(player.id, "ship")
		var shipScene = load("res://scenes/ships/%s.tscn" % [shipName]).instantiate()
		shipScene.set_id(player.id)
		shipScene.set_input(player.device)
		subvp[player.id].add_child(shipScene)
		# Place ship on start "grid"
		# FIXME: don't necessarily place ships depending on their player id
		shipScene.global_transform = shipStarts[player.id]
		shipScene.global_transform.origin += Vector3(0, 0.1, 0)
		raceManager.opponent_set_timeout.connect(shipScene.on_opponent_set_timeout)
		raceManager.opponent_start_timer.connect(shipScene.on_opponent_start_timer)
		raceManager.opponent_finished.connect(shipScene.on_opponent_finished)
		raceManager.opponent_set_rank.connect(shipScene.on_opponent_set_rank)
		raceManager.add_opponent(shipScene)
	
	MusicController.playany()

# Given a `parent` container (usually a VBoxContainer),
# create a child grid for `count` subviewports.
# If the last row would be incomplete (ie. less than columns number used) :
# - if more than one : use a HBoxContainer and put the remainder there
# - if only one : simply add it as a child of the parent so it's placed under the grid
func setup_subviewports(parent, count, separation = 0):
	var grid = GridContainer.new()
	# Compute columns and rows numbers
	grid.columns = floorf(sqrt(count))
	var remainder = count % grid.columns
	var rows
	if remainder > 0:
		rows = floor(count / grid.columns + 1)
	else:
		rows = count / grid.columns	
	# Grid layout settings
	grid.size = DisplayServer.screen_get_size()
	grid.anchors_preset = GridContainer.PRESET_FULL_RECT
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", separation)
	grid.add_theme_constant_override("v_separation", separation)
	parent.add_child(grid)
	
	var subviewports = []
	for i in count:
		var subvcont = SubViewportContainer.new()
		subvcont.stretch = true
		subvcont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		subvcont.size_flags_vertical = Control.SIZE_EXPAND_FILL
		subviewports.push_back(SubViewport.new())
		subviewports[i].render_target_update_mode = SubViewport.UPDATE_ALWAYS
		subvcont.add_child(subviewports[i])
		# Decide how to add remaining subviewports which don't fill a grid row
		if remainder > 0 and i >= count - remainder:
			if remainder > 1:
				if parent.get_node("LastLine"):
					# Continue adding to HBoxContainer if it already exists
					parent.get_node("LastLine").add_child(subvcont)
				else:
					# Create HBoxContainer as child of the parent
					var hbox = HBoxContainer.new()
					hbox.name = "LastLine"
					hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
					hbox.add_theme_constant_override("separation", separation)
					hbox.add_child(subvcont)
					parent.add_child(hbox)
			else:
				# If only one SubViewportContainer in last line, add it to parent
				parent.add_child(subvcont)
			# Adjust grid depending on the row count to make place for last line
			grid.size_flags_stretch_ratio = rows - 1
		else:
			# Normal case : add SubViewportContainer to the grid
			grid.add_child(subvcont)
	return subviewports