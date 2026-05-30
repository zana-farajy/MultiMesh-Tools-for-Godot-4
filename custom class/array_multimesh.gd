@tool
extends MultiMeshInstance3D

# Number of instances per row
@export var count_per_row: int = 20:
	set(value):
		count_per_row = value
		update_multimesh()

# Alternate rows face the opposite direction
@export var mirror_rows: bool = false:
	set(value):
		mirror_rows = value
		update_multimesh()

# Apply random Y rotation to existing instances
@export var randomize_rotation: bool = false:
	set(value):
		if value:
			apply_random_rotation()
		randomize_rotation = value

# Apply random height offset to existing instances
@export var randomize_height: bool = false:
	set(value):
		if value:
			apply_random_height()
		randomize_height = value

# Apply random scale to existing instances
@export var randomize_scale: bool = false:
	set(value):
		if value:
			apply_random_scale()
		randomize_scale = value

# Random height offset range
@export var height_range: Vector2 = Vector2(-0.5, 0.5):
	set(value):
		height_range = value
		update_multimesh()

# Number of rows
@export var row_count: int = 2:
	set(value):
		row_count = value
		update_multimesh()

# Spacing between instances in a row
@export var forward_spacing: Vector3 = Vector3(2.0, 0.0, 0.0):
	set(value):
		forward_spacing = value
		update_multimesh()

# Direction used to offset rows
@export var side_direction: Vector3 = Vector3(0.0, 0.0, 1.0):
	set(value):
		side_direction = value.normalized()
		update_multimesh()

# Distance between rows
@export var side_spacing: float = 10.0:
	set(value):
		side_spacing = value
		update_multimesh()

# Base scale applied to all instances
@export var object_scale: Vector3 = Vector3(1.0, 1.0, 1.0):
	set(value):
		object_scale = value
		update_multimesh()

# Minimum random scale
@export var min_random_scale: Vector3 = Vector3(0.8, 0.8, 0.8):
	set(value):
		min_random_scale = value

# Maximum random scale
@export var max_random_scale: Vector3 = Vector3(1.2, 1.2, 1.2):
	set(value):
		max_random_scale = value

# Apply random Y offset
func apply_random_height():
	var multimesh_res = self.multimesh

	if not multimesh_res:
		return

	var rng = RandomNumberGenerator.new()

	for i in range(multimesh_res.instance_count):
		var xform = multimesh_res.get_instance_transform(i)

		xform.origin.y += rng.randf_range(
			height_range.x,
			height_range.y
		)

		multimesh_res.set_instance_transform(i, xform)

# Apply small random Y rotation
func apply_random_rotation():
	var multimesh_res = self.multimesh

	if not multimesh_res:
		return

	var rng = RandomNumberGenerator.new()

	for i in range(multimesh_res.instance_count):
		var xform = multimesh_res.get_instance_transform(i)

		var rand_y = deg_to_rad(
			rng.randf_range(-5.0, 5.0)
		)

		var rotation = xform.basis.get_euler()
		rotation.y += rand_y

		var current_scale = xform.basis.get_scale()

		xform.basis = Basis.from_euler(rotation).scaled(current_scale)

		multimesh_res.set_instance_transform(i, xform)

# Apply random scale variation
func apply_random_scale():
	var multimesh_res = self.multimesh

	if not multimesh_res:
		return

	var rng = RandomNumberGenerator.new()

	for i in range(multimesh_res.instance_count):
		var xform = multimesh_res.get_instance_transform(i)

		var random_scale = Vector3(
			rng.randf_range(min_random_scale.x, max_random_scale.x),
			rng.randf_range(min_random_scale.y, max_random_scale.y),
			rng.randf_range(min_random_scale.z, max_random_scale.z)
		)

		var rotation = xform.basis.get_rotation_quaternion()

		xform.basis = Basis(rotation).scaled(random_scale)

		multimesh_res.set_instance_transform(i, xform)

# Generate row-based multimesh layout
func update_multimesh():
	if not multimesh:
		multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D

	multimesh.instance_count = count_per_row * row_count

	var instance_idx = 0

	for r in range(row_count):
		for i in range(count_per_row):
			var transform = Transform3D()

			transform.origin = (
				forward_spacing * i
			) + (
				side_direction * (r * side_spacing)
			)

			transform.basis = transform.basis.scaled(object_scale)

			# Flip every second row
			if mirror_rows and (r % 2 != 0):
				var current_scale = transform.basis.get_scale()

				var rot_180 = Basis(Vector3.UP, PI)
				var rot_180_fro = Basis(Vector3.FORWARD, PI)

				transform.basis = transform.basis * rot_180
				transform.basis = transform.basis * rot_180_fro

				transform.basis = (
					transform.basis
					.orthonormalized()
					.scaled(current_scale)
				)

			multimesh.set_instance_transform(
				instance_idx,
				transform
			)

			instance_idx += 1
