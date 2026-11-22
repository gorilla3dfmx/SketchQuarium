# SketchQuarium

A small game/experiment in which you draw your own aquarium elements – **fish,
jellyfish, plants and corals** – and then place them as animated 3D objects in
an aquarium scene. Fish swim in schools, get hungry and have to be fed.

Built with **Delphi / FireMonkey (FMX)** and the **[Gorilla3D](https://gorilla3d.de)**
framework.

---

## Idea

1. In the editor you draw an aquarium element (freehand or by colouring in an
   SVG stencil) and choose its kind.
2. The drawing is stored as a template in a Gorilla3D inventory
   (`TGorillaInventory`) and is used as the texture of a subdivided quad mesh.
3. The element is **animated according to its kind** (fish wiggles, jellyfish
   pulses, plant/coral sways) and – for fish and jellyfish – moves freely
   through the tank.
4. Templates can be picked from the editor list or the inventory catalog and
   placed in the aquarium with the mouse.
5. The complete aquarium (templates + placed instances) can be saved to and
   loaded from an XML file.

---

## Requirements

- **RAD Studio / Delphi 11.3 (Alexandria) up to 13.2 (Florence)** – the version
  range currently supported by Gorilla3D. The project file is maintained with
  Delphi 13.
- **Gorilla3D framework 1.5.5 or newer**, installed in the IDE and available on
  the library path (e.g. package `Gorilla3D_Delphi_13_0_0_Florence` for
  Delphi 13).
- **Skia4Delphi** (part of RAD Studio since 12) – used to render the SVG
  stencils in the editor.
- Platforms: **Win64** (default configuration: `Release`) and **Linux64**.
- Runtime libraries next to the executable (included in the repository):
  `fmodL64.dll` (FMOD audio), `Jolt64.dll` (Jolt physics),
  `shaderc_shared.dll` (shader compiler), `sk4d.dll` (Skia).

> **Note:** The user interface of the application is in German.

---

## Build & Run

Open and compile in the IDE:

```
SketchQuarium.dproj  ->  Open project  ->  Run (F9)
```

The executable is written to the project root, so the `assets/` folder and the
runtime DLLs are found next to it.

Command-line build (example for RAD Studio 13 / BDS 37.0):

```
call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"
msbuild SketchQuarium.dproj /t:Build /p:Config=Release /p:Platform=Win64
```

For **Linux64**, deploy via the IDE (PAServer); `SketchQuarium.deployproj`
contains the required assets and libraries.

---

## Usage

### Toolbar (left)

| Button | Function                                                  |
|--------|-----------------------------------------------------------|
| ✎      | Show/hide the drawing editor                              |
| 🌯     | Feeding mode on/off                                       |
| ☰      | Show/hide the inventory catalog (available templates)     |
| 💾     | Save the aquarium setup (XML)                             |
| 📂     | Load an aquarium setup (XML)                              |

### Drawing
- **Center:** Drawing canvas (transparent background – transparent areas stay
  transparent in the resulting 3D object).
- **Right:** Kind (fish/jellyfish/plant/coral), name, colour palette, brush
  type (normal, very soft, extra soft, elongated), brush size, *Eraser*,
  *Clear*, *Apply & save*.
- **Stencils:** For each kind, SVG silhouettes from `assets/shapes/<kind>/` are
  offered. A selected stencil restricts strokes to its shape; *Freehand*
  removes the restriction.

### Saved elements (left column of the editor)
- List with **preview thumbnails**.
- **Place in aquarium** – starts placement mode.
- **Load for editing** – loads drawing, kind and name back into the editor.
- **Update with drawing** – overwrites the selected element.
- **Delete** – removes the element (PNG file + inventory entry).

### Inventory catalog
Shows all templates as clickable tiles; a click starts placement mode for that
template.

### Placement mode
- A **preview** follows the mouse cursor within the aquarium bounds.
- **Left click** places an instance (and immediately allows the next one).
- **Mouse wheel** adjusts the size (also applies to subsequent instances).
- **Right click** ends placement mode.
- Mouse events are only taken over during placement – otherwise the viewport's
  design camera navigation remains fully usable.
- **Fish/jellyfish** are placed on a vertical plane and then move freely;
  **plants/corals** get ground contact: they sit on the terrain or on the rock
  model (triangle raycast).

### Feeding
- In feeding mode a **left click** on the water surface drops a food pellet
  (with a ripple on the water); **right click** ends the mode.
- Pellets sink to the ground and dissolve after a while if not eaten.
- Fish lose health over time. Hungry fish pulse, critically hungry fish blink;
  starved fish float to the surface and disappear. Eating a pellet restores
  health and keeps a fish sated for a while.

---

## Project structure

| File                                   | Contents                                                       |
|----------------------------------------|----------------------------------------------------------------|
| `SketchQuarium.dpr`                    | Program entry point                                            |
| `Unit1.pas` / `Unit1.fmx`              | Main form: 3D scene, toolbar, feeding, save/load, asset paths  |
| `Aquarium.Elements.pas`                | Element kinds, inventory persistence, spawned instances, scene, swarm/feeding logic |
| `Aquarium.EditorFrame.pas` / `.fmx`    | Drawing editor as FMX frame (drawing, stencils, element list)  |
| `Aquarium.Placement.pas`               | Placement mode controller (preview, raycast, mouse handling)   |
| `Aquarium.InventoryUI.pas`             | Inventory catalog frame (template tiles)                       |
| `Aquarium.Theme.pas`                   | Dark "deep sea" colour scheme for the 2D UI                    |
| `assets/`                              | Textures, 3D models (rock, octopus), music/sounds, SVG stencils |
| `package.zip`                          | Embedded model resources (for `TGorillaAssetsManager`)         |
| `SketchQuarium-Presentation.*` / `-Praesentation.*` | Presentation slides (EN/DE, HTML + PDF)           |

### Key classes

- **`TAquariumKind`** – `akFish`, `akJellyfish`, `akPlant`, `akCoral`.
- **`TAquariumLibrary`** – manages the drawings as inventory templates
  (one group per kind); save/load, update, delete; saving/loading of complete
  setups.
- **`TSpawnedElement`** – a placed instance (`TGorillaModel`) with motion,
  health and an inventory collectable; `Frozen` = preview follows the mouse.
- **`TFoodPellet`** – a sinking food pellet (sphere with physics collider).
- **`TAquariumScene`** – creates instances from cached `TModelDef`s, drives
  movement, swarm behaviour and feeding, restores a scene from the inventory.
- **`TEditorFrame`**, **`TAquariumPlacement`**, **`TAquariumTemplateFrame`**,
  **`TAquaTheme`** – editor, placement mode, catalog and UI theme.

---

## Storage location

Templates are stored in the user's Documents folder (on Linux with a fallback
to the home or temp directory):

