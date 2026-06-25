unit Aquarium.EditorFrame;

{
  Drawquarium - Zeicheneditor als FireMonkey-Frame

  Dieser Frame kapselt den kompletten Editor zum Zeichnen, Speichern und
  Platzieren von Aquariumselementen. Das Layout wird zur Entwurfszeit in
  Aquarium.EditorFrame.fmx gepflegt; saemtliche Editor-Funktionen
  (Zeichnen, Bibliotheksverwaltung, Platzierungsmodus) liegen hier in der Unit.

  Der Frame braucht von aussen nur drei Dinge aus der 3D-Szene, die ihm per
  Init() uebergeben werden:
    - die TAquariumScene zum Erzeugen/Entfernen platzierter Elemente
    - die TGorillaViewport fuer den Raycast und die Maus-Vorschau
    - das Stein-Modell (Rock) als Auflageflaeche fuer Pflanzen/Korallen
  Zusaetzlich erhaelt er das Host-Control (die Popup-Flaeche), das er beim
  Schliessen bzw. beim Wechsel in den Platzierungsmodus ausblendet.
}

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Math,
  System.Math.Vectors, System.Generics.Collections,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Objects,
  FMX.Controls.Presentation, FMX.StdCtrls, FMX.Layouts, FMX.Edit, FMX.ListBox,
  FMX.Types3D, FMX.Controls3D,
  Gorilla.Viewport, Gorilla.Mesh, Gorilla.Model, Gorilla.DefTypes, Gorilla.Control,
  Gorilla.Terrain,
  Aquarium.Elements;

type
  TEditorFrame = class(TFrame)
    HeaderLabel: TLabel;
    LeftPanel: TRectangle;
    LeftHeader: TLabel;
    PlaceBtn: TButton;
    EditBtn: TButton;
    UpdateBtn: TButton;
    DeleteBtn: TButton;
    CloseBtn: TButton;
    ElementsList: TListBox;
    RightPanel: TRectangle;
    ArtLabel: TLabel;
    KindCombo: TComboBox;
    NameLabel: TLabel;
    NameEdit: TEdit;
    ColorLabel: TLabel;
    ColorRow: TFlowLayout;
    SwatchBlack: TRectangle;
    SwatchWhite: TRectangle;
    SwatchRed: TRectangle;
    SwatchOrange: TRectangle;
    SwatchGold: TRectangle;
    SwatchYellow: TRectangle;
    SwatchLime: TRectangle;
    SwatchGreen: TRectangle;
    SwatchSky: TRectangle;
    SwatchBlue: TRectangle;
    SwatchPurple: TRectangle;
    SwatchMagenta: TRectangle;
    SwatchBrown: TRectangle;
    SwatchPink: TRectangle;
    BrushLabel: TLabel;
    BrushSize: TTrackBar;
    EraserBtn: TButton;
    ClearBtn: TButton;
    AcceptBtn: TButton;
    CenterPanel: TRectangle;
    CanvasBg: TRectangle;
    CanvasImage: TImage;

    // Zeichenflaeche
    procedure CanvasMouseDown(Sender: TObject; Button: TMouseButton;
                Shift: TShiftState; X, Y: Single);
    procedure CanvasMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
    procedure CanvasMouseUp(Sender: TObject; Button: TMouseButton;
                Shift: TShiftState; X, Y: Single);

    // Werkzeuge
    procedure ColorSwatchClick(Sender: TObject);
    procedure EraserClick(Sender: TObject);
    procedure ClearClick(Sender: TObject);
    procedure AcceptClick(Sender: TObject);

    // Bibliotheksaktionen
    procedure PlaceClick(Sender: TObject);
    procedure EditClick(Sender: TObject);
    procedure UpdateClick(Sender: TObject);
    procedure DeleteClick(Sender: TObject);
    procedure CloseEditorClick(Sender: TObject);
  private
    { Private-Deklarationen }
    FScene    : TAquariumScene;       // 3D-Szene (Eigentum des Formulars)
    FLibrary  : TAquariumLibrary;     // gespeicherte Elemente (Eigentum des Frames)
    FViewport : TGorillaViewport;     // 3D-Viewport (Eigentum des Formulars)
    FHost     : TControl;             // Popup-Flaeche, die der Frame ausblenden darf
    FControls3D : TList<TGorillaMesh>;

    // Zeichen-Zustand
    FCurrentColor : TAlphaColor;
    FEraser       : Boolean;
    FDrawing      : Boolean;
    FLastPt       : TPointF;

    // Platzierungsmodus
    FHintBar         : TRectangle;
    FPlacingElement  : TAquariumElement;   // gerade aktives Element (oder nil)
    FPreview         : TSpawnedElement;    // Vorschau-Instanz, folgt der Maus
    FPlaceScale      : Single;             // per Mausrad einstellbare Groesse
    FLastMousePt     : TPointF;            // letzte Mausposition (fuer Mausrad)

    FStoredMouseDown : TMouseEvent;
    FStoredMouseMove : TMouseMoveEvent;
    FStoredMouseWheel: TMouseWheelEvent;

    procedure CreateHintBar();
    procedure RefreshElementsList();
    procedure ClearCanvas();

    function  ImageToBitmap(const APt: TPointF): TPointF;
    procedure StrokeTo(const APt: TPointF);
    procedure EraseAt(const APt: TPointF);

    // Platzierungsmodus
    procedure EnterPlacement(AElement: TAquariumElement);
    procedure ExitPlacement();

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
    { Public-Deklarationen }
    destructor Destroy(); override;

    /// <summary>
    ///  Verknuepft den Editor mit der 3D-Szene und initialisiert ihn:
    ///  laedt die Bibliothek, leert die Zeichenflaeche und baut die Liste auf.
    /// </summary>
    procedure Init(AScene: TAquariumScene; AViewport: TGorillaViewport;
      ARock: TGorillaModel; AHost: TControl);

    procedure Place3DObject(ACtrl : TGorillaMesh);
  end;

