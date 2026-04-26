export const LANGUAGE_STORAGE_KEY = "hermes-trictrac:language";

export const LANGUAGE_OPTIONS = [
  { id: "en", label: "English" },
  { id: "de", label: "Deutsch" },
  { id: "fr", label: "Français" },
  { id: "sv", label: "Svenska" },
  { id: "da", label: "Dansk" }
];

const SUPPORTED = new Set(LANGUAGE_OPTIONS.map((option) => option.id));
const LANGUAGE_EVENT = "hermes-trictrac:language-change";

// Translator note: English is the ergonomic source UI, not a manual witness.
// For German, French, Swedish, and Danish, the multilingual manual is the
// terminology authority. Terms are translated, preserved, or paraphrased by
// manual usage and UI context: e.g. "trou" is "Loch/Löcher", "hål", and
// "hul/huller" in score/count contexts, while historical terms such as jan,
// bredouille, relevé, reprise, marqué, jeton, and honneurs may remain
// recognizable where the manual keeps them.
const STRINGS = {
  en: {
    appTitle: "HERMES Trictrac",
    language: "Language",
    yes: "Yes",
    no: "No",
    on: "On",
    off: "Off",
    show: "Show",
    hide: "Hide",
    none: "None",
    waiting: "Waiting",
    unknown: "unknown",
    someone: "Someone",
    color: {
      white: "White",
      black: "Black",
      unknown: "Unknown"
    },
    lobby: {
      title: "Start or Join a Table",
      lobbyName: "Lobby Name:",
      userName: "User Name:",
      chooseGame: "Choose a Game",
      moreGames: "More games",
      computerNote: "More games are not available for computer play yet.",
      opponent: "Opponent",
      playAgainst: "Play against",
      human: "Human",
      computer: "Computer",
      margot: "Margot",
      botNote:
        "Computer play uses BackgammonAI for English backgammon and the current Trictrac model for Trictrac classique, Trictrac à écrire, Trictrac combiné, Toc, and Toccategli.",
      enter: "Enter Lobby"
    },
    join: {
      joiningLabel: "Joining Table",
      joinFailed: "Join Failed",
      tryAgain: "Try Again",
      backToLobby: "Back to Lobby",
      connectingBot: "Connecting to table and warming the model. The first bot game can take around a minute.",
      connecting: "Connecting to table...",
      slowBot: "Still warming the model. The first bot connection can take a little while.",
      slow: "Still connecting to table...",
      seatReclaim: "Seat reclaim requested.",
      reclaimRetry: "If the seated browser does not click Remain Seated within about {seconds} {seconds, plural, one {second} other {seconds}}, you can click Try Again to reclaim the seat.",
      reclaiming: "Reconnecting to reclaim your seat...",
      unable: "Unable to Join Table",
      rejected: "The table rejected this join request.",
      hint: "Try a different lobby name, match the existing table's game type, or ask a seated player to make room.",
      timedOut: "Join Timed Out",
      botMayWarm: "The model opponent may still be warming up.",
      noResponse: "The table did not respond before the join timeout.",
      timeoutHint: "Try again in a moment. If this keeps happening, return to the lobby and create a fresh table.",
      reactMissing: "React app not loaded..."
    },
    chat: {
      title: "Chat",
      empty: "No messages yet.",
      you: "You",
      opponent: "Opponent",
      placeholder: "Send a message",
      send: "Send"
    },
    game: {
      tableGame: "Table Game",
      againstBot: "You are playing as {color} against {bot}.",
      againstHuman: "You are playing as {color}. Share this lobby name with your opponent to join the same table.",
      host: "Host",
      guest: "Guest",
      turn: "Turn {number}",
      currentPlayer: "Current player",
      toMove: "{player} to move",
      settingUp: "Table is setting up.",
      waitingOpponent: "Waiting for an opponent to join.",
      tavliAgreement: "Tavli target must be agreed before play starts.",
      margotAgreement: "Margot la fendue must be agreed before play starts.",
      optionsAgreement: "Match options need to be confirmed before play starts.",
      decisionRequired: "{player} must resolve a turn decision.",
      wonBy: "{winner} won by {kind}.",
      wonByPoints: "{winner} won by {points}.",
      drawnSettlement: "Drawn settlement",
      currentLeg: "Current leg: {leg}",
      seat: "Seat",
      youAre: "You are {color}",
      seatWarning: "Seat Warning",
      seatWanted: "Another browser wants this seat.",
      reclaimingSeat: "{name} is trying to reclaim this table seat.",
      remainWithin: "Click Remain Seated within about {seconds} {seconds, plural, one {second} other {seconds}} to keep playing from this browser.",
      remainSeated: "Remain Seated",
      dice: "Dice",
      noDice: "No dice rolled yet.",
      dieAlt: "Die {value}",
      openingDieAlt: "{color} opening die {value}",
      movesLeft: "Moves left: {moves}",
      noMovesLeft: "none",
      awaitingRoll: "Awaiting next roll.",
      openingRoll: "Opening Roll",
      rollToStart: "Roll to decide who starts.",
      actions: "Actions",
      roll: "Roll",
      passDice: "Pass Dice",
      undo: "Undo",
      confirm: "Confirm",
      newMatch: "New Match",
      endTurn: "End Turn",
      resign: "Resign",
      resignConfirm: "Resign the match?",
      impuissance: "Dame impuissante: {points} {points, plural, one {point} other {points}} to {color}.",
      passDiceHint: "No legal moves are available; pass the dice to your opponent.",
      matchOptions: "Match Options",
      startMatch: "Start Match",
      pregame: "Pregame",
      choosePregame: "Choose the pregame option.",
      yourChoice: "Your choice",
      colorChoice: "{color} choice",
      selectedTarget: "Selected target: {target}",
      chooseTarget: "Choose {target}",
      decision: "Decision",
      decisionKey: "Decision key: {key}",
      trictracTrack: "Trictrac Track",
      match: "Match",
      target: "Target",
      opponentBar: "Opponent Bar",
      yourBar: "Your Bar",
      bearOff: "Bear Off",
      actionFailed: "Action failed.",
      soundUnavailable: "Sound Unavailable",
      soundOn: "Sound On",
      soundOff: "Sound Off",
      soundUnavailableTitle: "Sound is unavailable in this browser",
      soundOffTitle: "Turn generated sound cues off",
      soundOffLockedTitle: "Turn generated sound cues off. Audio will resume on your next click or key press.",
      soundOnTitle: "Turn generated sound cues on",
      pack: "Pack",
      packTitle: "Choose a sound pack"
    },
    units: {
      point: "{count} {count, plural, one {point} other {points}}",
      hole: "{count} {count, plural, one {hole} other {holes}}",
      game: "{count} {count, plural, one {game} other {games}}",
      marque: "{count} marqués",
      trou: "{count} {count, plural, one {trou} other {trous}}",
      jeton: "{count} {count, plural, one {jeton} other {jetons}}",
      honneur: "{count} honneurs"
    },
    score: {
      wins: "{color} wins {points} {points, plural, one {point} other {points}}",
      event: "score event"
    },
    decision: {
      reprise: "Choose whether to continue the game or take a reprise.",
      suspension: "Choose which track to suspend.",
      suspendOneTrack: "Suspend one track?",
      continueMarque: "Choose how to continue the marqué.",
      none: "None",
      tenir: "Tenir",
      "s'en aller": "S'en aller",
      suspend_classique: "Suspend honneurs",
      suspend_a_ecrire: "Suspend à écrire"
    },
    options: {
      pointsToPlay: "Points to play",
      marquesToPlay: "Marqués to play",
      holesToPlay: "Holes to play",
      matchLength: "Match length",
      doublesMode: "Doubles mode",
      margot: "Margot la fendue",
      enableMargot: "Enable Margot",
      targetHoles: "Target holes",
      doubleScoring: "Double Scoring",
      doublesOn: "Doubles On",
      doublesOff: "Doubles Off",
      bestOf: "Best Of",
      bestOfN: "Best-of {count}",
      tavliPrompt: "Choose the Tavli target. If you disagree, the match defaults to 7.",
      margotPrompt: "Play with Margot la fendue?",
      partieLengthPrompt: "Choose the marqué target."
    },
    detail: {
      bredouille: "Bredouille",
      grandeBredouille: "Grande bredouille",
      currentCoup: "Current coup",
      consolation: "Consolation",
      lastMarque: "Last marqué",
      lastHonneurs: "Last honneurs",
      honneursState: "Honneurs state",
      suspension: "Suspension",
      whiteSettlement: "White settlement",
      blackSettlement: "Black settlement",
      result: "Result",
      whiteAEcrire: "White à écrire",
      blackAEcrire: "Black à écrire",
      whiteHonneurs: "White honneurs",
      blackHonneurs: "Black honneurs",
      queueJetons: "Queue des jetons {value}",
      marques: "Marqués {value}",
      queueMarques: "Queue des marqués {value}",
      final: "Final {value}",
      noMarque: "No marqué settled yet.",
      refait: "Refait",
      nextConsolation: "Next consolation {value}",
      trouAgainst: "{winner} trous against {loser}",
      voluntaryLoss: "Voluntary loss",
      simpleMarque: "Simple marqué",
      gainExact: "Gain exact {value}",
      gainArrondi: "Gain arrondi {value}",
      noHonneurs: "No honneurs partie settled yet.",
      wonClass: "{color} won {klass}",
      noCarry: "No carry",
      carried: "{count} {count, plural, one {trou} other {trous}} carried",
      currentPartieWhite: "White current partie: {value}",
      currentPartieBlack: "Black current partie: {value}",
      honneursNear: "Honneurs near settlement",
      honneursProgress: "Honneurs in progress",
      suspended: "{track} suspended",
      frozenBy: "Frozen by {color}",
      resumesOnReleve: "Resumes on relevé",
      beforeQueues: "{value} before queues",
      finalValue: "{value} final",
      nextJetons: "{value} jetons next",
      noRefait: "No refait",
      refaitCount: "{count} {count, plural, one {refait} other {refaits}}",
      partieTrous: "{count} partie trous",
      marquesProgress: "{count}/{total} marqués",
      colorTrous: "{color}: {holes}",
      pointsAndTrous: "{points} / {holes}",
      compactClasses: "S/D/T/Q {value}"
    },
    matchResult: {
      gameDraw: "Game {number}: {kind}{award}",
      gameWin: "Game {number}: {leg}{winner} won{award} by {kind}"
    },
    errors: {
      unknown: "Unknown error.",
      unauthorized: "Unauthorized.",
      lobby_full: "Lobby is full.",
      player_not_found: "Player not found in lobby.",
      match_over: "Match is already over.",
      not_your_turn: "Not your turn.",
      invalid_move: "Invalid move.",
      no_rolled_dice: "No rolled dice to confirm.",
      turn_obligations: "Turn obligations not fulfilled.",
      coin_rest: "Coin de repos must end the turn with 0 or at least 2 checkers.",
      only_host_options: "Only the host can submit match options.",
      variant_mismatch: "This lobby is already using another game.",
      reset_unavailable: "Reset is only available after the match is over.",
      seat_reclaim_pending: "Seat reclaim requested.",
      bot_unavailable: "The selected bot is unavailable.",
      action_failed: "Action failed."
    }
  }
};

