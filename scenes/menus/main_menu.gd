extends MarginContainer

### Main menu design after Godot doc
### https://docs.godotengine.org/en/3.0/getting_started/step_by_step/ui_main_menu.html
### Options menu from @16BitDev after https://youtu.be/QnEG01t2P9M
### User preferences settings from @Game Dev Artisan after https://youtu.be/GPzdFzNq060
@onready var fps = %FPS
@onready var fullscreen = %Fullscreen
@onready var separation = %Separation
@onready var vibration = %Vibration
@onready var vibration_force = %VibrationForce
@onready var music = %PlayMusic
@onready var volume_master = %MasterVolume
@onready var volume_music = %MusicVolume
@onready var volume_sfx = %SFXVolume
@onready var debug_finish = %DebugFinish
@onready var version = %Version
@onready var godotver = %GodotVersion

var user_prefs: UserPreferences

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE) 
	user_prefs = UserPreferences.load_or_create()
	if fps:
		fps.button_pressed = user_prefs.fps
	if fullscreen:
		fullscreen.button_pressed = user_prefs.fullscreen
	if separation:
		separation.value = user_prefs.separation
	if vibration:
		vibration.button_pressed = user_prefs.vibrate
	if vibration_force:
		vibration_force.value = user_prefs.vibrate_force
	if music:
		music.button_pressed = user_prefs.music
	if volume_master:
		volume_master.value = user_prefs.volume_master
	if volume_music:
		volume_music.value = user_prefs.volume_music
	if volume_sfx:
		volume_sfx.value = user_prefs.volume_sfx
	if debug_finish:
		debug_finish.button_pressed = user_prefs.debug_finish
	version.text = ProjectSettings.get_setting("application/config/version")
	godotver.text =  "Godot " + Engine.get_version_info().string
	%OptionsMenu.visible = false
	%CreditsMenu.visible = false
	%MultiLocal.grab_focus()

func _process(_delta):
	if Input.is_action_just_pressed("exit"):
		get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
		get_tree().quit()

func _on_multi_local_pressed():
	get_tree().change_scene_to_file("res://scenes/menus/game_setup.tscn")

func _on_options_pressed():
	%Buttons.visible = false
	%OptionsMenu.visible = true
	%DoneOptions.grab_focus()

func _on_credits_pressed():
	%Buttons.visible = false
	%CreditsMenu.visible = true
	%DoneCredits.grab_focus()

func _on_exit_pressed():
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	get_tree().quit()

func _on_done_credits_pressed():
	%CreditsMenu.visible = false
	%Buttons.visible = true
	%Credits.grab_focus()

############# Options menu #############

func _on_done_pressed():
	%Buttons.visible = true
	%OptionsMenu.visible = false
	%Options.grab_focus()

func _on_fps_toggled(toggled_on):
	if toggled_on:
		Globals.do_fps = true
	else:
		Globals.do_fps = false
	if user_prefs:
		user_prefs.fps = toggled_on
		user_prefs.save()

func _on_fullscreen_toggled(toggled_on):
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if user_prefs:
		user_prefs.fullscreen = toggled_on
		user_prefs.save()

func _on_separation_value_changed(value):
	Globals.separation = value
	if user_prefs:
		user_prefs.separation = value
		user_prefs.save()

func _on_vibration_toggled(toggled_on):
	Globals.do_vibrate = toggled_on
	if user_prefs:
		user_prefs.vibrate = toggled_on
		user_prefs.save()

func _on_vibration_force_value_changed(value):
	Globals.vibrate_force = value
	if user_prefs:
		user_prefs.vibrate_force = value
		user_prefs.save()

func _on_play_music_toggled(toggled_on):
	Globals.do_music = toggled_on
	if toggled_on:
		MusicController.play("res://assets/music/menu/warmup2.ogg")
	else:
		MusicController.stop()
	if user_prefs:
		user_prefs.music = toggled_on
		user_prefs.save()

func _on_master_volume_value_changed(value):
	adjust_volume("Master", value)
	if user_prefs:
		user_prefs.volume_master = value
		user_prefs.save()

func _on_music_volume_value_changed(value):
	adjust_volume("Music", value)
	if user_prefs:
		user_prefs.volume_music = value
		user_prefs.save()

func _on_sfx_volume_value_changed(value):
	adjust_volume("SFX", value)
	if user_prefs:
		user_prefs.volume_sfx = value
		user_prefs.save()

func _on_debug_finish_toggled(toggled_on):
	Globals.do_debug_finish = toggled_on
	if user_prefs:
		user_prefs.debug_finish = toggled_on
		user_prefs.save()

# Convert a linear scale value to decibels for the audio bus volume.
func adjust_volume(bus_name: String, linear_value: float):
	var db_value = linear2db(linear_value)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus_name), db_value)

# Convert linear volume to decibels. 0 is silent, 100 is full volume.
func linear2db(linear_value: float) -> float:
	if linear_value == 0:
		return -80.0 # Minimum volume level in decibels.
	else:
		var t = linear_value / 100.0
		return 20.0 * log(t) / log(10.0) # Convert linear value to decibels.
