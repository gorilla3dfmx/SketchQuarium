program SketchQuarium;

uses
  System.StartUpCopy,
  Gorilla.Context.Backend,
  FMX.Skia,
  FMX.Forms,
  Unit1 in 'Unit1.pas' {Form1},
  Aquarium.Elements in 'Aquarium.Elements.pas',
  Aquarium.EditorFrame in 'Aquarium.EditorFrame.pas' {EditorFrame: TFrame};

{$R *.res}

begin
{$IF Defined(MSWINDOWS) AND Defined(CPUX64)}
  Gorilla.Context.Backend.GorillaGraphicsBackend := TGorillaGraphicsBackend.gbVulkan;
{$ENDIF}
{$IF Defined(LINUX) AND Defined(CPUX64)}
  Gorilla.Context.Backend.GorillaGraphicsBackend := TGorillaGraphicsBackend.gbVulkan;
{$ENDIF}

  FMX.Skia.GlobalUseSkia := true;
  FMX.Skia.GlobalUseSkiaRasterWhenAvailable := false;

  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