const LOCALE_OVERRIDES = {
  de: {
    language: "Sprache",
    yes: "Ja",
    no: "Nein",
    on: "Ein",
    off: "Aus",
    show: "Zeigen",
    hide: "Verbergen",
    none: "Keine",
    waiting: "Warten",
    unknown: "unbekannt",
    someone: "Jemand",
    color: { white: "Weiß", black: "Schwarz", unknown: "Unbekannt" },
    lobby: {
      title: "Tisch eröffnen oder beitreten",
      lobbyName: "Tischname:",
      userName: "Name:",
      chooseGame: "Spiel wählen",
      moreGames: "Weitere Spiele",
      computerNote: "Weitere Spiele sind gegen den Computer noch nicht verfügbar.",
      opponent: "Gegner",
      playAgainst: "Spielen gegen",
      human: "Person",
      computer: "Computer",
      margot: "Margot",
      botNote: "Partien gegen den Computer nutzen BackgammonAI für englisches Backgammon und das aktuelle Trictrac-Modell für Trictrac classique, Trictrac zum Aufschreiben, Kombiniertes Trictrac, Toc und Toccategli.",
      enter: "Zum Tisch"
    },
    join: {
      joiningLabel: "Tisch beitreten",
      joinFailed: "Beitritt fehlgeschlagen",
      tryAgain: "Noch einmal",
      backToLobby: "Zurück zur Lobby",
      connectingBot: "Verbindung zum Tisch wird hergestellt; das Modell wird vorbereitet. Die erste Partie gegen den Bot kann etwa eine Minute dauern.",
      connecting: "Verbindung zum Tisch...",
      slowBot: "Das Modell wird noch vorbereitet. Die erste Verbindung zum Bot kann etwas dauern.",
      slow: "Verbindung zum Tisch läuft noch...",
      seatReclaim: "Sitzrückforderung angefordert.",
      reclaimRetry: "Wenn der belegte Browser nicht innerhalb von etwa {seconds} {seconds, plural, one {Sekunde} other {Sekunden}} auf Sitz behalten klickt, können Sie mit Noch einmal den Sitz übernehmen.",
      reclaiming: "Sitz wird zurückgeholt...",
      unable: "Tischbeitritt nicht möglich",
      rejected: "Der Tisch hat diese Anfrage abgelehnt.",
      hint: "Wählen Sie einen anderen Tischnamen, dieselbe Spielart wie am bestehenden Tisch, oder bitten Sie einen sitzenden Spieler, Platz zu machen.",
      timedOut: "Beitritt abgelaufen",
      botMayWarm: "Der Modellgegner wird möglicherweise noch vorbereitet.",
      noResponse: "Der Tisch hat nicht rechtzeitig geantwortet.",
      timeoutHint: "Versuchen Sie es gleich noch einmal. Wenn es weiter geschieht, kehren Sie zur Lobby zurück und erstellen Sie einen frischen Tisch.",
      reactMissing: "React-App nicht geladen..."
    },
    chat: { title: "Chat", empty: "Noch keine Nachrichten.", you: "Sie", opponent: "Gegner", placeholder: "Nachricht senden", send: "Senden" },
    game: {
      tableGame: "Spiel am Tisch",
      againstBot: "Sie spielen als {color} gegen {bot}.",
      againstHuman: "Sie spielen als {color}. Teilen Sie diesen Tischnamen mit Ihrem Gegner.",
      host: "Gastgeber",
      guest: "Gast",
      turn: "Zug {number}",
      currentPlayer: "Aktueller Spieler",
      toMove: "{player} am Zug",
      settingUp: "Der Tisch wird vorbereitet.",
      waitingOpponent: "Warten auf einen Gegner.",
      tavliAgreement: "Das Tavli-Ziel muss vor Spielbeginn vereinbart werden.",
      margotAgreement: "Margot la fendue muss vor Spielbeginn vereinbart werden.",
      optionsAgreement: "Die Matchoptionen müssen vor Spielbeginn bestätigt werden.",
      decisionRequired: "{player} muss eine Zugentscheidung treffen.",
      wonBy: "{winner} gewann durch {kind}.",
      wonByPoints: "{winner} gewann mit {points} Vorsprung.",
      drawnSettlement: "Ausgeglichene Abrechnung",
      currentLeg: "Aktuelle Partie: {leg}",
      seat: "Sitz",
      youAre: "Sie sind {color}",
      seatWarning: "Sitzwarnung",
      seatWanted: "Ein anderer Browser möchte diesen Platz einnehmen.",
      reclaimingSeat: "{name} versucht, diesen Platz am Tisch zurückzuholen.",
      remainWithin: "Klicken Sie innerhalb von etwa {seconds} {seconds, plural, one {Sekunde} other {Sekunden}} auf Sitz behalten, um von diesem Browser weiterzuspielen.",
      remainSeated: "Sitz behalten",
      dice: "Würfel",
      noDice: "Noch keine Würfel.",
      dieAlt: "Würfel {value}",
      openingDieAlt: "{color}: Eröffnungswürfel {value}",
      movesLeft: "Züge verbleibend: {moves}",
      noMovesLeft: "keine",
      awaitingRoll: "Warten auf den nächsten Wurf.",
      openingRoll: "Eröffnungswurf",
      rollToStart: "Würfeln Sie, um den Startspieler zu bestimmen.",
      actions: "Aktionen",
      roll: "Würfeln",
      passDice: "Würfel abgeben",
      undo: "Rückgängig",
      confirm: "Bestätigen",
      newMatch: "Neues Match",
      endTurn: "Zug beenden",
      resign: "Aufgeben",
      resignConfirm: "Match aufgeben?",
      impuissance: "Dame impuissante: {points} {points, plural, one {Punkt} other {Punkte}} an {color}.",
      passDiceHint: "Keine legalen Züge verfügbar; geben Sie die Würfel ab.",
      matchOptions: "Matchoptionen",
      startMatch: "Match starten",
      pregame: "Vor Spielbeginn",
      choosePregame: "Wählen Sie die Option vor Spielbeginn.",
      yourChoice: "Ihre Wahl",
      colorChoice: "Wahl von {color}",
      selectedTarget: "Gewähltes Ziel: {target}",
      chooseTarget: "Ziel {target} wählen",
      decision: "Entscheidung",
      decisionKey: "Entscheidungsschlüssel: {key}",
      trictracTrack: "Trictrac-Leiste",
      match: "Match",
      target: "Ziel",
      opponentBar: "Gegnerische Bar",
      yourBar: "Ihre Bar",
      bearOff: "Aus",
      actionFailed: "Aktion fehlgeschlagen.",
      soundUnavailable: "Ton nicht verfügbar",
      soundOn: "Ton an",
      soundOff: "Ton aus",
      soundUnavailableTitle: "Ton ist in diesem Browser nicht verfügbar",
      soundOffTitle: "Töne ausschalten",
      soundOffLockedTitle: "Töne ausschalten. Audio wird beim nächsten Klick oder Tastendruck fortgesetzt.",
      soundOnTitle: "Töne einschalten",
      pack: "Paket",
      packTitle: "Soundpaket wählen"
    },
    options: {
      pointsToPlay: "Zielpunkte",
      marquesToPlay: "Marqué-Ziel",
      holesToPlay: "Löcher-Ziel",
      matchLength: "Matchlänge",
      doublesMode: "Doublettenwertung",
      enableMargot: "Margot aktivieren",
      targetHoles: "Ziellöcher",
      doubleScoring: "Doppelte Wertung",
      doublesOn: "Doubletten an",
      doublesOff: "Doubletten aus",
      bestOf: "Best-of",
      bestOfN: "Best of {count}",
      tavliPrompt: "Wählen Sie das Tavli-Ziel. Bei Uneinigkeit gilt 7.",
      margotPrompt: "Mit Margot la fendue spielen?",
      partieLengthPrompt: "Wählen Sie das Marqué-Ziel."
    },
    units: {
      point: "{count} {count, plural, one {Punkt} other {Punkte}}",
      hole: "{count} {count, plural, one {Loch} other {Löcher}}",
      game: "{count} {count, plural, one {Spiel} other {Spiele}}",
      marque: "{count} marqués",
      trou: "{count} {count, plural, one {Loch} other {Löcher}}",
      jeton: "{count} {count, plural, one {jeton} other {jetons}}",
      honneur: "{count} honneurs"
    },
    score: {
      wins: "{color} gewinnt {points} {points, plural, one {Punkt} other {Punkte}}",
      event: "Wertungsereignis"
    },
    decision: {
      reprise: "Wählen Sie, ob das Spiel fortgesetzt oder eine reprise genommen wird.",
      suspension: "Wählen Sie, welche Leiste ausgesetzt wird.",
      suspendOneTrack: "Eine Leiste aussetzen?",
      continueMarque: "Wählen Sie, wie der marqué fortgesetzt wird.",
      none: "Keine",
      tenir: "Stehen bleiben",
      "s'en aller": "Spiel heben",
      suspend_classique: "Honneurs aussetzen",
      suspend_a_ecrire: "À écrire aussetzen"
    },
    detail: {
      currentCoup: "Aktueller coup",
      consolation: "Consolation",
      lastMarque: "Letzter marqué",
      lastHonneurs: "Letzte honneurs",
      honneursState: "Honneurs-Stand",
      suspension: "Suspension",
      whiteSettlement: "Abrechnung Weiß",
      blackSettlement: "Abrechnung Schwarz",
      result: "Ergebnis",
      whiteAEcrire: "Weiß à écrire",
      blackAEcrire: "Schwarz à écrire",
      whiteHonneurs: "Weiß honneurs",
      blackHonneurs: "Schwarz honneurs",
      final: "Endstand {value}",
      noMarque: "Noch kein marqué abgerechnet.",
      nextConsolation: "Nächste consolation {value}",
      trouAgainst: "{winner} Löcher gegen {loser}",
      voluntaryLoss: "Freiwillige Niederlage",
      simpleMarque: "Einfacher marqué",
      gainExact: "Exakter Gewinn {value}",
      gainArrondi: "Gerundeter Gewinn {value}",
      noHonneurs: "Noch keine honneurs-Partie abgerechnet.",
      wonClass: "{color} gewann {klass}",
      noCarry: "Keine Übertragung",
      carried: "{count} {count, plural, one {Loch} other {Löcher}} übertragen",
      currentPartieWhite: "Aktuelle Partie Weiß: {value}",
      currentPartieBlack: "Aktuelle Partie Schwarz: {value}",
      honneursNear: "Honneurs kurz vor der Abrechnung",
      honneursProgress: "Honneurs läuft",
      suspended: "{track} ausgesetzt",
      frozenBy: "Gesperrt durch {color}",
      resumesOnReleve: "Wird bei relevé fortgesetzt",
      beforeQueues: "{value} vor den queues",
      finalValue: "{value} Endstand",
      nextJetons: "{value} jetons als Nächstes",
      noRefait: "Kein refait",
      refaitCount: "{count} {count, plural, one {refait} other {refaits}}",
      partieTrous: "Partie-Löcher: {count}",
      marquesProgress: "{count}/{total} marqués",
      colorTrous: "{color}: {holes}",
      pointsAndTrous: "{points} / {holes}",
      compactClasses: "S/D/T/Q {value}"
    },
    matchResult: {
      gameDraw: "Partie {number}: {kind}{award}",
      gameWin: "Partie {number}: {leg}{winner} gewann{award} durch {kind}"
    },
    errors: {
      unknown: "Unbekannter Fehler.",
      unauthorized: "Nicht autorisiert.",
      lobby_full: "Die Lobby ist voll.",
      player_not_found: "Spieler nicht in der Lobby gefunden.",
      match_over: "Das Match ist bereits beendet.",
      not_your_turn: "Sie sind nicht am Zug.",
      invalid_move: "Ungültiger Zug.",
      no_rolled_dice: "Kein Wurf zum Bestätigen.",
      turn_obligations: "Zugpflichten nicht erfüllt.",
      coin_rest: "Coin de repos muss den Zug mit 0 oder mindestens 2 Steinen beenden.",
      only_host_options: "Nur der Gastgeber kann Matchoptionen senden.",
      variant_mismatch: "Diese Lobby nutzt bereits ein anderes Spiel.",
      reset_unavailable: "Zurücksetzen ist erst nach Matchende verfügbar.",
      seat_reclaim_pending: "Sitzrückforderung angefordert.",
      bot_unavailable: "Der gewählte Bot ist nicht verfügbar.",
      action_failed: "Aktion fehlgeschlagen."
    }
  },
  fr: {
    language: "Langue",
    yes: "Oui",
    no: "Non",
    on: "Activé",
    off: "Désactivé",
    show: "Afficher",
    hide: "Masquer",
    none: "Aucun",
    waiting: "En attente",
    unknown: "inconnu",
    someone: "Quelqu’un",
    color: { white: "Blancs", black: "Noirs", unknown: "Inconnu" },
    colorSubject: { white: "Les Blancs", black: "Les Noirs", unknown: "Inconnu" },
    lobby: {
      title: "Créer ou rejoindre une table",
      lobbyName: "Nom de la table :",
      userName: "Nom du joueur :",
      chooseGame: "Choisir un jeu",
      moreGames: "Autres jeux",
      computerNote: "Les autres jeux ne sont pas encore disponibles contre l’ordinateur.",
      opponent: "Adversaire",
      playAgainst: "Jouer contre",
      human: "Humain",
      computer: "Ordinateur",
      margot: "Margot",
      botNote: "Le jeu contre l’ordinateur utilise BackgammonAI pour le backgammon anglais et le modèle Trictrac actuel pour Trictrac classique, Trictrac à écrire, Trictrac combiné, Toc et Toccategli.",
      enter: "Entrer à la table"
    },
    join: {
      joiningLabel: "Connexion à la table",
      joinFailed: "Connexion échouée",
      tryAgain: "Réessayer",
      backToLobby: "Retour à la table d’accueil",
      connectingBot: "Connexion à la table et préparation du modèle. La première partie contre le bot peut prendre environ une minute.",
      connecting: "Connexion à la table...",
      slowBot: "Le modèle se prépare encore. La première connexion au bot peut prendre un peu de temps.",
      slow: "Connexion à la table toujours en cours...",
      seatReclaim: "Réclamation de siège demandée.",
      reclaimRetry: "Si le navigateur déjà assis ne clique pas sur Rester assis dans environ {seconds} {seconds, plural, one {seconde} other {secondes}}, vous pourrez cliquer sur Réessayer pour reprendre le siège.",
      reclaiming: "Reconnexion pour reprendre le siège...",
      unable: "Impossible de rejoindre la table",
      rejected: "La table a refusé cette demande.",
      hint: "Essayez un autre nom de table, choisissez le même jeu que la table existante, ou demandez à un joueur assis de libérer une place.",
      timedOut: "Connexion expirée",
      botMayWarm: "L’adversaire modèle est peut-être encore en préparation.",
      noResponse: "La table n’a pas répondu avant l’expiration du délai.",
      timeoutHint: "Réessayez dans un instant. Si cela continue, revenez au lobby et créez une nouvelle table.",
      reactMissing: "Application React non chargée..."
    },
    chat: { title: "Chat", empty: "Aucun message.", you: "Vous", opponent: "Adversaire", placeholder: "Envoyer un message", send: "Envoyer" },
    game: {
      tableGame: "Jeu à la table",
      againstBot: "Vous jouez les {color} contre {bot}.",
      againstHuman: "Vous jouez les {color}. Partagez ce nom de table avec votre adversaire.",
      host: "Hôte",
      guest: "Invité",
      turn: "Tour {number}",
      currentPlayer: "Joueur actuel",
      toMove: "À {player} de jouer",
      settingUp: "La table se prépare.",
      waitingOpponent: "En attente d’un adversaire.",
      tavliAgreement: "La cible du Tavli doit être convenue avant de jouer.",
      margotAgreement: "Margot la fendue doit être convenue avant de jouer.",
      optionsAgreement: "Les options du match doivent être confirmées avant de jouer.",
      decisionRequired: "{player} doit prendre une décision de tour.",
      wonBy: "{winner} ont gagné par {kind}.",
      wonByPoints: "{winner} ont gagné par {points}.",
      drawnSettlement: "Décompte à égalité",
      currentLeg: "Manche actuelle : {leg}",
      seat: "Siège",
      youAre: "Vous êtes {color}",
      seatWarning: "Avertissement de siège",
      seatWanted: "Un autre navigateur veut reprendre ce siège.",
      reclaimingSeat: "{name} tente de reprendre ce siège.",
      remainWithin: "Cliquez sur Rester assis dans environ {seconds} {seconds, plural, one {seconde} other {secondes}} pour continuer depuis ce navigateur.",
      remainSeated: "Rester assis",
      dice: "Dés",
      noDice: "Aucun dé lancé.",
      dieAlt: "Dé {value}",
      openingDieAlt: "Dé d’ouverture {color} {value}",
      movesLeft: "Coups restants : {moves}",
      noMovesLeft: "aucun",
      awaitingRoll: "En attente du prochain lancer.",
      openingRoll: "Lancer d’ouverture",
      rollToStart: "Lancez pour décider qui commence.",
      actions: "Actions",
      roll: "Lancer",
      passDice: "Passer les dés",
      undo: "Annuler",
      confirm: "Confirmer",
      newMatch: "Nouveau match",
      endTurn: "Terminer le tour",
      resign: "Abandonner",
      resignConfirm: "Abandonner le match ?",
      impuissance: "Dame impuissante : {points} {points, plural, one {point} other {points}} à {color}.",
      passDiceHint: "Aucun coup légal n’est disponible ; passez les dés à votre adversaire.",
      matchOptions: "Options du match",
      startMatch: "Démarrer le match",
      pregame: "Avant-jeu",
      choosePregame: "Choisissez l’option d’avant-partie.",
      yourChoice: "Votre choix",
      colorChoice: "Choix des {color}",
      selectedTarget: "Cible choisie : {target}",
      chooseTarget: "Choisir {target}",
      decision: "Décision",
      decisionKey: "Clé de décision : {key}",
      trictracTrack: "Piste de trictrac",
      match: "Match",
      target: "Cible",
      opponentBar: "Barre adverse",
      yourBar: "Votre barre",
      bearOff: "Sortir",
      actionFailed: "Action échouée.",
      soundUnavailable: "Son indisponible",
      soundOn: "Son activé",
      soundOff: "Son coupé",
      soundUnavailableTitle: "Le son n’est pas disponible dans ce navigateur",
      soundOffTitle: "Couper les sons",
      soundOffLockedTitle: "Couper les sons. L’audio reprendra au prochain clic ou appui.",
      soundOnTitle: "Activer les sons",
      pack: "Pack sonore",
      packTitle: "Choisir un pack sonore"
    },
    options: {
      pointsToPlay: "Objectif en points",
      marquesToPlay: "Objectif en marqués",
      holesToPlay: "Objectif en trous",
      matchLength: "Longueur du match",
      doublesMode: "Mode doublets",
      enableMargot: "Activer Margot",
      targetHoles: "Trous visés",
      doubleScoring: "Décompte double",
      doublesOn: "Doublets activés",
      doublesOff: "Doublets désactivés",
      bestOf: "Au meilleur de",
      bestOfN: "Au meilleur de {count}",
      tavliPrompt: "Choisissez la cible du Tavli. En cas de désaccord, le match vaut 7.",
      margotPrompt: "Jouer avec Margot la fendue ?",
      partieLengthPrompt: "Choisissez l’objectif en marqués."
    },
    units: {
      point: "{count} {count, plural, one {point} other {points}}",
      hole: "{count} {count, plural, one {trou} other {trous}}",
      game: "{count} {count, plural, one {partie} other {parties}}",
      marque: "{count} marqués",
      trou: "{count} {count, plural, one {trou} other {trous}}",
      jeton: "{count} {count, plural, one {jeton} other {jetons}}",
      honneur: "{count} honneurs"
    },
      score: {
      wins: "Les {color} marquent {points} {points, plural, one {point} other {points}}",
      event: "événement de score"
    },
    decision: {
      reprise: "Choisissez de continuer le jeu ou de prendre une reprise.",
      suspension: "Choisissez quelle piste suspendre.",
      suspendOneTrack: "Suspendre une piste ?",
      continueMarque: "Choisissez comment continuer le marqué.",
      none: "Aucun",
      tenir: "Tenir",
      "s'en aller": "S’en aller",
      suspend_classique: "Suspendre les honneurs",
      suspend_a_ecrire: "Suspendre l’à écrire"
    },
    detail: {
      currentCoup: "Coup actuel",
      consolation: "Consolation",
      lastMarque: "Dernier marqué",
      lastHonneurs: "Derniers honneurs",
      honneursState: "État des honneurs",
      suspension: "Suspension",
      whiteSettlement: "Décompte des Blancs",
      blackSettlement: "Décompte des Noirs",
      result: "Résultat",
      whiteAEcrire: "Blancs à écrire",
      blackAEcrire: "Noirs à écrire",
      whiteHonneurs: "Honneurs blancs",
      blackHonneurs: "Honneurs noirs",
      final: "Total final {value}",
      noMarque: "Aucun marqué décompté.",
      nextConsolation: "Prochaine consolation {value}",
      trouAgainst: "{winner} trous contre {loser}",
      voluntaryLoss: "Défaite volontaire",
      simpleMarque: "Marqué simple",
      noHonneurs: "Aucune partie d’honneurs décomptée.",
      wonClass: "Les {color} gagnent {klass}",
      noCarry: "Aucun report",
      carried: "{count} {count, plural, one {trou reporté} other {trous reportés}}",
      currentPartieWhite: "Partie actuelle des Blancs : {value}",
      currentPartieBlack: "Partie actuelle des Noirs : {value}",
      honneursNear: "Honneurs près du décompte",
      honneursProgress: "Honneurs en cours",
      suspended: "{track} suspendu",
      frozenBy: "Bloqué par {color}",
      resumesOnReleve: "Reprend au relevé",
      beforeQueues: "{value} avant les queues",
      finalValue: "{value} au final",
      nextJetons: "{value} jetons ensuite",
      noRefait: "Pas de refait",
      refaitCount: "{count} {count, plural, one {refait} other {refaits}}",
      partieTrous: "{count} trous de partie",
      marquesProgress: "{count}/{total} marqués",
      colorTrous: "{color} : {holes}",
      pointsAndTrous: "{points} / {holes}",
      compactClasses: "S/D/T/Q {value}"
    },
    matchResult: {
      gameDraw: "Partie {number} : {kind}{award}",
      gameWin: "Partie {number} : {leg}{winner} ont gagné{award} par {kind}"
    },
    errors: {
      unknown: "Erreur inconnue.",
      unauthorized: "Non autorisé.",
      lobby_full: "La table est pleine.",
      player_not_found: "Joueur introuvable dans le lobby.",
      match_over: "Le match est déjà terminé.",
      not_your_turn: "Ce n’est pas votre tour.",
      invalid_move: "Coup invalide.",
      no_rolled_dice: "Aucun dé lancé à confirmer.",
      turn_obligations: "Obligations du tour non remplies.",
      coin_rest: "Le coin de repos doit finir le tour avec 0 ou au moins 2 dames.",
      only_host_options: "Seul l’hôte peut envoyer les options du match.",
      variant_mismatch: "Ce lobby utilise déjà un autre jeu.",
      reset_unavailable: "La remise à zéro n’est disponible qu’après la fin du match.",
      seat_reclaim_pending: "Réclamation de siège demandée.",
      bot_unavailable: "Le bot choisi n’est pas disponible.",
      action_failed: "Action échouée."
    }
  },
  sv: {
    language: "Språk",
    yes: "Ja",
    no: "Nej",
    on: "På",
    off: "Av",
    show: "Visa",
    hide: "Dölj",
    none: "Ingen",
    waiting: "Väntar",
    unknown: "okänd",
    someone: "Någon",
    color: { white: "Vit", black: "Svart", unknown: "Okänd" },
    lobby: {
      title: "Starta eller anslut till ett bord",
      lobbyName: "Bordsnamn:",
      userName: "Spelarnamn:",
      chooseGame: "Välj spel",
      moreGames: "Fler spel",
      computerNote: "Fler spel är ännu inte tillgängliga mot datorn.",
      opponent: "Motståndare",
      playAgainst: "Spela mot",
      human: "Person",
      computer: "Dator",
      margot: "Margot",
      botNote: "Spel mot datorn använder BackgammonAI för engelskt backgammon och den aktuella Trictrac-modellen för Trictrac classique, Trictrac att skriva, Kombinerad Trictrac, Toc och Toccategli.",
      enter: "Till bordet"
    },
    join: {
      joiningLabel: "Ansluter till bord",
      joinFailed: "Anslutning misslyckades",
      tryAgain: "Försök igen",
      backToLobby: "Tillbaka till lobbyn",
      connectingBot: "Ansluter till bordet och värmer upp modellen. Det första botpartiet kan ta omkring en minut.",
      connecting: "Ansluter till bordet...",
      slowBot: "Modellen värms fortfarande upp. Den första botanslutningen kan ta lite tid.",
      slow: "Ansluter fortfarande till bordet...",
      seatReclaim: "Återtagning av plats begärd.",
      reclaimRetry: "Om den webbläsare som redan sitter inte klickar på Behåll platsen inom cirka {seconds} {seconds, plural, one {sekund} other {sekunder}}, kan du klicka på Försök igen för att återta platsen.",
      reclaiming: "Ansluter igen för att återta platsen...",
      unable: "Kunde inte gå med i bordet",
      rejected: "Bordet avvisade anslutningen.",
      hint: "Prova ett annat bordsnamn, matcha det befintliga bordets speltyp eller be en sittande spelare lämna plats.",
      timedOut: "Anslutningen tog för lång tid",
      botMayWarm: "Modellmotståndaren kan fortfarande värmas.",
      noResponse: "Bordet svarade inte innan tidsgränsen.",
      timeoutHint: "Försök igen om en stund. Om det fortsätter, gå tillbaka till lobbyn och skapa ett nytt bord.",
      reactMissing: "React-appen har inte laddats..."
    },
    chat: { title: "Chatt", empty: "Inga meddelanden än.", you: "Du", opponent: "Motståndare", placeholder: "Skicka ett meddelande", send: "Skicka" },
    game: {
      tableGame: "Spel vid bordet",
      againstBot: "Du spelar som {color} mot {bot}.",
      againstHuman: "Du spelar som {color}. Dela bordsnamnet med din motståndare.",
      host: "Värd",
      guest: "Gäst",
      turn: "Omgång {number}",
      currentPlayer: "Aktuell spelare",
      toMove: "{player} ska spela",
      settingUp: "Bordet förbereds.",
      waitingOpponent: "Väntar på en motståndare.",
      seat: "Plats",
      youAre: "Du är {color}",
      actions: "Åtgärder",
      roll: "Kasta",
      passDice: "Lämna över tärningarna",
      undo: "Ångra",
      confirm: "Bekräfta",
      newMatch: "Ny match",
      endTurn: "Avsluta omgång",
      resign: "Ge upp",
      resignConfirm: "Ge upp matchen?",
      match: "Match",
      dice: "Tärningar",
      openingRoll: "Startkast",
      rollToStart: "Kasta för att avgöra vem som börjar.",
      tavliAgreement: "Tavli-målet måste godkännas före spelstart.",
      margotAgreement: "Margot la fendue måste godkännas före spelstart.",
      optionsAgreement: "Matchalternativen måste bekräftas före spelstart.",
      decisionRequired: "{player} måste fatta ett turbeslut.",
      wonBy: "{winner} vann genom {kind}.",
      wonByPoints: "{winner} vann med {points} i marginal.",
      drawnSettlement: "Jämn avräkning",
      currentLeg: "Aktuellt parti: {leg}",
      seatWarning: "Platsvarning",
      seatWanted: "En annan webbläsare vill återta denna plats.",
      reclaimingSeat: "{name} försöker återta platsen vid bordet.",
      remainWithin: "Klicka på Behåll platsen inom cirka {seconds} {seconds, plural, one {sekund} other {sekunder}} för att fortsätta spela från denna webbläsare.",
      remainSeated: "Behåll platsen",
      noDice: "Inga tärningar kastade än.",
      dieAlt: "Tärning {value}",
      openingDieAlt: "{color} öppningstärning {value}",
      movesLeft: "Drag återstår: {moves}",
      noMovesLeft: "inga",
      awaitingRoll: "Väntar på nästa kast.",
      soundOn: "Ljud på",
      soundOff: "Ljud av",
      soundUnavailable: "Ljud ej tillgängligt",
      soundUnavailableTitle: "Ljud är inte tillgängligt i denna webbläsare",
      soundOffTitle: "Stäng av ljud",
      soundOffLockedTitle: "Stäng av ljud. Ljudet fortsätter vid nästa klick eller tangenttryckning.",
      soundOnTitle: "Slå på ljud",
      matchOptions: "Matchalternativ",
      startMatch: "Starta match",
      pregame: "Före spelet",
      choosePregame: "Välj alternativ före spelet.",
      yourChoice: "Ditt val",
      colorChoice: "{color}s val",
      selectedTarget: "Valt mål: {target}",
      chooseTarget: "Välj {target}",
      decision: "Beslut",
      decisionKey: "Beslutsnyckel: {key}",
      trictracTrack: "Trictrac-spår",
      target: "Mål",
      opponentBar: "Motståndarens bar",
      yourBar: "Din bar",
      bearOff: "Ta ut",
      actionFailed: "Åtgärden misslyckades.",
      impuissance: "Dame impuissante: {points} {points, plural, one {poäng} other {poäng}} till {color}.",
      passDiceHint: "Inga lagliga drag finns; lämna över tärningarna till motståndaren.",
      pack: "Paket",
      packTitle: "Välj ljudpaket"
    },
    options: {
      pointsToPlay: "Poängmål",
      marquesToPlay: "Marqué-mål",
      holesToPlay: "Hålmål",
      matchLength: "Matchlängd",
      doublesMode: "Doublettläge",
      margot: "Margot la fendue",
      enableMargot: "Aktivera Margot",
      targetHoles: "Hålmål",
      doubleScoring: "Dubbel räkning",
      doublesOn: "Doubletter på",
      doublesOff: "Doubletter av",
      bestOf: "Bäst av",
      bestOfN: "Bäst av {count}",
      tavliPrompt: "Välj Tavli-mål. Vid oenighet blir målet 7.",
      margotPrompt: "Spela med Margot la fendue?",
      partieLengthPrompt: "Välj marqué-mål."
    },
    units: {
      point: "{count} {count, plural, one {poäng} other {poäng}}",
      hole: "{count} {count, plural, one {hål} other {hål}}",
      game: "{count} {count, plural, one {parti} other {partier}}",
      marque: "{count} marqués",
      trou: "{count} {count, plural, one {hål} other {hål}}",
      jeton: "{count} {count, plural, one {jeton} other {jetons}}",
      honneur: "{count} honneurs"
    },
    score: { wins: "{color} får {points} {points, plural, one {poäng} other {poäng}}", event: "poänghändelse" },
    decision: {
      reprise: "Välj om spelet ska fortsätta eller ta en reprise.",
      suspension: "Välj vilket spår som ska suspenderas.",
      suspendOneTrack: "Suspendera ett spår?",
      continueMarque: "Välj hur marqué ska fortsätta.",
      none: "Ingen",
      tenir: "Stå kvar",
      "s'en aller": "Lyft spelet",
      suspend_classique: "Suspendera honneurs",
      suspend_a_ecrire: "Suspendera à écrire"
    },
    detail: {
      currentCoup: "Aktuellt coup",
      consolation: "Consolation",
      lastMarque: "Senaste marqué",
      lastHonneurs: "Senaste honneurs",
      honneursState: "Honneurs-läge",
      suspension: "Suspension",
      whiteSettlement: "Avräkning för vit",
      blackSettlement: "Avräkning för svart",
      result: "Resultat",
      whiteAEcrire: "Vit à écrire",
      blackAEcrire: "Svart à écrire",
      whiteHonneurs: "Vit honneurs",
      blackHonneurs: "Svart honneurs",
      final: "Slutligt {value}",
      noMarque: "Ingen marqué avräknad än.",
      nextConsolation: "Nästa consolation {value}",
      trouAgainst: "{winner} hål mot {loser}",
      voluntaryLoss: "Frivillig förlust",
      simpleMarque: "Enkel marqué",
      gainExact: "Exakt vinst {value}",
      gainArrondi: "Avrundad vinst {value}",
      noHonneurs: "Ingen honneurs-partie avräknad än.",
      wonClass: "{color} vann {klass}",
      noCarry: "Ingen överföring",
      carried: "{count} {count, plural, one {hål överfört} other {hål överförda}}",
      currentPartieWhite: "Aktuellt parti vit: {value}",
      currentPartieBlack: "Aktuellt parti svart: {value}",
      honneursNear: "Honneurs nära avräkning",
      honneursProgress: "Honneurs pågår",
      suspended: "{track} suspenderat",
      frozenBy: "Låst av {color}",
      resumesOnReleve: "Fortsätter vid relevé",
      beforeQueues: "{value} före queues",
      finalValue: "{value} slutligt",
      nextJetons: "{value} jetons härnäst",
      noRefait: "Ingen refait",
      refaitCount: "{count} {count, plural, one {refait} other {refaits}}",
      partieTrous: "Partihål: {count}",
      marquesProgress: "{count}/{total} marqués",
      colorTrous: "{color}: {holes}",
      pointsAndTrous: "{points} / {holes}",
      compactClasses: "S/D/T/Q {value}"
    },
    matchResult: {
      gameDraw: "Parti {number}: {kind}{award}",
      gameWin: "Parti {number}: {leg}{winner} vann{award} genom {kind}"
    },
    errors: {
      unknown: "Okänt fel.",
      unauthorized: "Obehörig.",
      lobby_full: "Bordet är fullt.",
      player_not_found: "Spelaren finns inte i lobbyn.",
      match_over: "Matchen är redan slut.",
      not_your_turn: "Det är inte din tur.",
      invalid_move: "Ogiltigt drag.",
      no_rolled_dice: "Inga kastade tärningar att bekräfta.",
      turn_obligations: "Omgångens skyldigheter är inte uppfyllda.",
      coin_rest: "Coin de repos måste avsluta omgången med 0 eller minst 2 brickor.",
      only_host_options: "Endast värden kan skicka matchalternativ.",
      variant_mismatch: "Denna lobby använder redan ett annat spel.",
      reset_unavailable: "Återställning är bara möjlig efter matchens slut.",
      seat_reclaim_pending: "Återtagning av plats begärd.",
      bot_unavailable: "Den valda boten är inte tillgänglig.",
      action_failed: "Åtgärden misslyckades."
    }
  },
  da: {
    language: "Sprog",
    yes: "Ja",
    no: "Nej",
    on: "Til",
    off: "Fra",
    show: "Vis",
    hide: "Skjul",
    none: "Ingen",
    waiting: "Venter",
    unknown: "ukendt",
    someone: "Nogen",
    color: { white: "Hvid", black: "Sort", unknown: "Ukendt" },
    lobby: {
      title: "Start eller slut dig til et bord",
      lobbyName: "Bordnavn:",
      userName: "Spillernavn:",
      chooseGame: "Vælg spil",
      moreGames: "Flere spil",
      computerNote: "Flere spil er endnu ikke tilgængelige mod computeren.",
      opponent: "Modstander",
      playAgainst: "Spil mod",
      human: "Person",
      computer: "Computer",
      margot: "Margot",
      botNote: "Spil mod computeren bruger BackgammonAI til engelsk backgammon og den aktuelle Trictrac-model til Trictrac classique, Trictrac til bogføring, Kombineret Trictrac, Toc og Toccategli.",
      enter: "Til bordet"
    },
    join: {
      joiningLabel: "Forbinder til bord",
      joinFailed: "Forbindelse mislykkedes",
      tryAgain: "Prøv igen",
      backToLobby: "Tilbage til lobbyen",
      connectingBot: "Forbinder til bordet og varmer modellen op. Det første spil mod botten kan tage omkring et minut.",
      connecting: "Forbinder til bordet...",
      slowBot: "Modellen varmes stadig op. Den første forbindelse til botten kan tage lidt tid.",
      slow: "Forbinder stadig til bordet...",
      seatReclaim: "Anmodning om at overtage pladsen.",
      reclaimRetry: "Hvis den browser, der allerede sidder, ikke klikker på Behold pladsen inden cirka {seconds} {seconds, plural, one {sekund} other {sekunder}}, kan du klikke Prøv igen for at overtage pladsen.",
      reclaiming: "Forbinder igen for at overtage pladsen...",
      unable: "Kunne ikke deltage ved bordet",
      rejected: "Bordet afviste denne anmodning.",
      hint: "Prøv et andet bordnavn, vælg samme spiltype som det eksisterende bord, eller bed en siddende spiller gøre plads.",
      timedOut: "Forbindelsen udløb",
      botMayWarm: "Modelmodstanderen varmes måske stadig op.",
      noResponse: "Bordet svarede ikke før tidsfristen.",
      timeoutHint: "Prøv igen om lidt. Hvis det fortsætter, så gå tilbage til lobbyen og opret et nyt bord.",
      reactMissing: "React-appen er ikke indlæst..."
    },
    chat: { title: "Chat", empty: "Ingen beskeder endnu.", you: "Du", opponent: "Modstander", placeholder: "Send en besked", send: "Send" },
    game: {
      tableGame: "Spil ved bordet",
      againstBot: "Du spiller som {color} mod {bot}.",
      againstHuman: "Du spiller som {color}. Del bordnavnet med din modstander.",
      host: "Vært",
      guest: "Gæst",
      turn: "Runde {number}",
      currentPlayer: "Aktuel spiller",
      toMove: "{player} skal spille",
      settingUp: "Bordet gøres klar.",
      waitingOpponent: "Venter på en modstander.",
      seat: "Plads",
      youAre: "Du er {color}",
      actions: "Handlinger",
      roll: "Kast",
      passDice: "Overdrag terningerne",
      undo: "Fortryd",
      confirm: "Bekræft",
      newMatch: "Ny match",
      endTurn: "Afslut runden",
      resign: "Opgiv",
      resignConfirm: "Opgiv matchen?",
      match: "Match",
      dice: "Terninger",
      openingRoll: "Startkast",
      rollToStart: "Kast for at afgøre, hvem der begynder.",
      tavliAgreement: "Tavli-målet skal aftales før spillet starter.",
      margotAgreement: "Margot la fendue skal aftales før spillet starter.",
      optionsAgreement: "Matchindstillingerne skal bekræftes før spillet starter.",
      decisionRequired: "{player} skal træffe en beslutning for runden.",
      wonBy: "{winner} vandt på {kind}.",
      wonByPoints: "{winner} vandt med {points} i margin.",
      drawnSettlement: "Jævn afregning",
      currentLeg: "Aktuelt parti: {leg}",
      seatWarning: "Pladsadvarsel",
      seatWanted: "En anden browser vil overtage denne plads.",
      reclaimingSeat: "{name} prøver at overtage denne bordplads.",
      remainWithin: "Klik Behold pladsen inden cirka {seconds} {seconds, plural, one {sekund} other {sekunder}} for at fortsætte fra denne browser.",
      remainSeated: "Behold pladsen",
      noDice: "Ingen terninger kastet endnu.",
      dieAlt: "Terning {value}",
      openingDieAlt: "{color} åbningsterning {value}",
      movesLeft: "Resterende træk: {moves}",
      noMovesLeft: "ingen",
      awaitingRoll: "Venter på næste kast.",
      soundOn: "Lyd til",
      soundOff: "Lyd fra",
      soundUnavailable: "Lyd ikke tilgængelig",
      soundUnavailableTitle: "Lyd er ikke tilgængelig i denne browser",
      soundOffTitle: "Slå lyd fra",
      soundOffLockedTitle: "Slå lyd fra. Lyden fortsætter ved næste klik eller tastetryk.",
      soundOnTitle: "Slå lyd til",
      matchOptions: "Matchindstillinger",
      startMatch: "Start match",
      pregame: "Før spillet",
      choosePregame: "Vælg indstilling før spillet.",
      yourChoice: "Dit valg",
      colorChoice: "{color}s valg",
      selectedTarget: "Valgt mål: {target}",
      chooseTarget: "Vælg {target}",
      decision: "Beslutning",
      decisionKey: "Beslutningsnøgle: {key}",
      trictracTrack: "Trictrac-spor",
      target: "Mål",
      opponentBar: "Modstanderens bar",
      yourBar: "Din bar",
      bearOff: "Tag ud",
      actionFailed: "Handlingen mislykkedes.",
      impuissance: "Dame impuissante: {points} {points, plural, one {point} other {point}} til {color}.",
      passDiceHint: "Der er ingen lovlige træk; overdrag terningerne til modstanderen.",
      pack: "Pakke",
      packTitle: "Vælg lydpakke"
    },
    options: {
      pointsToPlay: "Pointmål",
      marquesToPlay: "Marqué-mål",
      holesToPlay: "Hulmål",
      matchLength: "Matchlængde",
      doublesMode: "Doublet-tilstand",
      margot: "Margot la fendue",
      enableMargot: "Aktivér Margot",
      targetHoles: "Hulmål",
      doubleScoring: "Dobbelt optælling",
      doublesOn: "Doubletter til",
      doublesOff: "Doubletter fra",
      bestOf: "Bedst af",
      bestOfN: "Bedst af {count}",
      tavliPrompt: "Vælg Tavli-målet. Ved uenighed bliver målet 7.",
      margotPrompt: "Spil med Margot la fendue?",
      partieLengthPrompt: "Vælg marqué-mål."
    },
    units: {
      point: "{count} {count, plural, one {point} other {point}}",
      hole: "{count} {count, plural, one {hul} other {huller}}",
      game: "{count} {count, plural, one {parti} other {partier}}",
      marque: "{count} marqués",
      trou: "{count} {count, plural, one {hul} other {huller}}",
      jeton: "{count} {count, plural, one {jeton} other {jetons}}",
      honneur: "{count} honneurs"
    },
    score: { wins: "{color} får {points} {points, plural, one {point} other {point}}", event: "scoringshændelse" },
    decision: {
      reprise: "Vælg om spillet skal fortsætte, eller om der skal tages en reprise.",
      suspension: "Vælg hvilket spor der skal suspenderes.",
      suspendOneTrack: "Suspendér et spor?",
      continueMarque: "Vælg hvordan marqué skal fortsætte.",
      none: "Ingen",
      tenir: "Bliv stående",
      "s'en aller": "Løft spillet",
      suspend_classique: "Suspendér honneurs",
      suspend_a_ecrire: "Suspendér à écrire"
    },
    detail: {
      currentCoup: "Aktuelt coup",
      consolation: "Consolation",
      lastMarque: "Seneste marqué",
      lastHonneurs: "Seneste honneurs",
      honneursState: "Honneurs-status",
      suspension: "Suspension",
      whiteSettlement: "Afregning for hvid",
      blackSettlement: "Afregning for sort",
      result: "Resultat",
      whiteAEcrire: "Hvid til bogføring",
      blackAEcrire: "Sort til bogføring",
      whiteHonneurs: "Hvid honneurs",
      blackHonneurs: "Sort honneurs",
      final: "Endeligt {value}",
      noMarque: "Ingen marqué afregnet endnu.",
      nextConsolation: "Næste consolation {value}",
      trouAgainst: "{winner} huller mod {loser}",
      voluntaryLoss: "Frivilligt tab",
      simpleMarque: "Enkelt marqué",
      gainExact: "Præcis gevinst {value}",
      gainArrondi: "Afrundet gevinst {value}",
      noHonneurs: "Ingen honneurs-partie afregnet endnu.",
      wonClass: "{color} vandt {klass}",
      noCarry: "Ingen overførsel",
      carried: "{count} {count, plural, one {hul overført} other {huller overført}}",
      currentPartieWhite: "Aktuelt parti hvid: {value}",
      currentPartieBlack: "Aktuelt parti sort: {value}",
      honneursNear: "Honneurs tæt på afregning",
      honneursProgress: "Honneurs i gang",
      suspended: "{track} suspenderet",
      frozenBy: "Låst af {color}",
      resumesOnReleve: "Fortsætter ved relevé",
      beforeQueues: "{value} før queues",
      finalValue: "{value} endeligt",
      nextJetons: "{value} jetons næste",
      noRefait: "Ingen refait",
      refaitCount: "{count} {count, plural, one {refait} other {refaits}}",
      partieTrous: "Partihuller: {count}",
      marquesProgress: "{count}/{total} marqués",
      colorTrous: "{color}: {holes}",
      pointsAndTrous: "{points} / {holes}",
      compactClasses: "S/D/T/Q {value}"
    },
    matchResult: {
      gameDraw: "Parti {number}: {kind}{award}",
      gameWin: "Parti {number}: {leg}{winner} vandt{award} på {kind}"
    },
    errors: {
      unknown: "Ukendt fejl.",
      unauthorized: "Ikke autoriseret.",
      lobby_full: "Bordet er fuldt.",
      player_not_found: "Spilleren findes ikke i lobbyen.",
      match_over: "Matchen er allerede slut.",
      not_your_turn: "Det er ikke din tur.",
      invalid_move: "Ugyldigt træk.",
      no_rolled_dice: "Ingen kastede terninger at bekræfte.",
      turn_obligations: "Turens forpligtelser er ikke opfyldt.",
      coin_rest: "Coin de repos skal afslutte runden med 0 eller mindst 2 brikker.",
      only_host_options: "Kun værten kan sende matchindstillinger.",
      variant_mismatch: "Denne lobby bruger allerede et andet spil.",
      reset_unavailable: "Nulstilling er kun tilgængelig efter matchen er slut.",
      seat_reclaim_pending: "Anmodning om at overtage pladsen.",
      bot_unavailable: "Den valgte bot er ikke tilgængelig.",
      action_failed: "Handlingen mislykkedes."
    }
  }
};

