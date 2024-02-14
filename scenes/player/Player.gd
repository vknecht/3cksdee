extends RigidBody3D


signal failed(node, reason)

var input
var player_id

@onready var hud = preload("res://scenes/player/hud.tscn").instantiate()
@onready var ray = $Ray
@onready var path = get_tree().get_nodes_in_group("Path")
@onready var timer = Timer.new()
@onready var sfxTimeout = preload("res://assets/sounds/114497__flash_shumway__piep.mp3")

enum RacingStatus { WAITING, RACING, FAILED, FINISHED }
@onready var status = RacingStatus.WAITING

var pffinished

var speed_max = 20000
var speed = speed_max
var turn_speed = 100
var height = 0.1

var turn
var accel

func set_id(id: int):
	player_id = id

func set_input(device: int):
	input = DeviceInput.new(device)

func _ready():
	add_to_group("Opponents")
	self.failed.connect(hud.failed)
	add_child(hud)
	timer.autostart = false
	timer.one_shot = true
	add_child(timer)
	timer.connect("timeout", _on_timer_timeout)

func _process(delta):
	match status:
		RacingStatus.FINISHED:
			pffinished.progress_ratio += 0.03 * delta
		RacingStatus.RACING:
			hud.update_timeout(timer.time_left)
			if timer.time_left < 10.0 and not $TimeoutSound.playing:
				$TimeoutSound.play(4.6)
	
	if input.is_action_just_pressed("start"):
		# TODO: implement pause menu
		pass
	if input.is_action_pressed("exit"):
		for p in PlayerManager.get_player_indexes():
			PlayerManager.leave(p)
		get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")

func _physics_process(delta):
	if input.is_action_just_pressed("reset"):
		print("player %d: just pressed reset action!!!" % player_id)
		global_transform = Globals.find_closest_curve_transform(path[0], global_transform.origin)
		global_transform.origin += global_basis.y * height
		linear_velocity = Vector3(0, 0, 0)
		angular_velocity = Vector3(0, 0, 0)
	
	accel = input.get_action_strength("accelerate") - input.get_action_strength("brake")
	turn = Vector2(input.get_action_strength("right") - input.get_action_strength("left"), 0)

	match status:
		RacingStatus.RACING:
			apply_central_force(-global_transform.basis.z * accel * speed * delta)
			apply_torque(-global_transform.basis.y * turn.sign().x * turn.length() * turn_speed * delta)
			#apply_torque(-global_transform.basis.z * turn.sign().x * turn.length() * turn_speed * speed * state.step / 30000)
			if input.is_action_just_pressed("turbo"): speed = speed_max * 1.5
			if input.is_action_just_released("turbo"): speed = speed_max
		_:
			return

func _integrate_forces(state):
	match status:
		RacingStatus.FAILED, RacingStatus.FINISHED:
			return
	
	var posupv = Globals.find_closest_abs_posrot(path[0], position)
	var vec = Vector2(posupv[1].x, posupv[1].y)
	var angle = vec.angle() - rotation.z
	
	### Align ship's Y with the curve's Y (maybe only when left/right are released ?)
	if turn.length() == 0 and angular_velocity.abs().z < 0.2:
	#if angular_velocity.abs().z < 0.2:
		var new_transform = Globals.align_with_y(global_transform, posupv[1])
		var a = Quaternion(global_transform.basis)
		var b = Quaternion(new_transform.basis)
		var c = a.slerp(b, 0.1)
		global_transform.basis = Basis(c)
	
	# Fake rotation around forward axis when turning
	if status == RacingStatus.RACING:
		clampf(rotation.z, angle - PI / 8, angle + PI / 8)
		rotation.z = lerp(rotation.z, -turn.sign().x * turn.length(), \
						  turn_speed * state.step / 125.0)
	
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
	linear_velocity = Vector3(0, 0, 0)
	angular_velocity = Vector3(0, 0, 0)

func _on_timer_timeout():
	status = RacingStatus.FAILED
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
	timer.start()
	status = RacingStatus.RACING

func on_opponent_finished(shipNode: Node3D, raceTime: int, lapTimes: Array):
	if shipNode.player_id == player_id:
		print("player %s finished: raceTime = %s usec, laps : %s" % [player_id, raceTime, lapTimes])
		timer.stop()
		$TimeoutSound.stop()
		# Show race and lap times
		status = RacingStatus.FINISHED
		hud.show_results()
		hud.update_racetime(raceTime)
		for i in lapTimes.size():
			hud.add_lap_time(lapTimes[i])
		# Align ship orientation along the path
		var t: Transform3D = Globals.find_closest_curve_transform(path[0], global_position)
		var tween = get_tree().create_tween()
		tween.tween_property(self, "global_basis", t.basis, 0.2)

func on_opponent_set_rank(shipNode: Node3D, rank: int, count: int, lap: int, laps: int):
	match status:
		RacingStatus.FAILED, RacingStatus.FINISHED:
			return
	if shipNode.player_id == player_id:
		hud.update_rank(rank, count)
		hud.update_laps(lap, laps)

func on_race_reset():
	# Reset race state on players side
	status = RacingStatus.WAITING
