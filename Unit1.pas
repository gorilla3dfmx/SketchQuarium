unit Unit1;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.Math, System.Diagnostics,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Types3D,
  System.Math.Vectors, FMX.Controls3D, Gorilla.Light, Gorilla.Viewport,
  Gorilla.Mesh, Gorilla.Cube, Gorilla.Control, Gorilla.Transform, Gorilla.Group,
  Gorilla.SkyBox, FMX.MaterialSources, Gorilla.Material.Default,
  Gorilla.Material.Custom, Gorilla.Material.Blinn, Gorilla.Plane,
  Gorilla.Material.Water, Gorilla.Controller.Passes.Reflection,
  Gorilla.Controller, Gorilla.Controller.Passes.Refraction,
  Gorilla.Material.POM, Gorilla.Material.PBR,
  Gorilla.Controller.Passes.Underwater, Gorilla.AssetsManager, Gorilla.Model,
  Gorilla.Material.Behaviour, Gorilla.Material.Behaviour.Caustics,
  Gorilla.Material.Lambert, Gorilla.Hemisphere, FMX.Objects,
  FMX.Controls.Presentation, FMX.StdCtrls, FMX.Layouts, FMX.Edit, FMX.ListBox,
  Gorilla.DefTypes, Aquarium.Elements;

type
  TForm1 = class(TForm)
    GorillaViewport1: TGorillaViewport;
    GorillaLight1: TGorillaLight;
    AquariumWalls: TGorillaGroup;
    LeftWall: TGorillaCube;
    RightWall: TGorillaCube;
    BackWall: TGorillaCube;
    FrontWall: TGorillaCube;
    AquariumWallMaterial: TGorillaBlinnMaterialSource;
    BottomWall: TGorillaCube;
    GorillaWaterMaterialSource1: TGorillaWaterMaterialSource;
    GorillaRenderPassRefraction1: TGorillaRenderPassRefraction;
    GorillaRenderPassReflection1: TGorillaRenderPassReflection;
    WaterSurface: TGorillaPlane;
    Ground: TGorillaCube;
    GorillaPBRMaterialSource1: TGorillaPBRMaterialSource;
    GorillaAssetsManager1: TGorillaAssetsManager;
    Rock: TGorillaModel;
    GorillaRenderPassUnderwater1: TGorillaRenderPassUnderwater;
    GorillaMaterialCausticsBehaviour1: TGorillaMaterialCausticsBehaviour;
    Octopus: TGorillaModel;
    GorillaHemisphere1: TGorillaHemisphere;
    GorillaLambertMaterialSource1: TGorillaLambertMaterialSource;
    ToolsArea: TRectangle;
    Rectangle1: TRectangle;
    PopupArea: TRectangle;
    Label1: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure Rectangle1Click(Sender: TObject);
  private
    { Private-Deklarationen }
    FLibrary      : TAquariumLibrary;
    FScene        : TAquariumScene;
    FAnimTimer    : TTimer;
    FClock        : TStopwatch;

    // Editor-Steuerelemente (zur Laufzeit erzeugt)
    FCanvasImage  : TImage;
    FKindCombo    : TComboBox;
    FNameEdit     : TEdit;
    FBrushSize    : TTrackBar;
    FEraserBtn    : TButton;
    FElementsList : TListBox;

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

    procedure BuildEditorUI();
    procedure RefreshElementsList();
    procedure ClearCanvas();

    function  CreateLabel(AParent: TFmxObject; const AText: String): TLabel;
    function  CreateButton(AParent: TFmxObject; const AText: String;
                AHandler: TNotifyEvent): TButton;
    procedure AddColorSwatch(AParent: TFmxObject; AColor: TAlphaColor);

    function  ImageToBitmap(const APt: TPointF): TPointF;
    procedure StrokeTo(const APt: TPointF);
    procedure EraseAt(const APt: TPointF);

    // Ereignisbehandlung
    procedure CanvasMouseDown(Sender: TObject; Button: TMouseButton;
                Shift: TShiftState; X, Y: Single);
    procedure CanvasMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
    procedure CanvasMouseUp(Sender: TObject; Button: TMouseButton;
                Shift: TShiftState; X, Y: Single);
    procedure ColorSwatchClick(Sender: TObject);
    procedure EraserClick(Sender: TObject);
    procedure ClearClick(Sender: TObject);
    procedure AcceptClick(Sender: TObject);
    procedure PlaceClick(Sender: TObject);
    procedure EditClick(Sender: TObject);
    procedure UpdateClick(Sender: TObject);
    procedure DeleteClick(Sender: TObject);
    procedure CloseEditorClick(Sender: TObject);
    procedure AnimTimerTick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);

    // Platzierungsmodus
    procedure EnterPlacement(AElement: TAquariumElement);
    procedure ExitPlacement();
    procedure EnableMeshHitTest(AMesh: TGorillaMesh);
    function  CameraRay(const APt: TPointF; out AOrigin, ADir: TPoint3D): Boolean;
    function  RayPlaneHit(const AOrigin, ADir: TPoint3D; AAxis: Integer;
                AValue: Single; out AHit: TPoint3D): Boolean;
    function  SurfacePlacement(const AOrigin, ADir: TPoint3D): TPoint3D;
    function  MouseToTankPoint(const APt: TPointF): TPoint3D;
    procedure ViewportMouseDown(Sender: TObject; Button: TMouseButton;
                Shift: TShiftState; X, Y: Single);
    procedure ViewportMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
    procedure ViewportMouseWheel(Sender: TObject; Shift: TShiftState;
                WheelDelta: Integer; var Handled: Boolean);
  public
    { Public-Deklarationen }
  end;