const VARIANT_TITLES = {
  en: {
    backgammon: "Backgammon",
    tapa: "Tapa / Plakoto",
    jacquet: "Jacquet / Pheuga",
    tavli: "Tavli",
    brade: "Bräde",
    garanguet: "Garanguet",
    sbaraglio: "Sbaraglio",
    sbaraglino: "Sbaraglino",
    plein: "Plein",
    tourne_case: "Tourne-Case",
    dames_rabattues: "Dames Rabattues",
    trictrac_classique: "Trictrac classique",
    trictrac_aecrire: "Trictrac à écrire",
    trictrac_combine: "Trictrac combiné",
    toc: "Toc",
    toccategli: "Toccategli"
  },
  de: {
    trictrac_aecrire: "Trictrac zum Aufschreiben",
    trictrac_combine: "Kombiniertes Trictrac",
    brade: "Bräde",
    plein: "Plein",
    dames_rabattues: "Dames Rabattues"
  },
  fr: {
    trictrac_aecrire: "Trictrac à écrire",
    trictrac_combine: "Trictrac combiné",
    brade: "Bräde suédois",
    plein: "Plein",
    dames_rabattues: "Dames Rabattues"
  },
  sv: {
    trictrac_aecrire: "Trictrac att skriva",
    trictrac_combine: "Kombinerad Trictrac",
    brade: "Bräde",
    plein: "Plein",
    dames_rabattues: "Dames Rabattues"
  },
  da: {
    trictrac_aecrire: "Trictrac til bogføring",
    trictrac_combine: "Kombineret Trictrac",
    brade: "Bræde",
    plein: "Plein",
    dames_rabattues: "Dames Rabattues"
  }
};

