unit Aquarium.EditorFrame;

{
  SketchQuarium - Zeicheneditor als FireMonkey-Frame

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
  System.Math.Vectors, System.Generics.Collections, System.IOUtils,
  System.Skia, FMX.Skia,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Objects,
  FMX.Controls.Presentation, FMX.StdCtrls, FMX.Layouts, FMX.Edit, FMX.ListBox,
  FMX.Types3D, FMX.Controls3D,
  Gorilla.Viewport, Gorilla.Mesh, Gorilla.Model, Gorilla.DefTypes, Gorilla.Control,
  Gorilla.Terrain, Gorilla.Utils.Inventory,
  Aquarium.Elements, Aquarium.Placement;

type
  /// <summary>Eine aus einer SVG-Datei geladene Schablonen-Vorlage.</summary>
  TStencilItem = record
    Kind : TAquariumKind;   // zu welcher Art gehoert die Vorlage
    Name : String;          // Dateiname (ohne Endung) -> Hinweistext
    Svg  : String;          // roher SVG-Inhalt (von Skia gerendert)
  end;

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
    BrushTypeLabel: TLabel;
    BrushRow: TFlowLayout;
    BrushRound: TRectangle;
    BrushSoft: TRectangle;
    BrushExtraSoft: TRectangle;
    BrushElongated: TRectangle;
    BrushLabel: TLabel;
    BrushSize: TTrackBar;
    EraserBtn: TButton;
    ClearBtn: TButton;
    AcceptBtn: TButton;
    CenterPanel: TRectangle;
    StencilBar: TFlowLayout;
    StencilLabel: TLabel;
    StencilFish: TRectangle;
    StencilJelly: TRectangle;
    StencilPlant: TRectangle;
    StencilCoral: TRectangle;
    FreehandBtn: TButton;
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
    procedure BrushSwatchClick(Sender: TObject);
    procedure StencilSwatchClick(Sender: TObject);
    procedure FreehandClick(Sender: TObject);
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
    FLibrary  : TAquariumLibrary;     // geteiltes Inventar (Eigentum des Formulars)
    FViewport : TGorillaViewport;     // 3D-Viewport (Eigentum des Formulars)
    FHost     : TControl;             // Popup-Flaeche, die der Frame ausblenden darf
    FPlacement : TAquariumPlacement;  // Platzierungsmodus (eigene Unit)

    // Zeichen-Zustand
    FCurrentColor : TAlphaColor;
    FBrushType    : Integer;          // 0 = rund, 1 = sehr weich, 2 = laenglich
    FEraser       : Boolean;
    FDrawing      : Boolean;
    FLastPt       : TPointF;

    // aktuell umrahmte (selektierte) Felder fuer Farbe bzw. Pinsel
    FSelColorSwatch : TRectangle;
    FSelBrushSwatch : TRectangle;

    // Schablonen (aus SVG-Vorlagen geladene Silhouetten zum Ausmalen)
    FStencilActive   : Boolean;
    FStencilMask     : TArray<Single>;   // 0..1 Deckung der Form, in Bitmap-Pixeln
    FStencilGuide    : TImage;           // Kontur-Overlay ueber der Zeichenflaeche
    FSelStencil      : TRectangle;       // aktuell umrahmtes Schablonenfeld
    FStencils        : TList<TStencilItem>;  // alle geladenen Vorlagen (nach Art)
    FStencilSwatches : TList<TRectangle>;    // dynamische Felder der aktuellen Art
    FSvgBrush        : TSkSvgBrush;          // Skia-Renderer fuer die SVGs
    FUpdatingKind    : Boolean;          // unterdrueckt KindCombo.OnChange-Reentrancy

    // Zustand fuer den weichen Pinsel: ein Schnappschuss des Bildes zu
    // Strichbeginn plus ein Deckungspuffer. So laesst sich der Strich aus der
    // Basis neu zusammensetzen und es entsteht kein Farbaufbau an Ueberlappungen.
    FStrokeActive : Boolean;
    FStrokeBase   : TBitmap;
    FStrokeCov    : TArray<Single>;

    procedure RefreshElementsList();
    procedure ClearCanvas();

    // Pinselvorschauen aufbauen und Auswahlrahmen verwalten
    procedure BuildBrushPreviews();
    procedure SelectColorSwatch(ASwatch: TRectangle);
    procedure SelectBrushSwatch(ASwatch: TRectangle);

    // Schablonen (aus SVG-Vorlagen via Skia)
    function  ShapesDir(): String;
    procedure LoadStencils();
    procedure RenderStencil(const ASvg: String; ADst: TBitmap; const ADest: TRectF;
                ATint: TAlphaColor);
    procedure RebuildStencilBar(AKind: TAquariumKind);
    procedure BuildStencilMask(const ASvg: String);
    procedure ActivateStencil(AIndex: Integer; ASwatch: TRectangle);
    procedure DeactivateStencil();
    procedure ApplyStencilClip(const A, B: TPointF);
    procedure KindComboChange(Sender: TObject);

    function  ImageToBitmap(const APt: TPointF): TPointF;
    procedure StrokeTo(const APt: TPointF);
    procedure StrokeRound(const A, B: TPointF);
    procedure StrokeSoft(const A, B: TPointF);
    procedure StrokeExtraSoft(const A, B: TPointF);
    procedure SoftStrokeCore(const A, B: TPointF; AScale, ACoreFrac, APeak: Single);
    procedure StrokeElongated(const A, B: TPointF);
    procedure BeginSoftStroke();
    procedure EraseAt(const APt: TPointF);
  public
    { Public-Deklarationen }
    destructor Destroy(); override;

    /// <summary>
    ///  Verknuepft den Editor mit der 3D-Szene und dem geteilten Inventar und
    ///  initialisiert ihn: leert die Zeichenflaeche und baut die Liste auf.
    ///  Das Inventar (ALibrary) gehoert dem Aufrufer (Formular).
    /// </summary>
    procedure Init(AScene: TAquariumScene; ALibrary: TAquariumLibrary;
      AViewport: TGorillaViewport; ARock: TGorillaModel; AHost: TControl);

    procedure Place3DObject(ACtrl : TGorillaMesh);

    /// <summary>
    ///  Baut die Elementliste neu auf (z.B. nachdem von aussen ein Setup
    ///  geladen wurde und sich der Vorlagenbestand geaendert hat).
    /// </summary>
    procedure RefreshLibrary();

    /// <summary>
    ///  Startet den Platzierungsmodus fuer eine Vorlage (z.B. aus dem
    ///  Inventar-Katalog des Hauptfensters) und blendet das Host-Popup aus.
    /// </summary>
    procedure PlaceTemplate(ATemplate: TGorillaInventoryItemTemplate);
  end;

implementation

{$R *.fmx}

const
  CANVAS_PX = 600;   // Pixelaufloesung der Zeichenflaeche (quadratisch)

  // Rahmen der anklickbaren Felder (Farben + Pinsel)
  SWATCH_STROKE_DEF = TAlphaColor($FF808080);   // Standardrahmen (grau)
  SWATCH_STROKE_SEL = TAlphaColor($FF2196F3);   // Auswahlrahmen (kraeftiges Blau)
  SWATCH_THICK_DEF  = 1.0;
  SWATCH_THICK_SEL  = 3.0;

  PREVIEW_INK = TAlphaColor($FF20272E);          // Vorschaufarbe der Pinselstempel

  // Weicher Pinsel: etwas groesser als die eingestellte Groesse und mit einem
  // voll deckenden Kern, damit die Mitte fuelliger wirkt.
  SOFT_SCALE = 1.35;    // Radius-Faktor bei der Benutzung
  SOFT_CORE  = 0.45;    // Anteil des voll deckenden Kerns am Radius

  // Extra weicher Pinsel: noch groesser, ohne deckenden Kern und mit
  // reduzierter Spitzendeckung -> sehr zarter, hauchiger Auftrag.
  XSOFT_SCALE = 1.7;    // Radius-Faktor (noch groesser)
  XSOFT_PEAK  = 0.6;    // maximale Deckung in der Mitte (< 1 -> weicher)

  // Vorschaufarben der Schablonen (je Art ein typischer Ton)
  STENCIL_COLORS : array[TAquariumKind] of TAlphaColor = (
    TAlphaColor($FFEF8A3B),   // Fisch  - orange
    TAlphaColor($FFB561C9),   // Qualle - violett
    TAlphaColor($FF3FA84B),   // Pflanze- gruen
    TAlphaColor($FFE76E8A));  // Koralle- koralle/rosa

  STENCIL_GUIDE_INK = TAlphaColor($AA404848);   // Kontur des Guide-Overlays

{ ----------------------------------------------------------------------------
  Initialisierung / Aufraeumen
  ---------------------------------------------------------------------------- }

procedure TEditorFrame.Init(AScene: TAquariumScene; ALibrary: TAquariumLibrary;
  AViewport: TGorillaViewport; ARock: TGorillaModel; AHost: TControl);
begin
  FScene    := AScene;
  FLibrary  := ALibrary;
  FViewport := AViewport;
  FHost     := AHost;

  // Platzierungsmodus in eigener Unit kapseln (Vorschau, Raycast, Hinweisleiste).
  FPlacement := TAquariumPlacement.Create(FScene, FViewport, Self);

  FStencils        := TList<TStencilItem>.Create();
  FStencilSwatches := TList<TRectangle>.Create();
  FSvgBrush        := TSkSvgBrush.Create();
  FSvgBrush.WrapMode := TSkSvgWrapMode.Fit;   // Silhouette in das Feld einpassen

  FCurrentColor := TAlphaColorRec.Black;
  FBrushType    := 0;
  FEraser       := False;

  ClearCanvas();
  RefreshElementsList();

  // Maus fangen, damit das MouseUp auch dann ankommt, wenn man beim Zeichnen
  // ueber den Rand der Zeichenflaeche hinauszieht und dort loslaesst.
  CanvasImage.AutoCapture := True;

  // Pinselvorschauen rendern und Startauswahl (Schwarz / runder Pinsel) rahmen
  BuildBrushPreviews();
  SelectColorSwatch(SwatchBlack);
  SelectBrushSwatch(BrushRound);

  // Kontur-Overlay fuer die Schablonen (liegt ueber der Zeichenflaeche, faengt
  // aber keine Maus-Ereignisse ab) und die Schablonen-Vorschauen aufbauen.
  FStencilGuide := TImage.Create(Self);
  FStencilGuide.Parent := CanvasBg;
  FStencilGuide.Align := TAlignLayout.Client;
  // Muss exakt das Anzeige-Rechteck von CanvasImage abdecken, sonst liegt die
  // Kontur versetzt/groesser ueber dem tatsaechlich geklippten Bereich.
  // -> dieselben Raender wie CanvasImage (16 px).
  FStencilGuide.Margins.Rect := RectF(16, 16, 16, 16);
  FStencilGuide.HitTest := False;
  FStencilGuide.WrapMode := TImageWrapMode.Stretch;
  FStencilGuide.Visible := False;

  // Die vier festen Entwurfszeit-Felder werden durch dynamische, aus den
  // SVG-Vorlagen erzeugte Felder ersetzt -> aus der Leiste nehmen.
  StencilFish.Parent  := nil;
  StencilJelly.Parent := nil;
  StencilPlant.Parent := nil;
  StencilCoral.Parent := nil;

  // SVG-Vorlagen laden und die Leiste fuer die aktuell gewaehlte Art aufbauen.
  // Ein Wechsel der Art (KindCombo) baut die Leiste neu auf.
  LoadStencils();
  KindCombo.OnChange := KindComboChange;
  RebuildStencilBar(TAquariumKind(Max(0, KindCombo.ItemIndex)));
end;

destructor TEditorFrame.Destroy();
begin
  // Beendet einen evtl. laufenden Platzierungsmodus und loest die
  // Viewport-Maus-Events (Szene/Viewport leben zu diesem Zeitpunkt noch).
  FPlacement.Free();
  // FLibrary gehoert dem Formular und wird von diesem freigegeben.
  FStrokeBase.Free();
  FStencils.Free();
  FStencilSwatches.Free();
  FSvgBrush.Free();
  inherited;
end;

procedure TEditorFrame.Place3DObject(ACtrl : TGorillaMesh);
begin
  FPlacement.RegisterSurface(ACtrl);
end;

procedure TEditorFrame.RefreshLibrary();
begin
  RefreshElementsList();
end;

procedure TEditorFrame.RefreshElementsList();
var
  i     : Integer;
  LTpl  : TGorillaInventoryItemTemplate;
  LItem : TListBoxItem;
  LBg   : TRectangle;
  LImg  : TImage;
  LLbl  : TLabel;
  LBmp  : TBitmap;
begin
  ElementsList.BeginUpdate();
  try
    ElementsList.Clear();
    for i := 0 to FLibrary.Count - 1 do
    begin
      LTpl := FLibrary.GetTemplate(i);

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
      LBmp := AquariumTemplateBitmap(LTpl);
      if Assigned(LBmp) then
        LImg.Bitmap.Assign(LBmp);

      LLbl := TLabel.Create(LItem);
      LLbl.Parent := LItem;
      LLbl.Align := TAlignLayout.Client;
      LLbl.Margins.Rect := RectF(4, 0, 4, 0);
      LLbl.HitTest := False;
      LLbl.StyledSettings := LLbl.StyledSettings - [TStyledSetting.Size];
      LLbl.TextSettings.Font.Size := 14;
      LLbl.Text := AQUARIUM_KIND_NAMES[AquariumTemplateKind(LTpl)] + ': ' +
                   AquariumTemplateName(LTpl);
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
  Pinselvorschauen + Auswahlrahmen
  ---------------------------------------------------------------------------- }

