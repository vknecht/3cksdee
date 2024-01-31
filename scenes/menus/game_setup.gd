extends MarginContainer

### Multiplayer Input from https://github.com/matjlars/godot-multiplayer-input

@onready var levelList = Globals.scan("res://scenes/levels", "tscn")
@onready var playerList = %PlayerList
@onready var waitForPlayers = true

func _ready():
	var levelKeys = levelList.keys()
	Globals.level = levelList[levelKeys[0]].fullpath
	for key in levelKeys:
		var btn = Button.new()
		btn.text = key
		btn.add_theme_font_size_override("font_size", 32)
		btn.pressed.connect(level_selected.bind(levelList[key].fullpath))
		%LevelList.add_child(btn)
	Globals.players.clear()
	MultiplayerInput.set_ui_action_device(-2) # All devices can move in UI
	PlayerManager.player_joined.connect(spawn_player)
	#player_manager.player_left.connect(delete_player)
	%LapCount.text = str(int(%LapCountSlider.value))
	Globals.lap_count = int(%LapCountSlider.value)

func _process(_delta):
	if waitForPlayers:
		PlayerManager.handle_join_input()
	if PlayerManager.someone_wants_to_start():
		waitForPlayers = false
		%Wait.disabled = false
		%Ready.disabled = false
		%Ready.grab_focus()

func spawn_player(player: int):
	var playerLabel = Label.new()
	playerLabel.add_theme_font_size_override("font_size", 32)
	playerLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var device = PlayerManager.get_player_device(player)
	var joyname = Input.get_joy_name(device)
	if device == -1:
		joyname = "Keyboard"
	var color = Globals.playerColors[player]
	playerLabel.text = "Player %s (%s)" % [str(player), joyname]
	playerLabel.add_theme_color_override("font_color", color)
	playerList.add_child(playerLabel)
	var dict = { "id": player, "device": device }
	Globals.players.push_back(dict)

func level_selected(levelScene):
	print(levelScene + " selected !")
	Globals.level = levelScene

func _on_wait_pressed():
	waitForPlayers = true
	%Ready.disabled = true
	%Wait.disabled = true
	%Back.disabled = true
	%Done.disabled = true

func _on_ready_pressed():
	%Ready.disabled = true
	%Back.disabled = false
	%Done.disabled = false
	%Done.grab_focus()
	for i in PlayerManager.get_unjoined_devices():
		var devname = Input.get_joy_name(i)
		print("Unjoined device %s (%s)" % [i, devname])

func _on_done_pressed():
	get_tree().change_scene_to_file("res://scenes/menus/ship_select.tscn")

func _on_back_pressed():
	# Reset the list of joined players
	for p in PlayerManager.get_player_indexes():
		PlayerManager.leave(p)
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")

func _on_lap_count_slider_value_changed(value):
	%LapCount.text = str(int(value))
	Globals.lap_count = int(value)
