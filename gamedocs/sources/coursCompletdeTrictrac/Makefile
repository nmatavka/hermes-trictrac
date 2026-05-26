servedocs:
	mkdocs serve
viewdocs:
	firefox http://127.0.0.1:8000
diagrams:
	./postProcess.sh src/premierePartie.md
	./postProcess.sh src/deuxiemePartie.md
	./postProcess.sh src/troisiemePartie.md
	./postProcess.sh src/quatriemePartie.md
builddocs: diagrams
	mkdocs build
deploy: builddocs
	mkdocs gh-deploy
epub:
	sh makeEpub.sh
ocr:
	echo "nix develop"
	echo "source ./gcloud/bin/activate"
	echo "GOOGLE_APPLICATION_CREDENTIALS='./trictracbooks-be003810fedc.json' ./gcloud/bin/python ./gcloudVision.py"
