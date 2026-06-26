unit Aquarium.Elements;

{
  SketchQuarium - Aquariumselemente

  Diese Unit kapselt drei Dinge:
    1. TAquariumKind            - die Art eines Elements (Fisch, Qualle, ...)
    2. TAquariumLibrary         - das Speichern/Laden gezeichneter Elemente
                                  (PNG + Manifest im Dokumente-Ordner)
    3. TAquariumScene           - das Erzeugen animierter Planes in der 3D-Szene
                                  inkl. der pro-Frame Vertex-Deformation

  Die eigentliche 3D-Geometrie ist ein TGorillaPlane mit Subdivisions, dem ein
  TGorillaBlinnMaterialSource mit der gezeichneten Textur (Texture0) zugewiesen
  wird. Damit transparente Bereiche nicht schwarz erscheinen, wird das Plane als
  nicht-opak (Opaque := False) gerendert und das Material nutzt die Alpha-Kanal-
  Transparenz der Textur.
}

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math,
  System.Math.Vectors, System.Generics.Collections, System.IOUtils,
  FMX.Graphics, FMX.Types3D, FMX.Controls3D,
  Gorilla.Viewport, Gorilla.Plane, Gorilla.Material.Blinn;

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
  ///  Eine in der Szene platzierte Instanz eines Elements. Haelt das Plane,
  ///  die unverformten Ausgangs-Vertices (Ruhelage) sowie Parameter fuer die
  ///  Animation.
  /// </summary>
  TSpawnedElement = class
  private
    FPlane     : TGorillaPlane;
    FMaterial  : TGorillaBlinnMaterialSource;
    FKind      : TAquariumKind;
    FRestVerts : TArray<TPoint3D>;
    FBasePos   : TPoint3D;
    FPhase     : Single;
    FFrozen    : Boolean;
    procedure CaptureRestVertices();
  public
    /// <summary>Berechnet und setzt die Vertexpositionen fuer den Zeitpunkt ATime.</summary>
    procedure Animate(ATime: Single);

    /// <summary>Setzt Basis- und aktuelle Position (z.B. fuer die Vorschau).</summary>
    procedure SetBasePosition(const APos: TPoint3D);

    /// <summary>Skaliert das Element gleichmaessig (1.0 = Ausgangsgroesse).</summary>
    procedure SetSizeScale(const AFactor: Single);

    property Plane : TGorillaPlane read FPlane;
    property Kind  : TAquariumKind read FKind;
    /// <summary>
    ///  Im eingefrorenen Zustand bleibt das Element exakt an seiner Position
    ///  (es wabbelt nur), bewegt sich aber nicht frei. Wird fuer die
    ///  Maus-Vorschau verwendet.
    /// </summary>
    property Frozen : Boolean read FFrozen write FFrozen;
  end;

  /// <summary>
  ///  Verwaltet alle in der Szene platzierten Elemente und treibt deren
  ///  Animation. Animate() muss regelmaessig (z.B. per Timer) aufgerufen werden.
  /// </summary>
  TAquariumScene = class
  private
    FViewport : TGorillaViewport;
    FOwner    : TComponent;
    FItems    : TObjectList<TSpawnedElement>;
    function BuildMaterial(ABitmap: TBitmap): TGorillaBlinnMaterialSource;
  public
    constructor Create(AViewport: TGorillaViewport; AOwner: TComponent);
    destructor Destroy(); override;

    /// <summary>Platziert ein Element als animiertes Plane in der Szene.</summary>
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
  SUBDIVISIONS   = 24;     // Aufloesung des Plane-Meshes (pro Achse)

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

procedure TSpawnedElement.CaptureRestVertices();
var
  LData : TMeshData;
  i, n  : Integer;
begin
  LData := FPlane.MeshData;
  n := LData.VertexBuffer.Length;
  SetLength(FRestVerts, n);
  for i := 0 to n - 1 do
    FRestVerts[i] := LData.VertexBuffer.Vertices[i];
end;

procedure TSpawnedElement.Animate(ATime: Single);
var
  LData : TMeshData;
  i, n  : Integer;
  u, v  : Single;       // lokale Vertexkoordinaten in [-0.5 .. 0.5]
  r, w  : Single;
  dx, dz, z : Single;
  pulse : Single;
  t     : Single;
  P     : TPoint3D;
