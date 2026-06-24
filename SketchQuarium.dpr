program SketchQuarium;

uses
  System.StartUpCopy,
  FMX.Forms,
  Unit1 in 'Unit1.pas' {Form1},
  Aquarium.Elements in 'Aquarium.Elements.pas',
  Aquarium.EditorFrame in 'Aquarium.EditorFrame.pas' {EditorFrame: TFrame};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
