# Résolutions des règles de Trictrac

Ce registre accompagne l’implémentation. Il ne remplace ni ne modifie les
sources historiques importées.

## Ouverture

- L’application emploie le lancer simultané d’un dé par joueur, avec relance
  en cas d’égalité; le vainqueur commence ensuite un coup ordinaire. Elle ne
  reproduit pas le *coup et dés*.
- Le *jan de rencontre* reste documenté et son détecteur historique est
  conservé, mais il est inactif dans les parties. Ce choix suit directement
  du mode d’ouverture numérique plutôt que d’une règle de compensation.
- Le *jan de six tables* vise les six flèches après le talon: positions
  normalisées `17..22`. Il dépend de la puissance du troisième coup, sans
  obliger le joueur à réaliser ce placement particulier.

## Pleins et remplissage

- Guiton, *Traité complet du Trictrac*, chapitres VI et IX, distingue le
  remplissage, le remplissage en passant, et la conservation. Le moteur les
  traite donc comme trois événements distincts.
- Lafosse, *Le Jeu de Trictrac rendu facile*, nos 345–352, décrit les deux
  demi-cases dans les ordres naturel et inverse. Une première demi-case seule
  ne suffit pas: le plein est acquis seulement lorsque, après cette première
  pose virtuelle fixée, la seconde et dernière est aussi légalement possible.
- Les moyens sont calculés en parcourant les coups légaux du moteur, puis en
  regroupant les réalisations équivalentes par dés et flèches de remplissage;
  l’identité matérielle de deux dames interchangeables ne compte jamais deux
  fois.

## Toccategli

- `multi-rules.md` conserve les descriptions allemandes, danoises et
  suédoises du jeu. Douze points ferment un trou, non la partie entière.
- Le trou vaut une fois lorsque le perdant a 7–11 points, deux fois avec
  4–6, trois fois avec 1–3, et quatre fois avec 0 (*march*). Le multiplicateur
  est versé au suivi supérieur des trous et enregistré sur l’événement qui
  ferme le trou.