var
  Form1: TForm1;

implementation

{$R *.fmx}

const
  CANVAS_PX = 600;   // Pixelaufloesung der Zeichenflaeche (quadratisch)

procedure TForm1.FormCreate(Sender: TObject);
begin
  Octopus.AnimationManager.Current.Start;
  (Rock.Def as TModelDef).AcquireBVH();

  Self.OnDestroy := FormDestroy;

  FCurrentColor := TAlphaColorRec.Black;
  FEraser := False;
  FPlaceScale := 1.0;

  FLibrary := TAquariumLibrary.Create();
  FLibrary.LoadFromDisk();

  FScene := TAquariumScene.Create(GorillaViewport1, Self);

  BuildEditorUI();
  RefreshElementsList();

  // Animationsschleife (~60 fps): verformt platzierte Elemente und zeichnet neu
  FClock := TStopwatch.StartNew;
  FAnimTimer := TTimer.Create(Self);
  FAnimTimer.Interval := 16;
  FAnimTimer.OnTimer := AnimTimerTick;
  FAnimTimer.Enabled := True;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  FScene.Free();
  FLibrary.Free();
end;

procedure TForm1.AnimTimerTick(Sender: TObject);
begin
  FScene.Animate(FClock.Elapsed.TotalSeconds);
  GorillaViewport1.Invalidate();
end;

procedure TForm1.Rectangle1Click(Sender: TObject);
begin
  PopUpArea.Visible := not PopUpArea.Visible;
end;

{ ----------------------------------------------------------------------------
  UI-Aufbau (komplett im Code, damit die grosse .fmx unangetastet bleibt)
  ---------------------------------------------------------------------------- }

function TForm1.CreateLabel(AParent: TFmxObject; const AText: String): TLabel;
begin
  Result := TLabel.Create(Self);
  Result.Parent := AParent;
  Result.Align := TAlignLayout.Top;
  Result.Margins.Rect := RectF(8, 8, 8, 0);
  Result.StyledSettings := Result.StyledSettings - [TStyledSetting.Size, TStyledSetting.Style];
  Result.TextSettings.Font.Size := 15;
  Result.TextSettings.Font.Style := [TFontStyle.fsBold];
  Result.Height := 24;
  Result.Text := AText;
