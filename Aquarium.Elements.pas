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
  System.Math.Vectors, System.Generics.Collections, System.IOUtils,
  FMX.Types, FMX.Graphics, FMX.Types3D, FMX.Controls3D, FMX.Materials, FMX.Ani,
  Gorilla.Viewport, Gorilla.Mesh, Gorilla.Model, Gorilla.DefTypes,
  Gorilla.Loader, Gorilla.Animation, Gorilla.AssetsManager,
  Gorilla.Material.Default;

type
  /// <summary>Art eines Aquariumselements - bestimmt Aussehen und Animation.</summary>
  TAquariumKind = (akFish, akJellyfish, akPlant, akCoral);

  /// <summary>
  ///  Ein gespeichertes (gezeichnetes) Aquariumselement: Name, Art und das
  ///  zugehoerige Bild (das spaeter als Textur verwendet wird).
  /// </summary>
  TAquariumElement = class
  private
    FName     : String;
    FKind     : TAquariumKind;
    FFileName : String;       // absoluter Pfad zur PNG-Datei
    FBitmap   : TBitmap;      // im Speicher gehaltene Kopie der Zeichnung
  public
    constructor Create(const AName: String; AKind: TAquariumKind;
      const AFileName: String; ABitmap: TBitmap);
    destructor Destroy(); override;

    /// <summary>Aktualisiert Art, Name und Bild (z.B. beim Ueberschreiben).</summary>
    procedure Update(AKind: TAquariumKind; const AName: String; ABitmap: TBitmap);

    property Name     : String        read FName;
    property Kind     : TAquariumKind read FKind;
    property FileName : String        read FFileName;
    property Bitmap   : TBitmap       read FBitmap;
  end;

  /// <summary>
  ///  Verwaltet alle gespeicherten Elemente und kuemmert sich um Persistenz.
  ///  Die Bilder werden als PNG im Dokumente-Ordner abgelegt, eine kleine
  ///  Manifest-Datei haelt Name + Art + Dateiname je Zeile fest.
  /// </summary>
  TAquariumLibrary = class
  private
    FItems        : TObjectList<TAquariumElement>;
    FElementsDir  : String;
    FManifestPath : String;
    procedure EnsureDirectories();
    procedure SaveManifest();
  public
    constructor Create();
    destructor Destroy(); override;

    /// <summary>Liest das Manifest und laedt alle gespeicherten Elemente.</summary>
    procedure LoadFromDisk();

    /// <summary>
    ///  Speichert eine Zeichnung als neues Element. Es wird eine PNG-Datei
    ///  erzeugt, das Manifest geschrieben und das Element in die Liste
    ///  aufgenommen. Das Ergebnis ist das neu erstellte Element.
    /// </summary>
    function SaveElement(AKind: TAquariumKind; const AName: String;
      ASource: TBitmap): TAquariumElement;

    /// <summary>
    ///  Ueberschreibt ein vorhandenes Element (gleiche Datei) mit neuer Art,
    ///  neuem Namen und neuer Zeichnung.
    /// </summary>
    procedure UpdateElement(AIndex: Integer; AKind: TAquariumKind;
      const AName: String; ASource: TBitmap);

    /// <summary>Loescht ein Element samt PNG-Datei und Manifest-Eintrag.</summary>
    procedure DeleteElement(AIndex: Integer);

    property Items : TObjectList<TAquariumElement> read FItems;
  end;

  /// <summary>
  ///  Eine in der Szene platzierte Instanz eines Elements. Haelt das
  ///  TGorillaModel (mit laufender Eigen-Animation) und die Parameter fuer die
  ///  pro-Frame berechnete Raumbewegung.
  /// </summary>
  TSpawnedElement = class
  private
    FModel     : TGorillaModel;
    FKind      : TAquariumKind;
    FBasePos   : TPoint3D;
    FBaseW     : Single;        // Grundbreite der Art (lokale Quad-Groesse)
    FBaseH     : Single;        // Grundhoehe der Art
    FScale     : Single;        // per Mausrad eingestellte Groesse
    FFrozen    : Boolean;
    FFastSwim  : Boolean;            // schaltet zwischen 'self'- und 'fast'-Wabbeln
    FMoveAnim  : TPoint3DAnimation;  // entkoppelte Raumbewegung (Eigentum des Models)
    FMoveDur   : Single;             // Dauer eines Bewegungs-Hin/Her (variiert je Instanz)
    FLastX     : Single;             // letzte X-Position (fuer die Blickrichtung)
    procedure ApplyScale();
    procedure SetFrozen(const AValue: Boolean);
    procedure SetFastSwim(const AValue: Boolean);
    /// <summary>Konfiguriert die Raumbewegung um FBasePos und startet sie.</summary>
    procedure StartMovement();
  public
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
    ///  Im eingefrorenen Zustand bleibt das Element exakt an seiner Position
    ///  (es wabbelt nur), bewegt sich aber nicht frei. Wird fuer die
    ///  Maus-Vorschau verwendet. Das Umschalten stoppt bzw. startet die
    ///  entkoppelte Raumbewegung (TPoint3DAnimation).
    /// </summary>
    property Frozen : Boolean read FFrozen write SetFrozen;
    /// <summary>
    ///  Schaltet das Wabbeln zwischen dem ruhigen Grundzustand ('self') und dem
    ///  schnellen Schwimmen ('fast', schnellere Welle + staerkere Schwanzflosse)
    ///  um. Nur Fische besitzen die 'fast'-Animation; bei anderen Arten wirkungslos.
    /// </summary>
    property FastSwim : Boolean read FFastSwim write SetFastSwim;
  end;

  /// <summary>
  ///  Verwaltet alle in der Szene platzierten Elemente und treibt deren
  ///  Animation. Animate() muss regelmaessig (z.B. per Timer) aufgerufen werden.
  /// </summary>
  TAquariumScene = class
  private
    FViewport  : TGorillaViewport;
    FOwner     : TComponent;
    FModelDefs : TDictionary<String, TModelDef>;
    FItems     : TObjectList<TSpawnedElement>;
    /// <summary>
    ///  Baut ein frisches ModelDef (Quad-Mesh, texturiertes Material und
    ///  Eigen-Animation). Die gezeichnete Textur wird direkt ins Material-Def
    ///  gelegt; das Materialisieren erzeugt daraus automatisch die MaterialSource.
    ///  Das Eigentum am Def geht an das TGorillaModel ueber (gibt es selbst frei)
    ///  -> daher pro Spawn neu.
    /// </summary>
    function BuildModelDef(const AName: String; AKind: TAquariumKind;
      ABitmap: TBitmap): TModelDef;
  public
    constructor Create(AViewport: TGorillaViewport; AOwner: TComponent);
    destructor Destroy(); override;

    /// <summary>Platziert ein Element als animiertes Model in der Szene.</summary>
    function Spawn(AElement: TAquariumElement): TSpawnedElement;

    /// <summary>Entfernt ein platziertes Element wieder aus der Szene.</summary>
    procedure Remove(ASpawn: TSpawnedElement);

    /// <summary>Aktualisiert die Animation aller platzierten Elemente.</summary>
    procedure Animate(ATime: Single);
  end;

