unit Aquarium.Elements;

{
  SketchQuarium - Aquariumselemente

  Diese Unit kapselt vier Dinge:
    1. TAquariumKind            - die Art eines Elements (Fisch, Qualle, ...)
    2. TAquariumLibrary         - das Speichern/Laden gezeichneter Elemente
                                  (PNG + Manifest im Dokumente-Ordner)
    3. TAquariumScene           - das Erzeugen platzierter Elemente in der Szene
    4. TSpawnedElement          - eine platzierte Instanz (TGorillaModel)

  Die 3D-Geometrie wird ueber den CustomMesh-Ansatz von Gorilla3D aufgebaut:
  je Art wird einmalig ein TModelDef erzeugt (unterteiltes Quad als TMeshDef,
  ein Material und eine Eigen-Animation). Aus diesem ModelDef wird beim Spawnen
  per TGorillaModel.LoadNewModelFromDef eine Instanz materialisiert.

  Wichtig - zwei getrennte Animationsebenen:
    * Die EIGEN-Animation (Wabbeln/Puls/Schwingen) steckt als gebackene
      Vertex-Animation (TMeshInterpolatorDef) im ModelDef und wird von der
      Engine abgespielt. Sie beschreibt nur die Deformation des Elements selbst.
    * Die RAUM-Bewegung (Schwimmen/Treiben) laeuft als eigenstaendige
      TPoint3DAnimation auf der Position des Models. Sie ist von der Wabbel-
      Animation entkoppelt, damit ein Element spaeter gezielt gesteuert werden
      kann (die Animation einfach stoppen/ersetzen). TSpawnedElement.Animate
      richtet nur noch die Blickrichtung an der Bewegungsrichtung aus.

  Die gezeichnete Textur ist pro Instanz verschieden und wird nach dem
  Materialisieren als MaterialSource (Blinn, nicht-opak) auf das Model gelegt.
}

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math,
  System.Math.Vectors, System.Generics.Collections, System.IOUtils, System.Rtti,
  FMX.Types, FMX.Graphics, FMX.Types3D, FMX.Controls3D, FMX.Materials, FMX.Ani,
  Gorilla.Viewport, Gorilla.Mesh, Gorilla.Model, Gorilla.DefTypes,
  Gorilla.Loader, Gorilla.Animation, Gorilla.AssetsManager,
  Gorilla.Material.Default, Gorilla.Sphere, Gorilla.Material.Lambert,
  Gorilla.Physics, Gorilla.Physics.Types, Gorilla.Utils.Inventory;

type
  /// <summary>Art eines Aquariumselements - bestimmt Aussehen und Animation.</summary>
  TAquariumKind = (akFish, akJellyfish, akPlant, akCoral);

  /// <summary>
  ///  Verwaltet alle gespeicherten Zeichnungs-Vorlagen ueber das Gorilla-
  ///  Inventory: jede Zeichnung ist ein TGorillaInventoryItemTemplate (Vorlage),
  ///  kategorisiert in eine Gruppe je Art. Die gezeichnete Textur haengt am
  ///  Template in dessen Data-Eigenschaft (TBitmap) und wird zusaetzlich als PNG
  ///  abgelegt; ein VisualItem haelt den Dateinamen fuer die Persistenz.
  ///  Das gesamte Inventar wird als XML im Dokumente-Ordner gespeichert.
  /// </summary>
  TAquariumLibrary = class
  private
    FInventory    : TGorillaInventory;
    FElementsDir  : String;
    FFilePath     : String;       // absoluter Pfad zur Inventar-XML
    procedure EnsureDirectories();
    procedure EnsureGroups();
    function  GroupForKind(AKind: TAquariumKind): TGorillaInventoryGroup;
    function  VisualFileOf(ATemplate: TGorillaInventoryItemTemplate): String;
    procedure LoadBitmaps();
    procedure FreeBitmaps();
    procedure SyncImageIndices();
  public
    constructor Create();
    destructor Destroy(); override;

    /// <summary>Laedt das Inventar-XML und die zugehoerigen PNG-Texturen.</summary>
    procedure LoadFromDisk();
    /// <summary>Schreibt das gesamte Inventar als XML in den Dokumente-Ordner.</summary>
    procedure SaveToDisk();

    /// <summary>
    ///  Speichert das komplette Aquarium (Vorlagen + Gruppen + platzierte
    ///  Instanzen/Collectables) in eine frei waehlbare Datei. Die Texturen
    ///  bleiben als PNG im Inventar-Ordner; die Datei verweist auf sie.
    /// </summary>
    procedure SaveSetupToFile(const APath: String);
    /// <summary>
    ///  Laedt ein zuvor gespeichertes Setup (Vorlagen + Instanzen) aus einer
    ///  Datei. Die enthaltenen Collectables bleiben erhalten, damit die Szene
    ///  daraus wieder aufgebaut werden kann (Texturen werden nachgeladen).
    /// </summary>
    procedure LoadSetupFromFile(const APath: String);

    /// <summary>Anzahl der gespeicherten Vorlagen.</summary>
    function  Count(): Integer;
    /// <summary>Vorlage an Position AIndex (Reihenfolge wie im Inventar).</summary>
    function  GetTemplate(AIndex: Integer): TGorillaInventoryItemTemplate;

    /// <summary>
    ///  Speichert eine Zeichnung als neue Vorlage (Template + VisualItem + PNG)
    ///  und gibt das neue Template zurueck.
    /// </summary>
    function  AddDrawing(AKind: TAquariumKind; const AName: String;
      ASource: TBitmap): TGorillaInventoryItemTemplate;

    /// <summary>
    ///  Ueberschreibt eine vorhandene Vorlage mit neuer Art, neuem Namen und
    ///  neuer Zeichnung (gleiche PNG-Datei).
    /// </summary>
    procedure UpdateDrawing(ATemplate: TGorillaInventoryItemTemplate;
      AKind: TAquariumKind; const AName: String; ASource: TBitmap);

    /// <summary>Loescht eine Vorlage samt PNG-Datei und Inventar-Eintrag.</summary>
    procedure DeleteDrawing(ATemplate: TGorillaInventoryItemTemplate);

    /// <summary>Das zugrunde liegende Inventar (Templates/Gruppen/Items).</summary>
    property Inventory : TGorillaInventory read FInventory;
  end;

  TFoodPellet = class;

  /// <summary>
  ///  Eine in der Szene platzierte Instanz eines Elements. Haelt das
  ///  TGorillaModel (mit laufender Eigen-Animation) und den Zustand der
  ///  pro-Frame integrierten Raumbewegung (Geschwindigkeit/Schwarm).
  /// </summary>
  TSpawnedElement = class
  private
    FModel     : TGorillaModel;
    FDef       : TModelDef;     // geteiltes ModelDef, aus dem FModel gebaut wurde (gehoert der Szene)
    FKind      : TAquariumKind;
    FCollectable : TGorillaInventoryCollectable; // Inventar-Instanz dieser Vorlage
    FSpeciesId : String;        // Identitaet fuer Schwarmbildung (gleiche Zeichnung)
    FBasePos   : TPoint3D;
    FBaseW     : Single;        // Grundbreite der Art (lokale Quad-Groesse)
    FBaseH     : Single;        // Grundhoehe der Art
    FScale     : Single;        // per Mausrad eingestellte Groesse
    FFrozen    : Boolean;
    FFastSwim  : Boolean;       // schaltet zwischen 'self'- und 'fast'-Wabbeln
    // --- Raumbewegung (Velocity-Integration / Boids) ---
    FVelocity  : TPoint3D;      // aktuelle Schwimmgeschwindigkeit (Welt/s)
    FWanderDir : TPoint3D;      // langsam rotierende Wunschrichtung (Streifen)
    FMaxSpeed  : Single;        // Hoechstgeschwindigkeit (variiert je Instanz)
    FPhase     : Single;        // Zeitversatz (z.B. Quallen-Bob)
    // --- Lebenspunkte (nur fuetterbare Tiere = Fische) ---
    FHealth    : Single;        // 0..FISH_HEALTH_MAX, sinkt mit der Zeit (Hunger)
    FSatedTime : Single;        // Restzeit "satt": Health bleibt solange auf Max
    FDead      : Boolean;       // verhungert -> treibt nach oben, wird entfernt
    FDeadTime  : Single;        // Sekunden seit dem Tod
    FTinted    : Boolean;       // Material ist gerade eingefaerbt (Hunger/Tod)
    FBaseAmb, FBaseDif, FBaseSpec : TAlphaColorF; // Original-Materialfarben
    FFoodTarget : TFoodPellet;  // zugeteilte Futterkapsel (nil = keine)
    procedure ApplyScale();
    procedure SetFrozen(const AValue: Boolean);
    procedure SetFastSwim(const AValue: Boolean);
    /// <summary>Initialisiert Geschwindigkeit/Richtung beim Loslassen (Frozen:=False).</summary>
    procedure StartMotion();
    /// <summary>Integriert eine Beschleunigung und richtet die Blickrichtung aus.</summary>
    procedure ApplyMotion(const AAccel: TPoint3D; ADt: Single);
  public
    constructor Create();

    /// <summary>Richtet nur die Blickrichtung an der Bewegungsrichtung aus.</summary>
    procedure Animate(ATime: Single);

    /// <summary>Setzt Basis- und aktuelle Position (z.B. fuer die Vorschau).</summary>
    procedure SetBasePosition(const APos: TPoint3D);

    /// <summary>Skaliert das Element gleichmaessig (1.0 = Ausgangsgroesse).</summary>
    procedure SetSizeScale(const AFactor: Single);

    /// <summary>Aktuelle Welthoehe (fuer Bodenkontakt bei der Platzierung).</summary>
    function  WorldHeight(): Single;

    property Model : TGorillaModel read FModel;
    property Kind  : TAquariumKind read FKind;
    /// <summary>
    ///  Die zugehoerige Inventar-Instanz (Collectable) dieser platzierten
    ///  Vorlage. Wird beim Spawn erzeugt und beim Entfernen wieder abgeworfen.
    /// </summary>
    property Collectable : TGorillaInventoryCollectable read FCollectable;
    /// <summary>
    ///  Im eingefrorenen Zustand bleibt das Element exakt an seiner Position
    ///  (es wabbelt nur), bewegt sich aber nicht frei. Wird fuer die
    ///  Maus-Vorschau verwendet. Das Umschalten stoppt bzw. startet die
    ///  per-Frame integrierte Raumbewegung.
    /// </summary>
    property Frozen : Boolean read FFrozen write SetFrozen;
    /// <summary>
    ///  Schaltet das Wabbeln zwischen dem ruhigen Grundzustand ('self') und dem
    ///  schnellen Schwimmen ('fast', schnellere Welle + staerkere Schwanzflosse)
    ///  um. Nur Fische besitzen die 'fast'-Animation; bei anderen Arten wirkungslos.
    /// </summary>
    property FastSwim : Boolean read FFastSwim write SetFastSwim;
    /// <summary>
    ///  Lebenspunkte (0..100). Nur Fische koennen gefuettert werden und haben
    ///  daher einen Lebenswert; bei anderen Arten bleibt er konstant auf 100.
    /// </summary>
    property Health : Single read FHealth;
    /// <summary>Verhungert - das Tier treibt nach oben und verschwindet dann.</summary>
    property IsDead : Boolean read FDead;
  end;

  /// <summary>
  ///  Eine ins Wasser geworfene Futterkapsel. Sinkt langsam zum Boden und wird
  ///  von Fischen gefressen (oder loest sich nach einer Weile auf).
  /// </summary>
  TFoodPellet = class
  private
    FModel : TGorillaSphere;   // sichtbare Kugel (Eigentum: vom Scene-Owner verwaltet)
    FVel   : TPoint3D;         // Sinkgeschwindigkeit (+ leichte Drift)
    FAge   : Single;           // Lebensalter in Sekunden
    FEaten : Boolean;          // markiert -> wird im naechsten Tick entfernt
  public
    function Position(): TPoint3D;
  end;

  TOnSpawnedElementEvent = procedure(ASender : TObject; ATemplate : TGorillaInventoryItemTemplate;
    AElement : TSpawnedElement) of object;
  TOnSpawnedFoodPelletEvent = procedure(ASender : TObject; APellet : TFoodPellet) of object;

  /// <summary>
  ///  Verwaltet alle in der Szene platzierten Elemente und treibt deren
  ///  Animation. Animate() muss regelmaessig (z.B. per Timer) aufgerufen werden.
  /// </summary>
  TAquariumScene = class
  private
    FViewport  : TGorillaViewport;
    FOwner     : TComponent;
    // ModelDef-Cache: ein Def je Vorlage (Template-Id), geteilt von allen
    // Instanzen dieser Vorlage. Die Models sind NICHT Eigentuemer
    // (IsDefOwner = False) - die Szene gibt die Defs selbst frei.
    FModelDefs : TDictionary<String, TModelDef>;
    // Aus dem Cache genommene Defs (Vorlage geaendert/geloescht), die noch von
    // platzierten Instanzen benutzt werden. Freigabe, sobald die letzte
    // Instanz entfernt wird (bzw. spaetestens im Destruktor).
    FRetiredDefs : TList<TModelDef>;
    FItems     : TObjectList<TSpawnedElement>;
    FPhysicsSystem : TGorillaPhysicsSystem;
    FFood      : TObjectList<TFoodPellet>;
    FFoodMat   : TGorillaLambertMaterialSource;  // gemeinsames Material aller Kapseln
    FLastTime  : Single;       // letzter Animate-Zeitstempel (fuer dt)

    FOnSpawnedElement : TOnSpawnedElementEvent;
    FOnSpawnedFoodPellet : TOnSpawnedFoodPelletEvent;

    /// <summary>
    ///  Liefert das ModelDef einer Vorlage (Quad-Mesh, texturiertes Material und
    ///  Eigen-Animation) aus dem Cache oder baut es neu. Die gezeichnete Textur
    ///  wird direkt ins Material-Def gelegt; das Materialisieren erzeugt daraus
    ///  automatisch die MaterialSource. Das Def gehoert der Szene (FModelDefs)
    ///  und wird von allen Instanzen der Vorlage geteilt.
    /// </summary>
    function BuildModelDef(const AName: String; AKind: TAquariumKind;
      ABitmap: TBitmap): TModelDef;

    /// <summary>
    ///  Baut das animierte Model + Wrapper einer Vorlage auf (ohne Collectable,
    ///  ohne Position, noch nicht in FItems). Gemeinsame Basis von Spawn() und
    ///  der Wiederherstellung aus einem gespeicherten Setup.
    /// </summary>
    function BuildSpawn(ATemplate: TGorillaInventoryItemTemplate): TSpawnedElement;
    /// <summary>
    ///  Stellt die Szenen-Instanz fuer einen bereits vorhandenen Collectable
    ///  her (beim Laden eines Setups): Model bauen, an den Collectable koppeln,
    ///  Position/Groesse aus dessen Parametern uebernehmen, Bewegung aufnehmen.
    /// </summary>
    function SpawnFromCollectable(
      ACollectable: TGorillaInventoryCollectable): TSpawnedElement;

    /// <summary>True, wenn noch eine platzierte Instanz ADef benutzt.</summary>
    function  IsDefInUse(ADef: TModelDef): Boolean;
    /// <summary>Gibt ein ausgemustertes Def frei, sobald es niemand mehr nutzt.</summary>
    procedure ReleaseRetiredDef(ADef: TModelDef);

    /// <summary>Stellt das gemeinsame Futter-Material her (einmalig).</summary>
    procedure EnsureFoodMaterial();
    /// <summary>Laesst alle Kapseln absinken und entfernt gefressene/alte.</summary>
    procedure UpdateFood(ADt: Single);
    /// <summary>Boids-Schwarmverhalten + Futtersuche fuer einen Fisch.</summary>
    function  SteerFish(AFish: TSpawnedElement): TPoint3D;
    /// <summary>Sanftes 3D-Treiben (Bob + Wander) fuer Quallen.</summary>
    function  SteerJelly(AJelly: TSpawnedElement; ADt: Single): TPoint3D;
    /// <summary>
    ///  Teilt jedem hungrigen Fisch hoechstens eine Kapsel zu (und jede Kapsel
    ///  hoechstens einem Fisch). Hungrigere Fische in der Naehe haben Vorrang.
    /// </summary>
    procedure AssignFood();

    /// <summary>
    ///  Hunger: senkt die Lebenspunkte eines Fisches, laesst ihn bei 0 sterben
    ///  und blendet unterhalb der Warnschwelle die Hunger-Markierung ein.
    /// </summary>
    procedure UpdateHealth(AFish: TSpawnedElement; ADt, ATime: Single);
    /// <summary>Verhungerter Fisch: bauchoben zur Oberflaeche treiben lassen.</summary>
    procedure UpdateDead(AFish: TSpawnedElement; ADt: Single);
    /// <summary>
    ///  Faerbt einen Fisch ein: AAmount 0 = Originalfarben, 1 = voll AColor.
    ///  Jedes Model besitzt eine eigene MaterialSource, daher betrifft das nur
    ///  diese Instanz.
    /// </summary>
    procedure SetTint(AFish: TSpawnedElement; const AColor: TAlphaColorF;
      AAmount: Single);

  public
    property PhysicsSystem : TGorillaPhysicsSystem read FPhysicsSystem;
    property OnSpawnedElement : TOnSpawnedElementEvent read FOnSpawnedElement write FOnSpawnedElement;
    property OnSpawnedFoodPellet : TOnSpawnedFoodPelletEvent read FOnSpawnedFoodPellet write FOnSpawnedFoodPellet;

    constructor Create(AViewport: TGorillaViewport; APhysics: TGorillaPhysicsSystem;
      AOwner: TComponent);
    destructor Destroy(); override;

    /// <summary>
    ///  Platziert eine Vorlage als animiertes Model in der Szene und legt dafuer
    ///  eine Inventar-Instanz (Collectable) an.
    /// </summary>
    function Spawn(ATemplate: TGorillaInventoryItemTemplate): TSpawnedElement;

    /// <summary>Entfernt ein platziertes Element wieder aus der Szene.</summary>
    procedure Remove(ASpawn: TSpawnedElement);

    /// <summary>Entfernt alle platzierten Elemente (samt ihrer Collectables).</summary>
    procedure ClearScene();

    /// <summary>
    ///  Verwirft das gecachte ModelDef einer Vorlage (nach Aktualisieren oder
    ///  Loeschen der Zeichnung). Neue Instanzen bauen danach ein frisches Def
    ///  mit der aktuellen Textur; das alte wird freigegeben, sobald keine
    ///  platzierte Instanz es mehr benutzt.
    /// </summary>
    procedure InvalidateModelDef(const ATemplateId: String);

    /// <summary>
    ///  Schreibt Position und Groesse jeder platzierten Instanz in die Parameter
    ///  ihres Collectables, damit ein anschliessendes Speichern den Becken-Zustand
    ///  vollstaendig erfasst.
    /// </summary>
    procedure SyncCollectables();

    /// <summary>
    ///  Baut die Szene aus den im Inventar enthaltenen Collectables neu auf
    ///  (z.B. nach dem Laden eines gespeicherten Setups). Vorher sollte die Szene
    ///  geleert werden (ClearScene).
    /// </summary>
    procedure RestoreFromInventory(AInventory: TGorillaInventory);

    /// <summary>
    ///  Wirft eine Futterkapsel an der angegebenen Stelle ins Wasser. Die Kapsel
    ///  sinkt von dort langsam ab; Fische in der Naehe schwimmen hin und fressen.
    /// </summary>
    procedure DropFood(const APos: TPoint3D);

    /// <summary>Aktualisiert die Animation aller platzierten Elemente.</summary>
    procedure Animate(ATime: Single);
  end;