implementation

{$R *.fmx}

const
  CANVAS_PX = 600;   // Pixelaufloesung der Zeichenflaeche (quadratisch)

{ ----------------------------------------------------------------------------
  Initialisierung / Aufraeumen
  ---------------------------------------------------------------------------- }

procedure TEditorFrame.Init(AScene: TAquariumScene; AViewport: TGorillaViewport;
  ARock: TGorillaModel; AHost: TControl);
begin
  FScene    := AScene;
  FViewport := AViewport;
  FHost     := AHost;

  FControls3D := TList<TGorillaMesh>.Create();

  FCurrentColor := TAlphaColorRec.Black;
  FEraser       := False;
  FPlaceScale   := 1.0;

  FLibrary := TAquariumLibrary.Create();
  FLibrary.LoadFromDisk();

  CreateHintBar();
  ClearCanvas();
  RefreshElementsList();
end;

destructor TEditorFrame.Destroy();
begin
  // Falls noch ein Platzierungsmodus laeuft: Vorschau entfernen und die
  // Viewport-Maus-Events wieder loesen (die Szene lebt zu diesem Zeitpunkt noch).
  ExitPlacement();
  FControls3D.Free();
  FLibrary.Free();
  inherited;
end;

procedure TEditorFrame.Place3DObject(ACtrl : TGorillaMesh);
begin
  FControls3D.Add(ACtrl);
end;

procedure TEditorFrame.CreateHintBar();
begin
  // Hinweisleiste fuer den Platzierungsmodus - liegt ueber dem 3D-Viewport,
  // daher zur Laufzeit dort eingehaengt (gehoert aber dem Frame).
  FHintBar := TRectangle.Create(Self);
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

procedure TEditorFrame.RefreshElementsList();
var
  i     : Integer;
  LEl   : TAquariumElement;
  LItem : TListBoxItem;
  LBg   : TRectangle;
  LImg  : TImage;
  LLbl  : TLabel;
