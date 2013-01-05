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

{ Utilities for dealing with fractals. }
unit FractalsUnit;

interface

uses UComplex, CastleImages;

const
  MinColorExponent = 1;

var
  { How colors will be determined.
    Color:=(1-Iter/MaxIter)^ColorExponent.
    E.g. ColorExponent = 1 means that color is linearly computed based
    on (1-Iter/MaxIter).

    Always must be >= MinColorExponent. }
  ColorExponent: Cardinal = 1;

type
  TPixelDrawFunction = procedure(X, Y: Integer; const Color: Single; Data: Pointer);
  TComplexIterationFunction = function(const Z, C: Complex): Complex;

{ Returns Z*Z + C. }
function MandelbrotIteration(const Z, C: Complex): Complex;

var
  { Configure ZIntPowerIteration job. Must be >= 2. }
  ZIntPower: Integer = 3;

{ Generalized MandelbrotIteration, returns Z^ZIntPower + C }
function ZIntPowerIteration(const Z, C: Complex): Complex;

{ Returns sin(Z) + e^Z + C }
function BiomorphIteration(const Z, C: Complex): Complex;

{ Draws fractal.

  Iteration pattern is given as Iteration function where Z = value
  obtained from previous step and C = position of current pixel we're drawing.

  For each (x, y) in (XMin-XMax) x (YMin-YMax) calls OnPixelDraw(x, y, Color,
    OnPixelDrawData) where Color is in [0.0; 1.0] range.
  XMin, YMin is treated as CMin, XMax, YMax is treates as CMax. }
procedure DrawFractal(Iteration: TComplexIterationFunction;
  const CMin, CMax: Complex; XMin, XMax, YMin, YMax: Integer;
  OnPixelDraw: TPixelDrawFunction; OnPixelDrawData: Pointer);

