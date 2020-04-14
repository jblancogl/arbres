# Download data
if [ ! -f arbres.csv ]; then
echo "download arbres: arbres.csv"
  curl -L -s https://www.data.gouv.fr/fr/datasets/r/aaaddd02-206f-4d60-a04c-9a201297a3da > arbres.csv
fi

# Install tippecanoe
command -v tippecanoe &> /dev/null
if [ $? -ne 0 ]; then
  git clone --depth=1 https://github.com/mapbox/tippecanoe.git
  cd tippecanoe
  make -j
  sudo make install
  cd .. && rm -rf tippecanoe
fi

# Create arbres
tippecanoe --output-to-directory tiles \
           --quiet \
           --force \
           --exclude-all \
           --maximum-zoom=g \
           --drop-densest-as-needed \
           --extend-zooms-if-still-dropping \
           arbres.csv