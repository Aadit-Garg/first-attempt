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
    tile_relations = defaultdict(lambda: {"allowed": set(), "forbidden": set()})
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
        .rel-tiles { display: flex; flex-wrap: wrap; gap: 2px; max-height: 80px; overflow-y: auto; background: #0a0a0a; padding: 4px; border-radius: 3px; }
        .rel-tile { width: 24px; height: 24px; border: 2px solid #333; cursor: pointer; background-size: contain; }
        .rel-tile.allowed { border-color: #2ecc71; box-shadow: 0 0 3px #2ecc71; }
        .rel-tile.forbidden { border-color: #e74c3c; box-shadow: 0 0 3px #e74c3c; }
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
                    <label>Role:</label>
                    <select id="role">
                        <option>floor</option><option>wall</option><option>empty</option>
                        <option>decoration</option><option>water</option><option>door</option>
                        <option>spawn</option><option>exit</option>
                    </select>
                    <span class="info">(click tile to assign)</span>
                    <div id="tilesContainer" class="tiles">Load tileset first</div>
                </div>
                
                <div id="relationsTab" style="display: none;">
                    <div class="info">Select tile above, then click below to set neighbors</div>
                    <div style="font-size: 11px;">Selected: <span id="selTileInfo">None</span></div>
                    <div style="margin: 5px 0;">
                        <span style="color:#2ecc71;">✓ Allowed:</span>
                        <button onclick="autoRelations()" style="padding:2px 6px;font-size:10px;">Auto (same role)</button>
                    </div>
                    <div id="allowedTiles" class="rel-tiles"></div>
                    <div style="margin: 5px 0; color:#e74c3c;">✗ Forbidden:</div>
                    <div id="forbiddenTiles" class="rel-tiles"></div>
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

<script>
// State
let img = null;
let zoom = 1;
let panX = 0, panY = 0;
let tiles = [];
let selTile = 0;

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
    gctx.strokeStyle = 'rgba(0,255,255,0.7)';
    gctx.lineWidth = 1;
    
    const stepX = (v.tw + v.sx) * zoom;
    const stepY = (v.th + v.sy) * zoom;
    const tw = v.tw * zoom;
    const th = v.th * zoom;
    const ox = v.ox * zoom;
    const oy = v.oy * zoom;
    
    for (let x = ox; x < grid.width; x += stepX) {
        gctx.beginPath();
        gctx.moveTo(x, 0); gctx.lineTo(x, grid.height);
        gctx.moveTo(x + tw, 0); gctx.lineTo(x + tw, grid.height);
        gctx.stroke();
    }
    for (let y = oy; y < grid.height; y += stepY) {
        gctx.beginPath();
        gctx.moveTo(0, y); gctx.lineTo(grid.width, y);
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
        d.className = 'tile' + (i === selTile ? ' sel' : '');
        d.style.backgroundImage = `url(data:image/png;base64,${t.img})`;
        d.style.backgroundColor = roleColor(t.role);
        d.title = `#${i}: ${t.role}`;
        d.onclick = () => {
            selTile = i;
            const role = document.getElementById('role').value;
            fetch('/set_role', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({idx: i, role: role})
            }).then(r => r.json()).then(d => {
                tiles[i].role = role;
                renderTiles();
                status(`Tile ${i} → ${role}`);
            });
        };
        c.appendChild(d);
    });
}

function roleColor(r) {
    const c = {empty:'#333',floor:'#8b7355',wall:'#4a4a4a',decoration:'#6b8e23',water:'#4682b4',door:'#cd853f',spawn:'#32cd32',exit:'#f45'};
    return c[r] || '#333';
}

// Tabs
function showTab(tab) {
    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
    event.target.classList.add('active');
    document.getElementById('rolesTab').style.display = tab === 'roles' ? 'block' : 'none';
    document.getElementById('relationsTab').style.display = tab === 'relations' ? 'block' : 'none';
    if (tab === 'relations') renderRelationTiles();
}

function renderRelationTiles() {
    const allowed = document.getElementById('allowedTiles');
    const forbidden = document.getElementById('forbiddenTiles');
    allowed.innerHTML = '';
    forbidden.innerHTML = '';
    
    document.getElementById('selTileInfo').textContent = selTile >= 0 ? `#${selTile}` : 'None';
    
    tiles.forEach((t, i) => {
        // Allowed
        const a = document.createElement('div');
        a.className = 'rel-tile';
        a.style.backgroundImage = `url(data:image/png;base64,${t.img})`;
        a.title = `Tile ${i}`;
        a.onclick = () => toggleRelation(i, 'allowed');
        allowed.appendChild(a);
        
        // Forbidden
        const f = document.createElement('div');
        f.className = 'rel-tile';
        f.style.backgroundImage = `url(data:image/png;base64,${t.img})`;
        f.title = `Tile ${i}`;
        f.onclick = () => toggleRelation(i, 'forbidden');
        forbidden.appendChild(f);
    });
    
    // Fetch and highlight current relations
    if (selTile >= 0) {
        fetch(`/get_relations/${selTile}`).then(r => r.json()).then(data => {
            document.querySelectorAll('#allowedTiles .rel-tile').forEach((el, i) => {
                el.classList.toggle('allowed', data.allowed.includes(i));
            });
            document.querySelectorAll('#forbiddenTiles .rel-tile').forEach((el, i) => {
                el.classList.toggle('forbidden', data.forbidden.includes(i));
            });
        });
    }
}

function toggleRelation(target, type) {
    if (selTile < 0) return alert('Select a tile first');
    fetch('/toggle_relation', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({source: selTile, target: target, type: type})
    }).then(() => renderRelationTiles());
}