procedure TEditorFrame.BuildBrushPreviews();

  // Zeichnet in das Pinselfeld eine kleine, repraesentative Vorschau des
  // jeweiligen Pinselstempels (rund / weich / laenglich).
  procedure MakePreview(ASwatch: TRectangle; AKind: Integer);
  var
    LImg : TImage;
    bmp  : TBitmap;
    cx, cy, r : Single;
    m  : TMatrix;
    gp : TGradientPoint;
    softInk : TAlphaColor;
  begin
    if not Assigned(ASwatch) then
      Exit;

    LImg := TImage.Create(ASwatch);
    LImg.Parent := ASwatch;
    LImg.Align := TAlignLayout.Client;
    LImg.Margins.Rect := RectF(5, 5, 5, 5);
    LImg.HitTest := False;             // Klick faellt auf das Rechteck zurueck
    LImg.WrapMode := TImageWrapMode.Fit;

    bmp := LImg.Bitmap;
    bmp.SetSize(64, 64);
    bmp.Clear(TAlphaColorRec.Null);
    cx := 32; cy := 32; r := 22;

    if bmp.Canvas.BeginScene() then
    try
      case AKind of
        1: // sehr weich: radialer Verlauf von voller Deckung nach transparent
          begin
            bmp.Canvas.Fill.Kind := TBrushKind.Gradient;
            bmp.Canvas.Fill.Gradient.Style := TGradientStyle.Radial;
            bmp.Canvas.Fill.Gradient.Points.Clear();
            gp := TGradientPoint(bmp.Canvas.Fill.Gradient.Points.Add());
            gp.Color := PREVIEW_INK;          gp.Offset := 0;
            gp := TGradientPoint(bmp.Canvas.Fill.Gradient.Points.Add());
            gp.Color := PREVIEW_INK;          gp.Offset := SOFT_CORE;   // voller Kern
            gp := TGradientPoint(bmp.Canvas.Fill.Gradient.Points.Add());
            gp.Color := TAlphaColorRec.Null;  gp.Offset := 1;
            bmp.Canvas.FillEllipse(RectF(cx - r, cy - r, cx + r, cy + r), 1);
          end;

        2: // laenglich: um 45 Grad gedrehte, schmale Ellipse (kalligrafisch)
          begin
            bmp.Canvas.Fill.Kind := TBrushKind.Solid;
            bmp.Canvas.Fill.Color := PREVIEW_INK;
            m := TMatrix.CreateRotation(45 * Pi / 180)
               * TMatrix.CreateTranslation(cx, cy);
            bmp.Canvas.SetMatrix(m);
            bmp.Canvas.FillEllipse(RectF(-r, -r * 0.32, r, r * 0.32), 1);
            bmp.Canvas.SetMatrix(TMatrix.Identity);
          end;

        3: // extra weich: kernloser, zarter Verlauf mit reduzierter Spitze
          begin
            // Mittelpunktfarbe auf die reduzierte Spitzendeckung setzen.
            softInk := (PREVIEW_INK and $00FFFFFF)
                     or (TAlphaColor(Round(XSOFT_PEAK * 255)) shl 24);
            bmp.Canvas.Fill.Kind := TBrushKind.Gradient;
            bmp.Canvas.Fill.Gradient.Style := TGradientStyle.Radial;
            bmp.Canvas.Fill.Gradient.Points.Clear();
            gp := TGradientPoint(bmp.Canvas.Fill.Gradient.Points.Add());
            gp.Color := softInk;              gp.Offset := 0;
            gp := TGradientPoint(bmp.Canvas.Fill.Gradient.Points.Add());
            gp.Color := TAlphaColorRec.Null;  gp.Offset := 1;
            bmp.Canvas.FillEllipse(RectF(cx - r, cy - r, cx + r, cy + r), 1);
          end;
      else // rund: voller Kreis
        begin
          bmp.Canvas.Fill.Kind := TBrushKind.Solid;
          bmp.Canvas.Fill.Color := PREVIEW_INK;
          bmp.Canvas.FillEllipse(RectF(cx - r, cy - r, cx + r, cy + r), 1);
        end;
      end;
    finally
      bmp.Canvas.EndScene();
    end;
    LImg.Repaint();
  end;

