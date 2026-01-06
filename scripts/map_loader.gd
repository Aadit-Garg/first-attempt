extends Node

## Map Loader - Loads JSON map data and places tiles on a TileMap
## Attach this script to a Node that is a sibling or parent of the TileMap

@export var tilemap_path: NodePath = "TileMap"
@export var map_json_path: String = "res://asset/map.json"
@export var source_id: int = 0  # TileSet source ID to use
@export var tileset_columns: int = 16  # Number of columns in your tileset

var tilemap: TileMap

func _ready() -> void:
	tilemap = get_node(tilemap_path) as TileMap
	if tilemap:
		load_map_from_json()
	else:
		push_error("TileMap not found at path: " + str(tilemap_path))


func load_map_from_json() -> void:
	var file = FileAccess.open(map_json_path, FileAccess.READ)
	if not file:
		push_error("Could not open map file: " + map_json_path)
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("JSON parse error: " + json.get_error_message())
		return
	
	var map_data = json.data
	
	var width: int = map_data.get("width", 0)
	var height: int = map_data.get("height", 0)
	var tiles: Array = map_data.get("tiles", [])
	var roles: Array = map_data.get("roles", [])
	
	print("Loading map: ", width, "x", height, " tiles")
	
	# Clear existing tiles on layer 0
	tilemap.clear_layer(0)
	
	# Place tiles based on JSON data
	for y in range(tiles.size()):
		var row: Array = tiles[y]
		for x in range(row.size()):
			var tile_index: int = row[x]
			var atlas_coords = get_atlas_coords_from_index(tile_index)
			
			# Check if this tile coordinate exists in the tileset
			if is_valid_tile(atlas_coords):
				tilemap.set_cell(0, Vector2i(x, y), source_id, atlas_coords)
	
	print("Map loaded successfully! ", width * height, " tiles placed.")


func get_atlas_coords_from_index(tile_index: int) -> Vector2i:
	# Convert linear tile index to 2D atlas coordinates
	# Based on tileset with tileset_columns columns
	var atlas_x: int = tile_index % tileset_columns
	var atlas_y: int = tile_index / tileset_columns
	return Vector2i(atlas_x, atlas_y)


func is_valid_tile(coords: Vector2i) -> bool:
	# Check if the tile set has this atlas coordinate
	# For sewer_1.png tileset (16 columns, ~22 rows)
	if coords.x < 0 or coords.x >= tileset_columns:
		return false
	if coords.y < 0 or coords.y >= 22:  # Approximate row count
		return false
	return true


# Call this to reload the map at runtime
func reload_map() -> void:
	load_map_from_json()
