#!/bin/sh

rm -rf src_epub
cp -r src src_epub
cd src_epub

for file in ./*.md 
do
  sed -i 's/\.svg/.png/' $file
  sed -i 's/!\[[^]]*\]/![]/g' $file # remove images legends (already in images)
done

for img in ./*.svg 
do
  echo "Converting $img"
  convert $img "${img%.svg}.png" 
  rm $img
done

pandoc -o coursCompletdeTrictrac.epub metadata.yaml \
  index.md \
  discoursPreliminaire.md \
  premierePartie.md \
  deuxiemePartie.md \
  troisiemePartie.md \
  quatriemePartie.md \
  appendix.md
cd ..
cp src_epub/coursCompletdeTrictrac.epub src/
rm -rf src_epub
echo "file ready in ./src/coursCompletdeTrictrac.epub"