const
  /// <summary>Anzeigenamen der Arten (Reihenfolge wie TAquariumKind).</summary>
  AQUARIUM_KIND_NAMES : array[TAquariumKind] of String =
    ('Fisch', 'Qualle', 'Pflanze', 'Koralle');

function AquariumKindToStr(AKind: TAquariumKind): String;
function StrToAquariumKind(const AValue: String): TAquariumKind;

implementation

uses
  System.RTLConsts,
  System.Generics.Defaults;

const
  MANIFEST_SEP   = '|';
  SUBDIVISIONS   = 24;     // Aufloesung des Quad-Meshes (pro Achse)
  ANIM_KEYS      = 24;     // Keyframes pro Loop der Eigen-Animation

  // Grundgroesse (lokale Quad-Breite/Hoehe) je Art - Reihenfolge wie TAquariumKind.
  AQUARIUM_BASE_W : array[TAquariumKind] of Single = (2.6, 2.2, 2.2, 2.6);
  AQUARIUM_BASE_H : array[TAquariumKind] of Single = (1.9, 2.4, 3.4, 2.2);

  // Loop-Dauer der Eigen-Animation je Art (Sekunden).
  AQUARIUM_LOOP_S : array[TAquariumKind] of Single = (1.6, 2.6, 3.0, 3.4);

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

