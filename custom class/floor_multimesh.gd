@tool
extends MultiMeshInstance3D

# Size of the generated grid area
@export var area_size: Vector2 = Vector2(20.0, 20.0):
	set(value):
		area_size = value
		update_multimesh()

# Distance between instances on X and Z axes
@export var spacing: Vector2 = Vector2(2.0, 2.0):
	set(value):
		spacing.x = max(value.x, 0.01)
		spacing.y = max(value.y, 0.01)
		update_multimesh()

# Global offset applied to the grid
@export var start_offset: Vector3 = Vector3.ZERO:
	set(value):
		start_offset = value
		update_multimesh()

# Scale applied to each instance
@export var item_scale: Vector3 = Vector3.ONE:
	set(value):
		item_scale = value
		update_multimesh()

# Center the grid around the origin
@export var center_area: bool = true:
	set(value):
		center_area = value
		update_multimesh()

func _ready():
	update_multimesh()

# Generate a grid of multimesh instances
func update_multimesh():
	if not multimesh:
		multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D

	# Prevent invalid spacing
	if spacing.x <= 0.0 or spacing.y <= 0.0:
		multimesh.instance_count = 0
		return

	var count_x = int(floor(area_size.x / spacing.x)) + 1
	var count_z = int(floor(area_size.y / spacing.y)) + 1

	if count_x <= 0 or count_z <= 0:
		multimesh.instance_count = 0
		return

	var total_count = count_x * count_z
	multimesh.instance_count = total_count

	var origin_offset = Vector3.ZERO

	# Move grid so its center stays at the origin
	if center_area:
		origin_offset.x = -((count_x - 1) * spacing.x) * 0.5
		origin_offset.z = -((count_z - 1) * spacing.y) * 0.5

	var index = 0

	for z in range(count_z):
		for x in range(count_x):
			var transform = Transform3D()

			transform.origin = start_offset + origin_offset + Vector3(
				x * spacing.x,
				0.0,
				z * spacing.y
			)

			transform.basis = Basis().scaled(item_scale)

			multimesh.set_instance_transform(index, transform)
			index += 1
