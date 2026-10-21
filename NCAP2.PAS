{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/meteopolis)
  @abstract(Target: Turbo Pascal 7, Free Pascal)
  Processeur NetCDF procedural, sans unite ni include.
  Compilation: TPC NCAP2.PAS ou FPC -Mtp NCAP2.PAS.
  Formats CDF-1/CDF-2; offsets et tailles limites a 2147483647 octets.
  Limites DOS: 4096 elements/tableau, 64 variables, 128 dimensions,
  128 attributs/objet, rang 8, script 60000 octets, noms 63 caracteres.
  HDF4/HDF5/CDF-5, compression et threads non implementes.
  Pas de traitement automatique de _FillValue, scale_factor/add_offset.
}
Program NCAP2;
{$IFDEF FPC}
 {$MODE TP}
{$ENDIF}
{$R+}{$Q+}
{$IFNDEF FPC}
 {$N+}{$E+}{$M 32768,0,655360}
{$ENDIF}
Const
 MaxElements=4096; MaxVars=64; MaxDims=128; MaxAttrs=128;
 MaxRank=8; MaxScript=60000; MaxRaw=32760; MaxIterations=1000000;
Type
 TName=String[63];
 TShape=Record Rank:Integer; ID:Array[0..MaxRank-1] Of Integer End;
 TNumbers=Array[0..MaxElements-1] Of Double;
 PNumbers=^TNumbers;
 TBytes=Array[0..MaxRaw-1] Of Byte;
 PBytes=^TBytes;
 TScript=Array[1..MaxScript] Of Char;
 PScript=^TScript;
 PValue=^TValue;
 TValue=Record
  Shape:TShape; Count:Integer; Data:PNumbers;
  IsText:Boolean; Text:String; Kind:Integer;
 End;
 PAttribute=^TAttribute;
 TAttribute=Record Name:TName; Kind:Integer; Count,Bytes:Word; Data:PBytes End;
 TAttributes=Record Count:Integer; Item:Array[0..MaxAttrs-1] Of PAttribute End;
 PAttributes=^TAttributes;
 TDimension=Record Name:TName; Size:LongInt; Unlimited:Boolean End;
 TDimensions=Record Count:Integer; Item:Array[0..MaxDims-1] Of TDimension End;
 PDimensions=^TDimensions;
 PVariable=^TVariable;
 TVariable=Record
  Name:TName; Kind:Integer; Value:PValue; Attrs:TAttributes;
  Offset,DiskSize:LongInt; Changed,Keep:Boolean;
 End;
 TVariables=Record Count:Integer; Item:Array[0..MaxVars-1] Of PVariable End;
 PVariables=^TVariables;
 PString=^String;
 TTextList=Record Count:Integer; Item:Array[0..MaxAttrs-1] Of PString End;
 PTextList=^TTextList;
 TParserState=Record Pos,Start:LongInt; Token:String; TokenKind:Char End;
 PParserState=^TParserState;
 PStream=^TStream;
 TStream=Record
  DiskFile:File; Opened,Counting:Boolean; Cursor:LongInt;
 End;
 TArgList=Array[0..15] Of PValue;
 TSelection=Array[0..MaxElements-1] Of Integer;
 PSelection=^TSelection;
 TByte8=Array[0..7] Of Byte;
 TIndexList=Array[0..MaxVars-1] Of Integer;
Var
 PathSep:Char;
 Dims:PDimensions; Vars:PVariables; GlobalAttrs:PAttributes;
 AddAttrs,DeleteAttrs:PTextList; P:PParserState;
 Script:PScript; ScriptLen:LongInt;
 InputName,OutputName,InputPath,FormatName,PendingOutput:String;
 Overwrite,AppendMode,OnlyChanged,Coordinates,History,FortranIndex:Boolean;
 NoTemp,ScriptRunning,Masked:Boolean;
 FormatVersion,DebugLevel:Integer; HeaderPad,Iterations:LongInt;
 ActiveMask:PValue;
 OpenStreams:Array[0..15] Of PStream;

Procedure ReleaseState; Forward;

Procedure ReportError(S:String);
Var I:Integer; J,L:LongInt; F:File;
Begin
 {$IFDEF FPC} Write(StdErr,'NCAP2: '); {$ELSE} Write('NCAP2: '); {$ENDIF}
 If ScriptRunning And (P<>Nil) Then Begin
  L:=1; J:=1;
  While (J<P^.Start) And (J<=ScriptLen) Do Begin
   If Script^[J]=#10 Then Inc(L); Inc(J)
  End;
  {$IFDEF FPC} Write(StdErr,'Script ligne ',L,' (position ',P^.Start,'): ')
  {$ELSE} Write('Script ligne ',L,' (position ',P^.Start,'): ') {$ENDIF}
 End;
 {$IFDEF FPC} WriteLn(StdErr,S); {$ELSE} WriteLn(S); {$ENDIF}
 For I:=0 To 15 Do If OpenStreams[I]<>Nil Then
  If OpenStreams[I]^.Opened Then Begin
   {$I-} Close(OpenStreams[I]^.DiskFile); If IOResult<>0 Then Begin End; {$I+}
   OpenStreams[I]^.Opened:=False
  End;
 If PendingOutput<>'' Then Begin
  Assign(F,PendingOutput);
  {$I-} Erase(F); If IOResult<>0 Then Begin End; {$I+}
 End;
 ReleaseState; Halt(1)
End;

Procedure CheckHeap(N:Word);
Begin
 {$IFNDEF FPC}
 If MaxAvail<N Then ReportError('Memoire DOS insuffisante');
 {$ENDIF}
End;

Function IntToStr(N:LongInt):String;
Var S:String;
Begin Str(N,S); IntToStr:=S End;

Function LowerCase(S:String):String;
Var I:Integer;
Begin
 For I:=1 To Length(S) Do If S[I] In ['A'..'Z'] Then S[I]:=Chr(Ord(S[I])+32);
 LowerCase:=S
End;

Function IntegerText(S:String):LongInt;
Var X:LongInt; Code:Integer;
Begin
 Val(S,X,Code); If (S='') Or (Code<>0) Then ReportError('Entier attendu: '+S);
 IntegerText:=X
End;

Procedure CheckName(S:String);
Begin If (S='') Or (Length(S)>63) Then ReportError('Nom vide ou plus de 63 caracteres') End;

Function FindDim(S:String):Integer;
Var I,R:Integer;
Begin
 R:=-1; For I:=0 To Dims^.Count-1 Do If Dims^.Item[I].Name=S Then R:=I;
 FindDim:=R
End;

Function FindVar(S:String):Integer;
Var I,R:Integer;
Begin
 R:=-1; For I:=0 To Vars^.Count-1 Do If Vars^.Item[I]^.Name=S Then R:=I;
 FindVar:=R
End;

Function FindAttr(Var A:TAttributes; S:String):Integer;
Var I,R:Integer;
Begin
 R:=-1; For I:=0 To A.Count-1 Do If A.Item[I]^.Name=S Then R:=I;
 FindAttr:=R
End;

Function AddDimension(S:String; N:LongInt; Unlimited:Boolean):Integer;
Var I:Integer;
Begin
 CheckName(S); If (N<0) Or (N>MaxElements) Then ReportError('Dimension hors limites DOS');
 I:=Dims^.Count; If I=MaxDims Then ReportError('Trop de dimensions');
 Dims^.Item[I].Name:=S; Dims^.Item[I].Size:=N; Dims^.Item[I].Unlimited:=Unlimited;
 Inc(Dims^.Count); AddDimension:=I
End;

Function Product(Var Shape:TShape):Integer;
Var I:Integer; N:LongInt;
Begin
 N:=1;
 For I:=0 To Shape.Rank-1 Do Begin
  If (Shape.ID[I]<0) Or (Shape.ID[I]>=Dims^.Count) Then ReportError('Dimension invalide');
  If (Dims^.Item[Shape.ID[I]].Size<>0) And
   (N>MaxElements Div Dims^.Item[Shape.ID[I]].Size) Then ReportError('Tableau trop grand (4096 elements)');
  N:=N*Dims^.Item[Shape.ID[I]].Size
 End;
 Product:=N
End;

Function NewValue(N:Integer):PValue;
Var V:PValue;
Begin
 If (N<0) Or (N>MaxElements) Then ReportError('Taille de tableau invalide');
 CheckHeap(SizeOf(TValue)); New(V); FillChar(V^,SizeOf(TValue),0);
 V^.Count:=N; V^.Kind:=6;
 If N>0 Then Begin
  CheckHeap(LongInt(N)*SizeOf(Double)); GetMem(V^.Data,LongInt(N)*SizeOf(Double));
  FillChar(V^.Data^,LongInt(N)*SizeOf(Double),0)
 End;
 NewValue:=V
End;

Procedure FreeValue(Var V:PValue);
Begin
 If V<>Nil Then Begin
  If V^.Data<>Nil Then FreeMem(V^.Data,LongInt(V^.Count)*SizeOf(Double));
  Dispose(V); V:=Nil
 End
End;

Function Scalar(X:Double):PValue;
Var V:PValue;
Begin V:=NewValue(1); V^.Data^[0]:=X; Scalar:=V End;

Function CopyValue(V:PValue):PValue;
Var R:PValue;
Begin
 R:=NewValue(V^.Count); R^.Shape:=V^.Shape; R^.Kind:=V^.Kind;
 R^.IsText:=V^.IsText; R^.Text:=V^.Text;
 If V^.Count>0 Then Move(V^.Data^,R^.Data^,LongInt(V^.Count)*SizeOf(Double));
 CopyValue:=R
End;

Function NumericScalar(V:PValue):Double;
Begin
 If V^.IsText Or (V^.Count<>1) Then ReportError('Scalaire numerique attendu');
 NumericScalar:=V^.Data^[0]
End;

Function IsNan(X:Double):Boolean;
Var B:TByte8;
Begin
 Move(X,B,8);
 IsNan:=((B[7] And $7F)=$7F) And ((B[6] And $F0)=$F0) And
 (((B[6] And $0F) Or B[5] Or B[4] Or B[3] Or B[2] Or B[1] Or B[0])<>0)
End;

Function IsInfinite(X:Double):Boolean;
Var B:TByte8;
Begin
 Move(X,B,8);
 IsInfinite:=((B[7] And $7F)=$7F) And (B[6]=$F0) And
 ((B[5] Or B[4] Or B[3] Or B[2] Or B[1] Or B[0])=0)
End;

Function IntegerScalar(V:PValue):LongInt;
Var X:Double;
Begin
 X:=NumericScalar(V);
 If IsNan(X) Or IsInfinite(X) Then ReportError('Entier non fini');
 If (X< -2147483647.0-1) Or (X>2147483647.0) Then ReportError('Entier hors limites');
 If X<>Trunc(X) Then ReportError('Entier attendu'); IntegerScalar:=Trunc(X)
End;

Procedure FreeAttrs(Var A:TAttributes);
Var I:Integer;
Begin
 For I:=0 To A.Count-1 Do Begin
  If A.Item[I]^.Data<>Nil Then FreeMem(A.Item[I]^.Data,A.Item[I]^.Bytes);
  Dispose(A.Item[I]); A.Item[I]:=Nil
 End;
 A.Count:=0
End;

Procedure FreeList(Var L:TTextList);
Var I:Integer;
Begin
 For I:=0 To L.Count-1 Do Begin Dispose(L.Item[I]); L.Item[I]:=Nil End;
 L.Count:=0
End;

Procedure ListAdd(Var L:TTextList; S:String);
Begin
 If L.Count=MaxAttrs Then ReportError('Trop d''options');
 CheckHeap(256); New(L.Item[L.Count]); L.Item[L.Count]^:=S; Inc(L.Count)
End;

