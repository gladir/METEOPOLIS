{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2022
  @website(https://www.gladir.com/meteopolis)
  @abstract(Target: Turbo Pascal, Free Pascal)
}

Program CONVERS;

Function StrToUpper(S:String):String;
Var
 I:Byte;
Begin
 For I:=1 to Length(S)do Begin
  If S[I] in['a'..'z']Then S[I]:=Chr(Ord(S[I])-32);
 End;
 StrToUpper:=S;
End;

Function FahrToCent(Fahr:Real):Real;Begin
 FahrToCent:=(5.0/9.0)*(Fahr-32.0);
End;

Function CentToFahr(Cent:Real):Real;Begin
 CentToFahr:=1.8*Cent+32.0;
End;

Function CentToKelvin(Cent:Real):Real;Begin
 CentToKelvin:=Cent+273.16;
End;

Function KelvinToCent(Kelvin:Real):Real;Begin
 KelvinToCent:=Kelvin-273.16;
End;

Function KelvinToFahr(Kelvin:Real):Real;Begin
 KelvinToFahr:=1.8*(Kelvin-273.16)+32.0;
End;

Function RankineToCent(Rankine:Real):Real;Begin
 RankineToCent:=(5.0/9.0)*(Rankine-491.69);
End;

Function CentToRankine(Celsius:Real):Real;Begin
 CentToRankine:=(Celsius*1.8)+491.69;
End;

Function RankineToFahr(Rankine:Real):Real;Begin
 RankineToFahr:=Rankine-459.69;
End;

Function ReaumurToCent(Reaumur:Real):Real;BEGIN
 ReaumurToCent:=Reaumur*5/4;
End;

Function NewtonToCent(Newton:Real):Real;BEGIN
 NewtonToCent:=Newton*100/33;
End;

Var
 SourceTemp,TargetTemp:(None,Celcius,Kelvin,Fahrenheit,Rankine,Newton);
 Mesure:Real;
 Err:Word;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('CONVERS : Cette commande permet de convertir une unite de mesure ',
                   'de temperature.');
  WriteLn;
  WriteLn('Syntaxe : CONVERS source TO destination mesure');
  WriteLn;
  WriteLn(' source       La source peut etre : CELCIUS, KELVIN, FAHRENHEIT, RANKINE');
  WriteLn(' destination  La destination peut etre : CELCIUS, KELVIN, FAHRENHEIT, RANKINE');
  WriteLn(' mesure       La mesure correspond a chiffre de la temperature source');
 End
  Else
 If ParamCount>0Then Begin
  SourceTemp:=None;
  TargetTemp:=None;
  If StrToUpper(ParamStr(1))='CELCIUS'Then SourceTemp:=Celcius Else
  If StrToUpper(ParamStr(1))='KELVIN'Then SourceTemp:=Kelvin Else
  If StrToUpper(ParamStr(1))='FAHRENHEIT'Then SourceTemp:=Fahrenheit Else
  If StrToUpper(ParamStr(1))='RANKINE'Then SourceTemp:=Rankine Else
  If StrToUpper(ParamStr(1))='NEWTON'Then SourceTemp:=Rankine
   Else
  Begin
   WriteLn('Source non reconnu');
   Halt;
  End;
  If StrToUpper(ParamStr(2))<>'TO'Then Begin
   WriteLn('Parametre TO attendu');
   Halt;
  End;
  If StrToUpper(ParamStr(3))='CELCIUS'Then TargetTemp:=Celcius Else
  If StrToUpper(ParamStr(3))='KELVIN'Then TargetTemp:=Kelvin Else
  If StrToUpper(ParamStr(3))='FAHRENHEIT'Then TargetTemp:=Fahrenheit Else
  If StrToUpper(ParamStr(1))='RANKINE'Then TargetTemp:=Rankine Else
  If StrToUpper(ParamStr(1))='NEWTON'Then SourceTemp:=Rankine
   Else
  Begin
   WriteLn('Destination non reconnu');
   Halt;
  End;
  Val(ParamStr(4),Mesure,Err);
  If Err<>0Then Begin
   WriteLn('Valeur invalide');
   Halt;
  End;
  Case SourceTemp of
   Celcius:Case TargetTemp of
    Fahrenheit:WriteLn(CentToFahr(Mesure):0:3);
    Kelvin:WriteLn(CentToKelvin(Mesure):0:3);
    Celcius:WriteLn(Mesure:0:3);
    Rankine:WriteLn(CentToRankine(Mesure):0:3);
    Else WriteLn('Destination inconnu');
   End;
   Fahrenheit:Case TargetTemp of
    Fahrenheit:WriteLn(Mesure:0:3);
    Kelvin:WriteLn(FahrToCent(CentToKelvin(Mesure)):0:3);
    Celcius:WriteLn(FahrToCent(Mesure):0:3);
    Rankine:WriteLn(FahrToCent(CentToRankine(Mesure)):0:3);
    Else WriteLn('Destination inconnu');
   End;
   Kelvin:Case TargetTemp of
    Fahrenheit:WriteLn(KelvinToFahr(Mesure):0:3);
    Kelvin:WriteLn(Mesure:0:3);
    Celcius:WriteLn(KelvinToCent(Mesure):0:3);
    Rankine:WriteLn(KelvinToCent(CentToRankine(Mesure)):0:3);
    Else WriteLn('Destination inconnu');
   End;
   Rankine:Case TargetTemp of
    Fahrenheit:WriteLn(RankineToFahr(Mesure):0:3);
    Kelvin:WriteLn(RankineToCent(CentToKelvin(Mesure)):0:3);
    Celcius:WriteLn(RankineToCent(Mesure):0:3);
    Rankine:WriteLn(Mesure:0:3);
    Else WriteLn('Destination inconnu');
   End;
   Newton:Case TargetTemp of
    Fahrenheit:WriteLn(NewtonToCent(CentToFahr(Mesure)):0:3);
    Kelvin:WriteLn(NewtonToCent(CentToKelvin(Mesure)):0:3);
    Celcius:WriteLn(NewtonToCent(Mesure):0:3);
    Rankine:WriteLn(NewtonToCent(CentToRankine(Mesure)):0:3);
    Newton:WriteLn(Mesure:0:3);
    Else WriteLn('Destination inconnu');
   End;
   Else WriteLn('Source inconnu');
  End;
 End;
END.