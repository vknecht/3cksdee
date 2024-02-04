extends RigidBody3D

signal warmup(node)
signal failed(node, reason)

var input
var player_id

@onready var hud = preload("res://scenes/player/hud.tscn").instantiate()
@onready var ray = $Ray
@onready var path = get_tree().get_nodes_in_group("Path")
@onready var pathfollow = get_tree().get_nodes_in_group("PathFollow")
@onready var timer = Timer.new()

@onready var sfxTimeout = preload("res://assets/sounds/114497__flash_shumway__piep.mp3")

var pffinished
var racestarted = false
var racefinished = false
var racefailed = false
var hudResults
var raceTimeLabel
var ltvbox
var speed_label
var rank_label
var timeout_label: Label
var lap_label

var speed = 10000 # 15000
var turn_speed = 50 # 25 # 50 #200
var height = 0.08

var turn
var accel

func set_id(id: int):
	player_id = id

func set_input(device: int):
	input = DeviceInput.new(device)

func _ready():
	add_to_group("Opponents")
	add_child(hud)
	rank_label = hud.find_child("Rank")
	timeout_label = hud.find_child("Timeout")
	lap_label = hud.find_child("LapNumber")
	hudResults = hud.find_child("RaceResults")
	hudResults.visible = false
	raceTimeLabel = hud.find_child("RaceTime")
	ltvbox = hud.find_child("LapTimes")
	timer.autostart = false
	timer.one_shot = true
	add_child(timer)
	timer.connect("timeout", _on_timer_timeout)

func _process(delta):
	if racefinished:
		pffinished.progress_ratio += 0.03 * delta
		timeout_label.text = ""
	elif racestarted:
		timeout_label.text = Globals.usec_to_str(timer.time_left * 1000 * 1000)
		if timer.time_left < 5.0:
			timeout_label.add_theme_color_override("font_color", Color(Color.RED))
		elif timer.time_left < 10.0:
			timeout_label.add_theme_color_override("font_color", Color(Color.ORANGE))
		else:
			timeout_label.add_theme_color_override("font_color", Color(Color.WHITE))
	if input.is_action_just_pressed("start"):
		# TODO: implement pause menu
		pass
	if input.is_action_pressed("exit"):
		for p in PlayerManager.get_player_indexes():
			PlayerManager.leave(p)
		get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")
	if racestarted and not racefailed and not racefinished and timer.time_left < 10.0 and not $TimeoutSound.playing:
		$TimeoutSound.play(4.6)

func _physics_process(_delta):
	if input.is_action_just_pressed("reset"):
		global_transform = Globals.find_closest_curve_transform(path[0], global_transform.origin)
		global_transform.origin += global_basis.y * height
		linear_velocity = Vector3(0, 0, 0)
		angular_velocity = Vector3(0, 0, 0)
	if input.is_action_just_pressed("turbo"):
			speed *= 3
	if input.is_action_just_released("turbo"):
			speed /= 3

func _integrate_forces(state):
	accel = input.get_action_strength("accelerate") - input.get_action_strength("brake")
	turn = Vector2(input.get_action_strength("right") - input.get_action_strength("left"), 0)
	
	if racefinished or racefailed: return
	if racestarted:
		apply_central_force(-global_transform.basis.z * accel * speed * state.step)
		apply_torque(-global_transform.basis.y * turn.sign().x * turn.length() * turn_speed * state.step)
		#apply_torque(-global_transform.basis.z * turn.sign().x * turn.length() * turn_speed * speed * state.step / 30000)
	
	var posupv = Globals.find_closest_abs_posrot(path[0], position)
	var vec = Vector2(posupv[1].x, posupv[1].y)
	var angle = vec.angle() - rotation.z
	# Clamp rotation around forward axis
	clampf(rotation.z, angle - PI / 8, angle + PI / 8)
	### Align ship's Y with the curve's Y (maybe only when left/right are released ?)
	###if turn.length() == 0 and angular_velocity.abs().z < 0.2:
	if angular_velocity.abs().z < 0.2:
		var new_transform = Globals.align_with_y(global_transform, posupv[1])
		var a = Quaternion(global_transform.basis)
		var b = Quaternion(new_transform.basis)
		var c = a.slerp(b, 0.25)
		global_transform.basis = Basis(c)
	
	### Keep the ship at given height above the track
	ray.force_raycast_update()
	if ray.is_colliding():
		var collision_point = ray.get_collision_point()
		var dist = collision_point.distance_to(ray.global_transform.origin)
		position.y += height - dist # + lerpf(-0.02, 0.02, 1)

func _on_body_entered(_body):
	$CollisionSound.play()
	if Globals.do_vibrate:
		input.start_vibration(0.2, 0.8, 0.1)
	#linear_velocity = Vector3(0, 0, 0)
	#angular_velocity = Vector3(0, 0, 0)

func _on_timer_timeout():
	racefailed = true
	timeout_label.visible = false
	emit_signal("failed", self, player_id, "timeout")

func on_opponent_set_timeout(shipNode: Node3D, value: float, autostart: bool):
	if shipNode.player_id == player_id:
		$TimeoutSound.stop()
		print("Player %s : on_opponent_set_timeout (%s sec)" % [player_id, value])
		timer.autostart = autostart
		timer.wait_time = value
		if autostart:
			timer.start()

func on_opponent_start_timer():
	print("Player %s : on_opponent_start_timer" % [player_id])
	timeout_label.add_theme_color_override("font_color", Color(Color.WHITE))
	timeout_label.visible = true
	timer.start()
	racestarted = true
	
func on_opponent_finished(shipNode: Node3D, raceTime: int, lapTimes: Array):
	if shipNode.player_id == player_id:
		print("player %s finished: raceTime = %s usec, laps : %s" % [player_id, raceTime, lapTimes])
		timer.stop()
		$TimeoutSound.stop()
		timeout_label.visible = false
		# Duplicate path and pathfollow then parent them to player' subviewport
		var pathdup = path[0].duplicate()
		pffinished = pathfollow[0].duplicate()
		pathdup.add_child(pffinished)
		var subv = shipNode.get_parent()
		subv.add_child(pathdup)
		# Compute current ship position as a progress value of the pathfollow
		pffinished.progress = Globals.find_closest_curve_offset(pathdup, shipNode.global_position)
		# Reparent the ship to the pathfollow
		self.reparent(pffinished) #, false)
		self.set_owner(get_tree().edited_scene_root)
		Globals.set_children_scene_root(self)
		# Show race and lap times
		racefinished = true
		hudResults.visible = true
		raceTimeLabel.add_theme_font_size_override("font_size", 24)
		raceTimeLabel.text = Globals.usec_to_str(raceTime)
		print("ltvbox: %s" % ltvbox)
		for i in lapTimes.size():
			var lt = Label.new()
			lt.add_theme_font_size_override("font_size", 24)
			lt.text = "Lap %s: %s" % [i + 1, Globals.usec_to_str(lapTimes[i])]
			ltvbox.add_child(lt)

func on_opponent_set_rank(shipNode: Node3D, rank: int, count: int, lap: int, laps: int):
	if shipNode.player_id == player_id:
		rank_label.text = "%s / %s" % [rank, count]
		lap_label.text = "%s / %s" % [lap, laps]

func on_race_reset():
	hudResults.visible = false
	# Remove previous' race lap times
	for child in ltvbox.find_children("*", "", true, false):
		ltvbox.remove_child(child)
		child.queue_free()
	# Reset race state on players side
	racefinished = false
	racestarted = false
	racefailed = false
