"""
Converts map.json to Godot TileMap tile_data and updates level_1.tscn
This embeds the tiles directly in the scene file for editor editing.
"""
import json
import re

def encode_tile_data(x: int, y: int, source_id: int, atlas_x: int, atlas_y: int) -> list[int]:
    """
    Encode a single tile into Godot's PackedInt32Array format.
    Returns 3 integers: [cell_coords, source_atlas, alternative_id]
    
    Godot TileMap format (format=2):
    - First int: cell coordinates encoded as (y << 16) | (x & 0xFFFF)
    - Second int: source_id only
    - Third int: (atlas_y << 16) | atlas_x
    """
    # Encode cell position
    cell_coords = (y << 16) | (x & 0xFFFF)
    
    # Source ID (0 for main tileset)
    src = source_id
    
    # Atlas coordinates
    atlas = (atlas_y << 16) | (atlas_x & 0xFFFF)
    
    return [cell_coords, src, atlas]


def convert_tile_index_to_atlas(tile_index: int, columns: int = 16) -> tuple[int, int]:
    """Convert linear tile index to atlas x,y coordinates"""
    atlas_x = tile_index % columns
    atlas_y = tile_index // columns
    return atlas_x, atlas_y


def load_map_json(filepath: str) -> dict:
    with open(filepath, 'r') as f:
        return json.load(f)


def generate_tile_data(map_data: dict, tileset_columns: int = 16) -> list[int]:
    """Generate PackedInt32Array data from map.json"""
    tiles = map_data.get('tiles', [])
    tile_data = []
    
    for y, row in enumerate(tiles):
        for x, tile_index in enumerate(row):
            if tile_index >= 0:  # Skip invalid tiles
                atlas_x, atlas_y = convert_tile_index_to_atlas(tile_index, tileset_columns)
                encoded = encode_tile_data(x, y, 0, atlas_x, atlas_y)
                tile_data.extend(encoded)
    
    return tile_data


def format_packed_int32_array(data: list[int]) -> str:
    """Format as Godot PackedInt32Array string"""
    return f"PackedInt32Array({', '.join(str(x) for x in data)})"


def update_tscn_file(tscn_path: str, tile_data_str: str):
    """Update the level_1.tscn file with the tile data"""
    with open(tscn_path, 'r') as f:
        content = f.read()
    
    # Check if layer_0/tile_data already exists
    if 'layer_0/tile_data' in content:
        # Replace existing tile_data
        content = re.sub(
            r'layer_0/tile_data = PackedInt32Array\([^)]*\)',
            f'layer_0/tile_data = {tile_data_str}',
            content
        )
    else:
        # Add tile_data after format = 2
        content = content.replace(
            'format = 2',
            f'format = 2\nlayer_0/tile_data = {tile_data_str}'
        )
    
    with open(tscn_path, 'w') as f:
        f.write(content)
    
    print(f"Updated {tscn_path} with tile data")


def main():
    # Paths
    map_json_path = r"d:\Programming Languages\first attempt\asset\map.json"
    tscn_path = r"d:\Programming Languages\first attempt\levels\level_1.tscn"
    
    # Load map data
    print("Loading map.json...")
    map_data = load_map_json(map_json_path)
    
    width = map_data.get('width', 0)
    height = map_data.get('height', 0)
    print(f"Map size: {width}x{height}")
    
    # Generate tile data (16 columns for sewer_1.png tileset)
    print("Generating tile data...")
    tile_data = generate_tile_data(map_data, tileset_columns=16)
    print(f"Generated {len(tile_data) // 3} tiles")
    
    # Format as PackedInt32Array
    tile_data_str = format_packed_int32_array(tile_data)
    
    # Update the .tscn file
    print("Updating level_1.tscn...")
    update_tscn_file(tscn_path, tile_data_str)
    
    print("Done! Reload the scene in Godot to see the tiles.")


if __name__ == "__main__":
    main()
