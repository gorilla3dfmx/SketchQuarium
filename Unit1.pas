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
  Gorilla.DefTypes, Aquarium.Elements, Aquarium.EditorFrame, Gorilla.Terrain,
  Gorilla.Material.NormalMap, Gorilla.Bokeh, Gorilla.Physics,
  Gorilla.Utils.Inventory, Aquarium.InventoryUI, Gorilla.Audio.Manager,
  Gorilla.Audio.FMOD, Gorilla.Audio.Playlist, Gorilla.Particle.Influencer,
  Gorilla.Particle.Emitter, Gorilla.Material.Particle;

type
  TForm1 = class(TForm)
    GorillaViewport1: TGorillaViewport;
    GorillaLight1: TGorillaLight;
    AquariumWalls: TGorillaGroup;
    LeftWall: TGorillaCube;
    RightWall: TGorillaCube;
    BackWall: TGorillaCube;
    AquariumWallMaterial: TGorillaBlinnMaterialSource;
    BottomWall: TGorillaCube;
    GorillaWaterMaterialSource1: TGorillaWaterMaterialSource;
    GorillaRenderPassRefraction1: TGorillaRenderPassRefraction;
    GorillaRenderPassReflection1: TGorillaRenderPassReflection;
    WaterSurface: TGorillaPlane;
    GorillaAssetsManager1: TGorillaAssetsManager;
    Rock: TGorillaModel;
    GorillaMaterialCausticsBehaviour1: TGorillaMaterialCausticsBehaviour;
    Octopus: TGorillaModel;
    GorillaHemisphere1: TGorillaHemisphere;
    GorillaLambertMaterialSource1: TGorillaLambertMaterialSource;
    ToolsArea: TRectangle;
    DrawButton: TRectangle;
    PopupArea: TRectangle;
    Label1: TLabel;
    Ground: TGorillaTerrain;
    GorillaPBRMaterialSource1: TGorillaPBRMaterialSource;
    GorillaRenderPassUnderwater1: TGorillaRenderPassUnderwater;
    Timer1: TTimer;
    FeedButton: TRectangle;
    Label2: TLabel;
    GorillaPhysicsSystem1: TGorillaPhysicsSystem;
    InventoryButton: TRectangle;
    Label3: TLabel;
    InventoryArea: TRectangle;
    SaveButton: TRectangle;
    Label4: TLabel;
    LoadButton: TRectangle;
    Label5: TLabel;
    GorillaFMODAudioManager1: TGorillaFMODAudioManager;
    GorillaAudioPlaylist1: TGorillaAudioPlaylist;
    BubbleEmitter: TGorillaParticleEmitter;
    GorillaParticleMaterialSource1: TGorillaParticleMaterialSource;
    procedure FormCreate(Sender: TObject);
    procedure DrawButtonClick(Sender: TObject);
    procedure FeedButtonClick(Sender: TObject);
    procedure InventoryButtonClick(Sender: TObject);
    procedure SaveButtonClick(Sender: TObject);
    procedure LoadButtonClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
  private
    { Private-Deklarationen }
    FScene        : TAquariumScene;     // animierte 3D-Szene
    FLibrary      : TAquariumLibrary;   // geteiltes Inventar (Vorlagen/Instanzen)
    FEditor       : TEditorFrame;       // Zeicheneditor (eigener Frame)
    FCatalog      : TAquariumTemplateFrame;  // Inventar-Katalog im Hauptfenster
    FAnimTimer    : TTimer;
    FClock        : TStopwatch;

    FFeeding        : Boolean;          // Modus aktiv: Klick wirft Futter
    FStoredFeedDown : TMouseEvent;      // gesicherter Viewport-Handler

    procedure SetFeeding(AValue: Boolean);
    function  SurfacePoint(const APt: TPointF; out APos: TPoint3D): Boolean;
    procedure FeedMouseDown(Sender: TObject; Button: TMouseButton;
                Shift: TShiftState; X, Y: Single);

    procedure AnimTimerTick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure DoOnSpawnedElementEvent(ASender : TObject; ATemplate : TGorillaInventoryItemTemplate;
      AElement : TSpawnedElement);
    procedure DoOnSpawnedFoodPelletEvent(ASender : TObject; APellet : TFoodPellet);

    /// <summary>Vorlagen-Auswahl aus dem Inventar-Katalog -> Platzierungsmodus.</summary>
    procedure CatalogPick(Sender: TObject; ATemplate: TGorillaInventoryItemTemplate);
  public
    { Public-Deklarationen }
  end;

var
  Form1: TForm1;

implementation

{$R *.fmx}