{ TAquariumElement }

constructor TAquariumElement.Create(const AName: String; AKind: TAquariumKind;
  const AFileName: String; ABitmap: TBitmap);
begin
  inherited Create();
  FName     := AName;
  FKind     := AKind;
  FFileName := AFileName;
  FBitmap   := TBitmap.Create();
  if Assigned(ABitmap) then
    FBitmap.Assign(ABitmap);
end;

destructor TAquariumElement.Destroy();
begin
  FBitmap.Free();
  inherited;
end;

procedure TAquariumElement.Update(AKind: TAquariumKind; const AName: String;
  ABitmap: TBitmap);
begin
  FKind := AKind;
  FName := AName;
  if Assigned(ABitmap) then
    FBitmap.Assign(ABitmap);
end;

{ TAquariumLibrary }

constructor TAquariumLibrary.Create();
begin
  inherited Create();
  FItems := TObjectList<TAquariumElement>.Create(True);

  FElementsDir  := TPath.Combine(
    TPath.Combine(TPath.GetDocumentsPath, 'SketchQuarium'), 'elements');
  FManifestPath := TPath.Combine(FElementsDir, 'elements.idx');

  EnsureDirectories();
end;

destructor TAquariumLibrary.Destroy();
begin
  FItems.Free();
  inherited;
end;

procedure TAquariumLibrary.EnsureDirectories();
begin
  if not TDirectory.Exists(FElementsDir) then
    TDirectory.CreateDirectory(FElementsDir);
end;

procedure TAquariumLibrary.LoadFromDisk();
var
  LLines   : TStringList;
  i        : Integer;
  LParts   : TArray<String>;
  LBmp     : TBitmap;
  LFile    : String;
  LElement : TAquariumElement;
begin
  FItems.Clear();

  if not TFile.Exists(FManifestPath) then
    Exit;

  LLines := TStringList.Create();
  try
    LLines.LoadFromFile(FManifestPath);
    for i := 0 to LLines.Count - 1 do
    begin
      if Trim(LLines[i]) = '' then
        Continue;

      LParts := LLines[i].Split([MANIFEST_SEP]);
      if Length(LParts) < 3 then
        Continue;

      LFile := TPath.Combine(FElementsDir, LParts[2]);
      if not TFile.Exists(LFile) then
        Continue;

      LBmp := TBitmap.Create();
      try
        LBmp.LoadFromFile(LFile);
        LElement := TAquariumElement.Create(
          LParts[1], StrToAquariumKind(LParts[0]), LFile, LBmp);
        FItems.Add(LElement);
      finally
        LBmp.Free();
      end;
    end;
  finally
    LLines.Free();
  end;
end;

procedure TAquariumLibrary.SaveManifest();
var
  LLines : TStringList;
  i      : Integer;
  LEl    : TAquariumElement;
begin
  LLines := TStringList.Create();
  try
    for i := 0 to FItems.Count - 1 do
    begin
      LEl := FItems[i];
      LLines.Add(AquariumKindToStr(LEl.Kind) + MANIFEST_SEP +
                 LEl.Name + MANIFEST_SEP +
                 TPath.GetFileName(LEl.FileName));
    end;
    LLines.SaveToFile(FManifestPath, TEncoding.UTF8);
  finally
    LLines.Free();
  end;
end;

function TAquariumLibrary.SaveElement(AKind: TAquariumKind; const AName: String;
  ASource: TBitmap): TAquariumElement;
var
  LName, LFileName, LFullPath : String;
  LGuid : TGUID;
