unit Aquarium.Placement;

{
  SketchQuarium - Platzierungsmodus (ausgelagert aus dem Zeicheneditor)

  Diese Unit kapselt den kompletten Ablauf, ein gezeichnetes Element in der
  3D-Szene zu platzieren:
    - eine Vorschau-Instanz folgt dem Mauszeiger,
    - Linksklick setzt sie fest (sie beginnt zu schwimmen/schwingen) und
      erzeugt sofort eine neue Vorschau,
    - das Mausrad skaliert sie,
    - Rechtsklick beendet den Modus.

  Waehrend der Platzierung uebernimmt der Controller die Maus-Events der
  Viewport und stellt die zuvor gesetzten Handler danach wieder her, damit die
  Design-Kamera-Navigation erhalten bleibt.

  Auflageflaechen (Terrain, Stein) werden per RegisterSurface() bekannt gemacht
  und per Dreieck-Raycast abgetastet; ohne Treffer wird auf die Bodenebene
  projiziert.

  Der Controller besitzt weder Szene noch Viewport (beide gehoeren dem
  Formular). Die Hinweisleiste wird mit AOwner als Eigentuemer erzeugt und von
  diesem freigegeben.
}

interface

uses
  System.Types, System.UITypes, System.Classes, System.Math,
  System.Math.Vectors, System.Generics.Collections,
  FMX.Types, FMX.Controls, FMX.Graphics, FMX.Objects, FMX.StdCtrls,
  FMX.Types3D, FMX.Controls3D,
  Gorilla.Viewport, Gorilla.Mesh, Gorilla.DefTypes, Gorilla.Control,
  Aquarium.Elements;

type
  /// <summary>
  ///  Steuert den Platzierungsmodus: eine Vorschau folgt der Maus, Linksklick
  ///  platziert, Mausrad skaliert, Rechtsklick beendet.
  /// </summary>
  TAquariumPlacement = class
  private
    FOwner    : TComponent;             // Eigentuemer der erzeugten Controls
    FScene    : TAquariumScene;         // 3D-Szene (Eigentum des Formulars)
    FViewport : TGorillaViewport;       // 3D-Viewport (Eigentum des Formulars)
    FControls3D : TList<TGorillaMesh>;  // registrierte Auflageflaechen

    FHintBar         : TRectangle;
    FPlacingElement  : TAquariumElement;   // gerade aktives Element (oder nil)
    FPreview         : TSpawnedElement;    // Vorschau-Instanz, folgt der Maus
    FPlaceScale      : Single;             // per Mausrad einstellbare Groesse
    FLastMousePt     : TPointF;            // letzte Mausposition (fuer Mausrad)

    FStoredMouseDown : TMouseEvent;
    FStoredMouseMove : TMouseMoveEvent;
    FStoredMouseWheel: TMouseWheelEvent;

    procedure CreateHintBar();

    function  CameraRay(const APt: TPointF; out AOrigin, ADir: TPoint3D): Boolean;
    function  RayPlaneHit(const AOrigin, ADir: TPoint3D; AAxis: Integer;
                AValue: Single; out AHit: TPoint3D): Boolean;
    function  SurfacePlacement(const AMousePos: TPointF; const AOrigin, ADir: TPoint3D): TPoint3D;
    function  MouseToTankPoint(const APt: TPointF): TPoint3D;

    procedure ViewportMouseDown(Sender: TObject; Button: TMouseButton;
                Shift: TShiftState; X, Y: Single);
    procedure ViewportMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
    procedure ViewportMouseWheel(Sender: TObject; Shift: TShiftState;
                WheelDelta: Integer; var Handled: Boolean);
  public
    /// <param name="AOwner">Eigentuemer der erzeugten Hinweisleiste (z.B. der Frame).</param>
    constructor Create(AScene: TAquariumScene; AViewport: TGorillaViewport;
      AOwner: TComponent);
    destructor Destroy(); override;

    /// <summary>Registriert eine Auflageflaeche (Terrain, Stein) fuer den Raycast.</summary>
    procedure RegisterSurface(ACtrl: TGorillaMesh);

    /// <summary>Startet den Platzierungsmodus fuer ein Element.</summary>
    procedure Start(AElement: TAquariumElement);

    /// <summary>Beendet den Platzierungsmodus und raeumt die Vorschau auf.</summary>
    procedure Stop();

    /// <summary>True, solange eine Vorschau aktiv der Maus folgt.</summary>
    function Active(): Boolean;
  end;

