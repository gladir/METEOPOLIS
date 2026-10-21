{ @author: Sylvain Maltais (support@gladir.com)
 @created: 2026
 @website(https://www.gladir.com/meteopolis)
 @abstract(Target: Turbo Pascal, Free Pascal)
 @description: Processeur arithmetique NetCDF autonome. Compilation: fpc NCAP2.PAS (Free Pascal 3.2 ou ulterieur). }

Program NCAP2;

{$mode fpc}{$modeswitch result+}{$H+}{$R+}{$Q+}

Const
 MaxElements = 16000000;
 MaxIterations = 1000000;

Type
  { Toutes les implementations ci-dessous sont locales au programme.
    Aucune clause uses ni fichier include: primitives natives du compilateur. }
 TByteBuffer = Array Of Byte;
 PStream = ^TStream;
 TStream = Record
  DiskFile: File;
  OnDisk, Opened, Writable: Boolean;
  Buffer: TByteBuffer;
  Cursor, Used: Int64;
 End;
 TStrings = Array Of String;
 TTextList = Record
  Entries: TStrings;
 End;

Const
 fmOpenRead=0;
 fmShareDenyWrite=0;
 fmCreate=1;

Type
 TIntArray = Array Of LongInt;
 TNumbers = Array Of Double;
 TAttribute = Record
  Name: String;
  Kind, Count: LongInt;
  Data: RawByteString;
 End;
 TAttributes = Array Of TAttribute;
 TDimension = Record
  Name: String;
  Size: LongInt;
  Unlimited: Boolean
 End;
 TDimensions = Array Of TDimension;
 TValue = Record
  Dims: TIntArray;
  Data: TNumbers;
  Text: String;
  IsText: Boolean;
  NumericKind: LongInt
 End;
 TVariable = Record
  Name: String;
  Kind: LongInt;
  Value: TValue;
  Attrs: TAttributes;
  Offset, DiskSize: Int64;
  Changed, Keep: Boolean;
 End;
 TVariables = Array Of TVariable;
 TParserState = Record
  Pos, Start: SizeInt;
  Token: String;
  TokenKind: Char
 End;

Var
 Dims: TDimensions;
 Vars: TVariables;
 GlobalAttrs: TAttributes;
 Script, InputName, OutputName, InputPath, LocalPath, FormatName: String;
 AddAttrs, DeleteAttrs: TTextList;
 P: TParserState;
 Overwrite, AppendMode, OnlyChanged, Coordinates, History, FortranIndex: Boolean;
 NoTemp, VersionOnly: Boolean;
 FormatVersion, DebugLevel: LongInt;
 HeaderPad: Int64;
 Iterations: LongInt;
 Masked: Boolean;
 ActiveMask: TValue;
 OpenStreams: Array[0..31] Of PStream;
 PendingOutput: String;
 ScriptRunning: Boolean;

Procedure ReportError(Const S: String);
Var
 I,Line: SizeInt;
 F: File;
Begin
 Write(StdErr,'NCAP2: ');
 If ScriptRunning Then Begin
  Line:=1;
  For I:=1 To P.Start Do If (I<=Length(Script)) And (Script[I]=#10) Then Inc(Line);
  Write(StdErr,'Script ligne ',Line,' (position ',P.Start,'): ');
 End;
 WriteLn(StdErr,S);
  { Le registre garde les adresses des records actifs. Une erreur ferme
    les fichiers avant Halt, sans objet exception ni deroulement de pile. }
 For I:=0 To High(OpenStreams) Do If OpenStreams[I]<>Nil Then Begin
  If OpenStreams[I]^.Opened Then Begin
      {$I-} Close(OpenStreams[I]^.DiskFile); If IOResult<>0 Then Begin
   End; {$I+}
   OpenStreams[I]^.Opened:=False;
  End;
 End;
 If PendingOutput<>'' Then Begin
  Assign(F,PendingOutput);
    {$I-} Erase(F); If IOResult<>0 Then Begin
  End; {$I+}
 End;
 Halt(1);
End;

Procedure StreamInit(Var F: TStream);
Var
 I: LongInt;
Begin
 F.OnDisk:=False; F.Opened:=False; F.Writable:=False;
 F.Buffer:=Nil; F.Cursor:=0; F.Used:=0;
 For I:=0 To High(OpenStreams) Do If OpenStreams[I]=Nil Then Begin
  OpenStreams[I]:=@F; Exit
 End;
 ReportError('Trop de flux ouverts');
End;

Procedure StreamOpen(Var F: TStream; Const Name: String; Mode: LongInt);
Var
 Code: LongInt;
Begin
 StreamInit(F); F.OnDisk:=True; F.Writable:=Mode=fmCreate;
 Assign(F.DiskFile,Name);
  {$I-}
 If F.Writable Then Rewrite(F.DiskFile,1) Else
 Begin
  FileMode:=0; Reset(F.DiskFile,1);
 End;
 Code:=IOResult;
  {$I+}
 If Code<>0 Then ReportError('Impossible d''ouvrir '+Name+' (erreur E/S)');
 F.Opened:=True;
End;

Procedure StreamClose(Var F: TStream);
Var
 I,Code: LongInt;
Begin
 Code:=0;
 If F.Opened Then Begin
 {$I-} Close(F.DiskFile); Code:=IOResult; {$I+}
 End;
 F.Opened:=False; F.Buffer:=Nil;
 For I:=0 To High(OpenStreams) Do If OpenStreams[I]=@F Then OpenStreams[I]:=Nil;
 If Code<>0 Then ReportError('Erreur de fermeture du fichier');
End;

Function StreamSize(Var F: TStream): Int64;
Var
 Code: LongInt;
Begin
 If Not F.OnDisk Then Exit(F.Used);
  {$I-} Result:=FileSize(F.DiskFile); Code:=IOResult; {$I+}
 If Code<>0 Then ReportError('Impossible de mesurer le fichier');
End;

Procedure StreamSeek(Var F: TStream; N: Int64);
Var
 Code: LongInt;
Begin
 If N<0 Then ReportError('Position de fichier negative');
 If F.OnDisk Then Begin
    {$I-} Seek(F.DiskFile,N); Code:=IOResult; {$I+}
  If Code<>0 Then ReportError('Impossible de deplacer la position du fichier');
 End;
 F.Cursor:=N;
End;
Procedure StreamWrite(Var F: TStream; Const B; N: LongInt);Forward;

Procedure StreamResize(Var F: TStream; N: Int64);
Var
 Saved,Old: Int64;
 B: Byte;
 Code: LongInt;
Begin
 If (N<0) Or ((Not F.OnDisk) And (N>High(SizeInt))) Then ReportError(
 'Taille de flux invalide');
 If Not F.OnDisk Then Begin
  SetLength(F.Buffer,N); F.Used:=N; If F.Cursor>N Then F.Cursor:=N; Exit
 End;
 If Not F.Writable Then ReportError('Flux en lecture seule');
 Saved:=F.Cursor; Old:=StreamSize(F);
 If N>Old Then Begin
  StreamSeek(F,N-1); B:=0; StreamWrite(F,B,1)
 End
 Else If N<Old Then Begin
  StreamSeek(F,N);
    {$I-} Truncate(F.DiskFile); Code:=IOResult; {$I+}
  If Code<>0 Then ReportError('Impossible de tronquer le fichier');
 End;
 StreamSeek(F,Saved);
End;

Function StreamRead(Var F: TStream; Var B; N: LongInt): LongInt;
Var
 Code: LongInt;
 Available: Int64;
Begin
 If N<0 Then ReportError('Longueur de lecture negative'); Result:=0;
 If N=0 Then Exit;
 If F.OnDisk Then Begin
    {$I-} BlockRead(F.DiskFile,B,N,Result); Code:=IOResult; {$I+}
  If Code<>0 Then ReportError('Erreur de lecture du fichier');
 End Else
 Begin
  Available:=F.Used-F.Cursor; If Available<=0 Then Exit;
  Result:=N; If Available<N Then Result:=Available;
  Move(F.Buffer[SizeInt(F.Cursor)],B,Result);
 End;
 Inc(F.Cursor,Result);
End;

Procedure StreamWrite(Var F: TStream; Const B; N: LongInt);
Var
 Written,Code: LongInt;
 Needed,Capacity: Int64;
Begin
 If N<0 Then ReportError('Longueur d''ecriture negative'); If N=0 Then Exit;
 If F.OnDisk Then Begin
  If Not F.Writable Then ReportError('Flux en lecture seule');
    {$I-} BlockWrite(F.DiskFile,B,N,Written); Code:=IOResult; {$I+}
  If (Code<>0) Or (Written<>N) Then ReportError('Erreur d''ecriture du fichier');
 End Else
 Begin
  Needed:=F.Cursor+N; If Needed>High(SizeInt) Then ReportError('Flux memoire trop grand');
  If Needed>Length(F.Buffer) Then Begin
   Capacity:=Length(F.Buffer)*Int64(2); If Capacity<Needed Then Capacity:=Needed;
   If Capacity>High(SizeInt) Then Capacity:=Needed;
   SetLength(F.Buffer,Capacity);
  End;
  Move(B,F.Buffer[SizeInt(F.Cursor)],N); If Needed>F.Used Then F.Used:=Needed;
 End;
 Inc(F.Cursor,N);
End;

Procedure ListAdd(Var L: TTextList; Const S: String);
Var
 N: LongInt;
Begin
 N:=Length(L.Entries); SetLength(L.Entries,N+1); L.Entries[N]:=S
End;

Function IntToStr(X: Int64): String;Begin
 Str(X,Result)
End;

Function FloatToStr(X: Double): String;Begin
 Str(X,Result);
 While (Length(Result)>0) And (Result[1]=' ') Do Delete(Result,1,1);
End;

Function TryStrToInt64(Const S: String; Var X: Int64): Boolean;
Var
 Code: LongInt;
Begin
 Val(S,X,Code); Result:=(S<>'') And (Code=0)
End;

Function TryStrToInt(Const S: String; Var X: LongInt): Boolean;
Var
 V: Int64;
Begin
 Result:=TryStrToInt64(S,V);
 If Result Then Result:=(V>=Low(LongInt)) And (V<=High(LongInt));
 If Result Then X:=V Else X:=0;
End;

Function LowerCase(Const S: String): String;
Var
 I: SizeInt;
Begin
 Result:=S;
 For I:=1 To Length(Result) Do  If Result[I] In ['A'..'Z'] Then Result[I]:=Chr(Ord(
 Result[I])+32)
End;

Function Min(A,B: Double): Double;
overload;
Begin
 If A<B Then Result:=A Else Result:=B
End;

Function Max(A,B: Double): Double;Begin
 If A>B Then Result:=A Else Result:=B
End;

Function Min(A,B: SizeInt): SizeInt;
overload;
Begin
 If A<B Then Result:=A Else Result:=B
End;

Function IsNan(X: Double): Boolean;
Var
 Bits: QWord;
Begin
 Move(X,Bits,8); Result:=((Bits Shr 52) And $7FF=$7FF) And (Bits And $FFFFFFFFFFFFF<>0)
End;

Function IsInfinite(X: Double): Boolean;
Var
 Bits: QWord;
Begin
 Move(X,Bits,8); Result:=(Bits And $7FFFFFFFFFFFFFFF)=$7FF0000000000000
End;

Function Power(X,Y: Double): Double;
Var
 N: Int64;
 Negative: Boolean;
Begin
 If IsNan(X) Or IsNan(Y) Or IsInfinite(X) Or IsInfinite(Y) Then ReportError(
 'Puissance non finie');
 If X=0 Then Begin
  If Y<0 Then ReportError('Puissance de zero negative'); If Y=0 Then Exit(1) Else Exit(0)
 End;
 If (Abs(Y)<9223372036854775808.0) And (Y=Trunc(Y)) Then Begin
  N:=Trunc(Y); If N=Low(Int64) Then ReportError('Exposant hors limites');
  Negative:=N<0; If Negative Then N:=-N;
  Result:=1;
  While N>0 Do Begin
   If Odd(N) Then Result:=Result*X; N:=N Div 2; If N>0 Then X:=X*X;
  End;
  If Negative Then Result:=1/Result;
 End Else
 Begin
  If X<0 Then ReportError('Puissance fractionnaire d''un nombre negatif');
  Result:=Exp(Y*Ln(X))
 End;
End;

Function ArcTan2(Y,X: Double): Double;Begin
 If X>0 Then Result:=ArcTan(Y/X) Else
 If X<0 Then Begin
  Result:=ArcTan(Y/X); If Y>=0 Then Result:=Result+Pi Else Result:=Result-Pi
 End
 Else If Y>0 Then Result:=Pi/2 Else If Y<0 Then Result:=-Pi/2 Else Result:=0;
End;

Function ArcSin(X: Double): Double;Begin
 If Abs(X)>1 Then ReportError('asin: argument hors [-1,1]');
 Result:=ArcTan2(X,Sqrt((1-X)*(1+X)));
End;

Function ArcCos(X: Double): Double;Begin
 If Abs(X)>1 Then ReportError('acos: argument hors [-1,1]');
 Result:=ArcTan2(Sqrt((1-X)*(1+X)),X);
End;

Function Log10(X: Double): Double;Begin
 If X<=0 Then ReportError('log10: argument positif attendu'); Result:=Ln(X)/Ln(10)
End;

Function Tan(X: Double): Double;
Var
 C: Double;
Begin
 C:=Cos(X); If C=0 Then ReportError('tan: resultat indefini'); Result:=Sin(X)/C
End;

Function Sinh(X: Double): Double;Begin
 Result:=(Exp(X)-Exp(-X))/2
End;

Function Cosh(X: Double): Double;Begin
 Result:=(Exp(X)+Exp(-X))/2
End;

Function Tanh(X: Double): Double;
Var
 E: Double;
Begin
 E:=Exp(-2*Abs(X)); Result:=(1-E)/(1+E); If X<0 Then Result:=-Result
End;

Function Floor(X: Double): Double;Begin
 If IsNan(X) Or IsInfinite(X) Or (Abs(X)>=9223372036854775808.0) Then Exit(X);
 Result:=Trunc(X); If Result>X Then Result:=Result-1;
End;

Function Ceil(X: Double): Double;Begin
 If IsNan(X) Or IsInfinite(X) Or (Abs(X)>=9223372036854775808.0) Then Exit(X);
 Result:=Trunc(X); If Result<X Then Result:=Result+1;
End;

Function FileExists(Const Name: String): Boolean;
Var
 F: File;
 Code: LongInt;
Begin
 Assign(F,Name); FileMode:=0;
  {$I-} Reset(F,1); Code:=IOResult;
 Result:=Code=0;
 If Result Then Begin
  Close(F); If IOResult<>0 Then Begin
  End
 End; {$I+}
End;

Function DeleteFile(Const Name: String): Boolean;
Var
 F: File;
Begin
 Assign(F,Name); {$I-} Erase(F); Result:=IOResult=0; {$I+}
End;

Function RenameFile(Const OldName,NewName: String): Boolean;
Var
 F: File;
Begin
 Assign(F,OldName); {$I-} Rename(F,NewName); Result:=IOResult=0; {$I+}
End;

Function IncludeTrailingPathDelimiter(Const S: String): String;Begin
 Result:=S;
 If (S<>'') And Not (S[Length(S)] In ['/', '\']) Then Result:=Result+DirectorySeparator;
End;

Function ExtractFilePath(Const S: String): String;
Var
 I: SizeInt;
Begin
 I:=Length(S);
 While (I>0) And Not (S[I] In ['/', '\']) Do Dec(I); Result:=Copy(S,1,I);
End;

Function ExpandFileName(Const Name: String): String;
Var
 S,Root,Part,Cwd: String;
 I,J,Code: LongInt;
 Parts: TStrings;
Begin
 S:=Name;
 {$IFDEF MSWINDOWS}
  For I:=1 To Length(S) Do If S[I]='/' Then S[I]:='\';
 {$ENDIF}
  {$I-} GetDir(0,Cwd); Code:=IOResult; {$I+}
 If Code<>0 Then ReportError('Impossible de lire le repertoire courant');
 {$IFDEF MSWINDOWS}
  If (Length(S)>=2) And (S[2]=':') Then Begin
   If (Length(S)<3) Or (S[3]<>'\') Then Begin
    I:=Ord(UpCase(S[1]))-Ord('A')+1;
    If (I<1) Or (I>26) Then ReportError('Lecteur invalide');
      {$I-} GetDir(I,Cwd); Code:=IOResult; {$I+}
    If Code<>0 Then ReportError('Impossible de lire le repertoire du lecteur');
    S:=IncludeTrailingPathDelimiter(Cwd)+Copy(S,3,MaxInt);
   End;
  End Else If Copy(S,1,2)<>'\\' Then Begin
   If Copy(S,1,1)='\' Then S:=Copy(Cwd,1,2)+S
                      Else S:=IncludeTrailingPathDelimiter(Cwd)+S;
  End;
  If Copy(S,1,2)='\\' Then Begin
   I:=3; J:=0;
   While (I<=Length(S)) And (J<2) Do Begin
    If S[I]='\' Then Inc(J); Inc(I)
   End;
   Root:=Copy(S,1,I-1); S:=Copy(S,I,MaxInt);
  End Else
  Begin
   Root:=Copy(S,1,3); Delete(S,1,3)
  End;
 {$ELSE}
  If Copy(S,1,1)<>'/' Then S:=IncludeTrailingPathDelimiter(Cwd)+S;
  Root:='/'; Delete(S,1,1);
 {$ENDIF}
 Parts:=Nil; I:=1;
 While I<=Length(S) Do Begin
  J:=I;
  While (J<=Length(S)) And (S[J]<>DirectorySeparator) Do Inc(J);
  Part:=Copy(S,I,J-I); I:=J+1;
  If Part='..' Then Begin
   If Length(Parts)>0 Then SetLength(Parts,Length(Parts)-1)
  End
  Else If (Part<>'') And (Part<>'.') Then Begin
   J:=Length(Parts); SetLength(Parts,J+1); Parts[J]:=Part
  End;
 End;
 Result:=Root;
 For I:=0 To High(Parts) Do Result:=IncludeTrailingPathDelimiter(Result)+Parts[I];
End;

Function SameFileName(Const A,B: String): Boolean;Begin
 {$IFDEF MSWINDOWS}
  Result:=LowerCase(A)=LowerCase(B);
 {$ELSE}
  Result:=A=B;
 {$ENDIF}
End;

Function GetTempFileName(Const Dir,Prefix: String): String;
Var
 I: LongInt;
Begin
 For I:=1 To 10000 Do Begin
  Result:=IncludeTrailingPathDelimiter(Dir)+Prefix+IntToStr(Random(High(LongInt)))+'.tmp';
  If Not FileExists(Result) Then Exit;
 End;
 ReportError('Impossible de choisir un nom temporaire');
End;

Function Product(Const Shape: TIntArray): LongInt;
Var
 I: LongInt;
 N: Int64;
Begin
 N := 1;
 For I := 0 To High(Shape) Do Begin
  If (Shape[I] < 0) Or (Shape[I] >= Length(Dims)) Then ReportError('Dimension invalide');
  N := N * Dims[Shape[I]].Size;
  If N > MaxElements Then ReportError('Tableau trop grand (limite: 16000000 elements)');
 End;
 Result := N;
End;

Function FindDim(Const Name: String): LongInt;
Var
 I: LongInt;
Begin
 Result := -1;
 For I := 0 To High(Dims) Do If Dims[I].Name=Name Then Exit(I)
End;

Function FindVar(Const Name: String): LongInt;
Var
 I: LongInt;
Begin
 Result := -1;
 For I := 0 To High(Vars) Do If Vars[I].Name=Name Then Exit(I)
End;

Function FindAttr(Const A: TAttributes; Const Name: String): LongInt;
Var
 I: LongInt;
Begin
 Result := -1;
 For I := 0 To High(A) Do If A[I].Name=Name Then Exit(I)
End;

Function Scalar(X: Double): TValue;Begin
 Result := Default(TValue); Result.NumericKind:=6; SetLength(Result.Data,1);
 Result.Data[0]:=X
End;

Function CopyValue(Const V: TValue): TValue;Begin
 Result:=V; Result.Dims:=Copy(V.Dims); Result.Data:=Copy(V.Data)
End;

Function TypeSize(K: LongInt): LongInt;Begin
 Case K Of 1,2: Result:=1; 3: Result:=2; 4,5: Result:=4; 6: Result:=8;
 Else ReportError('Type NetCDF non classique: '+IntToStr(K)); Result:=0
End;
End;

Procedure ReadExact(Var F: TStream; Var B; N: LongInt);Begin
 If StreamRead(F,B,N)<>N Then ReportError('Fichier NetCDF tronque')
End;

Function ReadUInt(Var F: TStream; N: LongInt): QWord;
Var
 I: LongInt;
 B: Byte;
Begin
 Result:=0;
 For I:=1 To N Do Begin
  ReadExact(F,B,1); Result:=(Result Shl 8) Or B
 End
End;

Procedure WriteUInt(Var F: TStream; X: QWord; N: LongInt);
Var
 I: LongInt;
 B: Byte;
Begin
 For I:=N-1 Downto 0 Do Begin
  B:=(X Shr (I*8)) And 255; StreamWrite(F,B,1)
 End
End;

Function ReadCount(F: TStream): LongInt;
Var
 N: QWord;
Begin
 N:=ReadUInt(F,4); If N>MaxLongInt Then ReportError('Compteur NetCDF trop grand');
 Result:=N
End;

Procedure ReadPadding(Var F: TStream; N: Int64);
Var
 B: Byte;
 I: LongInt;
Begin
 For I:=1 To (4-N Mod 4) Mod 4 Do ReadExact(F,B,1)
End;

Procedure WritePadding(Var F: TStream; N: Int64);
Var
 I: LongInt;
 B: Byte;
Begin
 B:=0;
 For I:=1 To (4-N Mod 4) Mod 4 Do StreamWrite(F,B,1)
End;

Function ReadName(F: TStream): String;
Var
 N: LongInt;
Begin
 N:=ReadCount(F); If (N=0) Or (N>1048576) Then ReportError('Nom NetCDF invalide');
 SetLength(Result,N); ReadExact(F,Result[1],N); ReadPadding(F,N)
End;

Procedure WriteName(Var F: TStream; Const S: String);Begin
 WriteUInt(F,Length(S),4); If S<>'' Then StreamWrite(F,S[1],Length(S));
 WritePadding(F,Length(S))
End;

Function ListCount(Var F: TStream; Tag: LongInt): LongInt;
Var
 T,N: LongInt;
Begin
 T:=ReadCount(F); N:=ReadCount(F);
 If ((T<>Tag) And (T<>0)) Or ((T=0) And (N<>0)) Then ReportError('Liste NetCDF invalide');
 If N>100000 Then ReportError('Trop d''objets NetCDF'); Result:=N
End;

Function ReadAttrs(F: TStream): TAttributes;
Var
 I,N: LongInt;
 Bytes: Int64;
Begin
 Result:=Nil; N:=ListCount(F,12); SetLength(Result,N);
 For I:=0 To N-1 Do With Result[I] Do Begin
  Name:=ReadName(F); Kind:=ReadCount(F); Count:=ReadCount(F);
  Bytes:=Int64(Count)*TypeSize(Kind);
  If (Bytes>StreamSize(F)-F.Cursor) Or (Bytes>128*1024*1024) Then ReportError(
  'Attribut trop grand ou tronque');
  SetLength(Data,Bytes); If Bytes>0 Then ReadExact(F,Data[1],Bytes); ReadPadding(F,Bytes);
 End;
End;

Procedure WriteAttrs(Var F: TStream; Const A: TAttributes);
Var
 I: LongInt;
Begin
 If Length(A)=0 Then WriteUInt(F,0,4) Else WriteUInt(F,12,4);
 WriteUInt(F,Length(A),4);
 For I:=0 To High(A) Do Begin
  WriteName(F,A[I].Name); WriteUInt(F,A[I].Kind,4); WriteUInt(F,A[I].Count,4);
  If A[I].Data<>'' Then StreamWrite(F,A[I].Data[1],Length(A[I].Data));
  WritePadding(F,Length(A[I].Data));
 End;
End;

Function ReadNumber(Var F: TStream; K: LongInt): Double;
Var
 U: LongWord;
 Q: QWord;
 S: Single;
 D: Double;
 B: Byte;
 W: Word;
Begin
 Case K Of
 1:
 Begin
  B:=ReadUInt(F,1); Result:=ShortInt(B)
 End;
 2: Result:=ReadUInt(F,1);
 3:
 Begin
  W:=ReadUInt(F,2); Result:=SmallInt(W)
 End;
 4:
 Begin
  U:=ReadUInt(F,4); Result:=LongInt(U)
 End;
 5:
 Begin
  U:=ReadUInt(F,4); Move(U,S,4); Result:=S
 End;
 6:
 Begin
  Q:=ReadUInt(F,8); Move(Q,D,8); Result:=D
 End;
 Else ReportError('Type invalide'); Result:=0
End;
End;

Procedure WriteNumber(Var F: TStream; K: LongInt; X: Double);
Var
 U: LongWord;
 Q: QWord;
 S: Single;
 D: Double;
 I: Int64;
Begin
 If K In [1,2,3,4] Then Begin
  If IsNan(X) Or IsInfinite(X) Then ReportError('Conversion non finie vers un entier');
  Case K Of
  1: If (X < -128) Or (X > 127) Then ReportError('Depassement NC_BYTE');
  2: If (X < 0) Or (X > 255) Then ReportError('Depassement NC_CHAR');
  3: If (X < -32768) Or (X > 32767) Then ReportError('Depassement NC_SHORT');
  4: If (X < -2147483648.0) Or (X > 2147483647.0) Then ReportError('Depassement NC_INT');
 End;
 I:=Trunc(X); Move(I,Q,8); WriteUInt(F,Q,TypeSize(K));
End Else If K=5 Then Begin
 S:=X; Move(S,U,4); WriteUInt(F,U,4)
End
 Else
Begin
 D:=X; Move(D,Q,8); WriteUInt(F,Q,8)
End;
End;

Procedure LoadNetCDF(Const Name: String; Merge: Boolean);
Var
 F: TStream;
 Magic: Array[0..3] Of Byte;
 ND,NV,I,J,K,V,OldN,DimId,NumRecords,RecordVars: LongInt;
 Map: TIntArray;
 RecSize,RecordBase,At: Int64;
 A: TAttributes;
 VV: TVariable;
 NewDims: TDimensions;
 NewVars: TVariables;
Begin
 StreamOpen(F,Name,fmOpenRead Or fmShareDenyWrite);
 Begin
  ReadExact(F,Magic,4);
  If (Magic[0]<>67) Or (Magic[1]<>68) Or (Magic[2]<>70) Or
  Not (Magic[3] In [1,2]) Then ReportError(
  'Seuls les formats NetCDF CDF-1 et CDF-2 sont pris en charge');
  If Not Merge Then FormatVersion:=Magic[3];
  NumRecords:=ReadCount(F); ND:=ListCount(F,10); SetLength(Map,ND);
  SetLength(NewDims,ND);
  For I:=0 To ND-1 Do Begin
   NewDims[I].Name:=ReadName(F); J:=ReadCount(F);
   NewDims[I].Unlimited:=J=0; If J=0 Then J:=NumRecords; NewDims[I].Size:=J;
   K:=FindDim(NewDims[I].Name);
   If K<0 Then Begin
    K:=Length(Dims); SetLength(Dims,K+1); Dims[K]:=NewDims[I]
   End
   Else If (Dims[K].Size<>J) Or (Dims[K].Unlimited<>NewDims[I].Unlimited)
   Then        ReportError('Dimensions incompatibles: '+NewDims[I].Name);
   Map[I]:=K;
  End;
  A:=ReadAttrs(F);
  If Not Merge Then GlobalAttrs:=A Else
  For I:=0 To High(A) Do Begin
   J:=FindAttr(GlobalAttrs,A[I].Name);
   If J<0 Then Begin
    J:=Length(GlobalAttrs); SetLength(GlobalAttrs,J+1)
   End;
   GlobalAttrs[J]:=A[I];
  End;
  NV:=ListCount(F,11); SetLength(NewVars,NV); RecSize:=0; RecordVars:=0;
  For I:=0 To NV-1 Do Begin
   VV:=Default(TVariable); VV.Name:=ReadName(F); J:=ReadCount(F);
   If J>ND Then ReportError('Rang NetCDF invalide'); SetLength(VV.Value.Dims,J);
   For K:=0 To J-1 Do Begin
    DimId:=ReadCount(F);
    If DimId>=ND Then ReportError('Identifiant de dimension invalide');
    VV.Value.Dims[K]:=Map[DimId]
   End;
   VV.Attrs:=ReadAttrs(F); VV.Kind:=ReadCount(F); TypeSize(VV.Kind);
   VV.DiskSize:=ReadUInt(F,4);
   If Magic[3]=2 Then VV.Offset:=ReadUInt(F,8) Else VV.Offset:=ReadUInt(F,4);
   SetLength(VV.Value.Data,Product(VV.Value.Dims));
   If (J>0) And Dims[VV.Value.Dims[0]].Unlimited Then Begin
    Inc(RecSize,VV.DiskSize); Inc(RecordVars)
   End;
   NewVars[I]:=VV;
  End;
    { A unique record variable has no padding between records (CDF specification). }
  If RecordVars=1 Then
  For I:=0 To NV-1 Do With NewVars[I] Do      If (Length(Value.Dims)>0)
  And Dims[Value.Dims[0]].Unlimited Then Begin
   RecSize:=TypeSize(Kind);
   For J:=1 To High(Value.Dims) Do RecSize:=RecSize*Dims[Value.Dims[J]].Size;
  End;
  For I:=0 To NV-1 Do Begin
   VV:=NewVars[I]; OldN:=Length(VV.Value.Data); RecordBase:=OldN;
   If (Length(VV.Value.Dims)>0) And Dims[VV.Value.Dims[0]].Unlimited Then Begin
    RecordBase:=1;
    For J:=1 To High(VV.Value.Dims) Do RecordBase:=RecordBase*Dims[VV.Value.Dims[J]].Size;
   End;
   For J:=0 To OldN-1 Do Begin
    If (Length(VV.Value.Dims)>0) And Dims[VV.Value.Dims[0]].Unlimited Then          At:=
    VV.Offset+(J Div RecordBase)*RecSize+(J Mod RecordBase)*TypeSize(VV.Kind)
    Else At:=VV.Offset+Int64(J)*TypeSize(VV.Kind);
    If (At<0) Or (At>StreamSize(F)-TypeSize(VV.Kind)) Then ReportError(
    'Donnees NetCDF hors fichier');
    StreamSeek(F,At); VV.Value.Data[J]:=ReadNumber(F,VV.Kind);
   End;
   V:=FindVar(VV.Name);
   If V<0 Then Begin
    V:=Length(Vars); SetLength(Vars,V+1)
   End;
   VV.Keep:=Vars[V].Keep; Vars[V]:=VV;
  End;
 End; StreamClose(F);
End;

Procedure SetAttribute(Var A: TAttributes; Const Name: String; Const V: TValue);
Var
 I,J: LongInt;
 M: TStream;
Begin
 I:=FindAttr(A,Name); If I<0 Then Begin
  I:=Length(A); SetLength(A,I+1)
 End;
 A[I].Name:=Name;
 If V.IsText Then Begin
  A[I].Kind:=2; A[I].Count:=Length(V.Text); A[I].Data:=V.Text
 End
  Else
 Begin
  A[I].Kind:=V.NumericKind; If Not (A[I].Kind In [1,3,4,5,6]) Then A[I].Kind:=6;
  A[I].Count:=Length(V.Data); StreamInit(M);
  Begin
   For J:=0 To High(V.Data) Do WriteNumber(M,A[I].Kind,V.Data[J]);
   SetLength(A[I].Data,StreamSize(M));
   If StreamSize(M)>0 Then Move(M.Buffer[0],A[I].Data[1],StreamSize(M));
  End; StreamClose(M);
 End;
End;

Function GetAttribute(Const A: TAttributes; Const Name: String): TValue;
Var
 I,J: LongInt;
 M: TStream;
Begin
 Result:=Default(TValue); I:=FindAttr(A,Name);
 If I<0 Then ReportError('Attribut inconnu: '+Name);
 If A[I].Kind=2 Then Begin
  Result.IsText:=True; Result.Text:=A[I].Data
 End
  Else
 Begin
  Result.NumericKind:=A[I].Kind; SetLength(Result.Data,A[I].Count); StreamInit(M);
  Begin
   If A[I].Data<>'' Then StreamWrite(M,A[I].Data[1],Length(A[I].Data)); StreamSeek(M,0);
   For J:=0 To High(Result.Data) Do Result.Data[J]:=ReadNumber(M,A[I].Kind);
  End; StreamClose(M);
 End;
End;

Procedure Next;
Var
 C,Q: Char;
 B: SizeInt;
Begin
 Repeat
 While (P.Pos<=Length(Script)) And (Script[P.Pos]<=' ') Do Inc(P.Pos);
 If (Copy(Script,P.Pos,2)='//') Or (Copy(Script,P.Pos,1)='#') Then Begin
  While (P.Pos<=Length(Script)) And (Script[P.Pos]<>#10) Do Inc(P.Pos);
 End Else If Copy(Script,P.Pos,2)='/*' Then Begin
  Inc(P.Pos,2);
  While (P.Pos<=Length(Script)) And (Copy(Script,P.Pos,2)<>'*/') Do Inc(P.Pos);
  If P.Pos>Length(Script) Then ReportError('Commentaire non termine'); Inc(P.Pos,2);
 End Else Break;
 Until False;
 P.Start:=P.Pos; P.Token:=''; P.TokenKind:=#0;
 If P.Pos>Length(Script) Then Exit;
 C:=Script[P.Pos]; Inc(P.Pos);
 If C In ['a'..'z','A'..'Z','_'] Then Begin
  B:=P.Start;
  While (P.Pos<=Length(Script)) And (Script[P.Pos] In ['a'..'z','A'..'Z','0'..'9','_'])
  Do Inc(P.Pos);
  P.Token:=Copy(Script,B,P.Pos-B); P.TokenKind:='i';
 End Else If (C In ['0'..'9']) Or ((C='.') And (P.Pos<=Length(Script)) And (
 Script[P.Pos] In ['0'..'9'])) Then Begin
  B:=P.Start;
  While (P.Pos<=Length(Script)) And (Script[P.Pos] In ['0'..'9','.']) Do Inc(P.Pos);
  If (P.Pos<=Length(Script)) And (Script[P.Pos] In ['e','E']) Then Begin
   Inc(P.Pos);
   If (P.Pos<=Length(Script)) And (Script[P.Pos] In ['+','-']) Then Inc(P.Pos);
   While (P.Pos<=Length(Script)) And (Script[P.Pos] In ['0'..'9']) Do Inc(P.Pos);
  End;
  P.Token:=Copy(Script,B,P.Pos-B); P.TokenKind:='n';
 End Else If C In ['''','"'] Then Begin
  Q:=C; P.TokenKind:='s';
  While (P.Pos<=Length(Script)) And (Script[P.Pos]<>Q) Do Begin
   C:=Script[P.Pos]; Inc(P.Pos);
   If (C='\') And (P.Pos<=Length(Script)) Then Begin
    C:=Script[P.Pos]; Inc(P.Pos);
    Case C Of 'n': C:=#10; 't': C:=#9; 'r': C:=#13
   End
  End;
  P.Token:=P.Token+C;
 End;
 If P.Pos>Length(Script) Then ReportError('Chaine non terminee'); Inc(P.Pos);
End Else
Begin
 P.TokenKind:='p'; P.Token:=C;
 If (P.Pos<=Length(Script)) And
 ((Pos(C+Script[P.Pos],' == != <= >= && || += -= *= /= ++ -- ')>0) And (Script[P.Pos]<>
 ' ')) Then Begin
  P.Token:=C+Script[P.Pos]; Inc(P.Pos);
 End;
End;
End;

Procedure Expect(Const S: String);Begin
 If P.Token<>S Then ReportError('Attendu "'+S+'", trouve "'+P.Token+'"'); Next
End;

Function Identifier: String;Begin
 If P.TokenKind<>'i' Then ReportError('Identificateur attendu'); Result:=P.Token; Next
End;

Function NumericScalar(Const V: TValue): Double;Begin
 If V.IsText Or (Length(V.Data)<>1) Then ReportError('Scalaire numerique attendu');
 Result:=V.Data[0]
End;

Function IntegerScalar(Const V: TValue): LongInt;
Var
 X: Double;
Begin
 X:=NumericScalar(V); If IsNan(X) Or IsInfinite(X) Or (X<>Trunc(X)) Or
 (X<Low(LongInt)) Or (X>High(LongInt)) Then ReportError('Entier attendu');
 Result:=Trunc(X)
End;

Function BroadcastIndex(Const Shape: TIntArray; Const OutShape: TIntArray;
                        Flat: LongInt): LongInt;
Var
 I,J,K,C,Stride: LongInt;
Begin
 Result:=0; Stride:=1;
 For I:=High(OutShape) Downto 0 Do Begin
  C:=Flat Mod Dims[OutShape[I]].Size; Flat:=Flat Div Dims[OutShape[I]].Size;
  For J:=High(Shape) Downto 0 Do If Shape[J]=OutShape[I] Then Begin
   Stride:=1; If J<High(Shape) Then
   For K:=J+1 To High(Shape) Do Stride:=Stride*Dims[Shape[K]].Size;
   Inc(Result,C*Stride); Break;
  End;
 End;
End;

Function Combine(Const A,B: TValue; Const Op: String): TValue;
Var
 I,J,K,AI,BI: LongInt;
 X,Y,Z: Double;
Begin
 Result:=Default(TValue);
 If A.IsText Or B.IsText Then Begin
  If (Op='+') And A.IsText And B.IsText Then Begin
   Result.IsText:=True; Result.Text:=A.Text+B.Text; Exit
  End;
  ReportError('Operation numerique sur une chaine');
 End;
 Result.Dims:=Copy(A.Dims);
 For I:=0 To High(B.Dims) Do Begin
  K:=-1;
  For J:=0 To High(Result.Dims) Do If Result.Dims[J]=B.Dims[I] Then K:=J;
  If K<0 Then Begin
   K:=Length(Result.Dims); SetLength(Result.Dims,K+1); Result.Dims[K]:=B.Dims[I]
  End;
 End;
 SetLength(Result.Data,Product(Result.Dims));
 If (Length(A.Dims)=0) And (Length(A.Data)<>1) Then ReportError('Tableau sans dimensions')
 ;
 If (Length(B.Dims)=0) And (Length(B.Data)<>1) Then ReportError('Tableau sans dimensions')
 ;
 For I:=0 To High(Result.Data) Do Begin
  AI:=BroadcastIndex(A.Dims,Result.Dims,I); BI:=BroadcastIndex(B.Dims,Result.Dims,I);
  X:=A.Data[AI]; Y:=B.Data[BI]; Z:=0;
  If Op='+' Then Z:=X+Y Else If Op='-' Then Z:=X-Y Else If Op='*' Then Z:=X*Y Else
  If Op='/' Then Begin
   If Y=0 Then ReportError('Division par zero'); Z:=X/Y
  End
  Else If Op='%' Then Begin
   If Y=0 Then ReportError('Modulo par zero'); Z:=X-Trunc(X/Y)*Y
  End
  Else If Op='^' Then Z:=Power(X,Y) Else
  If Op='==' Then Z:=Ord(X=Y) Else If Op='!=' Then Z:=Ord(X<>Y) Else
  If Op='<' Then Z:=Ord(X<Y) Else If Op='>' Then Z:=Ord(X>Y) Else
  If Op='<=' Then Z:=Ord(X<=Y) Else If Op='>=' Then Z:=Ord(X>=Y) Else
  If Op='&&' Then Z:=Ord((X<>0) And (Y<>0)) Else If Op='||' Then
   Z:=Ord((X<>0) Or (Y<>0))
  Else ReportError('Operateur inconnu: '+Op);
  Result.Data[I]:=Z;
 End;
End;
Function Expression(MinPrec: LongInt): TValue;Forward;

Function ApplyFunction(Const Name: String; Const Args: Array Of TValue): TValue;
Var
 I,J,K,N,D: LongInt;
 X,Y: Double;
 S: String;
 Reduced,Counts: TIntArray;
 Include: Boolean;
Begin
 S:=LowerCase(Name); Result:=Default(TValue); N:=Length(Args);
 If S='array' Then Begin
  If N<3 Then ReportError('array(debut,pas,$dimension,...) attendu');
  X:=NumericScalar(Args[0]); Y:=NumericScalar(Args[1]); SetLength(Result.Dims,N-2);
  For I:=2 To N-1 Do Begin
   J:=IntegerScalar(Args[I]);
   If (J<0) Or (J>=Length(Dims)) Then ReportError('Dimension invalide');
   Result.Dims[I-2]:=J
  End;
  SetLength(Result.Data,Product(Result.Dims));
  For I:=0 To High(Result.Data) Do Result.Data[I]:=X+I*Y; Exit;
 End;
 If (S='pow') Or (S='atan2') Then Begin
  If N<>2 Then ReportError(S+': deux arguments attendus');
  If S='pow' Then Exit(Combine(Args[0],Args[1],'^'));
  Result:=Combine(Args[0],Args[1],'+');
  For I:=0 To High(Result.Data) Do Result.Data[I]:=ArcTan2(
  Args[0].Data[BroadcastIndex(Args[0].Dims,Result.Dims,I)],
  Args[1].Data[BroadcastIndex(Args[1].Dims,Result.Dims,I)]); Exit;
 End;
 If N=0 Then ReportError(S+': argument manquant');
 If Args[0].IsText Then ReportError('Argument numerique attendu');
 If (S='sum') Or (S='total') Or (S='avg') Or (S='mean') Or (S='min') Or
 (S='max') Or (S='size') Or (S='rms') Then Begin
  If (S='size') And (N=1) Then Exit(Scalar(Length(Args[0].Data)));
  Reduced:=Nil;
  If N=1 Then Reduced:=Copy(Args[0].Dims) Else
  Begin
   SetLength(Reduced,N-1);
   For I:=1 To N-1 Do Begin
    D:=IntegerScalar(Args[I]); Include:=False;
    For J:=0 To High(Args[0].Dims) Do If Args[0].Dims[J]=D Then Include:=True;
    If Not Include Then ReportError('Dimension de reduction absente'); Reduced[I-1]:=D;
   End;
  End;
  For I:=0 To High(Args[0].Dims) Do Begin
   Include:=True;
   For J:=0 To High(Reduced) Do If Reduced[J]=Args[0].Dims[I] Then Include:=False;
   If Include Then Begin
    K:=Length(Result.Dims); SetLength(Result.Dims,K+1); Result.Dims[K]:=Args[0].Dims[I]
   End;
  End;
  K:=Product(Result.Dims); SetLength(Result.Data,K); SetLength(Counts,K);
  Result.NumericKind:=6;
  For I:=0 To High(Args[0].Data) Do Begin
   J:=BroadcastIndex(Result.Dims,Args[0].Dims,I); Y:=Args[0].Data[I];
   If (S='min') Or (S='max') Then Begin
    If Counts[J]=0 Then Result.Data[J]:=Y Else
    If S='min' Then Result.Data[J]:=Min(Result.Data[J],Y) Else Result.Data[J]:=Max(
    Result.Data[J],Y);
   End Else If S='rms' Then Result.Data[J]:=Result.Data[J]+Y*Y
                       Else Result.Data[J]:=Result.Data[J]+Y;
   Inc(Counts[J]);
  End;
  For J:=0 To High(Result.Data) Do Begin
   If Counts[J]=0 Then ReportError('Reduction sur un tableau vide');
   If (S='avg') Or (S='mean') Then Result.Data[J]:=Result.Data[J]/Counts[J];
   If S='rms' Then Result.Data[J]:=Sqrt(Result.Data[J]/Counts[J]);
   If S='size' Then Result.Data[J]:=Counts[J];
  End;
  Exit;
 End;
 If N<>1 Then ReportError(S+': un argument attendu');
 Result:=CopyValue(Args[0]);
 K:=0;
 If S='byte' Then K:=1 Else If S='short' Then K:=3 Else If (S='int') Or (S='long')
 Then K:=4 Else
 If S='float' Then K:=5 Else If S='double' Then K:=6;
 Result.NumericKind:=K; If K=0 Then Result.NumericKind:=6;
 For I:=0 To High(Result.Data) Do Begin
  X:=Result.Data[I];
  If K In [1,3,4] Then Begin
   If IsNan(X) Or IsInfinite(X) Then ReportError('Conversion entiere non finie');
   Y:=Trunc(X); If ((K=1) And ((Y< -128) Or (Y>127))) Or
   ((K=3) And ((Y< -32768) Or (Y>32767))) Or
   ((K=4) And ((Y< -2147483648.0) Or (Y>2147483647.0))) Then ReportError(
   'Conversion entiere hors limites');
   X:=Y;
  End Else If K<>0 Then Begin
 { Storage is double; casts round numeric values only. }
   If K=5 Then X:=Single(X);
  End Else If S='abs' Then X:=Abs(X) Else If S='sqrt' Then X:=Sqrt(X) Else
  If S='sqr' Then X:=Sqr(X) Else If S='exp' Then X:=Exp(X) Else
  If (S='log') Or (S='ln') Then X:=Ln(X) Else If S='log10' Then X:=Log10(X) Else
  If S='sin' Then X:=Sin(X) Else If S='cos' Then X:=Cos(X) Else If S='tan' Then X:=
  Tan(X)
  Else If S='asin' Then X:=ArcSin(X) Else If S='acos' Then X:=ArcCos(X) Else If S=
  'atan' Then X:=ArcTan(X) Else
  If S='sinh' Then X:=Sinh(X) Else If S='cosh' Then X:=Cosh(X) Else If S=
  'tanh' Then X:=Tanh(X) Else
  If S='floor' Then X:=Floor(X) Else If S='ceil' Then X:=Ceil(X) Else
  If S='round' Then X:=Round(X) Else If S='int' Then X:=Trunc(X) Else
  If S='isnan' Then X:=Ord(IsNan(X)) Else If S='isfinite' Then X:=Ord(Not IsNan(X)
  And Not IsInfinite(X))
  Else ReportError('Fonction non implementee: '+Name);
  Result.Data[I]:=X;
 End;
End;
{ A slice selects inclusive bounds, as NCO does. LongInt indices remove a dimension.
  Kept ranges receive private dimensions, preventing false named broadcasting. }

Procedure ParseSelection(Const V: TValue; Var Indices, Shape: TIntArray);
Var
 Starts,Steps,Counts: TIntArray;
 I,J,K,L,H,Step,N,C,Flat,Stride,D: LongInt;
 SingleIndex: Boolean;
 T: TValue;
Begin
 SetLength(Starts,Length(V.Dims)); SetLength(Steps,Length(V.Dims));
 SetLength(Counts,Length(V.Dims));
 Shape:=Nil; Expect('(');
 For I:=0 To High(V.Dims) Do Begin
  D:=V.Dims[I]; L:=0; H:=Dims[D].Size-1; Step:=1; SingleIndex:=False;
  If P.Token<>':' Then Begin
   T:=Expression(0); L:=IntegerScalar(T); If FortranIndex Then Dec(L); SingleIndex:=True
  End;
  If P.Token=':' Then Begin
   Next; SingleIndex:=False;
   If (P.Token<>',') And (P.Token<>')') And (P.Token<>':') Then Begin
    H:=IntegerScalar(Expression(0)); If FortranIndex Then Dec(H)
   End;
   If P.Token=':' Then Begin
    Next; Step:=IntegerScalar(Expression(0))
   End;
  End Else H:=L;
  If (Step<=0) Or (L<0) Or (H<L) Or (H>=Dims[D].Size) Then ReportError(
  'Tranche hors limites');
  Starts[I]:=L; Steps[I]:=Step; Counts[I]:=(H-L) Div Step+1;
  If Not SingleIndex Then Begin
   If (L<>0) Or (Step<>1) Or (Counts[I]<>Dims[D].Size) Then Begin
    D:=Length(Dims); SetLength(Dims,D+1); Dims[D].Name:='_slice_'+IntToStr(D);
    Dims[D].Size:=Counts[I];
   End;
   J:=Length(Shape); SetLength(Shape,J+1); Shape[J]:=D;
  End;
  If I<High(V.Dims) Then Expect(',');
 End;
 Expect(')'); N:=1;
 For I:=0 To High(Counts) Do N:=N*Counts[I]; SetLength(Indices,N);
 For I:=0 To N-1 Do Begin
  Flat:=I; Stride:=1; K:=0;
  For J:=High(Counts) Downto 0 Do Begin
   C:=Flat Mod Counts[J]; Flat:=Flat Div Counts[J];
   Inc(K,(Starts[J]+C*Steps[J])*Stride); Stride:=Stride*Dims[V.Dims[J]].Size
  End;
  Indices[I]:=K;
 End;
End;

Function Primary: TValue;
Var
 Name,S: String;
 I,J: LongInt;
 X: Double;
 Code: LongInt;
 Args: Array Of TValue;
 Index,Shape: TIntArray;
 V,T: TValue;
Begin
 Result:=Default(TValue);
 If P.TokenKind='n' Then Begin
  Val(P.Token,X,Code); If Code<>0 Then ReportError('Nombre invalide'); Result:=Scalar(X);
  Next
 End
 Else If P.TokenKind='s' Then Begin
  Result.IsText:=True; Result.Text:=P.Token; Next
 End
 Else If P.Token='(' Then Begin
  Next; Result:=Expression(0); Expect(')')
 End
 Else If P.Token='$' Then Begin
  Next; Name:=Identifier; I:=FindDim(Name);
  If I<0 Then ReportError('Dimension inconnue: '+Name); Result:=Scalar(I)
 End
 Else If P.Token='@' Then Begin
  Next; Result:=GetAttribute(GlobalAttrs,Identifier)
 End
 Else If P.Token='{' Then Begin
  Next; If P.Token='}' Then ReportError('Liste vide');
  Repeat
  T:=Expression(0); J:=Length(Result.Data); SetLength(Result.Data,J+1);
  Result.Data[J]:=NumericScalar(T);
  If P.Token<>',' Then Break; Next;
  Until False; Expect('}');
  I:=Length(Dims); SetLength(Dims,I+1); Dims[I].Name:='_list_'+IntToStr(I);
  Dims[I].Size:=Length(Result.Data);
  SetLength(Result.Dims,1); Result.Dims[0]:=I;
 End
 Else If P.TokenKind='i' Then Begin
  Name:=Identifier; I:=FindVar(Name);
  If (P.Token='(') And (I<0) Then Begin
   Next; Args:=Nil;
   If P.Token<>')' Then Repeat
   J:=Length(Args); SetLength(Args,J+1); Args[J]:=Expression(0);
   If P.Token<>',' Then Break; Next;
   Until False;
   Expect(')'); Result:=ApplyFunction(Name,Args);
  End Else
  Begin
   If I<0 Then Begin
    S:=LowerCase(Name);
    If (S='pi') Or (S='m_pi') Then Result:=Scalar(Pi) Else
    If S='e' Then Result:=Scalar(Exp(1)) Else
    If S='true' Then Result:=Scalar(1) Else If S='false' Then Result:=Scalar(0)
                Else ReportError('Variable inconnue: '+Name);
   End Else If P.Token='@' Then Begin
    Next; Result:=GetAttribute(Vars[I].Attrs,Identifier)
   End
    Else
   Begin
    Result:=CopyValue(Vars[I].Value);
    If P.Token='(' Then Begin
     V:=Result; ParseSelection(V,Index,Shape); Result.Dims:=Shape;
     SetLength(Result.Data,Length(Index));
     For J:=0 To High(Index) Do Result.Data[J]:=V.Data[Index[J]];
    End;
   End;
  End;
 End Else ReportError('Expression attendue, trouve "'+P.Token+'"');
 While P.Token='.' Do Begin
  Next; Name:=Identifier; Expect('('); Args:=Nil; SetLength(Args,1); Args[0]:=Result;
  If P.Token<>')' Then Repeat
  J:=Length(Args); SetLength(Args,J+1); Args[J]:=Expression(0);
  If P.Token<>',' Then Break; Next;
  Until False;
  Expect(')'); Result:=ApplyFunction(Name,Args);
 End;
End;

Function Precedence(Const Op: String): LongInt;Begin
 Result:=-1;
 If Op='||' Then Result:=1 Else If Op='&&' Then Result:=2 Else
 If (Op='==') Or (Op='!=') Then Result:=3 Else
 If (Op='<') Or (Op='>') Or (Op='<=') Or (Op='>=') Then Result:=4 Else
 If (Op='+') Or (Op='-') Then Result:=5 Else
 If (Op='*') Or (Op='/') Or (Op='%') Then Result:=6 Else
 If Op='^' Then Result:=8;
End;

Function Expression(MinPrec: LongInt): TValue;
Var
 Op: String;
 Prec,I: LongInt;
 R: TValue;
Begin
 If (P.Token='+') Or (P.Token='-') Or (P.Token='!') Then Begin
  Op:=P.Token; Next; Result:=Expression(7);
  If Result.IsText Then ReportError('Operateur unaire numerique attendu');
  For I:=0 To High(Result.Data) Do If Op='-' Then Result.Data[I]:=-Result.Data[I] Else
  If Op='!' Then Result.Data[I]:=Ord(Result.Data[I]=0);
 End Else Result:=Primary;
 Repeat
 Prec:=Precedence(P.Token); If Prec<MinPrec Then Break;
 Op:=P.Token; Next;
 If Op='^' Then R:=Expression(Prec) Else R:=Expression(Prec+1);
 Result:=Combine(Result,R,Op);
 Until False;
End;

Procedure AssignVariable(Const Name: String; Const Shape: TIntArray;
                         ExplicitShape: Boolean;  Const Index: TIntArray; Sliced: Boolean;
                         Const Op: String; Const Source: TValue);
Var
 I,J,K,L: LongInt;
 V,T,Before: TValue;
 Found: Boolean;
Begin
 I:=FindVar(Name);
 Before:=Default(TValue);
 If I>=0 Then Before:=Vars[I].Value;
 If Sliced Then Begin
  If I<0 Then ReportError('Variable inconnue: '+Name);
  V:=CopyValue(Vars[I].Value);
  If Source.IsText Or ((Length(Source.Data)<>1) And (Length(Source.Data)<>Length(Index)))
  Then ReportError('Taille de tranche incompatible');
  For J:=0 To High(Index) Do Begin
   K:=J; If Length(Source.Data)=1 Then K:=0;
   If Op='=' Then V.Data[Index[J]]:=Source.Data[K]
    Else
   Begin
    T:=Combine(Scalar(V.Data[Index[J]]),Scalar(Source.Data[K]),Copy(Op,1,1));
    V.Data[Index[J]]:=T.Data[0]
   End;
  End;
 End Else
 Begin
  V:=CopyValue(Source);
  If V.IsText Then Begin
   SetLength(V.Data,Length(V.Text));
   For J:=1 To Length(V.Text) Do V.Data[J-1]:=Ord(V.Text[J]);
   If Not ExplicitShape Then ReportError(
   'Affectation texte: fournir une dimension explicite'); V.IsText:=False
  End;
  If ExplicitShape Then Begin
   K:=Product(Shape);
   If Length(V.Data)=1 Then Begin
    SetLength(V.Data,K);
    For J:=1 To K-1 Do V.Data[J]:=V.Data[0]
   End
   Else If Length(V.Data)<>K Then ReportError('Dimensions incompatibles dans '+Name);
   V.Dims:=Copy(Shape);
  End Else If (I>=0) And (Length(V.Dims)=0) And (Length(Before.Dims)>0) Then Begin
   T:=V; V.Dims:=Copy(Before.Dims); SetLength(V.Data,Length(Before.Data));
   For J:=0 To High(V.Data) Do V.Data[J]:=T.Data[0];
  End;
  If Op<>'=' Then Begin
   If I<0 Then ReportError('Variable inconnue: '+Name);
   V:=Combine(Vars[I].Value,V,Copy(Op,1,1));
  End;
 End;
 If Masked Then Begin
  If ActiveMask.IsText Then ReportError('Masque numerique attendu');
  If Not Sliced And (Length(V.Dims)=0) And (Length(ActiveMask.Dims)>0) Then Begin
   T:=V; V:=Combine(Scalar(0),ActiveMask,'*');
   For J:=0 To High(V.Data) Do V.Data[J]:=T.Data[0];
  End;
  For J:=0 To High(ActiveMask.Dims) Do Begin
   Found:=False;
   For K:=0 To High(V.Dims) Do If V.Dims[K]=ActiveMask.Dims[J] Then Found:=True;
   If Not Found Then ReportError('Le masque where contient une dimension absente de '+
   Name);
  End;
  If I>=0 Then Begin
   For J:=0 To High(Before.Dims) Do Begin
    Found:=False;
    For K:=0 To High(V.Dims) Do If V.Dims[K]=Before.Dims[J] Then Found:=True;
    If Not Found Then ReportError('where ne peut pas supprimer une dimension existante');
   End;
  End;
  For J:=0 To High(V.Data) Do Begin
   L:=BroadcastIndex(ActiveMask.Dims,V.Dims,J);
   If ActiveMask.Data[L]=0 Then Begin
    If I>=0 Then V.Data[J]:=Before.Data[BroadcastIndex(Before.Dims,V.Dims,J)]
            Else V.Data[J]:=0;
   End;
  End;
 End;
 If I<0 Then Begin
  I:=Length(Vars); SetLength(Vars,I+1); Vars[I].Name:=Name; Vars[I].Kind:=V.NumericKind;
  If Not (Vars[I].Kind In [1,2,3,4,5,6]) Then Vars[I].Kind:=6;
 End;
 Vars[I].Value:=V; Vars[I].Changed:=True;
End;
Procedure Statement(Execute: Boolean);Forward;

Procedure SkipStatement;
Var
 Depth: LongInt;
 Control: String;
Begin
 If (P.TokenKind='i') And ((P.Token='if') Or (P.Token='while') Or
 (P.Token='for') Or (P.Token='where')) Then Begin
  Control:=P.Token; Next; Expect('('); Depth:=1;
  While Depth>0 Do Begin
   If P.TokenKind=#0 Then ReportError('Condition non terminee');
   If P.TokenKind='p' Then Begin
    If P.Token='(' Then Inc(Depth) Else If P.Token=')' Then Dec(Depth);
   End;
   Next;
  End;
  SkipStatement;
  If ((Control='if') And (P.Token='else')) Or ((Control='where') And (P.Token='elsewhere')
  ) Then Begin
   Next; SkipStatement
  End;
  Exit;
 End;
 If P.Token='{' Then Begin
  Depth:=1; Next;
  While Depth>0 Do Begin
   If P.TokenKind=#0 Then ReportError('Bloc non termine');
   If P.TokenKind='p' Then Begin
    If P.Token='{' Then Inc(Depth) Else If P.Token='}' Then Dec(Depth);
   End; Next;
  End;
 End Else
 Begin
  Depth:=0;
  Repeat
  If P.TokenKind=#0 Then ReportError('Instruction non terminee');
  If P.TokenKind='p' Then Begin
   If (P.Token=';') And (Depth=0) Then Begin
    Next; Break
   End;
   If (P.Token='(') Or (P.Token='{') Then Inc(Depth);
   If (P.Token=')') Or (P.Token='}') Then Dec(Depth);
  End; Next;
  Until False;
 End;
End;

Procedure RunFragment(Const Fragment: String);
Var
 SavedScript: String;
 SavedState: TParserState;
Begin
 SavedScript:=Script; SavedState:=P;
 Begin
  Script:=Fragment; P:=Default(TParserState); P.Pos:=1; Next;
  While P.TokenKind<>#0 Do Statement(True);
 End; Script:=SavedScript; P:=SavedState;
End;

Procedure Statement(Execute: Boolean);
Var
 Name,Attr,Op,UpdateText: String;
 I,J,N,Depth,BeginUpdate: LongInt;
 V,OldMask,ConditionMask: TValue;
 Shape,Index,Dummy: TIntArray;
 ExplicitShape,Sliced,Condition,OldMasked: Boolean;
 CondState,BodyState,AfterState: TParserState;
Begin
 If Not Execute Then Begin
  SkipStatement; Exit
 End;
 Inc(Iterations);
 If Iterations>MaxIterations Then ReportError('Limite d''execution depassee');
 If P.Token=';' Then Begin
  Next; Exit
 End;
 If P.Token='{' Then Begin
  Next;
  While P.Token<>'}' Do Begin
   If P.TokenKind=#0 Then ReportError('Bloc non termine'); Statement(True)
  End;
  Next; Exit;
 End;
 If P.Token='if' Then Begin
  Next; Expect('('); Condition:=NumericScalar(Expression(0))<>0; Expect(')');
  Statement(Condition);
  If P.Token='else' Then Begin
   Next; Statement(Not Condition)
  End;
  Exit;
 End;
 If P.Token='where' Then Begin
  Next; Expect('('); ConditionMask:=Expression(0); Expect(')');
  If ConditionMask.IsText Then ReportError('where attend un masque numerique');
  For I:=0 To High(ConditionMask.Data) Do ConditionMask.Data[I]:=Ord(
  ConditionMask.Data[I]<>0);
  OldMask:=ActiveMask; OldMasked:=Masked;
  Begin
   Masked:=True; ActiveMask:=ConditionMask;
   If OldMasked Then ActiveMask:=Combine(OldMask,ConditionMask,'&&');
   Statement(True);
   If P.Token='elsewhere' Then Begin
    Next;
    For I:=0 To High(ConditionMask.Data) Do ConditionMask.Data[I]:=Ord(
    ConditionMask.Data[I]=0);
    ActiveMask:=ConditionMask;
    If OldMasked Then ActiveMask:=Combine(OldMask,ConditionMask,'&&');
    Statement(True);
   End;
  End; ActiveMask:=OldMask; Masked:=OldMasked;
  Exit;
 End;
 If P.Token='for' Then Begin
  Next; Expect('('); Statement(True); CondState:=P;
    { Locate the update and body without evaluating their expressions. }
  Depth:=0;
  While Not ((P.Token=';') And (Depth=0)) Do Begin
   If P.TokenKind=#0 Then ReportError('Boucle for non terminee');
   If P.TokenKind='p' Then Begin
    If P.Token='(' Then Inc(Depth) Else If P.Token=')' Then Dec(Depth);
   End; Next;
  End;
  Next; BeginUpdate:=P.Start; Depth:=0;
  While Not ((P.Token=')') And (Depth=0)) Do Begin
   If P.TokenKind=#0 Then ReportError('Boucle for non terminee');
   If P.TokenKind='p' Then Begin
    If P.Token='(' Then Inc(Depth) Else If P.Token=')' Then Dec(Depth);
   End; Next;
  End;
  UpdateText:=Copy(Script,BeginUpdate,P.Start-BeginUpdate)+';'; Next; BodyState:=P;
  Repeat
  P:=CondState;
  If P.Token=';' Then Condition:=True Else Condition:=NumericScalar(Expression(0))<>0;
  Expect(';'); P:=BodyState; Statement(Condition); AfterState:=P;
  If Not Condition Then Break;
  RunFragment(UpdateText);
  Until False;
  P:=AfterState; Exit;
 End;
 If P.Token='while' Then Begin
  Next; Expect('('); CondState:=P;
  Repeat
  P:=CondState; Condition:=NumericScalar(Expression(0))<>0; Expect(')');
  Statement(Condition); AfterState:=P;
  If Not Condition Then Break;
  Until False;
  P:=AfterState; Exit;
 End;
 If P.Token='defdim' Then Begin
  If Masked Then ReportError('defdim interdit dans where');
  Next; Expect('(');
  If P.TokenKind<>'s' Then ReportError('Nom de dimension entre guillemets attendu');
  Name:=P.Token; Next; Expect(','); N:=IntegerScalar(Expression(0));
  If (N<=0) Or (N>MaxElements) Then ReportError('Taille de dimension invalide');
  I:=FindDim(Name); If I>=0 Then ReportError('Dimension deja definie: '+Name);
  I:=Length(Dims); SetLength(Dims,I+1); Dims[I].Name:=Name; Dims[I].Size:=N;
  If P.Token=',' Then Begin
   Next; Dims[I].Unlimited:=IntegerScalar(Expression(0))<>0
  End;
  Expect(')'); Expect(';'); Exit;
 End;
 If P.Token='print' Then Begin
  Next; Expect('('); V:=Expression(0); Expect(')'); Expect(';');
  If V.IsText Then WriteLn(V.Text) Else
  Begin
   For I:=0 To High(V.Data) Do Begin
    If I>0 Then Write(' '); Write(FloatToStr(V.Data[I]))
   End; WriteLn;
  End; Exit;
 End;
 Name:=''; Attr:=''; Shape:=Nil; Index:=Nil; ExplicitShape:=False; Sliced:=False;
 If P.Token='@' Then Begin
  Next; Attr:=Identifier
 End
  Else
 Begin
  Name:=Identifier;
  If P.Token='@' Then Begin
   Next; Attr:=Identifier
  End
  Else If P.Token='[' Then Begin
   Next; ExplicitShape:=True;
   Repeat
   If P.Token='$' Then Next; I:=FindDim(Identifier);
   If I<0 Then ReportError('Dimension inconnue'); J:=Length(Shape); SetLength(Shape,J+1);
   Shape[J]:=I;
   If P.Token<>',' Then Break; Next;
   Until False;
   Expect(']');
  End Else If P.Token='(' Then Begin
   I:=FindVar(Name); If I<0 Then ReportError('Variable inconnue: '+Name);
   ParseSelection(Vars[I].Value,Index,Dummy); Sliced:=True;
  End;
 End;
 Op:=P.Token;
 If (Op='++') Or (Op='--') Then Begin
  Next; If Op='++' Then Op:='+=' Else Op:='-='; V:=Scalar(1)
 End
  Else
 Begin
  If (Op<>'=') And (Op<>'+=' ) And (Op<>'-=') And (Op<>'*=') And (Op<>'/=')
  Then ReportError('Affectation attendue');
  Next; V:=Expression(0);
 End;
 Expect(';');
 If Attr<>'' Then Begin
  If Masked Then ReportError('Affectation d''attribut interdite dans where');
  If Op<>'=' Then ReportError('Un attribut accepte seulement =');
  If Name='' Then SetAttribute(GlobalAttrs,Attr,V)
   Else
  Begin
   I:=FindVar(Name); If I<0 Then ReportError('Variable inconnue: '+Name);
   SetAttribute(Vars[I].Attrs,Attr,V); Vars[I].Changed:=True
  End;
 End Else AssignVariable(Name,Shape,ExplicitShape,Index,Sliced,Op,V);
End;

Procedure RunScript;Begin
 P:=Default(TParserState); P.Pos:=1; Iterations:=0;
 ScriptRunning:=True;
 Next;
 While P.TokenKind<>#0 Do Statement(True);
 ScriptRunning:=False;
End;

Function Selected(I: LongInt): Boolean;
Var
 J,K: LongInt;
Begin
 Result:=Not OnlyChanged Or Vars[I].Changed Or Vars[I].Keep;
 If Result Or Not Coordinates Then Exit;
 K:=FindDim(Vars[I].Name);
 If (K<0) Or (Length(Vars[I].Value.Dims)<>1) Or (Vars[I].Value.Dims[0]<>K) Then Exit;
 For J:=0 To High(Vars) Do If Vars[J].Changed Then    If Length(Vars[J].Value.Dims)>
 0 Then Begin
  For K:=0 To High(Vars[J].Value.Dims) Do If Vars[J].Value.Dims[K]=
  Vars[I].Value.Dims[0] Then Exit(True);
 End;
End;

Procedure WriteHeader(Var F: TStream; Const Chosen: TIntArray; Version: LongInt;
                      NumRecords: LongInt);
Var
 I,J,K: LongInt;
Begin
 WriteUInt(F,$434446,3); WriteUInt(F,Version,1); WriteUInt(F,NumRecords,4);
 If Length(Dims)=0 Then WriteUInt(F,0,4) Else WriteUInt(F,10,4);
 WriteUInt(F,Length(Dims),4);
 For I:=0 To High(Dims) Do Begin
  WriteName(F,Dims[I].Name);
  If Dims[I].Unlimited Then WriteUInt(F,0,4) Else WriteUInt(F,Dims[I].Size,4)
 End;
 WriteAttrs(F,GlobalAttrs);
 If Length(Chosen)=0 Then WriteUInt(F,0,4) Else WriteUInt(F,11,4);
 WriteUInt(F,Length(Chosen),4);
 For J:=0 To High(Chosen) Do Begin
  K:=Chosen[J]; WriteName(F,Vars[K].Name); WriteUInt(F,Length(Vars[K].Value.Dims),4);
  For I:=0 To High(Vars[K].Value.Dims) Do WriteUInt(F,Vars[K].Value.Dims[I],4);
  WriteAttrs(F,Vars[K].Attrs); WriteUInt(F,Vars[K].Kind,4);
  WriteUInt(F,Vars[K].DiskSize,4);
  If Version=2 Then WriteUInt(F,Vars[K].Offset,8) Else WriteUInt(F,Vars[K].Offset,4);
 End;
End;

Procedure SaveNetCDF(Const Name: String);
Var
 F: TStream;
 M: TStream;
 Chosen: TIntArray;
 I,J,K,R,N,NumRecords,UnlimitedId,RecordVars: LongInt;
 Posn,RecSize,Base,Bytes,Count,RecordStart: Int64;
 TempName,BackupName: String;
 IsRecord: Boolean;
Begin
 If FileExists(Name) And Not (Overwrite Or AppendMode) Then ReportError(
 'La sortie existe deja; utiliser -O ou -A');
 UnlimitedId:=-1; NumRecords:=0; RecordVars:=0;
 For I:=0 To High(Dims) Do If Dims[I].Unlimited Then Begin
  If UnlimitedId>=0 Then ReportError(
  'Une seule dimension illimitee est permise en NetCDF classique');
  UnlimitedId:=I; NumRecords:=Dims[I].Size;
 End;
 Chosen:=Nil;
 For I:=0 To High(Vars) Do If Selected(I) Then Begin
  N:=Length(Chosen); SetLength(Chosen,N+1); Chosen[N]:=I;
  For J:=0 To High(Vars[I].Value.Dims) Do      If (Vars[I].Value.Dims[J]=UnlimitedId)
  And (J<>0) Then ReportError('La dimension illimitee doit etre la premiere');
  Bytes:=Int64(Length(Vars[I].Value.Data))*TypeSize(Vars[I].Kind);
  If (Length(Vars[I].Value.Dims)>0) And (Vars[I].Value.Dims[0]=UnlimitedId) Then Begin
   Inc(RecordVars); Bytes:=TypeSize(Vars[I].Kind);
   For J:=1 To High(Vars[I].Value.Dims) Do Bytes:=Bytes*Dims[Vars[I].Value.Dims[J]].Size;
  End;
  Vars[I].DiskSize:=((Bytes+3) Div 4)*4;
 End;
 StreamInit(M);
 Begin
  WriteHeader(M,Chosen,FormatVersion,NumRecords);
  Posn:=((StreamSize(M)+HeaderPad+3) Div 4)*4
 End; StreamClose(M);
 For J:=0 To High(Chosen) Do Begin
  I:=Chosen[J];
  If (Length(Vars[I].Value.Dims)=0) Or (Vars[I].Value.Dims[0]<>UnlimitedId) Then Begin
   Vars[I].Offset:=Posn; Inc(Posn,Vars[I].DiskSize);
  End;
 End;
 RecSize:=0; RecordStart:=Posn;
 For J:=0 To High(Chosen) Do Begin
  I:=Chosen[J];
  If (Length(Vars[I].Value.Dims)>0) And (Vars[I].Value.Dims[0]=UnlimitedId) Then Begin
   Vars[I].Offset:=RecordStart+RecSize;
   If RecordVars=1 Then Begin
    Bytes:=TypeSize(Vars[I].Kind);
    For K:=1 To High(Vars[I].Value.Dims) Do Bytes:=Bytes*Dims[Vars[I].Value.Dims[K]].Size;
    RecSize:=Bytes;
   End Else Inc(RecSize,Vars[I].DiskSize);
  End;
 End;
 If (FormatVersion=1) And (RecordStart+RecSize*NumRecords>High(LongInt)) Then ReportError(
 'Sortie trop grande pour cette implementation CDF-1; utiliser -6');
 TempName:=Name;
 If Not NoTemp Then Begin
  TempName:=GetTempFileName(ExtractFilePath(ExpandFileName(Name)),'.nc');
  PendingOutput:=TempName;
 End;
 Begin
  StreamOpen(F,TempName,fmCreate);
  Begin
   WriteHeader(F,Chosen,FormatVersion,NumRecords);
   StreamResize(F,RecordStart+RecSize*NumRecords);
   For J:=0 To High(Chosen) Do Begin
    I:=Chosen[J];
    IsRecord:=(Length(Vars[I].Value.Dims)>0) And (Vars[I].Value.Dims[0]=UnlimitedId);
    Count:=Length(Vars[I].Value.Data); If IsRecord Then Begin
     Count:=1;
     For K:=1 To High(Vars[I].Value.Dims) Do Count:=Count*
     Dims[Vars[I].Value.Dims[K]].Size;
    End;
    N:=1; If IsRecord Then N:=NumRecords;
    For R:=0 To N-1 Do Begin
     Base:=Vars[I].Offset; If IsRecord Then Inc(Base,R*RecSize);
     StreamSeek(F,Base);
     For K:=0 To Count-1 Do WriteNumber(F,Vars[I].Kind,Vars[I].Value.Data[R*Count+K]);
     If Not IsRecord Or (RecordVars<>1) Then WritePadding(F,Count*TypeSize(Vars[I].Kind));
    End;
   End;
  End; StreamClose(F);
  If Not NoTemp Then Begin
   {$IFDEF MSWINDOWS}
      { Windows rename cannot replace an existing file. Preserve it as a backup
        until the new complete file is installed. }
    If FileExists(Name) Then Begin
     BackupName:=GetTempFileName(ExtractFilePath(ExpandFileName(Name)),'.bak');
     If FileExists(BackupName) And Not DeleteFile(BackupName) Then ReportError(
     'Impossible de preparer la sauvegarde');
     If Not RenameFile(Name,BackupName) Then ReportError(
     'Impossible de sauvegarder la sortie existante');
     If Not RenameFile(TempName,Name) Then Begin
      If Not RenameFile(BackupName,Name) Then ReportError(
      'Echec installation; original conserve dans '+BackupName);
      ReportError('Impossible d''installer la sortie');
     End;
     If Not DeleteFile(BackupName) Then WriteLn(StdErr,'NCAP2: sauvegarde conservee: ',
     BackupName);
    End Else If Not RenameFile(TempName,Name) Then ReportError(
    'Impossible d''installer la sortie');
   {$ELSE}
    If Not RenameFile(TempName,Name) Then ReportError('Impossible d''installer la sortie')
    ;
   {$ENDIF}
  End;
 End; PendingOutput:='';
End;

Procedure Help;Begin
 WriteLn('NCAP2 - processeur arithmetique NetCDF autonome (Free Pascal)');
 WriteLn('Usage: NCAP2 [options] [entree.nc] sortie.nc');
 WriteLn('  -s, --script TEXTE     script en ligne (repetable)');
 WriteLn('  -S, --script-file NOM  fichier de script (repetable)');
 WriteLn('  -o NOM  -O ecraser  -A fusionner la sortie existante');
 WriteLn('  -3 CDF-1  -6 CDF-2  --fl_fmt=classic|64bit_offset');
 WriteLn('  -v variables affectees seulement; -C sans coordonnees; -c avec');
 WriteLn('  -F indices a partir de 1; -h sans historique; -H sans effet');
 WriteLn('  -p chemin entree; -D niveau; -t 1; --hdr_pad octets');
 WriteLn('  --gaa nom=valeur; --gad nom[,nom]; --no_tmp_fl; --ram_all');
 WriteLn('  -r, --version version; --help aide');
 WriteLn('Langage: defdim("x",10); x[$x]=array(0,1,$x); y=x*2;');
 WriteLn('  tableaux {1,2,3}, tranches y(0:4:2), attributs y@units="K";');
 WriteLn('  + - * / % ^, comparaisons, && || !, += -= *= /= ++ --');
 WriteLn('  if (scalaire) {...} else {...}, while (scalaire) {...}, print(x);');
 WriteLn('  for(i=0;i<10;i++){...}, where(masque){...} elsewhere {...}');
 WriteLn('  abs sqrt sqr exp log ln log10 sin cos tan asin acos atan atan2');
 WriteLn('  sinh cosh tanh floor ceil round pow isnan isfinite');
 WriteLn('  sum total avg mean min max rms size: globales ou par dimensions');
 WriteLn('  ex. avg(a,$x), a.avg($x); byte short int long float double');
 WriteLn('Limites: 16000000 elements/tableau, 1000000 instructions/script.');
 WriteLn('  Calculs en double; types existants conserves, casts pour nouveaux types.');
 WriteLn('  Broadcasting par noms de dimensions; bornes de tranches inclusives.');
 WriteLn('  Pas de traitement automatique de _FillValue, scale_factor/add_offset.');
 WriteLn('  where: expressions evaluees integralement, nouvelles cases hors masque a 0.');
 WriteLn('  Pas de groupes, reseau, threads,');
 WriteLn('  HDF4/HDF5/CDF-5, compression, syntaxe Fortran -f ni Turbo Pascal 16 bits.');
 WriteLn('  Les options non prises en charge sont refusees.');
End;

Function ReadText(Const Name: String): String;
Var
 F: TStream;
Begin
 StreamOpen(F,Name,fmOpenRead);
 If StreamSize(F)>High(SizeInt) Then ReportError('Fichier texte trop grand');
 SetLength(Result,StreamSize(F));
 If Length(Result)>0 Then ReadExact(F,Result[1],Length(Result));
 StreamClose(F);
End;

Function OptionValue(Var I: LongInt; Const InlineValue: String;
                     HasInline: Boolean): String;Begin
 If HasInline Then Result:=InlineValue Else
 Begin
  Inc(I); If I>ParamCount Then ReportError('Valeur d''option manquante');
  Result:=ParamStr(I);
 End;
End;

Procedure ParseOptions;
Var
 I,J,N: LongInt;
 A,Opt,InlineValue,V: String;
 HasInline,EndOptions: Boolean;
 Files: TTextList;
Begin
 Files.Entries:=Nil;
 Begin
  I:=1; EndOptions:=False;
  While I<=ParamCount Do Begin
   A:=ParamStr(I); Opt:=A; InlineValue:=''; HasInline:=False;
   If A='--' Then Begin
    EndOptions:=True; Inc(I); Continue
   End;
   If Not EndOptions And (Length(A)>0) And (A[1]='-') Then Begin
    If Copy(A,1,2)='--' Then Begin
     J:=Pos('=',A); If J>0 Then Begin
      Opt:=Copy(A,1,J-1); InlineValue:=Copy(A,J+1,MaxInt); HasInline:=True
     End;
    End Else If (Length(A)>2) And (A[2] In ['s','S','o','p','l','D','L','t']) Then Begin
     Opt:=Copy(A,1,2); InlineValue:=Copy(A,3,MaxInt); HasInline:=True;
    End;
    If (Opt='--help') Or (Opt='-?') Then Begin
     Help; Halt(0)
    End
    Else If (Opt='-r') Or (Opt='--version') Then VersionOnly:=True Else
    If (Opt='-s') Or (Opt='--script') Or (Opt='--spt') Then Script:=Script+
    OptionValue(I,InlineValue,HasInline)+#10
    Else If (Opt='-S') Or (Opt='--script-file') Or (Opt='--fl_spt') Or (Opt=
    '--nco_script') Then Script:=Script+ReadText(OptionValue(I,InlineValue,HasInline))+#10 Else
    If (Opt='-o') Or (Opt='--output') Then OutputName:=OptionValue(I,InlineValue,
    HasInline)
    Else If Opt='-p' Then InputPath:=OptionValue(I,InlineValue,HasInline) Else
    If Opt='-l' Then Begin
     LocalPath:=OptionValue(I,InlineValue,HasInline);
     ReportError('-l: recuperation distante non implementee')
    End
    Else If Opt='-O' Then Overwrite:=True Else If Opt='-A' Then AppendMode:=True Else
    If Opt='-v' Then OnlyChanged:=True Else If Opt='-C' Then Coordinates:=False Else
    If Opt='-c' Then Coordinates:=True Else If Opt='-F' Then FortranIndex:=True Else
    If Opt='-h' Then History:=False Else If Opt='-H' Then Begin
    End
    Else If Opt='-3' Then FormatName:='classic' Else If Opt='-6' Then FormatName:=
    '64bit_offset'
    Else If (Opt='--fl_fmt') Then FormatName:=OptionValue(I,InlineValue,HasInline) Else
    If Opt='--no_tmp_fl' Then NoTemp:=True Else If Opt='--ram_all' Then Begin
    End
    Else If Opt='--gaa' Then ListAdd(AddAttrs,OptionValue(I,InlineValue,HasInline)) Else
    If Opt='--gad' Then ListAdd(DeleteAttrs,OptionValue(I,InlineValue,HasInline)) Else
    If Opt='--hdr_pad' Then Begin
     V:=OptionValue(I,InlineValue,HasInline);
     If Not TryStrToInt64(V,HeaderPad) Or (HeaderPad<0) Or (HeaderPad>1073741824)
     Then ReportError('--hdr_pad: taille invalide');
    End Else If (Opt='-D') Or (Opt='-t') Or (Opt='-L') Then Begin
     V:=OptionValue(I,InlineValue,HasInline);
     If Not TryStrToInt(V,N) Then ReportError(Opt+': entier attendu');
     If Opt='-D' Then Begin
      If N<0 Then ReportError('-D: niveau negatif'); DebugLevel:=N
     End
     Else If Opt='-t' Then Begin
      If N<>1 Then ReportError('Seul -t 1 est pris en charge')
     End
     Else If N<>0 Then ReportError('Compression non disponible en CDF-1/CDF-2');
    End Else ReportError('Option inconnue ou non implementee: '+Opt);
   End Else ListAdd(Files,A);
   Inc(I);
  End;
  If VersionOnly Then Begin
   WriteLn('NCAP2.PAS 1.0 - implementation independante CDF-1/CDF-2, Free Pascal');
   Halt(0)
  End;
  If OutputName<>'' Then Begin
   If Length(Files.Entries)>1 Then ReportError('Avec -o, une seule entree est permise');
   If Length(Files.Entries)=1 Then InputName:=Files.Entries[0];
  End Else
  Begin
   If (Length(Files.Entries)<1) Or (Length(Files.Entries)>2) Then ReportError(
   'Indiquer [entree] sortie (voir --help)');
   OutputName:=Files.Entries[Length(Files.Entries)-1];
   If Length(Files.Entries)=2 Then InputName:=Files.Entries[0];
  End;
  If (InputPath<>'') And (InputName<>'') Then InputName:=IncludeTrailingPathDelimiter(
  InputPath)+InputName;
  If (InputName<>'') And (Pos('://',InputName)>0) Then ReportError(
  'Entrees reseau non implementees');
  If (InputName<>'') And SameFileName(ExpandFileName(InputName),ExpandFileName(OutputName)
  ) And NoTemp Then ReportError('--no_tmp_fl interdit avec entree=sortie');
 End; Files.Entries:=Nil;
End;

Procedure UpdateGlobalAttrs;
Var
 I,J,K,N: LongInt;
 S,Name: String;
 V,Old: TValue;
Begin
 For I:=0 To Length(DeleteAttrs.Entries)-1 Do Begin
  S:=DeleteAttrs.Entries[I]+',';
  Repeat J:=Pos(',',S); If J=0 Then Break; Name:=Copy(S,1,J-1); Delete(S,1,J);
  K:=FindAttr(GlobalAttrs,Name); If K>=0 Then Begin
   For N:=K To High(GlobalAttrs)-1 Do GlobalAttrs[N]:=GlobalAttrs[N+1];
   SetLength(GlobalAttrs,Length(GlobalAttrs)-1);
  End;
  Until S='';
 End;
 For I:=0 To Length(AddAttrs.Entries)-1 Do Begin
  S:=AddAttrs.Entries[I]; J:=Pos('=',S);
  If J<2 Then ReportError('--gaa attend nom=valeur');
  V:=Default(TValue); V.IsText:=True; V.Text:=Copy(S,J+1,MaxInt);
  SetAttribute(GlobalAttrs,Copy(S,1,J-1),V);
 End;
 If History Then Begin
  V:=Default(TValue); V.IsText:=True; V.Text:='NCAP2.PAS';
  For I:=1 To ParamCount Do V.Text:=V.Text+' '+ParamStr(I);
  If FindAttr(GlobalAttrs,'history')>=0 Then Begin
   Old:=GetAttribute(GlobalAttrs,'history');
   If Old.IsText Then V.Text:=V.Text+#10+Old.Text;
  End;
  SetAttribute(GlobalAttrs,'history',V);
 End;
End;

Procedure KeepExistingOutput;
Var
 I: LongInt;
Begin
 For I:=0 To High(Vars) Do Vars[I].Keep:=True
End;

BEGIN
 Randomize;
 Coordinates:=True; History:=True; FormatVersion:=1;
 AddAttrs.Entries:=Nil; DeleteAttrs.Entries:=Nil;
 If ParamCount=0 Then Begin
  Help; Halt(0)
 End;
 ParseOptions;
 If FileExists(OutputName) And Not (Overwrite Or AppendMode) Then ReportError(
 'La sortie existe deja; utiliser -O ou -A');
 If AppendMode And FileExists(OutputName) Then Begin
  LoadNetCDF(OutputName,False); KeepExistingOutput
 End;
 If InputName<>'' Then LoadNetCDF(InputName,AppendMode And FileExists(OutputName));
 If FormatName<>'' Then Begin
  If (FormatName='classic') Or (FormatName='netcdf3') Or (FormatName='1')
  Then FormatVersion:=1 Else
  If (FormatName='64bit_offset') Or (FormatName='64bit') Or (FormatName='2')
  Then FormatVersion:=2
  Else ReportError('Format non pris en charge: '+FormatName);
 End;
 If DebugLevel>0 Then WriteLn(StdErr,'NCAP2: ',Length(Dims),' dimensions, ',Length(Vars),
 ' variables');
 RunScript; UpdateGlobalAttrs; SaveNetCDF(OutputName);
 If DebugLevel>0 Then WriteLn(StdErr,'NCAP2: sortie ecrite: ',OutputName);
 AddAttrs.Entries:=Nil; DeleteAttrs.Entries:=Nil;
END.
