extends Node

var players = []
var level
var lap_count: int

var do_fps
var separation = 0
var do_vibrate = true
var vibrate_force = 100
var do_music = true
var do_debug_finish

# FIXME: don't hardcode all possible colors...
var playerColors = [Color(Color.RED), Color(Color.BLUE), Color(Color.GREEN),
					Color(Color.YELLOW), Color(Color.ORANGE), Color(Color.PURPLE),
					Color(Color.DARK_RED), Color(Color.DARK_BLUE), Color(Color.DARK_GREEN),
					Color(Color.DARK_GOLDENROD), Color(Color.DARK_MAGENTA), Color(Color.AQUA)]

func scan(directory, extension, dict = {}, recurse = true):
	var dir = DirAccess.open(directory)
	if dir:
		print("Scanning %s for %s files..." % [directory, extension])
		dir.include_hidden = false
		dir.include_navigational = false
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			print(" found %s" % file_name)
			# Exporting add .remap to scene filenames and .import to ogg filenames
			file_name = file_name.trim_suffix(".remap")
			file_name = file_name.trim_suffix(".import")
			if dir.current_is_dir() and recurse:
				dict = scan(dir.get_current_dir() + "/" + file_name, extension, dict)
			elif extension and file_name.ends_with(extension):
				var fname = file_name.get_basename()
				dict[fname] = {
					"directory": directory,
					"filename": file_name,
					"fullpath": directory + "/" + file_name,
				}
				print("  found %s" % dict[fname]["fullpath"])
			file_name = dir.get_next()
	return dict

func array_get_prev(myarray, element, loop=false):
	var idx = myarray.find(element)
	if idx - 1 < 0:
		if loop:
			return myarray[myarray.size() - 1]
		else:
			return myarray[0]
	return myarray[idx - 1]

func array_get_next(myarray, element, loop=false):
	var idx = myarray.find(element)
	if idx + 1 >= myarray.size():
		if loop:
			return myarray[0]
		else:
			return myarray[idx]
	return myarray[idx + 1]

### https://kidscancode.org/godot_recipes/4.x/3d/3d_align_surface/index.html
func align_with_y(xform, new_y):
	xform.basis.y = new_y
	xform.basis.x = -xform.basis.z.cross(new_y)
	xform.basis = xform.basis.orthonormalized()
	return xform

### https://medium.com/@oddlyshapeddog/finding-the-nearest-global-position-on-a-curve-in-godot-4-726d0c23defb
### Add curve point upvector
### also need to check https://forum.godotengine.org/t/how-would-i-get-the-closest-point-on-a-curve3d-in-world-space/16453
func find_closest_abs_posrot(lpath: Path3D, global_pos: Vector3):
	var lcurve: Curve3D = lpath.curve
	# transform the target position to local space
	var path_transform: Transform3D = lpath.global_transform
	var local_pos: Vector3 = global_pos * path_transform
	# get the nearest offset on the curve
	var offset: float = lcurve.get_closest_offset(local_pos)
	# get the local position at this offset
	var curve_pos: Vector3 = lcurve.sample_baked(offset, true)
	# transform it back to world space
	curve_pos = path_transform * curve_pos
	# get curve orientation
	var upvector: Vector3 = lcurve.sample_baked_up_vector(offset, true)
	
	var t: Transform3D = lcurve.sample_baked_with_rotation(offset, true, true)
	var forward: Vector3 = Vector3(t.basis[0][2], t.basis[1][2], t.basis[2][2])
	# Might need next curve point pos/upvector in the future...
	#var offset_next: float = curve.get_closest_offset()
	#var curve_next_pos: Vector3 = lcurve.sample_baked(offset + lcurve.bake_interval, true) * path_transform
	#var curve_next_upv: Vector3 =  lcurve.sample_baked_up_vector(offset + lcurve.bake_interval, true)
	#var array: PackedVector3Array = [curve_pos, curve_upvector, curve_next_pos, curve_next_upv]
	var array: PackedVector3Array = [curve_pos, upvector, forward]
	return array

func find_closest_curve_transform(lpath: Path3D, global_pos: Vector3):
	var lcurve: Curve3D = lpath.curve
	var offset: float = find_closest_curve_offset(lpath, global_pos)
	# return the Transform3D at this offset
	return lcurve.sample_baked_with_rotation(offset, true, true)

func find_curve_start_points(lpath: Path3D, global_pos: Vector3, count: int, distance: float):
	var lcurve: Curve3D = lpath.curve
	var offset: float = find_closest_curve_offset(lpath, global_pos)
	var points: Array = []
	for i in count:
		var point: Transform3D = lcurve.sample_baked_with_rotation(offset - distance - distance * i, true, true)
		# If there's only one ship, let it in the middle
		if count != 1:
			# Otherwise, displace it on the left or right
			if i % 2 == 0:
				point.origin -= point.basis.x / 2
			else:
				point.origin += point.basis.x / 2
		points.push_back(point)
	return points

func find_closest_curve_offset(lpath: Path3D, global_pos: Vector3):
	var lcurve: Curve3D = lpath.curve
	# transform the target position to local space
	var path_transform: Transform3D = lpath.global_transform
	var local_pos: Vector3 = global_pos * path_transform
	# get the nearest offset on the curve
	var offset: float = lcurve.get_closest_offset(local_pos)
	return offset

func set_children_scene_root(node):
	for child in node.get_children():
		set_children_scene_root(child)
		child.set_owner(get_tree().edited_scene_root)

func usec_to_str(value: int):
	var millisecs = floor(value / 1000)
	var secs = floor(millisecs / 1000)
	var minutes = floor(secs / 60)
	return "%02d:%02d.%03d" % [minutes, secs - minutes * 60, millisecs - secs * 1000]