Procedure AllocateState;
Begin
 CheckHeap(SizeOf(TDimensions)); New(Dims); FillChar(Dims^,SizeOf(TDimensions),0);
 CheckHeap(SizeOf(TVariables)); New(Vars); FillChar(Vars^,SizeOf(TVariables),0);
 CheckHeap(SizeOf(TAttributes)); New(GlobalAttrs); FillChar(GlobalAttrs^,SizeOf(TAttributes),0);
 CheckHeap(SizeOf(TTextList)); New(AddAttrs); FillChar(AddAttrs^,SizeOf(TTextList),0);
 CheckHeap(SizeOf(TTextList)); New(DeleteAttrs); FillChar(DeleteAttrs^,SizeOf(TTextList),0);
 CheckHeap(SizeOf(TParserState)); New(P); FillChar(P^,SizeOf(TParserState),0);
 CheckHeap(MaxScript); GetMem(Script,MaxScript)
End;

Procedure ReleaseState;
Var I:Integer;
Begin
 If ActiveMask<>Nil Then FreeValue(ActiveMask);
 If P<>Nil Then Begin Dispose(P); P:=Nil End;
 If DeleteAttrs<>Nil Then Begin FreeList(DeleteAttrs^); Dispose(DeleteAttrs); DeleteAttrs:=Nil End;
 If AddAttrs<>Nil Then Begin FreeList(AddAttrs^); Dispose(AddAttrs); AddAttrs:=Nil End;
 If GlobalAttrs<>Nil Then Begin FreeAttrs(GlobalAttrs^); Dispose(GlobalAttrs); GlobalAttrs:=Nil End;
 If Vars<>Nil Then Begin
  For I:=0 To Vars^.Count-1 Do Begin
   FreeValue(Vars^.Item[I]^.Value); FreeAttrs(Vars^.Item[I]^.Attrs); Dispose(Vars^.Item[I])
  End;
  Dispose(Vars); Vars:=Nil
 End;
 If Dims<>Nil Then Begin Dispose(Dims); Dims:=Nil End;
 If Script<>Nil Then Begin FreeMem(Script,MaxScript); Script:=Nil End
End;

Procedure StreamInit(Var F:TStream; Counting:Boolean);
Var I:Integer; Found:Boolean;
Begin
 F.Opened:=False; F.Counting:=Counting; F.Cursor:=0; Found:=False;
 For I:=0 To 15 Do If Not Found Then If OpenStreams[I]=Nil Then Begin
  OpenStreams[I]:=@F; Found:=True
 End;
 If Not Found Then ReportError('Trop de fichiers ouverts')
End;

Procedure StreamOpen(Var F:TStream; Name:String; Writing:Boolean);
Var Code:Integer;
Begin
 StreamInit(F,False); Assign(F.DiskFile,Name);
 {$I-}
 If Writing Then Rewrite(F.DiskFile,1) Else Begin FileMode:=0; Reset(F.DiskFile,1) End;
 Code:=IOResult; {$I+}
 If Code<>0 Then ReportError('Impossible d''ouvrir '+Name);
 F.Opened:=True
End;

Procedure StreamClose(Var F:TStream);
Var Code,I:Integer;
Begin
 Code:=0;
 If F.Opened Then Begin {$I-} Close(F.DiskFile); Code:=IOResult; {$I+} End;
 F.Opened:=False;
 For I:=0 To 15 Do If OpenStreams[I]=@F Then OpenStreams[I]:=Nil;
 If Code<>0 Then ReportError('Erreur de fermeture du fichier')
End;

Function StreamSize(Var F:TStream):LongInt;
Var N:LongInt; Code:Integer;
Begin
 If F.Counting Then N:=F.Cursor Else Begin
  {$I-} N:=FileSize(F.DiskFile); Code:=IOResult; {$I+}
  If Code<>0 Then ReportError('Erreur de taille du fichier')
 End;
 StreamSize:=N
End;

Procedure StreamSeek(Var F:TStream; N:LongInt);
Var Code:Integer;
Begin
 If N<0 Then ReportError('Offset negatif');
 If Not F.Counting Then Begin
  {$I-} Seek(F.DiskFile,N); Code:=IOResult; {$I+}
  If Code<>0 Then ReportError('Erreur de positionnement')
 End;
 F.Cursor:=N
End;

Procedure ReadExact(Var F:TStream; Var B; N:Word);
Var Done:Word; Code:Integer;
Begin
 If N=0 Then Exit;
 {$I-} BlockRead(F.DiskFile,B,N,Done); Code:=IOResult; {$I+}
 If (Code<>0) Or (Done<>N) Then ReportError('Fichier NetCDF tronque');
 Inc(F.Cursor,N)
End;

Procedure StreamWrite(Var F:TStream; Var B; N:Word);
Var Done:Word; Code:Integer;
Begin
 If Not F.Counting Then Begin
  {$I-} BlockWrite(F.DiskFile,B,N,Done); Code:=IOResult; {$I+}
  If (Code<>0) Or (Done<>N) Then ReportError('Erreur d''ecriture')
 End;
 If F.Cursor>2147483647-N Then ReportError('Fichier trop grand'); Inc(F.Cursor,N)
End;

Function ReadCount(Var F:TStream):LongInt;
Var B:Byte; I:Integer; N:LongInt;
Begin
 N:=0;
 For I:=1 To 4 Do Begin
  ReadExact(F,B,1); If N>(2147483647-B) Div 256 Then ReportError('Valeur NetCDF superieure a 2 Go');
  N:=N*256+B
 End;
 ReadCount:=N
End;

Procedure WriteUInt(Var F:TStream; X:LongInt; N:Integer);
Var B:TByte8; I:Integer; V:LongInt;
Begin
 If X<0 Then ReportError('Valeur d''en-tete negative'); FillChar(B,8,0); V:=X;
 For I:=N-1 DownTo 0 Do Begin B[I]:=V Mod 256; V:=V Div 256 End;
 If V<>0 Then ReportError('Valeur d''en-tete hors limites'); StreamWrite(F,B,N)
End;

Procedure ReadPadding(Var F:TStream; N:LongInt);
Var B:TByte8;
Begin ReadExact(F,B,(4-N Mod 4) Mod 4) End;
Procedure WritePadding(Var F:TStream; N:LongInt);
Var B:TByte8;
Begin FillChar(B,8,0); StreamWrite(F,B,(4-N Mod 4) Mod 4) End;

Function ReadName(Var F:TStream):String;
Var N:LongInt; S:String;
Begin
 N:=ReadCount(F); If (N<1) Or (N>63) Then ReportError('Nom NetCDF hors limites (63 caracteres)');
 S[0]:=Chr(N); ReadExact(F,S[1],N); ReadPadding(F,N); ReadName:=S
End;
Procedure WriteName(Var F:TStream; S:String);
Begin WriteUInt(F,Length(S),4); StreamWrite(F,S[1],Length(S)); WritePadding(F,Length(S)) End;

Function ListCount(Var F:TStream; Tag:Integer; Limit:Integer):Integer;
Var T,N:LongInt;
Begin
 T:=ReadCount(F); N:=ReadCount(F);
 If ((T<>Tag) And (T<>0)) Or ((T=0) And (N<>0)) Then ReportError('Liste NetCDF invalide');
 If N>Limit Then ReportError('Liste NetCDF trop longue pour DOS'); ListCount:=N
End;

Function TypeSize(K:Integer):Integer;
Var N:Integer;
Begin
 N:=0; Case K Of 1,2:N:=1; 3:N:=2; 4,5:N:=4; 6:N:=8 End;
 If N=0 Then ReportError('Type NetCDF non classique'); TypeSize:=N
End;

Function DecodeNumber(Var B:TByte8; K:Integer):Double;
Var R:TByte8; I,N:Integer; S:Single; D:Double; L:LongInt; W:Word; X:Double;
Begin
 N:=TypeSize(K); FillChar(R,8,0);
 For I:=0 To N-1 Do R[I]:=B[N-I-1];
 X:=0;
 Case K Of
  1:Begin X:=B[0]; If B[0]>127 Then X:=X-256 End;
  2:X:=B[0];
  3:Begin Move(R,W,2); X:=W; If W>32767 Then X:=X-65536.0 End;
  4:Begin Move(R,L,4); X:=L End;
  5:Begin Move(R,S,4); X:=S End;
  6:Begin Move(R,D,8); X:=D End
 End;
 DecodeNumber:=X
End;

Procedure EncodeNumber(X:Double; K:Integer; Var B:TByte8);
Var R:TByte8; I,N:Integer; L:LongInt; S:Single;
Begin
 N:=TypeSize(K); FillChar(R,8,0);
 If K In [1,2,3,4] Then Begin
  If IsNan(X) Or IsInfinite(X) Then ReportError('Conversion entiere non finie');
  Case K Of
   1:If (X< -128) Or (X>127) Then ReportError('Depassement NC_BYTE');
   2:If (X<0) Or (X>255) Then ReportError('Depassement NC_CHAR');
   3:If (X< -32768.0) Or (X>32767) Then ReportError('Depassement NC_SHORT');
   4:If (X< -2147483647.0-1) Or (X>2147483647.0) Then ReportError('Depassement NC_INT')
  End;
  L:=Trunc(X); Move(L,R,4)
 End Else If K=5 Then Begin
  If (Abs(X)>3.402823466E38) And Not IsInfinite(X) Then ReportError('Depassement NC_FLOAT');
  S:=X; Move(S,R,4)
 End Else Move(X,R,8);
 For I:=0 To N-1 Do B[I]:=R[N-I-1]
End;

Function ReadNumber(Var F:TStream; K:Integer):Double;
Var B:TByte8;
Begin ReadExact(F,B,TypeSize(K)); ReadNumber:=DecodeNumber(B,K) End;
Procedure WriteNumber(Var F:TStream; K:Integer; X:Double);
Var B:TByte8;
Begin EncodeNumber(X,K,B); StreamWrite(F,B,TypeSize(K)) End;

Function AttrSlot(Var A:TAttributes; Name:String):Integer;
Var I:Integer;
Begin
 CheckName(Name); I:=FindAttr(A,Name);
 If I<0 Then Begin
  If A.Count=MaxAttrs Then ReportError('Trop d''attributs');
  I:=A.Count; CheckHeap(SizeOf(TAttribute)); New(A.Item[I]);
  FillChar(A.Item[I]^,SizeOf(TAttribute),0); Inc(A.Count)
 End Else Begin
  If A.Item[I]^.Data<>Nil Then FreeMem(A.Item[I]^.Data,A.Item[I]^.Bytes);
  A.Item[I]^.Data:=Nil
 End;
 A.Item[I]^.Name:=Name; AttrSlot:=I
End;

Procedure ReadAttrs(Var F:TStream; Var A:TAttributes; Merge:Boolean);
Var I,J,N,K:Integer; Name:String; C,Bytes:LongInt;
Begin
 If Not Merge Then FreeAttrs(A);
 N:=ListCount(F,12,MaxAttrs);
 For I:=1 To N Do Begin
  Name:=ReadName(F); K:=ReadCount(F); C:=ReadCount(F);
  If C>MaxRaw Div TypeSize(K) Then ReportError('Attribut trop grand');
  Bytes:=C*TypeSize(K); J:=AttrSlot(A,Name);
  A.Item[J]^.Kind:=K; A.Item[J]^.Count:=C; A.Item[J]^.Bytes:=Bytes;
  If Bytes>0 Then Begin
   CheckHeap(Bytes); GetMem(A.Item[J]^.Data,Bytes); ReadExact(F,A.Item[J]^.Data^,Bytes)
  End;
  ReadPadding(F,Bytes)
 End
End;

Procedure WriteAttrs(Var F:TStream; Var A:TAttributes);
Var I:Integer;
Begin
 If A.Count=0 Then WriteUInt(F,0,4) Else WriteUInt(F,12,4);
 WriteUInt(F,A.Count,4);
 For I:=0 To A.Count-1 Do Begin
  WriteName(F,A.Item[I]^.Name); WriteUInt(F,A.Item[I]^.Kind,4); WriteUInt(F,A.Item[I]^.Count,4);
  If A.Item[I]^.Bytes>0 Then StreamWrite(F,A.Item[I]^.Data^,A.Item[I]^.Bytes);
  WritePadding(F,A.Item[I]^.Bytes)
 End