begin
  ElementsList.BeginUpdate();
  try
    ElementsList.Clear();
    for i := 0 to FLibrary.Items.Count - 1 do
    begin
      LEl := FLibrary.Items[i];

      LItem := TListBoxItem.Create(ElementsList);
      LItem.Parent := ElementsList;
      LItem.Height := 56;
      LItem.Text := '';   // eigene Inhalte statt Standardtext

      // heller Hintergrund, damit transparente Zeichnungen sichtbar sind
      LBg := TRectangle.Create(LItem);
      LBg.Parent := LItem;
      LBg.Align := TAlignLayout.Left;
      LBg.Width := 52;
      LBg.Margins.Rect := RectF(2, 2, 6, 2);
      LBg.Fill.Color := TAlphaColorRec.White;
      LBg.Stroke.Color := $33555555;
      LBg.XRadius := 3; LBg.YRadius := 3;
      LBg.HitTest := False;

      LImg := TImage.Create(LItem);
      LImg.Parent := LBg;
      LImg.Align := TAlignLayout.Client;
      LImg.Margins.Rect := RectF(2, 2, 2, 2);
      LImg.WrapMode := TImageWrapMode.Fit;
      LImg.HitTest := False;
      LImg.Bitmap.Assign(LEl.Bitmap);

      LLbl := TLabel.Create(LItem);
      LLbl.Parent := LItem;
      LLbl.Align := TAlignLayout.Client;
      LLbl.Margins.Rect := RectF(4, 0, 4, 0);
      LLbl.HitTest := False;
      LLbl.StyledSettings := LLbl.StyledSettings - [TStyledSetting.Size];
      LLbl.TextSettings.Font.Size := 14;
      LLbl.Text := AQUARIUM_KIND_NAMES[LEl.Kind] + ': ' + LEl.Name;
    end;
  finally
    ElementsList.EndUpdate();
  end;
end;

procedure TEditorFrame.ClearCanvas();
begin
  if (CanvasImage.Bitmap.Width <> CANVAS_PX) then
    CanvasImage.Bitmap.SetSize(CANVAS_PX, CANVAS_PX);
  // Voll transparent loeschen -> transparente Bereiche bleiben spaeter transparent
  CanvasImage.Bitmap.Clear(TAlphaColorRec.Null);
  CanvasImage.Repaint();
end;

{ ----------------------------------------------------------------------------
  Zeichnen
  ---------------------------------------------------------------------------- }

function TEditorFrame.ImageToBitmap(const APt: TPointF): TPointF;
begin
  // Steuerelement-lokale Koordinaten -> Bitmap-Pixel
  if (CanvasImage.Width <= 0) or (CanvasImage.Height <= 0) then
    Exit(APt);
  Result.X := APt.X / CanvasImage.Width  * CanvasImage.Bitmap.Width;
  Result.Y := APt.Y / CanvasImage.Height * CanvasImage.Bitmap.Height;
end;

procedure TEditorFrame.StrokeTo(const APt: TPointF);
var r : Single;
begin
  r := BrushSize.Value / 2;
  if CanvasImage.Bitmap.Canvas.BeginScene() then
  try
    CanvasImage.Bitmap.Canvas.Stroke.Kind := TBrushKind.Solid;
    CanvasImage.Bitmap.Canvas.Stroke.Color := FCurrentColor;
    CanvasImage.Bitmap.Canvas.Stroke.Thickness := BrushSize.Value;
    CanvasImage.Bitmap.Canvas.Stroke.Cap := TStrokeCap.Round;
    CanvasImage.Bitmap.Canvas.Stroke.Join := TStrokeJoin.Round;
    CanvasImage.Bitmap.Canvas.DrawLine(FLastPt, APt, 1);
    // Punkt am Ende sichern (sonst fehlen Einzelklicks / Kurvenenden)
    CanvasImage.Bitmap.Canvas.Fill.Kind := TBrushKind.Solid;
    CanvasImage.Bitmap.Canvas.Fill.Color := FCurrentColor;
    CanvasImage.Bitmap.Canvas.FillEllipse(
      RectF(APt.X - r, APt.Y - r, APt.X + r, APt.Y + r), 1);
  finally
    CanvasImage.Bitmap.Canvas.EndScene();
  end;
  CanvasImage.Repaint();
end;

procedure TEditorFrame.EraseAt(const APt: TPointF);
var
  LData : TBitmapData;
  r, x0, y0, x1, y1, xx, yy : Integer;
