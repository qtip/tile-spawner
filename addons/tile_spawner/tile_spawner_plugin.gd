tool
extends EditorPlugin

const TileSpawnerControls = preload("res://addons/tile_spawner/tile_spawner_controls.tscn")

enum Align {
	NONE,
	ROUND,
	FLOOR,
	CEIL,
	TRUNCATE
}

const UUID_TILE_SPAWNER_CONTROLS = "be2d8857-0633-431f-bc92-302da269bccd"
const UUID_TILE_SPAWNER = "ddfc5ec5-af82-4234-8aca-24678ee59958"

func _enter_tree():
	# Listen to selection changes so we can show custom buttons
	var selection = get_editor_interface().get_selection().connect("selection_changed", self, "selection_changed")

	# Register TileSpawner node
	add_custom_type("TileSpawner", "Node2D", load("res://addons/tile_spawner/tile_spawner.gd"), load("res://addons/tile_spawner/tile_spawner_icon.png"))

	# Register TileSpawnerMapping resource
	# add_custom_type("TileSpawnerMapping", "Resource", preload("res://addons/tile_spawner/tile_spawner_mapping.gd"), preload("res://addons/tile_spawner/tile_spawner_mapping_icon.png"))

func _exit_tree():
	# Clean up any UI changes
	remove_tile_spawner_controls()

	# Unregister TileSpawnerMapping resource
	#remove_custom_type("TileSpawnerMapping")

	# Unregister TileSpawner
	remove_custom_type("TileSpawner")

	# Stop listening for selection changes
	get_editor_interface().get_selection().disconnect("selection_changed", self, "selection_changed")

func selection_changed():
	# When the current selection changes, check to see what's now selected
	var selected_nodes = get_editor_interface().get_selection().get_selected_nodes()

	# Only show the controls when one node is selected.
	# Note: Perhaps this check isn't necessary
	if selected_nodes == null or selected_nodes.size() != 1:
		remove_tile_spawner_controls()
		return

	var related_tile_spawners = filter_related_tile_spawners(selected_nodes)
	if related_tile_spawners.size() > 0:
		add_tile_spawner_controls()
	else:
		remove_tile_spawner_controls()

# Given a tile_map, find the tile_spawners that are targeting it.
func get_source_tile_spawners(tile_map):
	var tile_spawners = []
	for tile_spawner in get_tree().get_nodes_in_group(UUID_TILE_SPAWNER):
		if tile_spawner.get_source_tilemap() == tile_map:
			tile_spawners.push_back(tile_spawner)
	return tile_spawners

# Given a list of nodes, return all related tile_spawners, either directly or
# indirectly from the list
func filter_related_tile_spawners(nodes):
	var tile_spawners = []
	for node in nodes:

		# Add a node if it is a tile spawner
		if node.is_in_group(UUID_TILE_SPAWNER):
			tile_spawners.push_back(node)
			continue

		# Add any tile_spawners targeting this node.
		var source_tile_spawners = get_source_tile_spawners(node)
		tile_spawners = array_extend(tile_spawners, source_tile_spawners)

	return tile_spawners

static func array_extend(array1, array2):
	for item in array2:
		array1.push_back(item)
	return array1

func undo_spawn(tile_spawner, old_children):
	free_children(tile_spawner)
	var scene_root = get_tree().get_edited_scene_root()
	for child in old_children:
		tile_spawner.add_child(child)
		child.set_owner(scene_root)


func bake_button_pressed():
	# Get all nodes selected
	var selected_nodes = get_editor_interface().get_selection().get_selected_nodes()

	# Only bake when one node is selected.
	# Note: Perhaps this check isn't necessary
	if selected_nodes == null or selected_nodes.size() != 1:
		print("Error: Trying to bake with multiple nodes selected")
		return

	var related_tile_spawners = filter_related_tile_spawners(selected_nodes)
	if related_tile_spawners.size() <= 0:
		print("Error: Trying to bake without a TileSpawner or TileMap selected")
		return

	var undo_redo = get_undo_redo()
	undo_redo.create_action("Bake Tile Spawner")

	# Do the tilemap spawning
	for tile_spawner in related_tile_spawners:
		undo_redo.add_undo_method(self, "undo_spawn", tile_spawner, tile_spawner.get_children())
		undo_redo.add_do_method(self, "spawn_from_tilemap", get_tree(), tile_spawner)
		spawn_from_tilemap(get_tree(), tile_spawner)
	
	undo_redo.commit_action()

func add_tile_spawner_controls():
	# If the tile spawner controls are already present, don't add them again
	if len(get_tree().get_nodes_in_group(UUID_TILE_SPAWNER_CONTROLS)) > 0:
		return

	# Add the controls to the editor
	var tile_spawner_controls = TileSpawnerControls.instance()
	tile_spawner_controls.add_to_group(UUID_TILE_SPAWNER_CONTROLS)
	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, tile_spawner_controls)

	# Listen for events from the controls so we can react to them
	tile_spawner_controls.get_node("bake_button").connect("pressed", self, "bake_button_pressed")

func remove_tile_spawner_controls():
	for tile_spawner_controls in get_tree().get_nodes_in_group(UUID_TILE_SPAWNER_CONTROLS):
		# Remove the controls from the editor
		remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, tile_spawner_controls)

		# Free the controls
		tile_spawner_controls.queue_free()