begin
  MakePreview(BrushRound,     0);
  MakePreview(BrushSoft,      1);
  MakePreview(BrushExtraSoft, 3);
  MakePreview(BrushElongated, 2);
end;

procedure TEditorFrame.SelectColorSwatch(ASwatch: TRectangle);
begin
  if not Assigned(ASwatch) then
    Exit;
  FCurrentColor := ASwatch.Fill.Color;

  if Assigned(FSelColorSwatch) then
  begin
    FSelColorSwatch.Stroke.Color := SWATCH_STROKE_DEF;
    FSelColorSwatch.Stroke.Thickness := SWATCH_THICK_DEF;
  end;
  FSelColorSwatch := ASwatch;
  ASwatch.Stroke.Color := SWATCH_STROKE_SEL;
  ASwatch.Stroke.Thickness := SWATCH_THICK_SEL;
end;

procedure TEditorFrame.SelectBrushSwatch(ASwatch: TRectangle);
begin
  if not Assigned(ASwatch) then
    Exit;
  FBrushType := Integer(ASwatch.Tag);

  if Assigned(FSelBrushSwatch) then
  begin
    FSelBrushSwatch.Stroke.Color := SWATCH_STROKE_DEF;
    FSelBrushSwatch.Stroke.Thickness := SWATCH_THICK_DEF;
  end;
  FSelBrushSwatch := ASwatch;
  ASwatch.Stroke.Color := SWATCH_STROKE_SEL;
  ASwatch.Stroke.Thickness := SWATCH_THICK_SEL;