const
  /// <summary>Anzeigenamen der Arten (Reihenfolge wie TAquariumKind).</summary>
  AQUARIUM_KIND_NAMES : array[TAquariumKind] of String =
    ('Fish', 'Jellyfish', 'Plant', 'Coral');

function AquariumKindToStr(AKind: TAquariumKind): String;
function StrToAquariumKind(const AValue: String): TAquariumKind;

/// <summary>Liest die Art einer Vorlage aus ihrer Inventar-Gruppe.</summary>
function AquariumTemplateKind(ATemplate: TGorillaInventoryItemTemplate): TAquariumKind;
/// <summary>Anzeigename einer Vorlage (Sprach-Map, Fallback: Id).</summary>
function AquariumTemplateName(ATemplate: TGorillaInventoryItemTemplate): String;
/// <summary>Die am Template (Data) gehaltene gezeichnete Textur, oder nil.</summary>
function AquariumTemplateBitmap(ATemplate: TGorillaInventoryItemTemplate): TBitmap;

implementation

uses
  System.RTLConsts, System.Generics.Defaults, FMX.MaterialSources, Gorilla.Control;

const
  SUBDIVISIONS   = 24;     // Aufloesung des Quad-Meshes (pro Achse)
  ANIM_KEYS      = 24;     // Keyframes pro Loop der Eigen-Animation

  // Grundgroesse (lokale Quad-Breite/Hoehe) je Art - Reihenfolge wie TAquariumKind.
  AQUARIUM_BASE_W : array[TAquariumKind] of Single = (2.6, 2.2, 2.2, 2.6);
  AQUARIUM_BASE_H : array[TAquariumKind] of Single = (1.9, 2.4, 3.4, 2.2);

  // Loop-Dauer der Eigen-Animation je Art (Sekunden).
  AQUARIUM_LOOP_S : array[TAquariumKind] of Single = (1.6, 2.6, 3.0, 3.4);

  // --- Tank-Grenzen fuer frei schwimmende Elemente (Welt-Koordinaten) ---
  // Wasseroberflaeche liegt bei Y~0, der Boden bei Y~7. Hoehere Y = tiefer.
  TANK_MIN_X = -15.0;  TANK_MAX_X = 15.0;
  TANK_MIN_Y =  1.5;  TANK_MAX_Y = 6.3;
  TANK_MIN_Z = -15.0;  TANK_MAX_Z = 15.0;
  TANK_MARGIN = 1.6;        // Abstand zur Wand, ab dem zurueckgelenkt wird

  // --- Boids / Schwarmverhalten (Fische) ---
  FISH_MAX_SPEED = 3.4;     // Hoechstgeschwindigkeit (Welt/s), je Instanz variiert
  FISH_MIN_SPEED = 0.7;     // Mindesttempo, damit Fische nie ganz stehen bleiben
  FISH_MAX_FORCE = 7.0;     // Begrenzung der Steuer-Beschleunigung
  NEIGH_RADIUS   = 4.0;     // Wahrnehmung fuer Ausrichtung/Zusammenhalt (gleiche Art)
  SEP_RADIUS     = 1.7;     // Mindestabstand -> Kollisionsvermeidung (alle Fische)
  W_SEPARATION   = 2.4;
  W_ALIGNMENT    = 0.8;
  W_COHESION     = 0.6;
  W_WANDER       = 1.1;
  W_BOUNDS       = 6.0;
  W_FOOD         = 6.0;

  // --- Futterkapseln ---
  FOOD_SENSE     = 8.0;     // Sichtweite, ab der ein Fisch Futter ansteuert
  FOOD_RADIUS    = 0.26;    // Welt-Radius der Kugel
  FOOD_SINK_ACC  = 1.4;     // Sink-Beschleunigung (+Y)
  FOOD_SINK_MAX  = 1.1;     // Sink-Endgeschwindigkeit
  FOOD_FLOOR_Y   = 6.5;     // Ruhelage am Boden
  FOOD_LIFETIME  = 45.0;    // Sekunden, dann loest sich uneaten Futter auf

  // --- Lebenspunkte / Hunger (Fische) ---
  FISH_HEALTH_MAX  = 100.0;
  FISH_HUNGER_RATE = 0.5;   // Lebenspunkte pro Sekunde -> ~3:20 min von voll bis tot
  FISH_FOOD_VALUE  = 30.0;  // Lebenspunkte je gefressener Kapsel
  FISH_SATED_TIME  = 15.0;  // so lange bleibt ein voller Fisch satt (frisst nicht)
  FISH_HEALTH_WARN = 40.0;  // darunter hungrig: sanftes Pulsieren (~80 s vor dem Tod)
  FISH_HEALTH_CRIT = 15.0;  // darunter kritisch: schnelles, kraeftiges Blinken (~30 s)
  // Vorrang beim Futter: pro fehlendem Lebenspunkt gilt ein Fisch als um diese
  // Strecke naeher an der Kapsel (ein fast toter Fisch "gewinnt" so gegen einen
  // satten, der bis zu ~6 Einheiten naeher ist).
  FOOD_PRIORITY_DIST = 0.06;
  // Einfaerbung (Faktoren auf die gezeichnete Textur): hungrig pulsiert der
  // Fisch zu einem blassen Gruen, kritisch blinkt er dunkel, tot wird er grau.
  TINT_SICK : TAlphaColorF = (R: 0.55; G: 0.85; B: 0.40; A: 1);
  TINT_CRIT : TAlphaColorF = (R: 0.20; G: 0.30; B: 0.15; A: 1);
  TINT_DEAD : TAlphaColorF = (R: 0.40; G: 0.40; B: 0.40; A: 1);
  DEAD_FLOAT_Y     = 0.8;   // Hoehe knapp unter der Oberflaeche, zu der Tote treiben
  DEAD_FLOAT_SPEED = 0.6;   // Auftriebsgeschwindigkeit toter Fische (Welt/s)
  DEAD_REMOVE_TIME = 12.0;  // Sekunden nach dem Tod, dann verschwindet der Fisch

