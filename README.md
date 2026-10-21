# METEOPOLIS
METEOPOLIS - Ensemble de commande écrit en Pascal d'aide sur la météorologie.

<h2>Liste des fichiers</h2>

Voici la liste des différents fichiers proposés dans METEOPOLIS :

<table>
	<tr>
		<th>Nom</th>
		<th>Description</th>	
	</tr>
	<tr>
		<td><b>NCAP2.PAS</b></td>
		<td>Processeur arithmetique NetCDF autonome pour Turbo Pascal 7 et Free Pascal : CDF-1/CDF-2, expressions sur tableaux, scripts, attributs, tranches, boucles et reductions. Implementation partielle de NCO ; consulter <code>NCAP2 --help</code> pour les limites.</td>
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

<p><b>NCAP2.PAS</b> compile avec Turbo Pascal 7 (<code>tpc NCAP2.PAS</code>) et Free Pascal (<code>fpc NCAP2.PAS</code>). Il utilise uniquement des records, des procedures et des fonctions, sans unite ni include ; ses tables sont allouees dans le tas. Pour respecter les limites DOS 16 bits : 4096 elements par tableau, 64 variables, 128 dimensions, rang 8, scripts de 60000 octets, noms de 63 caracteres et textes de 255 caracteres. Les formats CDF-1/CDF-2 sont pris en charge avec des offsets limites a 2 Go ; les autres formats ne sont pas implementes. Tests Free Pascal : <code>python tests/test_ncap2.py</code> apres compilation. Compilation et executions avec le vrai Turbo Pascal dans DOSBox : <code>python tests/test_ncap2_tp.py --bp C:/BP --dosbox "chemin/DOSBox.exe"</code>.</p>

<h2>Licence</h2>
<ul>
 <li>Le code source est publié sous la licence <a href="https://github.com/gladir/METEOPOLIS/blob/master/LICENSE">MIT</a>.</li>
 <li>Le paquet original est publié sous la licence <a href="https://github.com/gladir/METEOPOLIS/blob/master/LICENSE">MIT</a>.</li>
</ul>
