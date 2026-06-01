# filename: prize_box.gd
extends RigidBody3D

# Enumeration defining our allowed structural archetypes
enum PrizeType { ROUND_CAPSULE, RECTANGULAR_BOX }

# Set the DEFAULT type to round capsule
@export var current_type: PrizeType = PrizeType.ROUND_CAPSULE

var is_collected: bool = false

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	
	# Automatically configure geometric parameters based on chosen state type at birth
	apply_prize_geometry()

func apply_prize_geometry() -> void:
	# Ensure component node pointers are verified before manipulation
	if not collision_shape or not mesh_instance:
		return
		
	match current_type:
		PrizeType.ROUND_CAPSULE:
			# 1. Generate visual Sphere Mesh geometry
			var sphere_mesh = SphereMesh.new()
			sphere_mesh.radius = 0.25  # Total diameter of 0.5 units
			sphere_mesh.height = 0.5
			mesh_instance.mesh = sphere_mesh
			
			# 2. Generate matching Sphere Shape physics boundaries
			var sphere_shape = SphereShape3D.new()
			sphere_shape.radius = 0.25
			collision_shape.shape = sphere_shape
			
		PrizeType.RECTANGULAR_BOX:
			# 1. Generate visual Box Mesh geometry
			var box_mesh = BoxMesh.new()
			box_mesh.size = Vector3(0.4, 0.4, 0.4)
			mesh_instance.mesh = box_mesh
			
			# 2. Generate matching Box Shape physics boundaries
			var box_shape = BoxShape3D.new()
			box_shape.size = Vector3(0.4, 0.4, 0.4)
			collision_shape.shape = box_shape
