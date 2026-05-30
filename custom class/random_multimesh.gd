@tool
extends MultiMeshInstance3D

# Number of instances to generate
@export var count: int = 50:
	set(value):
		count = max(0, value)
		rebuild()

# Spawn area size (X,Z)
@export var area_size: Vector2 = Vector2(20.0, 20.0):
	set(value):
		area_size = value
		rebuild()

# Seed for deterministic random generation
@export var random_seed: int = 123:
	set(value):
		random_seed = value
		rebuild()

@export_group("Height")

# Height at left side of the area
@export var height_left: float = 0.0:
	set(value):
		height_left = value
		rebuild()

# Height at right side of the area
@export var height_right: float = 0.0:
	set(value):
		height_right = value
		rebuild()

# Height at front side of the area
@export var height_front: float = 0.0:
	set(value):
		height_front = value
		rebuild()

# Height at back side of the area
@export var height_back: float = 0.0:
	set(value):
		height_back = value
		rebuild()

# Blend heights smoothly between sides
@export var smooth_height_blend: bool = true:
	set(value):
		smooth_height_blend = value
		rebuild()

@export_group("Rotation (Degrees)")

# Randomize X rotation
@export var random_x: bool = false:
	set(value):
		random_x = value
		rebuild()

# Fixed X rotation
@export var rotation_x: float = 0.0:
	set(value):
		rotation_x = value
		rebuild()

# Randomize Y rotation
@export var random_y: bool = true:
	set(value):
		random_y = value
		rebuild()

# Fixed Y rotation
@export var rotation_y: float = 0.0:
	set(value):
		rotation_y = value
		rebuild()

# Randomize Z rotation
@export var random_z: bool = false:
	set(value):
		random_z = value
		rebuild()

# Fixed Z rotation
@export var rotation_z: float = 0.0:
	set(value):
		rotation_z = value
		rebuild()

@export_group("Collision")

# Generate collision objects
@export var generate_collision: bool = true:
	set(value):
		generate_collision = value
		rebuild()

# Shared collision shape
@export var collision_shape: Shape3D

# Collision layer
@export var collision_layer: int = 1

# Collision mask
@export var collision_mask: int = 1

# Parent node used to store generated collisions
@export var collision_parent_path: NodePath = NodePath(".")

# Use StaticBody3D instead of Area3D
@export var use_static_body: bool = true:
	set(value):
		use_static_body = value
		rebuild()

# Additional transform applied to collisions
@export var collision_offset: Transform3D = Transform3D.IDENTITY:
	set(value):
		collision_offset = value
		rebuild()

# Manual rebuild button
@export var rebuild_now: bool = false:
	set(value):
		if value:
			rebuild()
		rebuild_now = false

# Cached transforms used by instances and collisions
var instance_transforms: Array[Transform3D] = []

func _ready() -> void:
	if Engine.is_editor_hint():
		rebuild()

# Rebuild instances and collisions
func rebuild() -> void:
	update_multimesh()

	if generate_collision:
		update_collisions()
	else:
		clear_collisions()

# Calculate height based on position inside the area
func _calc_height(x: float, z: float) -> float:
	var half_x = max(area_size.x * 0.5, 0.0001)
	var half_z = max(area_size.y * 0.5, 0.0001)

	var nx = clamp(x / half_x, -1.0, 1.0)
	var nz = clamp(z / half_z, -1.0, 1.0)

	var w_right = max(nx, 0.0)
	var w_left = max(-nx, 0.0)
	var w_back = max(nz, 0.0)
	var w_front = max(-nz, 0.0)

	if smooth_height_blend:
		var sum_w = w_left + w_right + w_front + w_back

		if sum_w < 0.00001:
			return 0.0

		return (
			height_left * (w_left / sum_w) +
			height_right * (w_right / sum_w) +
			height_front * (w_front / sum_w) +
			height_back * (w_back / sum_w)
		)

	# Use nearest side height
	var best = w_left
	var h := height_left

	if w_right > best:
		best = w_right
		h = height_right

	if w_front > best:
		best = w_front
		h = height_front

	if w_back > best:
		best = w_back
		h = height_back

	return h

# Generate multimesh instances
func update_multimesh() -> void:
	if not multimesh:
		multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D

	multimesh.instance_count = count

	instance_transforms.clear()
	instance_transforms.resize(count)

	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed

	for i in range(count):
		var x := rng.randf_range(-area_size.x * 0.5, area_size.x * 0.5)
		var z := rng.randf_range(-area_size.y * 0.5, area_size.y * 0.5)
		var y := _calc_height(x, z)

		var pos := Vector3(x, y, z)

		var rx := deg_to_rad(
			rng.randf_range(0.0, 360.0) if random_x else rotation_x
		)

		var ry := deg_to_rad(
			rng.randf_range(0.0, 360.0) if random_y else rotation_y
		)

		var rz := deg_to_rad(
			rng.randf_range(0.0, 360.0) if random_z else rotation_z
		)

		var t := Transform3D()
		t.basis = Basis.from_euler(Vector3(rx, ry, rz))
		t.origin = pos

		instance_transforms[i] = t
		multimesh.set_instance_transform(i, t)

# Generate collision bodies for all instances
func update_collisions() -> void:
	if collision_shape == null:
		clear_collisions()
		return

	var parent := get_node_or_null(collision_parent_path)

	if parent == null:
		parent = self

	var container := parent.get_node_or_null("__mm_collisions__") as Node3D

	if container == null:
		container = Node3D.new()
		container.name = "__mm_collisions__"
		parent.add_child(container)

		if Engine.is_editor_hint():
			container.owner = get_tree().edited_scene_root

	# Remove old collisions
	for child in container.get_children():
		child.queue_free()

	var container_inv_global := container.global_transform.affine_inverse()
	var self_global := global_transform

	for i in range(instance_transforms.size()):
		var body: Node3D

		if use_static_body:
			var sb := StaticBody3D.new()
			sb.collision_layer = collision_layer
			sb.collision_mask = collision_mask
			body = sb
		else:
			var ar := Area3D.new()
			ar.collision_layer = collision_layer
			ar.collision_mask = collision_mask
			body = ar

		body.name = "MMCol_%d" % i

		var inst_global := self_global * instance_transforms[i]
		var col_global := inst_global * collision_offset

		body.transform = container_inv_global * col_global

		var cs := CollisionShape3D.new()
		cs.shape = collision_shape

		body.add_child(cs)
		container.add_child(body)

		if Engine.is_editor_hint():
			body.owner = get_tree().edited_scene_root
			cs.owner = get_tree().edited_scene_root

# Remove all generated collisions
func clear_collisions() -> void:
	var parent := get_node_or_null(collision_parent_path)

	if parent == null:
		parent = self

	var container := parent.get_node_or_null("__mm_collisions__")

	if container:
		for child in container.get_children():
			child.queue_free()
