extends Node

signal opponent_finished(node)
signal opponent_set_timeout(node, value, autostart)
signal opponent_start_timer()
signal opponent_set_rank(node, rank, count, lap, laps)
signal race_reset()
signal race_started()
signal race_ended()

@onready var raceStatus = RaceState.WAITING
@onready var sfxPlayer = AudioStreamPlayer.new()
@onready var sfxReady = preload("res://assets/sounds/ready.ogg")
@onready var sfxGo = preload("res://assets/sounds/go.ogg")

var difficulty: int = 1:
	set(new_value):
		difficulty = new_value
var laps: int = 3:
	set(new_value):
		laps = new_value
var raceMode: int = RaceMode.TIMEATTACK:
	set(new_value):
		raceMode = new_value
var do_debug_finish: bool = false:
	set(new_value):
		do_debug_finish = new_value
var raceStartTime
var raceCurrentTime

var opponents = []
var checkpoints = []
var levelPath
var pathLength

enum RaceMode { CLASSIC, TIMEATTACK }
enum RaceState { WAITING, STARTED, ENDED }
enum OpponentState { WAITING, WARMUP, RACING, FAILED, FINISHED }

func add_opponent(node: Node3D): #(id : int):
	var nextcp = 1
	if do_debug_finish:
		nextcp = 0
	opponents.push_back({ "node": node, "id": node.player_id, "lap": 1,
						  "state": OpponentState.WAITING, "nextcp": nextcp, "laptimes": [] })
	node.failed.connect(on_opponent_failed)

func add_checkpoint(path: Path3D, node : Node3D):
	levelPath = path
	pathLength = path.curve.get_baked_length()
	var idx = checkpoints.size()
	var offset = find_closest_curve_offset(path, node.global_position)
	# Compute some basic timeout delay based on offset difference with previous CP
	var timeout = 0.0
	if idx > 0: # FIXME: 1st CP / startline special case...
		timeout = (offset - checkpoints[idx - 1]["offset"])  / (2.0 + difficulty)
		# Set 1st CP / startline timeout as if the current CP is the last one
		# FIXME: don't require that 1st CP / startline has the smallest offset
		checkpoints[0]["timeout"] = \
			(pathLength - offset + checkpoints[0]["offset"]) / (2.0 + difficulty)
	checkpoints.push_back({ "node": node, "idx": idx, "offset": offset, "timeout": timeout })
	checkpoints.sort_custom(func(a, b): return a["offset"] < b["offset"])
	if idx == 0:
		node.passed.connect(on_startline_passed)
	else:
		node.passed.connect(on_checkpoint_passed)

func _ready():
	if do_debug_finish:
		laps = 1
	sfxPlayer.bus = &"SFX"
	add_child(sfxPlayer)

func _process(_delta):
	if raceStatus == RaceState.ENDED:
		return
	if raceStatus == RaceState.STARTED:
		raceCurrentTime = Time.get_ticks_usec() - raceStartTime
	# TODO: send race time
	# Compute rankings
	var rankList = []
	for opp in opponents:
		var offset = find_closest_curve_offset(levelPath, opp["node"].global_transform.origin)
		var rank = opp["lap"] * pathLength + offset
		rankList.push_back({ "node": opp["node"], "rank": rank, "lap": opp["lap"] })
	rankList.sort_custom(func(a, b): return a["rank"] > b["rank"])
	# FIXME? Emit signal only once, with all opponents informations ?
	for i in rankList.size():
		emit_signal("opponent_set_rank", rankList[i].node, i + 1, rankList.size(), rankList[i].lap, laps)

func on_checkpoint_passed(cpnode: Node3D, id: int):
	if opponents[id].state != OpponentState.RACING:
		return
	for cp in checkpoints:
		if cp["node"] == cpnode and opponents[id].nextcp == cp["idx"]:
			print("RaceManager: player %d passed %s" % [id, cpnode.name])
			if cp["idx"] + 1 >= checkpoints.size():
				opponents[id].nextcp = 0
			else:
				opponents[id].nextcp += 1
			var nexttimeout = checkpoints[opponents[id].nextcp].timeout
			if raceMode == RaceMode.TIMEATTACK:
				emit_signal("opponent_set_timeout", opponents[id].node, nexttimeout, true)
			print("RaceManager: Player %s : nextcp = %s, timeout %s" % [id, opponents[id].nextcp, nexttimeout])

