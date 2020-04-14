# Créer une image Docker avec la carte web statique

Tout ce que nous avons fait jusqu’ici a servi pour montrer notre dataset d’arbres 
dans un serveur web statique local mais, et si nous voulions le déployer 
dans d’autres machines ou aider d’autres personnes à le faire?

Pour cette tâche, nous allons utiliser Docker.

## Configuration de nginx

Nous allons maintenant utiliser `nginx` au lieu de `serve` comme serveur web statique. 
Avec `apache`, il s’agit probablement de l’un des serveurs les plus utilisés.

Nous devons créer une configuration propre à nginx pour lui indiquer qu’il doit 
envoyer l’en-tête `Content-Encoding: gzip` quand il envoie les fichiers **pbf**, 
comme on l’a vu avec `serve`. Pour cela, on crée un fichier dans le dossier nginx, 
qu’on nomme default.conf.

!!! Info
    Si vous avez cloné le projet depuis le dossier vous pouvez sauter cette étape 
    puisque vous aurez déjà ce fichier.


nginx/default.conf

```
server {
  listen       80;
  server_name  localhost;

  location / {
    root   /usr/share/nginx/html;
    index  index.html index.htm;
  }

  error_page   500 502 503 504  /50x.html;
  
  location = /50x.html {
    root   /usr/share/nginx/html;
  }

  gzip on;

  location ~* (.+\.(pbf))$ {
    root   /usr/share/nginx/html;
    add_header Content-Encoding gzip;
  }
}
```

Les lignes que nous avons ajoutées sont celles-ci : 

```
gzip on; <-- activer la compression

location ~* (.+\.(pbf))$ { <-- pour tous les fichiers pbf
  root   /usr/share/nginx/html; <--  qui se trouvent dans le dossier /usr/share/nginx/html
  add_header Content-Encoding gzip; <-- envoyer un dosier avec l'en-tête Content-Encoding gzip
}
```

## Dockerfile

Nous allons maintenant créer notre Dockerfile. Nous utilisons la puissance que 
nous donnent les [multi-stage builds][1] pour diviser notre image docker en deux étapes. 
En procédant ainsi, seule la dernière étape est utilisée dans l’image, ce qui 
permet que le résultat soit beaucoup plus propre et léger.

1. **Stage Build:** Créer les tuiles 
    * Utiliser comme image `node:alpine` et étiqueter la `stage` comme **builder**
    ```Docker
    FROM node:alpine AS builder
    ```
    
    * On installe toutes les dépendances dont on a besoin et on compile **Tippecanoe**
    ```Docker
    RUN apk add --no-cache sudo git g++ make libgcc libstdc++ sqlite-libs \
      sqlite-dev zlib-dev bash curl \
      && git clone https://github.com/mapbox/tippecanoe.git tippecanoe \
      && cd tippecanoe \
      && make \
      && make install
    ```
    
    * On télécharge le fichier **csv** de <http://www.data.fr>
    ```Docker
    RUN curl -L -s https://www.data.gouv.fr/fr/datasets/r/aaaddd02-206f-4d60-a04c-9a201297a3da > arbres.csv
    ```
    
    * On crée les tuiles avec Tippecanoe
    ```Docker
    RUN tippecanoe --output-to-directory tiles \
                   --quiet \
                   --force \
                   --exclude-all \
                   --maximum-zoom=g \
                   --drop-densest-as-needed \
                   --extend-zooms-if-still-dropping \
                   arbres.csv
    ```

2. **Stage Nginx:**  Créer un serveur web statique avec l’information de l’étape précédente.

    * Créer une image basée sur `nginx:alpine`
    ```Docker
    FROM nginx:alpine
    ```

    * Nettoyer le contenu par défaut du dossier de nginx.
    ```Docker
    RUN rm -rf /usr/share/nginx/html/*
    ```

    * Copier le dossier avec les tuiles de l’étape précédente dans le dossier de nginx
    ```Docker
    COPY --from=builder /app/tiles /usr/share/nginx/html/tiles
    ```

    * Ajouter notre fichier html pour pouvoir visualiser nos tuiles
    ```Docker
    ADD index.html /usr/share/nginx/html
    ```

    * Ajouter notre nouvelle configuration
    ```Docker
    ADD nginx/default.conf /etc/nginx/conf.d/default.conf
    ```

    * Exposer le port 80
    ```Docker
    EXPOSE 80
    ```

    * Et enfin, lancer notre serveur!
    ```Docker
    CMD ["nginx", "-g", "daemon off;"]
    ```



## Notre Dockerfile final

```Dockerfile
FROM node:alpine AS builder
LABEL maintainer="Javier Blanco <hi@javiblanco.dev>"

WORKDIR /app

# Install dependencies
RUN apk add --no-cache sudo git g++ make libgcc libstdc++ sqlite-libs \
 sqlite-dev zlib-dev bash curl \
 && git clone https://github.com/mapbox/tippecanoe.git tippecanoe \
 && cd tippecanoe \
 && make \
 && make install

# Download arbres.csv
RUN curl -L -s https://www.data.gouv.fr/fr/datasets/r/aaaddd02-206f-4d60-a04c-9a201297a3da > arbres.csv

# Generate tiles
RUN tippecanoe --output-to-directory tiles \
               --quiet \
               --force \
               --exclude-all \
               --maximum-zoom=g \
               --drop-densest-as-needed \
               --extend-zooms-if-still-dropping \
               arbres.csv

FROM nginx:alpine

RUN rm -rf /usr/share/nginx/html/*
COPY --from=builder /app/tiles /usr/share/nginx/html/tiles
ADD index.html /usr/share/nginx/html
ADD nginx/default.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

## Construire notre image

Nous pouvons maintenant construire notre image avec le commando suivant:

```sh
docker build -t jblancogl/arbres:latest .
```

!!! Info
    **-t** est une option, c’est le nom de l’étiquette que je lui ai donnée. D’autres options sont visibles  [ici][2].

Pour vérifier que tout a bien fonctionné, on exécute le commando suivant .

```sh
docker images | grep jblancogl/arbres
```

Le résultat obtenu devrait ressembler à ceci :

```sh
jblancogl/arbres           latest              cdaedf29956c        9 hours ago         33.8MB
```

## Démarrer notre image

Nous avons notre image, nous pouvons donc créer notre container avec elle:

```sh
docker run --publish 8855:80 --detach --name arbres-server jblancogl/arbres
```

Si nous allons maintenant à l’explorateur, nous devrions pouvoir voir notre carte ici -> <http://localhost:8855>

## Publier notre image dans hub.docker.com

```sh
docker push jblancogl/arbres:latest
```

## Récupérer notre image depuis n’importe quelle machine avec docker

```sh
docker pull jblancogl/arbres:latest
```

[1]: https://docs.docker.com/develop/develop-images/multistage-build
[2]: https://docs.docker.com/engine/reference/commandline/build