begin
  r := Round(BrushSize.Value / 2) + 1;
  if not CanvasImage.Bitmap.Map(TMapAccess.ReadWrite, LData) then
    Exit;
  try
    x0 := Max(0, Round(APt.X) - r);
    y0 := Max(0, Round(APt.Y) - r);
    x1 := Min(CanvasImage.Bitmap.Width  - 1, Round(APt.X) + r);
    y1 := Min(CanvasImage.Bitmap.Height - 1, Round(APt.Y) + r);
    for yy := y0 to y1 do
      for xx := x0 to x1 do
        if Sqr(xx - APt.X) + Sqr(yy - APt.Y) <= Sqr(r) then
          LData.SetPixel(xx, yy, TAlphaColorRec.Null);
  finally
    CanvasImage.Bitmap.Unmap(LData);
  end;
  CanvasImage.Repaint();
end;

procedure TEditorFrame.CanvasMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
begin
  FDrawing := True;
  FLastPt := ImageToBitmap(PointF(X, Y));
  if FEraser then
    EraseAt(FLastPt)
  else
    StrokeTo(FLastPt);
end;

procedure TEditorFrame.CanvasMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
var P : TPointF;
begin
  if not FDrawing then
    Exit;
  P := ImageToBitmap(PointF(X, Y));
  if FEraser then
    EraseAt(P)
  else
    StrokeTo(P);
  FLastPt := P;
end;

procedure TEditorFrame.CanvasMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
begin
  FDrawing := False;
end;

{ ----------------------------------------------------------------------------
  Werkzeug-Aktionen
  ---------------------------------------------------------------------------- }

procedure TEditorFrame.ColorSwatchClick(Sender: TObject);
begin
  FCurrentColor := (Sender as TRectangle).Fill.Color;
  FEraser := False;
  EraserBtn.Text := 'Radierer';
end;

procedure TEditorFrame.EraserClick(Sender: TObject);
begin
  FEraser := not FEraser;
  if FEraser then
    EraserBtn.Text := 'Radierer (aktiv)'
  else
    EraserBtn.Text := 'Radierer';
end;

procedure TEditorFrame.ClearClick(Sender: TObject);
begin
  ClearCanvas();
end;

procedure TEditorFrame.AcceptClick(Sender: TObject);
var LKind : TAquariumKind;
begin
  if KindCombo.ItemIndex < 0 then
  begin
    ShowMessage('Bitte zuerst eine Art waehlen.');
    Exit;
  end;

  LKind := TAquariumKind(KindCombo.ItemIndex);
  FLibrary.SaveElement(LKind, NameEdit.Text, CanvasImage.Bitmap);

  RefreshElementsList();
  ElementsList.ItemIndex := ElementsList.Count - 1;

  // Fuer die naechste Zeichnung aufraeumen
  ClearCanvas();
  NameEdit.Text := '';
end;

procedure TEditorFrame.PlaceClick(Sender: TObject);
begin
  if (ElementsList.ItemIndex < 0)
  or (ElementsList.ItemIndex >= FLibrary.Items.Count) then
  begin
    ShowMessage('Bitte ein Element aus der Liste waehlen.');
    Exit;
  end;

  if Assigned(FHost) then
    FHost.Visible := False;
  EnterPlacement(FLibrary.Items[ElementsList.ItemIndex]);
end;

{ ----------------------------------------------------------------------------
  Platzierungsmodus: Vorschau folgt der Maus, Linksklick platziert,
  Rechtsklick beendet den Modus.
  ---------------------------------------------------------------------------- }
procedure TEditorFrame.EnterPlacement(AElement: TAquariumElement);
begin
  ExitPlacement();   // evtl. laufende Vorschau zuerst aufraeumen

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

procedure TEditorFrame.ExitPlacement();
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

function TEditorFrame.CameraRay(const APt: TPointF; out AOrigin, ADir: TPoint3D): Boolean;
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

function TEditorFrame.RayPlaneHit(const AOrigin, ADir: TPoint3D; AAxis: Integer;
  AValue: Single; out AHit: TPoint3D): Boolean;
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

function TEditorFrame.SurfacePlacement(const AMousePos: TPointF; const AOrigin, ADir: TPoint3D): TPoint3D;
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