for (const [locale, overrides] of Object.entries(LOCALE_OVERRIDES)) {
  STRINGS[locale] = deepMerge(STRINGS.en, overrides);
  VARIANT_TITLES[locale] = { ...VARIANT_TITLES.en, ...(VARIANT_TITLES[locale] || {}) };
}

let currentLanguage = resolveInitialLanguage();
applyDocumentLanguage(currentLanguage);

function deepMerge(base, override) {
  const merged = { ...base };

  Object.entries(override || {}).forEach(([key, value]) => {
    if (value && typeof value === "object" && !Array.isArray(value)) {
      merged[key] = deepMerge(base[key] || {}, value);
    } else {
      merged[key] = value;
    }
  });

  return merged;
}

function lookup(source, key) {
  return key.split(".").reduce((current, part) => current?.[part], source);
}

function applyParams(template, params = {}) {
  return String(template).replace(/\{(\w+), plural, one \{([^{}]*)\} other \{([^{}]*)\}\}|\{(\w+)\}/g, (match, pluralKey, one, other, simpleKey) => {
    if (pluralKey) {
      return Number(params[pluralKey]) === 1 ? one : other;
    }

    return params[simpleKey] ?? match;
  });
}

export function normalizeLanguage(value) {
  const primary = String(value || "")
    .trim()
    .toLowerCase()
    .split("-")[0];

  return SUPPORTED.has(primary) ? primary : "en";
}

