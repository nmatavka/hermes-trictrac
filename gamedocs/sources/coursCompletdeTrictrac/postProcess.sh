#!/usr/bin/env bash

# crée les fichier svg à partir de leur référence dans un document et les place dans le même répertoire que le document
# usage : postProcess.sh src/index.md
# avec index.md contenant par exemple : ![figure 2](diag-trictrac-figure_1-aW9-cW1-jW1-sW1.svg)
# ici la notation est :
# m n o p q r  || s t u v x y
# ------------ || -----------
# l k j i h g  || f e d c b a

prefix="diag-trictrac-"
regex="$prefix([a-z0-9_]+)-(([a-y]+[WB][0-9]+-?)+).svg" # letters notation
# regex="$prefix([a-z0-9_]+)-(([0-9]+[WB][0-9]+-?)+).svg" # numerical notation

# translate letter notation to numerical : 
# 24 23 22 21 20 19 || 18 17 16 15 14 13
# ----------------- || -----------------
# 1  2  3  4  5  6  || 7  8  9  10 11 12
translateNotation() {
  echo $1 | tr 'lkjihgfed' '123456789' | sed 's/c/10/g; s/b/11/g; s/a/12/g; s/y/13/g; s/x/14/g; s/v/15/g; s/u/16/g; s/t/17/g; s/s/18/g; s/r/19/g; s/q/20/g; s/p/21/g; s/o/22/g; s/n/23/g; s/m/24/g'
}

createDiags() {
  while read line; do
    if [[ $line =~ $regex ]]
    then
      name="${BASH_REMATCH[1]}"
      positionsIni="${BASH_REMATCH[2]}"
      positions=$(translateNotation $positionsIni)
      diagParams=$(echo "${positions}" | tr "-" " " | sed 's/W/:white:/g' | sed 's/B/:black:/g')
      ./diagramMaker.sh $name $diagParams > $DEST/$prefix$name-$positionsIni.svg
    fi
  done
}

FILE=$1
DEST=$(dirname $FILE)
cat $FILE | grep "diag-trictrac" | createDiags