begin
  EnsureDirectories();

  LName := Trim(AName);
  if LName = '' then
    LName := AQUARIUM_KIND_NAMES[AKind] + ' ' + (FItems.Count + 1).ToString;
  // Trennzeichen darf nicht im Namen vorkommen
  LName := StringReplace(LName, MANIFEST_SEP, '/', [rfReplaceAll]);

  LGuid := TGUID.NewGuid();
  LFileName := AquariumKindToStr(AKind) + '_' +
    LGuid.ToString.Replace('{', '').Replace('}', '').Replace('-', '') + '.png';
  LFullPath := TPath.Combine(FElementsDir, LFileName);

  ASource.SaveToFile(LFullPath);

  Result := TAquariumElement.Create(LName, AKind, LFullPath, ASource);
  FItems.Add(Result);
  SaveManifest();
end;

procedure TAquariumLibrary.UpdateElement(AIndex: Integer; AKind: TAquariumKind;
  const AName: String; ASource: TBitmap);
var
  LEl   : TAquariumElement;
  LName : String;
begin
  if (AIndex < 0) or (AIndex >= FItems.Count) then
    Exit;

  LEl := FItems[AIndex];

  LName := Trim(AName);
  if LName = '' then
    LName := LEl.Name;
  LName := StringReplace(LName, MANIFEST_SEP, '/', [rfReplaceAll]);

  // gleiche Datei ueberschreiben
  ASource.SaveToFile(LEl.FileName);
  LEl.Update(AKind, LName, ASource);

  SaveManifest();
end;

procedure TAquariumLibrary.DeleteElement(AIndex: Integer);
begin
  if (AIndex < 0) or (AIndex >= FItems.Count) then
    Exit;

  if TFile.Exists(FItems[AIndex].FileName) then
    TFile.Delete(FItems[AIndex].FileName);

  FItems.Delete(AIndex);   // Liste besitzt das Objekt -> wird freigegeben
  SaveManifest();
end;

{ TSpawnedElement }

procedure TSpawnedElement.ApplyScale();
begin
  // Grundgroesse je Art (X/Y) mal Mausrad-Skalierung. Z nur die Skalierung,
  // damit die gebackene Z-Deformation - wie frueher beim Plane - unabhaengig
  // von der Breite bleibt.
  if Assigned(FModel) then
    FModel.Scale.Point := Point3D(FBaseW * FScale, FBaseH * FScale, FScale);
end;

procedure TSpawnedElement.Animate(ATime: Single);
var dx : Single;
begin
  // Die Raumbewegung selbst treibt die TPoint3DAnimation (entkoppelt). Hier
  // wird nur noch die Blickrichtung des Fisches an seine Bewegungsrichtung
  // angepasst. Im eingefrorenen Zustand (Vorschau) bleibt alles stehen.
  if FFrozen or not Assigned(FModel) then
    Exit;

  if FKind = akFish then
  begin
    dx := FModel.Position.X - FLastX;
    FLastX := FModel.Position.X;
    if dx > 0.0001 then
      FModel.RotationAngle.Y := 0          // schwimmt nach rechts -> Vorderseite
    else if dx < -0.0001 then
      FModel.RotationAngle.Y := 180;       // schwimmt nach links  -> Rueckseite
  end;
end;

procedure TSpawnedElement.StartMovement();
begin
  if not Assigned(FMoveAnim) then
    Exit;

  // Die Bewegung pendelt (AutoReverse + Loop) um FBasePos. Start-/Stopp-Punkt
  // je nach Art; spaeter kann diese Animation einfach durch eine gezielte
  // Steuerung ersetzt werden.
  case FKind of
    akFish:
      begin
        FMoveAnim.StartValue.Point := Point3D(FBasePos.X - 3.0, FBasePos.Y - 0.3, FBasePos.Z);
        FMoveAnim.StopValue.Point  := Point3D(FBasePos.X + 3.0, FBasePos.Y + 0.3, FBasePos.Z);
      end;
    akJellyfish:
      begin
        FMoveAnim.StartValue.Point := Point3D(FBasePos.X - 0.5, FBasePos.Y - 0.8, FBasePos.Z);
        FMoveAnim.StopValue.Point  := Point3D(FBasePos.X + 0.5, FBasePos.Y + 0.8, FBasePos.Z);
      end;
  else
    Exit;  // Pflanze/Koralle bewegen sich nicht im Raum
  end;

  FLastX := FBasePos.X;
  FMoveAnim.Duration := FMoveDur;
  FMoveAnim.Start();
