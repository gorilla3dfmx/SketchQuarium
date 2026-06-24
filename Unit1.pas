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
  Gorilla.DefTypes, Aquarium.Elements, Aquarium.EditorFrame;

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
    Ground: TGorillaCube;
    GorillaPBRMaterialSource1: TGorillaPBRMaterialSource;
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
    procedure FormCreate(Sender: TObject);
    procedure Rectangle1Click(Sender: TObject);
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

procedure TForm1.FormCreate(Sender: TObject);
begin
  Octopus.AnimationManager.Current.Start;
  (Rock.Def as TModelDef).AcquireBVH();

  Self.OnDestroy := FormDestroy;

  FScene := TAquariumScene.Create(GorillaViewport1, Self);

  // Zeicheneditor als Frame in die Popup-Flaeche einhaengen und mit der
  // 3D-Szene verknuepfen. Das Layout wird zur Entwurfszeit im Frame gepflegt.
  FEditor := TEditorFrame.Create(Self);
  FEditor.Parent := PopupArea;
  FEditor.Align := TAlignLayout.Client;
  FEditor.Init(FScene, GorillaViewport1, Rock, PopupArea);

  // Animationsschleife (~60 fps): verformt platzierte Elemente und zeichnet neu
  FClock := TStopwatch.StartNew;
  FAnimTimer := TTimer.Create(Self);
  FAnimTimer.Interval := 16;
  FAnimTimer.OnTimer := AnimTimerTick;
  FAnimTimer.Enabled := True;
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

end.
