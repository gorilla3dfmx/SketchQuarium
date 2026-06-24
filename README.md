# SketchQuarium

Ein kleines Spiel/Experiment, in dem man Aquariumselemente – **Fische, Quallen,
Pflanzen und Korallen** – selbst zeichnet und sie anschließend als animierte
3D-Objekte in einer Aquariumsszene platziert.

Gebaut mit **Delphi / FireMonkey (FMX)** und der **[Gorilla3D](https://gorilla3d.de)**
Engine.

---

## Idee

1. Im Editor zeichnet man ein Aquariumselement und wählt seine Art.
2. Die Zeichnung wird als Textur auf ein subdivisioniertes `TGorillaPlane` gelegt
   (`TGorillaBlinnMaterialSource`, Zeichnung in `Texture0`).
3. Das Plane wird **art-typisch animiert** (Fisch schwimmt, Qualle pulsiert,
   Pflanze/Koralle schwingt).
4. Gespeicherte Elemente lassen sich aus einer Liste auswählen und per Maus im
   Aquarium platzieren.

---

## Voraussetzungen

- **RAD Studio / Delphi 11 (Alexandria)** oder neuer (das Projekt ist für den
  Compiler 35.0 / Win64 konfiguriert).
- Das **Gorilla3D**-Package muss in der IDE installiert sein
  (`Gorilla3D_Delphi_13_0_0_Florence`) und auf dem Bibliothekspfad liegen.
- Plattform: **Win64** (aktive Konfiguration: `Release`).

---

## Bauen & Starten

In der IDE öffnen und kompilieren:

```
Drawquarium.dproj  ->  Projekt öffnen  ->  Run (F9)
```

> **Hinweis zum Kommandozeilen-Build:** Da Gorilla3D als IDE-installiertes
> Package eingebunden wird, lässt sich das Projekt am zuverlässigsten direkt aus
> RAD Studio bauen. Ein reiner `dcc64`/MSBuild-Lauf benötigt zusätzlich die
> passenden Package-DCP-/DCU-Pfade.

---

## Bedienung

### Editor öffnen
Der Stift-Button (✎) in der linken Werkzeugleiste blendet den Editor (Popup) ein
und aus.

### Zeichnen
- **Mitte:** Zeichenfläche (transparenter Hintergrund – transparente Bereiche
  bleiben später im 3D-Objekt transparent).
- **Rechts:** Art (Fisch/Qualle/Pflanze/Koralle), Name, Farbpalette,
  Pinselgröße, *Radierer*, *Leeren*, *Übernehmen & Speichern*.

### Gespeicherte Elemente (linke Spalte)
- Liste mit **Vorschau-Thumbnails**.
- **In Aquarium platzieren** – startet den Platzierungsmodus.
- **Zum Bearbeiten laden** – lädt Zeichnung, Art und Name zurück in den Editor.
- **Mit Zeichnung aktualisieren** – überschreibt das gewählte Element.
- **Löschen** – entfernt das Element (Datei + Eintrag).

### Platzierungsmodus
- Eine **Vorschau** folgt dem Mauszeiger innerhalb der Aquariumsgrenzen.
- **Linksklick** platziert eine Instanz (und erlaubt sofort die nächste).
- **Mausrad** stellt die Größe ein (gilt auch für die folgenden Instanzen).
- **Rechtsklick** beendet den Platzierungsmodus.
- Die Maus-Events sind nur im Platzierungsmodus aktiv – sonst bleibt die
  Design-Kamera-Navigation der Viewport voll nutzbar.
- **Fische/Quallen** schweben frei (vertikale Ebene), **Pflanzen/Korallen**
  bekommen Bodenkontakt: sie sitzen auf dem Boden oder auf der Oberfläche des
  Stein-Modells (Raycast).

---

## Projektstruktur

| Datei                     | Inhalt                                                            |
|---------------------------|-------------------------------------------------------------------|
| `Drawquarium.dpr`         | Programm-Einstiegspunkt                                           |
| `Unit1.pas` / `Unit1.fmx` | Hauptformular, 3D-Szene, Editor-UI (im Code), Platzierungsmodus  |
| `Aquarium.Elements.pas`   | Elementarten, Persistenz (`TAquariumLibrary`), Szene & Animation (`TAquariumScene`) |
| `assets/`                 | Texturen (Boden, Wasser, Himmel) und 3D-Modelle (Rock, Octopus)  |
| `package.zip`             | Eingebettete Modell-Ressourcen (vom `TGorillaAssetsManager`)     |

### Wichtige Klassen (`Aquarium.Elements.pas`)

- **`TAquariumKind`** – `akFish`, `akJellyfish`, `akPlant`, `akCoral`.
- **`TAquariumElement`** – ein gespeichertes Element (Name, Art, Bitmap/Datei).
- **`TAquariumLibrary`** – Speichern/Laden, Aktualisieren, Löschen.
- **`TSpawnedElement`** – eine platzierte, animierte Instanz (kennt ihre
  Ruhelage-Vertices; `Frozen` = Vorschau folgt der Maus).
- **`TAquariumScene`** – erzeugt die Planes, treibt die Animation, entfernt
  Instanzen.

---

## Speicherort der Elemente

Gezeichnete Elemente werden im Dokumente-Ordner abgelegt:

```
Dokumente\Drawquarium\elements\
    *.png              (eine PNG-Datei je Element, mit Alpha-Kanal)
    elements.idx       (Manifest: art|name|datei  je Zeile)
```

Beim Programmstart wird das Manifest gelesen und alle Elemente werden geladen.

---

## Technische Hinweise

- **Geometrie:** `TGorillaPlane` mit 24×24 Subdivisions. Nach dem Aufbau ist ein
  Plane statisch; für die Live-Vertex-Animation wird es mit `IsStatic := False`
  dynamisch gemacht (die Vertices werden aus der MeshDef zurück in die MeshData
  kopiert und pro Frame verformt).
- **Material:** `TGorillaBlinnMaterialSource`, Zeichnung als `Texture` (Texture0).
  Beleuchtung/Specular sind aus (Sprite-Look in Originalfarben).
- **Transparenz:** Das Plane wird mit `Opaque := False` gerendert; transparente
  Texturbereiche bleiben transparent (statt schwarz).
- **Animation:** Ein `TTimer` (~60 fps) verformt die Vertices art-typisch:
  - *Fisch* – Wanderwelle entlang X + sanftes Schwimmen
  - *Qualle* – pulsierende Glocke + Auf-/Abtreiben
  - *Pflanze* – an der Wurzel fixiert, schwingt nach oben zunehmend
  - *Koralle* – wie Pflanze, aber steifer
- **Maus → 3D:** Sichtstrahl aus `ScreenToWorld` + `Kamera.AbsolutePosition`,
  geschnitten mit einer Ebene (Z=0 für Wasser, Y=6.5 für den Boden) bzw.
  `PickTriangle` gegen das Stein-Modell für Oberflächenplatzierung.

---

## Bekannte Einschränkungen / Ideen

- Der Boden wird beim Platzieren als flache Ebene (Y=6.5) behandelt, nicht per
  Mesh-Raycast (der Ground hat 256×256 Subdivisions). Bei echtem
  Höhen-Relief könnten Pflanzen leicht schweben/einsinken.
- Platzierte Fische driften animationsbedingt um ihren Platzierungspunkt; ganz am
  Rand platziert können sie leicht durch die Scheibe schwimmen.
- Mögliche Erweiterungen: Tiefe beim Platzieren variieren, platzierte Elemente
  nachträglich verschieben/löschen, echte Schwimmpfade, Wölbung der Planes.

---

## Szene

Das Aquarium enthält bereits Glaswände, eine Wasseroberfläche mit
Refraktion/Reflexion und Unterwasser-Pass, Kaustik, einen Boden, ein
Stein-Modell und ein animiertes Octopus-Modell. Die selbst gezeichneten Elemente
werden zusätzlich in diese Szene eingefügt.