// --- kleine 3D-Vektorhelfer ---------------------------------------------------

// Begrenzt die Laenge eines Vektors auf AMax.
function LimitLen(const V: TPoint3D; AMax: Single): TPoint3D;
var L : Single;
begin
  L := V.Length;
  if (L > AMax) and (L > 0.0001) then
    Result := V * (AMax / L)
  else
    Result := V;
end;

// Normalisiert sicher (Nullvektor -> Nullvektor).
function NormSafe(const V: TPoint3D): TPoint3D;
var L : Single;
begin
  L := V.Length;
  if L > 0.0001 then
    Result := V * (1.0 / L)
  else
    Result := TPoint3D.Zero;
end;

// Zufaelliger Einheitsvektor (gleichmaessig auf der Kugel).
function RandomUnit3D(): TPoint3D;
var z, t, r : Single;
begin
  z := 2.0 * Random - 1.0;
  t := 2.0 * PI * Random;
  r := Sqrt(Max(0.0, 1.0 - z * z));
  Result := Point3D(r * Cos(t), r * Sin(t), z);
end;

const
  // Parameter-Schluessel + Trenner fuer "px;py;pz;scale" einer Instanz. Bewusst
  // als String kodiert, damit der Wert unabhaengig von der Parameter-
  // Serialisierung des Inventory (typbewusst oder Legacy-String) round-trippt.
  PARAM_XFORM = 'aqx';
  PARAM_HEALTH = 'aqh';      // Lebenspunkte einer Instanz (nur Fische)
  XFORM_SEP   = ';';

// Liest Position + Groesse einer gespeicherten Instanz aus dem Transform-
// Parameter ihres Collectables. Fehlt ein Wert, bleibt der uebergebene
// Default erhalten.
procedure ReadXformParam(const ACollectable: TGorillaInventoryCollectable;
  var APos: TPoint3D; var AScale: Single);
var
  LVal   : TValue;
  LParts : TArray<String>;
  LFmt   : TFormatSettings;
begin
  if not Assigned(ACollectable) then
    Exit;
  if not ACollectable.Parameters.TryGetValue(PARAM_XFORM, LVal) then
    Exit;

  LFmt   := TFormatSettings.Invariant;
  LParts := LVal.ToString().Split([XFORM_SEP]);
  if Length(LParts) > 0 then APos.X := StrToFloatDef(LParts[0], APos.X, LFmt);
  if Length(LParts) > 1 then APos.Y := StrToFloatDef(LParts[1], APos.Y, LFmt);
  if Length(LParts) > 2 then APos.Z := StrToFloatDef(LParts[2], APos.Z, LFmt);
  if Length(LParts) > 3 then AScale := StrToFloatDef(LParts[3], AScale, LFmt);
end;

function AquariumKindToStr(AKind: TAquariumKind): String;
begin
  case AKind of
    akFish      : Result := 'fish';
    akJellyfish : Result := 'jellyfish';
    akPlant     : Result := 'plant';
    akCoral     : Result := 'coral';
  else
    Result := 'fish';
  end;
end;

function StrToAquariumKind(const AValue: String): TAquariumKind;
var LVal : String;
begin
  LVal := LowerCase(Trim(AValue));
  if LVal = 'jellyfish' then Result := akJellyfish
  else if LVal = 'plant' then Result := akPlant
  else if LVal = 'coral' then Result := akCoral
  else Result := akFish;
end;

function AquariumTemplateKind(ATemplate: TGorillaInventoryItemTemplate): TAquariumKind;
begin
  Result := akFish;
  if Assigned(ATemplate) and Assigned(ATemplate.Group) then
    Result := StrToAquariumKind(ATemplate.Group.Id);
end;

function AquariumTemplateName(ATemplate: TGorillaInventoryItemTemplate): String;
begin
  Result := '';
  if not Assigned(ATemplate) then
    Exit;
  Result := ATemplate.GetCurrentName();
  if Result = '' then
    Result := ATemplate.Id;
end;

function AquariumTemplateBitmap(ATemplate: TGorillaInventoryItemTemplate): TBitmap;
begin
  Result := nil;
  if not Assigned(ATemplate) then
    Exit;
  if (not ATemplate.Data.IsEmpty) and ATemplate.Data.IsObject
  and (ATemplate.Data.AsObject is TBitmap) then
    Result := TBitmap(ATemplate.Data.AsObject);
end;

{ TAquariumLibrary }

constructor TAquariumLibrary.Create();
begin
  inherited Create();
  // Das Inventar besitzt die Library (Owner=nil -> wir geben es selbst frei).
  FInventory := TGorillaInventory.Create(nil);

  FElementsDir := TPath.Combine(
    TPath.Combine(TPath.GetDocumentsPath, 'SketchQuarium'), 'inventory');
  FFilePath := TPath.Combine(FElementsDir, 'inventory.xml');

  EnsureDirectories();
  EnsureGroups();
end;

destructor TAquariumLibrary.Destroy();
begin
  FreeBitmaps();
  FInventory.Free();
  inherited;
end;

procedure TAquariumLibrary.EnsureDirectories();
begin
  if not TDirectory.Exists(FElementsDir) then
    TDirectory.CreateDirectory(FElementsDir);
end;

procedure TAquariumLibrary.EnsureGroups();
var
  LKind : TAquariumKind;
  LGrp  : TGorillaInventoryGroup;
begin
  for LKind := Low(TAquariumKind) to High(TAquariumKind) do
  begin
    if Assigned(FInventory.FindGroup(AquariumKindToStr(LKind))) then
      Continue;
    LGrp := FInventory.AddGroup(AquariumKindToStr(LKind));
    LGrp.Name.AddOrSetValue(FInventory.GetCurrentLanguageName(),
      AQUARIUM_KIND_NAMES[LKind]);
  end;
end;

function TAquariumLibrary.GroupForKind(AKind: TAquariumKind): TGorillaInventoryGroup;
begin
  Result := FInventory.FindGroup(AquariumKindToStr(AKind));
end;

function TAquariumLibrary.VisualFileOf(
  ATemplate: TGorillaInventoryItemTemplate): String;
var LVi : TGorillaInventoryVisualItem;
begin
  Result := '';
  if not Assigned(ATemplate) then
    Exit;
  LVi := FInventory.GetVisualItemByName(ATemplate.Id);
  if Assigned(LVi) then
    Result := LVi.Resources[GORILLA_INVENTORY_VISUALITEM_RESOURCE_IMGLOD0];
end;

// Bindet jedem Template seinen ImageIndex an die Position seines VisualItems
// (nach Strukturaenderungen, damit das Inventar-Image-List konsistent bleibt).
procedure TAquariumLibrary.SyncImageIndices();
var
  i   : Integer;
  LTpl : TGorillaInventoryItemTemplate;
  LVi  : TGorillaInventoryVisualItem;
begin
  for i := 0 to FInventory.ItemTemplates.Count - 1 do
  begin
    LTpl := FInventory.ItemTemplates.Items[i] as TGorillaInventoryItemTemplate;
    LVi  := FInventory.GetVisualItemByName(LTpl.Id);
    if Assigned(LVi) then
      LTpl.ImageIndex := LVi.Index
    else
      LTpl.ImageIndex := -1;
  end;
end;

procedure TAquariumLibrary.LoadBitmaps();
var
  i    : Integer;
  LTpl : TGorillaInventoryItemTemplate;
  LRel, LFull : String;
  LBmp : TBitmap;
begin
  for i := 0 to FInventory.ItemTemplates.Count - 1 do
  begin
    LTpl := FInventory.ItemTemplates.Items[i] as TGorillaInventoryItemTemplate;
    LRel := VisualFileOf(LTpl);
    if LRel = '' then
      Continue;
    LFull := TPath.Combine(FElementsDir, LRel);
    if not TFile.Exists(LFull) then
      Continue;
    LBmp := TBitmap.Create();
    LBmp.LoadFromFile(LFull);
    LTpl.Data := TValue.From<TBitmap>(LBmp);
  end;
