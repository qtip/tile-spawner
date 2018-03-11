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
	add_custom_type("TileSpawner", "Node2D", preload("res://addons/tile_spawner/tile_spawner.gd"), preload("res://addons/tile_spawner/tile_spawner_icon.png"))
	
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
	if len(selected_nodes) == 1 and selected_nodes[0].is_in_group(UUID_TILE_SPAWNER):
		add_tile_spawner_controls()
	else:
		remove_tile_spawner_controls()

func bake_button_pressed():
	# Get all nodes selected
	var selected_nodes = get_editor_interface().get_selection().get_selected_nodes()
	if len(selected_nodes) != 1 or not selected_nodes[0].is_in_group(UUID_TILE_SPAWNER):
		# Shouldn't happen, but if a TileSpawner is not selected, then abort
		print("Warning: Tried to bake TileSpawner, but TileSpawner not selected")
		return

	var tile_spawner = selected_nodes[0]
	
	# Do the tilemap spawning
	spawn_from_tilemap(tile_spawner)

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

func spawn_from_tilemap(tile_spawner):
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
		clear_children(target_node)

	# For each tile, spawn a child into the target node
	for cellv in source_tilemap.get_used_cells():
		# Figure out the tile name for this cell
		var tile_set = source_tilemap.tile_set
		var tile_index = source_tilemap.get_cellv(cellv)
		var tile_name = tile_set.tile_get_name(tile_index)
		print(tile_name)

		# Get the mapping entry for this tile name
		var mapping_entry = mapping[tile_name]
		
		# Ignore tiles with no mapping
		if mapping_entry == null:
			continue

		# Using the entry, find the scene path for this tile name
		var scene_path = mapping_entry['scene']
		print(scene_path)

		# Add the child
		var child = spawn_child(get_tree().get_edited_scene_root(), target_node, scene_path)

		# Transform the child to match the global transform of the tile
		var tile_transform = source_tilemap.global_transform
		tile_transform.origin = tile_transform.xform(source_tilemap.map_to_world(cellv) + origin_offset)
		child.global_transform = tile_transform
		
		# Snap to pixels if requested
		if tile_spawner.grid_alignment == Align.ROUND:
			child.global_position = Vector2(round(child.global_position.x), round(child.global_position.y))
		elif tile_spawner.grid_alignment == Align.FLOOR:
			child.global_position = Vector2(floor(child.global_position.x), floor(child.global_position.y))
		elif tile_spawner.grid_alignment == Align.CEIL:
			child.global_position = Vector2(ceil(child.global_position.x), ceil(child.global_position.y))
		elif tile_spawner.grid_alignment == Align.TRUNCATE:
			child.global_position = Vector2(int(child.global_position.x), int(child.global_position.y))

func clear_children(parent_node):
	for child_node in parent_node.get_children():
		child_node.free()

func spawn_child(scene_root, parent, scene_path):
	var node
	node = load(scene_path).instance()
	node.filename = scene_path
	parent.add_child(node)
	node.position = Vector2(0,0)
	node.set_owner(scene_root)
	node.set_name(node.name)
	return node