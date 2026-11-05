unit Aquarium.Theme;

{
  SketchQuarium - Dunkles "Tiefsee"-Farbschema fuer die 2D-Oberflaeche

  Die Farben entsprechen denen der Praesentation (Folie 8, "Die 2D-Bedien-
  oberflaeche"): dunkles Petrol als Grund, halbtransparente Karten mit feiner,
  hellblauer Kante und Tuerkis/Bernstein als Akzent.

  Das statische Aussehen (Panels, Knoepfe, Beschriftungen) ist zur
  Entwurfszeit im .fmx gesetzt. Diese Unit liefert nur, was sich im
  Designer nicht klicken laesst:
    - Hover-/Druck-Effekt fuer die TRectangle-Knoepfe
    - Umschalt-Zustaende (aktiver Radierer, gewaehlte Art)
    - das Umfaerben der Standard-Controls TEdit, TTrackBar und TListBox:
      deren Windows-Stil zeichnet Bitmaps; diese werden ausgeblendet und
      durch eigene, einfache Formen in den Theme-Farben ersetzt.
}

interface

uses
  System.Types, System.UITypes, System.Classes,
  FMX.Types, FMX.Controls, FMX.Graphics, FMX.Objects, FMX.StdCtrls,
  FMX.Edit, FMX.ListBox;

const
  // Grundfarben (wie --bg0/--bg1/--code-bg der Praesentation)
  AQ_BG0     = TAlphaColor($FF04141F);
  AQ_BG1     = TAlphaColor($FF0A2A3D);
  AQ_PANEL   = TAlphaColor($E6061722);
  AQ_FIELD   = TAlphaColor($FF0B2433);   // Eingabefelder / Felder-Hintergrund

  // Schrift
  AQ_INK     = TAlphaColor($FFEAF4F8);
  AQ_MUTED   = TAlphaColor($FF9FC0CD);
  AQ_FAINT   = TAlphaColor($FF6F92A0);

  // Akzente
  AQ_TEAL    = TAlphaColor($FF35D6C8);
  AQ_AMBER   = TAlphaColor($FFFFC14D);
  AQ_CORAL   = TAlphaColor($FFFF7A59);

  // Kanten
  AQ_LINE    = TAlphaColor($2E78C8E6);   // rgba(120,200,230,0.18)
  AQ_LINE_HI = TAlphaColor($5578C8E6);   // etwas deutlicher (Felder, Hover)

  // Knopf-Flaechen (wie die Werkzeugknoepfe auf Folie 8)
  AQ_BTN_NEUTRAL = TAlphaColor($2978A0C8);
  AQ_BTN_TEAL    = TAlphaColor($2E35D6C8);
  AQ_BTN_AMBER   = TAlphaColor($2EFFC14D);
  AQ_BTN_CORAL   = TAlphaColor($26FF7A59);

type
  TAquaSkinMode = (asmEdit, asmTrack, asmList);

  TAquaTheme = class
  private
    class procedure HoverEnter(Sender: TObject);
    class procedure HoverLeave(Sender: TObject);
    class procedure PressDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    class procedure PressUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    class procedure NativePainting(Sender: TObject; Canvas: TCanvas;
      const ARect: TRectF);
    class procedure StripStyle(AObj: TFmxObject; AMode: TAquaSkinMode);
    class function  HasDecor(AObj: TFmxObject): Boolean;
    class function  AddDecor(AParent: TFmxObject; AFill: TAlphaColor;
      ARadius: Single): TRectangle;
  public
    /// <summary>Haengt den Hover-/Druck-Effekt an einen TRectangle-Knopf.</summary>
    class procedure AttachHover(ABtn: TRectangle);

    /// <summary>Faerbt einen Umschalt-Knopf (z.B. Radierer) als aktiv/inaktiv.</summary>
    class procedure SetToggle(ABtn: TRectangle; AActive: Boolean;
      AActiveFill, AActiveStroke: TAlphaColor);

    /// <summary>Waehl-Chip (z.B. Art): gewaehlt = Tuerkis, sonst neutral.</summary>
    class procedure SetChip(AChip: TRectangle; ASelected: Boolean);

    /// <summary>Dunkles Eingabefeld statt des hellen Windows-Stils.</summary>
    class procedure SkinEdit(AEdit: TEdit);

    /// <summary>Schmale Spur mit tuerkisem Fortschritt und rundem Regler.</summary>
    class procedure SkinTrackBar(ATrack: TTrackBar);

    /// <summary>Transparente Liste mit dezenter Scrollleiste.</summary>
    class procedure SkinListBox(AList: TListBox);
  end;

implementation

uses
  System.SysUtils, FMX.Styles.Objects;

const
  DECOR_TAG     = 'aqua-decor';   // markiert eigene Ersatzformen
  HOVER_FILL    = TAlphaColor($14FFFFFF);
  PRESS_FILL    = TAlphaColor($26FFFFFF);

{ ---------------------------------------------------------------------------
  Knoepfe
  --------------------------------------------------------------------------- }

class procedure TAquaTheme.AttachHover(ABtn: TRectangle);
var LOverlay : TRectangle;
begin
  // Ueberlagerung liegt unter der Beschriftung und wird nur beim Hover sichtbar.
  LOverlay := TRectangle.Create(ABtn);
  LOverlay.Parent := ABtn;
  LOverlay.Align := TAlignLayout.Contents;
  LOverlay.HitTest := False;
  LOverlay.Stroke.Kind := TBrushKind.None;
  LOverlay.Fill.Color := HOVER_FILL;
  LOverlay.XRadius := ABtn.XRadius;
  LOverlay.YRadius := ABtn.YRadius;
  LOverlay.Visible := False;
  LOverlay.SendToBack();

  ABtn.TagObject := LOverlay;
  ABtn.Cursor := crHandPoint;
  ABtn.OnMouseEnter := HoverEnter;
  ABtn.OnMouseLeave := HoverLeave;
  ABtn.OnMouseDown  := PressDown;
  ABtn.OnMouseUp    := PressUp;
end;

class procedure TAquaTheme.HoverEnter(Sender: TObject);
var LCtrl : TControl;
begin
  LCtrl := Sender as TControl;
  if LCtrl.TagObject is TRectangle then
  begin
    TRectangle(LCtrl.TagObject).Fill.Color := HOVER_FILL;
    TRectangle(LCtrl.TagObject).Visible := True;
  end;
end;

class procedure TAquaTheme.HoverLeave(Sender: TObject);
var LCtrl : TControl;
begin
  LCtrl := Sender as TControl;
  if LCtrl.TagObject is TRectangle then
    TRectangle(LCtrl.TagObject).Visible := False;
end;

class procedure TAquaTheme.PressDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
var LCtrl : TControl;
begin
  LCtrl := Sender as TControl;
  if LCtrl.TagObject is TRectangle then
  begin
    TRectangle(LCtrl.TagObject).Fill.Color := PRESS_FILL;
    TRectangle(LCtrl.TagObject).Visible := True;
  end;
end;

class procedure TAquaTheme.PressUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
var LCtrl : TControl;
begin
  LCtrl := Sender as TControl;
  if LCtrl.TagObject is TRectangle then
  begin
    TRectangle(LCtrl.TagObject).Fill.Color := HOVER_FILL;
    TRectangle(LCtrl.TagObject).Visible := LCtrl.IsMouseOver;
  end;
end;

class procedure TAquaTheme.SetToggle(ABtn: TRectangle; AActive: Boolean;
  AActiveFill, AActiveStroke: TAlphaColor);
begin
  if AActive then
  begin
    ABtn.Fill.Color := AActiveFill;
    ABtn.Stroke.Color := AActiveStroke;
  end
  else
  begin
    ABtn.Fill.Color := AQ_BTN_NEUTRAL;
    ABtn.Stroke.Color := AQ_LINE;
  end;
end;

class procedure TAquaTheme.SetChip(AChip: TRectangle; ASelected: Boolean);
var
  i : Integer;
begin
  if ASelected then
  begin
    AChip.Fill.Color := AQ_BTN_TEAL;
    AChip.Stroke.Color := AQ_TEAL;
  end
  else
  begin
    AChip.Fill.Color := AQ_BTN_NEUTRAL;
    AChip.Stroke.Color := AQ_LINE;
  end;

  for i := 0 to AChip.ChildrenCount - 1 do
    if AChip.Children[i] is TLabel then
    begin
      if ASelected then
        TLabel(AChip.Children[i]).TextSettings.FontColor := AQ_INK
      else
        TLabel(AChip.Children[i]).TextSettings.FontColor := AQ_MUTED;
    end;
end;

{ ---------------------------------------------------------------------------
  Standard-Controls umfaerben
  ---------------------------------------------------------------------------
  Der Windows-Stil zeichnet Hintergruende, Spuren und Regler als Bitmap-
  Ausschnitte (TCustomStyleObject). Setzt man deren Source auf nil, zeichnen
  sie nichts mehr - ihre Kinder (Text, Inhalt) bleiben aber erhalten. An
  ihre Stelle treten einfache TRectangle/TCircle in den Theme-Farben.

  Weil FMX Stile jederzeit neu laden kann (z.B. beim ersten Anzeigen),
  passiert das im OnPainting des Controls: vor jedem Zeichnen werden neu
  entstandene Stil-Bitmaps entfernt. Bereits bearbeitete Teile werden
  erkannt und uebersprungen, der Aufwand ist daher gering.
  --------------------------------------------------------------------------- }

class function TAquaTheme.HasDecor(AObj: TFmxObject): Boolean;
var i : Integer;
begin
  for i := 0 to AObj.ChildrenCount - 1 do
    if AObj.Children[i].TagString = DECOR_TAG then
      Exit(True);
  Result := False;
end;

class function TAquaTheme.AddDecor(AParent: TFmxObject; AFill: TAlphaColor;
  ARadius: Single): TRectangle;
begin
  Result := TRectangle.Create(AParent);
  Result.TagString := DECOR_TAG;
  Result.Parent := AParent;
  Result.Align := TAlignLayout.Contents;
  Result.HitTest := False;
  Result.Stored := False;
  Result.Fill.Color := AFill;
  Result.Stroke.Kind := TBrushKind.None;
  Result.XRadius := ARadius;
  Result.YRadius := ARadius;
  Result.SendToBack();
end;

class procedure TAquaTheme.StripStyle(AObj: TFmxObject; AMode: TAquaSkinMode);
var
  i      : Integer;
  LChild : TFmxObject;
  LThumb : TCircle;
  LField : TRectangle;
begin
  for i := 0 to AObj.ChildrenCount - 1 do
  begin
    LChild := AObj.Children[i];
    if LChild.TagString = DECOR_TAG then
      Continue;

    if LChild is TCustomStyleObject then
    begin
      if TCustomStyleObject(LChild).Source <> nil then
      begin
        TCustomStyleObject(LChild).Source := nil;

        // Eingabefeld: dunkle Flaeche innerhalb des Stils, also unter dem
        // Text. (Kinder, die man direkt in ein TEdit legt, landen in dessen
        // Presentation und wuerden ueber dem Text gezeichnet.)
        if (AMode = asmEdit) and SameText(LChild.StyleName, 'background') then
        begin
          LField := AddDecor(LChild, AQ_FIELD, 8);
          LField.Stroke.Kind := TBrushKind.Solid;
          LField.Stroke.Color := AQ_LINE_HI;
        end
        // Spur und Fortschritt einer TrackBar bekommen eigene Formen
        else if SameText(LChild.StyleName, 'htrack') or SameText(LChild.StyleName, 'vtrack') then
          AddDecor(LChild, AQ_LINE_HI, 2)
        else if SameText(LChild.StyleName, 'highlight') then
          AddDecor(LChild, AQ_TEAL, 2);
      end;
    end
    else if LChild is TBrushObject then
    begin
      // Textfarbe / Markierung der Eingabefelder
      if SameText(LChild.StyleName, 'foreground') then
        TBrushObject(LChild).Brush.Color := AQ_INK
      else if SameText(LChild.StyleName, 'selection') then
        TBrushObject(LChild).Brush.Color := TAlphaColor($6635D6C8);
    end
    else if LChild is TColorObject then
    begin
      if SameText(LChild.StyleName, 'caretcolor') then
        TColorObject(LChild).Color := AQ_TEAL;
    end;

    // Regler: rund (TrackBar) bzw. schmaler Balken (Scrollleiste)
    if (LChild is TThumb) and not HasDecor(LChild) then
    begin
      if AMode = asmTrack then
      begin
        LThumb := TCircle.Create(LChild);
        LThumb.TagString := DECOR_TAG;
        LThumb.Parent := LChild;
        LThumb.Align := TAlignLayout.Center;
        LThumb.Width := 16;
        LThumb.Height := 16;
        LThumb.HitTest := False;
        LThumb.Stored := False;
        LThumb.Fill.Color := AQ_TEAL;
        LThumb.Stroke.Color := AQ_BG0;
        LThumb.Stroke.Thickness := 3;
      end
      else
        AddDecor(LChild, AQ_LINE_HI, 3).Margins.Rect := RectF(2, 2, 2, 2);
    end;

    // TrackBar-Spuren/-Regler und eigene Inhalte (z.B. Listeneintraege)
    // werden ebenfalls durchsucht - eigene Ersatzformen nicht.
    StripStyle(LChild, AMode);
  end;
end;

class procedure TAquaTheme.NativePainting(Sender: TObject; Canvas: TCanvas;
  const ARect: TRectF);
begin
  if Sender is TEdit then
    StripStyle(TFmxObject(Sender), asmEdit)
  else if Sender is TTrackBar then
    StripStyle(TFmxObject(Sender), asmTrack)
  else
    StripStyle(TFmxObject(Sender), asmList);
end;

class procedure TAquaTheme.SkinEdit(AEdit: TEdit);
begin
  AEdit.StyledSettings := AEdit.StyledSettings
    - [TStyledSetting.FontColor, TStyledSetting.Size];
  AEdit.TextSettings.FontColor := AQ_INK;
  AEdit.TextSettings.Font.Size := 14;

  AEdit.OnPainting := NativePainting;
end;

class procedure TAquaTheme.SkinTrackBar(ATrack: TTrackBar);
begin
  ATrack.OnPainting := NativePainting;
end;

class procedure TAquaTheme.SkinListBox(AList: TListBox);
begin
  AList.OnPainting := NativePainting;
end;

end.
