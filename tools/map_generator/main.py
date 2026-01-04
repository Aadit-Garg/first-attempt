"""
Procedural Map Generator for Flatline Protocol
A GUI tool for creating tilemaps with various generation algorithms.
Optimized version to avoid bitmap allocation errors.
"""

import tkinter as tk
from tkinter import ttk, filedialog, messagebox
from PIL import Image, ImageTk, ImageDraw
import numpy as np
import json
import os

# =============================================================================
# CONSTANTS
# =============================================================================

WINDOW_TITLE = "Flatline Protocol - Map Generator"
TILE_ROLES = ["empty", "floor", "wall", "decoration", "water", "door", "spawn", "exit"]
ROLE_COLORS = {
    "empty": (51, 51, 51),
    "floor": (139, 115, 85),
    "wall": (74, 74, 74),
    "decoration": (107, 142, 35),
    "water": (70, 130, 180),
    "door": (205, 133, 63),
    "spawn": (50, 205, 50),
    "exit": (255, 69, 0)
}

# =============================================================================
# DATA CLASSES
# =============================================================================

class TileSet:
    """Manages the loaded tileset."""
    def __init__(self):
        self.image: Image.Image = None
        self.tile_images: list[Image.Image] = []
        self.tile_roles: list[str] = []
        self.tile_width = 16
        self.tile_height = 16
        self.path = ""
        
    def load(self, path: str, tile_w: int, tile_h: int):
        """Load tileset and split into tiles."""
        self.image = Image.open(path).convert("RGBA")
        self.path = path
        self.tile_width = tile_w
        self.tile_height = tile_h
        self.tile_images.clear()
        self.tile_roles.clear()
        
        cols = self.image.width // tile_w
        rows = self.image.height // tile_h
        
        for row in range(rows):
            for col in range(cols):
                x = col * tile_w
                y = row * tile_h
                tile_img = self.image.crop((x, y, x + tile_w, y + tile_h))
                self.tile_images.append(tile_img)
                self.tile_roles.append("empty")
                
        return len(self.tile_images)


class GameMap:
    """Represents the generated map."""
    def __init__(self, width: int = 40, height: int = 25):
        self.width = width
        self.height = height
        self.data = np.zeros((height, width), dtype=int)
        self.roles = np.full((height, width), "empty", dtype=object)
        
    def resize(self, width: int, height: int):
        """Resize the map."""
        new_data = np.zeros((height, width), dtype=int)
        new_roles = np.full((height, width), "empty", dtype=object)
        
        min_h = min(height, self.height)
        min_w = min(width, self.width)
        new_data[:min_h, :min_w] = self.data[:min_h, :min_w]
        new_roles[:min_h, :min_w] = self.roles[:min_h, :min_w]
        
        self.data = new_data
        self.roles = new_roles
        self.width = width
        self.height = height


# =============================================================================
# GENERATION ALGORITHMS
# =============================================================================

