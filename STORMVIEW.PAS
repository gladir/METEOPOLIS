{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/meteopolis)
  @abstract(Target: Turbo Pascal 7, Free Pascal)
  @description: Clone de l'application StormView Radar : visualisation
                meteorologique avec radar anime, alertes meteo, foudre,
                stations, suivi de cellules orageuses et mesures.
                Sources prises en charge (profils) : MRMS, NEXRAD Niveau II,
                NOAA nowCOAST, HRRR, RainViewer et ECCC GeoMet.
}

Program STORMVIEW;

{$IFNDEF FPC}
 {$M 16384,0,655360}
{$ENDIF}

Uses {$IFDEF FPC}
      {$IFDEF UNIX}CThreads,{$ENDIF}
      Crt,PtcGraph,PtcCrt,PtcMouse,Dos
     {$ELSE}
      Crt,Graph,Dos
     {$ENDIF};

Const
 MaxCols=120;      { Taille maximale de la grille radar }
 MaxRows=80;
 MaxFrames=24;     { Nombre maximal d'images dans une sequence }
 MaxAlerts=16;
 MaxPoly=20;
 MaxStations=12;
 MaxStrikes=300;
 MaxLieux=10;
 MaxCells=12;
 MaxCoast=1100;
 NbSrc=6;
 NbKind=10;
 NbMenu=6;
 NbCity=94;
 CoastCount=56;

 { Disposition de l'ecran (640x480) }
 MenuH=14;
 ToolY1=15;
 ToolY2=36;
 PanY1=38;
 PanY2=437;
 LeftX2=127;
 MapX1=129;
 MapX2=478;
 MapY1=38;
 MapY2=437;
 MapW=350;
 MapH=400;
 RightX1=481;
 TimeY1=439;
 TimeY2=458;
 StatY1=460;

 CellLvl=20;       { Niveau minimal (40 dBZ) d'un noyau orageux }

 {$IFDEF UNIX}
 DirSep='/';
 {$ELSE}
 DirSep='\';
 {$ENDIF}

Type
 TGrid=Array[0..MaxRows-1,0..MaxCols-1] of Byte;
 PGrid=^TGrid;
 TBytes=Array[0..MaxRows*MaxCols-1] of Byte;
 PBytes=^TBytes;
 TWords=Array[0..MaxRows*MaxCols-1] of Word;
 PWords=^TWords;
 TPolar=Array[0..57599] of Byte;
 PPolar=^TPolar;

 TSrcInfo=Record
  nm:String[12];
  nom:String[22];
  prod:String[30];
  res:String[8];
  pas:Integer;
  fmt:String[64];
  url:String[96];
 End;

 TKindInfo=Record
  cd:String[3];
  nom:String[18];
  col:Byte;
 End;

 TFrame=Record
  g:PGrid;
  tm:Integer;
 End;

 TCell=Record
  x,y:Real;
  mx:Byte;
  n:Integer;
 End;

 TAlert=Record
  kind:Byte;
  t0,t1:Integer;
  ti:String[34];
  tx:String[200];
  n:Integer;
  px,py:Array[0..MaxPoly-1] of Real;
 End;

 TStation=Record
  id:String[6];
  x,y:Real;
  t:Real;
  dr,v,r,p:Integer;
 End;

 TStrike=Record
  t:Integer;
  x,y:Real;
 End;

 TLieu=Record
  nm:String[16];
  x,y:Real;
 End;

 TCity=Record
  nm:String[14];
  lo,la:Integer;
 End;

 TItem=Record
  cap:String[28];
  id:Integer;
 End;

 TMenu=Record
  tt:String[10];
  n,x,w:Integer;
  it:Array[0..13] of TItem;
 End;

Const
 Src:Array[0..NbSrc-1] of TSrcInfo=(
  (nm:'MRMS'; nom:'NOAA MRMS'; prod:'MergedReflectivityQCComposite'; res:'1 km'; pas:2;
   fmt:'GRIB2 (.gz) -> gdal_translate -of AAIGrid -> .ASC';
   url:'https://mrms.ncep.noaa.gov/data/2D/MergedReflectivityQCComposite/'),
  (nm:'NEXRAD'; nom:'NEXRAD Niveau II'; prod:'Reflectivite de base (sweep)'; res:'250 m'; pas:5;
   fmt:'Archive II (.bz2) -> balayage polaire -> .SVR (RADAR/RADIAUX)';
   url:'https://noaa-nexrad-level2.s3.amazonaws.com/AAAA/MM/JJ/STATION/'),
  (nm:'NOWCOAST'; nom:'NOAA nowCOAST'; prod:'radar_meteo_imagery_nexrad'; res:'1 km'; pas:5;
   fmt:'WMS/ArcGIS (images) -> valeurs dBZ -> .ASC ou .SVR';
   url:'https://nowcoast.noaa.gov/geoserver/observations/weather_radar/wms'),
  (nm:'HRRR'; nom:'NOAA HRRR (prevision)'; prod:'REFC reflectivite composite'; res:'3 km'; pas:60;
   fmt:'GRIB2 (REFC) -> wgrib2/gdal_translate -of AAIGrid -> .ASC';
   url:'https://noaa-hrrr-bdp-pds.s3.amazonaws.com/hrrr.AAAAMMJJ/conus/'),
  (nm:'RAINVIEWER'; nom:'RainViewer'; prod:'Mosaique radar mondiale'; res:'1 km'; pas:10;
   fmt:'Tuiles PNG -> valeurs dBZ -> .ASC ou .SVR';
   url:'https://api.rainviewer.com/public/weather-maps.json'),
  (nm:'GEOMET'; nom:'ECCC GeoMet'; prod:'RADAR_1KM_RRAI (pluie mm/h)'; res:'1 km'; pas:6;
   fmt:'WMS/WCS -> GeoTIFF -> gdal_translate -of AAIGrid (option MMH)';
   url:'https://geo.weather.gc.ca/geomet?SERVICE=WMS&LAYERS=RADAR_1KM_RRAI')
 );

 Kinds:Array[0..NbKind-1] of TKindInfo=(
  (cd:'TOR'; nom:'Tornade'; col:12),
  (cd:'FFW'; nom:'Crue eclair'; col:10),
  (cd:'SVR'; nom:'Orage violent'; col:14),
  (cd:'SMW'; nom:'Marine speciale'; col:11),
  (cd:'WSW'; nom:'Tempete hivernale'; col:9),
  (cd:'HWW'; nom:'Vents forts'; col:13),
  (cd:'FLW'; nom:'Inondation'; col:2),
  (cd:'RFW'; nom:'Feu meteo'; col:6),
  (cd:'EHW'; nom:'Chaleur extreme'; col:5),
  (cd:'VEI'; nom:'Veille orage'; col:1)
 );

 { Couleurs de la legende radar : seuil en dBZ, couleur }
 LegDbz:Array[0..10] of Integer=(10,20,30,35,40,45,50,55,60,65,70);
 LegCol:Array[0..10] of Byte=(9,3,2,10,14,6,12,4,5,13,15);

 BtnTxt:Array[0..5] of String[8]=('Radar','Foudre','Alertes','Couches','Mesure','Suivi');

 Cities:Array[0..NbCity-1] of TCity=(
  (nm:'Montreal'; lo:-7357; la:4550), (nm:'Quebec'; lo:-7121; la:4681),
  (nm:'Ottawa'; lo:-7570; la:4542), (nm:'Toronto'; lo:-7938; la:4365),
  (nm:'Winnipeg'; lo:-9714; la:4990), (nm:'Halifax'; lo:-6357; la:4465),
  (nm:'Sherbrooke'; lo:-7190; la:4540), (nm:'Trois-Rivieres'; lo:-7255; la:4635),
  (nm:'Saguenay'; lo:-7107; la:4843), (nm:'Rimouski'; lo:-6852; la:4845),
  (nm:'Gaspe'; lo:-6448; la:4883), (nm:'Sept-Iles'; lo:-6638; la:5020),
  (nm:'Val-d''Or'; lo:-7776; la:4810), (nm:'Thunder Bay'; lo:-8925; la:4838),
  (nm:'Sudbury'; lo:-8099; la:4649), (nm:'London'; lo:-8125; la:4298),
  (nm:'Windsor'; lo:-8303; la:4231), (nm:'Kingston'; lo:-7650; la:4423),
  (nm:'Fredericton'; lo:-6665; la:4596), (nm:'Charlottetown'; lo:-6313; la:4623),
  (nm:'Oklahoma City'; lo:-9752; la:3547), (nm:'Tulsa'; lo:-9599; la:3615),
  (nm:'Wichita'; lo:-9734; la:3769), (nm:'Dallas'; lo:-9680; la:3278),
  (nm:'Fort Worth'; lo:-9733; la:3275), (nm:'Houston'; lo:-9537; la:2976),
  (nm:'San Antonio'; lo:-9849; la:2942), (nm:'Austin'; lo:-9774; la:3027),
  (nm:'Kansas City'; lo:-9458; la:3910), (nm:'Chicago'; lo:-8763; la:4188),
  (nm:'Saint-Louis'; lo:-9020; la:3863), (nm:'Memphis'; lo:-9005; la:3515),
  (nm:'Little Rock'; lo:-9229; la:3475), (nm:'Amarillo'; lo:-10183; la:3522),
  (nm:'Lubbock'; lo:-10186; la:3358), (nm:'Denver'; lo:-10499; la:3974),
  (nm:'Minneapolis'; lo:-9327; la:4498), (nm:'Detroit'; lo:-8305; la:4233),
  (nm:'Cleveland'; lo:-8169; la:4150), (nm:'New York'; lo:-7401; la:4071),
  (nm:'Boston'; lo:-7106; la:4236), (nm:'Philadelphie'; lo:-7517; la:3995),
  (nm:'Washington'; lo:-7704; la:3891), (nm:'Atlanta'; lo:-8439; la:3375),
  (nm:'Miami'; lo:-8019; la:2576), (nm:'Orlando'; lo:-8138; la:2854),
  (nm:'Tampa'; lo:-8246; la:2795), (nm:'Jacksonville'; lo:-8166; la:3033),
  (nm:'Nlle-Orleans'; lo:-9007; la:2995), (nm:'Nashville'; lo:-8678; la:3616),
  (nm:'Charlotte'; lo:-8084; la:3523), (nm:'Pittsburgh'; lo:-7999; la:4044),
  (nm:'Buffalo'; lo:-7888; la:4289), (nm:'Burlington'; lo:-7321; la:4448),
  (nm:'Portland'; lo:-7026; la:4366), (nm:'Tallahassee'; lo:-8428; la:3044),
  (nm:'Mobile'; lo:-8804; la:3069), (nm:'Shreveport'; lo:-9375; la:3252),
  (nm:'Baton Rouge'; lo:-9115; la:3045), (nm:'Corpus Christi'; lo:-9739; la:2780),
  (nm:'Brownsville'; lo:-9750; la:2590), (nm:'Albuquerque'; lo:-10665; la:3508),
  (nm:'Wichita Falls'; lo:-9849; la:3391), (nm:'Springfield'; lo:-9330; la:3720),
  (nm:'Des Moines'; lo:-9361; la:4160), (nm:'Omaha'; lo:-9594; la:4126),
  (nm:'Indianapolis'; lo:-8616; la:3977), (nm:'Columbus'; lo:-8300; la:3996),
  (nm:'Louisville'; lo:-8575; la:3825), (nm:'Raleigh'; lo:-7864; la:3578),
  (nm:'Norfolk'; lo:-7628; la:3685), (nm:'Savannah'; lo:-8110; la:3208),
  (nm:'La Havane'; lo:-8237; la:2313), (nm:'Monterrey'; lo:-10032; la:2567),
  (nm:'Cancun'; lo:-8685; la:2116), (nm:'Key West'; lo:-8180; la:2455),
  (nm:'Jackson'; lo:-9018; la:3230), (nm:'Birmingham'; lo:-8680; la:3350),
  (nm:'Duluth'; lo:-9210; la:4678), (nm:'Green Bay'; lo:-8802; la:4451),
  (nm:'Milwaukee'; lo:-8791; la:4304), (nm:'Grand Rapids'; lo:-8567; la:4296),
  (nm:'Rochester'; lo:-7762; la:4316), (nm:'Albany'; lo:-7376; la:4265),
  (nm:'Hartford'; lo:-7267; la:4176), (nm:'Syracuse'; lo:-7615; la:4305),
  (nm:'Fargo'; lo:-9679; la:4688), (nm:'Pensacola'; lo:-8722; la:3042),
  (nm:'Daytona'; lo:-8102; la:2921), (nm:'Fort Myers'; lo:-8187; la:2664),
  (nm:'Gainesville'; lo:-8233; la:2965), (nm:'Charleston'; lo:-7994; la:3278),
  (nm:'Lafayette'; lo:-9202; la:3022), (nm:'Laredo'; lo:-9951; la:2750)
 );

 { Contours simplifies (degres lon,lat). '/' au debut = nouvelle polyligne }
 CoastS:Array[0..56] of String[110]=(
  '/-123.3,49.0 -95.2,49.0 -95.2,49.4 -94.8,49.3 -94.6,48.7 -93.0,48.6 -91.5,48.1 -90.0,48.1 -89.6,48.0',
  '/-89.6,48.0 -88.4,48.3 -86.6,48.5 -84.9,47.0 -84.4,46.5 -83.6,46.1 -83.0,45.3 -82.5,45.3 -82.1,43.6',
  ' -82.5,43.0 -82.6,42.6 -83.1,42.3 -83.1,42.0 -82.5,41.7 -81.0,42.2 -79.0,42.8 -79.0,43.3 -77.6,43.6',
  ' -76.5,43.6 -76.3,44.1 -75.3,44.8 -74.7,45.0 -71.5,45.0 -70.8,45.4 -70.3,46.4 -70.0,46.7 -69.2,47.45',
  ' -68.3,47.35 -67.8,47.07 -67.8,45.7 -67.4,45.2 -67.0,44.9',
  '/-117.1,32.5 -114.7,32.7 -111.1,31.3 -108.2,31.3 -108.2,31.8 -106.5,31.8 -104.9,30.6 -104.5,29.6',
  ' -103.2,28.98 -102.4,29.8 -101.4,29.8 -100.6,28.9 -99.5,27.5 -99.1,26.4 -97.15,25.95',
  '/-124.7,48.4 -124.1,46.9 -124.0,46.2 -124.1,44.0 -124.5,42.8 -124.2,41.8 -124.4,40.4 -123.8,39.4',
  ' -122.5,37.8 -121.9,36.6 -120.6,34.6 -119.2,34.1 -118.5,34.0 -117.2,32.7 -117.1,32.5',
  '/-117.1,32.5 -116.0,30.7 -114.8,28.0 -112.3,24.8 -110.0,22.9 -109.5,23.5 -110.3,24.2 -111.3,25.9',
  ' -112.8,28.0 -114.6,31.0 -114.8,31.8 -113.0,31.0 -112.2,29.0 -110.6,27.8 -109.4,26.3 -108.6,25.2',
  ' -107.2,23.6 -105.6,21.9 -105.3,20.5',
  '/-97.15,25.95 -97.4,27.5 -96.4,28.3 -95.0,29.2 -93.8,29.7 -92.0,29.5 -90.5,29.1 -89.4,29.0',
  ' -89.0,29.2 -89.4,30.0 -88.4,30.3 -87.5,30.3 -86.0,30.0 -85.3,29.7 -84.0,30.1 -83.0,29.0',
  ' -82.7,27.8 -82.0,26.6 -81.7,25.9 -81.1,25.2 -80.4,25.2 -80.1,26.0 -80.0,26.8 -80.6,28.4',
  ' -81.3,29.9 -81.5,30.7 -81.1,32.0 -79.9,32.7 -78.9,33.7 -77.9,34.0 -76.5,34.7 -75.5,35.2',
  ' -75.9,36.9 -76.0,37.1 -75.9,37.5 -75.2,38.0 -75.1,38.8 -74.9,38.9 -74.1,39.7 -74.0,40.4',
  ' -73.9,40.6 -72.0,41.0 -71.5,41.4 -70.6,41.6 -70.0,41.7 -70.0,42.0 -70.6,42.0 -71.0,42.3',
  ' -70.7,42.7 -70.6,43.1 -70.2,43.6 -69.0,44.0 -68.0,44.3 -67.0,44.8',
  '/-67.0,44.8 -66.2,44.4 -65.8,43.6 -64.5,43.6 -63.5,44.5 -61.9,45.0 -60.2,45.9 -60.0,46.1',
  ' -60.5,47.0 -61.2,46.4 -61.5,45.7 -62.7,45.7 -64.0,45.9 -64.7,45.8 -64.3,45.3 -65.3,45.2',
  ' -66.1,44.7 -66.2,44.4',
  '/-67.0,44.9 -66.1,45.2 -65.0,45.8 -64.7,46.0 -64.7,46.9 -64.8,47.5 -65.0,47.9 -64.6,47.8',
  '/-73.5,45.5 -72.0,46.2 -71.2,46.8 -70.3,47.3 -69.4,48.0 -68.5,48.7 -67.0,49.2 -65.5,49.3',
  ' -64.2,49.1 -64.2,48.5 -64.8,48.0 -66.0,48.0 -66.7,47.9',
  '/-69.5,48.6 -68.0,49.4 -66.5,50.1 -64.5,50.3 -62.0,50.2 -60.0,50.2 -58.0,51.2 -56.2,51.6',
  '/-59.3,47.6 -57.0,47.6 -55.5,47.1 -53.1,46.7 -52.7,47.5 -53.6,49.2 -55.4,49.6 -56.1,51.4',
  ' -55.6,51.9 -57.3,51.4 -58.3,50.2 -59.2,48.6 -59.3,47.6',
  '/-92.1,46.7 -90.8,46.9 -89.5,46.9 -88.0,47.4 -87.5,46.5 -85.0,46.7 -84.6,46.5 -84.8,47.2',
  ' -85.9,47.9 -86.8,48.7 -88.2,48.9 -89.3,48.0 -90.5,47.6 -91.8,46.9 -92.1,46.7',
  '/-87.8,42.0 -87.5,41.7 -86.8,41.8 -86.3,42.4 -86.5,43.5 -86.2,44.7 -85.5,45.2 -85.0,45.7',
  ' -85.6,45.9 -86.5,45.8 -87.6,45.1 -88.0,44.5 -87.6,44.0 -87.8,43.0 -87.8,42.0',
  '/-84.7,45.8 -83.4,45.3 -83.4,44.3 -83.9,43.9 -83.0,44.0 -82.5,43.0 -81.7,43.2 -81.7,44.0',
  ' -81.3,44.6 -81.4,45.2 -80.0,44.7 -80.1,45.5 -81.5,45.9 -83.0,46.2 -84.0,46.1 -84.7,45.8',
  '/-83.4,41.7 -82.7,41.5 -81.7,41.5 -80.5,42.0 -79.0,42.8 -79.3,42.9 -80.5,42.6 -81.5,42.6',
  ' -82.5,42.0 -83.1,42.2 -83.4,41.7',
  '/-79.8,43.3 -79.3,43.6 -78.0,43.9 -76.5,44.0 -76.2,43.5 -76.7,43.3 -77.6,43.3 -79.0,43.3',
  ' -79.8,43.3',
  '/-97.15,25.95 -97.8,22.5 -96.0,19.4 -94.5,18.2 -92.5,18.6 -91.0,19.0 -90.5,20.7 -88.5,21.5',
  ' -87.0,21.5 -87.5,19.5 -88.0,17.5 -88.5,16.0',
  '/-85.0,21.9 -83.5,22.0 -81.5,22.1 -80.0,21.7 -78.5,21.3 -77.7,20.0 -76.0,19.9 -74.2,20.2',
  ' -75.5,21.0 -77.5,21.8 -79.0,22.5 -80.0,23.0 -81.5,23.1 -83.0,22.9 -84.5,22.0 -85.0,21.9',
  '/-103.0,37.0 -94.6,37.0 -94.4,35.4 -94.5,33.6 -96.0,33.8 -97.0,33.9 -99.0,34.2 -100.0,34.6',
  ' -100.0,36.5 -103.0,36.5 -103.0,37.0',
  '/-102.0,40.0 -95.3,40.0 -94.6,39.1 -94.6,37.0',
  '/-102.0,37.0 -102.0,40.0',
  '/-109.0,41.0 -102.0,41.0 -102.0,37.0 -109.0,37.0 -109.0,41.0',
  '/-103.0,36.5 -103.0,32.0 -106.5,31.8',
  '/-94.5,33.6 -94.0,33.55 -94.0,31.0 -93.5,31.0 -93.7,30.0 -93.8,29.7',
  '/-94.6,36.5 -90.1,36.5 -89.7,36.0 -90.4,35.0 -91.1,33.0 -94.0,33.0',
  '/-94.0,33.0 -91.2,33.0 -91.0,31.0 -89.7,31.0 -89.5,30.2',
  '/-85.4,31.0 -81.0,31.0 -81.5,30.7',
  '/-87.5,35.0 -85.6,35.0 -84.3,35.0 -83.1,35.0 -81.7,36.6 -75.9,36.55',
  '/-79.5,46.4 -77.0,45.9 -75.6,45.3 -74.5,45.0',
  '/-73.3,45.0 -73.4,43.6 -73.3,42.7 -73.5,42.05 -72.0,42.7 -70.8,42.9',
  '/-71.5,45.0 -71.5,43.0 -70.8,42.9',
  '/-104.0,45.0 -111.0,45.0 -111.0,41.0'
 );

Var
 { Donnees meteorologiques }
 Frames:Array[0..MaxFrames-1] of TFrame;
 NF,Cur:Integer;
 GCols,GRows:Integer;
 BLon0,BLat0,BLon1,BLat1:Real;
 SrcIdx:Integer;
 Title:String[60];
 ProdName:String[40];
 StepMin:Integer;
 Al:Array[0..MaxAlerts-1] of TAlert;
 NA,SelAl:Integer;
 Sta:Array[0..MaxStations-1] of TStation;
 NS:Integer;
 Stk:Array[0..MaxStrikes-1] of TStrike;
 NK:Integer;
 Lx:Array[0..MaxLieux-1] of TLieu;
 NL,SelL:Integer;
 Cl:Array[0..MaxFrames-1,0..MaxCells-1] of TCell;
 CN:Array[0..MaxFrames-1] of Integer;
 CoastX,CoastY:Array[0..MaxCoast] of Integer;
 NCoast:Integer;
 Vis:PBytes;
 Que:PWords;
 MaxDbz:Integer;
 { Vue cartographique }
 VLon,VLat,VScale,CosV:Real;
 { Couches et outils }
 LRadar,LFoudre,LAlert,LStation,LVille,LGrille,LCoast,LCell:Boolean;
 MinLv:Integer;
 Tool:Integer;
 Playing,Looping:Boolean;
 AnimMs:Integer;
 MeasN:Integer;
 MeasX,MeasY:Array[0..1] of Real;
 TrOn:Boolean;
 TrX,TrY:Array[0..MaxFrames-1] of Real;
 TrOk:Array[0..MaxFrames-1] of Boolean;
 TrSpd,TrDir,TrMx:Real;
 { Interface }
 Mn:Array[0..NbMenu-1] of TMenu;
 MenuOpen,MenuSel:Integer;
 BtnX,BtnW:Array[0..5] of Integer;
 StatMsg:String[80];
 MouseHid:Integer;
 Quit:Boolean;
 RAlY:Array[0..MaxAlerts-1] of Integer;
 RAlI:Array[0..MaxAlerts-1] of Integer;
 RAlN,RBackY:Integer;
 HovTxt:String[40];
 DragOn,DragMoved,TlDrag:Boolean;
 DragSX,DragSY:LongInt;
 DragLon,DragLat:Real;
 LastMX,LastMY:LongInt;
 SmpName:Array[0..29] of String[40];
 DL:Array[0..39] of String[78];
 DN:Integer;
 LastErr:String[80];
 StartMin:Integer;
 AscMmh:Boolean;
 CurFile:String[64];
 BoxSet:Boolean;

{ ---------------------------------------------------------------------------
  Utilitaires generaux
  --------------------------------------------------------------------------- }

Function IMin(a,b:Integer):Integer;Begin
 If a<b Then IMin:=a Else IMin:=b;
End;

Function IMax(a,b:Integer):Integer;Begin
 If a>b Then IMax:=a Else IMax:=b;
End;

Function Clamp(v:LongInt):Integer;Begin
 If v<-30000 Then v:=-30000;
 If v>30000 Then v:=30000;
 Clamp:=v;
End;

Function UpStr(s:String):String;
Var
 i:Integer;
Begin
 For i:=1 to Length(s)do s[i]:=UpCase(s[i]);
 UpStr:=s;
End;

Function IntStr(n:LongInt):String;
Var
 s:String;
Begin
 Str(n,s);
 IntStr:=s;
End;

Function RStr(r:Real;d:Integer):String;
Var
 s:String;
Begin
 Str(r:0:d,s);
 RStr:=s;
End;

Function Pad2(n:Integer):String;Begin
 If n<10 Then Pad2:='0'+IntStr(n) Else Pad2:=IntStr(n);
End;

Function TimeStr(m:Integer):String;Begin
 m:=m Mod 1440;
 If m<0 Then Inc(m,1440);
 TimeStr:=Pad2(m div 60)+':'+Pad2(m Mod 60);
End;

Function Tok(Var s:String):String;
Var
 i:Integer;
Begin
 While(Length(s)>0)and(s[1]=' ')do Delete(s,1,1);
 i:=Pos(' ',s);
 If i=0Then Begin
  Tok:=s;
  s:='';
 End
  Else
 Begin
  Tok:=Copy(s,1,i-1);
  Delete(s,1,i);
 End;
End;

Function LastTok(Var s:String):String;
Var
 i:Integer;
Begin
 While(Length(s)>0)and(s[Length(s)]=' ')do Dec(s[0]);
 i:=Length(s);
 While(i>0)and(s[i]<>' ')do Dec(i);
 LastTok:=Copy(s,i+1,255);
 s:=Copy(s,1,i);
 While(Length(s)>0)and(s[Length(s)]=' ')do Dec(s[0]);
End;

Function CleanLine(s:String):String;
Var
 i:Integer;
Begin
 For i:=1 to Length(s)do If s[i]<' 'Then s[i]:=' ';
 While(Length(s)>0)and(s[1]=' ')do Delete(s,1,1);
 While(Length(s)>0)and(s[Length(s)]=' ')do Dec(s[0]);
 CleanLine:=s;
End;

Function ValR(s:String;Var r:Real):Boolean;
Var
 e:Integer;
Begin
 Val(s,r,e);
 ValR:=(e=0)and(s<>'');
End;

Function ValI(s:String;Var n:Integer):Boolean;
Var
 e:Integer;
Begin
 Val(s,n,e);
 ValI:=(e=0)and(s<>'');
End;

Function ParseTime(s:String):Integer;
Var
 p,h,m:Integer;
Begin
 ParseTime:=-1;
 p:=Pos(':',s);
 If p=0Then Exit;
 If Not ValI(Copy(s,1,p-1),h)Then Exit;
 If Not ValI(Copy(s,p+1,2),m)Then Exit;
 ParseTime:=h*60+m;
End;

Function Atan2(y,x:Real):Real;
Var
 a:Real;
Begin
 If x=0Then Begin
  If y>0Then a:=Pi/2 Else If y<0Then a:=-Pi/2 Else a:=0;
 End
  Else
 Begin
  a:=ArcTan(y/x);
  If x<0Then Begin
   If y>=0Then a:=a+Pi Else a:=a-Pi;
  End;
 End;
 Atan2:=a;
End;

Function DistKm(lo1,la1,lo2,la2:Real):Real;
Var
 a,dla,dlo:Real;
Begin
 dla:=(la2-la1)*Pi/180;
 dlo:=(lo2-lo1)*Pi/180;
 a:=Sqr(Sin(dla/2))+Cos(la1*Pi/180)*Cos(la2*Pi/180)*Sqr(Sin(dlo/2));
 If a>1Then a:=1;
 DistKm:=6371*2*Atan2(Sqrt(a),Sqrt(1-a));
End;

Function BearingDeg(lo1,la1,lo2,la2:Real):Real;
Var
 y,x,b,dlo,p1,p2:Real;
Begin
 p1:=la1*Pi/180;
 p2:=la2*Pi/180;
 dlo:=(lo2-lo1)*Pi/180;
 y:=Sin(dlo)*Cos(p2);
 x:=Cos(p1)*Sin(p2)-Sin(p1)*Cos(p2)*Cos(dlo);
 b:=Atan2(y,x)*180/Pi;
 If b<0Then b:=b+360;
 BearingDeg:=b;
End;

Function Compass(b:Real):String;
Const
 Pts:Array[0..7] of String[2]=('N','NE','E','SE','S','SO','O','NO');
Var
 i:Integer;
Begin
 i:=Trunc((b+22.5)/45)Mod 8;
 If i<0Then i:=0;
 Compass:=Pts[i];
End;

Function IntensText(d:Integer):String;Begin
 If d<10Then IntensText:='Aucune' Else
 If d<20Then IntensText:='Tres faible' Else
 If d<30Then IntensText:='Faible' Else
 If d<40Then IntensText:='Moderee' Else
 If d<50Then IntensText:='Forte' Else
 If d<60Then IntensText:='Tres forte' Else
  IntensText:='Extreme (grele)';
End;

Function Ticks:LongInt;
Var
 h,m,s,hs:Word;
Begin
 GetTime(h,m,s,hs);
 Ticks:=((LongInt(h)*60+m)*60+s)*100+hs;
End;

Function LvlColor(lv:Integer):Byte;
Var
 d,i,c:Integer;
Begin
 d:=lv*2;
 c:=0;
 For i:=0 to 10do If d>=LegDbz[i]Then c:=LegCol[i];
 LvlColor:=c;
End;

Function LvChar(l:Integer):Char;Begin
 If l<0Then l:=0;
 If l>35Then l:=35;
 If l<10Then LvChar:=Chr(48+l) Else LvChar:=Chr(55+l);
End;

Function CharLv(c:Char):Integer;Begin
 If(c>='0')and(c<='9')Then CharLv:=Ord(c)-48 Else
 If(c>='A')and(c<='Z')Then CharLv:=Ord(c)-55 Else
 If(c>='a')and(c<='z')Then CharLv:=Ord(c)-87 Else
  CharLv:=0;
End;

Function FindSrc(s:String):Integer;
Var
 i:Integer;
Begin
 FindSrc:=-1;
 s:=UpStr(s);
 For i:=0 to NbSrc-1do If(s<>'')and(Pos(s,Src[i].nm)=1)Then Begin
  FindSrc:=i;
  Exit;
 End;
End;

Function KindOf(s:String):Integer;
Var
 i:Integer;
Begin
 KindOf:=2;
 s:=UpStr(s);
 For i:=0 to NbKind-1do If Kinds[i].cd=s Then KindOf:=i;
End;

Function FrameLbl(i:Integer):String;
Var
 h:Integer;
Begin
 If NF<=0Then Begin
  FrameLbl:='--:--';
  Exit;
 End;
 If SrcIdx=3Then Begin
  h:=(Frames[i].tm-Frames[0].tm)div 60;
  FrameLbl:='Prev. +'+IntStr(h)+'h ('+TimeStr(Frames[i].tm)+')';
 End
  Else
 FrameLbl:=TimeStr(Frames[i].tm);
End;

{ ---------------------------------------------------------------------------
  Gestion de la souris (Turbo Pascal : INT 33h, Free Pascal : unite PtcMouse)
  --------------------------------------------------------------------------- }

{$IFNDEF FPC}
 Function MouseDriverFound: Boolean;
 Var
  Regs: Registers;
 Begin
  Regs.AX := 0;
  Intr($33, Regs);
  MouseDriverFound := Regs.AX = $FFFF;
 End;

 Procedure ShowMouse;
 Var
  Regs: Registers;
 Begin
  Regs.AX := $0001;
  Intr($33, Regs);
 End;

 Procedure HideMouse;
 Var
  Regs: Registers;
 Begin
  Regs.AX := $0002;
  Intr($33, Regs);
 End;

 Procedure GetMouseState(Var X, Y, Button: LongInt);
 Var
  Regs: Registers;
 Begin
  Regs.AX := $0003;
  Intr($33, Regs);
  Button := Regs.BX;
  X := Regs.CX;
  Y := Regs.DX;
 End;
{$ELSE}
 Function MouseDriverFound: Boolean;
 Begin
  MouseDriverFound := True;
 End;

 Procedure ShowMouse;
 Begin
  PtcMouse.ShowMouse;
 End;

 Procedure HideMouse;
 Begin
  PtcMouse.HideMouse;
 End;
{$ENDIF}

Procedure MHide;Begin
 If MouseHid=0Then HideMouse;
 Inc(MouseHid);
End;

Procedure MShow;Begin
 Dec(MouseHid);
 If MouseHid<=0Then Begin
  MouseHid:=0;
  ShowMouse;
 End;
End;

{ ---------------------------------------------------------------------------
  Gestion des donnees : memoire, chargement, analyse
  --------------------------------------------------------------------------- }

Procedure FreeFrames;
Var
 i:Integer;
Begin
 For i:=0 to NF-1do If Frames[i].g<>NIL Then Begin
  FreeMem(Frames[i].g,SizeOf(TGrid));
  Frames[i].g:=NIL;
 End;
 NF:=0;
End;

Procedure ResetData;Begin
 FreeFrames;
 NA:=0;NS:=0;NK:=0;NL:=0;
 SelAl:=-1;SelL:=0;Cur:=0;
 GCols:=0;GRows:=0;
 BLon0:=-102;BLat0:=33;BLon1:=-92;BLat1:=39;
 Title:='';
 ProdName:='';
 StepMin:=0;
 TrOn:=False;
 MeasN:=0;
 MaxDbz:=0;
 BoxSet:=False;
 FillChar(CN,SizeOf(CN),0);
End;

Function NewFrame:Boolean;Begin
 NewFrame:=False;
 If NF>=MaxFrames Then Begin
  LastErr:='Trop d''images (maximum '+IntStr(MaxFrames)+')';
  Exit;
 End;
 GetMem(Frames[NF].g,SizeOf(TGrid));
 FillChar(Frames[NF].g^,SizeOf(TGrid),0);
 Frames[NF].tm:=0;
 Inc(NF);
 NewFrame:=True;
End;

Procedure SkipRows(Var f:Text;n:Integer);
Var
 i:Integer;
 s:String;
Begin
 For i:=1 to n do If Not Eof(f)Then ReadLn(f,s);
End;

{ Convertit un balayage polaire (n radiaux x ng portes) en grille }
Procedure PolarToGrid(pb:PPolar;n,ng:Integer;rlon,rlat,rng:Real;g:PGrid);
Var
 r,c,ri,gi:Integer;
 dlon,dlat,lo,la,dx,dy,d,az,kx:Real;
Begin
 dlon:=(BLon1-BLon0)/GCols;
 dlat:=(BLat1-BLat0)/GRows;
 kx:=111.19*Cos(rlat*Pi/180);
 For r:=0 to GRows-1do For c:=0 to GCols-1do Begin
  lo:=BLon0+(c+0.5)*dlon;
  la:=BLat1-(r+0.5)*dlat;
  dx:=(lo-rlon)*kx;
  dy:=(la-rlat)*111.19;
  d:=Sqrt(dx*dx+dy*dy);
  If d<rng Then Begin
   az:=Atan2(dx,dy)*180/Pi;
   If az<0Then az:=az+360;
   ri:=Round(az*n/360)Mod n;
   gi:=Trunc(d/rng*ng);
   If gi>=ng Then gi:=ng-1;
   g^[r,c]:=pb^[LongInt(ri)*ng+gi];
  End;
 End;
End;

Function ParseSVR(fn:String):Boolean;
Var
 f:Text;
 ln,cmd,w,w2:String;
 i,j,k,nrad,ngate,t:Integer;
 a,b:Real;
 polar:Boolean;
 rlon,rlat,rng:Real;
 pb:PPolar;
 Buf:Array[0..2047] of Byte;
Begin
 ParseSVR:=False;
 Assign(f,fn);
 SetTextBuf(f,Buf);
 {$I-}
 Reset(f);
 {$I+}
 If IOResult<>0Then Begin
  LastErr:='Fichier introuvable : '+fn;
  Exit;
 End;
 polar:=False;pb:=NIL;nrad:=0;ngate:=0;rlon:=0;rlat:=0;rng:=0;
 While Not Eof(f)do Begin
  ReadLn(f,ln);
  ln:=CleanLine(ln);
  If(ln='')or(ln[1]=';')or(ln[1]='#')Then Continue;
  cmd:=UpStr(Tok(ln));
  If cmd='SOURCE'Then Begin
   k:=FindSrc(Tok(ln));
   If k>=0Then SrcIdx:=k;
  End
  Else If cmd='TITRE'Then Title:=Copy(ln,1,60)
  Else If cmd='PRODUIT'Then ProdName:=Copy(ln,1,40)
  Else If cmd='PAS'Then Begin
   If ValI(Tok(ln),k)Then StepMin:=k;
  End
  Else If cmd='BOITE'Then Begin
   BoxSet:=True;
   If ValR(Tok(ln),a)Then BLon0:=a;
   If ValR(Tok(ln),a)Then BLat0:=a;
   If ValR(Tok(ln),a)Then BLon1:=a;
   If ValR(Tok(ln),a)Then BLat1:=a;
  End
  Else If cmd='GRILLE'Then Begin
   If ValI(Tok(ln),i)and ValI(Tok(ln),j)Then Begin
    GCols:=IMin(i,MaxCols);
    GRows:=IMin(j,MaxRows);
   End;
  End
  Else If cmd='RADAR'Then Begin
   Tok(ln);
   If ValR(Tok(ln),rlon)and ValR(Tok(ln),rlat)and ValR(Tok(ln),rng)Then Begin
    polar:=True;
    If ProdName=''Then ProdName:='Reflectivite de base (sweep)';
   End;
  End
  Else If cmd='RADIAUX'Then Begin
   If ValI(Tok(ln),nrad)and ValI(Tok(ln),ngate)Then
    If(nrad<1)or(ngate<1)or(LongInt(nrad)*ngate>57600)Then Begin
     LastErr:='RADIAUX : taille invalide (maximum 57600 echantillons)';
     Close(f);
     Exit;
    End;
  End
  Else If cmd='LIEU'Then Begin
   w:=LastTok(ln);w2:=LastTok(ln);
   If(NL<MaxLieux)and ValR(w,b)and ValR(w2,a)Then Begin
    Lx[NL].nm:=Copy(ln,1,16);
    Lx[NL].x:=a;Lx[NL].y:=b;
    Inc(NL);
   End;
  End
  Else If cmd='STATION'Then Begin
   If NS<MaxStations Then Begin
    Sta[NS].id:=Copy(Tok(ln),1,6);
    ValR(Tok(ln),Sta[NS].x);ValR(Tok(ln),Sta[NS].y);
    ValR(Tok(ln),Sta[NS].t);
    ValI(Tok(ln),Sta[NS].dr);ValI(Tok(ln),Sta[NS].v);
    ValI(Tok(ln),Sta[NS].r);ValI(Tok(ln),Sta[NS].p);
    Inc(NS);
   End;
  End
  Else If cmd='FOUDRE'Then Begin
   t:=ParseTime(Tok(ln));
   If(NK<MaxStrikes)and(t>=0)and ValR(Tok(ln),a)and ValR(Tok(ln),b)Then Begin
    Stk[NK].t:=t;Stk[NK].x:=a;Stk[NK].y:=b;
    Inc(NK);
   End;
  End
  Else If cmd='ALERTE'Then Begin
   If NA<MaxAlerts Then Begin
    Al[NA].kind:=KindOf(Tok(ln));
    Al[NA].t0:=ParseTime(Tok(ln));
    Al[NA].t1:=ParseTime(Tok(ln));
    If Al[NA].t0<0Then Al[NA].t0:=0;
    If Al[NA].t1<0Then Al[NA].t1:=1439;
    Al[NA].ti:=Copy(ln,1,34);
    If Al[NA].ti=''Then Al[NA].ti:=Kinds[Al[NA].kind].nom;
    Al[NA].tx:='';
    Al[NA].n:=0;
    Inc(NA);
   End;
  End
  Else If cmd='POLY'Then Begin
   If NA>0Then While ln<>''do Begin
    w:=Tok(ln);w2:=Tok(ln);
    If(Al[NA-1].n<MaxPoly)and ValR(w,a)and ValR(w2,b)Then Begin
     Al[NA-1].px[Al[NA-1].n]:=a;
     Al[NA-1].py[Al[NA-1].n]:=b;
     Inc(Al[NA-1].n);
    End;
   End;
  End
  Else If cmd='DETAIL'Then Begin
   If NA>0Then Begin
    If Al[NA-1].tx<>''Then ln:=' '+ln;
    Al[NA-1].tx:=Copy(Al[NA-1].tx+ln,1,200);
   End;
  End
  Else If cmd='TRAME'Then Begin
   t:=ParseTime(Tok(ln));
   If polar Then Begin
    If(GCols<1)or(GRows<1)Then Begin
     GCols:=100;GRows:=80;
    End;
    If Not BoxSet Then Begin
     BoxSet:=True;
     BLat0:=rlat-rng/111.19;BLat1:=rlat+rng/111.19;
     BLon0:=rlon-rng/(111.19*Cos(rlat*Pi/180));
     BLon1:=rlon+rng/(111.19*Cos(rlat*Pi/180));
    End;
   End;
   If(GCols<1)or(GRows<1)Then Begin
    LastErr:='TRAME avant GRILLE dans '+fn;
    Close(f);
    Exit;
   End;
   If Not NewFrame Then Begin
    Close(f);
    Exit;
   End;
   If t<0Then t:=StartMin+(NF-1)*StepMin;
   If(NF>1)Then While t<Frames[NF-2].tm do Inc(t,1440);
   Frames[NF-1].tm:=t;
   If polar and(nrad>0)and(ngate>0)Then Begin
    GetMem(pb,SizeOf(TPolar));
    FillChar(pb^,SizeOf(TPolar),0);
    For i:=0 to nrad-1do Begin
     If Not Eof(f)Then ReadLn(f,w) Else w:='';
     For j:=1 to IMin(Length(w),ngate)do pb^[LongInt(i)*ngate+j-1]:=CharLv(w[j]);
    End;
    PolarToGrid(pb,nrad,ngate,rlon,rlat,rng,Frames[NF-1].g);
    FreeMem(pb,SizeOf(TPolar));
   End
    Else
   For i:=0 to GRows-1do Begin
    If Not Eof(f)Then ReadLn(f,w) Else w:='';
    For j:=1 to IMin(Length(w),GCols)do Frames[NF-1].g^[i,j-1]:=CharLv(w[j]);
   End;
  End;
 End;
 Close(f);
 ParseSVR:=True;
End;

{ Lecture d'une grille ESRI ASCII (gdal_translate -of AAIGrid) comme image }
Function ParseASC(fn:String):Boolean;
Var
 f:Text;
 s,key:String;
 nc,nr,i,k,tc,tr,r,c,lv,e:Integer;
 xl,yl,cs,nd,v,d:Real;
 first,cen:Boolean;
 Buf:Array[0..4095] of Byte;
Begin
 ParseASC:=False;
 Assign(f,fn);
 SetTextBuf(f,Buf);
 {$I-}
 Reset(f);
 {$I+}
 If IOResult<>0Then Begin
  LastErr:='Fichier introuvable : '+fn;
  Exit;
 End;
 nc:=0;nr:=0;xl:=0;yl:=0;cs:=1;nd:=-9999;cen:=False;
 For i:=1 to 6do If Not Eof(f)Then Begin
  ReadLn(f,s);
  s:=CleanLine(s);
  key:=UpStr(Tok(s));
  If key='NCOLS'Then ValI(Tok(s),nc) Else
  If key='NROWS'Then ValI(Tok(s),nr) Else
  If(key='XLLCORNER')or(key='XLLCENTER')Then Begin
   ValR(Tok(s),xl);
   If key='XLLCENTER'Then cen:=True;
  End Else
  If(key='YLLCORNER')or(key='YLLCENTER')Then ValR(Tok(s),yl) Else
  If key='CELLSIZE'Then ValR(Tok(s),cs) Else
  If key='NODATA_VALUE'Then ValR(Tok(s),nd);
 End;
 If(nc<1)or(nr<1)or(cs<=0)Then Begin
  LastErr:='Entete ESRI ASCII invalide dans '+fn;
  Close(f);
  Exit;
 End;
 If cen Then Begin
  xl:=xl-cs/2;yl:=yl-cs/2;
 End;
 first:=(NF=0);
 k:=IMax((nc+MaxCols-1)div MaxCols,(nr+MaxRows-1)div MaxRows);
 tc:=(nc+k-1)div k;
 tr:=(nr+k-1)div k;
 If first Then Begin
  GCols:=tc;GRows:=tr;
  BLon0:=xl;BLon1:=xl+tc*k*cs;
  BLat1:=yl+nr*cs;BLat0:=BLat1-tr*k*cs;
  If Title=''Then Title:=Copy(fn,1,60);
 End
  Else If(tc<>GCols)or(tr<>GRows)Then Begin
  LastErr:='Dimensions differentes de la premiere image : '+fn;
  Close(f);
  Exit;
 End;
 If Not NewFrame Then Begin
  Close(f);
  Exit;
 End;
 Frames[NF-1].tm:=StartMin+(NF-1)*StepMin;
 For r:=0 to nr-1do For c:=0 to nc-1do Begin
  {$I-}
  Read(f,v);
  {$I+}
  If IOResult<>0Then v:=nd;
  If(v<>nd)and(v>0)Then Begin
   If AscMmh Then Begin
    If v<0.01Then d:=0 Else d:=10*Ln(200*Exp(1.6*Ln(v)))/Ln(10);
   End
    Else
   d:=v;
   lv:=Trunc(d/2+0.5);
   If lv>35Then lv:=35;
   If lv<0Then lv:=0;
   e:=Frames[NF-1].g^[r div k,c div k];
   If lv>e Then Frames[NF-1].g^[r div k,c div k]:=lv;
  End;
 End;
 Close(f);
 ParseASC:=True;
End;

Function LoadAny(fn:String):Boolean;
Forward;

{ Liste de fichiers : un nom par ligne + options SOURCE, PAS, HEURE, MMH, TITRE }
Function ParseLST(fn:String):Boolean;
Var
 f:Text;
 ln,cmd,w,dir:String;
 k:Integer;
Begin
 ParseLST:=False;
 k:=Length(fn);
 While(k>0)and(fn[k]<>'/')and(fn[k]<>'\')do Dec(k);
 dir:=Copy(fn,1,k);
 Assign(f,fn);
 {$I-}
 Reset(f);
 {$I+}
 If IOResult<>0Then Begin
  LastErr:='Fichier introuvable : '+fn;
  Exit;
 End;
 While Not Eof(f)do Begin
  ReadLn(f,ln);
  ln:=CleanLine(ln);
  If(ln='')or(ln[1]=';')or(ln[1]='#')Then Continue;
  w:=ln;
  cmd:=UpStr(Tok(w));
  If cmd='SOURCE'Then Begin
   k:=FindSrc(Tok(w));
   If k>=0Then SrcIdx:=k;
  End
  Else If cmd='PAS'Then Begin
   If ValI(Tok(w),k)Then StepMin:=k;
  End
  Else If cmd='HEURE'Then Begin
   k:=ParseTime(Tok(w));
   If k>=0Then StartMin:=k;
  End
  Else If cmd='MMH'Then AscMmh:=True
  Else If cmd='TITRE'Then Title:=Copy(w,1,60)
  Else Begin
   If(Pos('/',ln)=0)and(Pos('\',ln)=0)Then ln:=dir+ln;
   If Not LoadAny(ln)Then Begin
    Close(f);
    Exit;
   End;
  End;
 End;
 Close(f);
 ParseLST:=True;
End;

Function LoadAny(fn:String):Boolean;
Var
 e:String;
Begin
 e:=UpStr(Copy(fn,Length(fn)-3,4));
 If e='.ASC'Then LoadAny:=ParseASC(fn) Else
 If e='.LST'Then LoadAny:=ParseLST(fn) Else
  LoadAny:=ParseSVR(fn);
End;

{ Detection des cellules orageuses (zones connexes >= 40 dBZ) }
Procedure FindCells(f:Integer);
Var
 r,c,qh,qt,cr,cc,nr,nc,n,i,mx:Integer;
 sr,sc,dlon,dlat:Real;
 g:PGrid;
Begin
 CN[f]:=0;
 g:=Frames[f].g;
 If g=NIL Then Exit;
 dlon:=(BLon1-BLon0)/GCols;
 dlat:=(BLat1-BLat0)/GRows;
 FillChar(Vis^,GRows*GCols,0);
 For r:=0 to GRows-1do For c:=0 to GCols-1do
  If(g^[r,c]>=CellLvl)and(Vis^[r*GCols+c]=0)Then Begin
   qh:=0;qt:=0;n:=0;sr:=0;sc:=0;mx:=0;
   Que^[qt]:=r*GCols+c;Inc(qt);
   Vis^[r*GCols+c]:=1;
   While qh<qt do Begin
    cr:=Que^[qh]div GCols;
    cc:=Que^[qh]Mod GCols;
    Inc(qh);
    Inc(n);sr:=sr+cr;sc:=sc+cc;
    If g^[cr,cc]>mx Then mx:=g^[cr,cc];
    For i:=0 to 3do Begin
     nr:=cr;nc:=cc;
     Case i of
      0:Inc(nr);
      1:Dec(nr);
      2:Inc(nc);
      3:Dec(nc);
     End;
     If(nr>=0)and(nr<GRows)and(nc>=0)and(nc<GCols)Then
      If(g^[nr,nc]>=CellLvl)and(Vis^[nr*GCols+nc]=0)Then Begin
       Vis^[nr*GCols+nc]:=1;
       Que^[qt]:=nr*GCols+nc;Inc(qt);
      End;
    End;
   End;
   If(n>=3)and(CN[f]<MaxCells)Then Begin
    Cl[f,CN[f]].x:=BLon0+(sc/n+0.5)*dlon;
    Cl[f,CN[f]].y:=BLat1-(sr/n+0.5)*dlat;
    Cl[f,CN[f]].mx:=mx;
    Cl[f,CN[f]].n:=n;
    Inc(CN[f]);
   End;
  End;
End;

Procedure FitView;
Var
 sx,sy:Real;
Begin
 VLon:=(BLon0+BLon1)/2;
 VLat:=(BLat0+BLat1)/2;
 CosV:=Cos(VLat*Pi/180);
 sy:=MapH/(BLat1-BLat0);
 sx:=MapW/((BLon1-BLon0)*CosV);
 If sx<sy Then VScale:=sx Else VScale:=sy;
 VScale:=VScale*0.97;
End;

Procedure ComputeMax;
Var
 r,c,m:Integer;
Begin
 m:=0;
 If(NF>0)and(Frames[Cur].g<>NIL)Then
  For r:=0 to GRows-1do For c:=0 to GCols-1do
   If Frames[Cur].g^[r,c]>m Then m:=Frames[Cur].g^[r,c];
 MaxDbz:=m*2;
End;

Procedure FinishLoad;
Var
 i:Integer;
 lo,la:Real;
Begin
 If StepMin<=0Then StepMin:=Src[SrcIdx].pas;
 If ProdName=''Then ProdName:=Src[SrcIdx].prod;
 For i:=0 to NA-1do Begin
  If NF>0Then Begin
   If Al[i].t0<Frames[0].tm-720Then Inc(Al[i].t0,1440);
   If Al[i].t1<Al[i].t0 Then Inc(Al[i].t1,1440);
  End;
 End;
 For i:=0 to NK-1do If(NF>0)and(Stk[i].t<Frames[0].tm-720)Then Inc(Stk[i].t,1440);
 For i:=0 to NF-1do FindCells(i);
 If NL=0Then Begin
  For i:=0 to NbCity-1do Begin
   lo:=Cities[i].lo/100;la:=Cities[i].la/100;
   If(NL<6)and(lo>BLon0)and(lo<BLon1)and(la>BLat0)and(la<BLat1)Then Begin
    Lx[NL].nm:=Cities[i].nm;
    Lx[NL].x:=lo;Lx[NL].y:=la;
    Inc(NL);
   End;
  End;
 End;
 FitView;
 Cur:=0;
 SelAl:=-1;SelL:=0;
 ComputeMax;
End;

Procedure LoadBasemap;
Var
 i,p,e:Integer;
 s,w:String;
 r:Real;
 lo,la:Integer;
Begin
 NCoast:=0;
 For i:=0 to CoastCount do Begin
  s:=CoastS[i];
  If s[1]='/'Then Begin
   CoastX[NCoast]:=32000;CoastY[NCoast]:=0;
   Inc(NCoast);
  End;
  While s<>''do Begin
   w:=Tok(s);
   If w[1]='/'Then Delete(w,1,1);
   p:=Pos(',',w);
   If(p>0)and(NCoast<MaxCoast)Then Begin
    Val(Copy(w,1,p-1),r,e);lo:=Round(r*100);
    Val(Copy(w,p+1,20),r,e);la:=Round(r*100);
    CoastX[NCoast]:=lo;CoastY[NCoast]:=la;
    Inc(NCoast);
   End;
  End;
 End;
End;

{ ---------------------------------------------------------------------------
  Primitives graphiques
  --------------------------------------------------------------------------- }

Procedure InitializeGraphics;
Var
 Driver, Mode: Integer;
 ErrCode: Integer;
Begin
 {$IFDEF FPC}
  Driver:=VGA;
  Mode:=VGAHi;
 {$ELSE}
  Driver:=Detect;
  Mode:=VGAHi;
 {$ENDIF}
 InitGraph(Driver,Mode,'');
 ErrCode:=GraphResult;
 If ErrCode=grOk Then Begin
  SetColor(White);
  SetLineStyle(0,0,1);
 End
  Else
 Begin
  WriteLn('Erreur graphique : ',GraphErrorMsg(ErrCode));
  Halt;
 End;
End;

Procedure Txt(x,y:Integer;s:String;c:Byte);Begin
 SetColor(c);
 OutTextXY(x,y,s);
End;

Procedure FillR(x1,y1,x2,y2:Integer;c:Byte);Begin
 SetFillStyle(SolidFill,c);
 Bar(x1,y1,x2,y2);
End;

Procedure Frame3D(x1,y1,x2,y2:Integer;up:Boolean);Begin
 If up Then SetColor(15) Else SetColor(8);
 Line(x1,y1,x2,y1);Line(x1,y1,x1,y2);
 If up Then SetColor(8) Else SetColor(15);
 Line(x2,y1,x2,y2);Line(x1,y2,x2,y2);
End;

Function InRect(x,y,x1,y1,x2,y2:LongInt):Boolean;Begin
 InRect:=(x>=x1)and(x<=x2)and(y>=y1)and(y<=y2);
End;

Function Wrap(s:String;x,y,w:Integer;c:Byte):Integer;
Var
 k:Integer;
Begin
 While s<>''do Begin
  If Length(s)<=w Then Begin
   Txt(x,y,s,c);
   s:='';
  End
   Else
  Begin
   k:=w;
   While(k>0)and(s[k+1]<>' ')do Dec(k);
   If k=0Then k:=w;
   Txt(x,y,Copy(s,1,k),c);
   Delete(s,1,k);
   While(Length(s)>0)and(s[1]=' ')do Delete(s,1,1);
  End;
  Inc(y,10);
 End;
 Wrap:=y;
End;

{ ---------------------------------------------------------------------------
  Projection cartographique (coordonnees relatives a la fenetre de la carte)
  --------------------------------------------------------------------------- }

Function PX(lon:Real):Integer;Begin
 PX:=Clamp(Round((lon-VLon)*VScale*CosV)+MapW div 2);
End;

Function PY(lat:Real):Integer;Begin
 PY:=Clamp(MapH div 2-Round((lat-VLat)*VScale));
End;

Function UnX(x:Integer):Real;Begin
 UnX:=VLon+(x-MapW div 2)/(VScale*CosV);
End;

Function UnY(y:Integer):Real;Begin
 UnY:=VLat-(y-MapH div 2)/VScale;
End;

Function DbzAt(lo,la:Real):Integer;
Var
 r,c:Integer;
Begin
 DbzAt:=-1;
 If(NF=0)or(lo<BLon0)or(lo>=BLon1)or(la<=BLat0)or(la>BLat1)Then Exit;
 c:=Trunc((lo-BLon0)/(BLon1-BLon0)*GCols);
 r:=Trunc((BLat1-la)/(BLat1-BLat0)*GRows);
 If(c>=0)and(c<GCols)and(r>=0)and(r<GRows)Then DbzAt:=Frames[Cur].g^[r,c]*2;
End;

Function AlertOn(i:Integer):Boolean;Begin
 AlertOn:=(NF>0)and(Frames[Cur].tm>=Al[i].t0)and(Frames[Cur].tm<=Al[i].t1);
End;

Function InPoly(lo,la:Real;i:Integer):Boolean;
Var
 j,k:Integer;
 r:Boolean;
Begin
 r:=False;
 k:=Al[i].n-1;
 For j:=0 to Al[i].n-1do Begin
  If((Al[i].py[j]>la)<>(Al[i].py[k]>la))Then
   If lo<(Al[i].px[k]-Al[i].px[j])*(la-Al[i].py[j])/(Al[i].py[k]-Al[i].py[j])+Al[i].px[j]Then r:=Not r;
  k:=j;
 End;
 InPoly:=r;
End;

{ Alerte active couvrant un point (la plus recente d'abord), -1 si aucune }
Function AlertAt(lo,la:Real):Integer;
Var
 i:Integer;
Begin
 AlertAt:=-1;
 For i:=NA-1 downto 0do If AlertOn(i)and(Al[i].n>=3)and InPoly(lo,la,i)Then Begin
  AlertAt:=i;
  Exit;
 End;
End;

{ ---------------------------------------------------------------------------
  Dessin de la carte
  --------------------------------------------------------------------------- }

Procedure DrawGrid;
Const
 Steps:Array[0..9] of Real=(0.05,0.1,0.25,0.5,1,2,5,10,20,30);
Var
 st,v,la0,la1,lo0,lo1:Real;
 i,k,d,x,y:Integer;
Begin
 st:=30;
 For i:=9 downto 0do If Steps[i]*VScale>=60Then st:=Steps[i];
 If st>=1Then d:=0 Else If st>=0.1Then d:=1 Else d:=2;
 lo0:=UnX(0);lo1:=UnX(MapW-1);
 la1:=UnY(0);la0:=UnY(MapH-1);
 SetLineStyle(DottedLn,0,1);
 SetColor(8);
 For k:=Trunc(lo0/st)-1 to Trunc(lo1/st)+1do Begin
  v:=k*st;
  x:=PX(v);
  If(x>=0)and(x<MapW)Then Begin
   Line(x,0,x,MapH-1);
   Txt(x+2,2,RStr(v,d),8);
  End;
 End;
 For k:=Trunc(la0/st)-1 to Trunc(la1/st)+1do Begin
  v:=k*st;
  y:=PY(v);
  If(y>=0)and(y<MapH)Then Begin
   Line(0,y,MapW-1,y);
   Txt(2,y+2,RStr(v,d),8);
  End;
 End;
 SetLineStyle(SolidLn,0,1);
End;

Procedure DrawRadar;
Var
 r,c,k,x1,x2,y1,y2:Integer;
 col,col2:Byte;
 g:PGrid;
 dlon,dlat:Real;
 xs:Array[0..MaxCols] of Integer;
 ys:Array[0..MaxRows] of Integer;

 Function CC(lv:Integer):Byte;Begin
  If(lv<5)or(lv<MinLv)Then CC:=0 Else CC:=LvlColor(lv);
 End;

Begin
 g:=Frames[Cur].g;
 If g=NIL Then Exit;
 dlon:=(BLon1-BLon0)/GCols;
 dlat:=(BLat1-BLat0)/GRows;
 For c:=0 to GCols do xs[c]:=PX(BLon0+c*dlon);
 For r:=0 to GRows do ys[r]:=PY(BLat1-r*dlat);
 For r:=0 to GRows-1do Begin
  y1:=ys[r];y2:=ys[r+1]-1;
  If y2<y1 Then y2:=y1;
  If(y2>=0)and(y1<MapH)Then Begin
   c:=0;
   While c<GCols do Begin
    col:=CC(g^[r,c]);
    If col=0Then Inc(c)
     Else
    Begin
     k:=c;
     While k+1<GCols do Begin
      col2:=CC(g^[r,k+1]);
      If col2<>col Then Break;
      Inc(k);
     End;
     x1:=xs[c];x2:=xs[k+1]-1;
     If x2<x1 Then x2:=x1;
     If(x2>=0)and(x1<MapW)Then Begin
      SetFillStyle(SolidFill,col);
      Bar(x1,y1,x2,y2);
     End;
     c:=k+1;
    End;
   End;
  End;
 End;
End;

Procedure DrawCoast;
Var
 i:Integer;
 pen:Boolean;
Begin
 SetColor(7);
 pen:=False;
 For i:=0 to NCoast-1do Begin
  If CoastX[i]=32000Then pen:=False
   Else
  Begin
   If pen Then LineTo(PX(CoastX[i]/100),PY(CoastY[i]/100))
    Else MoveTo(PX(CoastX[i]/100),PY(CoastY[i]/100));
   pen:=True;
  End;
 End;
End;

Procedure DrawAlerts;
Var
 i,j,n,x,y,x1,y1,x2,y2,c:Integer;
 pts:Array[0..MaxPoly] of PointType;
 lo,la:Real;
Begin
 For i:=0 to NA-1do If AlertOn(i)and(Al[i].n>=3)Then Begin
  n:=Al[i].n;
  x1:=32000;y1:=32000;x2:=-32000;y2:=-32000;
  For j:=0 to n-1do Begin
   pts[j].x:=PX(Al[i].px[j]);
   pts[j].y:=PY(Al[i].py[j]);
   If pts[j].x<x1 Then x1:=pts[j].x;
   If pts[j].x>x2 Then x2:=pts[j].x;
   If pts[j].y<y1 Then y1:=pts[j].y;
   If pts[j].y>y2 Then y2:=pts[j].y;
  End;
  pts[n]:=pts[0];
  c:=Kinds[Al[i].kind].col;
  If i=SelAl Then Begin
   { Hachures de l'alerte selectionnee }
   If x1<0Then x1:=0;
   If y1<0Then y1:=0;
   If x2>=MapW Then x2:=MapW-1;
   If y2>=MapH Then y2:=MapH-1;
   y:=y1;
   While y<=y2 do Begin
    x:=x1+(y-y1)Mod 4;
    While x<=x2 do Begin
     lo:=UnX(x);la:=UnY(y);
     If InPoly(lo,la,i)Then PutPixel(x,y,c);
     Inc(x,4);
    End;
    Inc(y,2);
   End;
  End;
  SetColor(c);
  SetLineStyle(SolidLn,0,ThickWidth);
  DrawPoly(n+1,pts);
  SetLineStyle(SolidLn,0,NormWidth);
 End;
End;

Procedure DrawStrikes;
Var
 i,x,y:Integer;
 age:Integer;
Begin
 If NF=0Then Exit;
 For i:=0 to NK-1do Begin
  age:=Frames[Cur].tm-Stk[i].t;
  If(age>=0)and(age<IMax(StepMin,10))Then Begin
   x:=PX(Stk[i].x);y:=PY(Stk[i].y);
   If(x>=0)and(x<MapW)and(y>=0)and(y<MapH)Then Begin
    If age*2<IMax(StepMin,10)Then SetColor(14) Else SetColor(6);
    Line(x-3,y,x+3,y);Line(x,y-3,x,y+3);
    Line(x-2,y-2,x+2,y+2);Line(x-2,y+2,x+2,y-2);
   End;
  End;
 End;
End;

Procedure DrawCells;
Var
 i,x,y:Integer;
Begin
 If NF=0Then Exit;
 For i:=0 to CN[Cur]-1do Begin
  x:=PX(Cl[Cur,i].x);y:=PY(Cl[Cur,i].y);
  If(x>=0)and(x<MapW)and(y>=0)and(y<MapH)Then Begin
   SetColor(15);
   Circle(x,y,5);
   Txt(x+7,y-3,IntStr(Cl[Cur,i].mx*2),15);
  End;
 End;
End;

Procedure DrawStations;
Var
 i,x,y:Integer;
Begin
 For i:=0 to NS-1do Begin
  x:=PX(Sta[i].x);y:=PY(Sta[i].y);
  If(x>=0)and(x<MapW)and(y>=0)and(y<MapH)Then Begin
   SetColor(15);
   Circle(x,y,3);
   SetFillStyle(SolidFill,15);
   FillEllipse(x,y,2,2);
   Txt(x+5,y+3,IntStr(Round(Sta[i].t))+'C',15);
  End;
 End;
End;

Procedure DrawCities;
Var
 i,x,y,n,k:Integer;
 cxs,cys:Array[0..79] of Integer;
 ok:Boolean;
Begin
 n:=0;
 For i:=0 to NbCity-1do Begin
  x:=PX(Cities[i].lo/100);y:=PY(Cities[i].la/100);
  If(x>=4)and(x<MapW-8)and(y>=4)and(y<MapH-8)and(n<80)Then Begin
   ok:=True;
   For k:=0 to n-1do If(Abs(cxs[k]-x)<Length(Cities[i].nm)*8+16)and(Abs(cys[k]-y)<11)Then ok:=False;
   For k:=0 to NL-1do If Lx[k].nm=Cities[i].nm Then ok:=False;
   If ok Then Begin
    cxs[n]:=x;cys[n]:=y;Inc(n);
    PutPixel(x,y,15);PutPixel(x+1,y,15);PutPixel(x,y+1,15);PutPixel(x+1,y+1,15);
    Txt(x+5,y-3,Cities[i].nm,7);
   End;
  End;
 End;
End;

Procedure DrawLieux;
Var
 i,x,y:Integer;
Begin
 For i:=0 to NL-1do Begin
  x:=PX(Lx[i].x);y:=PY(Lx[i].y);
  If(x>=0)and(x<MapW)and(y>=0)and(y<MapH)Then Begin
   If i=SelL Then Begin
    SetColor(11);
    Circle(x,y,6);
    Line(x-9,y,x-3,y);Line(x+3,y,x+9,y);Line(x,y-9,x,y-3);Line(x,y+3,x,y+9);
    Txt(x+9,y+6,Lx[i].nm,11);
   End
    Else
   Begin
    SetColor(3);
    Rectangle(x-2,y-2,x+2,y+2);
   End;
  End;
 End;
End;

Procedure DrawMeasure;
Var
 i,x1,y1,x2,y2:Integer;
 d:Real;
Begin
 For i:=0 to MeasN-1do Begin
  x1:=PX(MeasX[i]);y1:=PY(MeasY[i]);
  SetColor(15);
  Circle(x1,y1,4);
 End;
 If MeasN=2Then Begin
  x1:=PX(MeasX[0]);y1:=PY(MeasY[0]);
  x2:=PX(MeasX[1]);y2:=PY(MeasY[1]);
  SetColor(15);
  Line(x1,y1,x2,y2);
  d:=DistKm(MeasX[0],MeasY[0],MeasX[1],MeasY[1]);
  FillR((x1+x2)div 2+4,(y1+y2)div 2-12,(x1+x2)div 2+12+Length(RStr(d,1))*8+24,(y1+y2)div 2-2,0);
  Txt((x1+x2)div 2+8,(y1+y2)div 2-10,RStr(d,1)+' km',15);
 End;
End;

Procedure DrawTrack;
Var
 f,x,y,k:Integer;
 first:Boolean;
 lo,la,vx,vy,t0,t1:Real;
 f0,f1:Integer;
Begin
 f0:=-1;f1:=-1;
 first:=True;
 SetColor(15);
 For f:=0 to NF-1do If TrOk[f]Then Begin
  x:=PX(TrX[f]);y:=PY(TrY[f]);
  If first Then MoveTo(x,y) Else LineTo(x,y);
  first:=False;
  If f0<0Then f0:=f;
  f1:=f;
 End;
 For f:=0 to NF-1do If TrOk[f]Then Begin
  x:=PX(TrX[f]);y:=PY(TrY[f]);
  If f=Cur Then Begin
   SetFillStyle(SolidFill,15);
   FillEllipse(x,y,4,4);
  End
   Else
  Circle(x,y,3);
 End;
 If(f1>f0)and(f0>=0)Then Begin
  t0:=Frames[f0].tm;t1:=Frames[f1].tm;
  vx:=(TrX[f1]-TrX[f0])/(t1-t0);
  vy:=(TrY[f1]-TrY[f0])/(t1-t0);
  SetColor(13);
  SetLineStyle(DashedLn,0,1);
  MoveTo(PX(TrX[f1]),PY(TrY[f1]));
  For k:=1 to 2do Begin
   lo:=TrX[f1]+vx*60*k;la:=TrY[f1]+vy*60*k;
   LineTo(PX(lo),PY(la));
  End;
  SetLineStyle(SolidLn,0,1);
  For k:=1 to 2do Begin
   lo:=TrX[f1]+vx*60*k;la:=TrY[f1]+vy*60*k;
   x:=PX(lo);y:=PY(la);
   Circle(x,y,3);
   Txt(x+5,y-3,'+'+IntStr(k)+'h',13);
  End;
 End;
End;

Procedure DrawMapOverlay;
Var
 km,L:Real;
 i,px1:Integer;
 sc:Array[0..9] of Real;
 s:String;
Begin
 { Etiquette de l'image courante }
 If NF>0Then Begin
  s:=FrameLbl(Cur);
  FillR(4,4,12+Length(s)*8,16,0);
  Txt(8,7,s,11);
 End;
 { Echelle }
 km:=111.19/VScale;
 sc[0]:=1;sc[1]:=2;sc[2]:=5;sc[3]:=10;sc[4]:=20;sc[5]:=50;sc[6]:=100;sc[7]:=200;sc[8]:=500;sc[9]:=1000;
 L:=1000;
 For i:=9 downto 0do If sc[i]/km>=40Then L:=sc[i];
 px1:=Round(L/km);
 If px1<MapW-40Then Begin
  FillR(6,MapH-22,px1+14+Length(IntStr(Round(L)))*8+24,MapH-4,0);
  SetColor(15);
  Line(10,MapH-8,10+px1,MapH-8);
  Line(10,MapH-12,10,MapH-8);
  Line(10+px1,MapH-12,10+px1,MapH-8);
  Txt(14,MapH-19,IntStr(Round(L))+' km',15);
 End;
 { Boutons de zoom }
 FillR(MapW-28,6,MapW-6,28,8);
 Frame3D(MapW-28,6,MapW-6,28,True);
 Txt(MapW-20,13,'+',15);
 FillR(MapW-28,32,MapW-6,54,8);
 Frame3D(MapW-28,32,MapW-6,54,True);
 Txt(MapW-20,39,'-',15);
End;

Procedure DrawMap;Begin
 MHide;
 SetViewPort(MapX1,MapY1,MapX2,MapY2,True);
 SetFillStyle(SolidFill,0);
 Bar(0,0,MapW-1,MapH-1);
 If LGrille Then DrawGrid;
 If LRadar and(NF>0)Then DrawRadar;
 If LCoast Then DrawCoast;
 If LAlert Then DrawAlerts;
 If LFoudre Then DrawStrikes;
 If LCell Then DrawCells;
 If TrOn Then DrawTrack;
 If LStation Then DrawStations;
 If LVille Then DrawCities;
 DrawLieux;
 DrawMeasure;
 DrawMapOverlay;
 SetViewPort(0,0,639,479,True);
 SetColor(8);
 Rectangle(MapX1-1,MapY1-1,MapX2+1,MapY2+1);
 MShow;
End;

{ ---------------------------------------------------------------------------
  Menus deroulants
  --------------------------------------------------------------------------- }

Procedure AddMenu(i:Integer;t:String);Begin
 Mn[i].tt:=t;
 Mn[i].n:=0;
End;

Procedure AddItem(i:Integer;c:String;id:Integer);Begin
 Mn[i].it[Mn[i].n].cap:=c;
 Mn[i].it[Mn[i].n].id:=id;
 Inc(Mn[i].n);
End;

Procedure BuildMenus;
Var
 i,j,x,w:Integer;
Begin
 AddMenu(0,'Fichier');
 AddItem(0,'Ouvrir un fichier...',101);
 AddItem(0,'Ouvrir un echantillon...',102);
 AddItem(0,'Exporter la sequence...',103);
 AddItem(0,'-',0);
 AddItem(0,'Quitter',109);
 AddMenu(1,'Source');
 AddItem(1,'MRMS (NOAA)',201);
 AddItem(1,'NEXRAD Niveau II',202);
 AddItem(1,'NOAA nowCOAST',203);
 AddItem(1,'HRRR (prevision)',204);
 AddItem(1,'RainViewer',205);
 AddItem(1,'ECCC GeoMet',206);
 AddItem(1,'-',0);
 AddItem(1,'Informations source...',210);
 AddItem(1,'Adresse (URL) source...',211);
 AddMenu(2,'Couches');
 AddItem(2,'Radar',301);
 AddItem(2,'Foudre',302);
 AddItem(2,'Alertes',303);
 AddItem(2,'Stations',304);
 AddItem(2,'Villes',305);
 AddItem(2,'Grille lat/lon',306);
 AddItem(2,'Contours',307);
 AddItem(2,'Cellules orageuses',308);
 AddItem(2,'-',0);
 AddItem(2,'Seuil radar 10 dBZ',311);
 AddItem(2,'Seuil radar 20 dBZ',312);
 AddItem(2,'Seuil radar 30 dBZ',313);
 AddItem(2,'Seuil radar 40 dBZ',314);
 AddMenu(3,'Animation');
 AddItem(3,'Lecture / Pause',401);
 AddItem(3,'Image precedente',402);
 AddItem(3,'Image suivante',403);
 AddItem(3,'Premiere image',404);
 AddItem(3,'Derniere image',405);
 AddItem(3,'-',0);
 AddItem(3,'Plus rapide',406);
 AddItem(3,'Plus lent',407);
 AddItem(3,'Lecture en boucle',408);
 AddMenu(4,'Outils');
 AddItem(4,'Mesurer une distance',501);
 AddItem(4,'Suivre une cellule',502);
 AddItem(4,'-',0);
 AddItem(4,'Zoom avant',503);
 AddItem(4,'Zoom arriere',504);
 AddItem(4,'Ajuster a la zone',505);
 AddItem(4,'Centrer sur le lieu',506);
 AddItem(4,'-',0);
 AddItem(4,'Effacer mesure/suivi',507);
 AddMenu(5,'Aide');
 AddItem(5,'Aide et raccourcis',601);
 AddItem(5,'Legende radar',602);
 AddItem(5,'Formats de fichiers',603);
 AddItem(5,'A propos',604);
 x:=4;
 For i:=0 to NbMenu-1do Begin
  Mn[i].x:=x;
  Inc(x,Length(Mn[i].tt)*8+16);
  w:=0;
  For j:=0 to Mn[i].n-1do If Length(Mn[i].it[j].cap)>w Then w:=Length(Mn[i].it[j].cap);
  Mn[i].w:=w*8+32;
 End;
End;

Function IsChecked(id:Integer):Boolean;Begin
 Case id of
  201..206:IsChecked:=SrcIdx=id-201;
  301:IsChecked:=LRadar;
  302:IsChecked:=LFoudre;
  303:IsChecked:=LAlert;
  304:IsChecked:=LStation;
  305:IsChecked:=LVille;
  306:IsChecked:=LGrille;
  307:IsChecked:=LCoast;
  308:IsChecked:=LCell;
  311:IsChecked:=MinLv=5;
  312:IsChecked:=MinLv=10;
  313:IsChecked:=MinLv=15;
  314:IsChecked:=MinLv=20;
  401:IsChecked:=Playing;
  408:IsChecked:=Looping;
  501:IsChecked:=Tool=1;
  502:IsChecked:=Tool=2;
  Else IsChecked:=False;
 End;
End;

Procedure DrawMenuBar;
Var
 i:Integer;
Begin
 FillR(0,0,639,MenuH-1,7);
 SetColor(8);
 Line(0,MenuH-1,639,MenuH-1);
 For i:=0 to NbMenu-1do Begin
  If i=MenuOpen Then Begin
   FillR(Mn[i].x,0,Mn[i].x+Length(Mn[i].tt)*8+11,MenuH-2,1);
   Txt(Mn[i].x+6,3,Mn[i].tt,15);
  End
   Else
  Txt(Mn[i].x+6,3,Mn[i].tt,0);
 End;
 Txt(640-8*17,3,'StormView Radar',8);
End;

Procedure DrawDropdown(m:Integer);
Var
 i,x1,y1,x2,y2,y:Integer;
Begin
 MHide;
 x1:=Mn[m].x;y1:=MenuH;x2:=x1+Mn[m].w;y2:=y1+Mn[m].n*12+4;
 FillR(x1,y1,x2,y2,7);
 Frame3D(x1,y1,x2,y2,True);
 For i:=0 to Mn[m].n-1do Begin
  y:=y1+2+i*12;
  If Mn[m].it[i].id=0Then Begin
   SetColor(8);
   Line(x1+3,y+5,x2-3,y+5);
  End
   Else
  Begin
   If i=MenuSel Then Begin
    FillR(x1+2,y,x2-2,y+11,1);
    SetColor(15);
   End
    Else
   SetColor(0);
   If IsChecked(Mn[m].it[i].id)Then OutTextXY(x1+6,y+2,'*');
   OutTextXY(x1+18,y+2,Mn[m].it[i].cap);
  End;
 End;
 MShow;
End;

Function MenuAt(x:Integer):Integer;
Var
 i:Integer;
Begin
 MenuAt:=-1;
 For i:=0 to NbMenu-1do If(x>=Mn[i].x)and(x<=Mn[i].x+Length(Mn[i].tt)*8+11)Then MenuAt:=i;
End;

Function ItemAt(m,x,y:Integer):Integer;
Var
 i:Integer;
Begin
 ItemAt:=-1;
 If(m<0)or Not InRect(x,y,Mn[m].x,MenuH,Mn[m].x+Mn[m].w,MenuH+Mn[m].n*12+4)Then Exit;
 i:=(y-MenuH-2)div 12;
 If(i>=0)and(i<Mn[m].n)and(Mn[m].it[i].id<>0)Then ItemAt:=i;
End;

{ ---------------------------------------------------------------------------
  Barre d'outils, panneaux lateraux, ligne temporelle et barre d'etat
  --------------------------------------------------------------------------- }

Function LayerCount:Integer;
Var
 n:Integer;
Begin
 n:=0;
 If LRadar Then Inc(n);
 If LFoudre Then Inc(n);
 If LAlert Then Inc(n);
 If LStation Then Inc(n);
 If LVille Then Inc(n);
 If LGrille Then Inc(n);
 If LCoast Then Inc(n);
 If LCell Then Inc(n);
 LayerCount:=n;
End;

Function BtnOn(i:Integer):Boolean;Begin
 Case i of
  0:BtnOn:=LRadar;
  1:BtnOn:=LFoudre;
  2:BtnOn:=LAlert;
  3:BtnOn:=MenuOpen=2;
  4:BtnOn:=Tool=1;
  5:BtnOn:=Tool=2;
  Else BtnOn:=False;
 End;
End;

Procedure DrawToolbar;
Var
 i,x:Integer;
 s:String;
Begin
 MHide;
 FillR(0,ToolY1,639,ToolY2,0);
 x:=6;
 For i:=0 to 5do Begin
  s:=BtnTxt[i];
  If i=3Then s:=s+' '+IntStr(LayerCount);
  BtnX[i]:=x;
  BtnW[i]:=Length(s)*8+14;
  If BtnOn(i)Then Begin
   FillR(x,ToolY1+2,x+BtnW[i],ToolY2-2,1);
   SetColor(3);
   Rectangle(x,ToolY1+2,x+BtnW[i],ToolY2-2);
   Txt(x+7,ToolY1+7,s,11);
  End
   Else
  Begin
   SetColor(8);
   Rectangle(x,ToolY1+2,x+BtnW[i],ToolY2-2);
   Txt(x+7,ToolY1+7,s,7);
  End;
  Inc(x,BtnW[i]+5);
 End;
 If NF>0Then Txt(x+8,ToolY1+7,Copy(Src[SrcIdx].nom+' - '+Title,1,(640-x-12)div 8),3);
 MShow;
End;

Function NearStation(lo,la:Real):Integer;
Var
 i,b:Integer;
 d,bd:Real;
Begin
 b:=-1;bd:=250;
 For i:=0 to NS-1do Begin
  d:=DistKm(lo,la,Sta[i].x,Sta[i].y);
  If d<bd Then Begin
   bd:=d;b:=i;
  End;
 End;
 NearStation:=b;
End;

Function NearCell(f:Integer;lo,la:Real;Var d:Real):Integer;
Var
 i,b:Integer;
 dd:Real;
Begin
 b:=-1;d:=1E9;
 If(f>=0)and(f<NF)Then For i:=0 to CN[f]-1do Begin
  dd:=DistKm(lo,la,Cl[f,i].x,Cl[f,i].y);
  If dd<d Then Begin
   d:=dd;b:=i;
  End;
 End;
 NearCell:=b;
End;

Procedure DrawLeft;
Var
 i,y,a,s,c:Integer;
 d:Real;
Begin
 MHide;
 FillR(0,PanY1,LeftX2,PanY2,0);
 SetColor(8);
 Rectangle(0,PanY1-1,LeftX2,PanY2+1);
 Txt(6,PanY1+4,'LIEUX',11);
 For i:=0 to NL-1do Begin
  y:=PanY1+16+i*14;
  If i=SelL Then FillR(2,y-2,LeftX2-2,y+10,1);
  a:=AlertAt(Lx[i].x,Lx[i].y);
  If a>=0Then c:=Kinds[Al[a].kind].col Else c:=2;
  SetFillStyle(SolidFill,c);
  FillEllipse(9,y+3,3,3);
  Txt(18,y,Copy(Lx[i].nm,1,13),15);
 End;
 y:=PanY1+16+NL*14+8;
 SetColor(8);
 Line(2,y-4,LeftX2-2,y-4);
 Txt(6,y,'ETAT DU LIEU',11);
 Inc(y,13);
 If(NL>0)and(SelL<NL)Then Begin
  a:=AlertAt(Lx[SelL].x,Lx[SelL].y);
  If a>=0Then Begin
   Txt(6,y,'ALERTE '+Kinds[Al[a].kind].cd,Kinds[Al[a].kind].col);
   Txt(6,y+10,Copy(Al[a].ti,1,15),Kinds[Al[a].kind].col);
   Inc(y,24);
  End
   Else
  Begin
   Txt(6,y,'Aucune alerte',10);
   Inc(y,12);
  End;
  c:=DbzAt(Lx[SelL].x,Lx[SelL].y);
  If c>=0Then Begin
   Txt(6,y,'Radar : '+IntStr(c)+' dBZ',15);
   Txt(6,y+10,IntensText(c),7);
  End
   Else
  Txt(6,y,'Radar : hors zone',8);
  Inc(y,24);
  i:=NearCell(Cur,Lx[SelL].x,Lx[SelL].y,d);
  If i>=0Then Begin
   Txt(6,y,'Cellule '+IntStr(Cl[Cur,i].mx*2)+' dBZ',15);
   Txt(6,y+10,IntStr(Round(d))+' km '+Compass(BearingDeg(Lx[SelL].x,Lx[SelL].y,Cl[Cur,i].x,Cl[Cur,i].y)),7);
   Inc(y,24);
  End;
  Inc(y,4);
  SetColor(8);
  Line(2,y-4,LeftX2-2,y-4);
  Txt(6,y,'CONDITIONS',11);
  Inc(y,13);
  s:=NearStation(Lx[SelL].x,Lx[SelL].y);
  If s>=0Then Begin
   SetTextStyle(DefaultFont,HorizDir,2);
   Txt(6,y,IntStr(Round(Sta[s].t))+' C',15);
   SetTextStyle(DefaultFont,HorizDir,1);
   Txt(6,y+20,'Vent '+Compass(Sta[s].dr)+' '+IntStr(Sta[s].v)+' km/h',7);
   Txt(6,y+30,'Rafale '+IntStr(Sta[s].r)+' km/h',7);
   Txt(6,y+40,'Press. '+IntStr(Sta[s].p)+' hPa',7);
   Txt(6,y+50,Sta[s].id+' ('+IntStr(Round(DistKm(Lx[SelL].x,Lx[SelL].y,Sta[s].x,Sta[s].y)))+' km)',8);
  End
   Else
  Txt(6,y,'Aucune station',8);
 End;
 MShow;
End;

Procedure DrawRight;
Var
 i,y,x0,n,k,f0,f1,a:Integer;
 d,h:Real;
 s:String;
Begin
 MHide;
 FillR(RightX1,PanY1,639,PanY2,0);
 SetColor(8);
 Rectangle(RightX1-1,PanY1-1,639,PanY2+1);
 x0:=RightX1+5;
 y:=PanY1+4;
 RAlN:=0;RBackY:=-1;
 If(SelAl>=0)and(SelAl<NA)Then Begin
  RBackY:=y;
  FillR(x0,y,x0+80,y+12,8);
  Frame3D(x0,y,x0+80,y+12,True);
  Txt(x0+4,y+3,'< Retour',15);
  Inc(y,18);
  a:=SelAl;
  Txt(x0,y,Kinds[Al[a].kind].nom,Kinds[Al[a].kind].col);
  Inc(y,12);
  y:=Wrap(Al[a].ti,x0,y,19,15);
  Inc(y,4);
  If NF>0Then Begin
   If AlertOn(a)Then Begin
    Txt(x0,y,'Etat : active',10);
    h:=(Al[a].t1-Frames[Cur].tm)/60;
    Txt(x0,y+10,'Expire dans '+IntStr(Trunc(h))+'h '+Pad2(Round((h-Trunc(h))*60))+'m',7);
   End
    Else
   Txt(x0,y,'Etat : inactive',8);
  End;
  Inc(y,24);
  Txt(x0,y,'Debut '+TimeStr(Al[a].t0),7);
  Txt(x0,y+10,'Fin   '+TimeStr(Al[a].t1),7);
  Txt(x0,y+20,'Type  '+Kinds[Al[a].kind].cd,7);
  Inc(y,36);
  Txt(x0,y,'DETAILS',11);
  Inc(y,12);
  If Al[a].tx=''Then Txt(x0,y,'(aucun detail)',8)
   Else y:=Wrap(Al[a].tx,x0,y,19,7);
 End
  Else
 Begin
  Txt(x0,y,'VUE D''ENSEMBLE',11);
  Inc(y,12);
  Txt(x0,y,Copy(Src[SrcIdx].nom,1,19),15);
  Inc(y,10);
  If NF>0Then Begin
   Txt(x0,y,'Image '+IntStr(Cur+1)+'/'+IntStr(NF)+' '+TimeStr(Frames[Cur].tm),7);
   Inc(y,10);
   Txt(x0,y,'Pas : '+IntStr(StepMin)+' min',7);
   Inc(y,10);
   Txt(x0,y,'Max : '+IntStr(MaxDbz)+' dBZ',7);
   Inc(y,10);
   Txt(x0,y,'Cellules 40+ : '+IntStr(CN[Cur]),7);
   Inc(y,10);
  End;
  y:=Wrap(ProdName,x0,y,19,8);
  Inc(y,4);
  SetColor(8);
  Line(x0,y,637,y);
  Inc(y,5);
  Txt(x0,y,'LEGENDE (dBZ)',11);
  Inc(y,12);
  For i:=0 to 10do Begin
   FillR(x0,y,x0+22,y+7,LegCol[i]);
   If i<10Then s:=IntStr(LegDbz[i])+'-'+IntStr(LegDbz[i+1]-1) Else s:=IntStr(LegDbz[i])+'+';
   Txt(x0+30,y,s,7);
   Inc(y,10);
  End;
  Inc(y,3);
  SetColor(8);
  Line(x0,y,637,y);
  Inc(y,5);
  n:=0;
  For i:=0 to NA-1do If AlertOn(i)Then Inc(n);
  Txt(x0,y,'ALERTES ACTIVES ('+IntStr(n)+')',11);
  Inc(y,12);
  For i:=0 to NA-1do If AlertOn(i)and(y<PanY2-100)Then Begin
   SetFillStyle(SolidFill,Kinds[Al[i].kind].col);
   Bar(x0,y,x0+6,y+6);
   Txt(x0+11,y,Copy(Kinds[Al[i].kind].cd+' '+Al[i].ti,1,17),15);
   RAlY[RAlN]:=y;RAlI[RAlN]:=i;Inc(RAlN);
   Inc(y,10);
  End;
  If n=0Then Begin
   Txt(x0,y,'Aucune alerte',10);
   Inc(y,10);
  End;
  Inc(y,3);
  If TrOn Then Begin
   SetColor(8);
   Line(x0,y,637,y);
   Inc(y,5);
   Txt(x0,y,'SUIVI DE CELLULE',13);
   Inc(y,12);
   Txt(x0,y,'Vitesse '+IntStr(Round(TrSpd))+' km/h',15);
   Txt(x0,y+10,'Vers '+Compass(TrDir)+' ('+IntStr(Round(TrDir))+' deg)',15);
   Txt(x0,y+20,'Max '+IntStr(Round(TrMx))+' dBZ',7);
   Inc(y,30);
   If(NL>0)and(TrSpd>0.5)Then Begin
    f0:=-1;f1:=-1;
    For k:=0 to NF-1do If TrOk[k]Then Begin
     If f0<0Then f0:=k;
     f1:=k;
    End;
    d:=DistKm(TrX[f1],TrY[f1],Lx[SelL].x,Lx[SelL].y);
    h:=BearingDeg(TrX[f1],TrY[f1],Lx[SelL].x,Lx[SelL].y)-TrDir;
    If h<0Then h:=h+360;
    If(h<35)or(h>325)Then Begin
     k:=Round(d/TrSpd*60);
     Txt(x0,y,Copy(Lx[SelL].nm,1,19),11);
     Txt(x0,y+10,IntStr(Round(d))+' km, arrivee',7);
     Txt(x0,y+20,'dans ~'+IntStr(k div 60)+'h '+Pad2(k Mod 60)+'m',14);
    End
     Else Txt(x0,y,'Ne vise pas '+Copy(Lx[SelL].nm,1,7),8);
    Inc(y,32);
   End;
  End;
  If MeasN=2Then Begin
   SetColor(8);
   Line(x0,y,637,y);
   Inc(y,5);
   Txt(x0,y,'MESURE',11);
   d:=DistKm(MeasX[0],MeasY[0],MeasX[1],MeasY[1]);
   Txt(x0,y+12,RStr(d,1)+' km',15);
   Txt(x0,y+22,RStr(d/1.609344,1)+' mi',7);
   h:=BearingDeg(MeasX[0],MeasY[0],MeasX[1],MeasY[1]);
   Txt(x0,y+32,'Cap '+IntStr(Round(h))+' '+Compass(h),7);
  End;
 End;
 MShow;
End;

Function TlX(i:Integer):Integer;Begin
 If NF<=1Then TlX:=150 Else TlX:=150+Round(i*(468-150)/(NF-1));
End;

Procedure DrawTimeline;
Const
 Cap:Array[0..4] of String[2]=('|<','<','>','>','>|');
Var
 i,x:Integer;
 s:String;
Begin
 MHide;
 FillR(0,TimeY1,639,TimeY2,0);
 SetColor(8);
 Line(0,TimeY1,639,TimeY1);
 For i:=0 to 4do Begin
  x:=4+i*28;
  FillR(x,TimeY1+3,x+25,TimeY2-2,8);
  Frame3D(x,TimeY1+3,x+25,TimeY2-2,True);
  s:=Cap[i];
  If(i=2)and Playing Then s:='||';
  Txt(x+13-Length(s)*4,TimeY1+7,s,15);
 End;
 SetColor(8);
 Line(150,TimeY1+10,468,TimeY1+10);
 If NF>0Then Begin
  For i:=0 to NF-1do Begin
   SetColor(7);
   Line(TlX(i),TimeY1+6,TlX(i),TimeY1+14);
  End;
  x:=TlX(Cur);
  FillR(x-3,TimeY1+3,x+3,TimeY2-3,11);
  Txt(478,TimeY1+7,Copy(FrameLbl(Cur),1,20),11);
 End;
 MShow;
End;

Procedure DrawStatus;
Var
 s:String;
Begin
 MHide;
 FillR(0,StatY1,639,479,7);
 SetColor(8);
 Line(0,StatY1,639,StatY1);
 Txt(6,StatY1+6,Copy(StatMsg,1,60),0);
 s:=HovTxt;
 Txt(634-Length(s)*8,StatY1+6,s,1);
 MShow;
End;

Procedure Msg(s:String);Begin
 StatMsg:=Copy(s,1,80);
 DrawStatus;
End;

Procedure DrawAll;Begin
 MHide;
 FillR(0,0,639,479,0);
 DrawMap;
 DrawLeft;
 DrawRight;
 DrawToolbar;
 DrawTimeline;
 DrawStatus;
 DrawMenuBar;
 MShow;
End;

Procedure FrameChanged;Begin
 ComputeMax;
 DrawMap;
 DrawLeft;
 DrawRight;
 DrawTimeline;
End;

Procedure SetFrame(n:Integer);Begin
 If NF=0Then Exit;
 If n<0Then n:=0;
 If n>=NF Then n:=NF-1;
 If n<>Cur Then Begin
  Cur:=n;
  FrameChanged;
 End;
End;

{ ---------------------------------------------------------------------------
  Boites de dialogue
  --------------------------------------------------------------------------- }

Procedure WaitRelease;
Var
 mx,my,mb:LongInt;
Begin
 Repeat
  GetMouseState(mx,my,mb);
  Delay(5);
 Until(mb And 3)=0;
End;

Procedure DlgFrame(x1,y1,x2,y2:Integer;ttl:String);Begin
 FillR(x1+5,y1+5,x2+5,y2+5,8);
 FillR(x1,y1,x2,y2,7);
 Frame3D(x1,y1,x2,y2,True);
 FillR(x1+3,y1+3,x2-3,y1+15,1);
 Txt(x1+8,y1+6,ttl,15);
End;

Procedure AddDL(s:String);Begin
 While(Length(s)>74)and(DN<39)do Begin
  DL[DN]:=Copy(s,1,74);
  Inc(DN);
  Delete(s,1,74);
 End;
 If DN<40Then Begin
  DL[DN]:=s;
  Inc(DN);
 End;
End;

Procedure InfoBox(ttl:String);
Var
 i,w,h,x1,y1,x2,y2:Integer;
 mx,my,mb:LongInt;
 k:Char;
Begin
 w:=240;
 For i:=0 to DN-1do If Length(DL[i])*8+24>w Then w:=Length(DL[i])*8+24;
 If w>630Then w:=630;
 h:=DN*10+58;
 x1:=(640-w)div 2;y1:=(480-h)div 2;x2:=x1+w;y2:=y1+h;
 MHide;
 DlgFrame(x1,y1,x2,y2,ttl);
 For i:=0 to DN-1do Txt(x1+12,y1+24+i*10,DL[i],0);
 FillR((x1+x2)div 2-26,y2-22,(x1+x2)div 2+26,y2-6,8);
 Frame3D((x1+x2)div 2-26,y2-22,(x1+x2)div 2+26,y2-6,True);
 Txt((x1+x2)div 2-8,y2-18,'OK',15);
 MShow;
 WaitRelease;
 Repeat
  GetMouseState(mx,my,mb);
  If KeyPressed Then Begin
   k:=ReadKey;
   If k=#0Then k:=ReadKey;
   Break;
  End;
  If(mb And 1)<>0Then Break;
  Delay(10);
 Until False;
 WaitRelease;
 DrawAll;
End;

{ Choix dans la liste DL[0..DN-1] ; retourne l'index ou -1 }
Function ListBox(ttl:String):Integer;
Var
 i,w,h,x1,y1,x2,y2,sel,old:Integer;
 mx,my,mb:LongInt;
 k:Char;
 done:Boolean;

 Procedure Row(j:Integer);
 Var
  y:Integer;
 Begin
  y:=y1+24+j*11;
  If j=sel Then Begin
   FillR(x1+6,y-1,x2-6,y+9,1);
   Txt(x1+10,y,DL[j],15);
  End
   Else Begin
   FillR(x1+6,y-1,x2-6,y+9,7);
   Txt(x1+10,y,DL[j],0);
  End;
 End;

Begin
 w:=300;
 For i:=0 to DN-1do If Length(DL[i])*8+28>w Then w:=Length(DL[i])*8+28;
 If w>630Then w:=630;
 h:=DN*11+50;
 x1:=(640-w)div 2;y1:=(480-h)div 2;x2:=x1+w;y2:=y1+h;
 sel:=0;
 MHide;
 DlgFrame(x1,y1,x2,y2,ttl);
 For i:=0 to DN-1do Row(i);
 Txt(x1+10,y2-14,'Clic ou Entree = choisir, Echap = annuler',8);
 MShow;
 WaitRelease;
 ListBox:=-1;
 done:=False;
 Repeat
  GetMouseState(mx,my,mb);
  If(mb And 1)<>0Then Begin
   If InRect(mx,my,x1+6,y1+23,x2-6,y1+23+DN*11)Then Begin
    sel:=(my-y1-23)div 11;
    ListBox:=sel;
   End;
   done:=True;
  End;
  If KeyPressed Then Begin
   k:=ReadKey;
   old:=sel;
   If k=#0Then Begin
    k:=ReadKey;
    If(k=#72)and(sel>0)Then Dec(sel);
    If(k=#80)and(sel<DN-1)Then Inc(sel);
    If sel<>old Then Begin
     MHide;Row(old);Row(sel);MShow;
    End;
   End
    Else
   If k=#13Then Begin
    ListBox:=sel;
    done:=True;
   End
    Else
   If k=#27Then done:=True;
  End;
  Delay(10);
 Until done;
 WaitRelease;
 DrawAll;
End;

Function InputBox(ttl,prompt:String;Var s:String):Boolean;
Var
 x1,y1,x2,y2:Integer;
 k:Char;
 done:Boolean;
 t:String;

 Procedure Field;Begin
  MHide;
  FillR(x1+10,y1+42,x2-10,y1+56,15);
  Txt(x1+14,y1+46,Copy(t+'_',Length(t)+2-IMin(Length(t)+1,49),49),0);
  MShow;
 End;

Begin
 x1:=100;y1:=180;x2:=540;y2:=270;
 t:=s;
 MHide;
 DlgFrame(x1,y1,x2,y2,ttl);
 Txt(x1+12,y1+24,prompt,0);
 Txt(x1+12,y2-14,'Entree = valider, Echap = annuler',8);
 MShow;
 Field;
 WaitRelease;
 InputBox:=False;
 done:=False;
 Repeat
  If KeyPressed Then Begin
   k:=ReadKey;
   If k=#0Then ReadKey
    Else If k=#13Then Begin
     s:=t;
     InputBox:=True;
     done:=True;
    End
    Else If k=#27Then done:=True
    Else If k=#8Then Begin
     If Length(t)>0Then Dec(t[0]);
     Field;
    End
    Else If(k>=' ')and(Length(t)<60)Then Begin
     t:=t+k;
     Field;
    End;
  End;
  Delay(10);
 Until done;
 DrawAll;
End;

{ ---------------------------------------------------------------------------
  Suivi de cellule, mesure, export
  --------------------------------------------------------------------------- }

Procedure TrackExtend(dir:Integer);
Var
 f,f2,k:Integer;
 px0,py0,vx,vy,qx,qy,dt,d,lim,maxkm:Real;
 have:Boolean;
Begin
 maxkm:=110*StepMin/60+25;
 f:=Cur;
 px0:=TrX[Cur];py0:=TrY[Cur];
 vx:=0;vy:=0;have:=False;
 While True do Begin
  f2:=f+dir;
  If(f2<0)or(f2>=NF)Then Break;
  dt:=Frames[f2].tm-Frames[f].tm;
  qx:=px0+vx*dt;qy:=py0+vy*dt;
  If have Then lim:=0.5*maxkm+10 Else lim:=maxkm;
  k:=NearCell(f2,qx,qy,d);
  If(k<0)or(d>lim)Then Break;
  vx:=(Cl[f2,k].x-px0)/dt;
  vy:=(Cl[f2,k].y-py0)/dt;
  have:=True;
  px0:=Cl[f2,k].x;py0:=Cl[f2,k].y;
  TrX[f2]:=px0;TrY[f2]:=py0;TrOk[f2]:=True;
  f:=f2;
 End;
End;

Procedure DoTrack(lo,la:Real);
Var
 k,f,f0,f1:Integer;
 d,hrs:Real;
Begin
 k:=NearCell(Cur,lo,la,d);
 If(k<0)or(d>60+StepMin/2)Then Begin
  Msg('Aucune cellule orageuse (>= 40 dBZ) a cet endroit.');
  Exit;
 End;
 FillChar(TrOk,SizeOf(TrOk),0);
 TrX[Cur]:=Cl[Cur,k].x;TrY[Cur]:=Cl[Cur,k].y;TrOk[Cur]:=True;
 TrMx:=Cl[Cur,k].mx*2;
 TrackExtend(1);
 TrackExtend(-1);
 f0:=-1;f1:=-1;
 For f:=0 to NF-1do If TrOk[f]Then Begin
  If f0<0Then f0:=f;
  f1:=f;
 End;
 TrSpd:=0;TrDir:=0;
 If f1>f0 Then Begin
  hrs:=(Frames[f1].tm-Frames[f0].tm)/60;
  TrSpd:=DistKm(TrX[f0],TrY[f0],TrX[f1],TrY[f1])/hrs;
  TrDir:=BearingDeg(TrX[f0],TrY[f0],TrX[f1],TrY[f1]);
  Msg('Cellule suivie sur '+IntStr(f1-f0+1)+' images : '+IntStr(Round(TrSpd))+' km/h vers '+Compass(TrDir));
 End
  Else Msg('Cellule trouvee, mais non retrouvee dans les autres images.');
 TrOn:=True;
End;

Procedure WriteHead(Var f:Text);Begin
 WriteLn(f,'; StormView Radar - sequence meteorologique (STORMVIEW.PAS)');
 WriteLn(f,'STORMVIEW 1');
 WriteLn(f,'SOURCE ',Src[SrcIdx].nm);
 WriteLn(f,'TITRE ',Title);
 WriteLn(f,'PRODUIT ',ProdName);
 WriteLn(f,'BOITE ',RStr(BLon0,4),' ',RStr(BLat0,4),' ',RStr(BLon1,4),' ',RStr(BLat1,4));
 WriteLn(f,'GRILLE ',GCols,' ',GRows);
 WriteLn(f,'PAS ',StepMin);
End;

Procedure WriteTail(Var f:Text);
Var
 i,j:Integer;
Begin
 For i:=0 to NL-1do WriteLn(f,'LIEU ',Lx[i].nm,' ',RStr(Lx[i].x,3),' ',RStr(Lx[i].y,3));
 For i:=0 to NS-1do WriteLn(f,'STATION ',Sta[i].id,' ',RStr(Sta[i].x,3),' ',RStr(Sta[i].y,3),' ',
                  RStr(Sta[i].t,1),' ',Sta[i].dr,' ',Sta[i].v,' ',Sta[i].r,' ',Sta[i].p);
 For i:=0 to NA-1do Begin
  WriteLn(f,'ALERTE ',Kinds[Al[i].kind].cd,' ',TimeStr(Al[i].t0),' ',TimeStr(Al[i].t1),' ',Al[i].ti);
  Write(f,'POLY');
  For j:=0 to Al[i].n-1do Write(f,' ',RStr(Al[i].px[j],3),' ',RStr(Al[i].py[j],3));
  WriteLn(f);
  If Al[i].tx<>''Then WriteLn(f,'DETAIL ',Al[i].tx);
 End;
 For i:=0 to NK-1do WriteLn(f,'FOUDRE ',TimeStr(Stk[i].t),' ',RStr(Stk[i].x,3),' ',RStr(Stk[i].y,3));
End;

Function WriteSVR(fn:String):Boolean;
Var
 f:Text;
 i,r,c:Integer;
 s:String;
Begin
 WriteSVR:=False;
 Assign(f,fn);
 {$I-}
 Rewrite(f);
 {$I+}
 If IOResult<>0Then Begin
  LastErr:='Impossible de creer : '+fn;
  Exit;
 End;
 WriteHead(f);
 WriteTail(f);
 For i:=0 to NF-1do Begin
  WriteLn(f,'TRAME ',TimeStr(Frames[i].tm));
  For r:=0 to GRows-1do Begin
   s:='';
   For c:=0 to GCols-1do s:=s+LvChar(Frames[i].g^[r,c]);
   WriteLn(f,s);
  End;
 End;
 Close(f);
 WriteSVR:=True;
End;

{ ---------------------------------------------------------------------------
  Ouverture de fichiers et echantillons
  --------------------------------------------------------------------------- }

Function FileOk(fn:String):Boolean;
Var
 f:File;
Begin
 Assign(f,fn);
 {$I-}
 Reset(f);
 {$I+}
 If IOResult=0Then Begin
  Close(f);
  FileOk:=True;
 End
  Else FileOk:=False;
End;

Function PeekInfo(fn:String):String;
Var
 f:Text;
 ln,cmd,s1,t1,e:String;
 i:Integer;
Begin
 e:=UpStr(Copy(fn,Length(fn)-3,4));
 If e='.ASC'Then Begin
  PeekInfo:='ASC   Grille ESRI ASCII';
  Exit;
 End;
 s1:='';t1:='';
 Assign(f,fn);
 {$I-}
 Reset(f);
 {$I+}
 If IOResult<>0Then Begin
  PeekInfo:='';
  Exit;
 End;
 For i:=1 to 16do If Not Eof(f)Then Begin
  ReadLn(f,ln);
  ln:=CleanLine(ln);
  cmd:=UpStr(Tok(ln));
  If cmd='SOURCE'Then s1:=UpStr(Tok(ln))
   Else If cmd='TITRE'Then t1:=ln;
 End;
 Close(f);
 While Length(s1)<11do s1:=s1+' ';
 PeekInfo:=Copy(s1+t1,1,58);
End;

Procedure ListSamples;
Const
 Pats:Array[0..2] of String[6]=('*.SVR','*.ASC','*.LST');
Var
 sr:SearchRec;
 k,i,j:Integer;
 t:String[40];
 u:String[78];
Begin
 DN:=0;
 For k:=0 to 2do Begin
  FindFirst('TEST'+DirSep+Pats[k],AnyFile,sr);
  While(DosError=0)and(DN<30)do Begin
   If(sr.Attr And Directory)=0Then Begin
    SmpName[DN]:=sr.Name;
    DL[DN]:=Copy(sr.Name+'                ',1,16)+PeekInfo('TEST'+DirSep+sr.Name);
    Inc(DN);
   End;
   FindNext(sr);
  End;
  {$IFDEF FPC}
  FindClose(sr);
  {$ENDIF}
 End;
 For i:=1 to DN-1do Begin
  j:=i;
  While(j>0)and(SmpName[j-1]>SmpName[j])do Begin
   t:=SmpName[j];SmpName[j]:=SmpName[j-1];SmpName[j-1]:=t;
   u:=DL[j];DL[j]:=DL[j-1];DL[j-1]:=u;
   Dec(j);
  End;
 End;
End;

Function LoadNew(fn:String):Boolean;Begin
 LoadNew:=False;
 If Not FileOk(fn)Then Begin
  LastErr:='Fichier introuvable : '+fn;
  Exit;
 End;
 ResetData;
 If LoadAny(fn)and(NF>0)Then Begin
  FinishLoad;
  CurFile:=Copy(fn,1,64);
  LoadNew:=True;
 End
  Else Begin
  If(NF=0)and(LastErr='')Then LastErr:='Aucune image dans '+fn;
  FinishLoad;
 End;
End;

Procedure OpenFile;
Var
 s:String;
Begin
 s:=CurFile;
 If InputBox('Ouvrir un fichier','Nom du fichier (.SVR, .ASC ou .LST) :',s)Then Begin
  LastErr:='';
  If LoadNew(s)Then Begin
   DrawAll;
   Msg('Fichier charge : '+s);
  End
   Else Begin
   DrawAll;
   Msg(LastErr);
  End;
 End;
End;

Procedure OpenSample;
Var
 k:Integer;
Begin
 ListSamples;
 If DN=0Then Begin
  DN:=0;
  AddDL('Aucun fichier .SVR, .ASC ou .LST dans le dossier TEST'+DirSep);
  InfoBox('Echantillons');
  Exit;
 End;
 k:=ListBox('Echantillons du dossier TEST');
 If k>=0Then Begin
  LastErr:='';
  If LoadNew('TEST'+DirSep+SmpName[k])Then Begin
   DrawAll;
   Msg('Echantillon charge : '+SmpName[k]);
  End
   Else Begin
   DrawAll;
   Msg(LastErr);
  End;
 End;
End;

Procedure ExportFile;
Var
 s:String;
Begin
 s:='EXPORT.SVR';
 If(NF>0)and InputBox('Exporter la sequence','Nom du fichier .SVR a creer :',s)Then Begin
  If WriteSVR(s)Then Msg('Sequence exportee : '+s) Else Msg(LastErr);
 End;
End;

{ ---------------------------------------------------------------------------
  Textes d'aide
  --------------------------------------------------------------------------- }

Procedure ShowHelp;Begin
 DN:=0;
 AddDL('SOURIS');
 AddDL('  Glisser sur la carte : deplacer la vue');
 AddDL('  Clic sur une alerte : afficher ses details');
 AddDL('  Clic sur un lieu (liste) : centrer la carte');
 AddDL('  Clic sur la ligne du temps : choisir l''image');
 AddDL('  Clic droit : annuler outil/selection');
 AddDL('');
 AddDL('CLAVIER');
 AddDL('  Espace  Lecture/Pause    PgUp/PgDn  Image -/+');
 AddDL('  < >     Image -/+        Home/End   Premiere/derniere');
 AddDL('  Fleches Deplacer         + -        Zoom');
 AddDL('  R Radar  F Foudre  A Alertes  S Stations  V Villes');
 AddDL('  G Grille K Contours C Cellules  M Mesure  T Suivi');
 AddDL('  L Lieu suivant  Z Ajuster  O Ouvrir  P Echantillons');
 AddDL('  E Exporter  F1 Aide  F10 Menus  Q Quitter');
 InfoBox('Aide et raccourcis');
End;

Procedure ShowLegend;
Var
 i:Integer;
Begin
 DN:=0;
 AddDL('Reflectivite radar (dBZ) :');
 For i:=0 to 10do Begin
  If i<10Then AddDL('  '+IntStr(LegDbz[i])+' a '+IntStr(LegDbz[i+1]-1)+' dBZ : '+IntensText(LegDbz[i]))
   Else AddDL('  '+IntStr(LegDbz[i])+' dBZ et plus : '+IntensText(LegDbz[i]));
 End;
 AddDL('');
 AddDL('Alertes (contour epais, couleur selon le type) :');
 For i:=0 to NbKind-1do AddDL('  '+Kinds[i].cd+'  '+Kinds[i].nom);
 InfoBox('Legende');
End;

Procedure ShowFormats;Begin
 DN:=0;
 AddDL('Fichier .SVR (texte, une instruction par ligne) :');
 AddDL(' SOURCE nom | TITRE texte | PRODUIT texte | PAS minutes');
 AddDL(' BOITE lonmin latmin lonmax latmax | GRILLE colonnes lignes');
 AddDL(' LIEU nom lon lat | STATION id lon lat tC dir kmh raf hPa');
 AddDL(' FOUDRE hh:mm lon lat');
 AddDL(' ALERTE type hh:mm hh:mm titre / POLY lon lat ... / DETAIL texte');
 AddDL(' TRAME hh:mm puis une ligne par rangee (0-9,A-Z = 2 dBZ/niveau)');
 AddDL(' RADAR id lon lat portee_km + RADIAUX n portes : balayage polaire');
 AddDL('Fichier .ASC : grille ESRI ASCII (gdal_translate -of AAIGrid),');
 AddDL(' une image par fichier. Fichier .LST : liste de fichiers .ASC');
 AddDL(' (options SOURCE, PAS, HEURE, MMH, TITRE).');
 AddDL('Types d''alertes : TOR FFW SVR SMW WSW HWW FLW RFW EHW VEI');
 InfoBox('Formats de fichiers');
End;

Procedure ShowAbout;Begin
 DN:=0;
 AddDL('StormView Radar (clone) version 1.00');
 AddDL('Projet METEOPOLIS - Sylvain Maltais (support@gladir.com)');
 AddDL('https://www.gladir.com/meteopolis');
 AddDL('');
 AddDL('Visualisation radar anime, alertes, foudre, stations,');
 AddDL('suivi de cellules et mesures. Licence MIT.');
 AddDL('Profils de sources : MRMS, NEXRAD, nowCOAST, HRRR,');
 AddDL('RainViewer et ECCC GeoMet.');
 InfoBox('A propos');
End;

Procedure ShowSource(url:Boolean);
Var
 s:TSrcInfo;
Begin
 s:=Src[SrcIdx];
 DN:=0;
 AddDL(s.nom);
 AddDL('');
 AddDL('Produit     : '+s.prod);
 AddDL('Resolution  : '+s.res+'   Pas typique : '+IntStr(s.pas)+' min');
 AddDL('Conversion  : '+s.fmt);
 AddDL('Adresse     :');
 AddDL(s.url);
 AddDL('');
 AddDL('Ce programme ne fait aucun acces reseau : telechargez les');
 AddDL('donnees (curl, wget), convertissez-les en .ASC ou .SVR,');
 AddDL('puis ouvrez-les avec Fichier > Ouvrir.');
 If url Then InfoBox('Adresse de la source') Else InfoBox('Informations sur la source');
End;

{ ---------------------------------------------------------------------------
  Commandes
  --------------------------------------------------------------------------- }

Procedure ZoomBy(f:Real);Begin
 VScale:=VScale*f;
 If VScale<3Then VScale:=3;
 If VScale>4000Then VScale:=4000;
 DrawMap;
End;

Procedure CenterOn(lo,la:Real);Begin
 VLon:=lo;VLat:=la;
 CosV:=Cos(VLat*Pi/180);
 DrawMap;
End;

Procedure ClearTools;Begin
 Tool:=0;
 MeasN:=0;
 TrOn:=False;
 SelAl:=-1;
End;

Procedure SetPlay(p:Boolean);Begin
 Playing:=p;
 If Playing and(Cur>=NF-1)Then Cur:=0;
 If Playing Then FrameChanged Else DrawTimeline;
End;

Procedure DoCmd(id:Integer);Begin
 Case id of
  101:OpenFile;
  102:OpenSample;
  103:ExportFile;
  109:Quit:=True;
  201..206:Begin
   SrcIdx:=id-201;
   If NF>0Then Begin
    ProdName:=Src[SrcIdx].prod;
   End;
   DrawAll;
   Msg('Profil de source : '+Src[SrcIdx].nom);
  End;
  210:ShowSource(False);
  211:ShowSource(True);
  301:Begin LRadar:=Not LRadar;DrawMap;End;
  302:Begin LFoudre:=Not LFoudre;DrawMap;End;
  303:Begin LAlert:=Not LAlert;DrawMap;End;
  304:Begin LStation:=Not LStation;DrawMap;End;
  305:Begin LVille:=Not LVille;DrawMap;End;
  306:Begin LGrille:=Not LGrille;DrawMap;End;
  307:Begin LCoast:=Not LCoast;DrawMap;End;
  308:Begin LCell:=Not LCell;DrawMap;End;
  311:Begin MinLv:=5;DrawMap;End;
  312:Begin MinLv:=10;DrawMap;End;
  313:Begin MinLv:=15;DrawMap;End;
  314:Begin MinLv:=20;DrawMap;End;
  401:SetPlay(Not Playing);
  402:Begin SetPlay(False);SetFrame(Cur-1);End;
  403:Begin SetPlay(False);SetFrame(Cur+1);End;
  404:Begin SetPlay(False);SetFrame(0);End;
  405:Begin SetPlay(False);SetFrame(NF-1);End;
  406:Begin
   AnimMs:=IMax(100,AnimMs-150);
   Msg('Delai entre images : '+IntStr(AnimMs)+' ms');
  End;
  407:Begin
   AnimMs:=IMin(3000,AnimMs+150);
   Msg('Delai entre images : '+IntStr(AnimMs)+' ms');
  End;
  408:Looping:=Not Looping;
  501:Begin
   If Tool=1Then Tool:=0 Else Tool:=1;
   MeasN:=0;
   DrawAll;
   If Tool=1Then Msg('Mesure : cliquez deux points sur la carte.');
  End;
  502:Begin
   If Tool=2Then Tool:=0 Else Tool:=2;
   DrawAll;
   If Tool=2Then Msg('Suivi : cliquez sur une cellule orageuse (>= 40 dBZ).');
  End;
  503:ZoomBy(1.5);
  504:ZoomBy(1/1.5);
  505:Begin FitView;DrawMap;End;
  506:If NL>0Then CenterOn(Lx[SelL].x,Lx[SelL].y);
  507:Begin ClearTools;DrawAll;End;
  601:ShowHelp;
  602:ShowLegend;
  603:ShowFormats;
  604:ShowAbout;
 End;
End;

Procedure OpenMenu(m:Integer);Begin
 MenuOpen:=m;
 MenuSel:=-1;
 DrawMenuBar;
 DrawDropdown(m);
End;

Procedure CloseMenu;Begin
 MenuOpen:=-1;
 MenuSel:=-1;
 DrawAll;
End;

Procedure MenuExec(m,i:Integer);
Var
 id:Integer;
Begin
 id:=Mn[m].it[i].id;
 MenuOpen:=-1;
 MenuSel:=-1;
 DrawAll;
 WaitRelease;
 DoCmd(id);
 DrawToolbar;
End;

{ ---------------------------------------------------------------------------
  Gestion des evenements souris et clavier
  --------------------------------------------------------------------------- }

Procedure MapClick(x,y:Integer);
Var
 lo,la:Real;
 i,a:Integer;
Begin
 lo:=UnX(x-MapX1);la:=UnY(y-MapY1);
 Case Tool of
  1:Begin
   If MeasN>=2Then MeasN:=0;
   MeasX[MeasN]:=lo;MeasY[MeasN]:=la;
   Inc(MeasN);
   DrawMap;
   DrawRight;
   If MeasN=2Then Msg('Distance : '+RStr(DistKm(MeasX[0],MeasY[0],MeasX[1],MeasY[1]),1)+' km')
    Else Msg('Mesure : cliquez le second point.');
  End;
  2:Begin
   DoTrack(lo,la);
   DrawMap;
   DrawRight;
  End;
  Else Begin
   For i:=0 to NL-1do If(Abs(PX(Lx[i].x)-(x-MapX1))<8)and(Abs(PY(Lx[i].y)-(y-MapY1))<8)Then Begin
    SelL:=i;
    DrawMap;DrawLeft;DrawRight;
    Msg('Lieu : '+Lx[i].nm);
    Exit;
   End;
   a:=-1;
   If LAlert Then a:=AlertAt(lo,la);
   If a<>SelAl Then Begin
    SelAl:=a;
    DrawMap;
    DrawRight;
    If a>=0Then Msg(Kinds[Al[a].kind].nom+' : '+Al[a].ti);
   End;
  End;
 End;
End;

Procedure ToolbarClick(x:Integer);
Var
 i:Integer;
Begin
 For i:=0 to 5do If(x>=BtnX[i])and(x<=BtnX[i]+BtnW[i])Then Case i of
  0:DoCmd(301);
  1:DoCmd(302);
  2:DoCmd(303);
  3:OpenMenu(2);
  4:DoCmd(501);
  5:DoCmd(502);
 End;
 If MenuOpen<0Then DrawToolbar;
End;

Procedure TimelineClick(x,y:Integer);
Var
 i,b,best:Integer;
Begin
 If x<146Then Begin
  b:=(x-4)div 28;
  Case b of
   0:DoCmd(404);
   1:DoCmd(402);
   2:DoCmd(401);
   3:DoCmd(403);
   4:DoCmd(405);
  End;
 End
  Else
 If(x>=140)and(x<=474)and(NF>0)Then Begin
  best:=0;
  For i:=0 to NF-1do If Abs(TlX(i)-x)<Abs(TlX(best)-x)Then best:=i;
  SetPlay(False);
  SetFrame(best);
  TlDrag:=True;
 End;
End;

Procedure LeftClick(x,y:Integer);
Var
 i:Integer;
Begin
 For i:=0 to NL-1do If InRect(x,y,2,PanY1+14+i*14,LeftX2-2,PanY1+26+i*14)Then Begin
  SelL:=i;
  CenterOn(Lx[i].x,Lx[i].y);
  DrawLeft;
  DrawRight;
  Msg('Lieu : '+Lx[i].nm+'  ('+RStr(Lx[i].y,2)+', '+RStr(Lx[i].x,2)+')');
 End;
End;

Procedure RightClick(x,y:Integer);
Var
 i:Integer;
Begin
 If(SelAl>=0)Then Begin
  If InRect(x,y,RightX1+5,RBackY,RightX1+85,RBackY+12)Then Begin
   SelAl:=-1;
   DrawMap;DrawRight;
  End;
 End
  Else
 For i:=0 to RAlN-1do If(y>=RAlY[i]-1)and(y<=RAlY[i]+9)Then Begin
  SelAl:=RAlI[i];
  DrawMap;DrawRight;
  Msg(Kinds[Al[SelAl].kind].nom+' : '+Al[SelAl].ti);
  Exit;
 End;
End;

Procedure MenuClick(x,y:Integer);
Var
 m,i:Integer;
Begin
 i:=ItemAt(MenuOpen,x,y);
 If i>=0Then MenuExec(MenuOpen,i)
  Else Begin
   m:=-1;
   If y<MenuH Then m:=MenuAt(x);
   If(m>=0)and(m<>MenuOpen)Then OpenMenu(m)
    Else CloseMenu;
  End;
End;

Procedure OnPress(x,y:Integer);
Var
 i:Integer;
Begin
 If MenuOpen>=0Then Begin
  MenuClick(x,y);
  Exit;
 End;
 If y<MenuH Then Begin
  i:=MenuAt(x);
  If i>=0Then OpenMenu(i);
 End
 Else If InRect(x,y,0,ToolY1,639,ToolY2)Then ToolbarClick(x)
 Else If InRect(x,y,0,TimeY1,639,TimeY2)Then TimelineClick(x,y)
 Else If InRect(x,y,0,PanY1,LeftX2,PanY2)Then LeftClick(x,y)
 Else If InRect(x,y,RightX1,PanY1,639,PanY2)Then RightClick(x,y)
 Else If InRect(x,y,MapX1,MapY1,MapX2,MapY2)Then Begin
  If InRect(x-MapX1,y-MapY1,MapW-28,6,MapW-6,28)Then ZoomBy(1.5) Else
  If InRect(x-MapX1,y-MapY1,MapW-28,32,MapW-6,54)Then ZoomBy(1/1.5)
   Else Begin
   DragOn:=True;DragMoved:=False;
   DragSX:=x;DragSY:=y;LastMX:=x;LastMY:=y;
   DragLon:=VLon;DragLat:=VLat;
  End;
 End;
End;

Procedure OnDrag(x,y:LongInt);Begin
 If TlDrag Then Begin
  If NF>0Then SetFrame(Round((x-150)*(NF-1)/(468-150)));
  Exit;
 End;
 If Not DragOn Then Exit;
 If(Abs(x-DragSX)>3)or(Abs(y-DragSY)>3)or DragMoved Then Begin
  If(Abs(x-LastMX)>=3)or(Abs(y-LastMY)>=3)Then Begin
   DragMoved:=True;
   VLon:=DragLon-(x-DragSX)/(VScale*CosV);
   VLat:=DragLat+(y-DragSY)/VScale;
   LastMX:=x;LastMY:=y;
   DrawMap;
  End;
 End;
End;

Procedure OnRelease(x,y:LongInt);Begin
 TlDrag:=False;
 If DragOn Then Begin
  DragOn:=False;
  If Not DragMoved Then MapClick(x,y)
   Else Begin
   CosV:=Cos(VLat*Pi/180);
   DrawMap;
  End;
 End;
End;

Procedure Hover(x,y:LongInt);
Var
 m,i:Integer;
 lo,la:Real;
 d:Integer;
Begin
 If MenuOpen>=0Then Begin
  i:=ItemAt(MenuOpen,x,y);
  If i<>MenuSel Then Begin
   MenuSel:=i;
   DrawDropdown(MenuOpen);
  End;
  If y<MenuH Then Begin
   m:=MenuAt(x);
   If(m>=0)and(m<>MenuOpen)Then Begin
    MenuOpen:=m;
    MenuSel:=-1;
    DrawAll;
    DrawDropdown(m);
   End;
  End;
  Exit;
 End;
 If InRect(x,y,MapX1,MapY1,MapX2,MapY2)Then Begin
  lo:=UnX(x-MapX1);la:=UnY(y-MapY1);
  HovTxt:=RStr(la,2)+','+RStr(lo,2);
  d:=DbzAt(lo,la);
  If d>=0Then HovTxt:=HovTxt+' '+IntStr(d)+'dBZ';
 End
  Else HovTxt:='';
 DrawStatus;
End;

Procedure NextLieu;Begin
 If NL=0Then Exit;
 SelL:=(SelL+1)Mod NL;
 CenterOn(Lx[SelL].x,Lx[SelL].y);
 DrawLeft;DrawRight;
End;

Procedure PanBy(dx,dy:Integer);Begin
 VLon:=VLon+dx/(VScale*CosV);
 VLat:=VLat-dy/VScale;
 CosV:=Cos(VLat*Pi/180);
 DrawMap;
End;

Function AltKey(k:Char):Boolean;
Var
 m:Integer;
Begin
 AltKey:=True;
 m:=-1;
 Case k of
  #33:m:=0;  { Alt+F }
  #31:m:=1;  { Alt+S }
  #46:m:=2;  { Alt+C }
  #30:m:=3;  { Alt+A }
  #24:m:=4;  { Alt+O }
  #53,#164:m:=5;  { Alt+? }
  #45,#107:Begin { Alt+X, Alt+F4 }
   If MenuOpen>=0Then CloseMenu;
   Quit:=True;
   Exit;
  End;
  Else Begin
   AltKey:=False;
   Exit;
  End;
 End;
 If MenuOpen>=0Then Begin
  MenuOpen:=m;
  MenuSel:=0;
  DrawAll;
  DrawDropdown(m);
 End
  Else
 Begin
  OpenMenu(m);
  MenuSel:=0;
  DrawDropdown(m);
 End;
End;

Procedure OnKey;
Var
 k:Char;
 m:Integer;
Begin
 k:=ReadKey;
 If MenuOpen>=0Then Begin
  If k=#0Then Begin
   k:=ReadKey;
   If AltKey(k)Then Exit;
   m:=MenuOpen;
   Case k of
    #75:Begin If m>0Then Dec(m) Else m:=NbMenu-1;MenuOpen:=m;MenuSel:=0;DrawAll;DrawDropdown(m);End;
    #77:Begin m:=(m+1)Mod NbMenu;MenuOpen:=m;MenuSel:=0;DrawAll;DrawDropdown(m);End;
    #72:Begin
     Repeat
      Dec(MenuSel);
      If MenuSel<0Then MenuSel:=Mn[m].n-1;
     Until Mn[m].it[MenuSel].id<>0;
     DrawDropdown(m);
    End;
    #80:Begin
     Repeat
      Inc(MenuSel);
      If MenuSel>=Mn[m].n Then MenuSel:=0;
     Until Mn[m].it[MenuSel].id<>0;
     DrawDropdown(m);
    End;
   End;
  End
   Else
  If(k=#13)and(MenuSel>=0)Then MenuExec(MenuOpen,MenuSel)
   Else If k=#27Then CloseMenu;
  Exit;
 End;
 If k=#0Then Begin
  k:=ReadKey;
  If AltKey(k)Then Exit;
  Case k of
   #59:ShowHelp;
   #68:Begin OpenMenu(0);MenuSel:=0;DrawDropdown(0);End;
   #75:PanBy(-40,0);
   #77:PanBy(40,0);
   #72:PanBy(0,-40);
   #80:PanBy(0,40);
   #73:DoCmd(402);
   #81:DoCmd(403);
   #71:DoCmd(404);
   #79:DoCmd(405);
  End;
 End
  Else
 Case UpCase(k)of
  ' ':DoCmd(401);
  '+','=':ZoomBy(1.5);
  '-','_':ZoomBy(1/1.5);
  ',','<':DoCmd(402);
  '.','>':DoCmd(403);
  'R':DoCmd(301);
  'F':DoCmd(302);
  'A':DoCmd(303);
  'S':DoCmd(304);
  'V':DoCmd(305);
  'G':DoCmd(306);
  'K':DoCmd(307);
  'C':DoCmd(308);
  'M':DoCmd(501);
  'T':DoCmd(502);
  'L':NextLieu;
  'Z':DoCmd(505);
  'O':DoCmd(101);
  'P':DoCmd(102);
  'E':DoCmd(103);
  'H':ShowHelp;
  'Q':Quit:=True;
  #27:Begin
   If(Tool<>0)or TrOn or(MeasN>0)or(SelAl>=0)Then Begin
    ClearTools;
    DrawAll;
   End;
  End;
 End;
 If MenuOpen<0Then DrawToolbar;
End;

Procedure Run;
Var
 mx,my,mb,pmb:LongInt;
 t0,t1,acc:LongInt;
Begin
 DrawAll;
 MouseHid:=1;
 MShow;
 pmb:=0;LastMX:=-1;LastMY:=-1;
 t0:=Ticks;acc:=0;
 Quit:=False;
 Repeat
  GetMouseState(mx,my,mb);
  If((mb And 1)<>0)and((pmb And 1)=0)Then OnPress(mx,my)
   Else If((mb And 1)<>0)Then OnDrag(mx,my)
   Else If((mb And 1)=0)and((pmb And 1)<>0)Then OnRelease(mx,my);
  If((mb And 2)<>0)and((pmb And 2)=0)Then Begin
   If MenuOpen>=0Then CloseMenu
    Else Begin
    ClearTools;
    DrawAll;
    Msg('Outils et selection annules.');
   End;
  End;
  If(mb=0)and((mx<>LastMX)or(my<>LastMY))Then Begin
   LastMX:=mx;LastMY:=my;
   Hover(mx,my);
  End;
  pmb:=mb;
  If KeyPressed Then OnKey;
  t1:=Ticks;
  acc:=acc+((t1-t0+8640000)Mod 8640000)*10;
  t0:=t1;
  If Playing and(MenuOpen<0)Then Begin
   If acc>=AnimMs Then Begin
    acc:=0;
    If Cur>=NF-1Then Begin
     If Looping Then SetFrame(0)
      Else Begin
      Playing:=False;
      DrawTimeline;
     End;
    End
     Else SetFrame(Cur+1);
   End;
  End
   Else If acc>AnimMs Then acc:=AnimMs;
  Delay(10);
 Until Quit;
End;

{$IFDEF FPC}
{ ---------------------------------------------------------------------------
  Generateur des echantillons du dossier TEST (Free Pascal seulement).
  Les donnees sont synthetiques : cellules, lignes de grains et ouragan
  deplaces d'heure en heure, avec alertes, foudre et stations d'essai.
  --------------------------------------------------------------------------- }

Type
 TBlob=Record
  sc,kd:Byte;
  x,y,vx,vy,pk,rad,len,an:Real;
 End;

 TScn=Record
  src:Byte;
  fn:String[14];
  tt:String[50];
  lo0,la0,lo1,la1:Real;
  cols,rows,nfr,step,t0:Integer;
 End;

 TGAl=Record
  sc,kd,bi:Byte;
  h0,h1,w,h:Real;
  ti:String[30];
  tx:String[130];
 End;

Const
 Scn:Array[1..7] of TScn=(
  (src:0; fn:'OKLAHOMA.SVR'; tt:'Orages violents - Oklahoma (MRMS)';
   lo0:-102; la0:33; lo1:-92; la1:39; cols:100; rows:60; nfr:12; step:60; t0:900),
  (src:1; fn:'KTLX.SVR'; tt:'Radar KTLX Oklahoma City (NEXRAD, polaire)';
   lo0:-99.81; la0:33.26; lo1:-94.74; la1:37.40; cols:100; rows:80; nfr:10; step:30; t0:1000),
  (src:2; fn:'FLORIDE.SVR'; tt:'Ouragan sur la Floride (nowCOAST)';
   lo0:-88; la0:22; lo1:-76; la1:32; cols:90; rows:80; nfr:12; step:60; t0:600),
  (src:3; fn:'TEXAS.SVR'; tt:'Prevision HRRR : ligne de grains Texas';
   lo0:-101; la0:28; lo1:-89; la1:36; cols:100; rows:80; nfr:12; step:60; t0:0),
  (src:4; fn:'GRANDSLACS.SVR'; tt:'Pluie sur les Grands Lacs (RainViewer)';
   lo0:-86; la0:41; lo1:-74; la1:48; cols:100; rows:80; nfr:12; step:60; t0:720),
  (src:5; fn:'QUEBEC.SVR'; tt:'Orages sur le Quebec (ECCC GeoMet)';
   lo0:-76; la0:44.5; lo1:-68; la1:48.5; cols:100; rows:72; nfr:12; step:30; t0:1020),
  (src:5; fn:'QC_ASC.LST'; tt:'Montreal en mm/h (grilles ESRI ASCII)';
   lo0:-75; la0:44.8; lo1:-72; la1:46.6; cols:60; rows:36; nfr:4; step:60; t0:1080)
 );

 NBlob=27;
 Blobs:Array[0..NBlob-1] of TBlob=(
  (sc:1; kd:1; x:-101.8; y:35.9; vx:0.55; vy:0.12; pk:56; rad:0.22; len:1.9; an:1.15),
  (sc:1; kd:0; x:-100.6; y:34.6; vx:0.60; vy:0.25; pk:68; rad:0.20; len:0; an:0),
  (sc:1; kd:0; x:-101.2; y:37.6; vx:0.50; vy:0.10; pk:60; rad:0.26; len:0; an:0),
  (sc:1; kd:0; x:-99.0; y:33.7; vx:0.40; vy:0.30; pk:54; rad:0.30; len:0; an:0),
  (sc:1; kd:0; x:-95.5; y:37.9; vx:0.30; vy:0.10; pk:30; rad:1.40; len:0; an:0),
  (sc:1; kd:0; x:-98.0; y:36.9; vx:0.55; vy:0.15; pk:48; rad:0.28; len:0; an:0),
  (sc:2; kd:1; x:-99.4; y:34.8; vx:0.60; vy:0.20; pk:58; rad:0.20; len:1.2; an:1.25),
  (sc:2; kd:0; x:-99.0; y:36.0; vx:0.55; vy:0.15; pk:66; rad:0.18; len:0; an:0),
  (sc:2; kd:0; x:-98.7; y:35.2; vx:0.50; vy:0.10; pk:50; rad:0.28; len:0; an:0),
  (sc:2; kd:0; x:-97.0; y:33.7; vx:0.35; vy:0.20; pk:44; rad:0.35; len:0; an:0),
  (sc:3; kd:2; x:-85.6; y:23.4; vx:0.12; vy:0.55; pk:62; rad:1.50; len:0; an:0),
  (sc:3; kd:0; x:-86.5; y:26.0; vx:0.15; vy:0.50; pk:52; rad:0.40; len:0; an:0),
  (sc:3; kd:0; x:-80.5; y:23.8; vx:0.20; vy:0.40; pk:42; rad:0.80; len:0; an:0),
  (sc:4; kd:1; x:-100.8; y:33.0; vx:0.55; vy:0.05; pk:58; rad:0.25; len:2.6; an:1.35),
  (sc:4; kd:0; x:-100.0; y:30.8; vx:0.60; vy:0.10; pk:62; rad:0.22; len:0; an:0),
  (sc:4; kd:0; x:-99.0; y:34.5; vx:0.50; vy:0.10; pk:52; rad:0.30; len:0; an:0),
  (sc:4; kd:0; x:-97.0; y:29.5; vx:0.40; vy:0.20; pk:36; rad:0.90; len:0; an:0),
  (sc:5; kd:0; x:-84.0; y:43.5; vx:0.40; vy:0.20; pk:42; rad:1.20; len:0; an:0),
  (sc:5; kd:0; x:-83.5; y:45.5; vx:0.45; vy:0.15; pk:55; rad:0.30; len:0; an:0),
  (sc:5; kd:0; x:-85.5; y:42.5; vx:0.50; vy:0.25; pk:50; rad:0.30; len:0; an:0),
  (sc:5; kd:1; x:-85.0; y:44.5; vx:0.40; vy:0.20; pk:45; rad:0.35; len:1.8; an:0.9),
  (sc:6; kd:1; x:-76.2; y:45.3; vx:0.70; vy:0.35; pk:48; rad:0.25; len:1.4; an:0.9),
  (sc:6; kd:0; x:-75.2; y:45.8; vx:0.70; vy:0.30; pk:58; rad:0.18; len:0; an:0),
  (sc:6; kd:0; x:-75.0; y:44.9; vx:0.60; vy:0.35; pk:50; rad:0.22; len:0; an:0),
  (sc:6; kd:0; x:-74.0; y:47.0; vx:0.60; vy:0.25; pk:32; rad:1.00; len:0; an:0),
  (sc:7; kd:0; x:-75.2; y:45.2; vx:0.80; vy:0.25; pk:50; rad:0.25; len:0; an:0),
  (sc:7; kd:0; x:-74.9; y:46.2; vx:0.70; vy:0.20; pk:38; rad:0.40; len:0; an:0)
 );

 NGAl=14;
 GAl:Array[0..NGAl-1] of TGAl=(
  (sc:1; kd:2; bi:1; h0:0.5; h1:3.5; w:1.1; h:0.8; ti:'Orage violent - Oklahoma';
   tx:'Orage violent : vents de 120 km/h et grele de 4 cm. Une supercellule se deplace vers l''est-nord-est a 55 km/h.'),
  (sc:1; kd:0; bi:1; h0:1.5; h1:2.5; w:0.55; h:0.4; ti:'Tornade confirmee';
   tx:'Tornade signalee par le radar. Prenez abri immediatement au niveau le plus bas, loin des fenetres.'),
  (sc:1; kd:9; bi:0; h0:0; h1:6; w:5.5; h:3.2; ti:'Veille d''orage violent';
   tx:'Conditions favorables aux orages violents : grele, vents destructeurs et tornades isolees possibles.'),
  (sc:1; kd:1; bi:3; h0:3; h1:7; w:1.2; h:0.8; ti:'Crue eclair';
   tx:'Fortes pluies : 50 a 80 mm en 2 heures. Ne traversez jamais une route inondee.'),
  (sc:2; kd:2; bi:7; h0:0.5; h1:2.5; w:0.9; h:0.6; ti:'Orage violent - KTLX';
   tx:'Orage violent detecte par le radar KTLX. Grele de 3 cm et rafales de 110 km/h.'),
  (sc:2; kd:0; bi:7; h0:1.5; h1:2.5; w:0.4; h:0.3; ti:'Tornade - Oklahoma City';
   tx:'Rotation intense detectee. Allez immediatement dans un abri.'),
  (sc:3; kd:5; bi:10; h0:0; h1:11; w:4.0; h:3.0; ti:'Vents forts - ouragan';
   tx:'Vents soutenus de 120 km/h pres de l''oeil, rafales superieures a 150 km/h.'),
  (sc:3; kd:6; bi:10; h0:3; h1:11; w:3.0; h:2.0; ti:'Inondation cotiere';
   tx:'Onde de tempete de 2 a 3 m et pluies diluviennes. Evacuez les zones basses.'),
  (sc:3; kd:0; bi:11; h0:2; h1:6; w:0.8; h:0.6; ti:'Tornade - bande externe';
   tx:'Tornade possible dans les bandes externes de l''ouragan.'),
  (sc:4; kd:9; bi:13; h0:0; h1:8; w:5.0; h:3.0; ti:'Veille de ligne de grains';
   tx:'Une ligne de grains avec des vents de 100 km/h est prevue en se deplacant vers l''est.'),
  (sc:4; kd:2; bi:14; h0:3; h1:7; w:1.2; h:0.8; ti:'Orage violent prevu';
   tx:'Cellule isolee prevue devant la ligne principale : grele et vents violents.'),
  (sc:5; kd:6; bi:17; h0:0; h1:10; w:3.0; h:2.0; ti:'Pluie abondante';
   tx:'Pluies persistantes de 25 a 40 mm avec des orages isoles.'),
  (sc:6; kd:2; bi:22; h0:0.5; h1:3.5; w:1.0; h:0.7; ti:'Avertissement d''orage violent';
   tx:'Orage violent pres de Montreal : grele de 2 cm et rafales de 100 km/h. Rentrez a l''interieur.'),
  (sc:6; kd:9; bi:21; h0:0; h1:5.5; w:3.6; h:2.0; ti:'Veille d''orage violent';
   tx:'Conditions favorables a des orages violents sur le sud du Quebec.')
 );

Var
 Seed:LongInt;

Function Rnd(n:Integer):Integer;
Var
 t:Int64;
Begin
 t:=Int64(Seed)*69069+1;
 Seed:=t And $7FFFFFFF;
 Rnd:=(Seed shr 8)Mod n;
End;

Function Hash(a,b:LongInt):Real;
Var
 h:Int64;
Begin
 h:=((Int64(a)*73856093)xor(Int64(b)*19349663))And $3FF;
 Hash:=h/1023;
End;

Function GenDbz(k:Integer;th,lon,lat:Real):Real;
Var
 i:Integer;
 cx,cy,dx,dy,u,w,v,m,r,ph,arm,env,cl:Real;
Begin
 m:=0;
 cl:=Cos(lat*Pi/180);
 For i:=0 to NBlob-1do If Blobs[i].sc=k Then Begin
  cx:=Blobs[i].x+Blobs[i].vx*th;
  cy:=Blobs[i].y+Blobs[i].vy*th;
  dx:=(lon-cx)*cl;dy:=lat-cy;
  Case Blobs[i].kd of
   1:Begin
    u:=dx*Cos(Blobs[i].an)+dy*Sin(Blobs[i].an);
    w:=-dx*Sin(Blobs[i].an)+dy*Cos(Blobs[i].an);
    v:=Blobs[i].pk*Exp(-1.2*(Sqr(w/Blobs[i].rad)+Sqr(Sqr(u/Blobs[i].len))));
    v:=v*(0.78+0.22*Sin(u*8));
   End;
   2:Begin
    r:=Sqrt(dx*dx+dy*dy);
    ph:=Atan2(dy,dx)-2.5*Ln(r/Blobs[i].rad+0.2)+th*0.6;
    arm:=0.5+0.5*Cos(2*ph);
    env:=Exp(-Sqr(r/(Blobs[i].rad*2.4)));
    v:=Blobs[i].pk*env*(0.4+0.6*arm);
    env:=Blobs[i].pk*Exp(-Sqr((r-0.4*Blobs[i].rad)/(0.14*Blobs[i].rad)));
    If env>v Then v:=env;
    If r<0.22*Blobs[i].rad Then v:=0;
   End;
   Else v:=Blobs[i].pk*Exp(-1.2*(dx*dx+dy*dy)/(Blobs[i].rad*Blobs[i].rad));
  End;
  If v>m Then m:=v;
 End;
 If m>0Then Begin
  w:=m/45;
  If w>1Then w:=1;
  m:=m+(Hash(Round(lon*40),Round(lat*40))-0.5)*12*w;
 End;
 If m<10Then m:=0;
 GenDbz:=m;
End;

Procedure BuildScenario(k:Integer);
Var
 f,r,c,i,j,b,lv:Integer;
 th,lo,la,dlon,dlat,cx,cy:Real;
 s:String;
Begin
 Seed:=12345+k;
 ResetData;
 SrcIdx:=Scn[k].src;
 Title:=Scn[k].tt;
 ProdName:=Src[SrcIdx].prod;
 StepMin:=Scn[k].step;
 BLon0:=Scn[k].lo0;BLat0:=Scn[k].la0;BLon1:=Scn[k].lo1;BLat1:=Scn[k].la1;
 GCols:=Scn[k].cols;GRows:=Scn[k].rows;
 BoxSet:=True;
 dlon:=(BLon1-BLon0)/GCols;
 dlat:=(BLat1-BLat0)/GRows;
 For f:=0 to Scn[k].nfr-1do Begin
  NewFrame;
  Frames[NF-1].tm:=Scn[k].t0+f*Scn[k].step;
  th:=f*Scn[k].step/60;
  For r:=0 to GRows-1do For c:=0 to GCols-1do Begin
   lo:=BLon0+(c+0.5)*dlon;
   la:=BLat1-(r+0.5)*dlat;
   lv:=Round(GenDbz(k,th,lo,la)/2);
   If lv>35Then lv:=35;
   Frames[NF-1].g^[r,c]:=lv;
  End;
 End;
 For i:=0 to NGAl-1do If(GAl[i].sc=k)and(NA<MaxAlerts)Then Begin
  b:=GAl[i].bi;
  th:=(GAl[i].h0+GAl[i].h1)/2;
  cx:=Blobs[b].x+Blobs[b].vx*th;
  cy:=Blobs[b].y+Blobs[b].vy*th;
  Al[NA].kind:=GAl[i].kd;
  Al[NA].ti:=GAl[i].ti;
  Al[NA].tx:=GAl[i].tx;
  Al[NA].t0:=Scn[k].t0+Round(GAl[i].h0*60);
  Al[NA].t1:=Scn[k].t0+Round(GAl[i].h1*60);
  Al[NA].n:=6;
  Al[NA].px[0]:=cx-GAl[i].w/2;Al[NA].py[0]:=cy;
  Al[NA].px[1]:=cx-GAl[i].w/4;Al[NA].py[1]:=cy+GAl[i].h/2;
  Al[NA].px[2]:=cx+GAl[i].w/4;Al[NA].py[2]:=cy+GAl[i].h/2;
  Al[NA].px[3]:=cx+GAl[i].w/2;Al[NA].py[3]:=cy;
  Al[NA].px[4]:=cx+GAl[i].w/4;Al[NA].py[4]:=cy-GAl[i].h/2;
  Al[NA].px[5]:=cx-GAl[i].w/4;Al[NA].py[5]:=cy-GAl[i].h/2;
  Inc(NA);
 End;
 For i:=0 to NbCity-1do Begin
  lo:=Cities[i].lo/100;la:=Cities[i].la/100;
  If(lo>BLon0)and(lo<BLon1)and(la>BLat0)and(la<BLat1)Then Begin
   If NL<6Then Begin
    Lx[NL].nm:=Cities[i].nm;Lx[NL].x:=lo;Lx[NL].y:=la;
    Inc(NL);
   End;
   If NS<8Then Begin
    s:=UpStr(Cities[i].nm);
    Sta[NS].id:=Copy(s,1,3)+Chr(65+NS);
    Sta[NS].x:=lo;Sta[NS].y:=la;
    Sta[NS].t:=27-(la-30)*0.7+(Hash(i,k)-0.5)*6;
    Sta[NS].dr:=Rnd(360);
    Sta[NS].v:=8+Rnd(25);
    Sta[NS].r:=Sta[NS].v+5+Rnd(20);
    Sta[NS].p:=1006+Rnd(14);
    Inc(NS);
   End;
  End;
 End;
 For f:=0 to NF-1do For b:=0 to NBlob-1do
  If(Blobs[b].sc=k)and(Blobs[b].pk>=52)Then Begin
   th:=f*Scn[k].step/60;
   cx:=Blobs[b].x+Blobs[b].vx*th;
   cy:=Blobs[b].y+Blobs[b].vy*th;
   If(cx>BLon0)and(cx<BLon1)and(cy>BLat0)and(cy<BLat1)Then
    For j:=1 to 4do If NK<MaxStrikes Then Begin
     Stk[NK].t:=Frames[f].tm-Rnd(IMax(1,Scn[k].step div 2));
     Stk[NK].x:=cx+(Rnd(100)-50)/50*Blobs[b].rad;
     Stk[NK].y:=cy+(Rnd(100)-50)/50*Blobs[b].rad;
     Inc(NK);
    End;
  End;
End;

Procedure WritePolarSVR(fn:String);
Var
 f:Text;
 i,ri,gi:Integer;
 az,rg,lo,la,th:Real;
 s:String;
Begin
 Assign(f,fn);
 Rewrite(f);
 WriteHead(f);
 WriteLn(f,'RADAR KTLX -97.278 35.333 230');
 WriteLn(f,'RADIAUX 120 115');
 WriteTail(f);
 For i:=0 to NF-1do Begin
  WriteLn(f,'TRAME ',TimeStr(Frames[i].tm));
  th:=i*StepMin/60;
  For ri:=0 to 119do Begin
   az:=ri*3*Pi/180;
   s:='';
   For gi:=0 to 114do Begin
    rg:=(gi+0.5)*2;
    lo:=-97.278+rg*Sin(az)/(111.19*Cos(35.333*Pi/180));
    la:=35.333+rg*Cos(az)/111.19;
    s:=s+LvChar(Round(GenDbz(2,th,lo,la)/2));
   End;
   WriteLn(f,s);
  End;
 End;
 Close(f);
End;

Procedure WriteASCSet(dir:String);
Var
 f:Text;
 i,r,c:Integer;
 lo,la,d,v:Real;
Begin
 Assign(f,dir+DirSep+'QC_ASC.LST');
 Rewrite(f);
 WriteLn(f,'; Liste de grilles ESRI ASCII (valeurs en mm/h)');
 WriteLn(f,'SOURCE GEOMET');
 WriteLn(f,'TITRE ',Title);
 WriteLn(f,'PAS 60');
 WriteLn(f,'HEURE 18:00');
 WriteLn(f,'MMH');
 For i:=0 to NF-1do Begin
  WriteLn(f,'QC_',i+1,'.ASC');
 End;
 Close(f);
 For i:=0 to NF-1do Begin
  Assign(f,dir+DirSep+'QC_'+IntStr(i+1)+'.ASC');
  Rewrite(f);
  WriteLn(f,'ncols ',GCols);
  WriteLn(f,'nrows ',GRows);
  WriteLn(f,'xllcorner ',RStr(BLon0,4));
  WriteLn(f,'yllcorner ',RStr(BLat0,4));
  WriteLn(f,'cellsize ',RStr((BLon1-BLon0)/GCols,4));
  WriteLn(f,'NODATA_value -9999');
  For r:=0 to GRows-1do Begin
   For c:=0 to GCols-1do Begin
    lo:=BLon0+(c+0.5)*(BLon1-BLon0)/GCols;
    la:=BLat1-(r+0.5)*(BLat1-BLat0)/GRows;
    d:=GenDbz(7,i,lo,la);
    If d<10Then v:=0 Else v:=Exp(Ln(Exp(d/10*Ln(10))/200)/1.6);
    Write(f,v:0:2);
    If c<GCols-1Then Write(f,' ');
   End;
   WriteLn(f);
  End;
  Close(f);
 End;
End;

Procedure GenerateAll(dir:String);
Var
 k:Integer;
Begin
 {$I-}
 MkDir(dir);
 {$I+}
 If IOResult<>0Then ;
 For k:=1 to 6do Begin
  BuildScenario(k);
  If k=2Then WritePolarSVR(dir+DirSep+Scn[k].fn)
   Else WriteSVR(dir+DirSep+Scn[k].fn);
  WriteLn('  ',dir+DirSep+Scn[k].fn,' (',NF,' images)');
 End;
 BuildScenario(7);
 WriteASCSet(dir);
 WriteLn('  ',dir+DirSep+Scn[7].fn,' + QC_1.ASC .. QC_',NF,'.ASC');
End;
{$ENDIF}

{ ---------------------------------------------------------------------------
  Ligne de commande
  --------------------------------------------------------------------------- }

Procedure ShowUsage;Begin
 WriteLn('STORMVIEW 1.0 - Cette commande permet de lancer le ',
         'StormView Radar (radar anime, alertes, foudre).');
 WriteLn;
 WriteLn('Syntaxe : STORMVIEW [fichier ...] [options]');
 WriteLn;
 WriteLn('  fichier           .SVR (sequence), .ASC (grille ESRI, une image par fichier)');
 WriteLn('                    ou .LST (liste de fichiers). Plusieurs fichiers = animation.');
 WriteLn;
 WriteLn('Options :');
 WriteLn('  /? ou /AIDE       Affiche cette aide');
 WriteLn('  /SOURCE:nom       MRMS, NEXRAD, NOWCOAST, HRRR, RAINVIEWER ou GEOMET');
 WriteLn('  /TITRE:texte      Titre de la sequence');
 WriteLn('  /PAS:minutes      Pas de temps entre les images (fichiers .ASC)');
 WriteLn('  /HEURE:hh:mm      Heure de la premiere image (fichiers .ASC)');
 WriteLn('  /MMH              Les valeurs des fichiers .ASC sont en mm/h (converties en dBZ)');
 WriteLn('  /LIEU:lon,lat     Centre la carte sur cette position (ex. /LIEU:-73.57,45.50)');
 WriteLn('  /ZOOM:n           Facteur de zoom initial (ex. /ZOOM:2)');
 WriteLn('  /VITESSE:ms       Delai entre les images, de 100 a 3000 (defaut 700)');
 WriteLn('  /SEUIL:dbz        Seuil d''affichage radar : 10, 20, 30 ou 40 dBZ');
 WriteLn('  /SANSANIM         Ne lance pas l''animation au demarrage');
 WriteLn('  /SANSBOUCLE       Arrete l''animation a la derniere image');
 WriteLn('  /SOURCES          Liste les sources prises en charge');
 WriteLn('  /LISTE            Liste les echantillons du dossier TEST');
 WriteLn('  /URL              Affiche l''adresse de telechargement de la source');
 WriteLn('  /EXPORT:fichier   Convertit la sequence en .SVR (sans ecran graphique)');
 {$IFDEF FPC}
 WriteLn('  /GENERER[:dossier] Recree les echantillons (defaut : TEST)');
 {$ENDIF}
 WriteLn;
 WriteLn('Sans fichier : ouvre TEST',DirSep,'OKLAHOMA.SVR.');
 WriteLn('Les options peuvent commencer par / ou par -.');
End;

Procedure ShowSources;
Var
 i:Integer;
Begin
 WriteLn('Sources prises en charge (profils) :');
 For i:=0 to NbSrc-1do Begin
  WriteLn;
  WriteLn('  ',Src[i].nm,' - ',Src[i].nom);
  WriteLn('    Produit    : ',Src[i].prod,' (',Src[i].res,', pas ',Src[i].pas,' min)');
  WriteLn('    Conversion : ',Src[i].fmt);
  WriteLn('    Adresse    : ',Src[i].url);
 End;
End;

Procedure ShowSamples;
Var
 i:Integer;
Begin
 ListSamples;
 If DN=0Then WriteLn('Aucun echantillon dans le dossier TEST',DirSep)
  Else Begin
  WriteLn('Echantillons du dossier TEST',DirSep,' :');
  For i:=0 to DN-1do WriteLn('  ',DL[i]);
 End;
End;

Function IsOption(s:String):Boolean;
Var
 j,c:Integer;
Begin
 IsOption:=False;
 If s=''Then Exit;
 If s[1]='-'Then IsOption:=True
  Else If s[1]='/'Then Begin
   j:=Pos('/',Copy(s,2,255));
   c:=Pos(':',Copy(s,2,255));
   IsOption:=(j=0)or((c>0)and(c<j));
  End;
End;

Procedure InitGlobals;Begin
 NF:=0;Cur:=0;NA:=0;NS:=0;NK:=0;NL:=0;
 FillChar(Frames,SizeOf(Frames),0);
 LRadar:=True;LFoudre:=True;LAlert:=True;LStation:=True;LVille:=True;
 LGrille:=False;LCoast:=True;LCell:=False;
 MinLv:=5;Tool:=0;
 Playing:=True;Looping:=True;AnimMs:=700;
 SrcIdx:=0;StepMin:=0;StartMin:=720;AscMmh:=False;
 MenuOpen:=-1;MenuSel:=-1;MouseHid:=0;
 StatMsg:='Bienvenue dans StormView Radar. F1 = aide, F10 = menus.';
 HovTxt:='';LastErr:='';CurFile:='';
 TlDrag:=False;DragOn:=False;
 GetMem(Vis,SizeOf(TBytes));
 GetMem(Que,SizeOf(TWords));
 ResetData;
 LoadBasemap;
 BuildMenus;
End;

Var
 Files:Array[0..9] of String[80];
 NFiles,i,k:Integer;
 p,o,v,optExport,optTitle:String;
 optSrc,optAnim,optLoop,doUrl:Boolean;
 optSrcIdx:Integer;
 optZoom:Real;
 optLon,optLat:Real;
 hasLieu:Boolean;
 optStep,optMs,optSeuil:Integer;
 optHeure:Integer;
BEGIN
 NFiles:=0;optExport:='';optTitle:='';optSrc:=False;optAnim:=True;optLoop:=True;
 doUrl:=False;optZoom:=1;hasLieu:=False;optStep:=0;optMs:=0;optSeuil:=0;optHeure:=-1;
 InitGlobals;
 For i:=1 to ParamCount do Begin
  p:=ParamStr(i);
  If IsOption(p)Then Begin
   Delete(p,1,1);
   k:=Pos(':',p);
   If k>0Then Begin
    o:=UpStr(Copy(p,1,k-1));
    v:=Copy(p,k+1,255);
   End
    Else Begin
    o:=UpStr(p);
    v:='';
   End;
   If(o='?')or(o='AIDE')or(o='H')or(o='HELP')Then Begin
    ShowUsage;
    Halt(0);
   End
   Else If o='SOURCES'Then Begin
    ShowSources;
    Halt(0);
   End
   Else If o='LISTE'Then Begin
    ShowSamples;
    Halt(0);
   End
   Else If o='URL'Then doUrl:=True
   Else If o='SOURCE'Then Begin
    k:=FindSrc(v);
    If k<0Then Begin
     WriteLn('Source inconnue : ',v,' (voir /SOURCES)');
     Halt(1);
    End;
    SrcIdx:=k;optSrcIdx:=k;optSrc:=True;
   End
   Else If o='TITRE'Then optTitle:=v
   Else If o='PAS'Then Begin
    If Not ValI(v,optStep)or(optStep<1)Then Begin
     WriteLn('Valeur invalide pour /PAS : ',v);
     Halt(1);
    End;
    StepMin:=optStep;
   End
   Else If o='HEURE'Then Begin
    optHeure:=ParseTime(v);
    If optHeure<0Then Begin
     WriteLn('Heure invalide pour /HEURE : ',v,' (format hh:mm)');
     Halt(1);
    End;
    StartMin:=optHeure;
   End
   Else If o='MMH'Then AscMmh:=True
   Else If o='LIEU'Then Begin
    k:=Pos(',',v);
    If(k=0)or Not ValR(Copy(v,1,k-1),optLon)or Not ValR(Copy(v,k+1,40),optLat)Then Begin
     WriteLn('Position invalide pour /LIEU : ',v,' (format lon,lat)');
     Halt(1);
    End;
    hasLieu:=True;
   End
   Else If o='ZOOM'Then Begin
    If Not ValR(v,optZoom)or(optZoom<=0)Then Begin
     WriteLn('Valeur invalide pour /ZOOM : ',v);
     Halt(1);
    End;
   End
   Else If o='VITESSE'Then Begin
    If Not ValI(v,optMs)Then Begin
     WriteLn('Valeur invalide pour /VITESSE : ',v);
     Halt(1);
    End;
    AnimMs:=IMax(100,IMin(3000,optMs));
   End
   Else If o='SEUIL'Then Begin
    If Not ValI(v,optSeuil)Then Begin
     WriteLn('Valeur invalide pour /SEUIL : ',v);
     Halt(1);
    End;
    MinLv:=IMax(5,IMin(20,optSeuil div 2));
   End
   Else If o='SANSANIM'Then optAnim:=False
   Else If o='SANSBOUCLE'Then optLoop:=False
   Else If o='EXPORT'Then optExport:=v
   {$IFDEF FPC}
   Else If o='GENERER'Then Begin
    If v=''Then v:='TEST';
    WriteLn('Generation des echantillons dans ',v,' :');
    GenerateAll(v);
    Halt(0);
   End
   {$ENDIF}
   Else Begin
    WriteLn('Option inconnue : ',ParamStr(i));
    WriteLn('Tapez STORMVIEW /? pour obtenir l''aide.');
    Halt(1);
   End;
  End
   Else If NFiles<=9Then Begin
   Files[NFiles]:=p;
   Inc(NFiles);
  End;
 End;
 If doUrl Then Begin
  WriteLn(Src[SrcIdx].nom,' : ',Src[SrcIdx].url);
  Halt(0);
 End;
 ResetData;
 If optTitle<>''Then Title:=Copy(optTitle,1,60);
 If NFiles=0Then Begin
  Files[0]:='TEST'+DirSep+'OKLAHOMA.SVR';
  NFiles:=1;
  If Not FileOk(Files[0])Then Begin
   {$IFDEF FPC}
   BuildScenario(1);
   NFiles:=0;
   {$ELSE}
   WriteLn('Fichier TEST',DirSep,'OKLAHOMA.SVR introuvable. Tapez STORMVIEW /? pour l''aide.');
   Halt(1);
   {$ENDIF}
  End;
 End;
 For i:=0 to NFiles-1do Begin
  LastErr:='';
  If Not FileOk(Files[i])Then Begin
   WriteLn('Fichier introuvable : ',Files[i]);
   Halt(1);
  End;
  If Not LoadAny(Files[i])Then Begin
   WriteLn(LastErr);
   Halt(1);
  End;
  CurFile:=Copy(Files[i],1,64);
 End;
 If NF=0Then Begin
  WriteLn('Aucune image dans les fichiers donnes.');
  Halt(1);
 End;
 If optSrc Then SrcIdx:=optSrcIdx;
 FinishLoad;
 If optTitle<>''Then Title:=Copy(optTitle,1,60);
 If optExport<>''Then Begin
  If WriteSVR(optExport)Then WriteLn('Sequence exportee : ',optExport,' (',NF,' images)')
   Else Begin
   WriteLn(LastErr);
   Halt(1);
  End;
  Halt(0);
 End;
 If hasLieu Then Begin
  VLon:=optLon;VLat:=optLat;CosV:=Cos(VLat*Pi/180);
 End;
 VScale:=VScale*optZoom;
 Playing:=optAnim and(NF>1);
 Looping:=optLoop;
 If Not MouseDriverFound Then Begin
  WriteLn('Pilote de souris introuvable.');
  Halt(1);
 End;
 InitializeGraphics;
 Run;
 CloseGraph;
END.