End;

Procedure SetAttribute(Var A:TAttributes; Name:String; V:PValue);
Var I,J,K,N:Integer; B:TByte8;
Begin
 I:=AttrSlot(A,Name); K:=V^.Kind;
 If V^.IsText Then Begin K:=2; N:=Length(V^.Text) End Else N:=V^.Count;
 If Not (K In [1,2,3,4,5,6]) Then K:=6;
 A.Item[I]^.Kind:=K; A.Item[I]^.Count:=N; A.Item[I]^.Bytes:=N*TypeSize(K);
 If A.Item[I]^.Bytes>0 Then Begin
  CheckHeap(A.Item[I]^.Bytes); GetMem(A.Item[I]^.Data,A.Item[I]^.Bytes);
  If V^.IsText Then Move(V^.Text[1],A.Item[I]^.Data^,N)
  Else For J:=0 To N-1 Do Begin
   EncodeNumber(V^.Data^[J],K,B); Move(B,A.Item[I]^.Data^[J*TypeSize(K)],TypeSize(K))
  End
 End
End;

Function GetAttribute(Var A:TAttributes; Name:String):PValue;
Var I,J,K,N:Integer; V:PValue; B:TByte8;
Begin
 I:=FindAttr(A,Name); If I<0 Then ReportError('Attribut inconnu: '+Name);
 K:=A.Item[I]^.Kind; N:=A.Item[I]^.Count;
 If K=2 Then Begin
  If N>255 Then ReportError('Attribut texte superieur a 255 caracteres');
  V:=NewValue(0); V^.IsText:=True; V^.Text[0]:=Chr(N);
  If N>0 Then Move(A.Item[I]^.Data^,V^.Text[1],N)
 End Else Begin
  V:=NewValue(N); V^.Kind:=K;
  For J:=0 To N-1 Do Begin
   Move(A.Item[I]^.Data^[J*TypeSize(K)],B,TypeSize(K)); V^.Data^[J]:=DecodeNumber(B,K)
  End
 End;
 GetAttribute:=V
End;

Function VariableSlot(Name:String):Integer;
Var I:Integer;
Begin
 CheckName(Name); I:=FindVar(Name);
 If I<0 Then Begin
  If Vars^.Count=MaxVars Then ReportError('Trop de variables');
  I:=Vars^.Count; CheckHeap(SizeOf(TVariable)); New(Vars^.Item[I]);
  FillChar(Vars^.Item[I]^,SizeOf(TVariable),0);
  Vars^.Item[I]^.Name:=Name; Inc(Vars^.Count)
 End;
 VariableSlot:=I
End;

Procedure LoadNetCDF(Name:String; Merge:Boolean);
Var F:TStream; Magic:TByte8; Map:Array[0..MaxDims-1] Of Integer;
 Loaded:TIndexList; I,J,K,ND,NV,Rank,V,DimId,RecordVars:Integer;
 NumRecords,Size,RecSize,Slab,At,HighOffset:LongInt;
 DName:String; Unlim:Boolean; Shape:TShape; VV:PVariable;
Begin
 StreamOpen(F,Name,False); ReadExact(F,Magic,4);
 If (Magic[0]<>67) Or (Magic[1]<>68) Or (Magic[2]<>70) Or
  Not (Magic[3] In [1,2]) Then ReportError('Seuls CDF-1/CDF-2 sont pris en charge');
 If Not Merge Then FormatVersion:=Magic[3];
 NumRecords:=ReadCount(F); ND:=ListCount(F,10,MaxDims);
 For I:=0 To ND-1 Do Begin
  DName:=ReadName(F); Size:=ReadCount(F); Unlim:=Size=0; If Unlim Then Size:=NumRecords;
  K:=FindDim(DName);
  If K<0 Then K:=AddDimension(DName,Size,Unlim)
  Else If (Dims^.Item[K].Size<>Size) Or (Dims^.Item[K].Unlimited<>Unlim) Then
   ReportError('Dimensions incompatibles: '+DName);
  Map[I]:=K
 End;
 ReadAttrs(F,GlobalAttrs^,Merge); NV:=ListCount(F,11,MaxVars); RecSize:=0; RecordVars:=0;
 For I:=0 To NV-1 Do Begin
  DName:=ReadName(F); V:=VariableSlot(DName); Loaded[I]:=V; VV:=Vars^.Item[V];
  Rank:=ReadCount(F); If Rank>MaxRank Then ReportError('Rang superieur a 8'); Shape.Rank:=Rank;
  For J:=0 To Rank-1 Do Begin
   DimId:=ReadCount(F); If (DimId<0) Or (DimId>=ND) Then ReportError('Dimension invalide');
   Shape.ID[J]:=Map[DimId];
   For K:=0 To J-1 Do If Shape.ID[K]=Shape.ID[J] Then ReportError('Dimensions repetees non prises en charge')
  End;
  ReadAttrs(F,VV^.Attrs,False); VV^.Kind:=ReadCount(F); K:=TypeSize(VV^.Kind);
  VV^.DiskSize:=ReadCount(F);
  If Magic[3]=2 Then Begin HighOffset:=ReadCount(F); If HighOffset<>0 Then
   ReportError('Offset CDF-2 superieur a 2 Go') End;
  VV^.Offset:=ReadCount(F); FreeValue(VV^.Value); VV^.Value:=NewValue(Product(Shape)); VV^.Value^.Shape:=Shape;
  If Rank>0 Then If Dims^.Item[Shape.ID[0]].Unlimited Then Begin
   Inc(RecSize,VV^.DiskSize); Inc(RecordVars)
  End
 End;
 If RecordVars=1 Then For I:=0 To NV-1 Do Begin
  VV:=Vars^.Item[Loaded[I]];
  If VV^.Value^.Shape.Rank>0 Then If Dims^.Item[VV^.Value^.Shape.ID[0]].Unlimited Then Begin
   RecSize:=TypeSize(VV^.Kind);
   For J:=1 To VV^.Value^.Shape.Rank-1 Do RecSize:=RecSize*Dims^.Item[VV^.Value^.Shape.ID[J]].Size
  End
 End;
 For I:=0 To NV-1 Do Begin
  VV:=Vars^.Item[Loaded[I]]; Unlim:=False;
  If VV^.Value^.Shape.Rank>0 Then Unlim:=Dims^.Item[VV^.Value^.Shape.ID[0]].Unlimited;
  Slab:=1;
  If Unlim Then For J:=1 To VV^.Value^.Shape.Rank-1 Do Slab:=Slab*Dims^.Item[VV^.Value^.Shape.ID[J]].Size;
  For J:=0 To VV^.Value^.Count-1 Do Begin
   If Unlim Then At:=VV^.Offset+(J Div Slab)*RecSize+(J Mod Slab)*TypeSize(VV^.Kind)
   Else At:=VV^.Offset+LongInt(J)*TypeSize(VV^.Kind);
   If (At<0) Or (At>StreamSize(F)-TypeSize(VV^.Kind)) Then ReportError('Donnees hors fichier');
   StreamSeek(F,At); VV^.Value^.Data^[J]:=ReadNumber(F,VV^.Kind)
  End
 End;
 StreamClose(F)
End;

Function BroadcastIndex(Var Shape,OutShape:TShape; Flat:Integer):Integer;
Var I,J,K,C,Stride,Index:Integer;
Begin
 Index:=0;
 For I:=OutShape.Rank-1 DownTo 0 Do Begin
  C:=Flat Mod Dims^.Item[OutShape.ID[I]].Size;
  Flat:=Flat Div Dims^.Item[OutShape.ID[I]].Size;
  For J:=0 To Shape.Rank-1 Do If Shape.ID[J]=OutShape.ID[I] Then Begin
   Stride:=1;
   For K:=J+1 To Shape.Rank-1 Do Stride:=Stride*Dims^.Item[Shape.ID[K]].Size;
   Inc(Index,C*Stride)
  End
 End;
 BroadcastIndex:=Index
End;

Function HasDimension(Var Shape:TShape; ID:Integer):Boolean;
Var I:Integer; Found:Boolean;
Begin
 Found:=False; For I:=0 To Shape.Rank-1 Do If Shape.ID[I]=ID Then Found:=True;
 HasDimension:=Found
End;

Procedure AppendDimension(Var Shape:TShape; ID:Integer);
Begin
 If HasDimension(Shape,ID) Then ReportError('Dimension repetee');
 If Shape.Rank=MaxRank Then ReportError('Rang superieur a 8');
 Shape.ID[Shape.Rank]:=ID; Inc(Shape.Rank)
End;

Function Power(X,Y:Double):Double;
Var N:LongInt; R:Double; Negative:Boolean;
Begin
 If IsNan(X) Or IsNan(Y) Or IsInfinite(X) Or IsInfinite(Y) Then ReportError('Puissance non finie');
 If X=0 Then Begin
  If Y<0 Then ReportError('Puissance negative de zero'); R:=0; If Y=0 Then R:=1
 End Else If (Abs(Y)<=2147483647.0) And (Y=Trunc(Y)) Then Begin
  N:=Trunc(Y); Negative:=N<0; If Negative Then N:=-N; R:=1;
  While N>0 Do Begin
   If Odd(N) Then R:=R*X; N:=N Div 2; If N>0 Then X:=X*X
  End;
  If Negative Then R:=1/R
 End Else Begin
  If X<0 Then ReportError('Puissance fractionnaire negative'); R:=Exp(Y*Ln(X))
 End;
 Power:=R
End;

Function Atan2(Y,X:Double):Double;
Var R:Double;
Begin
 If X>0 Then R:=ArcTan(Y/X) Else If X<0 Then Begin
  R:=ArcTan(Y/X); If Y>=0 Then R:=R+Pi Else R:=R-Pi
 End Else If Y>0 Then R:=Pi/2 Else If Y<0 Then R:=-Pi/2 Else R:=0;
 Atan2:=R
End;

Function Combine(A,B:PValue; Op:String):PValue;
Var R:PValue; Shape:TShape; I,AI,BI:Integer; X,Y,Z:Double;
Begin
 If A^.IsText Or B^.IsText Then Begin
  If Not ((Op='+') And A^.IsText And B^.IsText) Then ReportError('Operation numerique sur du texte');
  If Length(A^.Text)+Length(B^.Text)>255 Then ReportError('Texte superieur a 255 caracteres');
  R:=NewValue(0); R^.IsText:=True; R^.Text:=A^.Text+B^.Text
 End Else Begin
  Shape:=A^.Shape;
  For I:=0 To B^.Shape.Rank-1 Do If Not HasDimension(Shape,B^.Shape.ID[I]) Then AppendDimension(Shape,B^.Shape.ID[I]);
  R:=NewValue(Product(Shape)); R^.Shape:=Shape;
  If ((A^.Shape.Rank=0) And (A^.Count<>1)) Or
   ((B^.Shape.Rank=0) And (B^.Count<>1)) Then ReportError('Tableau sans dimensions');
  For I:=0 To R^.Count-1 Do Begin
   AI:=BroadcastIndex(A^.Shape,Shape,I); BI:=BroadcastIndex(B^.Shape,Shape,I);
   X:=A^.Data^[AI]; Y:=B^.Data^[BI]; Z:=0;
   If Op='+' Then Z:=X+Y Else If Op='-' Then Z:=X-Y Else If Op='*' Then Z:=X*Y
   Else If Op='/' Then Begin If Y=0 Then ReportError('Division par zero'); Z:=X/Y End
   Else If Op='%' Then Begin If Y=0 Then ReportError('Modulo par zero'); Z:=X-Trunc(X/Y)*Y End
   Else If Op='^' Then Z:=Power(X,Y)
   Else If Op='==' Then Z:=Ord(X=Y) Else If Op='!=' Then Z:=Ord(X<>Y)
   Else If Op='<' Then Z:=Ord(X<Y) Else If Op='>' Then Z:=Ord(X>Y)
   Else If Op='<=' Then Z:=Ord(X<=Y) Else If Op='>=' Then Z:=Ord(X>=Y)
   Else If Op='&&' Then Z:=Ord((X<>0) And (Y<>0))
   Else If Op='||' Then Z:=Ord((X<>0) Or (Y<>0)) Else ReportError('Operateur inconnu');
   R^.Data^[I]:=Z
  End
 End;
 Combine:=R