end;

{ ----------------------------------------------------------------------------
  Schablonen (Silhouetten zum Ausmalen)
  ---------------------------------------------------------------------------- }

// Sucht den Ordner assets/shapes ausgehend vom Programmverzeichnis nach oben
// (deckt EXE im Projektordner wie auch in Win64\Debug o.ae. ab).
function TEditorFrame.ShapesDir(): String;
var
  LBase, LCand : String;
  i : Integer;
begin
  Result := '';
  LBase := System.IOUtils.TPath.GetDirectoryName(ParamStr(0));
  for i := 0 to 6 do
  begin
    if LBase = '' then
      Break;
    LCand := System.IOUtils.TPath.Combine(System.IOUtils.TPath.Combine(LBase, 'assets'), 'shapes');
    if TDirectory.Exists(LCand) then
      Exit(LCand);
    LBase := System.IOUtils.TPath.GetDirectoryName(LBase);
  end;
end;

// Liest alle SVG-Vorlagen je Art aus assets/shapes/<unterordner> ein.
procedure TEditorFrame.LoadStencils();
const
  KIND_DIRS : array[TAquariumKind] of String =
    ('fish', 'jelly', 'plant', 'coral');
var
  LRoot, LDir, LFile : String;
  LKind : TAquariumKind;
  LItem : TStencilItem;
begin
  FStencils.Clear();
  LRoot := ShapesDir();
  if LRoot = '' then
    Exit;

  for LKind := Low(TAquariumKind) to High(TAquariumKind) do
  begin
    LDir := System.IOUtils.TPath.Combine(LRoot, KIND_DIRS[LKind]);
    if not TDirectory.Exists(LDir) then
      Continue;
    for LFile in TDirectory.GetFiles(LDir, '*.svg') do
    begin
      try
        LItem.Svg := TFile.ReadAllText(LFile);
      except
        Continue;     // unlesbare Datei ueberspringen
      end;
      if Trim(LItem.Svg) = '' then
        Continue;
      LItem.Kind := LKind;
      LItem.Name := System.IOUtils.TPath.GetFileNameWithoutExtension(LFile);
      FStencils.Add(LItem);
    end;
  end;
end;

// Rendert eine SVG-Silhouette per Skia in ADest (Bereich der bereits
// dimensionierten Bitmap ADst). ATint faerbt die gesamte Form ein.
procedure TEditorFrame.RenderStencil(const ASvg: String; ADst: TBitmap;
  const ADest: TRectF; ATint: TAlphaColor);
begin
  FSvgBrush.Source := TSkSvgSource(ASvg);
  FSvgBrush.OverrideColor := ATint;
  // SkiaDraw loescht die Bitmap transparent (AStartClean) und rendert dann.
  ADst.SkiaDraw(
    procedure (const ACanvas: ISkCanvas)
    begin
      FSvgBrush.Render(ACanvas, ADest, 1);
    end);
end;