end;

function TForm1.CreateButton(AParent: TFmxObject; const AText: String;
  AHandler: TNotifyEvent): TButton;
begin
  Result := TButton.Create(Self);
  Result.Parent := AParent;
  Result.Align := TAlignLayout.Top;
  Result.Margins.Rect := RectF(8, 8, 8, 0);
  Result.Height := 38;
  Result.Text := AText;
  Result.OnClick := AHandler;
end;

procedure TForm1.AddColorSwatch(AParent: TFmxObject; AColor: TAlphaColor);
var LRect : TRectangle;
begin
  LRect := TRectangle.Create(Self);
  LRect.Parent := AParent;
  LRect.Width := 26;
  LRect.Height := 26;
  LRect.Margins.Rect := RectF(3, 3, 3, 3);
  LRect.Fill.Color := AColor;
  LRect.Stroke.Color := TAlphaColorRec.Gray;
  LRect.XRadius := 4;
  LRect.YRadius := 4;
  LRect.Cursor := crHandPoint;
  LRect.OnClick := ColorSwatchClick;
end;

procedure TForm1.BuildEditorUI();
var
  LLeft, LRight, LCenter, LCanvasBg : TRectangle;
  LColorRow : TFlowLayout;
begin
  // --- Kopfzeile -----------------------------------------------------------
  with CreateLabel(PopupArea, 'Aquariumselement zeichnen') do
  begin
    Margins.Rect := RectF(16, 12, 16, 4);
    TextSettings.Font.Size := 20;
    Height := 32;
  end;

  // --- Linke Spalte: gespeicherte Elemente ---------------------------------
  LLeft := TRectangle.Create(Self);
  LLeft.Parent := PopupArea;
  LLeft.Align := TAlignLayout.Left;
  LLeft.Width := 280;
  LLeft.Margins.Rect := RectF(16, 8, 8, 16);
  LLeft.Fill.Color := $22FFFFFF;
  LLeft.Stroke.Color := $33555555;
  LLeft.XRadius := 6; LLeft.YRadius := 6;

  CreateLabel(LLeft, 'Gespeicherte Elemente');

  // Bottom-Buttons stapeln sich in Hinzufuege-Reihenfolge nach oben:
  // -> zuerst das unterste, zuletzt das oberste.
  CreateButton(LLeft, 'Schließen', CloseEditorClick).Align := TAlignLayout.Bottom;
  CreateButton(LLeft, 'Löschen', DeleteClick).Align := TAlignLayout.Bottom;
  CreateButton(LLeft, 'Mit Zeichnung aktualisieren', UpdateClick).Align := TAlignLayout.Bottom;
  CreateButton(LLeft, 'Zum Bearbeiten laden', EditClick).Align := TAlignLayout.Bottom;
  CreateButton(LLeft, 'In Aquarium platzieren', PlaceClick).Align := TAlignLayout.Bottom;

  FElementsList := TListBox.Create(Self);
  FElementsList.Parent := LLeft;
  FElementsList.Align := TAlignLayout.Client;
  FElementsList.Margins.Rect := RectF(8, 4, 8, 4);
  FElementsList.ItemHeight := 56;

  // --- Rechte Spalte: Werkzeuge --------------------------------------------
  LRight := TRectangle.Create(Self);
  LRight.Parent := PopupArea;
  LRight.Align := TAlignLayout.Right;
  LRight.Width := 260;
  LRight.Margins.Rect := RectF(8, 8, 16, 16);
  LRight.Fill.Color := $22FFFFFF;
  LRight.Stroke.Color := $33555555;
  LRight.XRadius := 6; LRight.YRadius := 6;

  CreateLabel(LRight, 'Art');
  FKindCombo := TComboBox.Create(Self);
  FKindCombo.Parent := LRight;
  FKindCombo.Align := TAlignLayout.Top;
  FKindCombo.Margins.Rect := RectF(8, 4, 8, 0);
  FKindCombo.Height := 34;
  FKindCombo.Items.Add('Fisch');
  FKindCombo.Items.Add('Qualle');
  FKindCombo.Items.Add('Pflanze');
  FKindCombo.Items.Add('Koralle');
  FKindCombo.ItemIndex := 0;

  CreateLabel(LRight, 'Name');
  FNameEdit := TEdit.Create(Self);
  FNameEdit.Parent := LRight;
  FNameEdit.Align := TAlignLayout.Top;
  FNameEdit.Margins.Rect := RectF(8, 4, 8, 0);
  FNameEdit.Height := 34;
  FNameEdit.TextPrompt := 'z.B. Nemo';

  CreateLabel(LRight, 'Farbe');
  LColorRow := TFlowLayout.Create(Self);
  LColorRow.Parent := LRight;
  LColorRow.Align := TAlignLayout.Top;
  LColorRow.Margins.Rect := RectF(8, 4, 8, 0);
  LColorRow.Height := 100;
  AddColorSwatch(LColorRow, TAlphaColorRec.Black);
  AddColorSwatch(LColorRow, TAlphaColorRec.White);
  AddColorSwatch(LColorRow, TAlphaColorRec.Red);
  AddColorSwatch(LColorRow, TAlphaColorRec.Orange);
  AddColorSwatch(LColorRow, TAlphaColorRec.Gold);
  AddColorSwatch(LColorRow, TAlphaColorRec.Yellow);
  AddColorSwatch(LColorRow, TAlphaColorRec.Limegreen);
  AddColorSwatch(LColorRow, TAlphaColorRec.Green);
  AddColorSwatch(LColorRow, TAlphaColorRec.Deepskyblue);
  AddColorSwatch(LColorRow, TAlphaColorRec.Blue);
  AddColorSwatch(LColorRow, TAlphaColorRec.Purple);
  AddColorSwatch(LColorRow, TAlphaColorRec.Magenta);
  AddColorSwatch(LColorRow, TAlphaColorRec.Saddlebrown);
  AddColorSwatch(LColorRow, TAlphaColorRec.Pink);

  CreateLabel(LRight, 'Pinselgröße');
  FBrushSize := TTrackBar.Create(Self);
  FBrushSize.Parent := LRight;
  FBrushSize.Align := TAlignLayout.Top;
  FBrushSize.Margins.Rect := RectF(8, 4, 8, 0);
  FBrushSize.Height := 34;
  FBrushSize.Min := 1;
  FBrushSize.Max := 60;
  FBrushSize.Value := 14;

  FEraserBtn := CreateButton(LRight, 'Radierer', EraserClick);
  CreateButton(LRight, 'Leeren', ClearClick);
  CreateButton(LRight, 'Übernehmen && Speichern', AcceptClick);

  // --- Mitte: Zeichenflaeche -----------------------------------------------
  LCenter := TRectangle.Create(Self);
  LCenter.Parent := PopupArea;
  LCenter.Align := TAlignLayout.Client;
  LCenter.Margins.Rect := RectF(8, 8, 8, 16);
  LCenter.Fill.Kind := TBrushKind.None;
  LCenter.Stroke.Kind := TBrushKind.None;

  LCanvasBg := TRectangle.Create(Self);
  LCanvasBg.Parent := LCenter;
  LCanvasBg.Align := TAlignLayout.Center;
  LCanvasBg.Width := 560;
  LCanvasBg.Height := 560;
  LCanvasBg.Fill.Color := TAlphaColorRec.White;
  LCanvasBg.Stroke.Color := $66333333;
  LCanvasBg.Stroke.Thickness := 2;
  LCanvasBg.XRadius := 6; LCanvasBg.YRadius := 6;

  FCanvasImage := TImage.Create(Self);
  FCanvasImage.Parent := LCanvasBg;
  FCanvasImage.Align := TAlignLayout.Client;
  FCanvasImage.Margins.Rect := RectF(4, 4, 4, 4);
  FCanvasImage.WrapMode := TImageWrapMode.Stretch;
  FCanvasImage.HitTest := True;
  FCanvasImage.OnMouseDown := CanvasMouseDown;
  FCanvasImage.OnMouseMove := CanvasMouseMove;
  FCanvasImage.OnMouseUp := CanvasMouseUp;

  ClearCanvas();

  // --- Hinweisleiste fuer den Platzierungsmodus (ueber dem 3D-Viewport) -----
  FHintBar := TRectangle.Create(Self);
  FHintBar.Parent := GorillaViewport1;
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