export function resolveInitialLanguage() {
  try {
    const stored = window.localStorage.getItem(LANGUAGE_STORAGE_KEY);

    if (stored) {
      return normalizeLanguage(stored);
    }
  } catch (_error) {
    // Local storage may be unavailable in private or restricted contexts.
  }

  if (typeof navigator !== "undefined") {
    return normalizeLanguage(navigator.languages?.[0] || navigator.language);
  }

  return "en";
}

export function getLanguage() {
  return currentLanguage;
}

export function setLanguage(language) {
  const next = normalizeLanguage(language);

  if (next === currentLanguage) {
    applyDocumentLanguage(next);
    return next;
  }

  currentLanguage = next;
  applyDocumentLanguage(next);

  try {
    window.localStorage.setItem(LANGUAGE_STORAGE_KEY, next);
  } catch (_error) {
    // Preference persistence is nice to have, not required for play.
  }

  if (typeof window !== "undefined") {
    window.dispatchEvent(new CustomEvent(LANGUAGE_EVENT, { detail: { language: next } }));
  }

  return next;
}

export function subscribeLanguage(callback) {
  const handler = (event) => callback(event.detail.language);
  window.addEventListener(LANGUAGE_EVENT, handler);
  return () => window.removeEventListener(LANGUAGE_EVENT, handler);
}