end;

procedure TAquariumLibrary.FreeBitmaps();
var
  i    : Integer;
  LTpl : TGorillaInventoryItemTemplate;
  LBmp : TBitmap;
begin
  for i := 0 to FInventory.ItemTemplates.Count - 1 do
  begin
    LTpl := FInventory.ItemTemplates.Items[i] as TGorillaInventoryItemTemplate;
    LBmp := AquariumTemplateBitmap(LTpl);
    if Assigned(LBmp) then
    begin
      LTpl.Data := TValue.Empty;
      LBmp.Free();
    end;
  end;
end;

procedure TAquariumLibrary.LoadFromDisk();
begin
  EnsureDirectories();

  // Eigene Data-Bitmaps freigeben, bevor das Inventar neu aufgebaut wird.
  FreeBitmaps();

  if TFile.Exists(FFilePath) then
    FInventory.LoadFromFile(FFilePath);

  EnsureGroups();

  // Sauberer Schnitt: ein frisch geladenes Inventar startet mit leerem Becken.
  FInventory.CollectedItems.Clear();

  LoadBitmaps();
end;

procedure TAquariumLibrary.SaveToDisk();
begin
  EnsureDirectories();
  FInventory.SaveToFile(FFilePath);
end;

procedure TAquariumLibrary.SaveSetupToFile(const APath: String);
begin
  FInventory.SaveToFile(APath);
end;

procedure TAquariumLibrary.LoadSetupFromFile(const APath: String);
begin
  FreeBitmaps();
  FInventory.LoadFromFile(APath);
  EnsureGroups();
  LoadBitmaps();
  // Collectables (= gespeicherte Instanzen) bleiben erhalten -> Szene baut sie
  // ueber TAquariumScene.RestoreFromInventory wieder auf.
end;

function TAquariumLibrary.Count(): Integer;
begin
  Result := FInventory.ItemTemplates.Count;
end;

function TAquariumLibrary.GetTemplate(
  AIndex: Integer): TGorillaInventoryItemTemplate;
begin
  Result := nil;
  if (AIndex >= 0) and (AIndex < FInventory.ItemTemplates.Count) then
    Result := FInventory.ItemTemplates.Items[AIndex] as TGorillaInventoryItemTemplate;
end;

function TAquariumLibrary.AddDrawing(AKind: TAquariumKind; const AName: String;
  ASource: TBitmap): TGorillaInventoryItemTemplate;
var
  LName, LId, LFileName, LFullPath : String;
  LBmp : TBitmap;
  LVi  : TGorillaInventoryVisualItem;
begin
  EnsureDirectories();
  EnsureGroups();

  LName := Trim(AName);
  if LName = '' then
    LName := AQUARIUM_KIND_NAMES[AKind] + ' ' + (Count() + 1).ToString;

  LId := TGUID.NewGuid().ToString
           .Replace('{', '').Replace('}', '').Replace('-', '');
  LFileName := AquariumKindToStr(AKind) + '_' + LId + '.png';
  LFullPath := TPath.Combine(FElementsDir, LFileName);
  ASource.SaveToFile(LFullPath);

  Result := FInventory.AddItemTemplate(LId);
  Result.Group    := GroupForKind(AKind);
  Result.IsPooled := False;   // jede Platzierung wird eine eigene Instanz
  Result.Enabled  := True;
  Result.Name.AddOrSetValue(FInventory.GetCurrentLanguageName(), LName);

  // VisualItem haelt den (relativen) Dateinamen fuer die Persistenz.
  LVi := FInventory.AddVisualItem(-1, LId, LFileName, LFileName, LFileName, '');
  Result.ImageIndex := LVi.Index;

  // gezeichnete Textur am Template halten (Eigentum der Library).
  LBmp := TBitmap.Create();
  LBmp.Assign(ASource);
  Result.Data := TValue.From<TBitmap>(LBmp);

  SaveToDisk();
end;

procedure TAquariumLibrary.UpdateDrawing(
  ATemplate: TGorillaInventoryItemTemplate; AKind: TAquariumKind;
  const AName: String; ASource: TBitmap);
var
  LName, LRel, LFull : String;
  LOld, LBmp : TBitmap;
begin
  if not Assigned(ATemplate) then
    Exit;

  LName := Trim(AName);
  if LName = '' then
    LName := AquariumTemplateName(ATemplate);

  // gleiche PNG-Datei ueberschreiben
  LRel := VisualFileOf(ATemplate);
  if LRel <> '' then
  begin
    LFull := TPath.Combine(FElementsDir, LRel);
    ASource.SaveToFile(LFull);
  end;

  ATemplate.Group := GroupForKind(AKind);
  ATemplate.Name.AddOrSetValue(FInventory.GetCurrentLanguageName(), LName);

  // alte Textur freigeben, neue uebernehmen
  LOld := AquariumTemplateBitmap(ATemplate);
  LBmp := TBitmap.Create();
  LBmp.Assign(ASource);
  ATemplate.Data := TValue.From<TBitmap>(LBmp);
  if Assigned(LOld) then
    LOld.Free();

  SaveToDisk();
end;

procedure TAquariumLibrary.DeleteDrawing(ATemplate: TGorillaInventoryItemTemplate);
var
  LRel, LFull : String;
  LBmp : TBitmap;
  LId  : String;
begin
  if not Assigned(ATemplate) then
    Exit;

  LId  := ATemplate.Id;
  LRel := VisualFileOf(ATemplate);

  LBmp := AquariumTemplateBitmap(ATemplate);
  if Assigned(LBmp) then
  begin
    ATemplate.Data := TValue.Empty;
    LBmp.Free();
  end;

  FInventory.RemoveVisualItem(LId);
  FInventory.RemoveItemTemplate(ATemplate);   // entfernt auch zugehoerige Items

  if LRel <> '' then
  begin
    LFull := TPath.Combine(FElementsDir, LRel);
    if TFile.Exists(LFull) then
      TFile.Delete(LFull);
  end;

  SyncImageIndices();
  SaveToDisk();
end;

{ TSpawnedElement }

constructor TSpawnedElement.Create();
begin
  inherited Create();
  FScale     := 1.0;
  FMaxSpeed  := FISH_MAX_SPEED;
  FFrozen    := False;
  FVelocity  := TPoint3D.Zero;
  FWanderDir := RandomUnit3D();
  FPhase     := Random * 2 * PI;
  FHealth    := FISH_HEALTH_MAX;
  FSatedTime := FISH_SATED_TIME;   // frisch eingesetzt = satt
end;

procedure TSpawnedElement.ApplyScale();
begin
  // Grundgroesse je Art (X/Y) mal Mausrad-Skalierung. Z nur die Skalierung,
  // damit die gebackene Z-Deformation - wie frueher beim Plane - unabhaengig
  // von der Breite bleibt.
  if Assigned(FModel) then
    FModel.Scale.Point := Point3D(FBaseW * FScale, FBaseH * FScale, FScale);
end;

procedure TSpawnedElement.Animate(ATime: Single);
begin
  // Die eigentliche Raumbewegung treibt jetzt die Szene per ApplyMotion
  // (Velocity-Integration). Diese Methode bleibt nur als Kompatibilitaets-
  // einstieg erhalten und tut nichts mehr.
end;

procedure TSpawnedElement.StartMotion();
begin
  // Beim Loslassen (Frozen:=False) eine Anfangsbewegung erzeugen, damit das
  // Element nicht aus dem Stand "anschwimmen" muss.
  if FKind in [akFish, akJellyfish] then
  begin
    // Position bleibt exakt am Klickpunkt (Z = 0). Die Verteilung in die
    // Tiefe ergibt sich danach durch das Schwimmen (FWanderDir hat Z-Anteil).
    FWanderDir := RandomUnit3D();
    if FKind = akFish then
      FVelocity := FWanderDir * (FMaxSpeed * 0.5)
    else
      FVelocity := FWanderDir * 0.3;   // Quallen treiben gemaechlich
  end;
end;

procedure TSpawnedElement.ApplyMotion(const AAccel: TPoint3D; ADt: Single);
var
  LPos, LAcc : TPoint3D;
  LSpeed : Single;
begin
  if FFrozen or not Assigned(FModel) or (ADt <= 0) then
    Exit;

  // Beschleunigung begrenzen, integrieren, Geschwindigkeit deckeln.
  LAcc := LimitLen(AAccel, FISH_MAX_FORCE);
  FVelocity := FVelocity + LAcc * ADt;
  FVelocity := LimitLen(FVelocity, FMaxSpeed);

  // Fische sollen nie ganz stehen bleiben (lebendiger Eindruck).
  if FKind = akFish then
  begin
    LSpeed := FVelocity.Length;
    if LSpeed < FISH_MIN_SPEED then
    begin
      if LSpeed > 0.0001 then
        FVelocity := FVelocity * (FISH_MIN_SPEED / LSpeed)
      else
        FVelocity := FWanderDir * FISH_MIN_SPEED;
    end;
  end;

  // Position fortschreiben und hart in den Tank klemmen (an der Wand abprallen).
  LPos := FModel.Position.Point + FVelocity * ADt;

  if LPos.X < TANK_MIN_X then begin LPos.X := TANK_MIN_X; FVelocity.X := Abs(FVelocity.X); end
  else if LPos.X > TANK_MAX_X then begin LPos.X := TANK_MAX_X; FVelocity.X := -Abs(FVelocity.X); end;
  if LPos.Y < TANK_MIN_Y then begin LPos.Y := TANK_MIN_Y; FVelocity.Y := Abs(FVelocity.Y); end
  else if LPos.Y > TANK_MAX_Y then begin LPos.Y := TANK_MAX_Y; FVelocity.Y := -Abs(FVelocity.Y); end;
  if LPos.Z < TANK_MIN_Z then begin LPos.Z := TANK_MIN_Z; FVelocity.Z := Abs(FVelocity.Z); end
  else if LPos.Z > TANK_MAX_Z then begin LPos.Z := TANK_MAX_Z; FVelocity.Z := -Abs(FVelocity.Z); end;

  FModel.Position.Point := LPos;

  // Blickrichtung: flache Sprites bleiben kamerazugewandt, klappen aber je nach
  // X-Richtung um (0 = nach rechts, 180 = nach links). Nur fuer Fische sinnvoll.
  if FKind = akFish then
  begin
    if FVelocity.X > 0.02 then
      FModel.RotationAngle.Y := 0
    else if FVelocity.X < -0.02 then
      FModel.RotationAngle.Y := 180;
  end;
end;

procedure TSpawnedElement.SetFrozen(const AValue: Boolean);
begin
  if FFrozen = AValue then
    Exit;
  FFrozen := AValue;

  if not FFrozen then
    StartMotion();   // platziert: Raumbewegung aufnehmen (Vorschau -> lebendig)
end;

