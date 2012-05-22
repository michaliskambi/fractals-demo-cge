{ docs:
  What is ColorExponent ? See FractalsUnit.ColorExponent comment.
  Mouse left click : zoom in (new view is ZoomFactor smaller),
        right click : zoom out (new view is ZoomFactor larger),
        middle click : shift (new view has the same size),
        always mouse click position sets new view middle

  TODO:
    window with info about
      ColorExponent,
      FractalCMin,
      FractalCMax
      ZoomFactor,
      Iteration
    better names for "z int power"
}


uses SysUtils, KambiUtils, GL, GLU, GLExt, GLWindow, GLWinInputs,
  UComplex, Math,
  GLWinMessages, Images, FractalsUnit, KambiComplexUtils, KambiGLUtils,
  KambiStringUtils, GLImages;

var
  { Can be modified only from Draw() (and when finalizing). }
  FractalImage: TRGBImage;
  dlFractalImage: TGLuint = 0;

  { After changing, remember to call PostRedrawFractal }
  FractalCMin: Complex = (Re:-3.0; Im: -2.0);
  FractalCMax: Complex = (Re: 3.0; Im:  2.0);

  ZoomFactor: Float = 2.0;

  Iteration: TComplexIterationFunction = @MandelbrotIteration;
  
  Window: TGLWindowDemo;

var
  { read/write only from PostRedrawFractal and Draw }
  RedrawFractalPosted: boolean = true;

{ This forces update of FractalImage and dlFractalImage in nearest
  Window.EventDraw and does Window.PostRedisplay; }
procedure PostRedrawFractal;
begin
 RedrawFractalPosted := true;
 Window.PostRedisplay;
end;

procedure Draw(Window: TGLWindow);
begin
 glRasterPos2i(0, 0);

 if RedrawFractalPosted then
 begin
  FreeAndNil(FractalImage);
  glFreeDisplayList(dlFractalImage);

  glClear(GL_COLOR_BUFFER_BIT);

  { now regenerate FractalImage and dlFractalImage }
  FractalImage := TRGBImage.Create(Window.Width, Window.Height);
  DrawFractal_ImageAndGL(Iteration, FractalCMin, FractalCMax, FractalImage);
  dlFractalImage := ImageDrawToDisplayList(FractalImage);

  RedrawFractalPosted := false;
 end else
 begin
  glCallList(dlFractalImage);
 end;
end;

procedure Resize(Window: TGLWindow);
begin
 Resize2D(Window);
 PostRedrawFractal;
end;

procedure CloseGL(Window: TGLWindow);
begin
 glFreeDisplayList(dlFractalImage);
end;

procedure MouseDown(Window: TGLWindow; btn: TMouseButton);
var Middle, NewSize: Complex;
begin
 if btn in [mbLeft, mbMiddle, mbRight] then
 begin
  Middle := MakeComplex(
    MapRange(Window.MouseX, 0, Window.Width,
      FractalCMin.Re, FractalCMax.Re),
    MapRange(Window.Height - Window.MouseY, 0, Window.Height,
      FractalCMin.Im, FractalCMax.Im));

  NewSize := FractalCMax - FractalCMin;

  case btn of
   mbLeft: NewSize /= ZoomFactor;
   mbRight: NewSize *= ZoomFactor;
  end;

  {
  FractalCMin := Middle - NewSize/2;
  FractalCMax := Middle + NewSize/2;
  }
  { to avoid FPC 1.0.10 problems }
  FractalCMin.Re := Middle.Re - NewSize.Re/2;
  FractalCMin.Im := Middle.Im - NewSize.Im/2;
  FractalCMax.Re := Middle.Re + NewSize.Re/2;
  FractalCMax.Im := Middle.Im + NewSize.Im/2;

  PostRedrawFractal;
 end;
end;

{ menu ------------------------------------------------------------ }

procedure MenuCommand(Window: TGLWindow; MenuItem: TMenuItem);

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

var Card: Cardinal;
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
  else raise EInternalError.Create('not impl menu item');
 end;

 Window.PostRedisplay;
end;

function GetMainMenu: TMenu;
var M: TMenu;
begin
 Result := TMenu.Create('Main menu');
 M := TMenu.Create('File');
   M.Append(TMenuItem.Create('Save picture to file',   41, CtrlS));
   M.Append(TMenuItem.Create('Exit',                   51, CharEscape));
   Result.Append(M);
 M := TMenu.Create('View');
   M.Append(TMenuItem.Create('Redraw fractal',         90, CtrlR));
   M.Append(TMenuSeparator.Create);
   M.Append(TMenuItem.Create('Set color exponent ...', 100));
   M.Append(TMenuItem.Create('Color exponent x 2',     110, 'c'));
   M.Append(TMenuItem.Create('Color exponent / 2',     120, 'C'));
   M.Append(TMenuSeparator.Create);
   M.Append(TMenuItem.Create('Set zoom factor ...',    130));
   M.Append(TMenuItem.Create('Zoom factor x 2',        140, 'z'));
   M.Append(TMenuItem.Create('Zoom factor / 2',        150, 'Z'));
   M.Append(TMenuSeparator.Create);
   M.Append(TMenuItem.Create('Set iteration to Mandelbrot',     160));
   M.Append(TMenuItem.Create('Set iteration to "z int power"',  165));
   M.Append(TMenuItem.Create('Set iteration to "biomorph"',     170));
   M.Append(TMenuSeparator.Create);
   M.Append(TMenuItem.Create('Set iteration "z int power"',     180));
   Result.Append(M);
end;

{ main ------------------------------------------------------------ }

begin
 Window := TGLWindowDemo.Create(Application);
 try
  Window.ParseParameters;

  Window.MainMenu := GetMainMenu;
  Window.OnMenuCommand := @MenuCommand;

  Window.DoubleBuffer := false;
  Window.OnResize := @Resize;
  Window.OnDraw := @Draw;
  Window.OnClose := @CloseGL;
  Window.OnMouseDown := @MouseDown;
  Window.OpenAndRun;
 finally
  FreeAndNil(FractalImage);
 end;
end.