(*
function TEditorFrame.SurfacePlacement(const AMousePos: TPointF; const AOrigin, ADir: TPoint3D): TPoint3D;
const
  FLOOR_Y = 6.5;          // Oberkante des Ground-Cubes (Y=7, Hoehe 1)
var
  LRes  : TTriangleRayCastResult;
  LHit  : TPoint3D;
  LH    : Single;
  LLocal: TPointF;
begin
  LLocal := AMousePos; //FViewport.LocalToScreen(AMousePos);
//  Log.d('p=(%n,%n), o=(%n,%n,%n), d=(%n,%n,%n)', [AMousePos.X, AMousePos.Y,
//    AOrigin.X, AOrigin.Y, AOrigin.Z, ADir.X, ADir.Y, ADir.Z]);

  for var I := 0 to FControls3D.Count - 1 do
  begin
    if FControls3D[I].PickTriangle(LLocal.X, LLocal.Y, LRes) then
    begin
      LHit := LRes.Intersection;
      Log.d('[HIT][%s]=(%n,%n,%n)', [FControls3D[I].Name, LHit.X, LHit.Y, LHit.Z]);
      Break;
    end;
  end;

  // Wurzel (untere Plane-Kante) auf die Oberflaeche setzen: Mittelpunkt um
  // halbe Hoehe nach oben (Welt-Oben = -Y)
  LH := 0;
  if Assigned(FPreview) and Assigned(FPreview.Plane) then
    LH := FPreview.Plane.Height * FPreview.Plane.Scale.Y;  // inkl. Mausrad-Skalierung

  Result := Point3D(LHit.X, LHit.Y - LH / 2, LHit.Z);
  Result.X := Max(-19.0, Min(19.0, Result.X));
  Result.Z := Max(-19.0, Min(19.0, Result.Z));
end;
*)

function TEditorFrame.MouseToTankPoint(const APt: TPointF): TPoint3D;
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

procedure TEditorFrame.ViewportMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Single);
begin
  if not Assigned(FPreview) then
    Exit;
  FLastMousePt := PointF(X, Y);
  FPreview.SetBasePosition(MouseToTankPoint(FLastMousePt));
end;

procedure TEditorFrame.ViewportMouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; var Handled: Boolean);
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

procedure TEditorFrame.ViewportMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
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
      ExitPlacement();
  end;
end;

{ ----------------------------------------------------------------------------
  Bibliotheksaktionen
  ---------------------------------------------------------------------------- }

procedure TEditorFrame.EditClick(Sender: TObject);
var LEl : TAquariumElement;
begin
  if (ElementsList.ItemIndex < 0)
  or (ElementsList.ItemIndex >= FLibrary.Items.Count) then
  begin
    ShowMessage('Bitte ein Element zum Bearbeiten waehlen.');
    Exit;
  end;

  // Gewaehltes Element in den Editor laden
  LEl := FLibrary.Items[ElementsList.ItemIndex];
  KindCombo.ItemIndex := Ord(LEl.Kind);
  NameEdit.Text := LEl.Name;
  if (CanvasImage.Bitmap.Width <> CANVAS_PX) then
    CanvasImage.Bitmap.SetSize(CANVAS_PX, CANVAS_PX);
  CanvasImage.Bitmap.Assign(LEl.Bitmap);
  CanvasImage.Repaint();
end;

procedure TEditorFrame.UpdateClick(Sender: TObject);
var
  LIdx  : Integer;
  LKind : TAquariumKind;
begin
  LIdx := ElementsList.ItemIndex;
  if (LIdx < 0) or (LIdx >= FLibrary.Items.Count) then
  begin
    ShowMessage('Bitte ein Element zum Aktualisieren waehlen.');
    Exit;
  end;

  if KindCombo.ItemIndex < 0 then
    LKind := FLibrary.Items[LIdx].Kind
  else
    LKind := TAquariumKind(KindCombo.ItemIndex);

  FLibrary.UpdateElement(LIdx, LKind, NameEdit.Text, CanvasImage.Bitmap);
  RefreshElementsList();
  ElementsList.ItemIndex := LIdx;
end;

procedure TEditorFrame.DeleteClick(Sender: TObject);
var LIdx : Integer;
begin
  LIdx := ElementsList.ItemIndex;
  if (LIdx < 0) or (LIdx >= FLibrary.Items.Count) then
  begin
    ShowMessage('Bitte ein Element zum Loeschen waehlen.');
    Exit;
  end;

  FLibrary.DeleteElement(LIdx);
  RefreshElementsList();
end;

procedure TEditorFrame.CloseEditorClick(Sender: TObject);
begin
  if Assigned(FHost) then
    FHost.Visible := False;
end;

end.
