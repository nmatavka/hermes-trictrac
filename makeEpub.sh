#!/bin/sh

rm -rf src_epub
cp -r src src_epub
cd src_epub

# for file in ./*.md; do
#   sed -i 's/\.svg/.png/' $file
#   sed -i 's/!\[[^]]*\]/![]/g' $file # remove images legends (already in images)
# done
#
# for img in ./*.svg; do
#   echo "Converting $img"
#   convert $img "${img%.svg}.png"
#   rm $img
# done

pandoc -o traiteCompletdeTrictrac.epub metadata.yaml \
  index.md \
  avertissement.md \
  introduction.md \
  chapitre1.md \
  chapitre2.md \
  chapitre3.md \
  chapitre4.md \
  chapitre5.md \
  chapitre6.md \
  chapitre7.md \
  chapitre8.md \
  chapitre9.md \
  chapitre10.md \
  chapitre11.md \
  chapitre12.md \
  chapitre13.md \
  chapitre14.md \
  chapitre15.md \
  le-trictrac-compare.md \
  traite-du-jeu-de-backgammon.md
cd ..
cp src_epub/traiteCompletdeTrictrac.epub src/
rm -rf src_epub
echo "file ready in ./src/traiteCompletdeTrictrac.epub"
