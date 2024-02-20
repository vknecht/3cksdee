extends MarginContainer

@onready var shipList = Globals.scan("res://scenes/ships/scenes", "tscn")
@onready var shipKeys = shipList.keys()
var gridElements = []
var players_ready = []

func _ready():
	for player in Globals.players:
		var label = Label.new()
		gridElements.push_back(label)
		PlayerManager.set_player_data(player.id, "ship", shipKeys[0])
		label.text = PlayerManager.get_player_data(player.id, "ship")
		label.add_theme_font_size_override("font_size", 32)
		var sb = StyleBoxFlat.new()
		sb.bg_color = Globals.playerColors[player.id]
		label.add_theme_stylebox_override("normal", sb)
		%GridPlayers.add_child(label)

func _process(_delta):
	if players_ready.size() == Globals.players.size():
		%Back.disabled = false
		%Done.disabled = false
		%Done.grab_focus()
	for i in Globals.players.size():
		var current = PlayerManager.get_player_data(i, "ship")
		if MultiplayerInput.is_action_just_pressed(Globals.players[i].device, "left"):
			if players_ready.has(i):
				continue
			var selected = Globals.array_get_prev(shipKeys, current)
			gridElements[i].text = selected
			PlayerManager.set_player_data(i, "ship", selected)
		if MultiplayerInput.is_action_just_pressed(Globals.players[i].device, "right"):
			if players_ready.has(i):
				continue
			var selected = Globals.array_get_next(shipKeys, current)
			gridElements[i].text = selected
			PlayerManager.set_player_data(i, "ship", selected)
		if MultiplayerInput.is_action_just_pressed(Globals.players[i].device, "start"):
			if players_ready.has(i):
				continue
			players_ready.push_back(i)
			gridElements[i].add_theme_color_override("font_color", Color(Color.BLACK))

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/menus/game_setup.tscn")

func _on_done_pressed():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().change_scene_to_file("res://scenes/game_screen.tscn")

