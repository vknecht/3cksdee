extends Control

### https://www.woubuc.be/blog/post/background-music-player-godot/
@onready var _player = $AudioStreamPlayer
var playlist = []

func _ready():
	_player.bus = "Music"
	playlist = Globals.scan("res://assets/music", "ogg", {}, false)
	print(playlist)

func playany():
	randomize()
	var keys = playlist.keys()
	var song = playlist[keys[randi() % playlist.size()]]
	play(song.fullpath)

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