End;

Function ApplyFunction(Name:String; Var Args:TArgList; N:Integer):PValue;
Var R,A:PValue; S:String; I,J,K,D,Num:Integer; X,Y,E:Double;
 Reduced:TShape; Counts:PSelection; B:TByte8;
Begin
 S:=LowerCase(Name); R:=Nil;
 If N=0 Then ReportError('Argument manquant: '+Name); A:=Args[0];
 If S='array' Then Begin
  If N<3 Then ReportError('array(debut,pas,$dimension,...) attendu');
  X:=NumericScalar(A); Y:=NumericScalar(Args[1]); Reduced.Rank:=0;
  For I:=2 To N-1 Do Begin
   D:=IntegerScalar(Args[I]); If (D<0) Or (D>=Dims^.Count) Then ReportError('Dimension inconnue');
   AppendDimension(Reduced,D)
  End;
  R:=NewValue(Product(Reduced)); R^.Shape:=Reduced;
  For I:=0 To R^.Count-1 Do R^.Data^[I]:=X+I*Y
 End Else If (S='pow') Or (S='atan2') Then Begin
  If N<>2 Then ReportError('Deux arguments attendus');
  If S='pow' Then R:=Combine(A,Args[1],'^') Else Begin
   R:=Combine(A,Args[1],'+');
   For I:=0 To R^.Count-1 Do R^.Data^[I]:=Atan2(
    A^.Data^[BroadcastIndex(A^.Shape,R^.Shape,I)],
    Args[1]^.Data^[BroadcastIndex(Args[1]^.Shape,R^.Shape,I)])
  End
 End Else If (S='sum') Or (S='total') Or (S='avg') Or (S='mean') Or
  (S='min') Or (S='max') Or (S='rms') Or (S='size') Then Begin
  If A^.IsText Then ReportError('Argument numerique attendu');
  If N=1 Then Reduced:=A^.Shape Else Begin
   Reduced.Rank:=0;
   For I:=1 To N-1 Do Begin
    D:=IntegerScalar(Args[I]); If Not HasDimension(A^.Shape,D) Then ReportError('Dimension de reduction absente');
    AppendDimension(Reduced,D)
   End
  End;
  R:=NewValue(0);
  For I:=0 To A^.Shape.Rank-1 Do If Not HasDimension(Reduced,A^.Shape.ID[I]) Then
   AppendDimension(R^.Shape,A^.Shape.ID[I]);
  Num:=Product(R^.Shape); R^.Count:=Num;
  If Num>0 Then Begin CheckHeap(LongInt(Num)*8); GetMem(R^.Data,LongInt(Num)*8);
   FillChar(R^.Data^,LongInt(Num)*8,0) End;
  CheckHeap(SizeOf(TSelection)); New(Counts); FillChar(Counts^,SizeOf(TSelection),0);
  For I:=0 To A^.Count-1 Do Begin
   J:=BroadcastIndex(R^.Shape,A^.Shape,I); Y:=A^.Data^[I];
   If (S='min') Or (S='max') Then Begin
    If Counts^[J]=0 Then R^.Data^[J]:=Y Else
     If ((S='min') And (Y<R^.Data^[J])) Or ((S='max') And (Y>R^.Data^[J])) Then R^.Data^[J]:=Y
   End Else If S='rms' Then R^.Data^[J]:=R^.Data^[J]+Y*Y Else R^.Data^[J]:=R^.Data^[J]+Y;
   Inc(Counts^[J])
  End;
  For J:=0 To R^.Count-1 Do Begin
   If (Counts^[J]=0) And (S<>'size') Then ReportError('Reduction sur un tableau vide');
   If (S='avg') Or (S='mean') Then R^.Data^[J]:=R^.Data^[J]/Counts^[J];
   If S='rms' Then R^.Data^[J]:=Sqrt(R^.Data^[J]/Counts^[J]);
   If S='size' Then R^.Data^[J]:=Counts^[J]
  End;
  Dispose(Counts)
 End Else Begin
  If N<>1 Then ReportError('Un argument attendu: '+Name);
  If A^.IsText Then ReportError('Argument numerique attendu'); R:=CopyValue(A); K:=0;
  If S='byte' Then K:=1 Else If S='short' Then K:=3 Else If (S='int') Or (S='long') Then K:=4
  Else If S='float' Then K:=5 Else If S='double' Then K:=6;
  R^.Kind:=K; If K=0 Then R^.Kind:=6;
  For I:=0 To R^.Count-1 Do Begin
   X:=R^.Data^[I];
   If K<>0 Then Begin EncodeNumber(X,K,B); X:=DecodeNumber(B,K) End
   Else If S='abs' Then X:=Abs(X) Else If S='sqr' Then X:=Sqr(X)
   Else If S='sqrt' Then Begin If X<0 Then ReportError('sqrt: argument negatif'); X:=Sqrt(X) End
   Else If S='exp' Then Begin If X>709 Then ReportError('exp: depassement'); X:=Exp(X) End
   Else If (S='ln') Or (S='log') Or (S='log10') Then Begin
    If X<=0 Then ReportError('log: argument positif attendu'); X:=Ln(X); If S='log10' Then X:=X/Ln(10)
   End Else If S='sin' Then X:=Sin(X) Else If S='cos' Then X:=Cos(X)
   Else If S='tan' Then Begin Y:=Cos(X); If Y=0 Then ReportError('tan indefinie'); X:=Sin(X)/Y End
   Else If (S='asin') Or (S='acos') Then Begin
    If Abs(X)>1 Then ReportError(S+': argument hors [-1,1]');
    If S='asin' Then X:=Atan2(X,Sqrt((1-X)*(1+X))) Else X:=Atan2(Sqrt((1-X)*(1+X)),X)
   End Else If S='atan' Then X:=ArcTan(X)
   Else If (S='sinh') Or (S='cosh') Then Begin
    If Abs(X)>709 Then ReportError('Depassement hyperbolique'); E:=Exp(X);
    If S='sinh' Then X:=(E-1/E)/2 Else X:=(E+1/E)/2
   End Else If S='tanh' Then Begin
    E:=Exp(-2*Abs(X)); Y:=(1-E)/(1+E); If X<0 Then Y:=-Y; X:=Y
   End Else If (S='floor') Or (S='ceil') Or (S='round') Then Begin
    If Abs(X)<=2147483647.0 Then Begin
     Y:=Trunc(X); If (S='floor') And (Y>X) Then Y:=Y-1;
     If (S='ceil') And (Y<X) Then Y:=Y+1;
     If S='round' Then Y:=Round(X); X:=Y
    End Else ReportError('Arrondi hors limites LongInt')
   End Else If S='isnan' Then X:=Ord(IsNan(X))
   Else If S='isfinite' Then X:=Ord(Not IsNan(X) And Not IsInfinite(X))
   Else ReportError('Fonction non implementee: '+Name);
   R^.Data^[I]:=X
  End
 End;
 ApplyFunction:=R
End;

Function ScriptChar(I:LongInt):Char;
Begin If (I<1) Or (I>ScriptLen) Then ScriptChar:=#0 Else ScriptChar:=Script^[I] End;

Procedure TokenAppend(C:Char);
Begin
 If Length(P^.Token)=255 Then ReportError('Jeton superieur a 255 caracteres');
 P^.Token:=P^.Token+C
End;