procedure TSpawnedElement.SetFastSwim(const AValue: Boolean);
var LId : String;
begin
  if FFastSwim = AValue then
    Exit;
  FFastSwim := AValue;

  if not Assigned(FModel) or not Assigned(FModel.AnimationManager) then
    Exit;

  if FFastSwim then
    LId := 'fast'
  else
    LId := 'self';

  // PlayAnimation stoppt die laufende und aktiviert die gewuenschte Animation;
  // existiert sie nicht (z.B. 'fast' nur beim Fisch), passiert nichts.
  FModel.AnimationManager.PlayAnimation(LId);
end;

procedure TSpawnedElement.SetBasePosition(const APos: TPoint3D);
begin
  FBasePos := APos;
  if Assigned(FModel) then
    FModel.Position.Point := APos;
end;

procedure TSpawnedElement.SetSizeScale(const AFactor: Single);
begin
  FScale := AFactor;
  ApplyScale();
end;

function TSpawnedElement.WorldHeight(): Single;
begin
  // Lokale Quad-Hoehe ist 1.0 (Bereich -0.5..0.5) -> Welt-Hoehe = FBaseH * FScale.
  Result := FBaseH * FScale;
end;

// Lokale Eigen-Deformation eines Vertex (u,v in -0.5..0.5) zum Loop-Winkel
// theta in [0..2*PI). Alle Zeitterme sind ganzzahlige Vielfache von theta,
// damit die gebackene Animation nahtlos in sich zurueckkehrt.
//   AAmp     - Amplitudenfaktor (1.0 = Grundstaerke des Wabbelns)
//   ASpeed   - Wellen-Zyklen je Loop (MUSS ganzzahlig sein -> nahtloser Loop);
//              hoeher = schnelleres Wabbeln
//   ATailPow - Exponent der Schwanzbetonung (hoeher = Bewegung staerker hinten
//              an der Flosse konzentriert)
//   ARamp    - zeitliche Verstaerkung: 0 = gleichmaessig, >0 = das Wabbeln baut
//              sich zum (spaeten) Loop-Ende hin auf und kehrt zum Grundwert
//              zurueck, damit die Animation weiterhin nahtlos loopt.
function DeformedVertex(AKind: TAquariumKind; u, v, theta: Single;
  AAmp: Single = 1.0; ASpeed: Single = 1.0; ATailPow: Single = 2.0;
  ARamp: Single = 0.0): TPoint3D;
var w, r, zz, dx, dy, dz, pulse, p, tenv, wave : Single;
begin
  dx := 0; dy := 0; dz := 0; zz := 0;
  case AKind of
    akFish:
      begin
        // Schwanz-Koordinate: 1 an der Schwanzflosse (u=-0.5), 0 am Kopf (u=+0.5)
        w := 0.5 - u;
        // Zeitliche Huellkurve: steigt ueber den Loop an, Spitze gegen Ende
        // (p^3 schiebt das Maximum nach hinten), faellt zum Loop-Punkt wieder
        // auf den Grundwert -> tenv(0)=tenv(1)=1, dazwischen bis 1+ARamp.
        p    := theta / (2 * PI);
        tenv := 1.0 + ARamp * (0.5 - 0.5 * Cos(2 * PI * Power(p, 3.0)));
        // Wanderwelle entlang X; Amplitude waechst per ATailPow zur Flosse hin.
        wave := AAmp * tenv * Power(w, ATailPow) * Sin(6.0 * u - ASpeed * theta);
        // Seitlicher Flossenschlag (Z). Da der Fisch ein kamerazugewandtes
        // Sprite ist, laeuft Z groesstenteils in Blickrichtung - daher zusaetzlich
        // ein kleinerer Anteil in der Sprite-Ebene (Y), damit das Schwimmen auch
        // frontal deutlich sichtbar ist.
        zz := 0.50 * wave;
        dy := 0.05 * wave;
      end;

    akJellyfish:
      begin
        r := Sqrt(u * u + v * v);
        pulse := 0.5 + 0.5 * Sin(theta);    // pulsierende Glocke
        zz := 0.22 * Cos(r * PI) * pulse;
        if v > 0 then                       // Tentakel-Saum unten nachziehen
          zz := zz + 0.10 * v * Sin(3.0 * theta - v * 4.0);
      end;

    akPlant:
      begin
        w := 0.5 - v;                       // 0 an der Wurzel .. 1 an der Spitze
        dx := 0.26 * (w * w) * Sin(theta + v * 3.0);
        dz := 0.10 * (w * w) * Cos(theta);
      end;

    akCoral:
      begin
        w := 0.5 - v;                       // steifer: kleinere Amplitude
        dx := 0.09 * (w * w * w) * Sin(theta + v * 2.0);
        dz := 0.05 * (w * w * w) * Cos(theta);
      end;
  end;
  Result := Point3D(u + dx, v + dy, zz + dz);
end;

{ TFoodPellet }

function TFoodPellet.Position(): TPoint3D;
begin
  if Assigned(FModel) then
    Result := FModel.Position.Point
  else
    Result := TPoint3D.Zero;
end;

{ TAquariumScene }

constructor TAquariumScene.Create(AViewport: TGorillaViewport;
  APhysics: TGorillaPhysicsSystem; AOwner: TComponent);
begin
  inherited Create();
  FViewport := AViewport;
  FPhysicsSystem := APhysics;
  FOwner    := AOwner;
  FModelDefs := TDictionary<String, TModelDef>.Create();
  FRetiredDefs := TList<TModelDef>.Create();
  FItems    := TObjectList<TSpawnedElement>.Create(True);
  FFood     := TObjectList<TFoodPellet>.Create(True);
  FLastTime := -1;
  Randomize();
end;

destructor TAquariumScene.Destroy();
var
  i    : Integer;
  LDef : TModelDef;
begin
  // Futterkugeln zuerst aus der Szene loesen (Models gehoeren dem Owner).
  for i := 0 to FFood.Count - 1 do
    if Assigned(FFood[i].FModel) then
    begin
      FFood[i].FModel.Parent := nil;
      FFood[i].FModel.Free();
      FFood[i].FModel := nil;
    end;
  FFood.Free();

  // Platzierte Models freigeben, BEVOR ihre (geteilten) Defs freigegeben
  // werden. Die Models gehoeren zwar FOwner, wuerden von diesem aber erst
  // nach der Szene zerstoert - ein Model darf sein Def nicht ueberleben.
  // Collectables werden hier bewusst NICHT abgeworfen (Inventar unveraendert).
  for i := 0 to FItems.Count - 1 do
    if Assigned(FItems[i].FModel) then
    begin
      FItems[i].FModel.Parent := nil;
      FItems[i].FModel.Free();
      FItems[i].FModel := nil;
    end;
  FItems.Free();

  // Die Models sind keine Def-Eigentuemer (IsDefOwner = False) -> die Szene
  // gibt alle gecachten und ausgemusterten Defs selbst frei.
  for LDef in FModelDefs.Values do
    LDef.Free();
  FModelDefs.Free();
  for LDef in FRetiredDefs do
    LDef.Free();
  FRetiredDefs.Free();
  // FFoodMat gehoert FOwner und wird von diesem freigegeben.

  inherited;
end;

function TAquariumScene.BuildModelDef(const AName: String; AKind: TAquariumKind;
  ABitmap: TBitmap): TModelDef;
const
  N = SUBDIVISIONS;
var
  LMesh  : TMeshDef;
  LData  : TMeshData;
  LMat   : TMaterialDef;
  LAsset : TGorillaTextureAsset;
  X, Y, idx, ver : Integer;

  // Backt eine gebackene Vertex-Animation (Wabbel-Loop) ins ModelDef. AAmp/
  // ASpeed/ATailPow steuern Staerke, Tempo und Schwanzbetonung (siehe
  // DeformedVertex). Jede Animation deformiert dasselbe Mesh - es laeuft immer
  // nur eine zur Zeit.
  procedure AddWobble(const AId: String; ADuration, AAmp, ASpeed, ATailPow, ARamp: Single);
  var
    LAnim  : TAnimationDef;
    LStage : TAnimationStageDef;
    LInter : TMeshInterpolatorDef;
    k, lx, ly, lidx : Integer;
    theta, lu, lv : Single;
    verts : TPoint3DDynArray;
  begin
    LAnim := TAnimationDef.Create(Result);
    LAnim.Id := AId;
    Result.AddAnimation(LAnim);

    LStage := TAnimationStageDef.Create(LAnim);
    LStage.Id := AId + '_stage';
    LStage.Reference := LMesh;                 // dieses Mesh wird deformiert
    LAnim.AddStage(LStage);

    LInter := TMeshInterpolatorDef.Create(LStage);
    LInter.Id := AId + '_deform';
    LInter.Duration := ADuration;
    LInter.Loop := True;
    LStage.AddInterpolator(LInter);

    // Keyframes ueber eine Loop-Periode sampeln (Schluesselzeiten 0..1 normiert).
    for k := 0 to ANIM_KEYS do
    begin
      theta := 2 * PI * (k / ANIM_KEYS);
      verts := nil;                            // frischer Puffer je Key
      SetLength(verts, ver);
      for ly := 0 to N do
        for lx := 0 to N do
        begin
          lidx := lx + ly * (N + 1);
          lu := -0.5 + lx / N;
          lv := -0.5 + ly / N;
          verts[lidx] := DeformedVertex(AKind, lu, lv, theta, AAmp, ASpeed, ATailPow, ARamp);
        end;
      LInter.AddKey(k / ANIM_KEYS, verts, TAnimationKeyInterpolationType.Linear);
    end;
  end;