end;

procedure TSpawnedElement.SetFrozen(const AValue: Boolean);
begin
  if FFrozen = AValue then
    Exit;
  FFrozen := AValue;

  if Assigned(FMoveAnim) then
  begin
    if FFrozen then
      FMoveAnim.Stop()        // Vorschau: exakt stehen bleiben (nur wabbeln)
    else
      StartMovement();        // platziert: Raumbewegung um FBasePos aufnehmen
  end;
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
  FLastX   := APos.X;
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
var w, r, zz, dx, dz, pulse, p, tenv : Single;
begin
  dx := 0; dz := 0; zz := 0;
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
        zz := 0.30 * AAmp * tenv * Power(w, ATailPow) * Sin(6.0 * u - ASpeed * theta);
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
  Result := Point3D(u + dx, v, zz + dz);
end;

// Schaltet die Beleuchtung fuer ein Mesh und alle Submeshes ab (rekursiv).
// Noetig, weil TGorillaMaterial.CreateMaterial fuer mkBlinnPhong UseLighting
// hart auf TRUE setzt und das ADef.UseLighting-Flag ignoriert -> ein beleuchtetes
// Sprite wird beim Umdrehen (Rueckseite vom Licht abgewandt) schwarz. Ohne Licht
// zeigt die Textur auf beiden Seiten ihre echten Farben.
procedure DisableLighting(AMesh: TGorillaMesh);
var i : Integer;
begin
  if not Assigned(AMesh) then
    Exit;

  if AMesh.MaterialSource is TGorillaDefaultMaterialSource then
    TGorillaDefaultMaterialSource(AMesh.MaterialSource).UseLighting := False;

  if Assigned(AMesh.Meshes) then
    for i := 0 to AMesh.Meshes.Count - 1 do
      DisableLighting(AMesh.Meshes[i]);
end;

{ TAquariumScene }

constructor TAquariumScene.Create(AViewport: TGorillaViewport; AOwner: TComponent);
begin
  inherited Create();
  FViewport := AViewport;
  FOwner    := AOwner;
  FModelDefs := TDictionary<String, TModelDef>.Create();
  FItems    := TObjectList<TSpawnedElement>.Create(True);
end;

destructor TAquariumScene.Destroy();
begin
  // Die ModelDefs gehoeren nach dem Materialisieren den jeweiligen Models und
  // werden von diesen freigegeben - hier nichts zu tun.
  FItems.Free();
  FModelDefs.Free();

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
  //               Dauer) und staerker zur Schwanzflosse hin betont (ATailPow 3).
  //    Umgeschaltet wird zur Laufzeit ueber TSpawnedElement.FastSwim.
  if AKind = akFish then
  begin
    //                Id      Dauer                  Amp  Speed TailPow Ramp
    AddWobble('self', AQUARIUM_LOOP_S[akFish],       1.0, 1.0,  2.5,    0.0);
    AddWobble('fast', 0.85,                          1.4, 2.0,  3.0,    0.9);
  end
  else
    AddWobble('self', AQUARIUM_LOOP_S[AKind],        1.0, 1.0,  2.5,    0.0);

  FModelDefs.Add(AName, Result);
end;

function TAquariumScene.Spawn(AElement: TAquariumElement): TSpawnedElement;
var
  LDef   : TModelDef;
  LModel : TGorillaModel;
  LSpawn : TSpawnedElement;
  LW, LH : Single;
  LAnim  : TGorillaAnimation;
