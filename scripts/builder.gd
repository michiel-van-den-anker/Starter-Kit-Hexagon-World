extends Node3D

@export var hexagons: Array[Hexagon] = []

var map:DataMap

var index:int = 0 # Index of hexagon being placed

@export var selector:Node3D # The 'cursor'
@export var selector_container:Node3D # Node that holds a preview of the hexagon
@export var hexagons_container:Node3D # Node that holds the placed hexagons
@export var view_camera:Camera3D # Used for raycasting mouse
@export var gridmap:GridMap
var HexGrid = preload("res://scripts/godot-gdhexgrid/HexGrid.gd").new() # TODO - fix so it can export
@export var cash_display:Label
@export var debug_text:Label

var plane:Plane # Used for raycasting mouse
var mesh_library:MeshLibrary
var selector_rotation = 90

func _ready():
	
	map = DataMap.new()
	plane = Plane(Vector3.UP, Vector3.ZERO)
	
	# Create new MeshLibrary dynamically, can also be done in the editor
	mesh_library = MeshLibrary.new()
	
	for hexagon in hexagons:
		
		var id = mesh_library.get_last_unused_item_id()
		
		mesh_library.create_item(id)
		mesh_library.set_item_mesh(id, get_mesh(hexagon.model))
		mesh_library.set_item_mesh_transform(id, Transform3D())
	
	update_hexagon()
	update_cash()

func _process(delta):
	
	# Controls
	
	action_rotate() # Rotates selection 60 degrees
	action_structure_toggle() # Toggles between structures
	
	action_save() # Saving
	action_load() # Loading
	
	# Map position based on mouse
	var world_position = plane.intersects_ray(
		view_camera.project_ray_origin(get_viewport().get_mouse_position()),
		view_camera.project_ray_normal(get_viewport().get_mouse_position()))

	world_position = Vector2(world_position.x, world_position.z)
	
	var plane_pos = HexGrid.get_hex_center3(HexGrid.get_hex_at(world_position))
	selector.position.x = plane_pos.x
	selector.position.z = plane_pos.z

	action_build(plane_pos)
	action_demolish(plane_pos)

# Retrieve the mesh from a PackedScene, used for dynamically creating a MeshLibrary

func get_mesh(packed_scene):
	var scene_state:SceneState = packed_scene.get_state()
	for i in range(scene_state.get_node_count()):
		if(scene_state.get_node_type(i) == "MeshInstance3D"):
			for j in scene_state.get_node_property_count(i):
				var prop_name = scene_state.get_node_property_name(i, j)
				if prop_name == "mesh":
					var prop_value = scene_state.get_node_property_value(i, j)
					
					return prop_value.duplicate()

# Build (place) a structure

func action_build(hexgrid_position):
	if Input.is_action_just_pressed("build"):
		
		var str_pos = get_node_string(hexgrid_position)
		
		var previous_hexagon = null

		# Check in the hexagons_container if there is a node with the name str_pos
		# If there is, remove it
		if hexagons_container.has_node(str_pos):
			previous_hexagon = hexagons_container.get_node(str_pos)
			hexagons_container.remove_child(previous_hexagon)
			previous_hexagon.queue_free()
			
		create_hexagon(hexgrid_position)
		
		if previous_hexagon && previous_hexagon.get_meta("index") != index || !previous_hexagon:
			map.cash -= hexagons[index].price
			update_cash()

func get_node_string(hexgrid_position):
	# Cast the hexgrid_position to a string
	var str_pos = str(HexGrid.get_hex_at(hexgrid_position).get_cube_coords())

	# Clean up the string
	str_pos = str_pos.replace("(", "")
	str_pos = str_pos.replace(")", "")
	str_pos = str_pos.replace(" ", "")
	str_pos = str_pos.replace(",", "_")
	str_pos = str_pos.replace(".", "dot")
	
	print(str_pos)
	
	return str_pos

func create_hexagon(hexgrid_position):
	var str_pos = get_node_string(hexgrid_position)
	
	# If there isn't, create a new node with the name str_pos
	var _model = hexagons[index].model.instantiate()
	hexagons_container.add_child(_model)
	_model.position = Vector3(hexgrid_position.x, 0, hexgrid_position.z)
	_model.rotation_degrees = Vector3(0, selector_rotation, 0)
	_model.scale = Vector3(1, 1, 1)
	_model.set_name(str_pos)
	_model.set("mesh", get_mesh(hexagons[index].model))
	_model.set_meta("index", index)

# Demolish (remove) a structure

func action_demolish(hexgrid_position):
	if Input.is_action_just_pressed("demolish"):
		gridmap.set_cell_item(hexgrid_position, -1)

# Rotates the 'cursor' 60 degrees

func action_rotate():
	if Input.is_action_just_pressed("rotate"):
		selector.get_node("Container").rotate_y(deg_to_rad(60))
		selector_rotation = (selector_rotation + 60) % 360

# Toggle between structures to build

func action_structure_toggle():
	if Input.is_action_just_pressed("structure_next"):
		index = wrap(index + 1, 0, hexagons.size())
	
	if Input.is_action_just_pressed("structure_previous"):
		index = wrap(index - 1, 0, hexagons.size())

	update_hexagon()

# Update the structure visual in the 'cursor'

func update_hexagon():
	# Clear previous structure preview in selector
	for n in selector_container.get_children():
		selector_container.remove_child(n)
		
	# Create new structure preview in selector
	var _model = hexagons[index].model.instantiate()
	selector_container.add_child(_model)
	_model.position.y += 0.25
	
	debug_text.text = "Hexagon: " + str(index) + " " + _model.name
	
func update_cash():
	cash_display.text = "$" + str(map.cash)

# Saving/load

func action_save():
	if Input.is_action_just_pressed("save"):
		print("Saving map...")
		
		# Get all the nodes in the hexagons_container
		# Save the position, rotation and model of each node
		var hexagons = hexagons_container.get_children()

		map.structures.clear()
		for hex in  hexagons_container.get_children():
			
			var data_structure:DataStructure = DataStructure.new()
			
			data_structure.position = Vector3(hex.position.x, 0, hex.position.z)
			data_structure.orientation = hex.rotation_degrees.y
			data_structure.structure = hex.get_meta("index")
			
			map.structures.append(data_structure)
			
		ResourceSaver.save(map, "user://map.res")
	
func action_load():
	if Input.is_action_just_pressed("load"):
		print("Loading map...")
		
		# Remove all hexagons from the hexagons_container
		for hex in hexagons_container.get_children():
			hexagons_container.remove_child(hex)
			hex.queue_free()
		
		map = ResourceLoader.load("user://map.res")
		if not map:
			map = DataMap.new()
		for hex in map.structures:
			index = hex.structure
			selector_rotation = hex.orientation
			create_hexagon(hex.position)
			
		update_cash()
