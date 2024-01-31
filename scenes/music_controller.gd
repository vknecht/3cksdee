extends Control

### https://www.woubuc.be/blog/post/background-music-player-godot/
@onready var _player = $AudioStreamPlayer
var playlist = []

func _ready():
	_player.bus = "Music"
	var dir = DirAccess.open("res://assets/music/")
	if dir:
		dir.include_hidden = false
		dir.include_navigational = false
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".ogg"):
				playlist.append(file_name)
			file_name = dir.get_next()

func playany():
	randomize()
	var song = playlist[randi() % playlist.size()]
	play("res://assets/music/" + song)

# Calling this function will load the given track, and play it
func play(track_url : String):
	if Globals.do_music:
		var track = load(track_url)
		if track == _player.stream:
			return
		_player.stream = track
		_player.play()

# Calling this function will stop the music
func stop():
	_player.stop()

func _on_audio_stream_player_finished():
	playany()