{ DrawFractal with OpenGL.

  Points are drawn using

@longCode(#
  glColor3f(Color, Color, Color)
  glVertex2i(x, y)
#)

  So e.g. you can translate them using modelview matrix
  but when using scale you must be careful (because if you scale them
  too large, you will see holes between adjacent points).
  Whole call is enclosed in glBegin(GL_POINTS) ... glEnd. }
procedure DrawFractal_GL(Iteration: TComplexIterationFunction;
  const CMin, CMax: Complex;
  XMin, XMax, YMin, YMax: Integer);

{ DrawFractal on TImage. For now, Image class must be TRGBImage.
  Every pixel on image is drawn. }
procedure DrawFractal_Image(Iteration: TComplexIterationFunction;
  const CMin, CMax: Complex; Image: TImage);

{ DrawFractal simultaneously in OpenGL and Image.
  So this is like

@longCode(#
  DrawFractal_Image(CMin, CMax, Image);
  DrawFractal_GL(CMin, CMax, 0, Image.Width-1, 0, Image.Height-1)
#)

  but both draws are done simultaneously (i.e. only ONE call
  to base DrawFractal function is made). }
procedure DrawFractal_ImageAndGL(Iteration: TComplexIterationFunction;
  const CMin, CMax: Complex; Image: TImage);

function MakeComplex(ARe, AIm: Real): Complex;

{ Absolute value of z squared }
function CSqrAbs(const C: Complex): Real;

implementation

uses CastleVectors, GL, Math, CastleUtils;

{ Iterations ------------------------------------------------------------ }

function MandelbrotIteration(const Z, C: Complex): Complex;
begin
  Result := Z * Z + C;
end;

function ZIntPowerIteration(const Z, C: Complex): Complex;
var
  I: Integer;
begin
  Result := Z;
  { TODO: of course, optimize below to log(ZIntPower) }
  for i := 0 to ZIntPower-2 do Result *= Z;
  Result += C;
end;

function BiomorphIteration(const Z, C: Complex): Complex;
begin
  Result := csin(Z) + cexp(Z) + C;
end;

{ DrawFractal ------------------------------------------------------------ }

procedure DrawFractal(Iteration: TComplexIterationFunction;
  const CMin, CMax: Complex; XMin, XMax, YMin, YMax: Integer;
  OnPixelDraw: TPixelDrawFunction; OnPixelDrawData: Pointer);
const
  { if after MaxIter iterations z will still be <= MaxZ,
    then we will assume that this iteration is bounded,
    i.e. z stays in some bounded range (does not go into infinity) }
  MaxIter = 100;
  MaxZ = 1e3;

  SqrMaxZ = MaxZ * MaxZ;
var
  X, Y, Iter: Integer;
  C, Z: Complex;
  DoBreak: boolean;
begin
  for X := XMin to XMax do
    for Y := YMin to YMax do
    begin
      C.Re := MapRange(X, XMin, XMax, CMin.Re, CMax.Re);
      C.Im := MapRange(Y, YMin, YMax, CMin.Im, CMax.Im);

      { start iteration }
      Z := UComplex._0;

      { It's better to use "while" than "for" here to be sure what's the value
        of Iter after the loop. }
      Iter := 0;
      while Iter < MaxIter do
      begin
        try
          { next iteration step }
          Z := Iteration(Z, C);
          DoBreak := CSqrAbs(Z) > SqrMaxZ;

          { Force raising pending exceptions after Iteration(Z, C)
            and CSqrAbs(Z) }
          ClearExceptions(true);

          if DoBreak then Break;
        except
          { Any problems with calculating Iteration(Z, C) or CSqrAbs(Z) ?
            Then assume that it means that Iteration(Z, C) == infinity
            and Break. }
          Break;
        end;

        Inc(Iter);
      end;

   {   Write('For ', X, ',', Y, ' we get Iter = ', Iter);
      Write(' so color is ', (1 - Iter/MaxIter):1:10);
      Write(' so color^exp is ', IntPower(1 - Iter/MaxIter, ColorExponent):1:10);
      Writeln; }

      { now Iter/MaxIter says "how fast Z approached infinity ?".
        Small Iter/MaxIter means that Z appraches infinity fast.
        Large Iter/MaxIter means that Z approaches infinity slow,
        Iter/MaxIter = 1 (so Iter = MaxItem) means that
        never CSqrAbs(Z) > SqrMaxZ, so we decide that Z stays bounded
        (does not approach infinity) }
      OnPixelDraw(X, Y, IntPower(1 - Iter/MaxIter, ColorExponent), OnPixelDrawData);
    end;
end;

{ DrawFractal_GL --------------------------------------------------- }

procedure GL_PixelDraw(X, Y: Integer; const Color: Single; Data: Pointer);
begin
  glColor3f(Color, Color, Color);
  glVertex2i(X, Y);
end;

procedure DrawFractal_GL(Iteration: TComplexIterationFunction;
  const CMin, CMax: Complex; XMin, XMax, YMin, YMax: Integer);
begin
  glBegin(GL_POINTS);
  DrawFractal(Iteration, CMin, CMax, XMin, XMax, YMin, YMax, @GL_PixelDraw, nil);
  glEnd;
end;

{ DrawFractal_Image --------------------------------------------------- }

procedure Image_PixelDraw(X, Y: Integer; const Color: Single; Data: Pointer);
var
  p: PVector3Byte;
begin
  p := PVector3Byte(TCastleImage(Data).PixelPtr(X, Y));
  p^[0] := Clamped(Round(Color*High(Byte)), Low(Byte), High(Byte));
  p^[1] := p^[0];
  p^[2] := p^[0];
end;

procedure DrawFractal_Image(Iteration: TComplexIterationFunction;
  const CMin, CMax: Complex; Image: TImage);
begin
  DrawFractal(Iteration, CMin, CMax, 0, Image.Width-1, 0, Image.Height-1,
    @Image_PixelDraw, Image);
end;

{ DrawFractal_ImageAndGL --------------------------------------------------- }

procedure ImageAndGL_PixelDraw(X, Y: Integer; const Color: Single; Data: Pointer);
begin
  Image_PixelDraw(X, Y, Color, Data);
  GL_PixelDraw(X, Y, Color, Data);
end;

procedure DrawFractal_ImageAndGL(Iteration: TComplexIterationFunction;
  const CMin, CMax: Complex; Image: TImage);
begin
  glBegin(GL_POINTS);
  DrawFractal(Iteration, CMin, CMax, 0, Image.Width-1, 0, Image.Height-1,
    @ImageAndGL_PixelDraw, Image);
  glEnd;
end;

function MakeComplex(ARe, AIm: Real): Complex;
begin
  Result.Re := ARe;
  Result.Im := AIm;
end;

function CSqrAbs(const C: Complex): Real;
begin
  Result := C.Re*C.Re + C.Im*C.Im;
end;

end.