static func spawn_from_tilemap(tree, tile_spawner):
	# Validate & get tilemap node
	var source_tilemap = tile_spawner.get_source_tilemap()
	if source_tilemap == null or not source_tilemap is TileMap:
		# Ensure the node select for source tilemap is correct
		print("Error: Source tilemap must be a TileMap!")
		return

	# Validate & get target node
	var target_node = tile_spawner.get_target_node()
	if target_node == null or not target_node is CanvasItem:
		# Ensure the node select for source tilemap is correct
		print("Error: Target node must be a CanvasItem!")
		return

	# Validate & get the mapping
	var mapping_path = tile_spawner.mapping
	var mapping_file = File.new()
	if mapping_path == null or not mapping_file.file_exists(mapping_path):
		# Make sure the mapping file exists
		print("Error: Mapping file for TileSpawner does not exist!")
		return
	if mapping_file.open(tile_spawner.mapping, File.READ) != OK:
		# Make sure the mapping file opened
		print("Error: Could not open the mapping file for TileSpawner!")
		return
	var mapping_json = JSON.parse(mapping_file.get_as_text())
	mapping_file.close()
	if typeof(mapping_json.result) != TYPE_DICTIONARY:
		# Make sure the mapping file is formatted correctly
		print("Error: Mapping file for TileSpawner must be a JSON object!")
		return
	var mapping = mapping_json.result

	# Using the tilemap's cell_tile_origin, find an offset for each node
	var origin_offset = Vector2()
	if source_tilemap.cell_tile_origin == TileMap.TILE_ORIGIN_TOP_LEFT:
		origin_offset = source_tilemap.cell_size / 2
	elif source_tilemap.cell_tile_origin == TileMap.TILE_ORIGIN_CENTER:
		origin_offset = source_tilemap.cell_size
	elif source_tilemap.cell_tile_origin == TileMap.TILE_ORIGIN_BOTTOM_LEFT:
		origin_offset = Vector2(source_tilemap.cell_size.x / 2, source_tilemap.cell_size.y * 3 / 2)

	# Optionally, clear children in the target node
	if tile_spawner.clear_children_before_baking:
		unparent_children(target_node)

	# For each tile, spawn a child into the target node
	for cellv in source_tilemap.get_used_cells():
		# Figure out the tile name for this cell
		var tile_set = source_tilemap.tile_set
		var tile_index = source_tilemap.get_cellv(cellv)
		var tile_name = tile_set.tile_get_name(tile_index)

		# Ignore tiles with no mapping
		if not mapping.has(tile_name):
			continue

		# Get the mapping entry for this tile name
		var mapping_entry = mapping[tile_name]

		# Using the entry, find the scene path for this tile name
		var scene_path = mapping_entry['scene']

		# Add the child
		var child = spawn_child(tree.get_edited_scene_root(), target_node, scene_path)

		# Find the transform for the tile
		var orientation_transform = get_cell_orientation_transform(source_tilemap, cellv)
		var tile_transform = source_tilemap.global_transform * orientation_transform

		# Compute origin of the tile
		var origin = source_tilemap.global_transform.xform(source_tilemap.map_to_world(cellv) + origin_offset)
		# Snap origin to pixel grid
		origin = snap_to_pixel_grid(origin, tile_spawner.grid_alignment)
		tile_transform.origin = origin

		# Set the transform
		child.global_transform = tile_transform

# Given a vector and an alignment type, return a new, aligned version
# of that vector
static func snap_to_pixel_grid(vec, align):
	if align == Align.ROUND:
		return Vector2(round(vec.x), round(vec.y))
	elif align == Align.FLOOR:
		return Vector2(floor(vec.x), floor(vec.y))
	elif align == Align.CEIL:
		return Vector2(ceil(vec.x), ceil(vec.y))
	elif align == Align.TRUNCATE:
		return Vector2(int(vec.x), int(vec.y))
	else:
		return vec

# Given a TileMap and a cell coordinate, return a Transform that represents
# the given rotation/mirroring etc.
static func get_cell_orientation_transform(tile_map, cellv):
	var transform = Transform2D(Vector2(1, 0), Vector2(0, 1), Vector2(0, 0))
	if tile_map.is_cell_transposed(cellv.x, cellv.y):
		var x_axis = Vector2(transform.x.x, transform.x.y)
		transform.x = -Vector2(transform.y.x, transform.y.y)
		transform.y = -x_axis
	if tile_map.is_cell_x_flipped(cellv.x, cellv.y):
		transform.x = -transform.x
	if tile_map.is_cell_y_flipped(cellv.x, cellv.y):
		transform.y = -transform.y

	return transform

# Given a node, free all children of that node
static func free_children(parent_node):
	for child_node in parent_node.get_children():
		child_node.free()

# Given a node, detach but do not free all children of that node
static func unparent_children(parent_node):
	var nodes = []
	for child_node in parent_node.get_children():
		parent_node.remove_child(child_node)
		child_node.set_owner(null)
		nodes.push_back(child_node)
	return nodes

static func spawn_child(scene_root, parent, scene_path):
	var node
	node = load(scene_path).instance()
	node.filename = scene_path
	parent.add_child(node)
	node.position = Vector2(0,0)
	node.set_owner(scene_root)
	node.set_name(node.name)
	return node
