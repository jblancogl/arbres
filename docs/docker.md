# Créer une image Docker avec la carte web statique

Tout ce que nous avons fait jusqu’ici a servi pour montrer notre dataset d’arbres 
dans un serveur web statique local mais, et si nous voulions le déployer 
dans d’autres machines ou aider d’autres personnes à le faire?

Pour cette tâche, nous allons utiliser Docker.

## Configuration de nginx

Nous allons maintenant utiliser `nginx` au lieu de `serve` comme serveur web statique. 
Avec `apache`, il s’agit probablement de l’un des serveurs les plus utilisés de la 
planète.

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
gzip on; <-- activamos la compresión

location ~* (.+\.(pbf))$ { <-- para todos los archivos de tipo pbf
  root   /usr/share/nginx/html; <-- que se encuentren en la carpeta /usr/share/nginx/html
  add_header Content-Encoding gzip; <-- enviamos una cabecera Content-Encoding gzip
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
    
    * On créé les tuiles avec Tippecanoe
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

    * On créé une image basée sur `nginx:alpine`
    ```Docker
    FROM nginx:alpine
    ```

    * Limpiamos el contenido de la carpeta de nginx por defecto.
    ```Docker
    RUN rm -rf /usr/share/nginx/html/*
    ```

    * Copiamos la carpeta con las teselas del paso anterior en la carpeta de nginx
    ```Docker
    COPY --from=builder /app/tiles /usr/share/nginx/html/tiles
    ```

    * Añadimos nuestro archivo html para poder visualizar nuestras teselas
    ```Docker
    ADD index.html /usr/share/nginx/html
    ```

    * Añadimos nuestra nueva configuración
    ```Docker
    ADD nginx/default.conf /etc/nginx/conf.d/default.conf
    ```

    * Exponemos el puerto 80
    ```Docker
    EXPOSE 80
    ```

    * Finalmente lanzamos nuestro servidor !
    ```Docker
    CMD ["nginx", "-g", "daemon off;"]
    ```



## Nuestro Dockerfile final

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

## Construir nuestra imagen

Ahora construimos nuestra imagen con el siguiente comando:

```sh
docker build -t jblancogl/arbres:latest .
```

!!! Info
    **-t** es opcional, es el nombre a la etiqueta que le he dado. 
    Puedes ver más opciones [aquí][2].

Para verificar que todo ha ido bien ejecutamos el siguiente comando.

```sh
docker images | grep jblancogl/arbres
```

Como resultado debería darnos algo parecido a esto:

```sh
jblancogl/arbres           latest              cdaedf29956c        9 hours ago         33.8MB
```

## Iniciar nuestra image

Ya tenemos nuestra image, ya podemos crear nuestro contenedor con ella:

```sh
docker run --publish 8855:80 --detach --name arbres-server jblancogl/arbres
```

Ahora si vamos al explorador deberiamos de poder ver nuestro mapa aqui -> <http://localhost:8855>

## Publicar nuestra imagen en hub.docker.com

```sh
docker push jblancogl/arbres:latest
```

## Recuperar nuestra imagen desde cualquier máquina con docker

```sh
docker pull jblancogl/arbres:latest
```

[1]: https://docs.docker.com/develop/develop-images/multistage-build
[2]: https://docs.docker.com/engine/reference/commandline/build