Procedure Next;
Var C,Q,N:Char; Done:Boolean; Pair:String[2];
Begin
 Done:=False;
 Repeat
  While (P^.Pos<=ScriptLen) And (ScriptChar(P^.Pos)<=' ') Do Inc(P^.Pos);
  C:=ScriptChar(P^.Pos); N:=ScriptChar(P^.Pos+1);
  If (C='#') Or ((C='/') And (N='/')) Then Begin
   While (P^.Pos<=ScriptLen) And (ScriptChar(P^.Pos)<>#10) Do Inc(P^.Pos)
  End Else If (C='/') And (N='*') Then Begin
   Inc(P^.Pos,2);
   While (P^.Pos<=ScriptLen) And Not ((ScriptChar(P^.Pos)='*') And (ScriptChar(P^.Pos+1)='/')) Do Inc(P^.Pos);
   If P^.Pos>ScriptLen Then ReportError('Commentaire non termine'); Inc(P^.Pos,2)
  End Else Done:=True
 Until Done;
 P^.Start:=P^.Pos; P^.Token:=''; P^.TokenKind:=#0;
 If P^.Pos>ScriptLen Then Exit;
 C:=ScriptChar(P^.Pos); Inc(P^.Pos);
 If C In ['a'..'z','A'..'Z','_'] Then Begin
  P^.TokenKind:='i'; TokenAppend(C);
  While ScriptChar(P^.Pos) In ['a'..'z','A'..'Z','0'..'9','_'] Do Begin TokenAppend(ScriptChar(P^.Pos)); Inc(P^.Pos) End
 End Else If (C In ['0'..'9']) Or ((C='.') And (ScriptChar(P^.Pos) In ['0'..'9'])) Then Begin
  P^.TokenKind:='n'; TokenAppend(C);
  While ScriptChar(P^.Pos) In ['0'..'9','.'] Do Begin TokenAppend(ScriptChar(P^.Pos)); Inc(P^.Pos) End;
  If ScriptChar(P^.Pos) In ['e','E'] Then Begin
   TokenAppend(ScriptChar(P^.Pos)); Inc(P^.Pos);
   If ScriptChar(P^.Pos) In ['+','-'] Then Begin TokenAppend(ScriptChar(P^.Pos)); Inc(P^.Pos) End;
   While ScriptChar(P^.Pos) In ['0'..'9'] Do Begin TokenAppend(ScriptChar(P^.Pos)); Inc(P^.Pos) End
  End
 End Else If C In ['''','"'] Then Begin
  Q:=C; P^.TokenKind:='s';
  While (P^.Pos<=ScriptLen) And (ScriptChar(P^.Pos)<>Q) Do Begin
   C:=ScriptChar(P^.Pos); Inc(P^.Pos);
   If C='\' Then Begin
    C:=ScriptChar(P^.Pos); Inc(P^.Pos);
    Case C Of 'n':C:=#10; 'r':C:=#13; 't':C:=#9 End
   End;
   TokenAppend(C)
  End;
  If P^.Pos>ScriptLen Then ReportError('Chaine non terminee'); Inc(P^.Pos)
 End Else Begin
  P^.TokenKind:='p'; P^.Token:=C; Pair:=C+ScriptChar(P^.Pos);
  If (Pair='==') Or (Pair='!=') Or (Pair='<=') Or (Pair='>=') Or (Pair='&&') Or (Pair='||') Or
   (Pair='+=') Or (Pair='-=') Or (Pair='*=') Or (Pair='/=') Or (Pair='++') Or (Pair='--') Then Begin
   P^.Token:=Pair; Inc(P^.Pos)
  End
 End
End;

Procedure Expect(S:String);
Begin If P^.Token<>S Then ReportError('Attendu "'+S+'", trouve "'+P^.Token+'"'); Next End;

Function Identifier:String;
Var S:String;
Begin
 If P^.TokenKind<>'i' Then ReportError('Identificateur attendu'); S:=P^.Token; Next; Identifier:=S
End;

Function Expression(MinPrec:Integer):PValue; Forward;

Function ParseInteger:LongInt;
Var V:PValue; N:LongInt;
Begin V:=Expression(0); N:=IntegerScalar(V); FreeValue(V); ParseInteger:=N End;

Procedure ParseSelection(V:PValue; Var Indices:PSelection; Var Shape:TShape; Var Count:Integer);
Var Starts,Steps,Counts:Array[0..MaxRank-1] Of Integer;
 I,J,K,D,C,Flat,Stride,L,H,Step:Integer; SingleIndex:Boolean; N:LongInt;
Begin
 Shape.Rank:=0; Expect('(');
 For I:=0 To V^.Shape.Rank-1 Do Begin
  D:=V^.Shape.ID[I]; L:=0; H:=Dims^.Item[D].Size-1; Step:=1; SingleIndex:=False;
  If P^.Token<>':' Then Begin
   N:=ParseInteger; If FortranIndex Then Dec(N);
   If (N<0) Or (N>MaxElements) Then ReportError('Indice hors limites'); L:=N; SingleIndex:=True
  End;
  If P^.Token=':' Then Begin
   Next; SingleIndex:=False;
   If (P^.Token<>',') And (P^.Token<>')') And (P^.Token<>':') Then Begin
    N:=ParseInteger; If FortranIndex Then Dec(N);
    If (N<0) Or (N>MaxElements) Then ReportError('Borne hors limites'); H:=N
   End;
   If P^.Token=':' Then Begin
    Next; N:=ParseInteger; If (N<1) Or (N>MaxElements) Then ReportError('Pas de tranche invalide'); Step:=N
   End
  End Else H:=L;
  If (L<0) Or (H<L) Or (H>=Dims^.Item[D].Size) Then ReportError('Tranche hors limites');
  Starts[I]:=L; Steps[I]:=Step; Counts[I]:=(H-L) Div Step+1;
  If Not SingleIndex Then Begin
   If (L<>0) Or (Step<>1) Or (Counts[I]<>Dims^.Item[D].Size) Then
    D:=AddDimension('_slice_'+IntToStr(Dims^.Count),Counts[I],False);
   AppendDimension(Shape,D)
  End;
  If I<V^.Shape.Rank-1 Then Expect(',')
 End;
 Expect(')'); Count:=1; For I:=0 To V^.Shape.Rank-1 Do Count:=Count*Counts[I];
 CheckHeap(SizeOf(TSelection)); New(Indices);
 For I:=0 To Count-1 Do Begin
  Flat:=I; Stride:=1; K:=0;
  For J:=V^.Shape.Rank-1 DownTo 0 Do Begin
   C:=Flat Mod Counts[J]; Flat:=Flat Div Counts[J]; Inc(K,(Starts[J]+C*Steps[J])*Stride);
   Stride:=Stride*Dims^.Item[V^.Shape.ID[J]].Size
  End;
  Indices^[I]:=K
 End
End;

Function Primary:PValue;
Var R,V,T:PValue; Name,S:String; Args:TArgList; N,I,J,Code:Integer; X:Double;
 Indices:PSelection; Shape:TShape;
Begin
 R:=Nil;
 If P^.TokenKind='n' Then Begin
  Val(P^.Token,X,Code); If Code<>0 Then ReportError('Nombre invalide'); R:=Scalar(X); Next
 End Else If P^.TokenKind='s' Then Begin
  R:=NewValue(0); R^.IsText:=True; R^.Text:=P^.Token; Next
 End Else If P^.Token='(' Then Begin Next; R:=Expression(0); Expect(')') End
 Else If P^.Token='$' Then Begin
  Next; Name:=Identifier; I:=FindDim(Name); If I<0 Then ReportError('Dimension inconnue: '+Name); R:=Scalar(I)
 End Else If P^.Token='@' Then Begin Next; Name:=Identifier; R:=GetAttribute(GlobalAttrs^,Name) End
 Else If P^.Token='{' Then Begin
  Next; R:=NewValue(MaxElements); N:=0;
  Repeat
   T:=Expression(0); If N=MaxElements Then ReportError('Liste trop longue');
   R^.Data^[N]:=NumericScalar(T); Inc(N); FreeValue(T);
   If P^.Token<>',' Then Break; Next
  Until False;
  Expect('}'); V:=NewValue(N); Move(R^.Data^,V^.Data^,N*8); FreeValue(R); R:=V;
  I:=AddDimension('_list_'+IntToStr(Dims^.Count),N,False); AppendDimension(R^.Shape,I)
 End Else If P^.TokenKind='i' Then Begin
  Name:=Identifier; I:=FindVar(Name);
  If (P^.Token='(') And (I<0) Then Begin
   Next; N:=0;
   If P^.Token<>')' Then Repeat
    If N=16 Then ReportError('Trop d''arguments'); Args[N]:=Expression(0); Inc(N);
    If P^.Token<>',' Then Break; Next
   Until False;
   Expect(')'); R:=ApplyFunction(Name,Args,N); For J:=0 To N-1 Do FreeValue(Args[J])
  End Else If I<0 Then Begin
   S:=LowerCase(Name);
   If (S='pi') Or (S='m_pi') Then R:=Scalar(Pi) Else If S='e' Then R:=Scalar(Exp(1))
   Else If S='true' Then R:=Scalar(1) Else If S='false' Then R:=Scalar(0)
   Else ReportError('Variable inconnue: '+Name)
  End Else If P^.Token='@' Then Begin Next; S:=Identifier; R:=GetAttribute(Vars^.Item[I]^.Attrs,S) End
  Else Begin
   V:=Vars^.Item[I]^.Value;
   If P^.Token='(' Then Begin
    ParseSelection(V,Indices,Shape,N); R:=NewValue(N); R^.Shape:=Shape;
    For J:=0 To N-1 Do R^.Data^[J]:=V^.Data^[Indices^[J]]; Dispose(Indices)
   End Else R:=CopyValue(V)
  End
 End Else ReportError('Expression attendue: '+P^.Token);
 While P^.Token='.' Do Begin
  Next; Name:=Identifier; Expect('('); Args[0]:=R; N:=1;
  If P^.Token<>')' Then Repeat
   If N=16 Then ReportError('Trop d''arguments'); Args[N]:=Expression(0); Inc(N);
   If P^.Token<>',' Then Break; Next
  Until False;
  Expect(')'); R:=ApplyFunction(Name,Args,N); For J:=0 To N-1 Do FreeValue(Args[J])
 End;
 Primary:=R
End;

Function Precedence(Op:String):Integer;
Var N:Integer;
Begin
 N:=-1;
 If Op='||' Then N:=1 Else If Op='&&' Then N:=2
 Else If (Op='==') Or (Op='!=') Then N:=3
 Else If (Op='<') Or (Op='>') Or (Op='<=') Or (Op='>=') Then N:=4
 Else If (Op='+') Or (Op='-') Then N:=5
 Else If (Op='*') Or (Op='/') Or (Op='%') Then N:=6 Else If Op='^' Then N:=8;
 Precedence:=N
End;

Function Expression(MinPrec:Integer):PValue;
Var L,R,T:PValue; Op:String; Prec,I:Integer;
Begin
 If (P^.Token='+') Or (P^.Token='-') Or (P^.Token='!') Then Begin
  Op:=P^.Token; Next; L:=Expression(7); If L^.IsText Then ReportError('Operateur unaire numerique attendu');
  For I:=0 To L^.Count-1 Do
   If Op='-' Then L^.Data^[I]:=-L^.Data^[I] Else If Op='!' Then L^.Data^[I]:=Ord(L^.Data^[I]=0)
 End Else L:=Primary;
 Repeat
  Prec:=Precedence(P^.Token); If Prec<MinPrec Then Break; Op:=P^.Token; Next;
  If Op='^' Then R:=Expression(Prec) Else R:=Expression(Prec+1);
  T:=Combine(L,R,Op); FreeValue(L); FreeValue(R); L:=T
 Until False;
 Expression:=L
End;

Function FilledValue(V:PValue; Var Shape:TShape):PValue;
Var R:PValue; I:Integer;
Begin
 R:=NewValue(Product(Shape)); R^.Shape:=Shape; R^.Kind:=V^.Kind;
 If V^.Count=1 Then For I:=0 To R^.Count-1 Do R^.Data^[I]:=V^.Data^[0]
 Else Begin
  If V^.Count<>R^.Count Then ReportError('Dimensions incompatibles');
  If R^.Count>0 Then Move(V^.Data^,R^.Data^,LongInt(R^.Count)*8)
 End;
 FilledValue:=R
End;

Procedure AssignVariable(Name:String; Var Shape:TShape; ExplicitShape:Boolean;
 Indices:PSelection; SelectionCount:Integer; Sliced:Boolean; Op:String; Source:PValue);
Var I,J,K:Integer; V,T,U,Before:PValue;
Begin
 I:=FindVar(Name); Before:=Nil; If I>=0 Then Before:=Vars^.Item[I]^.Value;
 If Sliced Then Begin
  If Before=Nil Then ReportError('Variable inconnue: '+Name); V:=CopyValue(Before);
  If Source^.IsText Or ((Source^.Count<>1) And (Source^.Count<>SelectionCount)) Then
   ReportError('Taille de tranche incompatible');
  For J:=0 To SelectionCount-1 Do Begin
   K:=J; If Source^.Count=1 Then K:=0;
   If Op='=' Then V^.Data^[Indices^[J]]:=Source^.Data^[K] Else Begin
    T:=Scalar(V^.Data^[Indices^[J]]); U:=Scalar(Source^.Data^[K]);
    V^.Data^[Indices^[J]]:=0;
    Case Op[1] Of
     '+':V^.Data^[Indices^[J]]:=T^.Data^[0]+U^.Data^[0];
     '-':V^.Data^[Indices^[J]]:=T^.Data^[0]-U^.Data^[0];
     '*':V^.Data^[Indices^[J]]:=T^.Data^[0]*U^.Data^[0];
     '/':Begin If U^.Data^[0]=0 Then ReportError('Division par zero');
      V^.Data^[Indices^[J]]:=T^.Data^[0]/U^.Data^[0] End
    End;
    FreeValue(T); FreeValue(U)
   End
  End
 End Else Begin
  If Source^.IsText Then Begin
   If Not ExplicitShape Then ReportError('Texte: fournir une dimension explicite');
   V:=NewValue(Length(Source^.Text)); V^.Kind:=2;
   For J:=1 To Length(Source^.Text) Do V^.Data^[J-1]:=Ord(Source^.Text[J])
  End Else V:=CopyValue(Source);
  If ExplicitShape Then Begin T:=FilledValue(V,Shape); FreeValue(V); V:=T End
  Else If Before<>Nil Then If (V^.Shape.Rank=0) And (Before^.Shape.Rank>0) Then Begin
   T:=FilledValue(V,Before^.Shape); FreeValue(V); V:=T
  End;
  If Op<>'=' Then Begin
   If Before=Nil Then ReportError('Variable inconnue: '+Name);
   T:=Combine(Before,V,Copy(Op,1,1)); FreeValue(V); V:=T
  End
 End;
 If Masked Then Begin
  If (V^.Shape.Rank=0) And (ActiveMask^.Shape.Rank>0) Then Begin
   T:=FilledValue(V,ActiveMask^.Shape); FreeValue(V); V:=T
  End;
  For J:=0 To ActiveMask^.Shape.Rank-1 Do
   If Not HasDimension(V^.Shape,ActiveMask^.Shape.ID[J]) Then ReportError('Dimension du masque absente de '+Name);
  If Before<>Nil Then For J:=0 To Before^.Shape.Rank-1 Do
   If Not HasDimension(V^.Shape,Before^.Shape.ID[J]) Then ReportError('where ne peut supprimer une dimension');
  For J:=0 To V^.Count-1 Do If ActiveMask^.Data^[BroadcastIndex(ActiveMask^.Shape,V^.Shape,J)]=0 Then Begin
   If Before=Nil Then V^.Data^[J]:=0
   Else V^.Data^[J]:=Before^.Data^[BroadcastIndex(Before^.Shape,V^.Shape,J)]
  End
 End;
 I:=VariableSlot(Name);
 If Vars^.Item[I]^.Value=Nil Then Vars^.Item[I]^.Kind:=V^.Kind;
 FreeValue(Vars^.Item[I]^.Value); Vars^.Item[I]^.Value:=V; Vars^.Item[I]^.Changed:=True
End;

Procedure Statement(Execute:Boolean); Forward;

Procedure SkipStatement;
Var Depth:Integer; Control:String;
Begin
 If (P^.TokenKind='i') And ((P^.Token='if') Or (P^.Token='while') Or
  (P^.Token='for') Or (P^.Token='where')) Then Begin
  Control:=P^.Token; Next; Expect('('); Depth:=1;
  While Depth>0 Do Begin
   If P^.TokenKind=#0 Then ReportError('Condition non terminee');
   If P^.TokenKind='p' Then Begin
    If P^.Token='(' Then Inc(Depth) Else If P^.Token=')' Then Dec(Depth)
   End;
   Next
  End;
  SkipStatement;
  If ((Control='if') And (P^.Token='else')) Or
   ((Control='where') And (P^.Token='elsewhere')) Then Begin Next; SkipStatement End
 End Else If P^.Token='{' Then Begin
  Depth:=1; Next;
  While Depth>0 Do Begin
   If P^.TokenKind=#0 Then ReportError('Bloc non termine');
   If P^.TokenKind='p' Then Begin
    If P^.Token='{' Then Inc(Depth) Else If P^.Token='}' Then Dec(Depth)
   End;
   Next
  End
 End Else Begin
  Depth:=0;
  Repeat
   If P^.TokenKind=#0 Then ReportError('Instruction non terminee');
   If P^.TokenKind='p' Then Begin
    If (P^.Token=';') And (Depth=0) Then Begin Next; Break End;
    If (P^.Token='(') Or (P^.Token='{') Then Inc(Depth);
    If (P^.Token=')') Or (P^.Token='}') Then Dec(Depth)
   End;
   Next
  Until False
 End
End;

Procedure Assignment(Terminator:String);
Var Name,Attr,Op,S:String; Shape,SliceShape:TShape;
 I,N:Integer; Indices:PSelection; ExplicitShape,Sliced:Boolean; V:PValue;
Begin
 Name:=''; Attr:=''; Indices:=Nil; N:=0; Shape.Rank:=0; ExplicitShape:=False; Sliced:=False;
 If P^.Token='@' Then Begin Next; Attr:=Identifier End Else Begin
  Name:=Identifier;
  If P^.Token='@' Then Begin Next; Attr:=Identifier End
  Else If P^.Token='[' Then Begin
   Next; ExplicitShape:=True;
   Repeat
    If P^.Token='$' Then Next; S:=Identifier; I:=FindDim(S);
    If I<0 Then ReportError('Dimension inconnue: '+S); AppendDimension(Shape,I);
    If P^.Token<>',' Then Break; Next
   Until False;
   Expect(']')
  End Else If P^.Token='(' Then Begin
   I:=FindVar(Name); If I<0 Then ReportError('Variable inconnue: '+Name);
   ParseSelection(Vars^.Item[I]^.Value,Indices,SliceShape,N); Sliced:=True
  End
 End;
 Op:=P^.Token;
 If (Op='++') Or (Op='--') Then Begin
  Next; If Op='++' Then Op:='+=' Else Op:='-='; V:=Scalar(1)
 End Else Begin
  If (Op<>'=') And (Op<>'+=' ) And (Op<>'-=') And (Op<>'*=') And (Op<>'/=') Then ReportError('Affectation attendue');
  Next; V:=Expression(0)
 End;
 Expect(Terminator);
 If Attr<>'' Then Begin
  If Masked Then ReportError('Attribut interdit dans where');
  If Op<>'=' Then ReportError('Attribut: seul = est accepte');
  If Name='' Then SetAttribute(GlobalAttrs^,Attr,V) Else Begin
   I:=FindVar(Name); If I<0 Then ReportError('Variable inconnue: '+Name);
   SetAttribute(Vars^.Item[I]^.Attrs,Attr,V); Vars^.Item[I]^.Changed:=True
  End
 End Else AssignVariable(Name,Shape,ExplicitShape,Indices,N,Sliced,Op,V);
 FreeValue(V); If Indices<>Nil Then Dispose(Indices)
End;

Function ConditionValue:Boolean;
Var V:PValue; B:Boolean;
Begin V:=Expression(0); B:=NumericScalar(V)<>0; FreeValue(V); ConditionValue:=B End;

Procedure Statement(Execute:Boolean);
Var Name:String; I,D:Integer; N:LongInt; B,OldMasked,Unlimited:Boolean;
 V,ConditionMask,OldMask:PValue;
 CondState,UpdateState,BodyState,AfterState:TParserState;
Begin
 If Not Execute Then Begin SkipStatement; Exit End;
 Inc(Iterations); If Iterations>MaxIterations Then ReportError('Limite d''execution depassee');
 If P^.Token=';' Then Next
 Else If P^.Token='{' Then Begin
  Next;
  While P^.Token<>'}' Do Begin If P^.TokenKind=#0 Then ReportError('Bloc non termine'); Statement(True) End;
  Next
 End Else If P^.Token='if' Then Begin
  Next; Expect('('); B:=ConditionValue; Expect(')'); Statement(B);
  If P^.Token='else' Then Begin Next; Statement(Not B) End
 End Else If P^.Token='while' Then Begin
  Next; Expect('('); CondState:=P^;
  Repeat
   P^:=CondState; B:=ConditionValue; Expect(')'); Statement(B); AfterState:=P^;
   If Not B Then Break
  Until False;
  P^:=AfterState
 End Else If P^.Token='for' Then Begin
  Next; Expect('('); If P^.Token=';' Then Next Else Assignment(';'); CondState:=P^;
  D:=0;
  While Not ((P^.Token=';') And (D=0)) Do Begin
   If P^.TokenKind=#0 Then ReportError('Boucle for non terminee');
   If P^.Token='(' Then Inc(D) Else If P^.Token=')' Then Dec(D); Next
  End;
  Next; UpdateState:=P^; D:=0;
  While Not ((P^.Token=')') And (D=0)) Do Begin
   If P^.TokenKind=#0 Then ReportError('Boucle for non terminee');
   If P^.Token='(' Then Inc(D) Else If P^.Token=')' Then Dec(D); Next
  End;
  Next; BodyState:=P^;
  Repeat
   P^:=CondState; B:=True; If P^.Token<>';' Then B:=ConditionValue; Expect(';');
   P^:=BodyState; Statement(B); AfterState:=P^; If Not B Then Break;
   P^:=UpdateState; If P^.Token<>')' Then Assignment(')')
  Until False;
  P^:=AfterState
 End Else If P^.Token='where' Then Begin
  Next; Expect('('); ConditionMask:=Expression(0); Expect(')');
  If ConditionMask^.IsText Then ReportError('Masque numerique attendu');
  For I:=0 To ConditionMask^.Count-1 Do ConditionMask^.Data^[I]:=Ord(ConditionMask^.Data^[I]<>0);
  OldMask:=ActiveMask; OldMasked:=Masked; Masked:=True;
  If OldMasked Then ActiveMask:=Combine(OldMask,ConditionMask,'&&') Else ActiveMask:=CopyValue(ConditionMask);
  Statement(True); FreeValue(ActiveMask);
  If P^.Token='elsewhere' Then Begin
   Next; For I:=0 To ConditionMask^.Count-1 Do ConditionMask^.Data^[I]:=Ord(ConditionMask^.Data^[I]=0);
   If OldMasked Then ActiveMask:=Combine(OldMask,ConditionMask,'&&') Else ActiveMask:=CopyValue(ConditionMask);
   Statement(True); FreeValue(ActiveMask)
  End;
  FreeValue(ConditionMask); ActiveMask:=OldMask; Masked:=OldMasked
 End Else If P^.Token='defdim' Then Begin
  If Masked Then ReportError('defdim interdit dans where');
  Next; Expect('('); If P^.TokenKind<>'s' Then ReportError('Nom de dimension entre guillemets attendu');
  Name:=P^.Token; Next; Expect(','); N:=ParseInteger; Unlimited:=False;
  If N<=0 Then ReportError('Taille de dimension invalide');
  If P^.Token=',' Then Begin Next; Unlimited:=ParseInteger<>0 End;
  Expect(')'); Expect(';'); If FindDim(Name)>=0 Then ReportError('Dimension deja definie');
  I:=AddDimension(Name,N,Unlimited)
 End Else If P^.Token='print' Then Begin
  Next; Expect('('); V:=Expression(0); Expect(')'); Expect(';');
  If V^.IsText Then WriteLn(V^.Text) Else Begin
   For I:=0 To V^.Count-1 Do Begin If I>0 Then Write(' '); Write(V^.Data^[I]) End; WriteLn
  End;
  FreeValue(V)
 End Else Assignment(';')
End;

Procedure RunScript;
Begin
 FillChar(P^,SizeOf(TParserState),0); P^.Pos:=1; Iterations:=0; ScriptRunning:=True;
 Next; While P^.TokenKind<>#0 Do Statement(True); ScriptRunning:=False
End;

Function FileExists(Name:String):Boolean;
Var F:File; Code:Integer;
Begin
 Assign(F,Name); FileMode:=0;
 {$I-} Reset(F,1); Code:=IOResult;
 If Code=0 Then Begin Close(F); If IOResult<>0 Then Begin End End; {$I+}
 FileExists:=Code=0
End;

Function DeleteFile(Name:String):Boolean;
Var F:File; Code:Integer;
Begin Assign(F,Name); {$I-} Erase(F); Code:=IOResult; {$I+} DeleteFile:=Code=0 End;

Function RenameFile(OldName,NewName:String):Boolean;
Var F:File; Code:Integer;
Begin Assign(F,OldName); {$I-} Rename(F,NewName); Code:=IOResult; {$I+} RenameFile:=Code=0 End;

Function IncludeTrailingPathDelimiter(S:String):String;
Begin
 If S<>'' Then If Not (S[Length(S)] In ['/','\']) Then Begin
  If Length(S)=255 Then ReportError('Chemin trop long'); S:=S+PathSep
 End;
 IncludeTrailingPathDelimiter:=S
End;

Function ExtractFilePath(S:String):String;
Var I:Integer;
Begin I:=Length(S); While (I>0) And Not (S[I] In ['/','\']) Do Dec(I); ExtractFilePath:=Copy(S,1,I) End;

Function ExpandFileName(Name:String):String;
Var S,Root,Part,Cwd:String; I,J,Drive:Integer; Code:Integer;
Begin
 S:=Name;
 {$IFDEF MSDOS}
 For I:=1 To Length(S) Do If S[I]='/' Then S[I]:='\';
 {$ENDIF}
 {$IFDEF MSWINDOWS}
 For I:=1 To Length(S) Do If S[I]='/' Then S[I]:='\';
 {$ENDIF}
 {$I-} GetDir(0,Cwd); Code:=IOResult; {$I+}
 If Code<>0 Then ReportError('Repertoire courant inaccessible');
 If PathSep='\' Then Begin
  If (Length(S)>=2) And (S[2]=':') Then Begin
   If (Length(S)<3) Or (S[3]<>'\') Then Begin
    Drive:=Ord(UpCase(S[1]))-Ord('A')+1;
    {$I-} GetDir(Drive,Cwd); Code:=IOResult; {$I+}
    If Code<>0 Then ReportError('Lecteur inaccessible'); S:=IncludeTrailingPathDelimiter(Cwd)+Copy(S,3,255)
   End
  End Else If Copy(S,1,2)<>'\\' Then Begin
   If Copy(S,1,1)='\' Then S:=Copy(Cwd,1,2)+S Else S:=IncludeTrailingPathDelimiter(Cwd)+S
  End;
  If Copy(S,1,2)='\\' Then Begin
   I:=3; J:=0; While (I<=Length(S)) And (J<2) Do Begin If S[I]='\' Then Inc(J); Inc(I) End;
   Root:=Copy(S,1,I-1); Delete(S,1,I-1)
  End Else Begin Root:=Copy(S,1,3); Delete(S,1,3) End
 End Else Begin
  If Copy(S,1,1)<>'/' Then S:=IncludeTrailingPathDelimiter(Cwd)+S;
  Root:='/'; Delete(S,1,1)
 End;
 While S<>'' Do Begin
  I:=Pos(PathSep,S); If I=0 Then I:=Length(S)+1;
  Part:=Copy(S,1,I-1); Delete(S,1,I);
  If Part='..' Then Begin
   If Length(Root)>3 Then Begin
    If Root[Length(Root)]=PathSep Then Delete(Root,Length(Root),1);
    Root:=ExtractFilePath(Root)
   End
  End Else If (Part<>'') And (Part<>'.') Then Root:=IncludeTrailingPathDelimiter(Root)+Part
 End;
 ExpandFileName:=Root
End;

Function SameFileName(A,B:String):Boolean;
Begin
 If PathSep='\' Then SameFileName:=LowerCase(A)=LowerCase(B) Else SameFileName:=A=B
End;

Function TempFileName(Name:String):String;
Var I:Integer; S:String;
Begin
 I:=0;
 Repeat
  Inc(I); S:=ExtractFilePath(ExpandFileName(Name))+'NC'+IntToStr(Random(30000))+'.TMP';
  If I>1000 Then ReportError('Impossible de choisir un fichier temporaire')
 Until Not FileExists(S);
 TempFileName:=S
End;

Function Selected(I:Integer):Boolean;
Var J,D:Integer; V:PVariable; B:Boolean;
Begin
 V:=Vars^.Item[I]; B:=Not OnlyChanged Or V^.Changed Or V^.Keep;
 If Not B And Coordinates Then Begin
  D:=FindDim(V^.Name);
  If (D>=0) And (V^.Value^.Shape.Rank=1) Then If V^.Value^.Shape.ID[0]=D Then
   For J:=0 To Vars^.Count-1 Do If Vars^.Item[J]^.Changed Then
    If HasDimension(Vars^.Item[J]^.Value^.Shape,D) Then B:=True
 End;
 Selected:=B
End;

Function IsRecord(V:PVariable):Boolean;
Var B:Boolean;
Begin
 B:=False; If V^.Value^.Shape.Rank>0 Then B:=Dims^.Item[V^.Value^.Shape.ID[0]].Unlimited;
 IsRecord:=B
End;

Function SlabCount(V:PVariable):Integer;
Var I,N:Integer;
Begin
 If Not IsRecord(V) Then N:=V^.Value^.Count Else Begin
  N:=1; For I:=1 To V^.Value^.Shape.Rank-1 Do N:=N*Dims^.Item[V^.Value^.Shape.ID[I]].Size
 End;
 SlabCount:=N
End;

Procedure WriteHeader(Var F:TStream; Var Chosen:TIndexList; Count:Integer; NumRecords:LongInt);
Var I,J:Integer; Magic:TByte8; V:PVariable;
Begin
 Magic[0]:=67; Magic[1]:=68; Magic[2]:=70; Magic[3]:=FormatVersion;
 StreamWrite(F,Magic,4); WriteUInt(F,NumRecords,4);
 If Dims^.Count=0 Then WriteUInt(F,0,4) Else WriteUInt(F,10,4); WriteUInt(F,Dims^.Count,4);
 For I:=0 To Dims^.Count-1 Do Begin
  WriteName(F,Dims^.Item[I].Name);
  If Dims^.Item[I].Unlimited Then WriteUInt(F,0,4) Else WriteUInt(F,Dims^.Item[I].Size,4)
 End;
 WriteAttrs(F,GlobalAttrs^);
 If Count=0 Then WriteUInt(F,0,4) Else WriteUInt(F,11,4); WriteUInt(F,Count,4);
 For I:=0 To Count-1 Do Begin
  V:=Vars^.Item[Chosen[I]]; WriteName(F,V^.Name); WriteUInt(F,V^.Value^.Shape.Rank,4);
  For J:=0 To V^.Value^.Shape.Rank-1 Do WriteUInt(F,V^.Value^.Shape.ID[J],4);
  WriteAttrs(F,V^.Attrs); WriteUInt(F,V^.Kind,4); WriteUInt(F,V^.DiskSize,4);
  If FormatVersion=2 Then WriteUInt(F,0,4); WriteUInt(F,V^.Offset,4)
 End
End;

Procedure SaveNetCDF(Name:String);
Var F,M:TStream; Chosen:TIndexList; I,J,R,Count,N,RecordVars,UnlimitedID:Integer;
 NumRecords,Posn,RecSize,RecordStart,At,Bytes:LongInt;
 TempName,BackupName:String; V:PVariable; Zero:Byte;
Begin
 If FileExists(Name) And Not (Overwrite Or AppendMode) Then ReportError('La sortie existe deja; utiliser -O ou -A');
 UnlimitedID:=-1; NumRecords:=0; RecordVars:=0; Count:=0;
 For I:=0 To Dims^.Count-1 Do If Dims^.Item[I].Unlimited Then Begin
  If UnlimitedID>=0 Then ReportError('Une seule dimension illimitee est permise');
  UnlimitedID:=I; NumRecords:=Dims^.Item[I].Size
 End;
 For I:=0 To Vars^.Count-1 Do If Selected(I) Then Begin
  Chosen[Count]:=I; Inc(Count); V:=Vars^.Item[I];
  For J:=1 To V^.Value^.Shape.Rank-1 Do If V^.Value^.Shape.ID[J]=UnlimitedID Then
   ReportError('Dimension illimitee: premiere position requise');
  If IsRecord(V) Then Inc(RecordVars);
  Bytes:=LongInt(SlabCount(V))*TypeSize(V^.Kind); V^.DiskSize:=((Bytes+3) Div 4)*4
 End;
 StreamInit(M,True); WriteHeader(M,Chosen,Count,NumRecords);
 Posn:=((M.Cursor+HeaderPad+3) Div 4)*4; StreamClose(M);
 For I:=0 To Count-1 Do Begin
  V:=Vars^.Item[Chosen[I]]; If Not IsRecord(V) Then Begin V^.Offset:=Posn; Inc(Posn,V^.DiskSize) End
 End;
 RecordStart:=Posn; RecSize:=0;
 For I:=0 To Count-1 Do Begin
  V:=Vars^.Item[Chosen[I]]; If IsRecord(V) Then Begin
   V^.Offset:=RecordStart+RecSize;
   If RecordVars=1 Then RecSize:=LongInt(SlabCount(V))*TypeSize(V^.Kind) Else Inc(RecSize,V^.DiskSize)
  End
 End;
 If NumRecords>0 Then If RecSize>(2147483647-RecordStart) Div NumRecords Then ReportError('Sortie superieure a 2 Go');
 TempName:=Name; If Not NoTemp Then Begin TempName:=TempFileName(Name); PendingOutput:=TempName End;
 StreamOpen(F,TempName,True); WriteHeader(F,Chosen,Count,NumRecords); Zero:=0;
 { Explicit zero filling also works on the DOS file system. }
 While F.Cursor<RecordStart Do StreamWrite(F,Zero,1);
 For I:=0 To Count-1 Do Begin
  V:=Vars^.Item[Chosen[I]]; If Not IsRecord(V) Then Begin
   StreamSeek(F,V^.Offset);
   For J:=0 To V^.Value^.Count-1 Do WriteNumber(F,V^.Kind,V^.Value^.Data^[J]);
   WritePadding(F,LongInt(V^.Value^.Count)*TypeSize(V^.Kind))
  End
 End;
 For R:=0 To NumRecords-1 Do For I:=0 To Count-1 Do Begin
  V:=Vars^.Item[Chosen[I]]; If IsRecord(V) Then Begin
   N:=SlabCount(V); At:=V^.Offset+LongInt(R)*RecSize; StreamSeek(F,At);
   For J:=0 To N-1 Do WriteNumber(F,V^.Kind,V^.Value^.Data^[R*N+J]);
   If RecordVars<>1 Then WritePadding(F,LongInt(N)*TypeSize(V^.Kind))
  End
 End;
 StreamClose(F);
 If Not NoTemp Then Begin
  If FileExists(Name) Then Begin
   BackupName:=TempFileName(Name);
   If Not RenameFile(Name,BackupName) Then ReportError('Impossible de sauvegarder la sortie');
   If Not RenameFile(TempName,Name) Then Begin
    If Not RenameFile(BackupName,Name) Then ReportError('Original conserve dans '+BackupName);
    ReportError('Impossible d''installer la sortie')
   End;
   If Not DeleteFile(BackupName) Then WriteLn('NCAP2: sauvegarde conservee: ',BackupName)
  End Else If Not RenameFile(TempName,Name) Then ReportError('Impossible d''installer la sortie')
 End;
 PendingOutput:=''
End;

Procedure AddScriptText(S:String);
Var I:Integer;
Begin
 If ScriptLen+Length(S)>MaxScript Then ReportError('Script superieur a 60000 octets');
 For I:=1 To Length(S) Do Begin Inc(ScriptLen); Script^[ScriptLen]:=S[I] End
End;

Procedure AddScriptFile(Name:String);
Var F:TStream; N:LongInt;
Begin
 StreamOpen(F,Name,False); N:=StreamSize(F);
 If N>MaxScript-ScriptLen-1 Then ReportError('Script superieur a 60000 octets');
 If N>0 Then ReadExact(F,Script^[ScriptLen+1],N);
 Inc(ScriptLen,N); AddScriptText(#10); StreamClose(F)
End;

Procedure Help;
Begin
 WriteLn('NCAP2 - Cette commande permet de lancer le processeur arithmetique NetCDF.');
 WriteLn;
 WriteLn('Syntaxe: NCAP2 [options] [entree.nc] sortie.nc');
 WriteLn;
 WriteLn(' -s texte           ajoute ce texte au script');
 WriteLn(' -S script.nco      lit le fichier contenant le script a executer');
 WriteLn(' -o sortie          indique le fichier de sortie');
 WriteLn(' -O                 autorise l''ecrasement de la sortie existante');
 WriteLn(' -A                 fusionne avec la sortie existante');
 WriteLn(' -3                 produit un fichier NetCDF classique CDF-1');
 WriteLn(' -6                 produit un fichier NetCDF CDF-2 (64-bit offset)');
 WriteLn(' --fl_fmt=format    choisit classic ou 64bit_offset');
 WriteLn(' -v                 conserve les variables affectees et leurs coordonnees');
 WriteLn(' -C                 exclut les coordonnees ajoutees automatiquement');
 WriteLn(' -c                 inclut les coordonnees associees');
 WriteLn(' -F                 utilise des indices commencant a 1');
 WriteLn(' -h                 desactive l''ajout de l''historique');
 WriteLn(' -H                 accepte sans effet dans cette implementation');
 WriteLn(' -p chemin          indique le chemin des fichiers d''entree');
 WriteLn(' -D niveau          definit le niveau des informations de debogage');
 WriteLn(' -t nombre          definit le nombre de threads (1 uniquement)');
 WriteLn(' --gaa nom=valeur   ajoute ou remplace un attribut global texte');
 WriteLn(' --gad nom[,nom]    supprime les attributs globaux indiques');
 WriteLn(' --hdr_pad octets   reserve de l''espace dans l''en-tete (1 Mo maximum)');
 WriteLn(' --no_tmp_fl        ecrit directement dans la sortie sans fichier temporaire');
 WriteLn(' --ram_all          accepte, les tableaux etant deja traites en memoire');
 WriteLn(' --version          affiche la version du programme');
 WriteLn(' -r                 affiche la version du programme');
 WriteLn(' --help             affiche cette aide');
 WriteLn;
 WriteLn(' defdim("x",5); x[$x]=array(0,1,$x); y=x*2; y@units="K";');
 WriteLn(' Listes {1,2,3}, tranches x(0:4:2), if/else, while, for, where/elsewhere');
 WriteLn(' + - * / % ^, comparaisons, && || !, += -= *= /= ++ --');
 WriteLn(' abs sqrt sqr exp ln log log10 sin cos tan asin acos atan atan2');
 WriteLn(' sinh cosh tanh floor ceil round pow isnan isfinite');
 WriteLn(' sum total avg mean min max rms size, reductions par dimensions: a.avg($x)');
 WriteLn(' byte short int long float double; nouvelles variables en double par defaut');
 WriteLn(' Limites DOS: 4096 elements/tableau, rang 8, 64 variables, 128 dimensions,');
 WriteLn(' 128 attributs/objet, script 60000 octets, texte 255, noms 63 caracteres.');
 WriteLn(' La memoire conventionnelle disponible peut imposer une limite inferieure.');
 WriteLn(' CDF-1/CDF-2: fichiers et offsets limites a 2 Go, types classiques seulement.');
 WriteLn(' Pas de HDF4/HDF5/CDF-5, compression, reseau, threads ni syntaxe -f.');
 WriteLn(' Pas de traitement automatique de _FillValue ou scale_factor/add_offset.');
 WriteLn(' where evalue les expressions integralement; nouvelles cases hors masque a 0.');
 WriteLn(' Cette implementation ne couvre pas tout le langage NCO.');
End;

Function OptionValue(Var I:Integer; InlineValue:String; HasInline:Boolean):String;
Begin
 If HasInline Then OptionValue:=InlineValue Else Begin
  Inc(I); If I>ParamCount Then ReportError('Valeur d''option manquante'); OptionValue:=ParamStr(I)
 End
End;

Procedure ParseOptions;
Var I,J,FileCount:Integer; A,Opt,InlineValue,FirstFile,SecondFile:String;
 HasInline,EndOptions,VersionOnly:Boolean; N:LongInt;
Begin
 FileCount:=0; FirstFile:=''; SecondFile:=''; I:=1; EndOptions:=False; VersionOnly:=False;
 While I<=ParamCount Do Begin
  A:=ParamStr(I); Opt:=A; InlineValue:=''; HasInline:=False;
  If A='--' Then EndOptions:=True
  Else If Not EndOptions And (Copy(A,1,1)='-') Then Begin
   If Copy(A,1,2)='--' Then Begin
    J:=Pos('=',A); If J>0 Then Begin Opt:=Copy(A,1,J-1); InlineValue:=Copy(A,J+1,255); HasInline:=True End
   End Else If Length(A)>2 Then If A[2] In ['s','S','o','p','l','D','L','t'] Then Begin
    Opt:=Copy(A,1,2); InlineValue:=Copy(A,3,255); HasInline:=True
   End;
   If (Opt='--help') Or (Opt='-?') Then Begin Help; ReleaseState; Halt(0) End
   Else If (Opt='--version') Or (Opt='-r') Then VersionOnly:=True
   Else If (Opt='-s') Or (Opt='--script') Or (Opt='--spt') Then Begin
    AddScriptText(OptionValue(I,InlineValue,HasInline)); AddScriptText(#10)
   End Else If (Opt='-S') Or (Opt='--script-file') Or (Opt='--fl_spt') Or (Opt='--nco_script') Then
    AddScriptFile(OptionValue(I,InlineValue,HasInline))
   Else If (Opt='-o') Or (Opt='--output') Then OutputName:=OptionValue(I,InlineValue,HasInline)
   Else If Opt='-p' Then InputPath:=OptionValue(I,InlineValue,HasInline)
   Else If Opt='-O' Then Overwrite:=True Else If Opt='-A' Then AppendMode:=True
   Else If Opt='-v' Then OnlyChanged:=True Else If Opt='-C' Then Coordinates:=False
   Else If Opt='-c' Then Coordinates:=True Else If Opt='-F' Then FortranIndex:=True
   Else If Opt='-h' Then History:=False Else If Opt='-H' Then Begin End
   Else If Opt='-3' Then FormatName:='classic' Else If Opt='-6' Then FormatName:='64bit_offset'
   Else If Opt='--fl_fmt' Then FormatName:=OptionValue(I,InlineValue,HasInline)
   Else If Opt='--no_tmp_fl' Then NoTemp:=True Else If Opt='--ram_all' Then Begin End
   Else If Opt='--gaa' Then ListAdd(AddAttrs^,OptionValue(I,InlineValue,HasInline))
   Else If Opt='--gad' Then ListAdd(DeleteAttrs^,OptionValue(I,InlineValue,HasInline))
   Else If (Opt='-D') Or (Opt='-t') Or (Opt='-L') Or (Opt='--hdr_pad') Then Begin
    N:=IntegerText(OptionValue(I,InlineValue,HasInline));
    If Opt='-D' Then Begin If (N<0) Or (N>32767) Then ReportError('Niveau de debug invalide'); DebugLevel:=N End
    Else If Opt='-t' Then Begin If N<>1 Then ReportError('Seul -t 1 est pris en charge') End
    Else If Opt='-L' Then Begin If N<>0 Then ReportError('Compression non implementee') End
    Else Begin If (N<0) Or (N>1048576) Then ReportError('--hdr_pad hors limites (1 Mo)'); HeaderPad:=N End
   End Else ReportError('Option inconnue ou non implementee: '+Opt)
  End Else Begin
   Inc(FileCount); If FileCount=1 Then FirstFile:=A Else If FileCount=2 Then SecondFile:=A Else
    ReportError('Trop de fichiers')
  End;
  Inc(I)
 End;
 If VersionOnly Then Begin WriteLn('NCAP2.PAS 2.0 - Turbo Pascal 7 / Free Pascal, CDF-1/CDF-2'); ReleaseState;
  Halt(0) End;
 If OutputName<>'' Then Begin
  If FileCount>1 Then ReportError('Avec -o: une seule entree permise'); If FileCount=1 Then InputName:=FirstFile
 End Else Begin
  If FileCount=0 Then ReportError('Indiquer [entree] sortie (voir --help)');
  If FileCount=1 Then OutputName:=FirstFile Else Begin InputName:=FirstFile; OutputName:=SecondFile End
 End;
 If (InputPath<>'') And (InputName<>'') Then InputName:=IncludeTrailingPathDelimiter(InputPath)+InputName;
 If Pos('://',InputName)>0 Then ReportError('Entrees reseau non implementees');
 If NoTemp And (InputName<>'') Then If SameFileName(ExpandFileName(InputName),ExpandFileName(OutputName)) Then
  ReportError('--no_tmp_fl interdit avec entree=sortie')
End;

Procedure UpdateGlobalAttrs;
Var I,J,K,N,OldSize:Integer; S,Name,Summary:String; V:PValue; Old:PBytes; A:PAttribute;
Begin
 For I:=0 To DeleteAttrs^.Count-1 Do Begin
  S:=DeleteAttrs^.Item[I]^+',';
  Repeat
   J:=Pos(',',S); If J=0 Then Break; Name:=Copy(S,1,J-1); Delete(S,1,J);
   K:=FindAttr(GlobalAttrs^,Name);
   If K>=0 Then Begin
    A:=GlobalAttrs^.Item[K]; If A^.Data<>Nil Then FreeMem(A^.Data,A^.Bytes); Dispose(A);
    For N:=K To GlobalAttrs^.Count-2 Do GlobalAttrs^.Item[N]:=GlobalAttrs^.Item[N+1]; Dec(GlobalAttrs^.Count)
   End
  Until S=''
 End;
 For I:=0 To AddAttrs^.Count-1 Do Begin
  S:=AddAttrs^.Item[I]^; J:=Pos('=',S); If J<2 Then ReportError('--gaa attend nom=valeur');
  V:=NewValue(0); V^.IsText:=True; V^.Text:=Copy(S,J+1,255);
  SetAttribute(GlobalAttrs^,Copy(S,1,J-1),V); FreeValue(V)
 End;
 If History Then Begin
  Summary:='NCAP2.PAS';
  For I:=1 To ParamCount Do If Length(Summary)+Length(ParamStr(I))+1<=255 Then Summary:=Summary+' '+ParamStr(I);
  K:=FindAttr(GlobalAttrs^,'history'); Old:=Nil; OldSize:=0;
  If K>=0 Then If GlobalAttrs^.Item[K]^.Kind=2 Then Begin
   Old:=GlobalAttrs^.Item[K]^.Data; OldSize:=GlobalAttrs^.Item[K]^.Bytes; GlobalAttrs^.Item[K]^.Data:=Nil
  End;
  K:=AttrSlot(GlobalAttrs^,'history'); A:=GlobalAttrs^.Item[K]; N:=Length(Summary);
  If OldSize>0 Then Inc(N,OldSize+1);
  If N>MaxRaw Then ReportError('Historique trop grand');
  A^.Kind:=2; A^.Count:=N; A^.Bytes:=N; CheckHeap(N); GetMem(A^.Data,N);
  Move(Summary[1],A^.Data^,Length(Summary));
  If OldSize>0 Then Begin
   A^.Data^[Length(Summary)]:=10; Move(Old^,A^.Data^[Length(Summary)+1],OldSize); FreeMem(Old,OldSize)
  End
 End
End;

Var I:Integer;
BEGIN
 PathSep:={$IFDEF MSDOS}'\'{$ELSE}{$IFDEF MSWINDOWS}'\'{$ELSE}'/'{$ENDIF}{$ENDIF};
 Dims:=Nil; Vars:=Nil; GlobalAttrs:=Nil; AddAttrs:=Nil; DeleteAttrs:=Nil; P:=Nil; Script:=Nil;
 ActiveMask:=Nil; ScriptLen:=0; PendingOutput:=''; InputName:=''; OutputName:=''; InputPath:=''; FormatName:='';
 FillChar(OpenStreams,SizeOf(OpenStreams),0);
 Overwrite:=False; AppendMode:=False; OnlyChanged:=False; Coordinates:=True; History:=True;
 FortranIndex:=False; NoTemp:=False; ScriptRunning:=False; Masked:=False;
 FormatVersion:=1; DebugLevel:=0; HeaderPad:=0; Iterations:=0;
 Randomize; AllocateState;
 If ParamCount=0 Then Begin Help; ReleaseState; Halt(0) End;
 ParseOptions;
 If FileExists(OutputName) And Not (Overwrite Or AppendMode) Then
  ReportError('La sortie existe deja; utiliser -O ou -A');
 If AppendMode And FileExists(OutputName) Then Begin
  LoadNetCDF(OutputName,False); For I:=0 To Vars^.Count-1 Do Vars^.Item[I]^.Keep:=True
 End;
 If InputName<>'' Then LoadNetCDF(InputName,AppendMode And FileExists(OutputName));
 If FormatName<>'' Then Begin
  If (FormatName='classic') Or (FormatName='netcdf3') Or (FormatName='1') Then FormatVersion:=1
  Else If (FormatName='64bit_offset') Or (FormatName='64bit') Or (FormatName='2') Then FormatVersion:=2
  Else ReportError('Format non pris en charge: '+FormatName)
 End;
 If DebugLevel>0 Then WriteLn('NCAP2: ',Dims^.Count,' dimensions, ',Vars^.Count,' variables');
 RunScript; UpdateGlobalAttrs; SaveNetCDF(OutputName); ReleaseState
END.