begin
  if FModelDefs.TryGetValue(AName, Result) then
    Exit;

  Result := TModelDef.Create(nil, nil);
  Result.Id := 'aq_' + AquariumKindToStr(AKind);

  ver := (N + 1) * (N + 1);

  // 1) Quad-Geometrie als TMeshData (unterteilt, mit planaren UVs) -> MeshDef.
  LMesh := TMeshDef.Create(Result);
  LMesh.Id := 'mesh';
  LMesh.FaceOrientation := TFaceOrientation.TwoFace;   // beidseitig sichtbar

  LData := TMeshData.Create();
  try
    LData.VertexBuffer.Length := ver;
    for Y := 0 to N do
      for X := 0 to N do
      begin
        idx := X + Y * (N + 1);
        LData.VertexBuffer.Vertices[idx]  := Point3D(-0.5 + X / N, -0.5 + Y / N, 0);
        LData.VertexBuffer.Normals[idx]   := Point3D(0, 0, -1);
        LData.VertexBuffer.TexCoord0[idx] := PointF(X / N, Y / N);
      end;

    LData.IndexBuffer.Length := N * N * 6;
    for Y := 0 to N - 1 do
      for X := 0 to N - 1 do
      begin
        idx := (X + Y * N) * 6;
        LData.IndexBuffer[idx + 0] := X     +  Y      * (N + 1);
        LData.IndexBuffer[idx + 1] := X + 1 +  Y      * (N + 1);
        LData.IndexBuffer[idx + 2] := X     + (Y + 1) * (N + 1);
        LData.IndexBuffer[idx + 3] := X     + (Y + 1) * (N + 1);
        LData.IndexBuffer[idx + 4] := X + 1 +  Y      * (N + 1);
        LData.IndexBuffer[idx + 5] := X + 1 + (Y + 1) * (N + 1);
      end;

    LData.CalcTangentBinormals();
    LMesh.ApplyFromMeshData(LData);
  finally
    LData.Free();
  end;
  Result.AddChild(LMesh);

  // 2) Material mit der gezeichneten Textur. Wie ein Sprite: unbeleuchtet
  //    (echte Farben, kein Abdunkeln/Schwarz beim Umdrehen), beidseitig, die
  //    Alpha-Transparenz der Zeichnung uebernimmt das nicht-opake Rendern.
  LMat := TMaterialDef.Create(Result, 'mat');
  LMat.Kind := TMaterialDefKind.mkBlinnPhong;
  LMat.UseTexturing := True;
  LMat.UseTexture0  := True;
  LMat.UseLighting  := False;
  LMat.UseSpecular  := False;
  LMat.DoubleSided  := True;
  LMat.AlphaCutoff := 0.1;
  LMat.UseAlphaCutoff := true;
  LMat.Diffuse := TAlphaColorF.Create(1, 1, 1, 1);

  // Textur aus dem gezeichneten Bitmap (wird intern geklont -> Original bleibt).
  LAsset := TGorillaTextureAsset.Create(nil);
  LAsset.ImportFromCachedBitmap('drawing.png', ABitmap);
  LMat.AddTexture(TColorChannelDef.Diffuse, LAsset, True);  // Material besitzt Asset

  LMesh.SetMaterialReference(LMat);

  // 3) Eigen-Animation(en): prozedurale Deformation als gebackene Vertex-Loops.
  //    Der Fisch bekommt zwei Loops auf demselben Mesh:
  //      'self' - ruhiges, kraeftiges Wabbeln (Grundzustand)
  //      'fast' - schnelles Schwimmen: schnellere Welle (2 Zyklen/Loop, kuerzere
  //               Dauer), groessere Amplitude und staerker zur Schwanzflosse
  //               hin betont (ATailPow 2.5).
  //    Umgeschaltet wird zur Laufzeit ueber TSpawnedElement.FastSwim.
  if AKind = akFish then
  begin
    //                Id      Dauer                  Amp  Speed TailPow Ramp
    AddWobble('self', AQUARIUM_LOOP_S[akFish],       1.0, 1.0,  2.0,    0.0);
    AddWobble('fast', 0.85,                          1.4, 2.0,  2.5,    0.6);
  end
  else
    AddWobble('self', AQUARIUM_LOOP_S[AKind],        1.0, 1.0,  2.5,    0.0);

  FModelDefs.Add(AName, Result);
end;

function TAquariumScene.BuildSpawn(
  ATemplate: TGorillaInventoryItemTemplate): TSpawnedElement;
var
  LDef   : TModelDef;
  LModel : TGorillaModel;
  LSpawn : TSpawnedElement;
  LKind  : TAquariumKind;
  LBmp   : TBitmap;
  LAnim  : TGorillaAnimation;
begin
  Result := nil;
  if not Assigned(ATemplate) then
    Exit;

  LKind := AquariumTemplateKind(ATemplate);
  LBmp  := AquariumTemplateBitmap(ATemplate);
  if not Assigned(LBmp) then
    Exit;   // ohne Textur laesst sich kein ModelDef aufbauen

  // Request a new model definition or if we already have created one - reuse it
  LDef := BuildModelDef(ATemplate.Id, LKind, LBmp);

  // Take the definition object and create a visual representation
  LModel := TGorillaModel.LoadNewModelFromDef(FOwner, LDef,
    GORILLA_ANIMATION_CACHING_DEFAULT);
  LModel.Parent := FViewport;
  LModel.SetHitTestValue(false);
  LModel.SetTwoSide(true);
  LModel.FrustumCullingCheck := False;

  // !!! if the model is getting destroyed we do not destroy the multiple referenced definition
  LModel.IsDefOwner := false;

  LSpawn := TSpawnedElement.Create();
  LSpawn.FModel     := LModel;
  LSpawn.FDef       := LDef;
  LSpawn.FKind      := LKind;
  LSpawn.FSpeciesId := ATemplate.Id;    // Schwarm bilden nur Fische gleicher Vorlage
  LSpawn.FBaseW     := AQUARIUM_BASE_W[LKind];
  LSpawn.FBaseH     := AQUARIUM_BASE_H[LKind];
  LSpawn.FScale     := 1.0;
  // Hoechstgeschwindigkeit leicht variieren -> Schwarm wirkt natuerlicher.
  LSpawn.FMaxSpeed  := FISH_MAX_SPEED * (0.8 + Random * 0.4);
  LSpawn.ApplyScale();

  // Eigen-Animation starten ('self' = ruhiges Wabbeln). Der Loop kommt aus
  // dem Interpolator-Def (LInter.Loop := True in BuildModelDef).
  if Assigned(LModel.AnimationManager)
  and (LModel.AnimationManager.Animations.Count > 0) then
  begin
    LAnim := LModel.AnimationManager.GetAnimation('self');
    LModel.AnimationManager.PlayAnimation(LAnim);
  end;

  Result := LSpawn;
end;

function TAquariumScene.Spawn(ATemplate: TGorillaInventoryItemTemplate): TSpawnedElement;
var LSpawn : TSpawnedElement;
begin
  LSpawn := BuildSpawn(ATemplate);
  if not Assigned(LSpawn) then
    Exit(nil);

  // Inventar-Instanz (Collectable) dieser Vorlage anlegen und wechselseitig
  // verknuepfen. Build() liefert nil, falls (theoretisch) nicht sammelbar.
  LSpawn.FCollectable := ATemplate.Build();
  if Assigned(LSpawn.FCollectable) then
    LSpawn.FCollectable.Data := TValue.From<TSpawnedElement>(LSpawn);

  // Startposition (Tank: X/Z ca. [-8..8], Boden bei Y~7, Oberflaeche Y~0).
  // Fische/Quallen schwimmen frei im Raum (X/Y/Z); Pflanzen/Korallen wurzeln.
  case LSpawn.FKind of
    akFish, akJellyfish:
      LSpawn.SetBasePosition(Point3D(
        TANK_MIN_X + Random * (TANK_MAX_X - TANK_MIN_X),
        TANK_MIN_Y + Random * (TANK_MAX_Y - TANK_MIN_Y),
        TANK_MIN_Z + Random * (TANK_MAX_Z - TANK_MIN_Z)));
    akPlant, akCoral:
      // Wurzel am Boden: Mittelpunkt um halbe Hoehe nach oben (= kleineres Y)
      LSpawn.SetBasePosition(Point3D(
        -7 + Random * 14, 7.2 - LSpawn.FBaseH / 2, -7 + Random * 12));
  end;

  FItems.Add(LSpawn);
  Result := LSpawn;

  if Assigned(FOnSpawnedElement) then
    FOnSpawnedElement(Self, ATemplate, LSpawn);
end;

function TAquariumScene.SpawnFromCollectable(
  ACollectable: TGorillaInventoryCollectable): TSpawnedElement;
var
  LSpawn : TSpawnedElement;
  LPos   : TPoint3D;
  LScale : Single;
  LVal   : TValue;
begin
  Result := nil;
  if not Assigned(ACollectable) or not Assigned(ACollectable.Template) then
    Exit;

  LSpawn := BuildSpawn(ACollectable.Template);
  if not Assigned(LSpawn) then
    Exit;

  // den bereits geladenen Collectable wiederverwenden (NICHT Build aufrufen)
  LSpawn.FCollectable := ACollectable;
  ACollectable.Data := TValue.From<TSpawnedElement>(LSpawn);

  // Position/Groesse aus den Parametern wiederherstellen (Defaults: Tankmitte)
  LPos   := Point3D(0, 4.5, 0);
  LScale := 1.0;
  ReadXformParam(ACollectable, LPos, LScale);

  LSpawn.SetSizeScale(LScale);
  LSpawn.SetBasePosition(LPos);

  // Lebenspunkte wiederherstellen (aeltere Setups ohne Wert: voll).
  if (LSpawn.FKind = akFish)
  and ACollectable.Parameters.TryGetValue(PARAM_HEALTH, LVal) then
  begin
    LSpawn.FHealth := EnsureRange(StrToFloatDef(LVal.ToString(), FISH_HEALTH_MAX,
      TFormatSettings.Invariant), 1.0, FISH_HEALTH_MAX);
    if LSpawn.FHealth < FISH_HEALTH_MAX then
      LSpawn.FSatedTime := 0;
  end;

  // Bewegung aufnehmen, ohne die wiederhergestellte Position zu veraendern
  // (anders als der Frozen-Setter, der Fisch/Qualle neu auf Z verteilt).
  LSpawn.FFrozen := False;
  if LSpawn.FKind in [akFish, akJellyfish] then
  begin
    LSpawn.FWanderDir := RandomUnit3D();
    if LSpawn.FKind = akFish then
      LSpawn.FVelocity := LSpawn.FWanderDir * (LSpawn.FMaxSpeed * 0.4)
    else
      LSpawn.FVelocity := LSpawn.FWanderDir * 0.3;
  end;

  FItems.Add(LSpawn);
  Result := LSpawn;

  if Assigned(FOnSpawnedElement) then
    FOnSpawnedElement(Self, ACollectable.Template, LSpawn);
end;

procedure TAquariumScene.Remove(ASpawn: TSpawnedElement);
var LDef : TModelDef;
begin
  if not Assigned(ASpawn) then
    Exit;

  // Inventar-Instanz wieder abwerfen (haelt Becken-Liste und Szene synchron).
  if Assigned(ASpawn.FCollectable) then
  begin
    ASpawn.FCollectable.Inventory.DropCollectedItem(ASpawn.FCollectable, -1);
    ASpawn.FCollectable := nil;
  end;

  // Das Model wird vom Formular (FOwner) verwaltet; explizites Freigeben
  // entfernt es aus der Szene. Sein ModelDef bleibt erhalten - es ist
  // geteilt und gehoert der Szene (IsDefOwner = False).
  if Assigned(ASpawn.FModel) then
  begin
    ASpawn.FModel.Parent := nil;
    ASpawn.FModel.Free();
    ASpawn.FModel := nil;
  end;

  LDef := ASpawn.FDef;
  FItems.Remove(ASpawn);   // OwnsObjects -> gibt nur das Wrapper-Objekt frei

  // War das die letzte Instanz einer geaenderten/geloeschten Vorlage?
  ReleaseRetiredDef(LDef);
end;

function TAquariumScene.IsDefInUse(ADef: TModelDef): Boolean;
var i : Integer;
begin
  for i := 0 to FItems.Count - 1 do
    if FItems[i].FDef = ADef then
      Exit(True);
  Result := False;
end;

procedure TAquariumScene.ReleaseRetiredDef(ADef: TModelDef);
begin
  if not Assigned(ADef) or not FRetiredDefs.Contains(ADef) then
    Exit;   // nicht ausgemustert (noch im Cache) -> bleibt erhalten
  if IsDefInUse(ADef) then
    Exit;
  FRetiredDefs.Remove(ADef);
  ADef.Free();
end;

procedure TAquariumScene.InvalidateModelDef(const ATemplateId: String);
var LDef : TModelDef;
begin
  if not FModelDefs.TryGetValue(ATemplateId, LDef) then
    Exit;
  FModelDefs.Remove(ATemplateId);

  if IsDefInUse(LDef) then
    FRetiredDefs.Add(LDef)     // Freigabe mit der letzten Instanz (Remove)
  else
    LDef.Free();
