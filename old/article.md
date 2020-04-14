# Comment effectuer le rendu (rendering) des 2.006.717 arbres générés par nam. R?

Il y a quelques jours, [@orovellotti](https://twitter.com/orovellotti) m'a transmis [un article][1] en medium qui expliquait comment la startup française **[nam.R](https://namr.com)** avait construit une base de données référentielle normalisée et homogène de l'ensemble des arbres gérés par différents acteurs publics en France. J'ai adoré le projet, et il tombe à pic pour montrer comment créer une carte de tuiles vectorielles avec les plus de deux millions d'arbres obtenus par nam.R.

Pour orienter mes recherches, [@AurlieJAMBON](https://twitter.com/AurlieJAMBON) m'a recommandé [un projet][2] similaire centré sur la ville de New York.

![new-york-map](./doc/images/nyc.png)

Ce qui a le plus attiré mon attention, c'est qu'à mesure que l'on augmente le zoom, les zones où un grand nombre d'arbres sont concentrés n'apparaissent pas comme un amas informe, bien au contraire. La représentation des arbres par des cercles de différents diamètres, opacités et couleurs permet en effet de les différencier les uns des autres. La technique utilisée pour ce rendu était clairement une carte de tuiles vectorielles.

## Les cartes de tuiles vectorielles : antécédents

Les premières cartes web sont apparues dans les années 1990 et MapQuest était alors le service le plus connu. Ses systèmes de navigation étaient assez rudimentaires et l'expérience de l'utilisateur relativement pauvre. Chaque fois qu'un utilisateur réalisait une action de navigation sur la carte, une demande au serveur était envoyée pour qu'il génère une nouvelle image. Même si le changement était minime, une image nouvelle était générée et renvoyée au client.

![ijgi-06-00317-g001](./doc/images/ijgi-06-00317-g001.png)

Puis en 2005 Google introduit Google Maps et chamboule le monde des cartes web avec une nouvelle technologie appelée **"slippy map"**. Très vite, de nouvelles applications avec une interface similaire voient le jour, pour tous types de dispositifs informatiques et pour les téléphones portables. Le concept clé sur lequel repose la technologie "slippy map" est celui de cartes basées sur des pyramides de mosaïques de tuiles.

## Les cartes de tuiles

La création de cartes de mosaïques s'effectue selon les valeurs d'une série de propriétés. Ces propriétés incluent la forme et la taille des mosaïques, la numérotation des niveaux de zoom, le schéma de sous-division d'une mosaïque pour obtenir les mosaïques dans le niveau suivant de zoom, la numérotation des mosaïques individuelles et la projection de cartes de mosaïques.

![tile-pyramid-model-for-map-visualization](./doc/images/tile-pyramid-model-for-map-visualization.png)

Les conventions de Google Maps pour ces valeurs sont les suivantes. Toutes les mosaïques de la carte ont une forme carrée et sont égalisées (c'est-à-dire/ à savoir) 256x256 pixels. Le monde est représenté dans une seule mosaïque au niveau de zoom le plus externe et se numérote comme zéro. Ce dessin représente la terre dans la projection Web Mercator (les valeurs de lattitude oscillent entre environ -85.0511 et +85.0511), et exclut les aires polaires. La projection adoptée pour toutes les mosaïques est Web Mercator avec la donnée WGS'84. Chaque mosaïque à n'importe quel niveau de zoom k est remplacée par 4 mosaïques de la même taille au niveau de zoom k + 1. Comme la taille de chaque nouvelle mosaïque continue d'être 256x256 pixels, la taille de pixel au niveau K + 1 est quatre fois plus petite que la taille de pixel au niveau k. Le nombre de mosaïques au niveau de zoom k est égal à ![formula](https://render.githubusercontent.com/render/math?math=4^k), par exemple, aux niveaux de zoom 3 et 17, il y a 64 et 17.179.869.184 mosaïques, tandis que la résolution du terrain est respectivement de 20 km et 1, 19 m par pixel. La numérotation d'une mosaïque au niveau de zoom k se décrit à travers une paire de nombres entiers (x, y), où x est le numéro de colonne de la mosaïque, en partant de la longitude de 180 degrés et en direction est, et y est le numéro de file de la tuile, en partant de la lattitude de + 85.0511 degrés et en allant vers le sud.

![Google-Maps-Tiling-Scheme-the-first-three-zoom-levels-the-tiles-and-their-numbering](./doc/images/Google-Maps-Tiling-Scheme-the-first-three-zoom-levels-the-tiles-and-their-numbering.png)

La plupart des principaux fournisseurs et vendeurs de cartes se sont efforcés (ont fait l'effort?) de s'aligner sur la convention (pluriel?) de Google et/ou de fournir des fonctions de transformation vers ou à partir d'elle, pour faciliter/ aller dans le sens de la standardisation.

## Les tuiles vectorielles

Les tuiles vectorielles sont un format de données léger pour stocker des données vectorielles géospatiales telles que les points, les lignes et les polygones. Les tuiles vectorielles codifient de l'information géographique conformément à la spécification de tuiles vecteur de Mapbox. La spécification de Mapbox est un standard ouvert sous une licence Creative Commons Attribution 3.0 US.

Une tuile vectorielle (vector tiles) contient des données vectorielles géoréférencées (elle peut contenir de multiples couches), découpées en tuiles pour faciliter leur récupération. Elles sont l'équivalent des tuiles raster traditionnelles (WMTS, TMS) mais rendent des données vectorielles au lieu d'une image.

Chaque ensemble de tuiles vectorielles a son propre schéma. Un schéma est un nombre de couches, attributs, sélection d'éléments etc.

## Différences entre tuiles raster et tuiles vectorielles

| **Tuiles vectorielles**                                                                                           | **Tuiles raster**                              |
|-------------------------------------------------------------------------------------------------------------------|------------------------------------------------|
| Le style se définit côté client                                                                                   | Le style se définit côté serveur               |
| L'information n'a besoin d'être tuilée qu'une fois et l'on peut obtenir plusieurs cartes                          | Il faut tuiler l'information pour chaque carte |
| Overzoom se mantient comme résolution                                                                             | Overzoom perd en résolution (pixelé)           |
| Taille moindre (on recommande maximum 500kb)                                                                      | Plus faciles à consommer                       |
| Caché occupe beaucoup moins d'espace. Utilisable sur des dispositifs portables sans connection                    |                                                |
| Caché utilise beaucoup d'espace. L'utilisation sur des dispositifs portables requiert beaucoup d'espace de disque |                                                |
| Accès natif à l'information de l'objet (attributs et géométrie), ce qui permet un traitement très sophistiqué     |                                                |
| Se voient mieux sur des dispositifs de haute résolution                                                           |                                                |

## Comment créer des tuiles vectorielles

### Tippecanoe

[Tippecanoe][3] est l'outil qui permet de créer des tuiles vectorielles depuis de grandes (ou petites) collections de GeoJSON, Geobuf, or CSV...

L'objectif de Tippecanoe est de permettre de visualiser des données indépendamment de l'échelle à laquelle elles sont représentées, de sorte que l'on puisse apprécier la densité et la texture des données à n'importe quel niveau, qu'il s'agisse du monde entier (z=0) ou d'un seul immeuble (z=22), au lieu d'une vue simplifiée qui élimine des caractéristiques supposément sans importance, les regroupe ou les assemble. 

Quelques exemples:

* Si l'on utilise toutes les données d'OpenStreetMap et que l'on fait un zoom extérieur, le rendu devrait ressembler à "toutes les rues" et non à quelque chose qui ressemblerait à un atlas des routes nationales.

* Si l'on utilise comme données d'entrée toutes les bases d'immeubles de Los Angeles et que l'on fait un zoom extérieur suffisamment éloigné pour ne plus arriver à distinguer la plupart des immeubles individuels, on devrait tout de même encore pouvoir voir l'extension et la variété de chaque quartier, et pas uniquement les immeubles les plus imposants du centre.

La qualité des résultats obtenus avec Tippecanoe est ainsi bien supérieure à celle d'autres alternatives qui utilisent des algorithmes de simplification plus conventionnels. Et aussi surprenant que cela puisse paraitre, Tippecanoe est en outre plus rapide pour traiter les données.  

### Natural Earth

Natural Earth is a public domain map dataset available at 1:10m, 1:50m, and 1:110 million scales. Featuring tightly integrated vector and raster data, with Natural Earth you can make a variety of visually pleasing, well-crafted maps with cartography or GIS software.

```bash
# countries
curl -L https://www.naturalearthdata.com/http//www.naturalearthdata.com/download/110m/cultural/ne_110m_admin_0_countries.zip > countries.zip 
unzip countries.zip
ogr2ogr -f GeoJSON countries.geojson ne_110m_admin_0_countries.shp
tippecanoe -zg --coalesce-densest-as-needed --extend-zooms-if-still-dropping -o countries.mbtiles  countries.geojson
rm countries.zip ne_110m_admin_0_countries.* countries.geojson
```

### Arbres

Ce jeu de données concerne l’ensemble des arbres urbains référencés dans l’open data. Il n’existe à ce jour aucun référentiel national des arbres urbains et nous proposons ici un travail qui synthétise les contenus des nombreux fichiers de données locaux disponibles en open data sur data.gouv.fr ou sur des portails locaux.

Un arbre urbain n’est pas défini de manière stricte. La définition des arbres de ce dataset a été dépendante de la nature des sources qui ont été associées ici. Il s’agit systématiquement d’arbres dont la gestion appartient à une collectivité territoriale, principalement de communes ou d’EPCI. Certaines régions ont également mis en open data la position des arbres dont ils sont gestionnaires.

Les arbres gérés par des services publics sont de trois types :

* les arbres d’alignement le long des voiries. Ils constituent un grand nombre d’arbres recensés par les collectivités (du fait, sans doute, du caractère critique de leur entretien) ;
* les arbres remarquables. Des arbres aux caractéristiques suffisamment uniques (essence rare, âge, dimensions) pour qu’ils soient répertoriés et classés ;
* les arbres d’ornement de l’espace public.

Par ailleurs, nous nous sommes tenus de ne recenser que les données livrées dans un format ponctuel, c’est-à-dire où chaque arbre est représenté par un point. Il existe des bases de données qui font référence aux arbres à travers des lignes (notamment pour les arbres d’alignement) ou des polygones (pour les zones arborées).

``` bash
# arbres
curl -L https://static.data.gouv.fr/resources/arbres-en-open-data-en-france-par-nam-r/20190319-185255/20190318-referentiel-arbre-namr.geojson > arbres.geojson
tippecanoe -pC -pk -zg --drop-densest-as-needed --extend-zooms-if-still-dropping -o arbres.mbtiles arbres.geojson 
rm arbres.geojson
```

[1]: https://medium.com/nam-r/open-data-and-urban-trees-8574eb202ab3
[2]: https://tree-map.nycgovparks.org
[3]: https://github.com/mapbox/tippecanoe

###