procedure TForm1.RefreshElementsList();
var
  i     : Integer;
  LEl   : TAquariumElement;
  LItem : TListBoxItem;
  LBg   : TRectangle;
  LImg  : TImage;
  LLbl  : TLabel;
begin
  FElementsList.BeginUpdate();
  try
    FElementsList.Clear();
    for i := 0 to FLibrary.Items.Count - 1 do
    begin
      LEl := FLibrary.Items[i];

      LItem := TListBoxItem.Create(FElementsList);
      LItem.Parent := FElementsList;
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
    FElementsList.EndUpdate();
  end;
end;

procedure TForm1.ClearCanvas();
begin
  if (FCanvasImage.Bitmap.Width <> CANVAS_PX) then
    FCanvasImage.Bitmap.SetSize(CANVAS_PX, CANVAS_PX);
  // Voll transparent loeschen -> transparente Bereiche bleiben spaeter transparent
  FCanvasImage.Bitmap.Clear(TAlphaColorRec.Null);
  FCanvasImage.Repaint();
end;

{ ----------------------------------------------------------------------------
  Zeichnen
  ---------------------------------------------------------------------------- }

function TForm1.ImageToBitmap(const APt: TPointF): TPointF;
begin
  // Steuerelement-lokale Koordinaten -> Bitmap-Pixel
  if (FCanvasImage.Width <= 0) or (FCanvasImage.Height <= 0) then
    Exit(APt);
  Result.X := APt.X / FCanvasImage.Width  * FCanvasImage.Bitmap.Width;
  Result.Y := APt.Y / FCanvasImage.Height * FCanvasImage.Bitmap.Height;