implementation

{ TAquariumPlacement }

constructor TAquariumPlacement.Create(AScene: TAquariumScene;
  AViewport: TGorillaViewport; AOwner: TComponent);
begin
  inherited Create();
  FScene      := AScene;
  FViewport   := AViewport;
  FOwner      := AOwner;
  FControls3D := TList<TGorillaMesh>.Create();
  FPlaceScale := 1.0;

  CreateHintBar();
end;

destructor TAquariumPlacement.Destroy();
begin
  // Falls noch ein Platzierungsmodus laeuft: Vorschau entfernen und die
  // Viewport-Maus-Events wieder loesen (Szene/Viewport leben noch).
  Stop();
  FControls3D.Free();
  // FHintBar gehoert FOwner und wird von diesem freigegeben.
  inherited;
end;

procedure TAquariumPlacement.RegisterSurface(ACtrl: TGorillaMesh);
begin
  FControls3D.Add(ACtrl);
end;

function TAquariumPlacement.Active(): Boolean;
begin
  Result := Assigned(FPreview);
end;

procedure TAquariumPlacement.CreateHintBar();
begin
  // Hinweisleiste fuer den Platzierungsmodus - liegt ueber dem 3D-Viewport,
  // daher dort eingehaengt (gehoert aber FOwner).
  FHintBar := TRectangle.Create(FOwner);
  FHintBar.Parent := FViewport;
  FHintBar.Align := TAlignLayout.Bottom;
  FHintBar.Height := 36;
  FHintBar.Fill.Color := $CC202020;
  FHintBar.Stroke.Kind := TBrushKind.None;
  FHintBar.HitTest := False;
  FHintBar.Visible := False;
  with TLabel.Create(FHintBar) do
  begin
    Parent := FHintBar;
    Align := TAlignLayout.Client;
    HitTest := False;
    StyledSettings := StyledSettings - [TStyledSetting.Size, TStyledSetting.FontColor];
    TextSettings.Font.Size := 15;
    TextSettings.FontColor := TAlphaColorRec.White;
    TextSettings.HorzAlign := TTextAlign.Center;
    Text := 'Linksklick: platzieren   •   Mausrad: Größe   •   Rechtsklick: beenden';
  end;
end;

{ ----------------------------------------------------------------------------
  Platzierungsmodus: Vorschau folgt der Maus, Linksklick platziert,
  Rechtsklick beendet den Modus.
  ---------------------------------------------------------------------------- }

procedure TAquariumPlacement.Start(AElement: TAquariumElement);
begin
  Stop();   // evtl. laufende Vorschau zuerst aufraeumen

  // Sicherstellen, dass das Stein-Modell (inkl. geladener Submeshes) per
  // Raycast getroffen werden kann.
  for var I := 0 to FControls3D.Count - 1 do
  begin
    (FControls3D[I].Def as TMeshDef).AcquireBVH();
    FControls3D[I].SetHitTestValue(false);
  end;

  FPlacingElement := AElement;

  // Vorschau-Instanz erzeugen: eingefroren, damit sie exakt der Maus folgt
  FPreview := FScene.Spawn(AElement);
  FPreview.Frozen := True;
  FPreview.SetSizeScale(FPlaceScale);            // zuletzt gewaehlte Groesse
  FPreview.SetBasePosition(Point3D(0, 4.5, 0));  // Startpunkt: Tankmitte

  FLastMousePt := PointF(FViewport.Width / 2, FViewport.Height / 2);

  // Maus-Events nur jetzt aktiv schalten - sonst deaktivieren sie die
  // Design-Kamera-Navigation der Viewport.
  FStoredMouseDown  := FViewport.OnMouseDown;
  FStoredMouseMove  := FViewport.OnMouseMove;
  FStoredMouseWheel := FViewport.OnMouseWheel;
  FViewport.OnMouseDown := ViewportMouseDown;
  FViewport.OnMouseMove := ViewportMouseMove;
  FViewport.OnMouseWheel := ViewportMouseWheel;

  FHintBar.Visible := True;
  FHintBar.BringToFront();
