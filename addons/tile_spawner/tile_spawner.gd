tool
extends Node2D

const TileSpawnerPlugin = preload("./tile_spawner_plugin.gd")

export(NodePath) var source_tilemap = null setget set_source_tilemap_path
export(String, FILE, "*.json") var mapping
export(bool) var clear_children_before_baking = true
export(bool) var spawn_at_runtime = false
export(NodePath) var target_node = "." setget set_target_node_path
export(int, "None", "Round", "Floor", "Ceiling", "Truncate") var grid_alignment = TileSpawnerPlugin.Align.NONE

var _source_tilemap = null
var _target_node = null

func _enter_tree():
	# Mark this node to help fetch it later
	add_to_group(TileSpawnerPlugin.UUID_TILE_SPAWNER)

func _exit_tree():
	remove_from_group(TileSpawnerPlugin.UUID_TILE_SPAWNER)

func _ready():
	_update_source_tilemap_field()
	_update_target_node_field()

	if _source_tilemap != null and not Engine.is_editor_hint():
		# At runtime, hide the source tilemap and show the new nodes so that you
		# can leave the tilemap showing while editing rapidly
		_source_tilemap.visible = false
		visible = true

		# Spawn nodes from tilemap at runtime desired
		if spawn_at_runtime:
			TileSpawnerPlugin.spawn_from_tilemap(get_tree(), self)

# source_tilemap helpers

func get_source_tilemap():
	return _source_tilemap

func set_source_tilemap_path(path):
	source_tilemap = path
	if is_inside_tree():
		_update_source_tilemap_field()

func _update_source_tilemap_field():
	if source_tilemap == null:
		# Unset the node if nothing is set for the node path
		_source_tilemap = null
		return

	var node = get_node(source_tilemap)
	if node == null or not node is TileMap:
		# Fail if the node is the wrong type
		print("Error: Source TileMap must be a TileMap node!")
		source_tilemap = null
		return

	# Update the node
	_source_tilemap = node

# target_node helpers

func get_target_node():
	return _target_node

func set_target_node_path(path):
	target_node = path
	if is_inside_tree():
		_update_target_node_field()

func _update_target_node_field():
	if target_node == null:
		# Unset the node if nothing is set for the node path
		_target_node = null
		return

	var node = get_node(target_node)
	if not node is CanvasItem:
		# Fail if the node is the wrong type
		print("Error: Target node must be a CanvasItem!")
		target_node = null
		return

	# Update the node
	_target_node = node