// Baut die Schablonen-Leiste fuer eine Art neu auf: ein Feld je Vorlage.
procedure TEditorFrame.RebuildStencilBar(AKind: TAquariumKind);
var
  i    : Integer;
  LSw  : TRectangle;
  LImg : TImage;
begin
  // alte dynamische Felder entfernen
  for i := 0 to FStencilSwatches.Count - 1 do
    FStencilSwatches[i].Free();
  FStencilSwatches.Clear();
  FSelStencil := nil;

  for i := 0 to FStencils.Count - 1 do
  begin
    if FStencils[i].Kind <> AKind then
      Continue;

    LSw := TRectangle.Create(Self);
    LSw.Parent := StencilBar;
    LSw.Width := 44;
    LSw.Height := 44;
    LSw.Margins.Rect := RectF(3, 3, 3, 3);
    LSw.Fill.Color := TAlphaColorRec.White;
    LSw.Stroke.Color := SWATCH_STROKE_DEF;
    LSw.Stroke.Thickness := SWATCH_THICK_DEF;
    LSw.XRadius := 6;
    LSw.YRadius := 6;
    LSw.Cursor := crHandPoint;
    LSw.Hint := FStencils[i].Name;
    LSw.ShowHint := True;
    LSw.Tag := i;                       // Index in FStencils
    LSw.OnClick := StencilSwatchClick;

    LImg := TImage.Create(LSw);
    LImg.Parent := LSw;
    LImg.Align := TAlignLayout.Client;
    LImg.Margins.Rect := RectF(4, 4, 4, 4);
    LImg.HitTest := False;
    LImg.WrapMode := TImageWrapMode.Fit;
    LImg.Bitmap.SetSize(64, 64);
    RenderStencil(FStencils[i].Svg, LImg.Bitmap, RectF(4, 4, 60, 60),
      STENCIL_COLORS[AKind]);

    FStencilSwatches.Add(LSw);
  end;

  // "Freihand"-Schaltflaeche stets ans Ende der Leiste schieben.
  FreehandBtn.Parent := nil;
  FreehandBtn.Parent := StencilBar;
end;

// Rendert die Silhouette gross (CANVAS_PX) und leitet daraus die Deckungsmaske
// sowie das Kontur-Overlay ab.
procedure TEditorFrame.BuildStencilMask(const ASvg: String);
const
  MARGIN = 0.08;   // Rand, damit die Form nicht am Canvas-Rand klebt
var
  bmp   : TBitmap;
  LData : TBitmapData;
  GData : TBitmapData;
  W, H, x, y, idx : Integer;
begin
  W := CANVAS_PX;
  H := CANVAS_PX;
  SetLength(FStencilMask, W * H);

  // 1) Silhouette weiss rendern -> Alpha = Deckung der Form.
  bmp := TBitmap.Create(W, H);
  try
    RenderStencil(ASvg, bmp,
      RectF(W * MARGIN, H * MARGIN, W * (1 - MARGIN), H * (1 - MARGIN)),
      TAlphaColorRec.White);

    if bmp.Map(TMapAccess.Read, LData) then
    try
      for idx := 0 to W * H - 1 do
        FStencilMask[idx] :=
          TAlphaColorRec(LData.GetPixel(idx mod W, idx div W)).A / 255;
    finally
      bmp.Unmap(LData);
    end;
  finally
    bmp.Free();
  end;

  // 2) Kontur-Overlay aus der Maske ableiten: Innenpixel mit Aussennachbar
  //    markieren (3 px dick). Wird angezeigt, aber nicht mitgespeichert.
  FStencilGuide.Bitmap.SetSize(W, H);
  FStencilGuide.Bitmap.Clear(TAlphaColorRec.Null);
  if FStencilGuide.Bitmap.Map(TMapAccess.ReadWrite, GData) then
  try
    for y := 1 to H - 2 do
      for x := 1 to W - 2 do
      begin
        idx := y * W + x;
        if FStencilMask[idx] < 0.5 then
          Continue;
        if (FStencilMask[idx - 1] < 0.5) or (FStencilMask[idx + 1] < 0.5)
        or (FStencilMask[idx - W] < 0.5) or (FStencilMask[idx + W] < 0.5) then
        begin
          GData.SetPixel(x,     y,     STENCIL_GUIDE_INK);
          GData.SetPixel(x - 1, y,     STENCIL_GUIDE_INK);
          GData.SetPixel(x + 1, y,     STENCIL_GUIDE_INK);
          GData.SetPixel(x,     y - 1, STENCIL_GUIDE_INK);
          GData.SetPixel(x,     y + 1, STENCIL_GUIDE_INK);
        end;
      end;
  finally
    FStencilGuide.Bitmap.Unmap(GData);
  end;
end;

procedure TEditorFrame.ActivateStencil(AIndex: Integer; ASwatch: TRectangle);
begin
  if (AIndex < 0) or (AIndex >= FStencils.Count) then
    Exit;

  // Maske + Kontur aus der SVG-Vorlage erzeugen und Schablone scharf schalten.
  BuildStencilMask(FStencils[AIndex].Svg);
  FStencilActive := True;
  FStencilGuide.Visible := True;
  FStencilGuide.BringToFront();

  // Auswahlrahmen umsetzen
  if Assigned(FSelStencil) then
  begin
    FSelStencil.Stroke.Color := SWATCH_STROKE_DEF;
    FSelStencil.Stroke.Thickness := SWATCH_THICK_DEF;
  end;
  FSelStencil := ASwatch;
  if Assigned(ASwatch) then
  begin
    ASwatch.Stroke.Color := SWATCH_STROKE_SEL;
    ASwatch.Stroke.Thickness := SWATCH_THICK_SEL;
  end;

  // Art synchronisieren - ohne die Leiste neu aufzubauen (gleiche Art).
  FUpdatingKind := True;
  try
    KindCombo.ItemIndex := Ord(FStencils[AIndex].Kind);
  finally
    FUpdatingKind := False;
  end;

  FEraser := False;
  EraserBtn.Text := 'Radierer';
