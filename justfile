serve:
  mkdocs serve

view:
  firefox http://127.0.0.1:8000

diagrams:
	# ./postProcess.sh src/premierePartie.md
	# ./postProcess.sh src/deuxiemePartie.md
	# ./postProcess.sh src/troisiemePartie.md
	# ./postProcess.sh src/quatriemePartie.md

build:
  just diagrams
  mkdocs build

deploy:
  just build
  mkdocs gh-deploy

epub:
  sh makeEpub.sh
