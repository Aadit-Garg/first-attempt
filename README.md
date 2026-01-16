# The Spore Warden 🍄💀

![Godot Engine](https://img.shields.io/badge/Godot-4.x-478cbf?style=flat&logo=godot-engine&logoColor=white)
![Status](https://img.shields.io/badge/Status-Prototype-orange)
![License](https://img.shields.io/badge/License-MIT-green)

> "Survival is a limited resource. And the rent is due."

**The Spore Warden** is a top-down, 2D psychological survival horror game built in the **Godot Engine**. Drawing heavy inspiration from *Resident Evil 2*'s "Mr. X" mechanics and the visceral combat of *Hotline Miami*, this project focuses on resource management, stealth, and advanced enemy AI systems.

---

## 🎮 Technical Overview

This project utilizes **Godot 4.x** and is written primarily in **GDScript**. The architecture prioritizes modularity to handle complex AI states and dynamic lighting systems without compromising performance on lower-end hardware.

### Key Systems & Architecture

#### 1. The Stalker AI (The Warden)
The core antagonist utilizes a **Finite State Machine (FSM)** combined with Godot's `NavigationServer2D` for persistent tracking.
* **State Logic:** The Warden cycles between `Patrol`, `Investigate` (triggered by noise events), `Chase` (line-of-sight), and `Attack`.
* **Dynamic Pathfinding:** Uses A* navigation mesh baking at runtime to adapt to dynamic obstacles (e.g., locked doors or barricades).
* **Audio Propagation:** A custom `SoundManager` singleton emits "noise signals" with a coordinate and radius. If the Warden is within radius, the state switches to `Investigate`.

#### 2. Inventory & Resource Management
* **Grid-Based Data Structure:** Inventory is not just a list; it handles slot management for distinct item types (Ammo, Key Items, Consumables).
* **Save/Load System:** JSON serialization of player state and world flags to ensure persistent progression.

#### 3. Visuals & Rendering
* **Lighting:** extensive use of `PointLight2D` with shadow casting.
* **Shaders:** Custom fragment shaders are used for the "Toxic Green" environmental effects and the monochromatic "Red-Scale" cutscenes.
* **Sprite Animation:** `AnimationTree` nodes blend states for 8-directional movement to ensure smooth transitions between `Idle`, `Walk`, and `Shoot`.