end;

// Wechsel der Art: aktive Schablone loesen und die Leiste neu aufbauen.
procedure TEditorFrame.KindComboChange(Sender: TObject);
begin
  if FUpdatingKind then
    Exit;
  DeactivateStencil();
  RebuildStencilBar(TAquariumKind(Max(0, KindCombo.ItemIndex)));
end;

procedure TEditorFrame.DeactivateStencil();
begin
  FStencilActive := False;
  if Assigned(FStencilGuide) then
    FStencilGuide.Visible := False;
  if Assigned(FSelStencil) then
  begin
    FSelStencil.Stroke.Color := SWATCH_STROKE_DEF;
    FSelStencil.Stroke.Thickness := SWATCH_THICK_DEF;
    FSelStencil := nil;
  end;
end;

// Begrenzt einen gerade gezogenen Strich auf die Schablonenform: ausserhalb
// liegende Pixel werden entfernt, am weichen Rand wird die Deckung gekappt.
// Das Kappen per Min ist idempotent -> keine schrittweise Randabdunklung.
procedure TEditorFrame.ApplyStencilClip(const A, B: TPointF);
var
  LData : TBitmapData;
  W, H, x0, y0, x1, y1, xx, yy, idx, ma, exp : Integer;
  m  : Single;
  px : TAlphaColorRec;
begin
  if not FStencilActive then
    Exit;

  W := CanvasImage.Bitmap.Width;
  H := CanvasImage.Bitmap.Height;
  if Length(FStencilMask) <> W * H then
    Exit;

  exp := Ceil(BrushSize.Value) + 2;
  x0 := Max(0,     Floor(Min(A.X, B.X)) - exp);
  y0 := Max(0,     Floor(Min(A.Y, B.Y)) - exp);
  x1 := Min(W - 1, Ceil (Max(A.X, B.X)) + exp);
  y1 := Min(H - 1, Ceil (Max(A.Y, B.Y)) + exp);
  if (x1 < x0) or (y1 < y0) then
    Exit;

  if not CanvasImage.Bitmap.Map(TMapAccess.ReadWrite, LData) then
    Exit;
  try
    for yy := y0 to y1 do
      for xx := x0 to x1 do
      begin
        idx := yy * W + xx;
        m := FStencilMask[idx];
        if m >= 0.999 then
          Continue;                         // voll innerhalb -> unveraendert
        px := TAlphaColorRec(LData.GetPixel(xx, yy));
        if px.A = 0 then
          Continue;
        ma := Round(m * 255);
        if px.A > ma then
        begin
          if ma = 0 then
            LData.SetPixel(xx, yy, TAlphaColorRec.Null)
          else
          begin
            px.A := ma;
            LData.SetPixel(xx, yy, px.Color);
          end;
        end;
      end;
  finally
    CanvasImage.Bitmap.Unmap(LData);
  end;
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

// Abstand eines Punktes zur Strecke A..B (fuer die weiche Pinselkante).
function DistPointToSegment(const P, A, B: TPointF): Single;
var vx, vy, wx, wy, c1, c2, t : Single;
begin
  vx := B.X - A.X; vy := B.Y - A.Y;
  wx := P.X - A.X; wy := P.Y - A.Y;
  c1 := vx * wx + vy * wy;
  if c1 <= 0 then
    Exit(Sqrt(wx * wx + wy * wy));
  c2 := vx * vx + vy * vy;
  if c2 <= c1 then
    Exit(Sqrt(Sqr(P.X - B.X) + Sqr(P.Y - B.Y)));
  t := c1 / c2;
  Result := Sqrt(Sqr(P.X - (A.X + t * vx)) + Sqr(P.Y - (A.Y + t * vy)));
end;

// "Over"-Komposition: Quelle (mit Deckung ACov) auf den Basispixel legen und
// das Ergebnis in den Zielpuffer schreiben (gerade Alpha-Werte, kein Aufbau).
procedure CompositeOver(var ADst, ABase: TBitmapData; X, Y: Integer;
  const ASrc: TAlphaColorRec; ACov: Single);
var
  base, outc : TAlphaColorRec;
  sa, da, oa : Single;
begin
  sa := (ASrc.A / 255) * ACov;
  base := TAlphaColorRec(ABase.GetPixel(X, Y));
  da := base.A / 255;
  oa := sa + da * (1 - sa);
  if oa <= 0.0001 then
  begin
    ADst.SetPixel(X, Y, TAlphaColorRec.Null);
    Exit;
  end;
  outc.A := Round(oa * 255);
  outc.R := Round((ASrc.R * sa + base.R * da * (1 - sa)) / oa);
  outc.G := Round((ASrc.G * sa + base.G * da * (1 - sa)) / oa);
  outc.B := Round((ASrc.B * sa + base.B * da * (1 - sa)) / oa);
  ADst.SetPixel(X, Y, outc.Color);
end;

procedure TEditorFrame.StrokeTo(const APt: TPointF);
begin
  // Pinselart: 1 = weich, 2 = laenglich, 3 = extra weich, sonst (0) = rund.
  case FBrushType of
    1: StrokeSoft(FLastPt, APt);
    2: StrokeElongated(FLastPt, APt);
    3: StrokeExtraSoft(FLastPt, APt);
  else
    StrokeRound(FLastPt, APt);
  end;
end;