export function applyDocumentLanguage(language = currentLanguage) {
  if (typeof document !== "undefined") {
    document.documentElement.lang = normalizeLanguage(language);
  }
}

export function t(key, params = {}) {
  const template = lookup(STRINGS[currentLanguage], key) ?? lookup(STRINGS.en, key) ?? key;
  return applyParams(template, params);
}

export function tx(key, fallback, params = {}) {
  const template = lookup(STRINGS[currentLanguage], key) ?? lookup(STRINGS.en, key);
  return applyParams(template ?? fallback ?? key, params);
}

export function variantTitle(id, fallback = "") {
  return VARIANT_TITLES[currentLanguage]?.[id] || VARIANT_TITLES.en[id] || fallback || id;
}

export function colorLabel(color) {
  return t(`color.${color || "unknown"}`);
}

export function boolLabel(value) {
  return value ? t("yes") : t("no");
}

export function localizeError(resp, fallbackKey = "errors.action_failed") {
  if (resp?.code) {
    const translated = tx(`errors.${resp.code}`, null, resp);

    if (translated && translated !== `errors.${resp.code}`) {
      return translated;
    }
  }

  return resp?.msg || t(fallbackKey);
}

export function optionLabel(option) {
  switch (option?.key) {
    case "margotEnabled":
      return t("options.enableMargot");
    case "holeTarget":
      return t("options.targetHoles");
    case "doublesMode":
      return t("options.doubleScoring");
    case "matchLength":
      return t("options.bestOf");
    default:
      return option?.label || "";
  }
}