end;

procedure TForm1.StrokeTo(const APt: TPointF);
var r : Single;
begin
  r := FBrushSize.Value / 2;
  if FCanvasImage.Bitmap.Canvas.BeginScene() then
  try
    FCanvasImage.Bitmap.Canvas.Stroke.Kind := TBrushKind.Solid;
    FCanvasImage.Bitmap.Canvas.Stroke.Color := FCurrentColor;
    FCanvasImage.Bitmap.Canvas.Stroke.Thickness := FBrushSize.Value;
    FCanvasImage.Bitmap.Canvas.Stroke.Cap := TStrokeCap.Round;
    FCanvasImage.Bitmap.Canvas.Stroke.Join := TStrokeJoin.Round;
    FCanvasImage.Bitmap.Canvas.DrawLine(FLastPt, APt, 1);
    // Punkt am Ende sichern (sonst fehlen Einzelklicks / Kurvenenden)
    FCanvasImage.Bitmap.Canvas.Fill.Kind := TBrushKind.Solid;
    FCanvasImage.Bitmap.Canvas.Fill.Color := FCurrentColor;
    FCanvasImage.Bitmap.Canvas.FillEllipse(
      RectF(APt.X - r, APt.Y - r, APt.X + r, APt.Y + r), 1);
  finally
    FCanvasImage.Bitmap.Canvas.EndScene();
  end;
  FCanvasImage.Repaint();
end;