procedure TEditorFrame.StrokeRound(const A, B: TPointF);
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
    CanvasImage.Bitmap.Canvas.DrawLine(A, B, 1);
    // Punkt am Ende sichern (sonst fehlen Einzelklicks / Kurvenenden)
    CanvasImage.Bitmap.Canvas.Fill.Kind := TBrushKind.Solid;
    CanvasImage.Bitmap.Canvas.Fill.Color := FCurrentColor;
    CanvasImage.Bitmap.Canvas.FillEllipse(
      RectF(B.X - r, B.Y - r, B.X + r, B.Y + r), 1);
  finally
    CanvasImage.Bitmap.Canvas.EndScene();
  end;
  ApplyStencilClip(A, B);
  CanvasImage.Repaint();
end;

procedure TEditorFrame.BeginSoftStroke();
var n : Integer;
begin
  // Basis-Schnappschuss + Deckungspuffer fuer einen aufbaufreien weichen Strich.
  if not Assigned(FStrokeBase) then
    FStrokeBase := TBitmap.Create();
  FStrokeBase.Assign(CanvasImage.Bitmap);

  n := CanvasImage.Bitmap.Width * CanvasImage.Bitmap.Height;
  if Length(FStrokeCov) <> n then
    SetLength(FStrokeCov, n);
  if n > 0 then
    FillChar(FStrokeCov[0], n * SizeOf(Single), 0);

  FStrokeActive := True;
end;

procedure TEditorFrame.StrokeSoft(const A, B: TPointF);
begin
  // Voller Kern, volle Spitzendeckung.
  SoftStrokeCore(A, B, SOFT_SCALE, SOFT_CORE, 1.0);
end;

procedure TEditorFrame.StrokeExtraSoft(const A, B: TPointF);
begin
  // Kein Kern, reduzierte Spitzendeckung -> deutlich weicher/hauchiger.
  SoftStrokeCore(A, B, XSOFT_SCALE, 0.0, XSOFT_PEAK);
end;

procedure TEditorFrame.SoftStrokeCore(const A, B: TPointF;
  AScale, ACoreFrac, APeak: Single);
var
  LDst, LBase    : TBitmapData;
  r, core, d, f, cov : Single;
  W, H, x0, y0, x1, y1, xx, yy, idx : Integer;
  src : TAlphaColorRec;
begin
  if not FStrokeActive then
    BeginSoftStroke();

  r := BrushSize.Value / 2 * AScale;        // bei Benutzung groesser
  if r < 1 then r := 1;
  core := r * ACoreFrac;                     // voll deckender Kern (0 = keiner)
  W := CanvasImage.Bitmap.Width;
  H := CanvasImage.Bitmap.Height;

  // Nur die betroffene Umgebung der Strecke bearbeiten.
  x0 := Max(0,     Floor(Min(A.X, B.X) - r));
  y0 := Max(0,     Floor(Min(A.Y, B.Y) - r));
  x1 := Min(W - 1, Ceil (Max(A.X, B.X) + r));
  y1 := Min(H - 1, Ceil (Max(A.Y, B.Y) + r));
  if (x1 < x0) or (y1 < y0) then
    Exit;

  if not FStrokeBase.Map(TMapAccess.Read, LBase) then
    Exit;
  try
    if not CanvasImage.Bitmap.Map(TMapAccess.ReadWrite, LDst) then
      Exit;
    try
      src := TAlphaColorRec(FCurrentColor);
      for yy := y0 to y1 do
        for xx := x0 to x1 do
        begin
          d := DistPointToSegment(PointF(xx + 0.5, yy + 0.5), A, B);
          if d >= r then
            Continue;
          // Voller Kern in der Mitte, dann weiche Smoothstep-Kante nach aussen.
          if d <= core then
            cov := APeak
          else
          begin
            f := (r - d) / (r - core);          // 1 am Kernrand -> 0 am Aussenrand
            cov := f * f * (3 - 2 * f) * APeak; // smoothstep, auf Spitzendeckung skaliert
          end;
          idx := yy * W + xx;
          // Hoechste bisher erreichte Deckung halten -> kein Aufbau im Strich.
          if cov > FStrokeCov[idx] then
          begin
            FStrokeCov[idx] := cov;
            CompositeOver(LDst, LBase, xx, yy, src, cov);
          end;
        end;
    finally
      CanvasImage.Bitmap.Unmap(LDst);
    end;
  finally
    FStrokeBase.Unmap(LBase);
  end;
  ApplyStencilClip(A, B);
  CanvasImage.Repaint();
end;

procedure TEditorFrame.StrokeElongated(const A, B: TPointF);
const
  NIB_ANGLE = 45 * Pi / 180;   // feste Neigung -> kalligrafischer Strichcharakter
var
  hl, hw, len, step, t, cx, cy : Single;
  steps, i : Integer;
  m : TMatrix;
begin
  hl := Max(1.0, BrushSize.Value / 2);       // halbe Laenge (lange Achse)
  hw := Max(0.6, BrushSize.Value * 0.16);    // halbe Breite (schmale Achse)

  if CanvasImage.Bitmap.Canvas.BeginScene() then
  try
    CanvasImage.Bitmap.Canvas.Fill.Kind := TBrushKind.Solid;
    CanvasImage.Bitmap.Canvas.Fill.Color := FCurrentColor;

    len := A.Distance(B);
    step := Max(0.5, hw * 0.5);
    steps := Max(1, Ceil(len / step));
    for i := 0 to steps do
    begin
      t  := i / steps;
      cx := A.X + (B.X - A.X) * t;
      cy := A.Y + (B.Y - A.Y) * t;
      // erst um die Nib-Achse drehen, dann an die Stempelposition schieben
      m := TMatrix.CreateRotation(NIB_ANGLE) * TMatrix.CreateTranslation(cx, cy);
      CanvasImage.Bitmap.Canvas.SetMatrix(m);
      CanvasImage.Bitmap.Canvas.FillEllipse(RectF(-hl, -hw, hl, hw), 1);
    end;

    CanvasImage.Bitmap.Canvas.SetMatrix(TMatrix.Identity);
  finally
    CanvasImage.Bitmap.Canvas.EndScene();
  end;
  ApplyStencilClip(A, B);
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

  // Schutz fuer den Fall, dass ein MouseUp verloren ging (z.B. ausserhalb des
  // Controls losgelassen): ohne gedrueckte linke Taste keinen Strich fortsetzen.
  if not (ssLeft in Shift) then
  begin
    FDrawing := False;
    FStrokeActive := False;
    Exit;
  end;

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
  FStrokeActive := False;   // weichen Strich abschliessen -> naechster startet neu