end;

procedure TAquariumPlacement.Stop();
begin
  // Maus-Events wieder loesen -> Design-Navigation ist erneut aktiv.
  if Assigned(FViewport) and (@FStoredMouseDown <> nil)
   and (@FStoredMouseMove <> nil) and (@FStoredMouseWheel <> nil) then
  begin
    FViewport.OnMouseDown := FStoredMouseDown;
    FViewport.OnMouseMove := FStoredMouseMove;
    FViewport.OnMouseWheel := FStoredMouseWheel;
  end;

  if Assigned(FPreview) and Assigned(FScene) then
    FScene.Remove(FPreview);

  FPreview := nil;
  FPlacingElement := nil;
  if Assigned(FHintBar) then
    FHintBar.Visible := False;

  for var I := 0 to FControls3D.Count - 1 do
  begin
    FControls3D[I].SetHitTestValue(false);
    (FControls3D[I].Def as TMeshDef).ReleaseBVH();
  end;
end;

function TAquariumPlacement.CameraRay(const APt: TPointF;
  out AOrigin, ADir: TPoint3D): Boolean;
var
  LCam : TCamera;
  LVec : TVector3D;
  LFar : TPoint3D;
begin
  Result := False;

  if FViewport.UsingDesignCamera then
    LCam := FViewport.GetDesignCamera()
  else
    LCam := FViewport.Camera;
  if not Assigned(LCam) then
    Exit;

  LVec := LCam.AbsolutePosition;
  AOrigin := Point3D(LVec.X, LVec.Y, LVec.Z);

  // Punkt auf dem Sichtstrahl durch den Mauszeiger -> Richtung ableiten
  LFar := FViewport.ScreenToWorld(APt);
  ADir := (LFar - AOrigin).Normalize();
  Result := True;
end;

function TAquariumPlacement.RayPlaneHit(const AOrigin, ADir: TPoint3D;
  AAxis: Integer; AValue: Single; out AHit: TPoint3D): Boolean;
var d, o, t : Single;
begin
  Result := False;
  case AAxis of
    0: begin d := ADir.X; o := AOrigin.X; end;   // X-Ebene
    1: begin d := ADir.Y; o := AOrigin.Y; end;   // Y-Ebene (Boden)
  else begin d := ADir.Z; o := AOrigin.Z; end;   // Z-Ebene (Wasser)
  end;

  if Abs(d) < 0.00001 then
    Exit;
  t := (AValue - o) / d;
  if t <= 0 then          // Treffer liegt hinter der Kamera
    Exit;

  AHit := AOrigin + ADir * t;
  Result := True;
end;

function TAquariumPlacement.SurfacePlacement(const AMousePos: TPointF;
  const AOrigin, ADir: TPoint3D): TPoint3D;
const
  FLOOR_Y = 6.5;
var
  LRes    : TTriangleRayCastResult;
  LLastDist : Single;
  LHit    : TPoint3D;
  LH      : Single;
  LFound  : Boolean;
  LRayPos : TVector3D;
  LRayDir : TVector3D;