class MapGenerator:
    
    @staticmethod
    def get_tiles_by_role(tileset: TileSet, role: str) -> list[int]:
        return [i for i, r in enumerate(tileset.tile_roles) if r == role]
    
    @staticmethod
    def bsp_dungeon(game_map: GameMap, tileset: TileSet, 
                    min_room_size: int = 5, max_room_size: int = 10,
                    corridor_width: int = 2) -> None:
        import random
        
        floor_tiles = MapGenerator.get_tiles_by_role(tileset, "floor") or [0]
        wall_tiles = MapGenerator.get_tiles_by_role(tileset, "wall") or ([1] if len(tileset.tile_images) > 1 else [0])
        
        # Fill with walls
        game_map.data.fill(random.choice(wall_tiles))
        game_map.roles.fill("wall")
        
        rooms = []
        
        def split_space(x, y, w, h, depth=0):
            if depth > 4 or w < min_room_size * 2 or h < min_room_size * 2:
                room_w = random.randint(min_room_size, min(max_room_size, w - 2))
                room_h = random.randint(min_room_size, min(max_room_size, h - 2))
                room_x = x + random.randint(1, max(1, w - room_w - 1))
                room_y = y + random.randint(1, max(1, h - room_h - 1))
                rooms.append((room_x, room_y, room_w, room_h))
                return
            
            if random.random() > 0.5 and w > min_room_size * 2:
                split = random.randint(w // 3, 2 * w // 3)
                split_space(x, y, split, h, depth + 1)
                split_space(x + split, y, w - split, h, depth + 1)
            elif h > min_room_size * 2:
                split = random.randint(h // 3, 2 * h // 3)
                split_space(x, y, w, split, depth + 1)
                split_space(x, y + split, w, h - split, depth + 1)
        
        split_space(0, 0, game_map.width, game_map.height)
        
        # Carve rooms
        for rx, ry, rw, rh in rooms:
            for py in range(ry, min(ry + rh, game_map.height)):
                for px in range(rx, min(rx + rw, game_map.width)):
                    game_map.data[py, px] = random.choice(floor_tiles)
                    game_map.roles[py, px] = "floor"
        
        # Connect rooms
        for i in range(len(rooms) - 1):
            r1, r2 = rooms[i], rooms[i + 1]
            cx1, cy1 = r1[0] + r1[2] // 2, r1[1] + r1[3] // 2
            cx2, cy2 = r2[0] + r2[2] // 2, r2[1] + r2[3] // 2
            
            for x in range(min(cx1, cx2), max(cx1, cx2) + 1):
                for w in range(corridor_width):
                    if 0 <= cy1 + w < game_map.height and 0 <= x < game_map.width:
                        game_map.data[cy1 + w, x] = random.choice(floor_tiles)
                        game_map.roles[cy1 + w, x] = "floor"
            
            for y in range(min(cy1, cy2), max(cy1, cy2) + 1):
                for w in range(corridor_width):
                    if 0 <= cx2 + w < game_map.width and 0 <= y < game_map.height:
                        game_map.data[y, cx2 + w] = random.choice(floor_tiles)
                        game_map.roles[y, cx2 + w] = "floor"
    
    @staticmethod
    def cellular_automata(game_map: GameMap, tileset: TileSet,
                          fill_chance: float = 0.45, iterations: int = 5) -> None:
        import random
        
        floor_tiles = MapGenerator.get_tiles_by_role(tileset, "floor") or [0]
        wall_tiles = MapGenerator.get_tiles_by_role(tileset, "wall") or ([1] if len(tileset.tile_images) > 1 else [0])
        
        for y in range(game_map.height):
            for x in range(game_map.width):
                if x == 0 or y == 0 or x == game_map.width - 1 or y == game_map.height - 1:
                    game_map.roles[y, x] = "wall"
                elif random.random() < fill_chance:
                    game_map.roles[y, x] = "wall"
                else:
                    game_map.roles[y, x] = "floor"
        
        for _ in range(iterations):
            new_roles = game_map.roles.copy()
            for y in range(1, game_map.height - 1):
                for x in range(1, game_map.width - 1):
                    walls = sum(1 for dy in [-1, 0, 1] for dx in [-1, 0, 1]
                                if game_map.roles[y + dy, x + dx] == "wall")
                    new_roles[y, x] = "wall" if walls > 4 else "floor"
            game_map.roles = new_roles
        
        for y in range(game_map.height):
            for x in range(game_map.width):
                if game_map.roles[y, x] == "wall":
                    game_map.data[y, x] = random.choice(wall_tiles)
                else:
                    game_map.data[y, x] = random.choice(floor_tiles)
    
    @staticmethod
    def grid_city(game_map: GameMap, tileset: TileSet,
                  block_size: int = 8, street_width: int = 2) -> None:
        import random
        
        floor_tiles = MapGenerator.get_tiles_by_role(tileset, "floor") or [0]
        wall_tiles = MapGenerator.get_tiles_by_role(tileset, "wall") or ([1] if len(tileset.tile_images) > 1 else [0])
        
        for y in range(game_map.height):
            for x in range(game_map.width):
                game_map.data[y, x] = random.choice(floor_tiles)
                game_map.roles[y, x] = "floor"
        
        period = block_size + street_width
        for by in range(0, game_map.height, period):
            for bx in range(0, game_map.width, period):
                bw = random.randint(block_size - 2, block_size)
                bh = random.randint(block_size - 2, block_size)
                
                for y in range(by, min(by + bh, game_map.height)):
                    for x in range(bx, min(bx + bw, game_map.width)):
                        game_map.data[y, x] = random.choice(wall_tiles)
                        game_map.roles[y, x] = "wall"


# =============================================================================
# PRESETS
# =============================================================================

PRESETS = {
    "Sewer": {"algorithm": "bsp", "params": {"min_room_size": 4, "max_room_size": 8, "corridor_width": 2}},
    "Urban": {"algorithm": "grid", "params": {"block_size": 10, "street_width": 3}},
    "Office": {"algorithm": "bsp", "params": {"min_room_size": 6, "max_room_size": 12, "corridor_width": 2}},
    "Caves": {"algorithm": "cellular", "params": {"fill_chance": 0.48, "iterations": 6}}
}


# =============================================================================
# EXPORT
# =============================================================================

class Exporter:
    @staticmethod
    def to_json(game_map: GameMap, tileset: TileSet, path: str) -> None:
        data = {
            "width": game_map.width,
            "height": game_map.height,
            "tile_width": tileset.tile_width,
            "tile_height": tileset.tile_height,
            "tileset_path": os.path.basename(tileset.path),
            "tiles": game_map.data.tolist(),
            "roles": game_map.roles.tolist()
        }
        with open(path, 'w') as f:
            json.dump(data, f, indent=2)
    
    @staticmethod
    def to_tscn(game_map: GameMap, tileset: TileSet, path: str) -> None:
        tscn = '''[gd_scene load_steps=2 format=3]
[ext_resource type="TileSet" path="res://tileset.tres" id="1"]
[node name="GeneratedMap" type="TileMapLayer"]
tile_set = ExtResource("1")
'''
        with open(path, 'w') as f:
            f.write(tscn)
        Exporter.to_json(game_map, tileset, path.replace('.tscn', '_data.json'))


# =============================================================================
# MAIN APPLICATION
# =============================================================================

class MapGeneratorApp:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title(WINDOW_TITLE)
        self.root.geometry("1200x700")
        
        self.tileset = TileSet()
        self.game_map = GameMap(40, 25)
        self.selected_tile = 0
        
        # Image references (to prevent garbage collection)
        self.tileset_photo = None
        self.map_photo = None
        
        self._setup_ui()
        
    def _setup_ui(self):
        # Main container
        main = ttk.Frame(self.root, padding=5)
        main.pack(fill=tk.BOTH, expand=True)
        
        # Left: Tileset panel
        left = ttk.LabelFrame(main, text="Tileset", padding=5)
        left.pack(side=tk.LEFT, fill=tk.Y, padx=5)
        
        # Load controls
        ctrl = ttk.Frame(left)
        ctrl.pack(fill=tk.X)
        
        ttk.Button(ctrl, text="Load", command=self._load_tileset).pack(side=tk.LEFT)
        ttk.Label(ctrl, text="Size:").pack(side=tk.LEFT, padx=(5, 0))
        self.tile_size_var = tk.StringVar(value="16")
        ttk.Entry(ctrl, textvariable=self.tile_size_var, width=4).pack(side=tk.LEFT)
        
        # Role selector
        role_frame = ttk.Frame(left)
        role_frame.pack(fill=tk.X, pady=5)
        ttk.Label(role_frame, text="Role:").pack(side=tk.LEFT)
        self.role_var = tk.StringVar(value="floor")
        ttk.Combobox(role_frame, textvariable=self.role_var, values=TILE_ROLES, width=10).pack(side=tk.LEFT, padx=5)
        
        # Tileset canvas (simple label with image)
        self.tileset_label = ttk.Label(left, text="No tileset loaded")
        self.tileset_label.pack(fill=tk.BOTH, expand=True, pady=5)
        self.tileset_label.bind("<Button-1>", self._on_tileset_click)
        
        # Center: Map
        center = ttk.LabelFrame(main, text="Map Preview", padding=5)
        center.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=5)
        
        self.map_label = ttk.Label(center, text="Generate a map to preview")
        self.map_label.pack(fill=tk.BOTH, expand=True)
        self.map_label.bind("<Button-1>", self._on_map_click)
        self.map_label.bind("<B1-Motion>", self._on_map_click)
        
        # Right: Controls
        right = ttk.LabelFrame(main, text="Controls", padding=5)
        right.pack(side=tk.RIGHT, fill=tk.Y, padx=5)
        
        # Map size
        size_frame = ttk.LabelFrame(right, text="Map Size", padding=5)
        size_frame.pack(fill=tk.X, pady=5)
        
        ttk.Label(size_frame, text="Width:").grid(row=0, column=0)
        self.width_var = tk.IntVar(value=40)
        ttk.Entry(size_frame, textvariable=self.width_var, width=5).grid(row=0, column=1)
        
        ttk.Label(size_frame, text="Height:").grid(row=1, column=0)
        self.height_var = tk.IntVar(value=25)
        ttk.Entry(size_frame, textvariable=self.height_var, width=5).grid(row=1, column=1)
        
        ttk.Button(size_frame, text="Resize", command=self._resize_map).grid(row=2, column=0, columnspan=2, pady=5)
        
        # Generation
        gen_frame = ttk.LabelFrame(right, text="Generate", padding=5)
        gen_frame.pack(fill=tk.X, pady=5)
        
        self.preset_var = tk.StringVar(value="Sewer")
        ttk.Combobox(gen_frame, textvariable=self.preset_var, values=list(PRESETS.keys()), width=12).pack()
        ttk.Button(gen_frame, text="Generate", command=self._generate).pack(pady=5)
        
        # Export
        exp_frame = ttk.LabelFrame(right, text="Export", padding=5)
        exp_frame.pack(fill=tk.X, pady=5)
        
        ttk.Button(exp_frame, text="Export JSON", command=self._export_json).pack(fill=tk.X)
        ttk.Button(exp_frame, text="Export TSCN", command=self._export_tscn).pack(fill=tk.X, pady=2)
        
        # Status
        self.status_var = tk.StringVar(value="Ready")
        ttk.Label(self.root, textvariable=self.status_var, relief=tk.SUNKEN).pack(fill=tk.X, side=tk.BOTTOM)
    
    def _load_tileset(self):
        path = filedialog.askopenfilename(filetypes=[("Images", "*.png *.jpg")])
        if not path:
            return
        
        try:
            size = int(self.tile_size_var.get())
            count = self.tileset.load(path, size, size)
            self._display_tileset()
            self.status_var.set(f"Loaded {count} tiles")
        except Exception as e:
            messagebox.showerror("Error", str(e))
    
    def _display_tileset(self):
        if not self.tileset.tile_images:
            return
        
        # Create a grid image of tiles (max 8 cols)
        cols = min(8, len(self.tileset.tile_images))
        rows = (len(self.tileset.tile_images) + cols - 1) // cols
        cell = 32
        
        grid = Image.new("RGB", (cols * cell, rows * cell), (30, 30, 30))
        draw = ImageDraw.Draw(grid)
        
        for i, img in enumerate(self.tileset.tile_images):
            r, c = i // cols, i % cols
            x, y = c * cell, r * cell
            
            # Draw role color background
            role = self.tileset.tile_roles[i]
            color = ROLE_COLORS.get(role, (51, 51, 51))
            draw.rectangle([x, y, x + cell - 1, y + cell - 1], fill=color)
            
            # Paste tile
            resized = img.resize((cell - 2, cell - 2), Image.Resampling.NEAREST)
            grid.paste(resized, (x + 1, y + 1), resized if resized.mode == 'RGBA' else None)
        
        self.tileset_photo = ImageTk.PhotoImage(grid)
        self.tileset_label.configure(image=self.tileset_photo, text="")
    
    def _on_tileset_click(self, event):
        if not self.tileset.tile_images:
            return
        
        cell = 32
        cols = min(8, len(self.tileset.tile_images))
        col = event.x // cell
        row = event.y // cell
        idx = row * cols + col
        
        if 0 <= idx < len(self.tileset.tile_images):
            self.tileset.tile_roles[idx] = self.role_var.get()
            self.selected_tile = idx
            self._display_tileset()
            self.status_var.set(f"Tile {idx} → {self.role_var.get()}")
    
    def _resize_map(self):
        self.game_map.resize(self.width_var.get(), self.height_var.get())
        self._display_map()
    
    def _generate(self):
        if not self.tileset.tile_images:
            messagebox.showwarning("Warning", "Load a tileset first!")
            return
        
        preset = PRESETS.get(self.preset_var.get(), PRESETS["Sewer"])
        
        if preset["algorithm"] == "bsp":
            MapGenerator.bsp_dungeon(self.game_map, self.tileset, **preset["params"])
        elif preset["algorithm"] == "cellular":
            MapGenerator.cellular_automata(self.game_map, self.tileset, **preset["params"])
        elif preset["algorithm"] == "grid":
            MapGenerator.grid_city(self.game_map, self.tileset, **preset["params"])
        
        self._display_map()
        self.status_var.set(f"Generated {self.preset_var.get()} map")
    
    def _display_map(self):
        cell = 10
        w = self.game_map.width * cell
        h = self.game_map.height * cell
        
        img = Image.new("RGB", (w, h), (40, 40, 40))
        draw = ImageDraw.Draw(img)
        
        for y in range(self.game_map.height):
            for x in range(self.game_map.width):
                role = self.game_map.roles[y, x]
                color = ROLE_COLORS.get(role, (51, 51, 51))
                px, py = x * cell, y * cell
                draw.rectangle([px, py, px + cell - 1, py + cell - 1], fill=color)
        
        self.map_photo = ImageTk.PhotoImage(img)
        self.map_label.configure(image=self.map_photo, text="")
    
    def _on_map_click(self, event):
        if not self.tileset.tile_images:
            return
        
        cell = 10
        x = event.x // cell
        y = event.y // cell
        
        if 0 <= x < self.game_map.width and 0 <= y < self.game_map.height:
            role = self.tileset.tile_roles[self.selected_tile]
            self.game_map.data[y, x] = self.selected_tile
            self.game_map.roles[y, x] = role
            self._display_map()
    
    def _export_json(self):
        if not self.tileset.tile_images:
            return
        path = filedialog.asksaveasfilename(defaultextension=".json", filetypes=[("JSON", "*.json")])
        if path:
            Exporter.to_json(self.game_map, self.tileset, path)
            self.status_var.set(f"Saved {os.path.basename(path)}")
    
    def _export_tscn(self):
        if not self.tileset.tile_images:
            return
        path = filedialog.asksaveasfilename(defaultextension=".tscn", filetypes=[("TSCN", "*.tscn")])
        if path:
            Exporter.to_tscn(self.game_map, self.tileset, path)
            self.status_var.set(f"Saved {os.path.basename(path)}")
    
    def run(self):
        self.root.mainloop()


if __name__ == "__main__":
    app = MapGeneratorApp()
    app.run()