begin
  // Request a new model definition or if we already have created one - reuse it
  LDef := BuildModelDef(AElement.Name, AElement.Kind, AElement.Bitmap);

  // Take the definition object and create a visual representation
  LModel := TGorillaModel.LoadNewModelFromDef(FOwner, LDef,
    []{GORILLA_ANIMATION_CACHING_DEFAULT});
  LModel.Parent := FViewport;
  LModel.SetHitTestValue(false);
  LModel.SetTwoSide(true);
  LModel.FrustumCullingCheck := False;

  // Sprite-Look erzwingen: Beleuchtung abschalten (sonst Rueckseite schwarz,
  // siehe DisableLighting). Erst nach dem Materialisieren moeglich.
  DisableLighting(LModel);

  // !!! if the model is getting destroyed we do not destroy the multiple referenced definition
  LModel.IsDefOwner := false;

  LW := AQUARIUM_BASE_W[AElement.Kind];
  LH := AQUARIUM_BASE_H[AElement.Kind];

  LSpawn := TSpawnedElement.Create();
  LSpawn.FModel    := LModel;
  LSpawn.FKind     := AElement.Kind;
  LSpawn.FBaseW    := LW;
  LSpawn.FBaseH    := LH;
  LSpawn.FScale    := 1.0;
  LSpawn.ApplyScale();

  // Entkoppelte Raumbewegung: eine TPoint3DAnimation auf der Model-Position.
  // Nur Fisch/Qualle bewegen sich; Pflanze/Koralle bleiben verwurzelt. Die
  // Animation gehoert dem Model (Owner+Parent) und wird mit ihm freigegeben.
  // Gestartet wird sie erst beim Platzieren (Frozen := False -> StartMovement).
  Randomize();
  if AElement.Kind in [akFish, akJellyfish] then
  begin
    LSpawn.FMoveDur := 5.0 + Random * 4.0;   // variiert -> Instanzen laufen nicht im Gleichschritt
    LSpawn.FMoveAnim := TPoint3DAnimation.Create(LModel);
    LSpawn.FMoveAnim.Parent       := LModel;
    LSpawn.FMoveAnim.PropertyName := 'Position.Point';
    LSpawn.FMoveAnim.Interpolation := TInterpolationType.Sinusoidal;
    LSpawn.FMoveAnim.AnimationType := TAnimationType.InOut;
    LSpawn.FMoveAnim.AutoReverse  := True;
    LSpawn.FMoveAnim.Loop         := True;
  end;

  // Startposition (Tank: X/Z ca. [-8..8], Boden bei Y~7.2, Oberflaeche Y~2.5)
  case AElement.Kind of
    akFish, akJellyfish:
      LSpawn.SetBasePosition(Point3D(
        -5 + Random * 10, 3.5 + Random * 2.0, -5 + Random * 10));
    akPlant, akCoral:
      // Wurzel am Boden: Mittelpunkt um halbe Hoehe nach oben (= kleineres Y)
      LSpawn.SetBasePosition(Point3D(
        -7 + Random * 14, 7.2 - LH / 2, -7 + Random * 12));
  end;

  // Eigen-Animation starten. Wichtig: Das treibende Skeleton muss auf Loop
  // gesetzt werden - sonst laeuft die Animation nur einmal ueber ihre Dauer
  // und bleibt dann stehen (der Interpolator-Loop allein genuegt nicht).
  if Assigned(LModel.AnimationManager)
  and (LModel.AnimationManager.Animations.Count > 0) then
  begin
    LAnim := LModel.AnimationManager.GetAnimation('self');
    LModel.AnimationManager.PlayAnimation(LAnim);
  end;

  FItems.Add(LSpawn);
  //LSpawn.FastSwim := true;
  Result := LSpawn;
end;

procedure TAquariumScene.Remove(ASpawn: TSpawnedElement);
begin
  if not Assigned(ASpawn) then
    Exit;

  // Das Model wird vom Formular (FOwner) verwaltet; explizites Freigeben
  // entfernt es aus der Szene und gibt sein ModelDef (inkl. Material/Textur)
  // mit frei.
  if Assigned(ASpawn.FModel) then
  begin
    ASpawn.FModel.Parent := nil;
    ASpawn.FModel.Free();
    ASpawn.FModel := nil;
  end;

  FItems.Remove(ASpawn);   // OwnsObjects -> gibt nur das Wrapper-Objekt frei
end;

procedure TAquariumScene.Animate(ATime: Single);
var i : Integer;
begin
  for i := 0 to FItems.Count - 1 do
    FItems[i].Animate(ATime);
end;

end.
