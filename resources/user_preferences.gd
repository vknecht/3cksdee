class_name UserPreferences extends Resource

@export var fullscreen: bool = false
@export_range(0, 20, 1) var separation: int = 0
@export var vibrate: bool = true
@export_range(1, 100, 1) var vibrate_force: int = 100
@export var music: bool = true
@export_range(0, 100, 1) var volume_master: int = 100
@export_range(0, 100, 1) var volume_music: int = 100
@export_range(0, 100, 1) var volume_sfx: int = 100

func save() -> void:
	ResourceSaver.save(self, "user://user_prefs.tres")

static func load_or_create() -> UserPreferences:
	var res: UserPreferences = load("user://user_prefs.tres") as UserPreferences
	if !res:
		res = UserPreferences.new()
	return res
