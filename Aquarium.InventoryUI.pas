unit Aquarium.InventoryUI;

{
  SketchQuarium - Inventar-Katalog (verfuegbare Vorlagen)

  Diese Unit stellt einen kleinen Inventar-Frame fuer das Hauptfenster bereit,
  der die im Inventar gespeicherten Vorlagen (TGorillaInventoryItemTemplate) als
  anklickbare Kacheln anzeigt. Ein Klick waehlt eine Vorlage zum Platzieren aus.

  Der Frame ist eine Subklasse von TInventoryFrame (Gorilla.UI.Inventory) und
  iteriert - anders als die mitgelieferte Simple-UI, die CollectedItems zeigt -
  ueber die ItemTemplates des Inventars. Die Kachel-Icons werden direkt aus der
  am Template gehaltenen Zeichnung (Data: TBitmap) gerendert, daher wird die
  Image-List des Inventars hier nicht benoetigt.
}

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes,
  System.Generics.Collections,
  FMX.Types, FMX.Controls, FMX.Graphics, FMX.Objects, FMX.Layouts, FMX.StdCtrls,
  Gorilla.Utils.Inventory, Gorilla.UI.Inventory,
  Aquarium.Elements;

type
  TAquariumPickTemplateEvent = procedure(Sender: TObject;
    ATemplate: TGorillaInventoryItemTemplate) of object;

  /// <summary>
  ///  Inventar-Frame, der die verfuegbaren Vorlagen als Kacheln auflistet.
  ///  Auswahl einer Kachel loest OnPickTemplate aus.
  /// </summary>
  TAquariumTemplateFrame = class(TInventoryFrame)
  private
    FInv    : TGorillaInventory;
    FFlow   : TFlowLayout;
    FCards  : TList<TRectangle>;
    FOnPick : TAquariumPickTemplateEvent;
    procedure CardClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;

    /// <summary>Verknuepft den Katalog mit einem Inventar und baut ihn auf.</summary>
    procedure ShowInventory(AInventory: TGorillaInventory);
    /// <summary>Baut die Kacheln aus den aktuellen Vorlagen neu auf.</summary>
    procedure RebuildCatalog();

    /// <summary>Wird ausgeloest, wenn eine Vorlagen-Kachel angeklickt wird.</summary>
    property OnPickTemplate : TAquariumPickTemplateEvent
      read FOnPick write FOnPick;
  end;

implementation

const
  CARD_SIZE   = 96.0;   // Kantenlaenge einer Vorlagen-Kachel
  CARD_GAP    = 12.0;   // Abstand zwischen den Kacheln
  LABEL_H     = 22.0;   // Hoehe der Namenszeile am unteren Rand

{ TAquariumTemplateFrame }

constructor TAquariumTemplateFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FCards := TList<TRectangle>.Create();

  // Die Kacheln liegen in einem FlowLayout, das die volle Frameflaeche fuellt
  // und automatisch umbricht.
  FFlow := TFlowLayout.Create(Self);
  FFlow.Parent := Self;
  FFlow.Align  := TAlignLayout.Client;
  FFlow.FlowDirection := TFlowDirection.LeftToRight;
  FFlow.Justify := TFlowJustify.Left;
  FFlow.JustifyLastLine := TFlowJustify.Left;
  FFlow.HorizontalGap := CARD_GAP;
  FFlow.VerticalGap   := CARD_GAP;
  FFlow.Margins.Rect  := RectF(CARD_GAP, CARD_GAP, CARD_GAP, CARD_GAP);
  FFlow.Stored := False;
end;

destructor TAquariumTemplateFrame.Destroy();
begin
  FCards.Free();
  inherited;
end;

procedure TAquariumTemplateFrame.ShowInventory(AInventory: TGorillaInventory);
begin
  FInv := AInventory;
  RebuildCatalog();
end;

procedure TAquariumTemplateFrame.RebuildCatalog();
var
  i    : Integer;
  LTpl : TGorillaInventoryItemTemplate;
  LBmp : TBitmap;
  LCard : TRectangle;
  LImg  : TImage;
  LLbl  : TLabel;
begin
  // alte Kacheln entfernen
  for i := 0 to FCards.Count - 1 do
    FCards[i].Free();
  FCards.Clear();

  if not Assigned(FInv) then
    Exit;

  for i := 0 to FInv.ItemTemplates.Count - 1 do
  begin
    LTpl := FInv.ItemTemplates.Items[i] as TGorillaInventoryItemTemplate;

    LCard := TRectangle.Create(Self);
    LCard.Parent := FFlow;
    LCard.Width  := CARD_SIZE;
    LCard.Height := CARD_SIZE;
    LCard.Fill.Color := TAlphaColorRec.White;
    LCard.Stroke.Color := $33555555;
    LCard.XRadius := 6;
    LCard.YRadius := 6;
    LCard.Cursor := crHandPoint;
    LCard.Hint := AquariumTemplateName(LTpl);
    LCard.ShowHint := True;
    LCard.TagObject := LTpl;          // Vorlage an der Kachel merken
    LCard.OnClick := CardClick;

    LImg := TImage.Create(LCard);
    LImg.Parent := LCard;
    LImg.Align  := TAlignLayout.Client;
    LImg.Margins.Rect := RectF(4, 4, 4, 4 + LABEL_H);
    LImg.WrapMode := TImageWrapMode.Fit;
    LImg.HitTest := False;            // Klick faellt auf die Kachel zurueck
    LBmp := AquariumTemplateBitmap(LTpl);
    if Assigned(LBmp) then
      LImg.Bitmap.Assign(LBmp);

    LLbl := TLabel.Create(LCard);
    LLbl.Parent := LCard;
    LLbl.Align  := TAlignLayout.Bottom;
    LLbl.Height := LABEL_H;
    LLbl.HitTest := False;
    LLbl.StyledSettings := LLbl.StyledSettings - [TStyledSetting.Size];
    LLbl.TextSettings.Font.Size := 12;
    LLbl.TextSettings.HorzAlign := TTextAlign.Center;
    LLbl.Text := AquariumTemplateName(LTpl);

    FCards.Add(LCard);
  end;
end;

procedure TAquariumTemplateFrame.CardClick(Sender: TObject);
var LTpl : TGorillaInventoryItemTemplate;
begin
  if not (Sender is TRectangle) then
    Exit;
  if not (TRectangle(Sender).TagObject is TGorillaInventoryItemTemplate) then
    Exit;

  LTpl := TGorillaInventoryItemTemplate(TRectangle(Sender).TagObject);
  if Assigned(FOnPick) then
    FOnPick(Self, LTpl);
end;

end.
