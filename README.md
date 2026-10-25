# METEOPOLIS
METEOPOLIS - Ensemble de commande écrit en Pascal d'aide sur la météorologie.

Aperçu de la commande STORMVIEW :

<img width="641" height="476" alt="image" src="https://github.com/user-attachments/assets/f708dbd5-fd8a-4ec6-88fb-c7b1b6624341" />

<h2>Liste des fichiers</h2>

Voici la liste des différents fichiers proposés dans METEOPOLIS :

<table>
	<tr>
		<th>Nom</th>
		<th>Description</th>	
	</tr>
	<tr>
		<td><b>NCAP2.PAS</b></td>
		<td>Cette commande permet de lancer le processeur arithmetique NetCDF autonome : CDF-1/CDF-2, expressions sur tableaux, scripts, attributs, tranches, boucles et reductions.</td>
	</tr>
	<tr>
		<td><b>CONVERS.PAS</b></td>
		<td>Cette commande permet de convertir une unite de mesure de temperature.</td>
	</tr>
     	<tr>
		<td><b>SEASON.PAS</b></td>
		<td>Cette commande permet de retourner la saison actuelle d'un pays ou de certaines villes.</td>
	</tr>
	<tr>
		<td><b>STORMVIEW.PAS</b></td>
		<td>Cette commande permet de lancer un clone de StormView Radar en mode graphique (souris) : radar anime, alertes meteo, foudre, stations, suivi de cellules orageuses, mesure de distance et profils de sources MRMS, NEXRAD Niveau II, NOAA nowCOAST, HRRR, RainViewer et ECCC GeoMet. Tapez <code>STORMVIEW /?</code> pour la liste des parametres.</td>
	</tr>
	<tr>
		<td><b>TEMP.PAS</b></td> 
		<td>Cette commande permet de retourner la temperature moyenne d'un pays ou d'une capitale par mois.</td>
	</tr>
</table>

<h2>Compilation</h2>
	
Les fichiers Pascal n'ont aucune dépendances, il suffit de télécharger le fichier désiré et de le compiler avec Free Pascal avec la syntaxe de commande  :

<pre><b>fpc</b> <i>LEFICHIER.PAS</i></pre>
	
Sinon, vous pouvez également le compiler avec le Turbo Pascal à l'aide de la syntaxe de commande suivante :	

<pre><b>tpc</b> <i>LEFICHIER.PAS</i></pre>
	
Par exemple, si vous voulez compiler SEASON.PAS, vous devrez tapez la commande suivante :

<pre><b>fpc</b> SEASON.PAS</pre>

<p><b>NCAP2.PAS</b> compile avec Turbo Pascal 7 (<code>tpc NCAP2.PAS</code>) et Free Pascal (<code>fpc NCAP2.PAS</code>). Il utilise uniquement des records, des procedures et des fonctions, sans unite ni include ; ses tables sont allouees dans la mémoire de tas. Pour respecter les limites DOS 16 bits : 4096 elements par tableau, 64 variables, 128 dimensions, rang 8, scripts de 60000 octets, noms de 63 caracteres et textes de 255 caracteres. Les formats CDF-1/CDF-2 sont pris en charge avec des offsets limites a 2 Go ; les autres formats ne sont pas implementes.</p>

<p><b>STORMVIEW.PAS</b> compile avec Turbo Pascal 7 (<code>tpc STORMVIEW.PAS</code>) et Free Pascal (<code>fpc STORMVIEW.PAS</code>). Il utilise uniquement les unites Crt, Graph (ou PtcGraph, PtcCrt et PtcMouse avec Free Pascal) et Dos, sans aucun fichier include. Sous Linux, l'unite CThreads est ajoutee automatiquement (requise par PtcGraph) et un affichage graphique (X11) est necessaire, meme pour <code>/?</code>.</p>

<p>STORMVIEW ne fait aucun acces reseau : les donnees doivent etre telechargees (curl, wget) puis converties en l'un des formats suivants. Les fichiers sont lus avec <code>STORMVIEW fichier [options]</code> :</p>
<ul>
 <li><b>.SVR</b> : sequence texte propre a STORMVIEW (grille de 120x80 au plus, 24 images au plus, alertes avec polygones, foudre, stations, lieux). Un balayage polaire NEXRAD (<code>RADAR</code> / <code>RADIAUX</code>) y est egalement possible. Les parametres sont listes dans le menu <i>Aide / Formats de fichiers</i>.</li>
 <li><b>.ASC</b> : grille ESRI ASCII (par exemple obtenue avec <code>gdal_translate -of AAIGrid</code> a partir d'un GRIB2 MRMS ou HRRR, ou d'un GeoTIFF GeoMet). Un fichier = une image ; les grilles plus grandes que 120x80 sont reduites en conservant le maximum.</li>
 <li><b>.LST</b> : liste de fichiers .ASC avec les options <code>SOURCE</code>, <code>PAS</code>, <code>HEURE</code>, <code>MMH</code> et <code>TITRE</code>.</li>
</ul>

<p>Le dossier <b>TEST/</b> contient des echantillons de demonstration (donnees synthetiques) qui montrent le deplacement des orages d'heure en heure : <code>OKLAHOMA.SVR</code> (MRMS), <code>KTLX.SVR</code> (NEXRAD, balayage polaire), <code>FLORIDE.SVR</code> (nowCOAST, ouragan), <code>TEXAS.SVR</code> (HRRR, prevision), <code>GRANDSLACS.SVR</code> (RainViewer), <code>QUEBEC.SVR</code> (GeoMet) et <code>QC_ASC.LST</code> (grilles ESRI en mm/h). Avec Free Pascal, <code>STORMVIEW /GENERER</code> les recree.</p>

<h2>Licence</h2>
<ul>
 <li>Le code source est publié sous la licence <a href="https://github.com/gladir/METEOPOLIS/blob/master/LICENSE">MIT</a>.</li>
 <li>Le paquet original est publié sous la licence <a href="https://github.com/gladir/METEOPOLIS/blob/master/LICENSE">MIT</a>.</li>
</ul>