export function optionChoiceLabel(optionKey, choice) {
  const value = choice?.value ?? choice;
  const label = choice?.label ?? String(choice);

  if (optionKey === "doublesMode") {
    return value === "on" ? t("options.doublesOn") : t("options.doublesOff");
  }

  if (optionKey === "matchLength") {
    return t("options.bestOfN", { count: value });
  }

  return label;
}

export function syncLanguageSelects() {
  document.querySelectorAll("[data-language-select]").forEach((select) => {
    select.value = currentLanguage;
  });

  document.querySelectorAll("[data-language-button]").forEach((button) => {
    const active = normalizeLanguage(button.dataset.languageButton) === currentLanguage;
    button.classList.toggle("active", active);
    button.setAttribute("aria-pressed", active ? "true" : "false");
  });
}

export function localizeStaticPage(root = document) {
  applyDocumentLanguage();
  syncLanguageSelects();

  root.querySelectorAll("[data-i18n]").forEach((element) => {
    element.textContent = t(element.dataset.i18n);
  });

  root.querySelectorAll("[data-i18n-placeholder]").forEach((element) => {
    element.setAttribute("placeholder", t(element.dataset.i18nPlaceholder));
  });

  root.querySelectorAll("[data-i18n-title]").forEach((element) => {
    element.setAttribute("title", t(element.dataset.i18nTitle));
  });

  root.querySelectorAll("[data-i18n-aria-label]").forEach((element) => {
    element.setAttribute("aria-label", t(element.dataset.i18nAriaLabel));
  });

  root.querySelectorAll("[data-i18n-summary-toggle]").forEach((element) => {
    element.dataset.closedLabel = t("show");
    element.dataset.openLabel = t("hide");
  });

  root.querySelectorAll("[data-variant-label]").forEach((element) => {
    element.textContent = variantTitle(element.dataset.variantLabel, element.textContent);
  });
}