uses
  Gorilla.GLB.Loader,
  Gorilla.USD.Loader,
  Gorilla.Context.ShadowSettings;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Self.ClientWidth := 1920;
  Self.ClientHeight := 1080;

  GorillaViewport1.GetDesignCameraController().SetPositionAndAngle(Point3D(0, 5.5, -5), TPoint3D.Zero);
  GorillaViewport1.GetDesignCameraController().Interval := 10;

  Rock.IsStatic := true;

  //Octopus.Visible := false;
  Octopus.SetHitTestValue(false);
  Octopus.AnimationManager.Current.Start;

  Self.OnDestroy := FormDestroy;

  FScene := TAquariumScene.Create(GorillaViewport1, GorillaPhysicsSystem1, Self);
  FScene.OnSpawnedElement := DoOnSpawnedElementEvent;
  FScene.OnSpawnedFoodPellet := DoOnSpawnedFoodPelletEvent;

  // Geteiltes Inventar: haelt alle gezeichneten Vorlagen (Templates) sowie die
  // platzierten Instanzen (Collectables). Wird von Editor und Katalog genutzt.
  FLibrary := TAquariumLibrary.Create();
  FLibrary.LoadFromDisk();

  // Zeicheneditor als Frame in die Popup-Flaeche einhaengen und mit der
  // 3D-Szene + dem Inventar verknuepfen. Das Layout wird zur Entwurfszeit
  // im Frame gepflegt.
  FEditor := TEditorFrame.Create(Self);
  FEditor.Parent := PopupArea;
  FEditor.Align := TAlignLayout.Client;
  FEditor.Init(FScene, FLibrary, GorillaViewport1, Rock, PopupArea);
  FEditor.Place3DObject(Ground);
  FEditor.Place3DObject(Rock.Meshes[0]);

  // Inventar-Katalog (verfuegbare Vorlagen) in die eigene Popup-Flaeche.
  FCatalog := TAquariumTemplateFrame.Create(Self);
  FCatalog.Parent := InventoryArea;
  FCatalog.Align := TAlignLayout.Client;
  FCatalog.OnPickTemplate := CatalogPick;
  FCatalog.ShowInventory(FLibrary.Inventory);

  // Animationsschleife (~60 fps): verformt platzierte Elemente und zeichnet neu
  FClock := TStopwatch.StartNew;
  FAnimTimer := TTimer.Create(Self);
  FAnimTimer.Interval := 16;
  FAnimTimer.OnTimer := AnimTimerTick;
  FAnimTimer.Enabled := True;
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  // Enable physics collision detection
  GorillaPhysicsSystem1.Active := true;

  // Start playing music
  GorillaAudioPlaylist1.Play();

  // Run the bubble emitting
  BubbleEmitter.Camera := GorillaViewport1.GetDesignCamera();
  BubbleEmitter.Start();
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  GorillaPhysicsSystem1.Active := false;

  // Erst den Editor (gibt Bibliothek frei, beendet einen evtl. laufenden
  // Platzierungsmodus), danach die Szene - in dieser Reihenfolge lebt die
  // Szene noch, falls der Editor sie beim Aufraeumen anspricht.
  FEditor.Free();
  FScene.Free();
  // Inventar zuletzt freigeben: die Szene wirft beim Aufraeumen noch
  // Collectables ab und braucht das Inventar dafuer.
  FLibrary.Free();
end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
  Self.Caption := Format('Gorilla3D - SketchQuarium (%n FPS', [GorillaViewport1.FPS]);
end;

procedure TForm1.DoOnSpawnedElementEvent(ASender : TObject; ATemplate : TGorillaInventoryItemTemplate;
  AElement : TSpawnedElement);
begin
  // Play sound effect depending on the type of element
  case AElement.Kind of
    TAquariumKind.akFish,
    TAquariumKind.akJellyfish :
      GorillaFMODAudioManager1.PlaySound(1, GorillaFMODAudioManager1.ChannelGroupRefs['Effects']);

    else
      GorillaFMODAudioManager1.PlaySound(2, GorillaFMODAudioManager1.ChannelGroupRefs['Effects']);
  end;
end;

procedure TForm1.DoOnSpawnedFoodPelletEvent(ASender : TObject; APellet : TFoodPellet);
begin
  // Play sound effect
  GorillaFMODAudioManager1.PlaySound(0, GorillaFMODAudioManager1.ChannelGroupRefs['Effects']);
end;

procedure TForm1.SetFeeding(AValue: Boolean);
begin
  if FFeeding = AValue then
    Exit;

  FFeeding := AValue;

  if FFeeding then
  begin
    FStoredFeedDown := GorillaViewport1.OnMouseDown;
    GorillaViewport1.OnMouseDown := FeedMouseDown;
    FeedButton.Fill.Color := TAlphaColor($FF2EA82E);   // gruen = aktiv
  end
  else
  begin
    if (@FStoredFeedDown <> nil) then
      GorillaViewport1.OnMouseDown := FStoredFeedDown;

    FeedButton.Fill.Color := TAlphaColors.Cornflowerblue;
  end;