procedure TForm1.EraseAt(const APt: TPointF);
var
  LData : TBitmapData;
  r, x0, y0, x1, y1, xx, yy : Integer;
begin
  r := Round(FBrushSize.Value / 2) + 1;
  if not FCanvasImage.Bitmap.Map(TMapAccess.ReadWrite, LData) then
    Exit;
  try
    x0 := Max(0, Round(APt.X) - r);
    y0 := Max(0, Round(APt.Y) - r);
    x1 := Min(FCanvasImage.Bitmap.Width  - 1, Round(APt.X) + r);
    y1 := Min(FCanvasImage.Bitmap.Height - 1, Round(APt.Y) + r);
    for yy := y0 to y1 do
      for xx := x0 to x1 do
        if Sqr(xx - APt.X) + Sqr(yy - APt.Y) <= Sqr(r) then
          LData.SetPixel(xx, yy, TAlphaColorRec.Null);
  finally
    FCanvasImage.Bitmap.Unmap(LData);
  end;
  FCanvasImage.Repaint();
end;

procedure TForm1.CanvasMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
begin
  FDrawing := True;
  FLastPt := ImageToBitmap(PointF(X, Y));
  if FEraser then
    EraseAt(FLastPt)
  else
    StrokeTo(FLastPt);
end;

procedure TForm1.CanvasMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
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

procedure TForm1.CanvasMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
begin
  FDrawing := False;
end;

{ ----------------------------------------------------------------------------
  Werkzeug-Aktionen
  ---------------------------------------------------------------------------- }

procedure TForm1.ColorSwatchClick(Sender: TObject);
begin
  FCurrentColor := (Sender as TRectangle).Fill.Color;
  FEraser := False;
  FEraserBtn.Text := 'Radierer';
end;

procedure TForm1.EraserClick(Sender: TObject);
begin
  FEraser := not FEraser;
  if FEraser then
    FEraserBtn.Text := 'Radierer (aktiv)'
  else
    FEraserBtn.Text := 'Radierer';
end;

procedure TForm1.ClearClick(Sender: TObject);
begin
  ClearCanvas();
end;

procedure TForm1.AcceptClick(Sender: TObject);
var LKind : TAquariumKind;
begin
  if FKindCombo.ItemIndex < 0 then
  begin
    ShowMessage('Bitte zuerst eine Art waehlen.');
    Exit;
  end;

  LKind := TAquariumKind(FKindCombo.ItemIndex);
  FLibrary.SaveElement(LKind, FNameEdit.Text, FCanvasImage.Bitmap);

  RefreshElementsList();
  FElementsList.ItemIndex := FElementsList.Count - 1;

  // Fuer die naechste Zeichnung aufraeumen
  ClearCanvas();
  FNameEdit.Text := '';
end;

procedure TForm1.PlaceClick(Sender: TObject);
begin
  if (FElementsList.ItemIndex < 0)
  or (FElementsList.ItemIndex >= FLibrary.Items.Count) then
  begin
    ShowMessage('Bitte ein Element aus der Liste waehlen.');
    Exit;
  end;

  PopupArea.Visible := False;
  EnterPlacement(FLibrary.Items[FElementsList.ItemIndex]);
end;

{ ----------------------------------------------------------------------------
  Platzierungsmodus: Vorschau folgt der Maus, Linksklick platziert,
  Rechtsklick beendet den Modus.
  ---------------------------------------------------------------------------- }

procedure TForm1.EnableMeshHitTest(AMesh: TGorillaMesh);
var i : Integer;
begin
  if not Assigned(AMesh) then
    Exit;
  // Der Raycast (DoInternalRayCastIntersectTriangle) testet Submeshes nur, wenn
  // HitTest aktiv ist - daher die komplette Hierarchie freischalten.
  AMesh.HitTest := True;
  if Assigned(AMesh.Meshes) then
    for i := 0 to AMesh.Meshes.Count - 1 do
      EnableMeshHitTest(AMesh.Meshes[i]);