begin
  t := ATime + FPhase;
  LData := FPlane.MeshData;
  n := Length(FRestVerts);
  if (n = 0) or (LData.VertexBuffer.Length < n) then
    Exit;

  // 1) Vertex-Deformation (lokaler Wabbel/Schwung des Meshes)
  for i := 0 to n - 1 do
  begin
    P := FRestVerts[i];
    u := P.X;
    v := P.Y;
    dx := 0; dz := 0; z := 0;

    case FKind of
      akFish:
        begin
          // Wanderwelle entlang X: Kopf (-X) ruhig, Schwanz (+X) schwingt
          w := u + 0.5;                       // 0 am Kopf .. 1 am Schwanz
          z := 0.18 * (w * w) * Sin(6.0 * u - 6.0 * t);
        end;

      akJellyfish:
        begin
          // Pulsierende Glocke: Mitte woelbt sich, Rand (Tentakel) folgt
          r := Sqrt(u * u + v * v);
          pulse := 0.5 + 0.5 * Sin(2.4 * t);
          z := 0.22 * Cos(r * PI) * pulse;
          // Tentakel-Saum unten leicht nachziehen
          if v > 0 then
            z := z + 0.10 * v * Sin(3.0 * t - v * 4.0);
        end;

      akPlant:
        begin
          // Verwurzelt unten (v=+0.5), schwingt nach oben (v=-0.5) zunehmend
          w := 0.5 - v;                       // 0 an der Wurzel .. 1 an der Spitze
          dx := 0.26 * (w * w) * Sin(2.0 * t + v * 3.0);
          dz := 0.10 * (w * w) * Cos(1.4 * t);
        end;

      akCoral:
        begin
          // Steifer als Pflanze: kleinere Amplitude, hoehere Frequenz
          w := 0.5 - v;
          dx := 0.09 * (w * w * w) * Sin(3.2 * t + v * 2.0);
          dz := 0.05 * (w * w * w) * Cos(2.6 * t);
        end;
    end;

    LData.VertexBuffer.Vertices[i] := Point3D(u + dx, v, P.Z + z + dz);
  end;

  // 2) Transform-Animation (Bewegung des gesamten Plane)
  //    Im eingefrorenen Zustand (Vorschau) entfaellt die freie Bewegung -
  //    das Element bleibt exakt unter dem Mauszeiger und wabbelt nur.
  if FFrozen then
    Exit;

  case FKind of
    akFish:
      begin
        // sanftes Hin- und Herschwimmen + leichtes Auf/Ab, Blick in Schwimmrichtung
        FPlane.Position.Point := Point3D(
          FBasePos.X + 3.0 * Sin(0.4 * t),
          FBasePos.Y + 0.3 * Sin(1.5 * t),
          FBasePos.Z);
        if Cos(0.4 * t) >= 0 then
          FPlane.RotationAngle.Y := 0
        else
          FPlane.RotationAngle.Y := 180;
      end;

    akJellyfish:
      begin
        // gemaechliches Auf- und Abtreiben
        FPlane.Position.Point := Point3D(
          FBasePos.X + 0.5 * Sin(0.3 * t),
          FBasePos.Y + 0.8 * Sin(0.8 * t),
          FBasePos.Z);
      end;

    akPlant, akCoral:
      ; // bleiben am Platz - nur die Vertices schwingen
  end;
end;

procedure TSpawnedElement.SetBasePosition(const APos: TPoint3D);
begin
  FBasePos := APos;
  FPlane.Position.Point := APos;
end;

procedure TSpawnedElement.SetSizeScale(const AFactor: Single);
begin
  FPlane.Scale.Point := Point3D(AFactor, AFactor, AFactor);
end;

{ TAquariumScene }

constructor TAquariumScene.Create(AViewport: TGorillaViewport; AOwner: TComponent);
begin
  inherited Create();
  FViewport := AViewport;
  FOwner    := AOwner;
  FItems    := TObjectList<TSpawnedElement>.Create(True);
end;

destructor TAquariumScene.Destroy();
begin
  FItems.Free();
  inherited;
