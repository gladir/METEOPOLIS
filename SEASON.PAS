{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2022
  @website(https://www.gladir.com/meteopolis)
  @abstract(Target: Turbo Pascal, Free Pascal)
}

Program SEASON;

Uses DOS;

Type
 CityGeoRecord=Record
  City:String[20];
  Latitude,LatiDeg:Byte;
  LatiDirection:Char;
  Longitude,LongDeg:Byte;
  LongDirection:Char;
 End;

 CountryGeoRecord=Record
  Country:String[40];
  Latitude,LatiDeg:Byte;
  LatiDirection:Char;
  Longitude,LongDeg:Byte;
  LongDirection:Char;
 End;

Const
 Country:Array[0..248]of CountryGeoRecord=(
  (Country:'Afghanistan';   Latitude:33; LatiDeg: 55; LatiDirection: 'N'; Longitude: 67; LongDeg: 40;LongDirection: 'E'),
  (Country:'Afrique du sud';Latitude:28; LatiDeg: 28; LatiDirection: 'S'; Longitude: 24; LongDeg: 40;LongDirection: 'E'),
  (Country:'Albanie';       Latitude:41; LatiDeg: 9;  LatiDirection: 'N'; Longitude: 20; LongDeg: 10;LongDirection: 'E'),
  (Country:'Algerie';       Latitude:28; LatiDeg: 1;  LatiDirection: 'N'; Longitude: 1;  LongDeg: 39;LongDirection: 'E'),
  (Country:'Allemagne';     Latitude:51; LatiDeg: 9;  LatiDirection: 'N'; Longitude: 10; LongDeg: 27;LongDirection: 'E'),
  (Country:'Andorre';       Latitude:42; LatiDeg: 32; LatiDirection: 'N'; Longitude: 1;  LongDeg: 35;LongDirection: 'E'),
  (Country:'Angola';        Latitude:11; LatiDeg: 12; LatiDirection: 'S'; Longitude: 17; LongDeg: 52;LongDirection: 'E'),
  (Country:'Anguilla';      Latitude:18; LatiDeg: 13; LatiDirection: 'N'; Longitude: 63; LongDeg: 4; LongDirection: 'O'),
  (Country:'Antarctique';   Latitude:75; LatiDeg: 15; LatiDirection: 'S'; Longitude: 0;  LongDeg: 0; LongDirection: 'E'),
  (Country:'Antigua et Barbuda';Latitude:17;LatiDeg:21;LatiDirection:'N'; Longitude: 61; LongDeg: 47;LongDirection: 'O'),
  (Country:'Arabie saoudite';Latitude:23;LatiDeg: 53; LatiDirection: 'N'; Longitude: 45; LongDeg: 4; LongDirection: 'E'),
  (Country:'Argentine';     Latitude:38; LatiDeg: 25; LatiDirection: 'S'; Longitude: 63; LongDeg: 35;LongDirection: 'O'),
  (Country:'Armenie';       Latitude:40; LatiDeg: 3;  LatiDirection: 'N'; Longitude: 45; LongDeg: 6; LongDirection: 'E'),
  (Country:'Aruba';         Latitude:12; LatiDeg: 31; LatiDirection: 'N'; Longitude: 69; LongDeg: 57;LongDirection: 'O'),
  (Country:'Australie';     Latitude:26; LatiDeg: 51; LatiDirection: 'S'; Longitude: 133;LongDeg: 16;LongDirection: 'E'),
  (Country:'Autriche';      Latitude:47; LatiDeg: 41; LatiDirection: 'N'; Longitude: 13; LongDeg: 20;LongDirection: 'E'),
  (Country:'Azerbaidjan';   Latitude:40; LatiDeg: 8;  LatiDirection: 'N'; Longitude: 47; LongDeg: 34;LongDirection: 'E'),
  (Country:'Bahamas';       Latitude:24; LatiDeg: 53; LatiDirection: 'N'; Longitude: 76; LongDeg: 42;LongDirection: 'O'),
  (Country:'Bahrein';       Latitude:26; LatiDeg: 2;  LatiDirection: 'N'; Longitude: 50; LongDeg: 33;LongDirection: 'E'),
  (Country:'Bangladesh';    Latitude:23; LatiDeg: 41; LatiDirection: 'N'; Longitude: 90; LongDeg: 21;LongDirection: 'E'),
  (Country:'Barbade';       Latitude:13; LatiDeg: 11; LatiDirection: 'N'; Longitude: 59; LongDeg: 32;LongDirection: 'O'),
  (Country:'Belgique';      Latitude:50; LatiDeg: 29; LatiDirection: 'N'; Longitude: 4;  LongDeg: 28;LongDirection: 'E'),
  (Country:'Belize';        Latitude:17; LatiDeg: 11; LatiDirection: 'N'; Longitude: 88; LongDeg: 30;LongDirection: 'O'),
  (Country:'Benin';         Latitude:9;  LatiDeg: 19; LatiDirection: 'N'; Longitude: 2;  LongDeg: 18;LongDirection: 'E'),
  (Country:'Bermudes';      Latitude:32; LatiDeg: 19; LatiDirection: 'N'; Longitude: 64; LongDeg: 46;LongDirection: 'O'),
  (Country:'Bhutan';        Latitude:27; LatiDeg: 30; LatiDirection: 'N'; Longitude: 90; LongDeg: 26;LongDirection: 'E'),
  (Country:'Bielorussie';   Latitude:53; LatiDeg: 42; LatiDirection: 'N'; Longitude: 27; LongDeg: 58;LongDirection: 'E'),
  (Country:'Bolivie';       Latitude:16; LatiDeg: 17; LatiDirection: 'S'; Longitude: 63; LongDeg: 32;LongDirection: 'O'),
  (Country:'Bonaire';       Latitude:12; LatiDeg: 9;  LatiDirection: 'N'; Longitude: 68; LongDeg: 18;LongDirection: 'O'),
  (Country:'Bosnie-Herzegovine';Latitude:43;LatiDeg:53;LatiDirection:'N'; Longitude: 17; LongDeg: 40;LongDirection: 'E'),
  (Country:'Botswana';      Latitude:22; LatiDeg: 20; LatiDirection: 'S'; Longitude: 24; LongDeg: 40;LongDirection: 'E'),
  (Country:'Bresil';        Latitude:14; LatiDeg: 14; LatiDirection: 'S'; Longitude: 53; LongDeg: 11;LongDirection: 'O'),
  (Country:'Brunei Darussalam';Latitude:4;LatiDeg:31; LatiDirection: 'N'; Longitude: 114;LongDeg: 42;LongDirection: 'E'),
  (Country:'Bulgarie';      Latitude:42; LatiDeg: 43; LatiDirection: 'N'; Longitude: 25; LongDeg: 29;LongDirection: 'E'),
  (Country:'Burkina Faso';  Latitude:12; LatiDeg: 14; LatiDirection: 'N'; Longitude: 1;  LongDeg: 33;LongDirection: 'O'),
  (Country:'Burundi';       Latitude:3;  LatiDeg: 23; LatiDirection: 'S'; Longitude: 29; LongDeg: 55;LongDirection: 'E'),
  (Country:'Cambodge';      Latitude:12; LatiDeg: 32; LatiDirection: 'N'; Longitude: 104;LongDeg: 59;LongDirection: 'E'),
  (Country:'Cameroun';      Latitude:7;  LatiDeg: 21; LatiDirection: 'N'; Longitude: 12; LongDeg: 20;LongDirection: 'E'),
  (Country:'Canada';        Latitude:62; LatiDeg: 23; LatiDirection: 'N'; Longitude: 96; LongDeg: 49;LongDirection: 'O'),
  (Country:'Cap-Vert';      Latitude:16; LatiDeg: 0;  LatiDirection: 'N'; Longitude: 24; LongDeg: 0; LongDirection: 'O'),
  (Country:'Centrafrique';  Latitude:6;  LatiDeg: 36; LatiDirection: 'N'; Longitude: 20; LongDeg: 56;LongDirection: 'E'),
  (Country:'Chili';         Latitude:36; LatiDeg: 42; LatiDirection: 'S'; Longitude: 73; LongDeg: 36;LongDirection: 'O'),
  (Country:'Chine';         Latitude:34; LatiDeg: 40; LatiDirection: 'N'; Longitude: 104;LongDeg: 9; LongDirection: 'E'),
  (Country:'Chypre';        Latitude:35; LatiDeg: 10; LatiDirection: 'N'; Longitude: 33; LongDeg: 26;LongDirection: 'E'),
  (Country:'Colombie';      Latitude:4;  LatiDeg: 34; LatiDirection: 'N'; Longitude: 74; LongDeg: 17;LongDirection: 'O'),
  (Country:'Comores';       Latitude:11; LatiDeg: 52; LatiDirection: 'S'; Longitude: 43; LongDeg: 52;LongDirection: 'E'),
  (Country:'Congo-Brazzaville';Latitude:0;LatiDeg:39; LatiDirection: 'S'; Longitude: 14; LongDeg: 55;LongDirection: 'E'),
  (Country:'Coree du Nord'; Latitude:40; LatiDeg: 20; LatiDirection: 'N'; Longitude: 127;LongDeg: 29;LongDirection: 'E'),
  (Country:'Coree du Sud';  Latitude:35; LatiDeg: 54; LatiDirection: 'N'; Longitude: 127;LongDeg: 44;LongDirection: 'E'),
  (Country:'Costa Rica';    Latitude:9;  LatiDeg: 37; LatiDirection: 'N'; Longitude: 84; LongDeg: 15;LongDirection: 'O'),
  (Country:'Cote d''Ivoire';Latitude:7;  LatiDeg: 32; LatiDirection: 'N'; Longitude: 5;  LongDeg: 32;LongDirection: 'O'),
  (Country:'Croatie';       Latitude:44; LatiDeg: 29; LatiDirection: 'N'; Longitude: 16; LongDeg: 27;LongDirection: 'E'),
  (Country:'Cuba';          Latitude:21; LatiDeg: 31; LatiDirection: 'N'; Longitude: 79; LongDeg: 32;LongDirection: 'O'),
  (Country:'Curacao';       Latitude:12; LatiDeg: 12; LatiDirection: 'N'; Longitude: 68; LongDeg: 56;LongDirection: 'O'),
  (Country:'Danemark';      Latitude:56; LatiDeg: 9;  LatiDirection: 'N'; Longitude: 11; LongDeg: 37;LongDirection: 'E'),
  (Country:'Djibouti';      Latitude:11; LatiDeg: 48; LatiDirection: 'N'; Longitude: 42; LongDeg: 35;LongDirection: 'E'),
  (Country:'Dominique';     Latitude:15; LatiDeg: 25; LatiDirection: 'N'; Longitude: 61; LongDeg: 21;LongDirection: 'O'),
  (Country:'Egypte';        Latitude:26; LatiDeg: 41; LatiDirection: 'N'; Longitude: 30; LongDeg: 14;LongDirection: 'E'),
  (Country:'Emirats arabes unis';Latitude:24;LatiDeg:21;LatiDirection:'N';Longitude: 53; LongDeg: 58;LongDirection: 'E'),
  (Country:'Equateur';      Latitude:1;  LatiDeg: 46; LatiDirection: 'S'; Longitude: 78; LongDeg: 7; LongDirection: 'O'),
  (Country:'Erythree';      Latitude:15; LatiDeg: 10; LatiDirection: 'N'; Longitude: 39; LongDeg: 47;LongDirection: 'E'),
  (Country:'Espagne';       Latitude:39; LatiDeg: 53; LatiDirection: 'N'; Longitude:  2; LongDeg: 29;LongDirection: 'O'),
  (Country:'Estonie';       Latitude:58; LatiDeg: 35; LatiDirection: 'N'; Longitude: 25; LongDeg: 1; LongDirection: 'E'),
  (Country:'Etats-Unis';    Latitude:36; LatiDeg: 57; LatiDirection: 'N'; Longitude: 95; LongDeg: 50;LongDirection: 'O'),
  (Country:'Ethiopie';      Latitude:9;  LatiDeg: 8;  LatiDirection: 'N'; Longitude: 40; LongDeg: 29;LongDirection: 'E'),
  (Country:'Fidji';         Latitude:16; LatiDeg: 34; LatiDirection: 'S'; Longitude: 179;LongDeg: 21;LongDirection: 'E'),
  (Country:'Finlande';      Latitude:64; LatiDeg: 57; LatiDirection: 'N'; Longitude: 26; LongDeg: 4; LongDirection: 'E'),
  (Country:'France';        Latitude:46; LatiDeg: 13; LatiDirection: 'N'; Longitude: 2;  LongDeg: 12;LongDirection: 'E'),
  (Country:'Gabon';         Latitude:0;  LatiDeg: 49; LatiDirection: 'S'; Longitude: 11; LongDeg: 35;LongDirection: 'E'),
  (Country:'Gambie';        Latitude:13; LatiDeg: 26; LatiDirection: 'N'; Longitude: 15; LongDeg: 18;LongDirection: 'O'),
  (Country:'Georgie';       Latitude:42; LatiDeg: 19; LatiDirection: 'N'; Longitude: 43; LongDeg: 22;LongDirection: 'E'),
  (Country:'Georgie du Sud';Latitude:56; LatiDeg: 43; LatiDirection: 'S'; Longitude: 32; LongDeg: 7; LongDirection: 'O'),
  (Country:'Ghana';         Latitude:7;  LatiDeg: 57; LatiDirection: 'N'; Longitude:  1; LongDeg: 1; LongDirection: 'O'),
  (Country:'Gibraltar';     Latitude:36; LatiDeg: 7;  LatiDirection: 'N'; Longitude:  5; LongDeg: 21;LongDirection: 'O'),
  (Country:'Grece';         Latitude:38; LatiDeg: 16; LatiDirection: 'N'; Longitude: 23; LongDeg: 48;LongDirection: 'E'),
  (Country:'Grenade';       Latitude:12; LatiDeg: 9;  LatiDirection: 'N'; Longitude: 61; LongDeg: 41;LongDirection: 'O'),
  (Country:'Groenland';     Latitude:71; LatiDeg: 42; LatiDirection: 'N'; Longitude: 42; LongDeg: 10;LongDirection: 'O'),
  (Country:'Guadeloupe';    Latitude:16; LatiDeg: 11; LatiDirection: 'N'; Longitude: 61; LongDeg: 16;LongDirection: 'O'),
  (Country:'Guam';          Latitude:13; LatiDeg: 26; LatiDirection: 'N'; Longitude: 144;LongDeg: 47;LongDirection: 'E'),
  (Country:'Guatemala';     Latitude:15; LatiDeg: 46; LatiDirection: 'N'; Longitude: 90; LongDeg: 13;LongDirection: 'O'),
  (Country:'Guernesey';     Latitude:49; LatiDeg: 34; LatiDirection: 'N'; Longitude: 2;  LongDeg: 25;LongDirection: 'O'),
  (Country:'Guinee';        Latitude:9;  LatiDeg: 56; LatiDirection: 'N'; Longitude: 11; LongDeg: 17;LongDirection: 'O'),
  (Country:'Guinee equatoriale';Latitude:1;LatiDeg:38;LatiDirection: 'N'; Longitude: 10; LongDeg: 20;LongDirection: 'E'),
  (Country:'Guinee-Bissau'; Latitude:11; LatiDeg: 48; LatiDirection: 'N'; Longitude: 15; LongDeg: 10;LongDirection: 'O'),
  (Country:'Guyana';        Latitude:4;  LatiDeg: 51; LatiDirection: 'N'; Longitude: 58; LongDeg: 55;LongDirection: 'O'),
  (Country:'Guyane';        Latitude:3;  LatiDeg: 57; LatiDirection: 'N'; Longitude: 53; LongDeg: 4; LongDirection: 'O'),
  (Country:'Haiti';         Latitude:19; LatiDeg: 3;  LatiDirection: 'N'; Longitude: 73; LongDeg: 2; LongDirection: 'O'),
  (Country:'Honduras';      Latitude:14; LatiDeg: 44; LatiDirection: 'N'; Longitude: 86; LongDeg: 15;LongDirection: 'O'),
  (Country:'Hong Kong';     Latitude:22; LatiDeg: 21; LatiDirection: 'N'; Longitude: 114;LongDeg: 8; LongDirection: 'E'),
  (Country:'Hongrie';       Latitude:47; LatiDeg: 9;  LatiDirection: 'N'; Longitude: 19; LongDeg: 30;LongDirection: 'E'),
  (Country:'Ile Bouvet';    Latitude:54; LatiDeg: 25; LatiDirection: 'S'; Longitude: 3;  LongDeg: 24;LongDirection: 'E'),
  (Country:'Ile Christmas'; Latitude:10; LatiDeg: 29; LatiDirection: 'S'; Longitude: 105;LongDeg: 37;LongDirection: 'E'),
  (Country:'Ile de Man';    Latitude:54; LatiDeg: 14; LatiDirection: 'N'; Longitude: 4;  LongDeg: 33;LongDirection: 'O'),
  (Country:'Ile Heard';     Latitude:53; LatiDeg: 3;  LatiDirection: 'S'; Longitude: 73; LongDeg: 13;LongDirection: 'E'),
  (Country:'Ile Norfolk';   Latitude:29; LatiDeg: 1;  LatiDirection: 'S'; Longitude: 167;LongDeg: 57;LongDirection: 'E'),
  (Country:'Iles Aland';    Latitude:60; LatiDeg: 11; LatiDirection: 'N'; Longitude: 20; LongDeg: 9; LongDirection: 'E'),
  (Country:'Iles Caimans';  Latitude:19; LatiDeg: 30; LatiDirection: 'N'; Longitude: 80; LongDeg: 34;LongDirection: 'O'),
  (Country:'Iles Cocos';    Latitude:12; LatiDeg: 8;  LatiDirection: 'S'; Longitude: 96; LongDeg: 52;LongDirection: 'E'),
  (Country:'Iles Cook';     Latitude:15; LatiDeg: 59; LatiDirection: 'S'; Longitude: 159;LongDeg: 12;LongDirection: 'O'),
  (Country:'Iles Feroe';    Latitude:61; LatiDeg: 53; LatiDirection: 'N'; Longitude: 6;  LongDeg: 55;LongDirection: 'O'),
  (Country:'Iles Malouines';Latitude:51; LatiDeg: 48; LatiDirection: 'S'; Longitude: 59; LongDeg: 31;LongDirection: 'O'),
  (Country:'Iles Mariannes du Nord';Latitude:17;LatiDeg:0;LatiDirection:'N';Longitude:145;LongDeg:0; LongDirection: 'E'),
  (Country:'Iles Marshall'; Latitude:10; LatiDeg: 6;  LatiDirection: 'N'; Longitude: 168;LongDeg: 43;LongDirection: 'E'),
  (Country:'Iles mineures'; Latitude:13; LatiDeg: 54; LatiDirection: 'N'; Longitude: 5;  LongDeg: 22;LongDirection: 'O'),
  (Country:'Iles Salomon';  Latitude:9;  LatiDeg: 13; LatiDirection: 'S'; Longitude: 161;LongDeg: 14;LongDirection: 'E'),
  (Country:'Iles Turques-et-Caiques';Latitude:21;LatiDeg:0;LatiDirection:'N';Longitude:71;LongDeg:0; LongDirection: 'O'),
  (Country:'Iles Vierges';  Latitude:18; LatiDeg: 0;  LatiDirection: 'N'; Longitude: 64; LongDeg: 0; LongDirection: 'O'),
  (Country:'Iles Vierges des Etats-Unis';
                            Latitude:18; LatiDeg: 2;  LatiDirection: 'N'; Longitude: 64; LongDeg: 48;LongDirection: 'O'),
  (Country:'Inde';          Latitude:21; LatiDeg: 7;  LatiDirection: 'N'; Longitude: 82; LongDeg: 47;LongDirection: 'E'),
  (Country:'Indonesie';     Latitude:2;  LatiDeg: 31; LatiDirection: 'S'; Longitude: 118;LongDeg: 0; LongDirection: 'E'),
  (Country:'Irak';          Latitude:33; LatiDeg: 13; LatiDirection: 'N'; Longitude: 43; LongDeg: 41;LongDirection: 'E'),
  (Country:'Iran';          Latitude:32; LatiDeg: 25; LatiDirection: 'N'; Longitude: 53; LongDeg: 40;LongDirection: 'E'),
  (Country:'Irlande';       Latitude:53; LatiDeg: 25; LatiDirection: 'N'; Longitude: 8;  LongDeg: 14;LongDirection: 'O'),
  (Country:'Islande';       Latitude:64; LatiDeg: 57; LatiDirection: 'N'; Longitude: 19; LongDeg: 1; LongDirection: 'O'),
  (Country:'Israel';        Latitude:31; LatiDeg: 25; LatiDirection: 'N'; Longitude: 35; LongDeg: 4; LongDirection: 'E'),
  (Country:'Italie';        Latitude:41; LatiDeg: 52; LatiDirection: 'N'; Longitude: 12; LongDeg: 33;LongDirection: 'E'),
  (Country:'Jamaique';      Latitude:18; LatiDeg: 6;  LatiDirection: 'N'; Longitude: 77; LongDeg: 16;LongDirection: 'O'),
  (Country:'Japon';         Latitude:34; LatiDeg: 53; LatiDirection: 'N'; Longitude: 134;LongDeg: 22;LongDirection: 'E'),
  (Country:'Jersey';        Latitude:49; LatiDeg: 13; LatiDirection: 'N'; Longitude: 2;  LongDeg: 8; LongDirection: 'O'),
  (Country:'Jordanie';      Latitude:31; LatiDeg: 16; LatiDirection: 'N'; Longitude: 37; LongDeg: 7; LongDirection: 'E'),
  (Country:'Kazakhstan';    Latitude:48; LatiDeg: 11; LatiDirection: 'N'; Longitude: 66; LongDeg: 54;LongDirection: 'E'),
  (Country:'Kenya';         Latitude:0;  LatiDeg: 10; LatiDirection: 'N'; Longitude: 37; LongDeg: 54;LongDirection: 'E'),
  (Country:'Kirghizistan';  Latitude:41; LatiDeg: 12; LatiDirection: 'N'; Longitude: 74; LongDeg: 46;LongDirection: 'E'),
  (Country:'Kiribati';      Latitude:3;  LatiDeg: 21; LatiDirection: 'S'; Longitude: 170;LongDeg: 19;LongDirection: 'O'),
  (Country:'Kosovo';        Latitude:42; LatiDeg: 33; LatiDirection: 'N'; Longitude: 20; LongDeg: 53;LongDirection: 'E'),
  (Country:'Koweit';        Latitude:29; LatiDeg: 18; LatiDirection: 'N'; Longitude: 47; LongDeg: 29;LongDirection: 'E'),
  (Country:'Laos';          Latitude:18; LatiDeg: 12; LatiDirection: 'N'; Longitude: 103;LongDeg: 53;LongDirection: 'E'),
  (Country:'Lesotho';       Latitude:29; LatiDeg: 37; LatiDirection: 'S'; Longitude: 28; LongDeg: 14;LongDirection: 'E'),
  (Country:'Lettonie';      Latitude:56; LatiDeg: 52; LatiDirection: 'N'; Longitude: 24; LongDeg: 36;LongDirection: 'E'),
  (Country:'Liban';         Latitude:33; LatiDeg: 52; LatiDirection: 'N'; Longitude: 35; LongDeg: 52;LongDirection: 'E'),
  (Country:'Liberia';       Latitude:6;  LatiDeg: 27; LatiDirection: 'N'; Longitude: 9;  LongDeg: 25;LongDirection: 'O'),
  (Country:'Libye';         Latitude:26; LatiDeg: 20; LatiDirection: 'N'; Longitude: 17; LongDeg: 16;LongDirection: 'E'),
  (Country:'Liechtenstein'; Latitude:47; LatiDeg: 9;  LatiDirection: 'N'; Longitude: 9;  LongDeg: 33;LongDirection: 'E'),
  (Country:'Lituanie';      Latitude:55; LatiDeg: 10; LatiDirection: 'N'; Longitude: 23; LongDeg: 54;LongDirection: 'E'),
  (Country:'Luxembourg';    Latitude:49; LatiDeg: 48; LatiDirection: 'N'; Longitude: 6;  LongDeg: 7; LongDirection: 'E'),
  (Country:'Macao';         Latitude:22; LatiDeg: 12; LatiDirection: 'N'; Longitude: 113;LongDeg: 32;LongDirection: 'E'),
  (Country:'Macedoine';     Latitude:41; LatiDeg: 36; LatiDirection: 'N'; Longitude: 21; LongDeg: 45;LongDirection: 'E'),
  (Country:'Madagascar';    Latitude:18; LatiDeg: 46; LatiDirection: 'S'; Longitude: 46; LongDeg: 51;LongDirection: 'E'),
  (Country:'Malaisie';      Latitude:4;  LatiDeg: 6;  LatiDirection: 'N'; Longitude: 109;LongDeg: 27;LongDirection: 'E'),
  (Country:'Malawi';        Latitude:13; LatiDeg: 14; LatiDirection: 'S'; Longitude: 34; LongDeg: 17;LongDirection: 'E'),
  (Country:'Maldives';      Latitude:3;  LatiDeg: 12; LatiDirection: 'N'; Longitude: 73; LongDeg: 9; LongDirection: 'E'),
  (Country:'Mali';          Latitude:17; LatiDeg: 34; LatiDirection: 'N'; Longitude: 3;  LongDeg: 59;LongDirection: 'O'),
  (Country:'Malte';         Latitude:35; LatiDeg: 56; LatiDirection: 'N'; Longitude: 14; LongDeg: 22;LongDirection: 'E'),
  (Country:'Maroc';         Latitude:31; LatiDeg: 47; LatiDirection: 'N'; Longitude: 7;  LongDeg: 4; LongDirection: 'O'),
  (Country:'Martinique';    Latitude:14; LatiDeg: 38; LatiDirection: 'N'; Longitude: 61; LongDeg: 1; LongDirection: 'O'),
  (Country:'Maurice';       Latitude:15; LatiDeg: 25; LatiDirection: 'S'; Longitude: 60; LongDeg: 0; LongDirection: 'E'),
  (Country:'Mauritanie';    Latitude:21; LatiDeg: 0;  LatiDirection: 'N'; Longitude: 10; LongDeg: 56;LongDirection: 'O'),
  (Country:'Mayotte';       Latitude:12; LatiDeg: 49; LatiDirection: 'S'; Longitude: 45; LongDeg: 9; LongDirection: 'E'),
  (Country:'Mexique';       Latitude:23; LatiDeg: 37; LatiDirection: 'N'; Longitude: 102;LongDeg: 34;LongDirection: 'O'),
  (Country:'Micronesie';    Latitude:5;  LatiDeg: 33; LatiDirection: 'N'; Longitude: 150;LongDeg: 11;LongDirection: 'E'),
  (Country:'Moldavie';      Latitude:46; LatiDeg: 58; LatiDirection: 'N'; Longitude: 28; LongDeg: 22;LongDirection: 'E'),
  (Country:'Monaco';        Latitude:43; LatiDeg: 44; LatiDirection: 'N'; Longitude: 7;  LongDeg: 25;LongDirection: 'E'),
  (Country:'Mongolie';      Latitude:46; LatiDeg: 51; LatiDirection: 'N'; Longitude: 103;LongDeg: 50;LongDirection: 'E'),
  (Country:'Montenegro';    Latitude:42; LatiDeg: 42; LatiDirection: 'N'; Longitude: 19; LongDeg: 24;LongDirection: 'E'),
  (Country:'Montserrat';    Latitude:16; LatiDeg: 44; LatiDirection: 'N'; Longitude: 62; LongDeg: 11;LongDirection: 'O'),
  (Country:'Mozambique';    Latitude:18; LatiDeg: 40; LatiDirection: 'S'; Longitude: 35; LongDeg: 31;LongDirection: 'E'),
  (Country:'Myanmar';       Latitude:19; LatiDeg: 9;  LatiDirection: 'N'; Longitude: 96; LongDeg: 40;LongDirection: 'E'),
  (Country:'Namibie';       Latitude:22; LatiDeg: 57; LatiDirection: 'S'; Longitude: 18; LongDeg: 29;LongDirection: 'E'),
  (Country:'Nauru';         Latitude:0;  LatiDeg: 31; LatiDirection: 'S'; Longitude: 166;LongDeg: 55;LongDirection: 'E'),
  (Country:'Nepal';         Latitude:28; LatiDeg: 23; LatiDirection: 'N'; Longitude: 84; LongDeg: 7; LongDirection: 'E'),
  (Country:'Nicaragua';     Latitude:12; LatiDeg: 52; LatiDirection: 'N'; Longitude: 85; LongDeg: 12;LongDirection: 'O'),
  (Country:'Niger';         Latitude:17; LatiDeg: 36; LatiDirection: 'N'; Longitude: 8;  LongDeg: 4; LongDirection: 'E'),
  (Country:'Nigeria';       Latitude:9;  LatiDeg: 5;  LatiDirection: 'N'; Longitude: 8;  LongDeg: 40;LongDirection: 'E'),
  (Country:'Nioue';         Latitude:19; LatiDeg: 3;  LatiDirection: 'S'; Longitude: 169;LongDeg: 51;LongDirection: 'O'),
  (Country:'Norvege';       Latitude:64; LatiDeg: 34; LatiDirection: 'N'; Longitude: 17; LongDeg: 51;LongDirection: 'E'),
  (Country:'Nouvelle-Caledonie';Latitude:21;LatiDeg:7;LatiDirection: 'S'; Longitude: 165;LongDeg: 50;LongDirection: 'E'),
  (Country:'Nouvelle-Zelande';Latitude:41;LatiDeg:0;  LatiDirection: 'S'; Longitude: 172;LongDeg: 0; LongDirection: 'E'),
  (Country:'Oman';          Latitude:21; LatiDeg: 31; LatiDirection: 'N'; Longitude: 55; LongDeg: 51;LongDirection: 'E'),
  (Country:'Ouganda';       Latitude:1;  LatiDeg: 21; LatiDirection: 'N'; Longitude: 32; LongDeg: 18;LongDirection: 'E'),
  (Country:'Ouzbekistan';   Latitude:41; LatiDeg: 22; LatiDirection: 'N'; Longitude: 64; LongDeg: 33;LongDirection: 'E'),
  (Country:'Pakistan';      Latitude:30; LatiDeg: 26; LatiDirection: 'N'; Longitude: 69; LongDeg: 21;LongDirection: 'E'),
  (Country:'Palaos';        Latitude:5;  LatiDeg: 38; LatiDirection: 'N'; Longitude: 132;LongDeg: 55;LongDirection: 'E'),
  (Country:'Panama';        Latitude:8;  LatiDeg: 25; LatiDirection: 'N'; Longitude: 80; LongDeg: 6; LongDirection: 'O'),
(Country:'Papouasie-Nouvelle Guinee';Latitude:6;LatiDeg:29;LatiDirection:'S';Longitude:148;LongDeg:24;LongDirection:'E'),
  (Country:'Paraguay';      Latitude:23; LatiDeg: 27; LatiDirection: 'S'; Longitude: 58; LongDeg: 27;LongDirection: 'O'),
  (Country:'Pays-Bas';      Latitude:52; LatiDeg: 7;  LatiDirection: 'N'; Longitude: 5;  LongDeg: 17;LongDirection: 'E'),
  (Country:'Perou';         Latitude:9;  LatiDeg: 10; LatiDirection: 'S'; Longitude: 75; LongDeg: 0; LongDirection: 'O'),
  (Country:'Philippines';   Latitude:12; LatiDeg: 52; LatiDirection: 'N'; Longitude: 121;LongDeg: 45;LongDirection: 'E'),
  (Country:'Pitcairn';      Latitude:24; LatiDeg: 29; LatiDirection: 'S'; Longitude: 126;LongDeg: 33;LongDirection: 'O'),
  (Country:'Pologne';       Latitude:51; LatiDeg: 55; LatiDirection: 'N'; Longitude: 19; LongDeg: 8; LongDirection: 'E'),
  (Country:'Polynesie Francaise';Latitude:17;LatiDeg:46;LatiDirection:'S';Longitude: 143;LongDeg: 54;LongDirection: 'O'),
  (Country:'Porto Rico';    Latitude:18; LatiDeg: 13; LatiDirection: 'N'; Longitude: 66; LongDeg: 35;LongDirection: 'O'),
  (Country:'Portugal';      Latitude:39; LatiDeg: 33; LatiDirection: 'N'; Longitude: 7;  LongDeg: 50;LongDirection: 'O'),
  (Country:'Qatar';         Latitude:25; LatiDeg: 19; LatiDirection: 'N'; Longitude: 51; LongDeg: 11;LongDirection: 'E'),
  (Country:'Republique democratique du congo';
                            Latitude:4;  LatiDeg: 2;  LatiDirection: 'S'; Longitude: 21; LongDeg: 45;LongDirection: 'E'),
  (Country:'Republique Dominicaine';Latitude:18;LatiDeg:44;LatiDirection:'N';Longitude:70;LongDeg:9; LongDirection: 'O'),
  (Country:'Republique Togolaise';Latitude:8;LatiDeg:37;LatiDirection:'N';Longitude: 0;  LongDeg: 49;LongDirection: 'E'),
  (Country:'Reunion';       Latitude:21; LatiDeg: 6;  LatiDirection: 'S'; Longitude: 55; LongDeg: 31;LongDirection: 'E'),
  (Country:'Roumanie';      Latitude:45; LatiDeg: 56; LatiDirection: 'N'; Longitude: 24; LongDeg: 58;LongDirection: 'E'),
  (Country:'Royaume-Uni';   Latitude:54; LatiDeg: 37; LatiDirection: 'N'; Longitude: 3;  LongDeg: 25;LongDirection: 'O'),
  (Country:'Russie';        Latitude:61; LatiDeg: 31; LatiDirection: 'N'; Longitude: 105;LongDeg: 6; LongDirection: 'E'),
  (Country:'Rwanda';        Latitude:1;  LatiDeg: 56; LatiDirection: 'S'; Longitude: 29; LongDeg: 52;LongDirection: 'E'),
  (Country:'Sahara Occidental';Latitude:24;LatiDeg:13;LatiDirection: 'N'; Longitude: 12; LongDeg: 53;LongDirection: 'O'),
  (Country:'Saint-Barthelemy';Latitude:17; LatiDeg:54;LatiDirection: 'N'; Longitude: 62; LongDeg: 49;LongDirection: 'O'),
  (Country:'Saint-Christophe-et-Nieves';
                            Latitude:17; LatiDeg: 15; LatiDirection: 'N'; Longitude: 62; LongDeg: 42;LongDirection: 'O'),
  (Country:'Saint-Marin';   Latitude:43; LatiDeg: 56; LatiDirection: 'N'; Longitude: 12; LongDeg: 27;LongDirection: 'E'),
  (Country:'Saint-Martin';  Latitude:18; LatiDeg: 2;  LatiDirection: 'N'; Longitude: 63; LongDeg: 4; LongDirection: 'O'),
  (Country:'Saint-Pierre et Miquelon';
                            Latitude:46; LatiDeg: 57; LatiDirection: 'N'; Longitude: 56; LongDeg: 20;LongDirection: 'O'),
  (Country:'Saint-Vincent-et-les Grenadines';
                            Latitude:12; LatiDeg: 58; LatiDirection: 'N'; Longitude: 61; LongDeg: 17;LongDirection: 'O'),
  (Country:'Sainte-Helene'; Latitude:11; LatiDeg: 57; LatiDirection: 'S'; Longitude: 10; LongDeg: 1; LongDirection: 'O'),
  (Country:'Sainte-Lucie';  Latitude:13; LatiDeg: 54; LatiDirection: 'N'; Longitude: 60; LongDeg: 58;LongDirection: 'O'),
  (Country:'Salvador';      Latitude:13; LatiDeg: 47; LatiDirection: 'N'; Longitude: 88; LongDeg: 54;LongDirection: 'O'),
  (Country:'Samoa';         Latitude:13; LatiDeg: 44; LatiDirection: 'S'; Longitude: 172;LongDeg: 6; LongDirection: 'O'),
  (Country:'Samoa americaines';Latitude:12;LatiDeg:42;LatiDirection: 'S'; Longitude:170; LongDeg: 15;LongDirection: 'O'),
  (Country:'Sao Tome-et-Principe';Latitude:0;LatiDeg:51;LatiDirection:'N'; Longitude: 6; LongDeg: 58;LongDirection: 'E'),
  (Country:'Senegal';       Latitude:14; LatiDeg: 29; LatiDirection: 'N'; Longitude: 14; LongDeg: 26;LongDirection: 'O'),
  (Country:'Serbie';        Latitude:44; LatiDeg: 12; LatiDirection: 'N'; Longitude: 20; LongDeg: 54;LongDirection: 'E'),
  (Country:'Seychelles';    Latitude:7;  LatiDeg: 1;  LatiDirection: 'S'; Longitude: 51; LongDeg: 14;LongDirection: 'E'),
  (Country:'Sierra Leone';  Latitude:8;  LatiDeg: 27; LatiDirection: 'N'; Longitude: 11; LongDeg: 47;LongDirection: 'O'),
  (Country:'Singapour';     Latitude:1;  LatiDeg: 21; LatiDirection: 'N'; Longitude: 103;LongDeg: 49;LongDirection: 'E'),
  (Country:'Slovaquie';     Latitude:48; LatiDeg: 39; LatiDirection: 'N'; Longitude: 19; LongDeg: 42;LongDirection: 'E'),
  (Country:'Slovenie';      Latitude:46; LatiDeg: 8;  LatiDirection: 'N'; Longitude: 14; LongDeg: 58;LongDirection: 'E'),
  (Country:'Somalie';       Latitude:5;  LatiDeg: 9;  LatiDirection: 'N'; Longitude: 46; LongDeg: 11;LongDirection: 'E'),
  (Country:'Soudan';        Latitude:15; LatiDeg: 27; LatiDirection: 'N'; Longitude: 30; LongDeg: 13;LongDirection: 'E'),
  (Country:'Sri Lanka';     Latitude:7;  LatiDeg: 52; LatiDirection: 'N'; Longitude: 80; LongDeg: 46;LongDirection: 'E'),
  (Country:'Sud-Soudan';    Latitude:7;  LatiDeg: 51; LatiDirection: 'N'; Longitude: 30; LongDeg: 2; LongDirection: 'E'),
  (Country:'Suede';         Latitude:62; LatiDeg: 11; LatiDirection: 'N'; Longitude: 17; LongDeg: 38;LongDirection: 'E'),
  (Country:'Suisse';        Latitude:46; LatiDeg: 48; LatiDirection: 'N'; Longitude: 8;  LongDeg: 13;LongDirection: 'E'),
  (Country:'Surinam';       Latitude:3;  LatiDeg: 55; LatiDirection: 'N'; Longitude: 56; LongDeg: 1; LongDirection: 'O'),
  (Country:'Svalbard et Ile Jan Mayen';
                            Latitude:79; LatiDeg: 59; LatiDirection: 'N'; Longitude: 25; LongDeg: 29;LongDirection: 'E'),
  (Country:'Swaziland';     Latitude:26; LatiDeg: 31; LatiDirection: 'S'; Longitude: 31; LongDeg: 27;LongDirection: 'E'),
  (Country:'Syrie';         Latitude:34; LatiDeg: 48; LatiDirection: 'N'; Longitude: 39; LongDeg: 3; LongDirection: 'E'),
  (Country:'Tadjikistan';   Latitude:38; LatiDeg: 51; LatiDirection: 'N'; Longitude: 71; LongDeg: 15;LongDirection: 'E'),
  (Country:'Taiwan';        Latitude:23; LatiDeg: 36; LatiDirection: 'N'; Longitude: 120;LongDeg: 46;LongDirection: 'E'),
  (Country:'Tanzanie';      Latitude:6;  LatiDeg: 22; LatiDirection: 'S'; Longitude: 34; LongDeg: 53;LongDirection: 'E'),
  (Country:'Tchad';         Latitude:15; LatiDeg: 26; LatiDirection: 'N'; Longitude: 18; LongDeg: 44;LongDirection: 'E'),
  (Country:'Tchequie';      Latitude:49; LatiDeg: 48; LatiDirection: 'N'; Longitude: 15; LongDeg: 28;LongDirection: 'E'),
  (Country:'Terres australes francaises';
                            Latitude:43; LatiDeg: 45; LatiDirection: 'S'; Longitude: 63; LongDeg: 53;LongDirection: 'E'),
  (Country:'Territoire britannique de l''ocean Indien';
                            Latitude:6;  LatiDeg: 21; LatiDirection: 'N'; Longitude: 71; LongDeg: 52;LongDirection: 'E'),
  (Country:'Territoire palestinien';Latitude:31;LatiDeg:52;LatiDirection:'N';Longitude:34;LongDeg:53;LongDirection: 'E'),
  (Country:'Thailande';     Latitude:13; LatiDeg: 2;  LatiDirection: 'N'; Longitude: 101;LongDeg: 29;LongDirection: 'E'),
  (Country:'Timor Oriental';Latitude:8;  LatiDeg: 47; LatiDirection: 'S'; Longitude: 125;LongDeg: 40;LongDirection: 'E'),
  (Country:'Tokelau';       Latitude:8;  LatiDeg: 58; LatiDirection: 'S'; Longitude: 171;LongDeg: 51;LongDirection: 'O'),
  (Country:'Tonga';         Latitude:18; LatiDeg: 30; LatiDirection: 'S'; Longitude: 174;LongDeg: 47;LongDirection: 'O'),
  (Country:'Trinidad et Tobago';Latitude:10;LatiDeg:41;LatiDirection: 'N';Longitude: 61; LongDeg: 13;LongDirection: 'O'),
  (Country:'Tunisie';       Latitude:33; LatiDeg: 53; LatiDirection: 'N'; Longitude: 9;  LongDeg: 33;LongDirection: 'E'),
  (Country:'Turkmenistan';  Latitude:38; LatiDeg: 58; LatiDirection: 'N'; Longitude: 59; LongDeg: 33;LongDirection: 'E'),
  (Country:'Turquie';       Latitude:38; LatiDeg: 57; LatiDirection: 'N'; Longitude: 35; LongDeg: 15;LongDirection: 'E'),
  (Country:'Tuvalu';        Latitude:8;  LatiDeg: 13; LatiDirection: 'S'; Longitude: 177;LongDeg: 57;LongDirection: 'E'),
  (Country:'Ukraine';       Latitude:48; LatiDeg: 22; LatiDirection: 'N'; Longitude: 31; LongDeg: 10;LongDirection: 'E'),
  (Country:'Uruguay';       Latitude:32; LatiDeg: 31; LatiDirection: 'S'; Longitude: 55; LongDeg: 45;LongDirection: 'O'),
  (Country:'Vanuatu';       Latitude:16; LatiDeg: 39; LatiDirection: 'S'; Longitude: 168;LongDeg: 12;LongDirection: 'E'),
  (Country:'Vatican';       Latitude:41; LatiDeg: 54; LatiDirection: 'N'; Longitude: 12; LongDeg: 27;LongDirection: 'E'),
  (Country:'Venezuela';     Latitude:6;  LatiDeg: 24; LatiDirection: 'N'; Longitude: 66; LongDeg: 34;LongDirection: 'O'),
  (Country:'Vietnam';       Latitude:15; LatiDeg: 58; LatiDirection: 'N'; Longitude: 105;LongDeg: 48;LongDirection: 'E'),
  (Country:'Wallis-et-Futuna';Latitude:13;LatiDeg:45; LatiDirection: 'S'; Longitude: 177;LongDeg: 10;LongDirection: 'O'),
  (Country:'Yemen';         Latitude:15; LatiDeg: 15; LatiDirection: 'N'; Longitude: 48; LongDeg: 31;LongDirection: 'E'),
  (Country:'Zambie';        Latitude:13; LatiDeg: 9;  LatiDirection: 'S'; Longitude: 27; LongDeg: 51;LongDirection: 'E'),
  (Country:'Zimbabwe';      Latitude:19; LatiDeg: 0;  LatiDirection: 'S'; Longitude: 29; LongDeg: 8; LongDirection: 'E')
 );


 City:Array[1..73] of CityGeoRecord=(
  (City:'Alger';          Latitude:36; LatiDeg: 45; LatiDirection: 'N'; Longitude: 3;  LongDeg:   2; LongDirection: 'E'),
  (City:'Alma';           Latitude:48; LatiDeg: 35; LatiDirection: 'N'; Longitude: 71; LongDeg:  40; LongDirection: 'O'),
  (City:'Arvida';         Latitude:48; LatiDeg: 26; LatiDirection: 'N'; Longitude: 71; LongDeg:  11; LongDirection: 'O'),
  (City:'Bagdad';         Latitude:33; LatiDeg: 20; LatiDirection: 'N'; Longitude: 44; LongDeg:  26; LongDirection: 'E'),
  (City:'Bagotville';     Latitude:48; LatiDeg: 19; LatiDirection: 'N'; Longitude: 70; LongDeg:  59; LongDirection: 'O'),
  (City:'Barcelone';      Latitude:41; LatiDeg: 22; LatiDirection: 'N'; Longitude:  2; LongDeg:  10; LongDirection: 'E'),
  (City:'Beijing';        Latitude:39; LatiDeg: 54; LatiDirection: 'N'; Longitude: 116;LongDeg:  24; LongDirection: 'E'),
  (City:'Berlin';         Latitude:52; LatiDeg: 31; LatiDirection: 'N'; Longitude: 13; LongDeg:  24; LongDirection: 'E'),
  (City:'Boston';         Latitude:42; LatiDeg: 21; LatiDirection: 'N'; Longitude: 71; LongDeg:   3; LongDirection: 'O'),
  (City:'Brampton';       Latitude:43; LatiDeg: 41; LatiDirection: 'N'; Longitude: 79; LongDeg:  46; LongDirection: 'O'),
  (City:'Brossard';       Latitude:45; LatiDeg: 28; LatiDirection: 'N'; Longitude: 73; LongDeg:  27; LongDirection: 'O'),
  (City:'Calgary';        Latitude:51; LatiDeg:  2; LatiDirection: 'N'; Longitude: 114;LongDeg:   3; LongDirection: 'O'),
  (City:'Chicago';        Latitude:41; LatiDeg: 52; LatiDirection: 'N'; Longitude: 87; LongDeg:  34; LongDirection: 'O'),
  (City:'Chicoutimi';     Latitude:48; LatiDeg: 28; LatiDirection: 'N'; Longitude: 71; LongDeg:   5; LongDirection: 'O'),
  (City:'Chomedey';       Latitude:45; LatiDeg: 32; LatiDirection: 'N'; Longitude: 73; LongDeg:  45; LongDirection: 'O'),
  (City:'Dallas';         Latitude:32; LatiDeg: 46; LatiDirection: 'N'; Longitude: 96; LongDeg:  48; LongDirection: 'O'),
  (City:'Delhi';          Latitude:28; LatiDeg: 38; LatiDirection: 'N'; Longitude: 77; LongDeg:  13; LongDirection: 'E'),
  (City:'Edmonton';       Latitude:53; LatiDeg: 32; LatiDirection: 'N'; Longitude: 113;LongDeg:  30; LongDirection: 'O'),
  (City:'Gaspe';          Latitude:48; LatiDeg: 49; LatiDirection: 'N'; Longitude: 64; LongDeg:  29; LongDirection: 'O'),
  (City:'Gatineau';       Latitude:45; LatiDeg: 29; LatiDirection: 'N'; Longitude: 75; LongDeg:  39; LongDirection: 'O'),
  (City:'Geneve';         Latitude:46; LatiDeg: 12; LatiDirection: 'N'; Longitude: 6;  LongDeg:   9; LongDirection: 'E'),
  (City:'Grand-mere';     Latitude:46; LatiDeg: 36; LatiDirection: 'N'; Longitude: 72; LongDeg:  40; LongDirection: 'O'),
  (City:'Guelph';         Latitude:43; LatiDeg: 33; LatiDirection: 'N'; Longitude: 80; LongDeg:  15; LongDirection: 'O'),
  (City:'Halifax';        Latitude:44; LatiDeg: 38; LatiDirection: 'N'; Longitude: 63; LongDeg:  34; LongDirection: 'O'),
  (City:'Hamilton';       Latitude:43; LatiDeg: 15; LatiDirection: 'N'; Longitude: 79; LongDeg:  52; LongDirection: 'O'),
  (City:'Houston';        Latitude:29; LatiDeg: 45; LatiDirection: 'N'; Longitude: 95; LongDeg:  22; LongDirection: 'O'),
  (City:'Jakarta';        Latitude: 6; LatiDeg: 12; LatiDirection: 'S'; Longitude:106; LongDeg:  50; LongDirection: 'E'),
  (City:'Jonquiere';      Latitude:48; LatiDeg: 27; LatiDirection: 'N'; Longitude: 71; LongDeg:  14; LongDirection: 'O'),
  (City:'Laval';          Latitude:45; LatiDeg: 35; LatiDirection: 'N'; Longitude: 73; LongDeg:  45; LongDirection: 'O'),
  (City:'Levis';          Latitude:46; LatiDeg: 48; LatiDirection: 'N'; Longitude: 71; LongDeg:  11; LongDirection: 'O'),
  (City:'London';         Latitude:42; LatiDeg: 59; LatiDirection: 'N'; Longitude: 81; LongDeg:  14; LongDirection: 'O'),
  (City:'Londres';        Latitude:51; LatiDeg: 30; LatiDirection: 'N'; Longitude:  0; LongDeg:   7; LongDirection: 'O'),
  (City:'Longueuil';      Latitude:45; LatiDeg: 32; LatiDirection: 'N'; Longitude: 73; LongDeg:  31; LongDirection: 'O'),
  (City:'Madrid';         Latitude:40; LatiDeg: 26; LatiDirection: 'N'; Longitude: 3;  LongDeg:  41; LongDirection: 'O'),
  (City:'Manille';        Latitude:14; LatiDeg: 35; LatiDirection: 'N'; Longitude: 120;LongDeg:  58; LongDirection: 'E'),
  (City:'Markham';        Latitude:43; LatiDeg: 53; LatiDirection: 'N'; Longitude: 79; LongDeg:  15; LongDirection: 'O'),
  (City:'Marseille';      Latitude:43; LatiDeg: 17; LatiDirection: 'N'; Longitude: 5;  LongDeg:  22; LongDirection: 'E'),
  (City:'Mexico';         Latitude:23; LatiDeg: 38; LatiDirection: 'N'; Longitude: 102;LongDeg:  33; LongDirection: 'O'),
  (City:'Miami';          Latitude:25; LatiDeg: 47; LatiDirection: 'N'; Longitude: 80; LongDeg:  13; LongDirection: 'O'),
  (City:'Milan';          Latitude:45; LatiDeg: 27; LatiDirection: 'N'; Longitude:  9; LongDeg:  11; LongDirection: 'E'),
  (City:'Mirabel';        Latitude:45; LatiDeg: 39; LatiDirection: 'N'; Longitude: 74; LongDeg:   5; LongDirection: 'O'),
  (City:'Mississauga';    Latitude:43; LatiDeg: 36; LatiDirection: 'N'; Longitude: 79; LongDeg:  39; LongDirection: 'O'),
  (City:'Mumbai';         Latitude:19; LatiDeg:  4; LatiDirection: 'N'; Longitude: 72; LongDeg:  52; LongDirection: 'E'),
  (City:'Moncton';        Latitude:46; LatiDeg:  5; LatiDirection: 'N'; Longitude: 64; LongDeg:  46; LongDirection: 'O'),
  (City:'Montreal';       Latitude:45; LatiDeg: 31; LatiDirection: 'N'; Longitude: 73; LongDeg:  34; LongDirection: 'O'),
  (City:'Moscou';         Latitude:55; LatiDeg: 45; LatiDirection: 'N'; Longitude: 37; LongDeg:  37; LongDirection: 'E'),
  (City:'Munich';         Latitude:48; LatiDeg:  9; LatiDirection: 'N'; Longitude: 11; LongDeg:  34; LongDirection: 'E'),
  (City:'Oakville';       Latitude:43; LatiDeg: 28; LatiDirection: 'N'; Longitude: 79; LongDeg:  41; LongDirection: 'O'),
  (City:'Ottawa';         Latitude:45; LatiDeg: 25; LatiDirection: 'N'; Longitude: 75; LongDeg:  41; LongDirection: 'O'),
  (City:'Paris';          Latitude:48; LatiDeg: 50; LatiDirection: 'N'; Longitude: 2;  LongDeg:  20; LongDirection: 'E'),
  (City:'Pekin';          Latitude:39; LatiDeg: 54; LatiDirection: 'N'; Longitude: 116;LongDeg:  23; LongDirection: 'E'),
  (City:'Quebec';         Latitude:46; LatiDeg: 48; LatiDirection: 'N'; Longitude: 71; LongDeg:  13; LongDirection: 'O'),
  (City:'Rome';           Latitude:41; LatiDeg: 53; LatiDirection: 'N'; Longitude: 12; LongDeg:  29; LongDirection: 'E'),
  (City:'Saguenay';       Latitude:48; LatiDeg: 25; LatiDirection: 'N'; Longitude: 71; LongDeg:   4; LongDirection: 'O'),
  (City:'Sainte-Dorothee';Latitude:45; LatiDeg: 32; LatiDirection: 'N'; Longitude: 73; LongDeg:  49; LongDirection: 'O'),
  (City:'Saint-Jerome';   Latitude:45; LatiDeg: 47; LatiDirection: 'N'; Longitude: 74; LongDeg:  0;  LongDirection: 'O'),
  (City:'Saint-Lin';      Latitude:45; LatiDeg: 44; LatiDirection: 'N'; Longitude: 73; LongDeg:  46; LongDirection: 'O'),
  (City:'Seoul';          Latitude:37; LatiDeg: 33; LatiDirection: 'N'; Longitude: 126;LongDeg:  58; LongDirection: 'E'),
  (City:'Shanghai';       Latitude:31; LatiDeg: 14; LatiDirection: 'N'; Longitude: 121;LongDeg:  29; LongDirection: 'E'),
  (City:'Sherbrooke';     Latitude:45; LatiDeg: 24; LatiDirection: 'N'; Longitude: 71; LongDeg:  54; LongDirection: 'O'),
  (City:'Sept-Iles';      Latitude:50; LatiDeg: 13; LatiDirection: 'N'; Longitude: 66; LongDeg:  23; LongDirection: 'O'),
  (City:'St-Lin';         Latitude:45; LatiDeg: 44; LatiDirection: 'N'; Longitude: 73; LongDeg:  46; LongDirection: 'O'),
  (City:'Ste-Dorothee';   Latitude:45; LatiDeg: 32; LatiDirection: 'N'; Longitude: 73; LongDeg:  49; LongDirection: 'O'),
  (City:'Surrey';         Latitude:49; LatiDeg: 11; LatiDirection: 'N'; Longitude: 122;LongDeg:  51; LongDirection: 'O'),
  (City:'Sydney';         Latitude:33; LatiDeg: 51; LatiDirection: 'S'; Longitude: 151;LongDeg:  11; LongDirection: 'E'),
  (City:'Tadoussac';      Latitude:48; LatiDeg:  9; LatiDirection: 'N'; Longitude: 69; LongDeg:  43; LongDirection: 'O'),
  (City:'Teheran';        Latitude:35; LatiDeg: 41; LatiDirection: 'N'; Longitude: 51; LongDeg:  25; LongDirection: 'E'),
  (City:'Terrebonne';     Latitude:45; LatiDeg: 42; LatiDirection: 'N'; Longitude: 73; LongDeg:  38; LongDirection: 'O'),
  (City:'Tokyo';          Latitude:35; LatiDeg: 41; LatiDirection: 'N'; Longitude: 139;LongDeg:  41; LongDirection: 'E'),
  (City:'Toronto';        Latitude:43; LatiDeg: 40; LatiDirection: 'N'; Longitude: 79; LongDeg:  23; LongDirection: 'O'),
  (City:'Vancouver';      Latitude:49; LatiDeg: 15; LatiDirection: 'N'; Longitude: 123;LongDeg:   6; LongDirection: 'O'),
  (City:'Washington';     Latitude:38; LatiDeg: 53; LatiDirection: 'N'; Longitude: 77; LongDeg:   2; LongDirection: 'O'),
  (City:'Winnipeg';       Latitude:49; LatiDeg: 53; LatiDirection: 'N'; Longitude: 97; LongDeg:   9; LongDirection: 'O')
 );

Function StrToUpper(S:String):String;
Var
 I:Byte;
Begin
 For I:=1 to Length(S)do Begin
  If S[I] in['a'..'z']Then S[I]:=Chr(Ord(S[I])-32);
 End;
 StrToUpper:=S;
End;

Function GetSeasonNumber:Byte;
Var
 Year,Month,Days,DOW:Word;
Begin
 GetDate(Year,Month,Days,DOW);
 If(Month<=3)and(Days<=21)Then GetSeasonNumber:=1 Else
 If(Month<=6)and(Days<=20)Then GetSeasonNumber:=2 Else
 If(Month<=9)and(Days<=22)Then GetSeasonNumber:=3 Else
 If(Month<=12)and(Days<=21)Then GetSeasonNumber:=4
                           Else GetSeasonNumber:=1;
End;

Var
 I,J:Integer;
 Found:Boolean;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('SEASON : Cette commande permet de retourner la saison d''un pays ou d''une ville.');
  WriteLn;
  WriteLn('Syntaxe : SEASON [pays]');
 End
  Else
 If ParamCount>0Then Begin
  For I:=1 to ParamCount do Begin
   Found:=False;
   For J:=Low(Country) to High(Country)do Begin
    If StrToUpper(Country[J].Country)=StrToUpper(ParamStr(I))Then Begin
     If(Country[J].LatiDirection='N')Then Begin
      Case GetSeasonNumber of
       1:WriteLn('Hiver');
       2:WriteLn('Printemps');
       3:WriteLn('Ete');
       4:WriteLn('Automne');
       Else WriteLn('Inconnu');
      End;
     End
      Else
     Begin
      Case GetSeasonNumber of
       1:WriteLn('Ete');
       2:WriteLn('Automne');
       3:WriteLn('Hiver');
       4:WriteLn('Printemps');
       Else WriteLn('Inconnu');
      End;
     End;
     Found:=True;
     Break;
    End;
   End;
   If Not(Found)Then For J:=Low(City) to High(City)do Begin
    If StrToUpper(City[J].City)=StrToUpper(ParamStr(I))Then Begin
     If(City[J].LatiDirection='N')Then Begin
      Case GetSeasonNumber of
       1:WriteLn('Hiver');
       2:WriteLn('Printemps');
       3:WriteLn('Ete');
       4:WriteLn('Automne');
       Else WriteLn('Inconnu');
      End;
     End
      Else
     Begin
      Case GetSeasonNumber of
       1:WriteLn('Ete');
       2:WriteLn('Automne');
       3:WriteLn('Hiver');
       4:WriteLn('Printemps');
       Else WriteLn('Inconnu');
      End;
     End;
     Found:=True;
     Break;
    End;
   End;
  End;
 End
  Else
 Begin
  Write('La saison de votre systäme est : ');
  Case GetSeasonNumber of
   1:WriteLn('Hiver');
   2:WriteLn('Printemps');
   3:WriteLn('Ete');
   4:WriteLn('Automne');
   Else WriteLn('Inconnu');
  End;
 End;
END.
