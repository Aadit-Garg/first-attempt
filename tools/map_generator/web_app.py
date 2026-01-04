"""
Procedural Map Generator - Fixed Version with Zoom
All features working: drag select, keyboard resize, spacing, offset, zoom, tile preview
"""

from flask import Flask, render_template_string, request, jsonify, send_file
from PIL import Image
import numpy as np
import json
import io
import base64
import random
from collections import defaultdict

app = Flask(__name__)

# Global state
DIRECTIONS = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW']
DIR_OFFSETS = {
    'N': (0, -1), 'NE': (1, -1), 'E': (1, 0), 'SE': (1, 1),
    'S': (0, 1), 'SW': (-1, 1), 'W': (-1, 0), 'NW': (-1, -1)
}

class State:
    tileset_image = None
    tile_images = []
    tile_roles = []
    tile_width = 16
    tile_height = 16
    spacing_x = 0
    spacing_y = 0
    offset_x = 0
    offset_y = 0
    # 8-directional relations: tile_idx -> direction -> {allowed: set, forbidden: set}
    tile_relations = defaultdict(lambda: {d: {"allowed": set(), "forbidden": set()} for d in DIRECTIONS})
    map_width = 40
    map_height = 25
    map_data = None
    map_roles = None

state = State()

ROLE_COLORS = {
    "empty": (51, 51, 51), "floor": (139, 115, 85), "wall": (74, 74, 74),
    "decoration": (107, 142, 35), "water": (70, 130, 180), "door": (205, 133, 63),
    "spawn": (50, 205, 50), "exit": (255, 69, 0)
}

# ============================================================================
# GENERATORS
# ============================================================================

def get_tiles_by_role(role):
    return [i for i, r in enumerate(state.tile_roles) if r == role]

