unit KambiComplexUtils;

interface

uses UComplex;

function MakeComplex(ARe, AIm: Real): Complex;

{ Absolute value of z squared }
function CSqrAbs(const C: Complex): Real;

implementation

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