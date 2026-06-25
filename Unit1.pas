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
  Gorilla.Material.NormalMap, Gorilla.Bokeh;

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
    Rectangle1: TRectangle;
    PopupArea: TRectangle;
    Label1: TLabel;
    Ground: TGorillaTerrain;
    GorillaPBRMaterialSource1: TGorillaPBRMaterialSource;
    GorillaRenderPassUnderwater1: TGorillaRenderPassUnderwater;
    Timer1: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure Rectangle1Click(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
  private
    { Private-Deklarationen }
    FScene        : TAquariumScene;     // animierte 3D-Szene
    FEditor       : TEditorFrame;       // Zeicheneditor (eigener Frame)
    FAnimTimer    : TTimer;
    FClock        : TStopwatch;

    procedure AnimTimerTick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  public
    { Public-Deklarationen }
  end;

var
  Form1: TForm1;

implementation

{$R *.fmx}

uses
  Gorilla.Context.ShadowSettings;

procedure TForm1.FormCreate(Sender: TObject);
begin
  GorillaViewport1.GetDesignCameraController().SetPositionAndAngle(Point3D(0, 5.5, -5), TPoint3D.Zero);

  Rock.IsStatic := true;

  Octopus.Visible := false;
  Octopus.SetHitTestValue(false);
  Octopus.AnimationManager.Current.Start;

  Self.OnDestroy := FormDestroy;

  FScene := TAquariumScene.Create(GorillaViewport1, Self);

  // Zeicheneditor als Frame in die Popup-Flaeche einhaengen und mit der
  // 3D-Szene verknuepfen. Das Layout wird zur Entwurfszeit im Frame gepflegt.
  FEditor := TEditorFrame.Create(Self);
  FEditor.Parent := PopupArea;
  FEditor.Align := TAlignLayout.Client;
  FEditor.Init(FScene, GorillaViewport1, Rock, PopupArea);
  FEditor.Place3DObject(Ground);
  FEditor.Place3DObject(Rock);

  // Animationsschleife (~60 fps): verformt platzierte Elemente und zeichnet neu
  FClock := TStopwatch.StartNew;
  FAnimTimer := TTimer.Create(Self);
  FAnimTimer.Interval := 16;
  FAnimTimer.OnTimer := AnimTimerTick;
  FAnimTimer.Enabled := True;

  // NOTICE: Activate Shadow Mapping (Runtime)
  (*
  // Light-Sources able to cast shadows
  GorillaLight1.LightType := TLightType.Point;
  GorillaLight1.CastShadow := true;
  GorillaLight1.ShadowStrength := 0.75;

  // Elements that should receive shadows:
  Rock.Shadows := true;
  Octopus.Shadows := true;
  Ground.Shadows := true;

  // Elements that should not cast any shadows:
  Ground.CastShadows := False;
  WaterSurface.CastShadows := False;
  GorillaHemisphere1.CastShadows := False;

  // General CSM shadow activation:
  GorillaViewport1.Shadows.Enabled := true;
  GorillaViewport1.Shadows.Filter := TGorillaShadowFilter.PCF5;
  GorillaViewport1.Shadows.MaxDirLights := 0;
  GorillaViewport1.Shadows.MaxSpotLights := 0;
  GorillaViewport1.Shadows.MaxPointLights := 1;
  GorillaViewport1.Shadows.AutoFitCascades := true; // default==true
  *)
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  // Erst den Editor (gibt Bibliothek frei, beendet einen evtl. laufenden
  // Platzierungsmodus), danach die Szene - in dieser Reihenfolge lebt die
  // Szene noch, falls der Editor sie beim Aufraeumen anspricht.
  FEditor.Free();
  FScene.Free();
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

procedure TForm1.Timer1Timer(Sender: TObject);
begin
  Self.Caption := Format('Gorilla3D - SketchQuarium (%n FPS', [GorillaViewport1.FPS]);
end;

end.
