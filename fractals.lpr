{
  Copyright 2002-2012 Michalis Kamburelis.

  This file is part of "fractals-demo-cge".

  "fractals-demo-cge" is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  "fractals-demo-cge" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with "fractals-demo-cge"; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

  ----------------------------------------------------------------------------
}

{ Draw fractals on OpenGL context, using Castle Game Engine
  [http://castle-engine.sourceforge.net/] utilities.

  Usage docs:
  Mouse left click : zoom in (new view is ZoomFactor smaller),
        right click : zoom out (new view is ZoomFactor larger),
        middle click : shift (new view has the same size),
        always mouse click position sets new view middle
  For an explanation what is ColorExponent see FractalsUnit.ColorExponent comment.

  TODO:
    window with info about
      ColorExponent,
      FractalCMin,
      FractalCMax
      ZoomFactor,
      Iteration
    better names for "z int power"
}

uses SysUtils, CastleUtils, GL, GLU, GLExt, CastleWindow, CastleInputs,
  UComplex, Math, CastleUIControls, CastleOpenDocument,
  CastleMessages, CastleImages, FractalsUnit, CastleGLUtils,
  CastleStringUtils, CastleGLImages, CastleKeysMouse;

var
  { Can be modified only from Draw() (and when finalizing). }
  FractalImage: TRGBImage;
  GLFractalImage: TGLImage;

  { After changing, remember to call PostRedrawFractal }
  FractalCMin: Complex = (Re:-3.0; Im: -2.0);
  FractalCMax: Complex = (Re: 3.0; Im:  2.0);

  ZoomFactor: Float = 2.0;

  Iteration: TComplexIterationFunction = @MandelbrotIteration;

  Window: TCastleWindowCustom;

var
  { Read/write only from PostRedrawFractal and Draw }
  RedrawFractalPosted: boolean = true;

{ Force update of FractalImage and GLFractalImage in nearest
  Window.EventDraw and does Window.PostRedisplay. }
procedure PostRedrawFractal;
begin
  RedrawFractalPosted := true;
  Window.PostRedisplay;
end;

procedure Draw(Window: TCastleWindowBase);
begin
  glRasterPos2i(0, 0);

  if RedrawFractalPosted then
  begin
    FreeAndNil(FractalImage);
    FreeAndNil(GLFractalImage);

    glClear(GL_COLOR_BUFFER_BIT);

    { now regenerate FractalImage and GLFractalImage }
    FractalImage := TRGBImage.Create(Window.Width, Window.Height);
    DrawFractal_ImageAndGL(Iteration, FractalCMin, FractalCMax, FractalImage);
    GLFractalImage := TGLImage.Create(FractalImage);

    RedrawFractalPosted := false;
  end else
  begin
    GLFractalImage.Draw;
  end;
end;

procedure Resize(Window: TCastleWindowBase);
begin
  Resize2D(Window);
  PostRedrawFractal;
end;

procedure Close(Window: TCastleWindowBase);
begin
  FreeAndNil(GLFractalImage);
end;

procedure Press(Window: TCastleWindowBase; const Event: TInputPressRelease);
var
  Middle, NewSize: Complex;
begin
  if Event.EventType = itMouseButton { any mouse button click } then
  begin
    Middle := MakeComplex(
      MapRange(Window.MouseX, 0, Window.Width,
        FractalCMin.Re, FractalCMax.Re),
      MapRange(Window.Height - Window.MouseY, 0, Window.Height,
        FractalCMin.Im, FractalCMax.Im));

    NewSize := FractalCMax - FractalCMin;

    case Event.MouseButton of
      mbLeft: NewSize /= ZoomFactor;
      mbRight: NewSize *= ZoomFactor;
    end;

    FractalCMin := Middle - NewSize/2;
    FractalCMax := Middle + NewSize/2;

    PostRedrawFractal;
  end;
end;

{ menu ------------------------------------------------------------ }

procedure MenuClick(Window: TCastleWindowBase; MenuItem: TMenuItem);

  procedure SetColorExponent(AValue: Cardinal);
  begin
    ColorExponent := AValue;
    Writeln('ColorExponent is now ', ColorExponent);
    PostRedrawFractal;
  end;

  procedure SetIteration(AValue: TComplexIterationFunction);
  begin
    Iteration := AValue;
    PostRedrawFractal;
  end;

var
  Card: Cardinal;
  FileName: string;
begin
  case MenuItem.IntData of
    41:  begin
          FileName := 'fractal.png';
          if Window.FileDialog('Save fractal image', FileName, false) then
           SaveImage(FractalImage, FileName);
         end;
    51:  Window.Close;
    90:  PostRedrawFractal;
    100: begin
          Card := ColorExponent;
          if MessageInputQueryCardinal(Window, 'New color exponent:', Card,
            taLeft) then
           SetColorExponent(Card);
         end;
    110: SetColorExponent(ColorExponent * 2);
    120: SetColorExponent(ColorExponent div 2);
    130: MessageInputQuery(Window, 'Input zoom factor:', ZoomFactor, taLeft);
    140: ZoomFactor *= 2;
    150: ZoomFactor /= 2;
    160: SetIteration(@MandelbrotIteration);
    165: SetIteration(@ZIntPowerIteration);
    170: SetIteration(@BiomorphIteration);
    180: begin
          Card := ZIntPower;
          if MessageInputQueryCardinal(Window, 'Input Z exponent for "Z int power" iteration:',
            Card, taLeft) then
          begin
           ZIntPower := Card;
           if Iteration = @ZIntPowerIteration then
            PostRedrawFractal;
          end;
         end;
    200: if not OpenURL('https://github.com/michaliskambi/fractals-demo-cge') then
           Window.MessageOk(SCannotOpenURL, mtError);
    210: if not OpenURL('http://castle-engine.sourceforge.net/') then
           Window.MessageOk(SCannotOpenURL, mtError);
    else raise EInternalError.Create('not impl menu item');
  end;

  Window.PostRedisplay;
end;

function GetMainMenu: TMenu;
var
  M: TMenu;
begin
  Result := TMenu.Create('Main menu');
  M := TMenu.Create('_File');
    M.Append(TMenuItem.Create('_Save picture to file',   41, CtrlS));
    M.Append(TMenuItem.Create('_Exit',                   51, CharEscape));
    Result.Append(M);
  M := TMenu.Create('_View');
    M.Append(TMenuItem.Create('_Redraw fractal',         90, CtrlR));
    M.Append(TMenuSeparator.Create);
    M.Append(TMenuItem.Create('Set _color exponent ...', 100));
    M.Append(TMenuItem.Create('Color exponent x 2',     110, 'c'));
    M.Append(TMenuItem.Create('Color exponent / 2',     120, 'C'));
    M.Append(TMenuSeparator.Create);
    M.Append(TMenuItem.Create('Set _zoom factor ...',    130));
    M.Append(TMenuItem.Create('Zoom factor x 2',        140, 'z'));
    M.Append(TMenuItem.Create('Zoom factor / 2',        150, 'Z'));
    M.Append(TMenuSeparator.Create);
    M.Append(TMenuItem.Create('Set iteration to _Mandelbrot',     160));
    M.Append(TMenuItem.Create('Set iteration to "z int power"',  165));
    M.Append(TMenuItem.Create('Set iteration to "_biomorph"',     170));
    M.Append(TMenuSeparator.Create);
    M.Append(TMenuItem.Create('Set iteration "z int power"',     180));
    Result.Append(M);
 M := TMenu.Create('_Help');
   M.Append(TMenuItem.Create('Visit our website (fractals-demo-cge)', 200));
   M.Append(TMenuItem.Create('Visit Castle Game Engine website'     , 210));
   Result.Append(M);
end;

{ main ------------------------------------------------------------ }

begin
  Window := TCastleWindowCustom.Create(Application);

  try
    Window.ParseParameters;

    Window.MainMenu := GetMainMenu;
    { TODO: Replace to OnMenuClick for Castle Game Engine > 4.0.1,
      OnMenuCommand is deprecated. }
    Window.OnMenuCommand := @MenuClick;

    Window.DoubleBuffer := false;
    Window.OnResize := @Resize;
    Window.OnDrawStyle := ds2D;
    Window.OnDraw := @Draw;
    Window.OnClose := @Close;
    Window.OnPress := @Press;
    Window.OpenAndRun;
  finally FreeAndNil(FractalImage) end;
end.
