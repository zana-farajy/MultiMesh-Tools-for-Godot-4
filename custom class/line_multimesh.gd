@tool
extends MultiMeshInstance3D

# Distance between generated instances
@export var spacing: float = 2.0:
	set(v):
		spacing = max(v, 0.001)
		_update_multimesh()

# Base rotation applied to all instances
@export var fixed_rotation_degrees: Vector3 = Vector3(0, -90, 0):
	set(v):
		fixed_rotation_degrees = v
		_update_multimesh()

# Axis used for random rotation
enum Axis {NONE = -1, X, Y, Z}

@export var random_axis: Axis = Axis.NONE:
	set(v):
		random_axis = v
		_update_multimesh()

# Random rotation range (± degrees)
@export var random_range_degrees: float = 0.0:
	set(v):
		random_range_degrees = max(v, 0.0)
		_update_multimesh()

# Scale applied to all instances
@export var instance_scale: Vector3 = Vector3.ONE:
	set(v):
		instance_scale = v
		_update_multimesh()

# Cached editor state signature
var _last_signature := ""

func _ready():
	# Generate once at startup
	_update_multimesh()

	# Markers are static at runtime
	set_process(false)

func _process(_delta):
	if Engine.is_editor_hint():
		var sig = _get_signature()

		if sig != _last_signature:
			_last_signature = sig
			_update_multimesh()

# Build a signature to detect editor changes
func _get_signature() -> String:
	var s := str(spacing)
	s += str(fixed_rotation_degrees)
	s += str(instance_scale)
	s += str(random_axis)
	s += str(random_range_degrees)

	for child in get_children():
		if child is Marker3D:
			s += str(child.global_transform)

	return s

# Generate instances between markers
func _update_multimesh():
	if not multimesh:
		multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D

	var markers: Array[Marker3D] = []

	for child in get_children():
		if child is Marker3D:
			markers.append(child)

	if markers.size() < 2:
		multimesh.instance_count = 0
		return

	var randomize = random_axis != Axis.NONE and random_range_degrees > 0.001

	var total_count := 0
	var segment_data: Array = []

	# Collect segment information
	for i in range(markers.size() - 1):
		var p1: Vector3 = to_local(markers[i].global_position)
		var p2: Vector3 = to_local(markers[i + 1].global_position)

		var seg_vec: Vector3 = p2 - p1
		var dist: float = seg_vec.length()

		if dist <= 0.0001:
			continue

		var count: int = int(dist / spacing) + 1

		segment_data.append({
			"p1": p1,
			"dir": seg_vec.normalized(),
			"dist": dist,
			"count": count
		})

		total_count += count

	multimesh.instance_count = total_count

	var current_idx := 0

	# Base rotation in radians
	var base_rot_rad := Vector3(
		deg_to_rad(fixed_rotation_degrees.x),
		deg_to_rad(fixed_rotation_degrees.y),
		deg_to_rad(fixed_rotation_degrees.z)
	)

	var fixed_basis := Basis.from_euler(base_rot_rad)
	fixed_basis = fixed_basis.scaled(instance_scale)

	# Stable random seed
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(fixed_rotation_degrees) + hash(instance_scale)

	for seg in segment_data:
		var p1: Vector3 = seg.p1
		var dir: Vector3 = seg.dir
		var dist: float = seg.dist
		var count: int = seg.count

		for j in range(count):
			var d = min(spacing * j, dist)
			var pos = p1 + dir * d

			var rot_rad = base_rot_rad

			if randomize:
				var rand_val = rng.randf_range(
					-random_range_degrees,
					random_range_degrees
				)

				match random_axis:
					Axis.X:
						rot_rad.x += deg_to_rad(rand_val)

					Axis.Y:
						rot_rad.y += deg_to_rad(rand_val)

					Axis.Z:
						rot_rad.z += deg_to_rad(rand_val)

			var basis = Basis.from_euler(rot_rad)
			basis = basis.scaled(instance_scale)

			var xform = Transform3D(basis, pos)

			multimesh.set_instance_transform(current_idx, xform)
			current_idx += 1