end;

procedure TForm1.EnterPlacement(AElement: TAquariumElement);
begin
  ExitPlacement();   // evtl. laufende Vorschau zuerst aufraeumen

  // Sicherstellen, dass das Stein-Modell (inkl. geladener Submeshes) per
  // Raycast getroffen werden kann.
  EnableMeshHitTest(Rock);

  FPlacingElement := AElement;

  // Vorschau-Instanz erzeugen: eingefroren, damit sie exakt der Maus folgt
  FPreview := FScene.Spawn(AElement);
  FPreview.Frozen := True;
  FPreview.SetSizeScale(FPlaceScale);            // zuletzt gewaehlte Groesse
  FPreview.SetBasePosition(Point3D(0, 4.5, 0));  // Startpunkt: Tankmitte

  FLastMousePt := PointF(GorillaViewport1.Width / 2, GorillaViewport1.Height / 2);

  // Maus-Events nur jetzt aktiv schalten - sonst deaktivieren sie die
  // Design-Kamera-Navigation der Viewport.
  GorillaViewport1.OnMouseDown := ViewportMouseDown;
  GorillaViewport1.OnMouseMove := ViewportMouseMove;
  GorillaViewport1.OnMouseWheel := ViewportMouseWheel;

  FHintBar.Visible := True;
  FHintBar.BringToFront();
end;

procedure TForm1.ExitPlacement();
begin
  // Maus-Events wieder loesen -> Design-Navigation ist erneut aktiv.
  GorillaViewport1.OnMouseDown := nil;
  GorillaViewport1.OnMouseMove := nil;
  GorillaViewport1.OnMouseWheel := nil;

  if Assigned(FPreview) then
    FScene.Remove(FPreview);
  FPreview := nil;
  FPlacingElement := nil;
  if Assigned(FHintBar) then
    FHintBar.Visible := False;
end;


function TForm1.CameraRay(const APt: TPointF; out AOrigin, ADir: TPoint3D): Boolean;
var
  LCam : TCamera;
  LVec : TVector3D;
  LFar : TPoint3D;
begin
  Result := False;

  if GorillaViewport1.UsingDesignCamera then
    LCam := GorillaViewport1.GetDesignCamera()
  else
    LCam := GorillaViewport1.Camera;
  if not Assigned(LCam) then
    Exit;

  LVec := LCam.AbsolutePosition;
  AOrigin := Point3D(LVec.X, LVec.Y, LVec.Z);

  // Punkt auf dem Sichtstrahl durch den Mauszeiger -> Richtung ableiten
  LFar := GorillaViewport1.ScreenToWorld(APt);
  ADir := (LFar - AOrigin).Normalize();
  Result := True;
end;

