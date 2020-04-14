FROM node:alpine AS builder
LABEL maintainer="Javier Blanco <jblancogl@gmail.com>"

WORKDIR /app

# Install dependencies
RUN apk add --no-cache sudo git g++ make libgcc libstdc++ sqlite-libs \
 sqlite-dev zlib-dev bash curl \
 && git clone https://github.com/mapbox/tippecanoe.git tippecanoe \
 && cd tippecanoe \
 && make \
 && make install

# Download arbres.geojson
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