end;

function TAquariumScene.BuildMaterial(ABitmap: TBitmap): TGorillaBlinnMaterialSource;
begin
  Result := TGorillaBlinnMaterialSource.Create(FOwner);
  Result.UseTexturing := True;
  Result.UseTexture0  := True;
  // Wie ein Sprite darstellen: keine Beleuchtung/Specular, damit die Zeichnung
  // in Originalfarben erscheint und unter Wasser nicht abdunkelt.
//  Result.UseLighting  := False;
//  Result.UseSpecular  := False;
  // Die gezeichnete Textur als Texture0. Transparente Bildbereiche bleiben
  // dank Alpha-Kanal transparent (siehe Opaque := False am Plane).
  Result.Texture := ABitmap;
end;

function TAquariumScene.Spawn(AElement: TAquariumElement): TSpawnedElement;
var
  LPlane : TGorillaPlane;
  LMat   : TGorillaBlinnMaterialSource;
  LSpawn : TSpawnedElement;
  LW, LH : Single;
begin
  LMat := BuildMaterial(AElement.Bitmap);

  LPlane := TGorillaPlane.Create(FOwner);
  LPlane.Parent := FViewport;

  // Geometrie: feines Plane fuer weiche Deformation
  LPlane.SubdivisionsWidth  := SUBDIVISIONS;
  LPlane.SubdivisionsHeight := SUBDIVISIONS;

  // Groesse je nach Art
  case AElement.Kind of
    akFish      : begin LW := 2.6; LH := 1.9; end;
    akJellyfish : begin LW := 2.2; LH := 2.4; end;
    akPlant     : begin LW := 2.2; LH := 3.4; end;
    akCoral     : begin LW := 2.6; LH := 2.2; end;
  else
    LW := 2.5; LH := 2.5;
  end;
  LPlane.Width  := LW;
  LPlane.Height := LH;

  LPlane.MaterialSource := LMat;
  LPlane.TwoSide := True;            // von beiden Seiten sichtbar
  LPlane.Opaque := False;           // -> Alpha-Transparenz statt schwarz
  LPlane.SetHitTestValue(false);
  LPlane.FrustumCullingCheck := False; // nicht wegculllen, da es sich bewegt/verformt

  // Dynamisch machen: kopiert die Vertices aus der MeshDef zurueck in die
  // MeshData, sodass sie pro Frame veraendert werden koennen.
  LPlane.IsStatic := False;

  // Position bestimmen (Tank: X/Z ca. [-8..8], Boden bei Y~7.2, Oberflaeche Y~2.5)
  Randomize();
  case AElement.Kind of
    akFish, akJellyfish:
      LPlane.Position.Point := Point3D(
        -5 + Random * 10, 3.5 + Random * 2.0, -5 + Random * 10);
    akPlant, akCoral:
      // Wurzel am Boden: Mittelpunkt um halbe Hoehe nach oben (= kleineres Y)
      LPlane.Position.Point := Point3D(
        -7 + Random * 14, 7.2 - LH / 2, -7 + Random * 12);
  end;

  LSpawn := TSpawnedElement.Create();
  LSpawn.FPlane    := LPlane;
  LSpawn.FMaterial := LMat;
  LSpawn.FKind     := AElement.Kind;
  LSpawn.FBasePos  := LPlane.Position.Point;
  LSpawn.FPhase    := Random * 2 * PI;
  LSpawn.CaptureRestVertices();

  FItems.Add(LSpawn);
  Result := LSpawn;
end;

procedure TAquariumScene.Remove(ASpawn: TSpawnedElement);
begin
  if not Assigned(ASpawn) then
    Exit;

  // Plane + Material werden vom Formular (FOwner) verwaltet; explizites
  // Freigeben entfernt sie aus der Szene und aus der Besitzerliste.
  if Assigned(ASpawn.FPlane) then
  begin
    ASpawn.FPlane.Parent := nil;
    ASpawn.FPlane.Free();
    ASpawn.FPlane := nil;
  end;
  if Assigned(ASpawn.FMaterial) then
  begin
    ASpawn.FMaterial.Free();
    ASpawn.FMaterial := nil;
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