begin
  Result := TPoint3D.Zero;

  // Denselben (bewaehrten) Kamerastrahl verwenden, mit dem auch die frei
  // schwebenden Objekte platziert werden. Der Ursprung kommt direkt aus der
  // Kamera (AOrigin) und ist damit robust gegen eine evtl. veraltete
  // Context.Pick-Kameramatrix, an der die (X,Y)-Ueberladung scheitert.
  LRayPos := TVector3D.Create(AOrigin.X, AOrigin.Y, AOrigin.Z, 1);
  LRayDir := TVector3D.Create(ADir.X, ADir.Y, ADir.Z, 0);

  LLastDist := 1000;
  LHit   := TPoint3D.Zero;
  LFound := False;

  // Auflageflaechen per Dreieck-Raycast abtasten (Terrain, Rock-Oberflaeche).
  for var I := 0 to FControls3D.Count - 1 do
  begin
    if FControls3D[I].PickTriangle(LRayPos, LRayDir, LRes) then
    begin
      if LLastDist > LRes.T then
      begin
        LHit      := LRes.Intersection;
        LLastDist := LRes.T;
        LFound    := True;
      end;
    end;
  end;

  // Fallback: keine Oberflaeche getroffen -> auf die Bodenebene Y=FLOOR_Y
  // projizieren, damit das Element trotzdem sinnvoll auf dem Boden landet.
  if not LFound then
    RayPlaneHit(AOrigin, ADir, 1, FLOOR_Y, LHit);

  LH := 0;
  if Assigned(FPreview) and Assigned(FPreview.Plane) then
    LH := FPreview.Plane.Height * FPreview.Plane.Scale.Y;

  Result := Point3D(LHit.X, LHit.Y - LH / 2, LHit.Z);
  Result.X := Max(-19.0, Min(19.0, Result.X));
  Result.Z := Max(-19.0, Min(19.0, Result.Z));
end;

function TAquariumPlacement.MouseToTankPoint(const APt: TPointF): TPoint3D;
var
  LOrigin, LDir : TPoint3D;
begin
  Result := Point3D(0, 4.5, 0);
  if not CameraRay(APt, LOrigin, LDir) then
    Exit;

  if Assigned(FPlacingElement)
  and (FPlacingElement.Kind in [akPlant, akCoral]) then
  begin
    // Pflanzen/Korallen: auf Geometrie (Rock) bzw. Boden mit Bodenkontakt
    Result := SurfacePlacement(APt, LOrigin, LDir);
  end
  else
  begin
    // Fische/Quallen: frei schwebend auf der vertikalen Ebene Z = 0
    if RayPlaneHit(LOrigin, LDir, 2, 0.0, Result) then
    begin
      Result.X := Max(-9.0, Min(9.0, Result.X));
      Result.Y := Max( 3.0, Min(7.0, Result.Y));
      Result.Z := 0;
    end
    else
      Result := Point3D(0, 4.5, 0);
  end;
end;

procedure TAquariumPlacement.ViewportMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Single);
begin
  if not Assigned(FPreview) then
    Exit;
  FLastMousePt := PointF(X, Y);
  FPreview.SetBasePosition(MouseToTankPoint(FLastMousePt));
end;

procedure TAquariumPlacement.ViewportMouseWheel(Sender: TObject;
  Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);
begin
  if not Assigned(FPreview) then
    Exit;

  // Groesse anpassen (multiplikativ -> gleichmaessige Schritte), begrenzt
  if WheelDelta > 0 then
    FPlaceScale := FPlaceScale * 1.1
  else
    FPlaceScale := FPlaceScale / 1.1;
  FPlaceScale := Max(0.2, Min(6.0, FPlaceScale));

  FPreview.SetSizeScale(FPlaceScale);
  // Position/Wurzel an die neue Groesse nachfuehren (ohne Mausbewegung)
  FPreview.SetBasePosition(MouseToTankPoint(FLastMousePt));

  Handled := True;   // Kamera-Zoom der Viewport unterdruecken
end;

procedure TAquariumPlacement.ViewportMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  if not Assigned(FPreview) then
    Exit;

  case Button of
    TMouseButton.mbLeft:
      begin
        // Vorschau an aktueller Stelle "festsetzen" (taut auf -> beginnt zu
        // schwimmen/schwingen) und sofort eine neue Vorschau erzeugen.
        FPreview.SetBasePosition(MouseToTankPoint(PointF(X, Y)));
        FPreview.Frozen := False;

        FPreview := FScene.Spawn(FPlacingElement);
        FPreview.Frozen := True;
        FPreview.SetSizeScale(FPlaceScale);   // gewaehlte Groesse beibehalten
        FPreview.SetBasePosition(MouseToTankPoint(PointF(X, Y)));
      end;

    TMouseButton.mbRight:
      Stop();
  end;
end;

end.