func on_startline_passed(cpnode: Node3D, id: int):
	if opponents[id].state != OpponentState.RACING:
		return
	if opponents[id].nextcp == 0:
		# A lap was completed, save lap time
		var laptimes = opponents[id]["laptimes"]
		if laptimes.size() > 0:
			# This was not the first lap, so substract previous lap times
			var previous_lap_times = 0.0
			for lt in laptimes:
				previous_lap_times += lt
			opponents[id].laptimes.push_back(raceCurrentTime - previous_lap_times)
		else:
			# First lap time is equal to race time
			opponents[id].laptimes.push_back(raceCurrentTime)
		
		if opponents[id].lap + 1 > laps:
			# All laps were completed
			opponents[id]["racetime"] = raceCurrentTime
			opponents[id].state = OpponentState.FINISHED
			emit_signal("opponent_finished", opponents[id].node, raceCurrentTime, opponents[id]["laptimes"])
			# Check if race has ended (all opponents finished or failed)
			for opp in opponents:
				print("RaceManager: startline: opp %s state = %s" % [opp.node, opp.state])
				match opp.state:
					OpponentState.RACING:
						return
			raceStatus = RaceState.ENDED
			print("RaceManager: race ended with %s (id = %s) crossing startline" % [opponents[id].node, id])
			emit_signal("race_ended")
			return
		opponents[id].lap += 1
		on_checkpoint_passed(cpnode, id)
		print("RaceManager: startline passed, lap %s" % [opponents[id].lap])

func race_warmup():
	print("RaceManager: race_warmup !")
	for opp in opponents:
		opp.state = OpponentState.WARMUP
		print("RaceManager: WARMUP %s" % opp.node)
		if raceMode == RaceMode.TIMEATTACK:
			emit_signal("opponent_set_timeout", opp.node, checkpoints[1].timeout, false)
	await get_tree().create_timer(1.0).timeout
	race_ready()

func race_ready():
	sfxPlayer.stream = sfxReady
	sfxPlayer.play()
	# FIXME? Set a timer since 321 sound file exceeds 4 seconds
	await get_tree().create_timer(4.0).timeout
	sfxPlayer.stop()
	race_start()

func race_start():
	print("RaceManager: calling race_start")
	raceStatus = RaceState.STARTED
	raceStartTime = Time.get_ticks_usec()
	for opp in opponents:
		opp.state = OpponentState.RACING
	sfxPlayer.stream = sfxGo
	sfxPlayer.play()
	emit_signal("race_started")
	if raceMode == RaceMode.TIMEATTACK:
		emit_signal("opponent_start_timer")

func on_opponent_failed(node: Node3D, id: int, reason: String):
	print("RaceManager: %s (id = %s) failed because %s !" % [node, id, reason])
	opponents[id].state = OpponentState.FAILED
	for opp in opponents:
		match opp.state:
			OpponentState.RACING:
				return
	# All opponents have either finished or failed, signal end of race
	print("RaceManager: race ended because %s failed (%s) !" % [node, reason])
	raceStatus = RaceState.ENDED
	emit_signal("race_ended")

func reset_race():
	print("RaceManager: *** reset race ***")
	raceStatus = RaceState.WAITING
	for opp in opponents:
		opp.state = OpponentState.WAITING
		opp.lap = 1
		opp.nextcp = 1
		opp.laptimes = []
	emit_signal("race_reset")
	await get_tree().create_timer(1.0).timeout
	race_warmup()

### Based on
### https://medium.com/@oddlyshapeddog/finding-the-nearest-global-position-on-a-curve-in-godot-4-726d0c23defb
func find_closest_curve_offset(lpath: Path3D, global_pos: Vector3):
	var lcurve: Curve3D = lpath.curve
	# transform the target position to local space
	var path_transform: Transform3D = lpath.global_transform
	var local_pos: Vector3 = global_pos * path_transform
	# get the nearest offset on the curve
	var offset: float = lcurve.get_closest_offset(local_pos)
	return offset