def generate_bsp(min_room=5, max_room=10, corridor=2):
    floor_tiles = get_tiles_by_role("floor") or [0]
    wall_tiles = get_tiles_by_role("wall") or ([1] if len(state.tile_images) > 1 else [0])
    
    state.map_data = np.full((state.map_height, state.map_width), wall_tiles[0] if wall_tiles else 0)
    state.map_roles = np.full((state.map_height, state.map_width), "wall", dtype=object)
    
    rooms = []
    
    def split(x, y, w, h, depth=0):
        if depth > 4 or w < min_room * 2 or h < min_room * 2:
            max_w = max(min_room, min(max_room, w - 2))
            max_h = max(min_room, min(max_room, h - 2))
            if max_w >= min_room and max_h >= min_room:
                rw = random.randint(min_room, max_w)
                rh = random.randint(min_room, max_h)
                rx = x + random.randint(0, max(0, w - rw - 1))
                ry = y + random.randint(0, max(0, h - rh - 1))
                rooms.append((rx, ry, rw, rh))
            return
        
        if random.random() > 0.5 and w > min_room * 2:
            s = random.randint(w // 3, 2 * w // 3)
            split(x, y, s, h, depth + 1)
            split(x + s, y, w - s, h, depth + 1)
        elif h > min_room * 2:
            s = random.randint(h // 3, 2 * h // 3)
            split(x, y, w, s, depth + 1)
            split(x, y + s, w, h - s, depth + 1)
    
    split(0, 0, state.map_width, state.map_height)
    
    for rx, ry, rw, rh in rooms:
        for py in range(ry, min(ry + rh, state.map_height)):
            for px in range(rx, min(rx + rw, state.map_width)):
                state.map_data[py, px] = random.choice(floor_tiles)
                state.map_roles[py, px] = "floor"
    
    for i in range(len(rooms) - 1):
        r1, r2 = rooms[i], rooms[i + 1]
        cx1, cy1 = r1[0] + r1[2] // 2, r1[1] + r1[3] // 2
        cx2, cy2 = r2[0] + r2[2] // 2, r2[1] + r2[3] // 2
        
        for x in range(min(cx1, cx2), max(cx1, cx2) + 1):
            for w in range(corridor):
                if 0 <= cy1 + w < state.map_height and 0 <= x < state.map_width:
                    state.map_data[cy1 + w, x] = random.choice(floor_tiles)
                    state.map_roles[cy1 + w, x] = "floor"
        
        for y in range(min(cy1, cy2), max(cy1, cy2) + 1):
            for w in range(corridor):
                if 0 <= cx2 + w < state.map_width and 0 <= y < state.map_height:
                    state.map_data[y, cx2 + w] = random.choice(floor_tiles)
                    state.map_roles[y, cx2 + w] = "floor"

def generate_caves(fill=0.45, iterations=5):
    floor_tiles = get_tiles_by_role("floor") or [0]
    wall_tiles = get_tiles_by_role("wall") or ([1] if len(state.tile_images) > 1 else [0])
    
    state.map_roles = np.full((state.map_height, state.map_width), "empty", dtype=object)
    
    for y in range(state.map_height):
        for x in range(state.map_width):
            if x == 0 or y == 0 or x == state.map_width - 1 or y == state.map_height - 1:
                state.map_roles[y, x] = "wall"
            elif random.random() < fill:
                state.map_roles[y, x] = "wall"
            else:
                state.map_roles[y, x] = "floor"
    
    for _ in range(iterations):
        new = state.map_roles.copy()
        for y in range(1, state.map_height - 1):
            for x in range(1, state.map_width - 1):
                walls = sum(1 for dy in [-1, 0, 1] for dx in [-1, 0, 1]
                            if state.map_roles[y + dy, x + dx] == "wall")
                new[y, x] = "wall" if walls > 4 else "floor"
        state.map_roles = new
    
    state.map_data = np.zeros((state.map_height, state.map_width), dtype=int)
    for y in range(state.map_height):
        for x in range(state.map_width):
            state.map_data[y, x] = random.choice(wall_tiles if state.map_roles[y, x] == "wall" else floor_tiles)

def get_map_b64():
    if state.map_data is None:
        return ""
    
    cell = 16
    w = state.map_width * cell
    h = state.map_height * cell
    
    img = Image.new('RGBA', (w, h), (40, 40, 40, 255))
    
    for y in range(state.map_height):
        for x in range(state.map_width):
            tile_idx = int(state.map_data[y, x])
            px, py = x * cell, y * cell
            
            if 0 <= tile_idx < len(state.tile_images):
                tile_img = state.tile_images[tile_idx].resize((cell, cell), Image.Resampling.NEAREST)
                img.paste(tile_img, (px, py), tile_img if tile_img.mode == 'RGBA' else None)
            else:
                role = state.map_roles[y, x]
                color = ROLE_COLORS.get(role, (51, 51, 51))
                for dy in range(cell):
                    for dx in range(cell):
                        img.putpixel((px + dx, py + dy), color + (255,))
    
    buf = io.BytesIO()
    img.save(buf, 'PNG')
    return base64.b64encode(buf.getvalue()).decode()

# ============================================================================
# HTML
# ============================================================================

HTML = '''
<!DOCTYPE html>
<html>
<head>
    <title>Map Generator</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: Arial; background: #1a1a2e; color: #eee; padding: 10px; }
        h1 { color: #00d4ff; font-size: 20px; margin-bottom: 10px; }
        .row { display: flex; gap: 10px; flex-wrap: wrap; }
        .panel { background: #16213e; padding: 10px; border-radius: 8px; border: 1px solid #0f3460; }
        .panel h3 { color: #e94560; font-size: 13px; margin-bottom: 8px; }
        button { background: #e94560; color: white; border: none; padding: 6px 12px; cursor: pointer; border-radius: 4px; font-size: 12px; }
        button:hover { background: #ff6b8a; }
        input, select { padding: 4px; background: #0f3460; color: #eee; border: 1px solid #e94560; border-radius: 3px; font-size: 12px; }
        input[type=number] { width: 50px; }
        label { font-size: 11px; margin-right: 5px; }
        
        #tilesetBox { position: relative; border: 2px solid #e94560; background: #000; overflow: auto; cursor: crosshair; width: 320px; height: 250px; }
        #tilesetCanvas { display: block; }
        #gridCanvas { position: absolute; top: 0; left: 0; pointer-events: none; }
        #selectBox { position: absolute; border: 2px dashed #0f0; background: rgba(0,255,0,0.1); display: none; pointer-events: none; }
        
        .tiles { display: flex; flex-wrap: wrap; gap: 2px; max-height: 150px; overflow-y: auto; background: #0a0a0a; padding: 5px; border-radius: 4px; margin-top: 5px; }
        .tile { width: 32px; height: 32px; border: 2px solid #333; cursor: pointer; background-size: contain; }
        .tile:hover { border-color: #0df; }
        .tile.sel { border-color: #0f0; box-shadow: 0 0 5px #0f0; }
        
        #mapCanvas { border: 2px solid #0f3460; max-width: 100%; }
        #status { background: #0f3460; padding: 8px; margin-top: 10px; border-radius: 4px; font-size: 12px; }
        .info { font-size: 11px; color: #888; margin: 5px 0; }
        
        .tabs { display: flex; gap: 2px; margin-bottom: 5px; }
        .tab { padding: 4px 10px; background: #0f3460; border: none; color: #888; cursor: pointer; border-radius: 3px 3px 0 0; font-size: 11px; }
        .tab.active { background: #e94560; color: white; }
        
        /* Multi-select tiles */
        .tile.multi-sel { border-color: #f1c40f; box-shadow: 0 0 5px #f1c40f; }
        .selection-info { background: #1a1a2e; padding: 4px 8px; border-radius: 4px; font-size: 11px; color: #f1c40f; display: inline-block; margin-left: 10px; }
        
        /* 8-direction node tile */
        .dir-node { position: relative; width: 80px; height: 80px; background: #1a1a2e; border: 2px solid #333; border-radius: 8px; margin: 10px; display: inline-block; }
        .dir-node .tile-img { position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); width: 32px; height: 32px; background-size: cover; border-radius: 4px; cursor: pointer; border: 2px solid #555; }
        .dir-node .tile-img:hover { border-color: #00d4ff; }
        .dir-node .tile-img.selected { border-color: #e94560; box-shadow: 0 0 8px rgba(233,69,96,0.7); }
        .dir-connector { position: absolute; width: 14px; height: 14px; background: #444; border: 2px solid #666; border-radius: 50%; cursor: pointer; font-size: 8px; color: #888; display: flex; align-items: center; justify-content: center; transition: all 0.15s; }
        .dir-connector:hover { background: #00d4ff; border-color: #00d4ff; color: #000; transform: scale(1.2); }
        .dir-connector.active { background: #e94560; border-color: #e94560; }
        .dir-connector.has-allowed { box-shadow: 0 0 6px #2ecc71; border-color: #2ecc71; }
        .dir-connector.has-forbidden { box-shadow: 0 0 6px #e74c3c; border-color: #e74c3c; }
        .dir-connector.has-both { box-shadow: 0 0 6px #f39c12; border-color: #f39c12; }
        /* Positions for 8 directions */
        .dir-connector.N { top: 0; left: 50%; transform: translate(-50%, -50%); }
        .dir-connector.NE { top: 8px; right: 8px; }
        .dir-connector.E { top: 50%; right: 0; transform: translate(50%, -50%); }
        .dir-connector.SE { bottom: 8px; right: 8px; }
        .dir-connector.S { bottom: 0; left: 50%; transform: translate(-50%, 50%); }
        .dir-connector.SW { bottom: 8px; left: 8px; }
        .dir-connector.W { top: 50%; left: 0; transform: translate(-50%, -50%); }
        .dir-connector.NW { top: 8px; left: 8px; }
        .dir-label { position: absolute; bottom: -20px; left: 50%; transform: translateX(-50%); font-size: 9px; color: #888; }
        
        /* Direction relation panel */
        .dir-panel { background: #0a0a1a; border: 1px solid #333; border-radius: 6px; padding: 10px; margin-top: 8px; }
        .dir-panel h4 { color: #00d4ff; font-size: 12px; margin: 0 0 8px 0; }
        .dir-tiles { display: flex; flex-wrap: wrap; gap: 3px; max-height: 100px; overflow-y: auto; }
        .dir-tile { width: 28px; height: 28px; border: 2px solid #333; cursor: pointer; background-size: cover; border-radius: 3px; }
        .dir-tile:hover { border-color: #00d4ff; }
        .dir-tile.allowed { border-color: #2ecc71; box-shadow: 0 0 4px #2ecc71; }
        .dir-tile.forbidden { border-color: #e74c3c; box-shadow: 0 0 4px #e74c3c; }
    </style>
</head>
<body>
    <h1>🗺️ Map Generator</h1>
    
    <div class="row">
        <!-- TILESET PANEL -->
        <div class="panel" style="width: 350px;">
            <h3>📁 Tileset</h3>
            <input type="file" id="fileInput" accept="image/*" style="font-size:11px;">
            <button onclick="loadFile()">Load</button>
            
            <div class="info">
                <b>Controls:</b> Drag=select | Scroll=zoom | ↑↓←→=resize | Shift+arrows=offset
            </div>
            
            <div style="margin: 5px 0;">
                <label>Tile W:</label><input type="number" id="tw" value="16" onchange="updateGrid()">
                <label>H:</label><input type="number" id="th" value="16" onchange="updateGrid()">
                <label>SpaceX:</label><input type="number" id="sx" value="0" onchange="updateGrid()">
                <label>Y:</label><input type="number" id="sy" value="0" onchange="updateGrid()">
            </div>
            <div style="margin: 5px 0;">
                <label>OffsetX:</label><input type="number" id="ox" value="0" onchange="updateGrid()">
                <label>Y:</label><input type="number" id="oy" value="0" onchange="updateGrid()">
                <button onclick="sliceTiles()">Slice Tiles</button>
            </div>
            
            <div id="tilesetBox">
                <canvas id="tilesetCanvas"></canvas>
                <canvas id="gridCanvas"></canvas>
                <div id="selectBox"></div>
            </div>
            <div id="sizeInfo" class="info"></div>
            
            <div style="margin-top: 5px;">
                <div class="tabs">
                    <button class="tab active" onclick="showTab('roles')">Roles</button>
                    <button class="tab" onclick="showTab('relations')">Relations</button>
                </div>
                
                <div id="rolesTab">
                    <div style="display: flex; align-items: center; gap: 8px; margin-bottom: 5px;">
                        <label>Role:</label>
                        <select id="role">
                            <option>floor</option><option>wall</option><option>empty</option>
                            <option>decoration</option><option>water</option><option>door</option>
                            <option>spawn</option><option>exit</option>
                        </select>
                        <button onclick="assignRoleToSelected()">Assign to Selected</button>
                        <button onclick="clearSelection()" style="background:#555;">Clear Selection</button>
                    </div>
                    <div class="info">Click tile = select single | Ctrl+Click = toggle multi-select | Drag = box select</div>
                    <div id="selectionInfo" class="selection-info" style="display:none;">0 tiles selected</div>
                    <div id="tilesContainer" class="tiles">Load tileset first</div>
                </div>
                
                <div id="relationsTab" style="display: none;">
                    <div class="info">Relations editor open in panel below ↓</div>
                </div>
            </div>
        </div>
        
        <!-- MAP PANEL -->
        <div class="panel" style="flex: 1; min-width: 400px;">
            <h3>🗺️ Generate Map</h3>
            <div style="margin-bottom: 10px;">
                <label>Width:</label><input type="number" id="mapW" value="30">
                <label>Height:</label><input type="number" id="mapH" value="20">
                <label>Preset:</label>
                <select id="preset">
                    <option value="wfc">WFC (Relations)</option>
                    <option value="sewer">Sewer</option>
                    <option value="office">Office</option>
                    <option value="caves">Caves</option>
                </select>
                <button onclick="generate()">Generate</button>
                <button onclick="exportJSON()">Export JSON</button>
            </div>
            <canvas id="mapCanvas" width="480" height="320"></canvas>
        </div>
    </div>
    
    <div id="status">Ready</div>
    
    <!-- SEPARATE RELATIONS PANEL (Full Width) -->
    <div id="relationsPanel" class="panel" style="display:none; margin-top:10px; width:100%;">
        <h3>🔗 Tile Relations Editor (8 Directions)</h3>
        <div class="info">Select a tile, then click a direction connector (N/NE/E/SE/S/SW/W/NW) to set which tiles can appear in that direction.</div>
        <div style="margin: 10px 0; display: flex; gap: 10px; align-items: center; flex-wrap: wrap;">
            <button onclick="autoRelations8Dir()" style="padding:5px 12px;">Auto Relations (same role, all dirs)</button>
            <button onclick="clearAllRelations()" style="padding:5px 12px;background:#555;">Clear All Relations</button>
            <button onclick="closeRelationsPanel()" style="padding:5px 12px;background:#e74c3c;margin-left:auto;">Close Panel</button>
        </div>
        <div style="display:flex; gap:15px; flex-wrap:wrap;">
            <div style="flex:1; min-width:400px;">
                <h4 style="color:#00d4ff; font-size:13px; margin-bottom:8px;">All Tiles (click connector dots)</h4>
                <div id="tileNodesContainer" style="display:flex;flex-wrap:wrap;gap:8px;max-height:300px;overflow-y:auto;background:#0a0a0a;padding:12px;border-radius:6px;"></div>
            </div>
            <div id="directionPanel" class="dir-panel" style="flex:1; min-width:300px; display:none;">
                <h4>Editing: Tile #<span id="dirPanelTile">0</span> → <span id="dirPanelDir" style="color:#e94560;">N</span> Direction</h4>
                <div style="margin:10px 0; font-size:12px;">
                    <span style="color:#2ecc71;">✓ Left-click = Allow</span> &nbsp;|&nbsp; 
                    <span style="color:#e74c3c;">✗ Right-click = Forbid</span> &nbsp;|&nbsp;
                    <span style="color:#888;">Click again to remove</span>
                </div>
                <div id="dirTilesContainer" class="dir-tiles" style="max-height:250px;"></div>
            </div>
        </div>
    </div>

<script>
// State
let img = null;
let zoom = 1;
let panX = 0, panY = 0;
let tiles = [];
let selTile = 0;
let selectedTiles = new Set(); // Multi-select for role assignment

// Elements
const box = document.getElementById('tilesetBox');
const canvas = document.getElementById('tilesetCanvas');
const ctx = canvas.getContext('2d');
const grid = document.getElementById('gridCanvas');
const gctx = grid.getContext('2d');
const selBox = document.getElementById('selectBox');

// Load file
function loadFile() {
    const file = document.getElementById('fileInput').files[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = (e) => {
        img = new Image();
        img.onload = () => {
            canvas.width = img.width;
            canvas.height = img.height;
            grid.width = img.width;
            grid.height = img.height;
            zoom = Math.min(320 / img.width, 200 / img.height, 1);
            applyTransform();
            ctx.imageSmoothingEnabled = false;
            ctx.drawImage(img, 0, 0);
            updateGrid();
            status('Loaded! Drag to select tile, scroll to zoom');
        };
        img.src = e.target.result;
    };
    reader.readAsDataURL(file);
}

function applyTransform() {
    // Scale canvas size directly instead of using CSS transform
    if (!img) return;
    const newW = Math.round(img.width * zoom);
    const newH = Math.round(img.height * zoom);
    
    canvas.width = newW;
    canvas.height = newH;
    grid.width = newW;
    grid.height = newH;
    
    ctx.imageSmoothingEnabled = false;
    ctx.drawImage(img, 0, 0, newW, newH);
    updateGrid();
}

// Get values
function getVals() {
    return {
        tw: parseInt(document.getElementById('tw').value) || 16,
        th: parseInt(document.getElementById('th').value) || 16,
        sx: parseInt(document.getElementById('sx').value) || 0,
        sy: parseInt(document.getElementById('sy').value) || 0,
        ox: parseInt(document.getElementById('ox').value) || 0,
        oy: parseInt(document.getElementById('oy').value) || 0
    };
}

function setVals(v) {
    document.getElementById('tw').value = v.tw;
    document.getElementById('th').value = v.th;
    document.getElementById('sx').value = v.sx;
    document.getElementById('sy').value = v.sy;
    document.getElementById('ox').value = v.ox;
    document.getElementById('oy').value = v.oy;
}

function updateGrid() {
    if (!img) return;
    const v = getVals();
    gctx.clearRect(0, 0, grid.width, grid.height);
    
    const stepX = (v.tw + v.sx) * zoom;
    const stepY = (v.th + v.sy) * zoom;
    const tw = v.tw * zoom;
    const th = v.th * zoom;
    const ox = v.ox * zoom;
    const oy = v.oy * zoom;
    
    // Fill spacing gaps with a subtle color to show they're not part of tiles
    if (v.sx > 0 || v.sy > 0) {
        gctx.fillStyle = 'rgba(233, 69, 96, 0.25)';
        // Vertical spacing strips
        for (let x = ox + tw; x < grid.width; x += stepX) {
            if (v.sx > 0) {
                gctx.fillRect(x, 0, v.sx * zoom, grid.height);
            }
        }
        // Horizontal spacing strips
        for (let y = oy + th; y < grid.height; y += stepY) {
            if (v.sy > 0) {
                gctx.fillRect(0, y, grid.width, v.sy * zoom);
            }
        }
    }
    
    // Draw tile boundaries with clear cyan lines
    gctx.strokeStyle = 'rgba(0,255,255,0.8)';
    gctx.lineWidth = 1;
    
    for (let x = ox; x < grid.width; x += stepX) {
        gctx.beginPath();
        gctx.moveTo(x, 0); gctx.lineTo(x, grid.height);
        gctx.stroke();
        gctx.beginPath();
        gctx.moveTo(x + tw, 0); gctx.lineTo(x + tw, grid.height);
        gctx.stroke();
    }
    for (let y = oy; y < grid.height; y += stepY) {
        gctx.beginPath();
        gctx.moveTo(0, y); gctx.lineTo(grid.width, y);
        gctx.stroke();
        gctx.beginPath();
        gctx.moveTo(0, y + th); gctx.lineTo(grid.width, y + th);
        gctx.stroke();
    }
    
    document.getElementById('sizeInfo').textContent = 
        `Tile: ${v.tw}x${v.th} | Space: ${v.sx},${v.sy} | Offset: ${v.ox},${v.oy} | Zoom: ${Math.round(zoom*100)}%`;
}

// Zoom
box.addEventListener('wheel', (e) => {
    e.preventDefault();
    zoom *= e.deltaY < 0 ? 1.1 : 0.9;
    zoom = Math.max(0.5, Math.min(5, zoom));
    applyTransform();
});

// Drag to select
let dragging = false, startX, startY;

box.addEventListener('mousedown', (e) => {
    if (!img) return;
    dragging = true;
    // Account for scroll position
    startX = e.offsetX + box.scrollLeft;
    startY = e.offsetY + box.scrollTop;
    selBox.style.display = 'block';
    selBox.style.left = startX + 'px';
    selBox.style.top = startY + 'px';
    selBox.style.width = '0';
    selBox.style.height = '0';
});

box.addEventListener('mousemove', (e) => {
    if (!dragging) return;
    const x = e.offsetX + box.scrollLeft;
    const y = e.offsetY + box.scrollTop;
    
    const left = Math.min(startX, x);
    const top = Math.min(startY, y);
    const w = Math.abs(x - startX);
    const h = Math.abs(y - startY);
    
    selBox.style.left = left + 'px';
    selBox.style.top = top + 'px';
    selBox.style.width = w + 'px';
    selBox.style.height = h + 'px';
});

box.addEventListener('mouseup', (e) => {
    if (!dragging) return;
    dragging = false;
    selBox.style.display = 'none';
    
    const x = e.offsetX + box.scrollLeft;
    const y = e.offsetY + box.scrollTop;
    
    // Convert from zoomed coordinates to original image coordinates
    const w = Math.abs(x - startX) / zoom;
    const h = Math.abs(y - startY) / zoom;
    
    if (w > 2 && h > 2) {
        const v = getVals();
        v.tw = Math.round(w);
        v.th = Math.round(h);
        setVals(v);
        updateGrid();
    }
});

// Keyboard
document.addEventListener('keydown', (e) => {
    if (!img) return;
    const v = getVals();
    let changed = false;
    
    if (e.shiftKey) {
        // Move offset
        if (e.key === 'ArrowUp') { v.oy = Math.max(0, v.oy - 1); changed = true; }
        if (e.key === 'ArrowDown') { v.oy++; changed = true; }
        if (e.key === 'ArrowLeft') { v.ox = Math.max(0, v.ox - 1); changed = true; }
        if (e.key === 'ArrowRight') { v.ox++; changed = true; }
    } else {
        // Resize
        if (e.key === 'ArrowUp') { v.th = Math.max(1, v.th - 1); changed = true; }
        if (e.key === 'ArrowDown') { v.th++; changed = true; }
        if (e.key === 'ArrowLeft') { v.tw = Math.max(1, v.tw - 1); changed = true; }
        if (e.key === 'ArrowRight') { v.tw++; changed = true; }
    }
    
    if (changed) {
        e.preventDefault();
        setVals(v);
        updateGrid();
    }
});

// Slice tiles
async function sliceTiles() {
    if (!img) return alert('Load an image first');
    const v = getVals();
    const formData = new FormData();
    formData.append('file', document.getElementById('fileInput').files[0]);
    formData.append('tw', v.tw);
    formData.append('th', v.th);
    formData.append('sx', v.sx);
    formData.append('sy', v.sy);
    formData.append('ox', v.ox);
    formData.append('oy', v.oy);
    
    const resp = await fetch('/slice', { method: 'POST', body: formData });
    const data = await resp.json();
    if (data.error) return alert(data.error);
    
    tiles = data.tiles;
    renderTiles();
    status(`Sliced ${tiles.length} tiles`);
}

function renderTiles() {
    const c = document.getElementById('tilesContainer');
    c.innerHTML = '';
    tiles.forEach((t, i) => {
        const d = document.createElement('div');
        let classes = 'tile';
        if (selectedTiles.has(i)) classes += ' multi-sel';
        if (i === selTile) classes += ' sel';
        d.className = classes;
        d.style.backgroundImage = `url(data:image/png;base64,${t.img})`;
        d.style.backgroundColor = roleColor(t.role);
        d.title = `#${i}: ${t.role}`;
        d.onclick = (e) => {
            if (e.ctrlKey || e.metaKey) {
                // Multi-select toggle
                if (selectedTiles.has(i)) {
                    selectedTiles.delete(i);
                } else {
                    selectedTiles.add(i);
                }
            } else {
                // Single select
                selectedTiles.clear();
                selectedTiles.add(i);
                selTile = i;
            }
            updateSelectionInfo();
            renderTiles();
        };
        c.appendChild(d);
    });
}

function updateSelectionInfo() {
    const info = document.getElementById('selectionInfo');
    if (selectedTiles.size > 0) {
        info.style.display = 'inline-block';
        info.textContent = `${selectedTiles.size} tile${selectedTiles.size > 1 ? 's' : ''} selected`;
    } else {
        info.style.display = 'none';
    }
}

async function assignRoleToSelected() {
    if (selectedTiles.size === 0) return alert('Select tiles first (click or Ctrl+click)');
    const role = document.getElementById('role').value;
    const indices = Array.from(selectedTiles);
    
    await fetch('/set_roles_batch', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({indices, role})
    });
    
    indices.forEach(i => tiles[i].role = role);
    renderTiles();
    status(`Assigned ${role} to ${indices.length} tiles`);
}

function clearSelection() {
    selectedTiles.clear();
    updateSelectionInfo();
    renderTiles();
}

function roleColor(r) {
    const c = {empty:'#333',floor:'#8b7355',wall:'#4a4a4a',decoration:'#6b8e23',water:'#4682b4',door:'#cd853f',spawn:'#32cd32',exit:'#f45'};
    return c[r] || '#333';
}

// ============================================================================
// 8-DIRECTIONAL RELATIONS
// ============================================================================
const DIRECTIONS = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
let currentRelTile = 0;
let currentDirection = 'N';
let allRelations8 = {};

function showTab(tab) {
    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
    event.target.classList.add('active');
    document.getElementById('rolesTab').style.display = tab === 'roles' ? 'block' : 'none';
    document.getElementById('relationsTab').style.display = tab === 'relations' ? 'block' : 'none';
    
    // Show/hide the separate relations panel
    const relPanel = document.getElementById('relationsPanel');
    if (tab === 'relations') {
        relPanel.style.display = 'block';
        initRelations8Dir();
    } else {
        relPanel.style.display = 'none';
    }
}

function closeRelationsPanel() {
    document.getElementById('relationsPanel').style.display = 'none';
    // Switch back to roles tab
    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
    document.querySelector('.tab').classList.add('active');
    document.getElementById('rolesTab').style.display = 'block';
    document.getElementById('relationsTab').style.display = 'none';
}

async function initRelations8Dir() {
    const container = document.getElementById('tileNodesContainer');
    container.innerHTML = '';
    
    // Fetch all 8-directional relations
    allRelations8 = {};
    for (let i = 0; i < tiles.length; i++) {
        const resp = await fetch(`/get_relations8/${i}`);
        allRelations8[i] = await resp.json();
    }
    
    // Create tile nodes with 8 direction connectors
    tiles.forEach((t, i) => {
        const node = document.createElement('div');
        node.className = 'dir-node';
        
        // Center tile image
        const tileImg = document.createElement('div');
        tileImg.className = 'tile-img';
        tileImg.style.backgroundImage = `url(data:image/png;base64,${t.img})`;
        tileImg.title = `Tile ${i} (${t.role})`;
        tileImg.onclick = () => {
            document.querySelectorAll('.dir-node .tile-img').forEach(el => el.classList.remove('selected'));
            tileImg.classList.add('selected');
            currentRelTile = i;
            updateConnectorStates(node, i);
        };
        if (i === currentRelTile) tileImg.classList.add('selected');
        node.appendChild(tileImg);
        
        // Create 8 direction connectors
        DIRECTIONS.forEach(dir => {
            const conn = document.createElement('div');
            conn.className = `dir-connector ${dir}`;
            conn.title = `${dir} direction`;
            conn.textContent = dir.length === 1 ? dir : '';
            conn.onclick = () => openDirectionPanel(i, dir);
            node.appendChild(conn);
        });
        
        // Label
        const label = document.createElement('div');
        label.className = 'dir-label';
        label.textContent = `#${i}`;
        node.appendChild(label);
        
        container.appendChild(node);
        
        // Update connector visual states
        updateConnectorStates(node, i);
    });
}

function updateConnectorStates(node, tileIdx) {
    const rels = allRelations8[tileIdx] || {};
    DIRECTIONS.forEach(dir => {
        const conn = node.querySelector(`.dir-connector.${dir}`);
        if (!conn) return;
        
        conn.classList.remove('has-allowed', 'has-forbidden', 'has-both', 'active');
        const dirRels = rels[dir] || {allowed: [], forbidden: []};
        const hasAllowed = dirRels.allowed && dirRels.allowed.length > 0;
        const hasForbidden = dirRels.forbidden && dirRels.forbidden.length > 0;
        
        if (hasAllowed && hasForbidden) conn.classList.add('has-both');
        else if (hasAllowed) conn.classList.add('has-allowed');
        else if (hasForbidden) conn.classList.add('has-forbidden');
        
        if (tileIdx === currentRelTile && dir === currentDirection) {
            conn.classList.add('active');
        }
    });
}

function openDirectionPanel(tileIdx, direction) {
    currentRelTile = tileIdx;
    currentDirection = direction;
    
    document.getElementById('dirPanelDir').textContent = direction;
    document.getElementById('dirPanelTile').textContent = tileIdx;
    document.getElementById('directionPanel').style.display = 'block';
    
    // Highlight active connector
    document.querySelectorAll('.dir-connector').forEach(c => c.classList.remove('active'));
    const nodes = document.querySelectorAll('.dir-node');
    nodes.forEach((node, i) => {
        if (i === tileIdx) {
            node.querySelector('.tile-img').classList.add('selected');
            node.querySelector(`.dir-connector.${direction}`).classList.add('active');
        } else {
            node.querySelector('.tile-img').classList.remove('selected');
        }
    });
    
    renderDirTiles();
}

function renderDirTiles() {
    const container = document.getElementById('dirTilesContainer');
    container.innerHTML = '';
    
    const rels = allRelations8[currentRelTile] || {};
    const dirRels = rels[currentDirection] || {allowed: [], forbidden: []};
    
    tiles.forEach((t, i) => {
        const tile = document.createElement('div');
        tile.className = 'dir-tile';
        tile.style.backgroundImage = `url(data:image/png;base64,${t.img})`;
        tile.title = `Tile ${i} (${t.role}) - Left click: Allow, Right click: Forbid`;
        
        if (dirRels.allowed && dirRels.allowed.includes(i)) tile.classList.add('allowed');
        if (dirRels.forbidden && dirRels.forbidden.includes(i)) tile.classList.add('forbidden');
        
        // Left click = allow
        tile.onclick = async () => {
            await fetch('/toggle_relation8', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({source: currentRelTile, target: i, direction: currentDirection, type: 'allowed'})
            });
            await refreshRelations(currentRelTile);
            renderDirTiles();
            updateAllConnectorStates();
        };
        
        // Right click = forbid
        tile.oncontextmenu = async (e) => {
            e.preventDefault();
            await fetch('/toggle_relation8', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({source: currentRelTile, target: i, direction: currentDirection, type: 'forbidden'})
            });
            await refreshRelations(currentRelTile);
            renderDirTiles();
            updateAllConnectorStates();
        };
        
        container.appendChild(tile);
    });
}

async function refreshRelations(tileIdx) {
    const resp = await fetch(`/get_relations8/${tileIdx}`);
    allRelations8[tileIdx] = await resp.json();
}

function updateAllConnectorStates() {
    const nodes = document.querySelectorAll('.dir-node');
    nodes.forEach((node, i) => updateConnectorStates(node, i));
}

async function autoRelations8Dir() {
    await fetch('/auto_relations8', {method: 'POST'});
    status('Auto-set relations for all directions');
    initRelations8Dir();
}

function clearAllRelations() {
    fetch('/clear_relations', {method: 'POST'}).then(() => {
        status('Cleared all relations');
        initRelations8Dir();
    });
}

function toggleRelation(target, type) {
    if (selTile < 0) return alert('Select a tile first');
    fetch('/toggle_relation', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({source: selTile, target: target, type: type})
    }).then(() => initRelationCanvas());
}

function autoRelations() {
    fetch('/auto_relations', {method: 'POST'}).then(r => r.json()).then(d => {
        status(d.message);
        initRelationCanvas();
    });
}

function clearAllRelations() {
    fetch('/clear_relations', {method: 'POST'}).then(() => {
        status('Cleared all relations');
        initRelationCanvas();
    });
}

// Generate
async function generate() {
    if (tiles.length === 0) return alert('Slice tiles first');
    const resp = await fetch('/generate', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({
            preset: document.getElementById('preset').value,
            width: parseInt(document.getElementById('mapW').value),
            height: parseInt(document.getElementById('mapH').value)
        })
    });
    const data = await resp.json();
    
    const mapCanvas = document.getElementById('mapCanvas');
    const mctx = mapCanvas.getContext('2d');
    const mapImg = new Image();
    mapImg.onload = () => {
        mapCanvas.width = mapImg.width;
        mapCanvas.height = mapImg.height;
        mctx.imageSmoothingEnabled = false;
        mctx.drawImage(mapImg, 0, 0);
    };
    mapImg.src = 'data:image/png;base64,' + data.image;
    status('Map generated!');
}

function exportJSON() { window.location = '/export'; }
function status(msg) { document.getElementById('status').textContent = '✅ ' + msg; }
</script>
</body>
</html>
'''

# ============================================================================
# ROUTES
# ============================================================================

@app.route('/')
def index():
    return render_template_string(HTML)

@app.route('/slice', methods=['POST'])
def slice_tileset():
    try:
        file = request.files['file']
        tw = int(request.form.get('tw', 16))
        th = int(request.form.get('th', 16))
        sx = int(request.form.get('sx', 0))
        sy = int(request.form.get('sy', 0))
        ox = int(request.form.get('ox', 0))
        oy = int(request.form.get('oy', 0))
        
        img = Image.open(file).convert('RGBA')
        state.tileset_image = img
        state.tile_width = tw
        state.tile_height = th
        state.spacing_x = sx
        state.spacing_y = sy
        state.offset_x = ox
        state.offset_y = oy
        state.tile_images = []
        state.tile_roles = []
        
        step_x = tw + sx
        step_y = th + sy
        
        tiles_data = []
        y = oy
        while y + th <= img.height:
            x = ox
            while x + tw <= img.width:
                tile = img.crop((x, y, x + tw, y + th))
                state.tile_images.append(tile)
                state.tile_roles.append("empty")
                
                buf = io.BytesIO()
                tile.save(buf, 'PNG')
                tiles_data.append({'img': base64.b64encode(buf.getvalue()).decode(), 'role': 'empty'})
                x += step_x
            y += step_y
        
        return jsonify({'tiles': tiles_data})
    except Exception as e:
        return jsonify({'error': str(e)})

@app.route('/set_role', methods=['POST'])
def set_role():
    data = request.json
    idx = data['idx']
    if 0 <= idx < len(state.tile_roles):
        state.tile_roles[idx] = data['role']
    return jsonify({'ok': True})

@app.route('/set_roles_batch', methods=['POST'])
def set_roles_batch():
    """Set role for multiple tiles at once."""
    data = request.json
    indices = data.get('indices', [])
    role = data.get('role', 'empty')
    for idx in indices:
        if 0 <= idx < len(state.tile_roles):
            state.tile_roles[idx] = role
    return jsonify({'ok': True, 'count': len(indices)})

@app.route('/get_relations8/<int:idx>')
def get_relations8(idx):
    """Get 8-directional relations for a tile."""
    rel = state.tile_relations[idx]
    result = {}
    for direction in DIRECTIONS:
        dir_rel = rel.get(direction, {"allowed": set(), "forbidden": set()})
        result[direction] = {
            'allowed': list(dir_rel.get('allowed', set())),
            'forbidden': list(dir_rel.get('forbidden', set()))
        }
    return jsonify(result)

@app.route('/toggle_relation8', methods=['POST'])
def toggle_relation8():
    """Toggle a relation for a specific direction."""
    data = request.json
    source = data['source']
    target = data['target']
    direction = data['direction']
    rel_type = data['type']
    
    if direction not in DIRECTIONS:
        return jsonify({'error': 'Invalid direction'}), 400
    
    rel = state.tile_relations[source][direction]
    if target in rel[rel_type]:
        rel[rel_type].remove(target)
    else:
        rel[rel_type].add(target)
        # Remove from opposite
        opposite = 'forbidden' if rel_type == 'allowed' else 'allowed'
        rel[opposite].discard(target)
    
    return jsonify({'ok': True})

@app.route('/auto_relations8', methods=['POST'])
def auto_relations8():
    """Auto-set relations based on roles for all 8 directions."""
    for i, role_i in enumerate(state.tile_roles):
        # Reset all directions
        state.tile_relations[i] = {d: {"allowed": set(), "forbidden": set()} for d in DIRECTIONS}
        for j, role_j in enumerate(state.tile_roles):
            if role_i == role_j:
                # Same role tiles can be neighbors in all directions
                for d in DIRECTIONS:
                    state.tile_relations[i][d]['allowed'].add(j)
    return jsonify({'message': f'Auto-set 8-dir relations for {len(state.tile_images)} tiles'})

# Legacy routes for backward compatibility
@app.route('/get_relations/<int:idx>')
def get_relations(idx):
    rel = state.tile_relations[idx]
    # Return flattened version for legacy
    all_allowed = set()
    all_forbidden = set()
    for d in DIRECTIONS:
        dir_rel = rel.get(d, {"allowed": set(), "forbidden": set()})
        all_allowed.update(dir_rel.get('allowed', set()))
        all_forbidden.update(dir_rel.get('forbidden', set()))
    return jsonify({
        'allowed': list(all_allowed),
        'forbidden': list(all_forbidden)
    })

@app.route('/toggle_relation', methods=['POST'])
def toggle_relation():
    # Legacy: apply to all directions
    data = request.json
    source = data['source']
    target = data['target']
    rel_type = data['type']
    
    for direction in DIRECTIONS:
        rel = state.tile_relations[source][direction]
        if target in rel[rel_type]:
            rel[rel_type].remove(target)
        else:
            rel[rel_type].add(target)
            opposite = 'forbidden' if rel_type == 'allowed' else 'allowed'
            rel[opposite].discard(target)
    
    return jsonify({'ok': True})

@app.route('/auto_relations', methods=['POST'])
def auto_relations():
    return auto_relations8()

@app.route('/clear_relations', methods=['POST'])
def clear_relations():
    for i in range(len(state.tile_images)):
        state.tile_relations[i] = {d: {"allowed": set(), "forbidden": set()} for d in DIRECTIONS}
    return jsonify({'ok': True})

def wfc_generate():
    """Wave Function Collapse using 8-directional tile relations."""
    if not state.tile_images:
        return
    
    height, width = state.map_height, state.map_width
    possible = [[set(range(len(state.tile_images))) for _ in range(width)] for _ in range(height)]
    state.map_data = np.full((height, width), -1, dtype=int)
    state.map_roles = np.full((height, width), "empty", dtype=object)
    
    def get_allowed_for_direction(tile_idx, direction):
        """Get allowed tiles for a specific direction from this tile."""
        rel = state.tile_relations[tile_idx]
        dir_rel = rel.get(direction, {"allowed": set(), "forbidden": set()})
        allowed = dir_rel.get("allowed", set())
        forbidden = dir_rel.get("forbidden", set())
        if allowed:
            return allowed - forbidden
        return set(range(len(state.tile_images))) - forbidden
    
    # Collapse all cells
    for _ in range(width * height * 2):
        min_e, min_cell = float('inf'), None
        for y in range(height):
            for x in range(width):
                if state.map_data[y, x] == -1 and len(possible[y][x]) < min_e:
                    min_e = len(possible[y][x])
                    min_cell = (x, y)
        
        if min_cell is None:
            break
        
        x, y = min_cell
        if not possible[y][x]:
            tile = random.randint(0, len(state.tile_images) - 1)
        else:
            tile = random.choice(list(possible[y][x]))
        
        state.map_data[y, x] = tile
        state.map_roles[y, x] = state.tile_roles[tile]
        
        # Propagate to all 8 neighbors using directional relations
        for direction, (dx, dy) in DIR_OFFSETS.items():
            nx, ny = x + dx, y + dy
            if 0 <= nx < width and 0 <= ny < height and state.map_data[ny, nx] == -1:
                allowed = get_allowed_for_direction(tile, direction)
                possible[ny][nx] &= allowed
    
    # Fill remaining
    for y in range(height):
        for x in range(width):
            if state.map_data[y, x] == -1:
                tile = random.randint(0, len(state.tile_images) - 1)
                state.map_data[y, x] = tile
                state.map_roles[y, x] = state.tile_roles[tile]



@app.route('/generate', methods=['POST'])
def generate():
    data = request.json
    state.map_width = data.get('width', 30)
    state.map_height = data.get('height', 20)
    preset = data.get('preset', 'sewer')
    
    if preset == 'wfc':
        wfc_generate()
    elif preset == 'sewer':
        generate_bsp(min_room=4, max_room=8, corridor=2)
    elif preset == 'office':
        generate_bsp(min_room=6, max_room=12, corridor=2)
    elif preset == 'caves':
        generate_caves(fill=0.48, iterations=5)
    
    return jsonify({'image': get_map_b64()})

@app.route('/export')
def export():
    if state.map_data is None:
        return "No map", 400
    
    data = {
        'width': state.map_width,
        'height': state.map_height,
        'tiles': state.map_data.tolist(),
        'roles': state.map_roles.tolist()
    }
    buf = io.BytesIO()
    buf.write(json.dumps(data, indent=2).encode())
    buf.seek(0)
    return send_file(buf, mimetype='application/json', as_attachment=True, download_name='map.json')

if __name__ == '__main__':
    print("\n" + "="*40)
    print("🗺️  MAP GENERATOR")
    print("="*40)
    print("Open: http://localhost:5000\n")
    app.run(debug=False, port=5000)