function autoRelations() {
    fetch('/auto_relations', {method: 'POST'}).then(r => r.json()).then(d => {
        status(d.message);
        renderRelationTiles();
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

@app.route('/get_relations/<int:idx>')
def get_relations(idx):
    rel = state.tile_relations[idx]
    return jsonify({
        'allowed': list(rel['allowed']),
        'forbidden': list(rel['forbidden'])
    })

@app.route('/toggle_relation', methods=['POST'])
def toggle_relation():
    data = request.json
    source = data['source']
    target = data['target']
    rel_type = data['type']
    
    rel = state.tile_relations[source]
    if target in rel[rel_type]:
        rel[rel_type].remove(target)
    else:
        rel[rel_type].add(target)
        # Remove from opposite
        opposite = 'forbidden' if rel_type == 'allowed' else 'allowed'
        rel[opposite].discard(target)
    
    return jsonify({'ok': True})

@app.route('/auto_relations', methods=['POST'])
def auto_relations():
    for i, role_i in enumerate(state.tile_roles):
        state.tile_relations[i] = {"allowed": set(), "forbidden": set()}
        for j, role_j in enumerate(state.tile_roles):
            if role_i == role_j:
                state.tile_relations[i]['allowed'].add(j)
    return jsonify({'message': f'Auto-set relations for {len(state.tile_images)} tiles'})

def wfc_generate():
    """Wave Function Collapse using tile relations."""
    if not state.tile_images:
        return
    
    height, width = state.map_height, state.map_width
    possible = [[set(range(len(state.tile_images))) for _ in range(width)] for _ in range(height)]
    state.map_data = np.full((height, width), -1, dtype=int)
    state.map_roles = np.full((height, width), "empty", dtype=object)
    
    def get_allowed(tile_idx):
        rel = state.tile_relations[tile_idx]
        if rel["allowed"]:
            return rel["allowed"] - rel["forbidden"]
        return set(range(len(state.tile_images))) - rel["forbidden"]
    
    # Collapse all cells
    for _ in range(width * height * 2):
        # Find cell with lowest entropy
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
        
        # Propagate to neighbors
        allowed = get_allowed(tile)
        for dx, dy in [(0, -1), (0, 1), (-1, 0), (1, 0)]:
            nx, ny = x + dx, y + dy
            if 0 <= nx < width and 0 <= ny < height and state.map_data[ny, nx] == -1:
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