end;

procedure TAquariumScene.ClearScene();
begin
  // rueckwaerts entfernen; Remove() wirft auch die zugehoerigen Collectables ab
  while FItems.Count > 0 do
    Remove(FItems[FItems.Count - 1]);
end;

procedure TAquariumScene.SyncCollectables();
var
  i     : Integer;
  LEl   : TSpawnedElement;
  LPos  : TPoint3D;
  LFmt  : TFormatSettings;
  LStr  : String;
begin
  LFmt := TFormatSettings.Invariant;
  for i := 0 to FItems.Count - 1 do
  begin
    LEl := FItems[i];
    if not Assigned(LEl.FCollectable) or not Assigned(LEl.FModel) then
      Continue;

    LPos := LEl.FModel.Position.Point;
    // Position + Groesse als "px;py;pz;scale" ablegen.
    LStr := FloatToStr(LPos.X, LFmt) + XFORM_SEP + FloatToStr(LPos.Y, LFmt) +
            XFORM_SEP + FloatToStr(LPos.Z, LFmt) + XFORM_SEP +
            FloatToStr(LEl.FScale, LFmt);
    LEl.FCollectable.Parameters.AddOrSetValue(PARAM_XFORM, TValue.From<String>(LStr));
    if LEl.FKind = akFish then
      LEl.FCollectable.Parameters.AddOrSetValue(PARAM_HEALTH,
        TValue.From<String>(FloatToStr(LEl.FHealth, LFmt)));
  end;
end;

procedure TAquariumScene.RestoreFromInventory(AInventory: TGorillaInventory);
var
  i     : Integer;
  LColls : TArray<TGorillaInventoryCollectable>;
begin
  if not Assigned(AInventory) then
    Exit;

  // Snapshot der Collectables ziehen (SpawnFromCollectable aendert die Sammlung
  // nicht, aber so sind wir gegen kuenftige Aenderungen abgesichert).
  SetLength(LColls, AInventory.CollectedItems.Count);
  for i := 0 to AInventory.CollectedItems.Count - 1 do
    LColls[i] := AInventory.CollectedItems.Items[i] as TGorillaInventoryCollectable;

  for i := Low(LColls) to High(LColls) do
    SpawnFromCollectable(LColls[i]);
end;

procedure TAquariumScene.EnsureFoodMaterial();
begin
  if Assigned(FFoodMat) then
    Exit;
  // Gemeinsames Material aller Futterkapseln (warmes Orange). Emissive sorgt
  // dafuer, dass die Kugeln auch ohne direkte Beleuchtung gut sichtbar sind.
  FFoodMat := TGorillaLambertMaterialSource.Create(FOwner);
  FFoodMat.Diffuse  := TAlphaColor($FFFF4500);   // Orangerot
  FFoodMat.Ambient  := TAlphaColor($FF402000);
  FFoodMat.Emissive := TAlphaColor($FF904010);

  FFoodMat.UseLighting := true;
  FFoodMat.UseTexture0 := false;
end;

procedure TAquariumScene.DropFood(const APos: TPoint3D);
var
  LFood : TFoodPellet;
  LSph  : TGorillaSphere;
  d     : Single;
  LPrefab : TGorillaColliderSettings;
begin
  if not Assigned(FViewport) then
    Exit;

  EnsureFoodMaterial();

  LSph := TGorillaSphere.Create(FOwner);
  LSph.Parent := FViewport;
  LSph.SubdivisionsAxes := 10;
  LSph.SubdivisionsHeight := 8;
  d := FOOD_RADIUS * 2;
  LSph.Width  := d;
  LSph.Height := d;
  LSph.Depth  := d;
  LSph.SetHitTestValue(false);
  LSph.MaterialSource := FFoodMat;
  LSph.Position.Point := APos;

  LFood := TFoodPellet.Create();
  LFood.FModel := LSph;
  LFood.FVel   := Point3D((Random - 0.5) * 0.3, 0.2, (Random - 0.5) * 0.3);
  LFood.FAge   := 0;
  LFood.FEaten := False;
  FFood.Add(LFood);

  // Add to physics system for collision detection
  LPrefab := TGorillaColliderSettings.Create(TGorillaPhysicsBodyType.eDynamicBody);
  LPrefab.LinearDamping := 10; // simulate sinking down
  PhysicsSystem.AddSphereCollider(LSph, LPrefab);

  if Assigned(FOnSpawnedFoodPellet) then
    FOnSpawnedFoodPellet(Self, LFood);
end;

procedure TAquariumScene.AssignFood();
type
  TCandidate = record
    Score : Single;
    Fish  : TSpawnedElement;
    Food  : TFoodPellet;
  end;
var
  i, k : Integer;
  LFish : TSpawnedElement;
  LFood : TFoodPellet;
  d : Single;
  LCands : TList<TCandidate>;
  LCand  : TCandidate;
  LTaken : TList<TFoodPellet>;
begin
  for i := 0 to FItems.Count - 1 do
    FItems[i].FFoodTarget := nil;
  if FFood.Count = 0 then
    Exit;

  // Alle Paare (hungriger Fisch, Kapsel in Sichtweite) mit Bewertung sammeln:
  // Abstand minus Hunger-Bonus. Kleinere Bewertung = hoeherer Vorrang.
  LCands := TList<TCandidate>.Create();
  LTaken := TList<TFoodPellet>.Create();
  try
    for i := 0 to FItems.Count - 1 do
    begin
      LFish := FItems[i];
      // Satte Fische (100 Lebenspunkte) lassen das Futter links liegen.
      if (LFish.FKind <> akFish) or LFish.FDead or LFish.FFrozen
      or not Assigned(LFish.FModel) or (LFish.FHealth >= FISH_HEALTH_MAX) then
        Continue;

      for k := 0 to FFood.Count - 1 do
      begin
        LFood := FFood[k];
        if LFood.FEaten or not Assigned(LFood.FModel) then
          Continue;
        d := (LFood.Position - LFish.FModel.Position.Point).Length;
        if d >= FOOD_SENSE then
          Continue;
        LCand.Score := d - FOOD_PRIORITY_DIST * (FISH_HEALTH_MAX - LFish.FHealth);
        LCand.Fish  := LFish;
        LCand.Food  := LFood;
        LCands.Add(LCand);
      end;
    end;

    LCands.Sort(TComparer<TCandidate>.Construct(
      function(const A, B: TCandidate): Integer
      begin
        Result := CompareValue(A.Score, B.Score);
      end));

    // Gierig zuteilen: bestes Paar zuerst, Fisch und Kapsel je nur einmal.
    for LCand in LCands do
      if not Assigned(LCand.Fish.FFoodTarget)
      and not LTaken.Contains(LCand.Food) then
      begin
        LCand.Fish.FFoodTarget := LCand.Food;
        LTaken.Add(LCand.Food);
      end;
  finally
    LTaken.Free();
    LCands.Free();
  end;
end;

procedure TAquariumScene.UpdateFood(ADt: Single);
var
  i   : Integer;
  LF  : TFoodPellet;
begin
  for i := FFood.Count - 1 downto 0 do
  begin
    LF := FFood[i];
    LF.FAge := LF.FAge + ADt;

    if LF.FEaten or (LF.FAge > FOOD_LIFETIME) or not Assigned(LF.FModel) then
    begin
      if Assigned(LF.FModel) then
      begin
        // Remove from physics again
        PhysicsSystem.RemoveCollider(LF.FModel);

        LF.FModel.Parent := nil;
        LF.FModel.Free();
        LF.FModel := nil;
      end;
      FFood.Delete(i);    // OwnsObjects -> gibt das Pellet-Objekt frei
      Continue;
    end;
  end;
end;

function TAquariumScene.SteerJelly(AJelly: TSpawnedElement; ADt: Single): TPoint3D;
var
  LPos, LAcc, LDesired : TPoint3D;
begin
  LPos := AJelly.FModel.Position.Point;
  LAcc := TPoint3D.Zero;

  // Sanftes Wandern: Wunschrichtung langsam verdrehen.
  AJelly.FWanderDir := NormSafe(AJelly.FWanderDir + RandomUnit3D() * (1.4 * ADt));
  LDesired := AJelly.FWanderDir * 0.5;       // gemaechliches Tempo
  LAcc := LAcc + (LDesired - AJelly.FVelocity) * 0.6;

  // Vertikales Schweben (Auf/Ab-Pulsieren), zeitversetzt je Instanz.
  AJelly.FPhase := AJelly.FPhase + ADt;
  LAcc.Y := LAcc.Y + 0.6 * Sin(AJelly.FPhase * 1.2);

  // In den Grenzen halten.
  if LPos.X < TANK_MIN_X + TANK_MARGIN then LAcc.X := LAcc.X + W_BOUNDS
  else if LPos.X > TANK_MAX_X - TANK_MARGIN then LAcc.X := LAcc.X - W_BOUNDS;
  if LPos.Y < TANK_MIN_Y + TANK_MARGIN then LAcc.Y := LAcc.Y + W_BOUNDS
  else if LPos.Y > TANK_MAX_Y - TANK_MARGIN then LAcc.Y := LAcc.Y - W_BOUNDS;
  if LPos.Z < TANK_MIN_Z + TANK_MARGIN then LAcc.Z := LAcc.Z + W_BOUNDS
  else if LPos.Z > TANK_MAX_Z - TANK_MARGIN then LAcc.Z := LAcc.Z - W_BOUNDS;

  Result := LAcc;
end;

function TAquariumScene.SteerFish(AFish: TSpawnedElement): TPoint3D;
var
  i : Integer;
  LOther : TSpawnedElement;
  LPos, LDiff, LAcc : TPoint3D;
  LSep, LAli, LCoh  : TPoint3D;
  LCount, LDist     : Single;
  LFood : TFoodPellet;