```
Documents\SketchQuarium\inventory\
    inventory.xml      (Gorilla3D inventory: groups, templates, instances)
    *.png              (one PNG file per template, with alpha channel)
```

The inventory is loaded on program start. Saved aquarium setups are separate
XML files at a location of your choice; they reference the PNG textures in the
inventory folder.

---

## Technical notes

- **Geometry:** Per template a `TModelDef` (subdivided quad, 24×24, as
  `TMeshDef` plus material and animation) is built once and shared by all
  instances; instances are created via `TGorillaModel.LoadNewModelFromDef`.
- **Two animation layers:**
  - *Self animation* (wiggle/pulse/sway) is baked as vertex animation
    (`TMeshInterpolatorDef`) into the model def and played by the framework.
    Fish additionally have a faster "fast" swim animation.
  - *Spatial movement* is integrated per frame: fish use a boids model
    (separation, alignment, cohesion within the same species, wandering, tank
    bounds, food seeking); jellyfish drift and bob.
- **Material:** `TGorillaBlinnMaterialSource` per instance with the drawing as
  texture, rendered non-opaque so transparent areas stay transparent.
- **Mouse → 3D:** View ray from `ScreenToWorld` + camera position, intersected
  with a plane, or `PickTriangle` against registered surfaces (terrain, rock).
- **Scene:** Glass walls, water surface with refraction/reflection and
  underwater pass, caustics, PBR sand terrain, rock and animated octopus models,
  bubble particle emitter, physics system (Jolt) and FMOD audio (music playlist
  and sound effects).

---

## Known limitations / ideas

- Placed fish move freely within the tank bounds; very close to the glass they
  may slightly clip through it.
- Possible extensions: vary depth during placement, move/delete placed
  instances afterwards, curvature of the planes, more stencils.