end;

function TForm1.SurfacePoint(const APt: TPointF; out APos: TPoint3D): Boolean;
var
  LCam : TCamera;
  LVec : TVector3D;
  LOrigin, LDir, LFar : TPoint3D;
  t : Single;
begin
  Result := False;
  APos := TPoint3D.Zero;

  if GorillaViewport1.UsingDesignCamera then
    LCam := GorillaViewport1.GetDesignCamera()
  else
    LCam := GorillaViewport1.Camera;
  if not Assigned(LCam) then
    Exit;

  LVec := LCam.AbsolutePosition;
  LOrigin := Point3D(LVec.X, LVec.Y, LVec.Z);
  LFar := GorillaViewport1.ScreenToWorld(APt);
  LDir := (LFar - LOrigin).Normalize();

  // Strahl mit der Wasseroberflaeche (Y=0) schneiden.
  if Abs(LDir.Y) < 0.00001 then
    Exit;
  t := (0.0 - LOrigin.Y) / LDir.Y;
  if t <= 0 then
    Exit;

  APos := LOrigin + LDir * t;
  APos.X := Max(-9.0, Min(9.0, APos.X));
  APos.Z := Max(-3.0, Min(8.0, APos.Z));
  APos.Y := -0.5;
  Result := True;

  Self.GorillaWaterMaterialSource1.AddRipple(APos);
end;

procedure TForm1.FeedMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
var LPos : TPoint3D;
begin
  case Button of
    TMouseButton.mbLeft :
      begin
        if SurfacePoint(PointF(X, Y), LPos) then
        begin
          FScene.DropFood(LPos);
        end;
      end;

    TMouseButton.mbRight :
      begin
        if FFeeding then
          SetFeeding(false);
      end;
  end;
end;

procedure TForm1.AnimTimerTick(Sender: TObject);
begin
  FScene.Animate(FClock.Elapsed.TotalSeconds);

  // NOTICE: Viewport invalidation is only needed if UseFixedFrameRate rendering is deactivated.
//  GorillaViewport1.Invalidate();
end;

procedure TForm1.DrawButtonClick(Sender: TObject);
begin
  SetFeeding(false);
  InventoryArea.Visible := False;
  PopUpArea.Visible := not PopUpArea.Visible;
end;

procedure TForm1.FeedButtonClick(Sender: TObject);
begin
  SetFeeding(not FFeeding);
end;

procedure TForm1.InventoryButtonClick(Sender: TObject);
begin
  SetFeeding(false);
  PopUpArea.Visible := False;
  InventoryArea.Visible := not InventoryArea.Visible;
  if InventoryArea.Visible then
    FCatalog.RebuildCatalog();   // aktuellen Vorlagen-Bestand zeigen
end;

procedure TForm1.CatalogPick(Sender: TObject;
  ATemplate: TGorillaInventoryItemTemplate);
begin
  InventoryArea.Visible := False;
  FEditor.PlaceTemplate(ATemplate);
end;

procedure TForm1.SaveButtonClick(Sender: TObject);
var LDlg : TSaveDialog;
begin
  SetFeeding(false);

  LDlg := TSaveDialog.Create(Self);
  try
    LDlg.Filter := 'SketchQuarium-Setup (*.xml)|*.xml';
    LDlg.DefaultExt := 'xml';
    LDlg.Options := LDlg.Options + [TOpenOption.ofOverwritePrompt];
    if not LDlg.Execute() then
      Exit;

    // Position/Groesse aller platzierten Instanzen in deren Collectables sichern,
    // dann das komplette Aquarium (Vorlagen + Instanzen) schreiben.
    FScene.SyncCollectables();
    FLibrary.SaveSetupToFile(LDlg.FileName);
  finally
    LDlg.Free();
  end;
end;

procedure TForm1.LoadButtonClick(Sender: TObject);
var LDlg : TOpenDialog;
begin
  SetFeeding(false);
  PopUpArea.Visible := False;
  InventoryArea.Visible := False;

  LDlg := TOpenDialog.Create(Self);
  try
    LDlg.Filter := 'SketchQuarium-Setup (*.xml)|*.xml';
    LDlg.Options := LDlg.Options + [TOpenOption.ofFileMustExist];
    if not LDlg.Execute() then
      Exit;

    FScene.ClearScene();                              // aktuelles Becken leeren
    FLibrary.LoadSetupFromFile(LDlg.FileName);         // Vorlagen + Instanzen laden
    FScene.RestoreFromInventory(FLibrary.Inventory);   // Szene neu aufbauen
    FCatalog.RebuildCatalog();                         // Katalog aktualisieren
    FEditor.RefreshLibrary();                          // Editor-Liste aktualisieren
  finally
    LDlg.Free();
  end;
end;

end.