end;

{ ----------------------------------------------------------------------------
  Werkzeug-Aktionen
  ---------------------------------------------------------------------------- }

procedure TEditorFrame.ColorSwatchClick(Sender: TObject);
begin
  SelectColorSwatch(Sender as TRectangle);
  FEraser := False;
  EraserBtn.Text := 'Radierer';
end;

procedure TEditorFrame.BrushSwatchClick(Sender: TObject);
begin
  SelectBrushSwatch(Sender as TRectangle);
  FEraser := False;
  EraserBtn.Text := 'Radierer';
end;

procedure TEditorFrame.StencilSwatchClick(Sender: TObject);
var LSw : TRectangle;
begin
  LSw := Sender as TRectangle;
  ActivateStencil(Integer(LSw.Tag), LSw);   // Tag = Index in FStencils
end;

procedure TEditorFrame.FreehandClick(Sender: TObject);
begin
  DeactivateStencil();   // zurueck zum freien Zeichnen
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
  FLibrary.AddDrawing(LKind, NameEdit.Text, CanvasImage.Bitmap);

  RefreshElementsList();
  ElementsList.ItemIndex := ElementsList.Count - 1;

  // Fuer die naechste Zeichnung aufraeumen
  ClearCanvas();
  NameEdit.Text := '';
end;

procedure TEditorFrame.PlaceClick(Sender: TObject);
begin
  if (ElementsList.ItemIndex < 0)
  or (ElementsList.ItemIndex >= FLibrary.Count) then
  begin
    ShowMessage('Bitte ein Element aus der Liste waehlen.');
    Exit;
  end;

  PlaceTemplate(FLibrary.GetTemplate(ElementsList.ItemIndex));
end;

procedure TEditorFrame.PlaceTemplate(ATemplate: TGorillaInventoryItemTemplate);
begin
  if not Assigned(ATemplate) then
    Exit;

  if Assigned(FHost) then
    FHost.Visible := False;
  FPlacement.Start(ATemplate);
end;

{ ----------------------------------------------------------------------------
  Bibliotheksaktionen
  ---------------------------------------------------------------------------- }

procedure TEditorFrame.EditClick(Sender: TObject);
var
  LTpl : TGorillaInventoryItemTemplate;
  LBmp : TBitmap;
begin
  if (ElementsList.ItemIndex < 0)
  or (ElementsList.ItemIndex >= FLibrary.Count) then
  begin
    ShowMessage('Bitte ein Element zum Bearbeiten waehlen.');
    Exit;
  end;

  // Gewaehlte Vorlage in den Editor laden
  DeactivateStencil();   // geladene Zeichnung frei bearbeitbar machen
  LTpl := FLibrary.GetTemplate(ElementsList.ItemIndex);
  KindCombo.ItemIndex := Ord(AquariumTemplateKind(LTpl));
  NameEdit.Text := AquariumTemplateName(LTpl);
  if (CanvasImage.Bitmap.Width <> CANVAS_PX) then
    CanvasImage.Bitmap.SetSize(CANVAS_PX, CANVAS_PX);
  LBmp := AquariumTemplateBitmap(LTpl);
  if Assigned(LBmp) then
    CanvasImage.Bitmap.Assign(LBmp);
  CanvasImage.Repaint();
end;

procedure TEditorFrame.UpdateClick(Sender: TObject);
var
  LIdx  : Integer;
  LTpl  : TGorillaInventoryItemTemplate;
  LKind : TAquariumKind;
begin
  LIdx := ElementsList.ItemIndex;
  if (LIdx < 0) or (LIdx >= FLibrary.Count) then
  begin
    ShowMessage('Bitte ein Element zum Aktualisieren waehlen.');
    Exit;
  end;

  LTpl := FLibrary.GetTemplate(LIdx);
  if KindCombo.ItemIndex < 0 then
    LKind := AquariumTemplateKind(LTpl)
  else
    LKind := TAquariumKind(KindCombo.ItemIndex);

  FLibrary.UpdateDrawing(LTpl, LKind, NameEdit.Text, CanvasImage.Bitmap);
  RefreshElementsList();
  ElementsList.ItemIndex := LIdx;
end;

procedure TEditorFrame.DeleteClick(Sender: TObject);
var LIdx : Integer;
begin
  LIdx := ElementsList.ItemIndex;
  if (LIdx < 0) or (LIdx >= FLibrary.Count) then
  begin
    ShowMessage('Bitte ein Element zum Loeschen waehlen.');
    Exit;
  end;

  FLibrary.DeleteDrawing(FLibrary.GetTemplate(LIdx));
  RefreshElementsList();
end;

procedure TEditorFrame.CloseEditorClick(Sender: TObject);
begin
  if Assigned(FHost) then
    FHost.Visible := False;
end;

end.