export function attachLanguageControls(root = document) {
  root.querySelectorAll("[data-language-select]").forEach((select) => {
    select.value = currentLanguage;
    select.addEventListener("change", (event) => {
      setLanguage(event.target.value);
      localizeStaticPage(root);
    });
  });

  root.querySelectorAll("[data-language-button]").forEach((button) => {
    button.addEventListener("click", () => {
      setLanguage(button.dataset.languageButton);
      localizeStaticPage(root);
    });
  });
}

export function languageSelectOptions() {
  return LANGUAGE_OPTIONS;
}

const EXACT_LEAK_ALLOWLIST = new Set([
  "appTitle",
  "chat.send",
  "chat.title",
  "game.actions",
  "game.match",
  "game.pack",
  "detail.compactClasses",
  "detail.gainExact",
  "detail.gainArrondi",
  "detail.marques",
  "detail.marquesProgress",
  "detail.colorTrous",
  "detail.pointsAndTrous",
  "detail.queueJetons",
  "detail.queueMarques",
  "detail.refaitCount",
  "detail.suspension",
  "lobby.computer",
  "lobby.margot",
  "options.margot",
  "units.honneur",
  "units.jeton",
  "units.marque",
  "units.point",
  "detail.bredouille",
  "detail.grandeBredouille",
  "detail.consolation",
  "detail.refait"
]);

const HISTORICAL_TERMS = new Set([
  "BackgammonAI",
  "Tavli",
  "Trictrac",
  "Toccategli",
  "Toc",
  "Margot",
  "jan",
  "bredouille",
  "marqué",
  "honneurs",
  "jeton",
  "jetons",
  "relevé",
  "reprise",
  "à écrire",
  "classique",
  "combiné"
]);

const MANUAL_LOCALIZED_KEYS = new Set([
  "decision.tenir",
  "decision.s'en aller",
  "detail.carried",
  "detail.partieTrous",
  "detail.trouAgainst",
  "options.holesToPlay",
  "options.targetHoles",
  "units.trou"
]);

const RAW_FRENCH_LEAK_PATTERN = /\btrous?\b|tenir|s[’']en aller/i;

function flattenStrings(source, prefix = "", out = []) {
  Object.entries(source || {}).forEach(([key, value]) => {
    const path = prefix ? `${prefix}.${key}` : key;

    if (value && typeof value === "object" && !Array.isArray(value)) {
      flattenStrings(value, path, out);
    } else {
      out.push([path, String(value)]);
    }
  });

  return out;
}

function isAllowedExactLeak(path, value) {
  return EXACT_LEAK_ALLOWLIST.has(path) || HISTORICAL_TERMS.has(value);
}

function isAllowedLocaleExactLeak(locale, path) {
  return (
    locale === "fr" &&
    new Set([
      "decision.tenir",
      "units.trou"
    ]).has(path)
  );
}

export function auditI18nEnglishLeaks() {
  const english = new Map(flattenStrings(STRINGS.en));
  const leaks = [];

  for (const locale of LANGUAGE_OPTIONS.map((option) => option.id).filter((id) => id !== "en")) {
    for (const [path, value] of flattenStrings(STRINGS[locale])) {
      if (value === english.get(path) && !isAllowedExactLeak(path, value) && !isAllowedLocaleExactLeak(locale, path)) {
        leaks.push({ locale, path, value, reason: "english-fallback" });
      }

      if (locale !== "fr" && MANUAL_LOCALIZED_KEYS.has(path) && RAW_FRENCH_LEAK_PATTERN.test(value)) {
        leaks.push({ locale, path, value, reason: "manual-localized-term-leak" });
      }
    }
  }

  return leaks;
}