function TForm1.RayPlaneHit(const AOrigin, ADir: TPoint3D; AAxis: Integer;
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

function TForm1.SurfacePlacement(const AOrigin, ADir: TPoint3D): TPoint3D;
const
  FLOOR_Y = 6.5;          // Oberkante des Ground-Cubes (Y=7, Hoehe 1)
var
  LRes  : TTriangleRayCastResult;
  LHit  : TPoint3D;
  LHave : Boolean;
  LH    : Single;
begin
  LHave := False;

  // 1) Steinoberflaeche abtasten (low-poly Mesh, inkl. Submeshes).
  //    Wichtig: den ABSOLUTEN Strahl (aus der aktiven Design-Kamera) verwenden -
  //    die (X,Y)-Variante von PickTriangle nutzt intern Context.Pick mit
  //    TProjection.Camera und liefert bei Design-Kamera einen falschen Strahl.
  if Assigned(Rock)
  and Rock.PickTriangle(Vector3D(AOrigin.X, AOrigin.Y, AOrigin.Z),
                        Vector3D(ADir.X, ADir.Y, ADir.Z), LRes) then
  begin
    LHit := LRes.Intersection;
    LHave := True;
  end;

  // 2) sonst auf den Boden (analytische Ebene, schnell - Ground hat 256er
  //    Subdivisions und waere als Mesh-Raycast zu teuer)
  if not LHave then
    if not RayPlaneHit(AOrigin, ADir, 1, FLOOR_Y, LHit) then
      LHit := Point3D(0, FLOOR_Y, 0);

  // Wurzel (untere Plane-Kante) auf die Oberflaeche setzen: Mittelpunkt um
  // halbe Hoehe nach oben (Welt-Oben = -Y)
  LH := 0;
  if Assigned(FPreview) and Assigned(FPreview.Plane) then
    LH := FPreview.Plane.Height * FPreview.Plane.Scale.Y;  // inkl. Mausrad-Skalierung

  Result := Point3D(LHit.X, LHit.Y - LH / 2, LHit.Z);
  Result.X := Max(-9.0, Min(9.0, Result.X));
  Result.Z := Max(-9.0, Min(9.0, Result.Z));
end;

function TForm1.MouseToTankPoint(const APt: TPointF): TPoint3D;
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
    Result := SurfacePlacement(LOrigin, LDir);
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

procedure TForm1.ViewportMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Single);
begin
  if not Assigned(FPreview) then
    Exit;
  FLastMousePt := PointF(X, Y);
  FPreview.SetBasePosition(MouseToTankPoint(FLastMousePt));
end;

procedure TForm1.ViewportMouseWheel(Sender: TObject; Shift: TShiftState;
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

procedure TForm1.ViewportMouseDown(Sender: TObject; Button: TMouseButton;
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

procedure TForm1.EditClick(Sender: TObject);
var LEl : TAquariumElement;
begin
  if (FElementsList.ItemIndex < 0)
  or (FElementsList.ItemIndex >= FLibrary.Items.Count) then
  begin
    ShowMessage('Bitte ein Element zum Bearbeiten waehlen.');
    Exit;
  end;

  // Gewaehltes Element in den Editor laden
  LEl := FLibrary.Items[FElementsList.ItemIndex];
  FKindCombo.ItemIndex := Ord(LEl.Kind);
  FNameEdit.Text := LEl.Name;
  if (FCanvasImage.Bitmap.Width <> CANVAS_PX) then
    FCanvasImage.Bitmap.SetSize(CANVAS_PX, CANVAS_PX);
  FCanvasImage.Bitmap.Assign(LEl.Bitmap);
  FCanvasImage.Repaint();
end;

procedure TForm1.UpdateClick(Sender: TObject);
var
  LIdx  : Integer;
  LKind : TAquariumKind;
begin
  LIdx := FElementsList.ItemIndex;
  if (LIdx < 0) or (LIdx >= FLibrary.Items.Count) then
  begin
    ShowMessage('Bitte ein Element zum Aktualisieren waehlen.');
    Exit;
  end;

  if FKindCombo.ItemIndex < 0 then
    LKind := FLibrary.Items[LIdx].Kind
  else
    LKind := TAquariumKind(FKindCombo.ItemIndex);

  FLibrary.UpdateElement(LIdx, LKind, FNameEdit.Text, FCanvasImage.Bitmap);
  RefreshElementsList();
  FElementsList.ItemIndex := LIdx;
end;

procedure TForm1.DeleteClick(Sender: TObject);
var LIdx : Integer;
begin
  LIdx := FElementsList.ItemIndex;
  if (LIdx < 0) or (LIdx >= FLibrary.Items.Count) then
  begin
    ShowMessage('Bitte ein Element zum Loeschen waehlen.');
    Exit;
  end;

  FLibrary.DeleteElement(LIdx);
  RefreshElementsList();
end;

procedure TForm1.CloseEditorClick(Sender: TObject);
begin
  PopupArea.Visible := False;
end;

end.