begin
  LPos := AFish.FModel.Position.Point;
  LAcc := TPoint3D.Zero;
  LSep := TPoint3D.Zero;
  LAli := TPoint3D.Zero;
  LCoh := TPoint3D.Zero;
  LCount := 0;

  for i := 0 to FItems.Count - 1 do
  begin
    LOther := FItems[i];
    if (LOther = AFish) or (LOther.FKind <> akFish) or LOther.FDead
    or not Assigned(LOther.FModel) then
      Continue;

    LDiff := LPos - LOther.FModel.Position.Point;
    LDist := LDiff.Length;
    if LDist < 0.0001 then
      Continue;

    // Separation: Abstand zu ALLEN Fischen halten (Kollisionsvermeidung).
    if LDist < SEP_RADIUS then
      LSep := LSep + LDiff * (1.0 / (LDist * LDist));

    // Ausrichtung + Zusammenhalt: nur Fische gleicher Zeichnung (Schwarm).
    if (LDist < NEIGH_RADIUS) and (LOther.FSpeciesId = AFish.FSpeciesId) then
    begin
      LAli := LAli + LOther.FVelocity;
      LCoh := LCoh + LOther.FModel.Position.Point;
      LCount := LCount + 1;
    end;
  end;

  LAcc := LAcc + NormSafe(LSep) * W_SEPARATION;

  if LCount > 0 then
  begin
    // Ausrichtung: in die mittlere Schwimmrichtung der Artgenossen einschwenken.
    LAcc := LAcc + (NormSafe(LAli) * AFish.FMaxSpeed - AFish.FVelocity) * (W_ALIGNMENT / AFish.FMaxSpeed);
    // Zusammenhalt: zum Schwerpunkt der Artgenossen ziehen.
    LCoh := LCoh * (1.0 / LCount);
    LAcc := LAcc + NormSafe(LCoh - LPos) * W_COHESION;
  end;

  // Futtersuche: naechste Kapsel ansteuern. Beim Jagen wird NICHT mehr gewandert,
  // sonst umkreist der Fisch die Kapsel, statt sie zu treffen. Solange er jagt,
  // schwimmt er im schnellen Modus (Schwanz betont).
  // Welche Kapsel ein Fisch ansteuert, legt AssignFood fest (hungrige zuerst,
  // satte gar nicht) - so frisst ein Fisch auch nur "seine" Kapsel.
  LFood := AFish.FFoodTarget;
  if Assigned(LFood) and not LFood.FEaten then
  begin
    LDiff := LFood.Position - LPos;
    LDist := LDiff.Length;
    LAcc := LAcc + NormSafe(LDiff) * W_FOOD;
    AFish.FastSwim := True;

    // Fressen: Fische sind grosse Sprites - die "Schnauze" reicht etwa eine
    // halbe Koerperbreite weit. Daher Fressdistanz an die Fischgroesse koppeln
    // (Modell-Breite = FBaseW * FScale), mit sinnvollem Minimum.
    if LDist < Max(0.9, 0.5 * AFish.FBaseW * AFish.FScale) + FOOD_RADIUS then
    begin
      LFood.FEaten := True;
      AFish.FHealth := Min(FISH_HEALTH_MAX, AFish.FHealth + FISH_FOOD_VALUE);
      // Voll gefressen -> eine Weile satt bleiben (frisst dann nicht mehr).
      if AFish.FHealth >= FISH_HEALTH_MAX then
        AFish.FSatedTime := FISH_SATED_TIME;
    end;
  end
  else
  begin
    AFish.FastSwim := False;
    // Wandern nur ohne Futterziel: Wunschrichtung leicht verdrehen -> Streifzuege.
    AFish.FWanderDir := NormSafe(AFish.FWanderDir + RandomUnit3D() * 0.35);
    LAcc := LAcc + AFish.FWanderDir * W_WANDER;
  end;

  // In den Grenzen halten (sanft nach innen lenken, bevor hart geklemmt wird).
  if LPos.X < TANK_MIN_X + TANK_MARGIN then LAcc.X := LAcc.X + W_BOUNDS
  else if LPos.X > TANK_MAX_X - TANK_MARGIN then LAcc.X := LAcc.X - W_BOUNDS;
  if LPos.Y < TANK_MIN_Y + TANK_MARGIN then LAcc.Y := LAcc.Y + W_BOUNDS
  else if LPos.Y > TANK_MAX_Y - TANK_MARGIN then LAcc.Y := LAcc.Y - W_BOUNDS;
  if LPos.Z < TANK_MIN_Z + TANK_MARGIN then LAcc.Z := LAcc.Z + W_BOUNDS
  else if LPos.Z > TANK_MAX_Z - TANK_MARGIN then LAcc.Z := LAcc.Z - W_BOUNDS;

  Result := LAcc;
end;

procedure TAquariumScene.SetTint(AFish: TSpawnedElement;
  const AColor: TAlphaColorF; AAmount: Single);
var
  i : Integer;
  LMat : TGorillaDefaultMaterialSource;
  LSum : TAlphaColorF;
begin
  if not Assigned(AFish.FModel) or not Assigned(AFish.FModel.Meshes) then
    Exit;
  if (AAmount <= 0) and not AFish.FTinted then
    Exit;

  for i := 0 to AFish.FModel.Meshes.Count - 1 do
  begin
    if not (AFish.FModel.Meshes[i].MaterialSource is TGorillaDefaultMaterialSource) then
      Continue;
    LMat := TGorillaDefaultMaterialSource(AFish.FModel.Meshes[i].MaterialSource);

    // Ohne Beleuchtung ergibt sich die Farbe aus Textur * (Ambient + Diffuse +
    // Specular + Emissive). Die Summe liegt ueber 1, nur Diffuse zu senken
    // wuerde daher kaum auffallen. Beim Einfaerben wird deshalb die gesamte
    // Summe in Diffuse gelegt und von dort zur Zielfarbe ueberblendet.
    if not AFish.FTinted then
    begin
      AFish.FBaseAmb  := LMat.AmbientF;
      AFish.FBaseDif  := LMat.DiffuseF;
      AFish.FBaseSpec := LMat.SpecularF;
    end;

    if AAmount <= 0 then
    begin
      LMat.AmbientF  := AFish.FBaseAmb;
      LMat.DiffuseF  := AFish.FBaseDif;
      LMat.SpecularF := AFish.FBaseSpec;
    end
    else
    begin
      LSum.R := Min(1, AFish.FBaseAmb.R + AFish.FBaseDif.R + AFish.FBaseSpec.R);
      LSum.G := Min(1, AFish.FBaseAmb.G + AFish.FBaseDif.G + AFish.FBaseSpec.G);
      LSum.B := Min(1, AFish.FBaseAmb.B + AFish.FBaseDif.B + AFish.FBaseSpec.B);
      LMat.AmbientF  := TAlphaColorF.Create(0, 0, 0, AFish.FBaseAmb.A);
      LMat.SpecularF := TAlphaColorF.Create(0, 0, 0, AFish.FBaseSpec.A);
      LMat.DiffuseF  := TAlphaColorF.Create(
        LSum.R + (AColor.R - LSum.R) * AAmount,
        LSum.G + (AColor.G - LSum.G) * AAmount,
        LSum.B + (AColor.B - LSum.B) * AAmount,
        AFish.FBaseDif.A);
    end;
  end;
  AFish.FTinted := AAmount > 0;
end;

procedure TAquariumScene.UpdateHealth(AFish: TSpawnedElement; ADt, ATime: Single);
var
  LHunger, LWave : Single;
begin
  // Satt: Lebenspunkte bleiben eine Weile auf dem Maximum, danach Hunger.
  if AFish.FSatedTime > 0 then
    AFish.FSatedTime := AFish.FSatedTime - ADt
  else
    AFish.FHealth := AFish.FHealth - FISH_HUNGER_RATE * ADt;

  if AFish.FHealth <= 0 then
  begin
    // Verhungert: grau faerben, Wabbeln anhalten, bauchoben drehen.
    AFish.FHealth := 0;
    AFish.FDead := True;
    AFish.FDeadTime := 0;
    AFish.FastSwim := False;
    AFish.FFoodTarget := nil;
    SetTint(AFish, TINT_DEAD, 1);
    if Assigned(AFish.FModel.AnimationManager)
    and Assigned(AFish.FModel.AnimationManager.Current) then
      AFish.FModel.AnimationManager.Current.StopAtCurrent();
    AFish.FModel.RotationAngle.X := 180;
    Exit;
  end;

  // Rechtzeitige Warnung in zwei Stufen:
  //  - hungrig (< FISH_HEALTH_WARN): langsames Pulsieren ins blasse Gruen, das
  //    mit sinkenden Lebenspunkten kraeftiger wird.
  //  - kritisch (< FISH_HEALTH_CRIT): schnelles Blinken ins Dunkle - der Fisch
  //    stirbt bald, wenn er nicht frisst.
  if AFish.FHealth < FISH_HEALTH_CRIT then
  begin
    LWave := 0.5 + 0.5 * Sin(ATime * 12.0 + AFish.FPhase);
    SetTint(AFish, TINT_CRIT, 0.25 + 0.75 * LWave);
  end
  else if AFish.FHealth < FISH_HEALTH_WARN then
  begin
    LHunger := (FISH_HEALTH_WARN - AFish.FHealth) / (FISH_HEALTH_WARN - FISH_HEALTH_CRIT);
    LWave := 0.5 + 0.5 * Sin(ATime * 3.5 + AFish.FPhase);
    SetTint(AFish, TINT_SICK, LWave * (0.45 + 0.55 * LHunger));
  end
  else
    SetTint(AFish, TINT_SICK, 0);   // wieder satt -> Originalfarben
end;

procedure TAquariumScene.UpdateDead(AFish: TSpawnedElement; ADt: Single);
var LPos : TPoint3D;
begin
  AFish.FDeadTime := AFish.FDeadTime + ADt;

  // Langsam zur Oberflaeche treiben (kleineres Y = weiter oben).
  LPos := AFish.FModel.Position.Point;
  if LPos.Y > DEAD_FLOAT_Y then
    LPos.Y := Max(DEAD_FLOAT_Y, LPos.Y - DEAD_FLOAT_SPEED * ADt);
  AFish.FModel.Position.Point := LPos;
  AFish.FVelocity := TPoint3D.Zero;
end;

procedure TAquariumScene.Animate(ATime: Single);
var
  i  : Integer;
  dt : Single;
  LEl : TSpawnedElement;
  LGone : TList<TSpawnedElement>;
begin
  // Zeitschritt aus aufeinanderfolgenden Aufrufen ableiten und begrenzen,
  // damit ein Ruckler (grosses dt) die Bewegung nicht explodieren laesst.
  if FLastTime < 0 then
    dt := 0
  else
    dt := ATime - FLastTime;
  FLastTime := ATime;
  if dt <= 0 then
    Exit;
  if dt > 0.1 then
    dt := 0.1;

  // Futter zuerst aktualisieren (sinken/aufloesen) -> Fische sehen aktuellen Stand.
  UpdateFood(dt);
  // Danach Kapseln zuteilen (verweist nur auf noch lebende Kapseln).
  AssignFood();

  for i := 0 to FItems.Count - 1 do
  begin
    LEl := FItems[i];
    if LEl.FFrozen or not Assigned(LEl.FModel) then
      Continue;

    if LEl.FDead then
    begin
      UpdateDead(LEl, dt);
      Continue;
    end;

    case LEl.FKind of
      akFish      :
        begin
          LEl.ApplyMotion(SteerFish(LEl), dt);
          UpdateHealth(LEl, dt, ATime);
        end;
      akJellyfish : LEl.ApplyMotion(SteerJelly(LEl, dt), dt);
      // Pflanze/Koralle: keine Raumbewegung (nur gebackenes Schwingen).
    end;
  end;

  // Tote Fische nach einer Weile entfernen - erst nach der Schleife, da
  // Remove() die Liste veraendert. Remove() wirft auch das Collectable ab.
  LGone := nil;
  try
    for i := 0 to FItems.Count - 1 do
      if FItems[i].FDead and (FItems[i].FDeadTime > DEAD_REMOVE_TIME) then
      begin
        if not Assigned(LGone) then
          LGone := TList<TSpawnedElement>.Create();
        LGone.Add(FItems[i]);
      end;
    if Assigned(LGone) then
      for LEl in LGone do
        Remove(LEl);
  finally
    LGone.Free();
  end;
end;

end.
