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
// bredouille, relevé, reprise, marqué, and honneurs may remain recognizable
// where the manual keeps them.
// Toast labels describe completed scoring events, so action verbs should be
// rendered as results rather than infinitives where the language distinguishes them.
const STRINGS = {
  "en": {
    "appTitle": "HERMES Trictrac",
    "language": "Language",
    "yes": "Yes",
    "no": "No",
    "on": "On",
    "off": "Off",
    "show": "Show",
    "hide": "Hide",
    "none": "None",
    "waiting": "Waiting",
    "unknown": "unknown",
    "someone": "Someone",
    "color": {
      "white": "White",
      "black": "Black",
      "unknown": "Unknown"
    },
    "colorSubject": {
      "white": "White",
      "black": "Black",
      "unknown": "Unknown"
    },
    "lobby": {
      "title": "Start or Join a Table",
      "lobbyName": "Lobby Name:",
      "userName": "User Name:",
      "blueskyHandle": "Bluesky Handle:",
      "signInWithBluesky": "Sign in with Bluesky",
      "signInRequired": "Sign in before opening, joining, or watching a table.",
      "signedInAs": "Signed in as",
      "logout": "Log out",
      "blueskyIdentityLocked": "In production mode, table identity comes from Bluesky.",
      "playMode": "Table mode",
      "headToHead": "Head-to-head",
      "multiSeat": "Multi-seat",
      "chooseGame": "Choose a Game",
      "chooseMultiSeat": "Choose a Multi-seat Table",
      "multiSeatIntro": "Some multi-seat tables rotate a queue, while others use fixed roles. Pick a format and the relevant setup controls will appear below.",
      "multiSeatTrictracPouleTitle": "Trictrac en poule",
      "multiSeatTrictracPouleMeta": "2 active seats · rotating queue",
      "multiSeatToccategliPouleTitle": "Toccategli en poule",
      "multiSeatToccategliPouleMeta": "2 active seats · rotating queue",
      "multiSeatTrictracPoulePlumeeTitle": "Trictrac en poule (plumée)",
      "multiSeatTrictracPoulePlumeeMeta": "fixed ring · common fund",
      "multiSeatToccategliPoulePlumeeTitle": "Toccategli en poule (plumée)",
      "multiSeatToccategliPoulePlumeeMeta": "fixed ring · common fund",
      "multiSeatAecrireTournerTitle": "Trictrac à écrire à tourner",
      "multiSeatAecrireTournerMeta": "3 players · round robin",
      "multiSeatAecrireChouetteTitle": "Trictrac à écrire chouette",
      "multiSeatAecrireChouetteMeta": "3 players · chouette",
      "multiSeatAecrireTeamsTitle": "Trictrac à écrire deux contre deux",
      "multiSeatAecrireTeamsMeta": "4 players · two sides",
      "multiSeatCombineChouetteTitle": "Trictrac combiné chouette",
      "multiSeatCombineChouetteMeta": "3 players · combined chouette",
      "multiSeatCombineTeamsTitle": "Trictrac combiné deux contre deux",
      "multiSeatCombineTeamsMeta": "4 players · combined teams",
      "queueSize": "Queue Size:",
      "ante": "Ante:",
      "stake": "Stake:",
      "holeValue": "Hole value:",
      "cashPerJeton": "Cash per jeton:",
      "aEcrirePartieLength": "Partie length:",
      "multiSeatSpectatorsNote": "Extra joiners watch as spectators. If a roster spot opens, a spectator can claim it.",
      "multiSeatStatus": "Status",
      "multiSeatStatusNote": "Multi-seat lobby flow is being wired. You can scope the table style now, but starting play stays disabled for the moment.",
      "moreGames": "More games",
      "computerNote": "More games are not available for computer play yet.",
      "opponent": "Opponent",
      "playAgainst": "Play against",
      "human": "Human",
      "computer": "Computer",
      "margot": "Margot",
      "botNote": "Computer play uses BackgammonAI for English backgammon and the current Trictrac model for Trictrac classique, Trictrac à écrire, Trictrac combiné, Toc, and Toccategli.",
      "enter": "Enter Lobby",
      "multiSeatEnter": "Enter Multi-seat Table"
    },
    "join": {
      "joiningLabel": "Joining Table",
      "joinFailed": "Join Failed",
      "tryAgain": "Try Again",
      "backToLobby": "Back to Lobby",
      "connectingBot": "Connecting to table and warming the model. The first bot game can take around a minute.",
      "connecting": "Connecting to table…",
      "slowBot": "Still warming the model. The first bot connection can take a little while.",
      "slow": "Still connecting to table…",
      "seatReclaim": "Seat reclaim requested.",
      "reclaimRetry": "If the seated browser does not click “Remain Seated” within about {seconds} {seconds, plural, one {second} other {seconds}}, you can click “Try Again” to reclaim the seat.",
      "reclaiming": "Reconnecting to reclaim your seat…",
      "unable": "Unable to Join Table",
      "rejected": "The table rejected this join request.",
      "hint": "Try a different lobby name, match the existing table's game type, or ask a seated player to make room.",
      "timedOut": "Join Timed Out",
      "botMayWarm": "The model opponent may still be warming up.",
      "noResponse": "The table did not respond before the join timeout.",
      "timeoutHint": "Try again in a moment. If this keeps happening, return to the lobby and create a fresh table.",
      "reactMissing": "React app not loaded…"
    },
    "chat": {
      "title": "Chat",
      "empty": "No messages yet.",
      "you": "You",
      "opponent": "Opponent",
      "placeholder": "Send a message",
      "send": "Send"
    },
    "game": {
      "tableGame": "Table Game",
      "againstBot": "You are playing as {color} against {bot}.",
      "againstHuman": "You are playing as {color}. Share this lobby name with your opponent to join the same table.",
      "host": "Host",
      "guest": "Guest",
      "turn": "Turn {number}",
      "currentPlayer": "Current player",
      "toMove": "{player} to move",
      "settingUp": "Table is setting up.",
      "waitingOpponent": "Waiting for an opponent to join.",
      "tavliAgreement": "Tavli target must be agreed before play starts.",
      "margotAgreement": "Margot la fendue must be agreed before play starts.",
      "optionsAgreement": "Match options need to be confirmed before play starts.",
      "decisionRequired": "{player} must resolve a turn decision.",
      "wonBy": "{winner} won by {kind}.",
      "wonByPoints": "{winner} won by {points}.",
      "drawnSettlement": "Drawn settlement",
      "currentLeg": "Current leg: {leg}",
      "seat": "Seat",
      "youAre": "You are {color}",
      "seatWarning": "Seat Warning",
      "seatWanted": "Another browser wants this seat.",
      "reclaimingSeat": "{name} is trying to reclaim this table seat.",
      "remainWithin": "Click “Remain Seated” within about {seconds} {seconds, plural, one {second} other {seconds}} to keep playing from this browser.",
      "remainSeated": "Remain Seated",
      "dice": "Dice",
      "noDice": "No dice rolled yet.",
      "dieAlt": "Die {value}",
      "openingDieAlt": "{color} opening die {value}",
      "movesLeft": "Moves left: {moves}",
      "noMovesLeft": "none",
      "awaitingRoll": "Awaiting next roll.",
      "lastMove": "{player} moved from {from} to {to}.",
      "lastMoves": "{player} moved {moves}.",
      "moveSegment": "from {from} to {to}",
      "listJoin": "{items} and {last}",
      "openingRoll": "Opening Roll",
      "rollToStart": "Roll to decide who starts.",
      "actions": "Actions",
      "roll": "Roll",
      "passDice": "Pass Dice",
      "undo": "Undo",
      "confirm": "Confirm",
      "newMatch": "New Match",
      "endTurn": "End Turn",
      "resign": "Resign",
      "resignConfirm": "Resign the match?",
      "impuissance": "Blocked checker: {points} {points, plural, one {point} other {points}} to {color}.",
      "passDiceHint": "No legal moves are available; pass the dice to your opponent.",
      "matchOptions": "Match Options",
      "startMatch": "Start Match",
      "pregame": "Pregame",
      "choosePregame": "Choose the pregame option.",
      "yourChoice": "Your choice",
      "colorChoice": "{color} choice",
      "selectedTarget": "Selected target: {target}",
      "chooseTarget": "Choose {target}",
      "decision": "Decision",
      "trictracTrack": "Trictrac Track",
      "match": "Match",
      "target": "Target",
      "bar": "Bar",
      "opponentBar": "Opponent Bar",
      "yourBar": "Your Bar",
      "bearOff": "Bear Off",
      "actionFailed": "Action failed.",
      "soundUnavailable": "Sound Unavailable",
      "soundOn": "Sound On",
      "soundOff": "Sound Off",
      "soundUnavailableTitle": "Sound is unavailable in this browser",
      "soundOffTitle": "Turn generated sound cues off",
      "soundOffLockedTitle": "Turn generated sound cues off. Audio will resume on your next click or key press.",
      "soundOnTitle": "Turn generated sound cues on",
      "pack": "Pack",
      "packTitle": "Choose a sound pack",
      "waitingCompetitors": "Waiting for enough competitors to fill the table.",
      "waitingQueueRefill": "Waiting for a spectator to claim the open queue slot.",
      "pouleFinished": "The poule session is finished.",
      "viewerActive": "You are {color} on the board.",
      "viewerQueued": "You are currently in the queue.",
      "viewerSpectator": "You are watching as a spectator.",
      "noSpectators": "No spectators are watching right now.",
      "currentStreak": "{name} is on a streak of {count}.",
      "noChampion": "No streak is running yet.",
      "poule": "Poule",
      "pool": "Pool",
      "ante": "Ante",
      "stake": "Stake",
      "holeValue": "Hole value",
      "remainingFund": "Remaining fund",
      "winTarget": "Target",
      "fixedRing": "Fixed ring",
      "fixedRingNote": "the second player stays on, and the first rotates to the tail.",
      "latestSettlement": "{name} took {amount} on a {trous}-trou lead.",
      "noSettlementYet": "No payout has been taken from the common fund yet.",
      "activeSeats": "Active seats",
      "queueOrder": "Queue",
      "spectators": "Spectators",
      "paid": "paid",
      "won": "won",
      "net": "net",
      "claimQueueSpot": "Claim queue spot",
      "openQueueSlot": "Open queue slot",
      "emptyQueue": "No one is waiting in the queue.",
      "poulePhase": {
        "waiting_for_competitors": "Waiting for competitors",
        "playing": "Playing",
        "waiting_for_queue_refill": "Waiting for queue refill",
        "finished": "Finished"
      }
    },
    "units": {
      "point": "{count} {count, plural, one {point} other {points}}",
      "hole": "{count} {count, plural, one {hole} other {holes}}",
      "game": "{count} {count, plural, one {game} other {games}}",
      "marque": "{count} {count, plural, one {marqué} other {marqués}}",
      "trou": "{count} {count, plural, one {trou} other {trous}}",
      "jeton": "{count} {count, plural, one {jeton} other {jetons}}",
      "honneur": "{count} {count, plural, one {honneur} other {honneurs}}"
    },
    "score": {
      "wins": "{color} wins {points} {points, plural, one {point} other {points}}",
      "event": "score event"
    },
    "scoreEvents": {
      "jan_rencontre": "jan de rencontre",
      "jan_de_meseas": "jan de meseas",
      "contre_jan_de_meseas": "contre-jan de meseas",
      "jan_de_deux_tables": "jan de deux tables",
      "contre_jan_de_deux_tables": "contre-jan de deux tables",
      "jan_de_six_tables": "jan de six tables",
      "jan_recompense": "jan de recompense",
      "jan_qui_ne_peut": "jan qui ne peut",
      "coin_battu": "coin battu",
      "coin_battu_a_faux": "coin battu a faux",
      "remplissage_petit": "remplissage petit jan",
      "remplissage_grand": "remplissage grand jan",
      "remplissage_retour": "remplissage jan de retour",
      "margot": "Margot la fendue",
      "impuissance": "impuissance",
      "conservation_petit": "conservation petit jan",
      "conservation_grand": "conservation grand jan",
      "conservation_retour": "conservation jan de retour",
      "pile_misere": "pile de misere",
      "sortie": "sortie"
    },
    "winnerKinds": {
      "grande_bredouille": "grande bredouille",
      "trous": "trous",
      "resign": "resign",
      "draw": "draw"
    },
    "decision": {
      "reprise": "Choose whether to continue the game or take a reprise.",
      "suspension": "Choose which track to suspend.",
      "suspendOneTrack": "Suspend one track?",
      "continueMarque": "Choose how to continue the marqué.",
      "none": "None",
      "tenir": "Tenir",
      "s'en aller": "S'en aller",
      "suspend_classique": "Suspend honneurs",
      "suspend_a_ecrire": "Suspend à écrire"
    },
    "options": {
      "pointsToPlay": "Points to play",
      "marquesToPlay": "Marqués to play",
      "holesToPlay": "Holes to play",
      "matchLength": "Match length",
      "doublesMode": "Doubles mode",
      "margot": "Margot la fendue",
      "enableMargot": "Enable Margot",
      "targetHoles": "Target holes",
      "doubleScoring": "Double Scoring",
      "doublesOn": "Doubles On",
      "doublesOff": "Doubles Off",
      "bestOf": "Best Of",
      "bestOfN": "Best-of-{count}",
      "tavliPrompt": "Choose the Tavli target. If you disagree, the match defaults to 7.",
      "margotPrompt": "Play with Margot la fendue?",
      "partieLengthPrompt": "Choose the marqué target."
    },
    "detail": {
      "bredouille": "Bredouille",
      "grandeBredouille": "Grande bredouille",
      "currentCoup": "Current coup",
      "consolation": "Consolation",
      "lastMarque": "Last marqué",
      "lastHonneurs": "Last honneurs",
      "honneursState": "Honneurs state",
      "suspension": "Suspension",
      "whiteSettlement": "White settlement",
      "blackSettlement": "Black settlement",
      "result": "Result",
      "whiteAEcrire": "White à écrire",
      "blackAEcrire": "Black à écrire",
      "whiteHonneurs": "White honneurs",
      "blackHonneurs": "Black honneurs",
      "queueJetons": "Queue des jetons {value}",
      "marques": "Marqués {value}",
      "queueMarques": "Queue des marqués {value}",
      "final": "Final {value}",
      "noMarque": "No marqué settled yet.",
      "refait": "Refait",
      "nextConsolation": "Next consolation {value}",
      "trouAgainst": "{winner} trous against {loser}",
      "voluntaryLoss": "Voluntary loss",
      "simpleMarque": "Simple marqué",
      "gainExact": "Gain exact {value}",
      "gainArrondi": "Gain arrondi {value}",
      "noHonneurs": "No honneurs partie settled yet.",
      "wonClass": "{color} won {klass}",
      "noCarry": "No carry",
      "carried": "{count} {count, plural, one {trou} other {trous}} carried",
      "currentPartieWhite": "White current partie: {value}",
      "currentPartieBlack": "Black current partie: {value}",
      "honneursNear": "Honneurs near settlement",
      "honneursProgress": "Honneurs in progress",
      "suspended": "{track} suspended",
      "frozenBy": "Frozen by {color}",
      "resumesOnReleve": "Resumes on relevé",
      "beforeQueues": "{value} before queues",
      "finalValue": "{value} final",
      "nextJetons": "{value} jetons next",
      "noRefait": "No refait",
      "refaitCount": "{count} {count, plural, one {refait} other {refaits}}",
      "partieTrous": "{count} partie trous",
      "marquesProgress": "{count}/{total} marqués",
      "colorTrous": "{color}: {holes}",
      "pointsAndTrous": "{points} / {holes}",
      "compactClasses": "S/D/T/Q {value}"
    },
    "matchResult": {
      "gameDraw": "Game {number}: {kind}{award}",
      "gameWin": "Game {number}: {leg}{winner} won{award} by {kind}"
    },
    "errors": {
      "unknown": "Unknown error.",
      "unauthorized": "Unauthorized.",
      "lobby_full": "Lobby is full.",
      "player_not_found": "Player not found in lobby.",
      "match_over": "Match is already over.",
      "not_your_turn": "Not your turn.",
      "invalid_move": "Invalid move.",
      "no_rolled_dice": "No rolled dice to confirm.",
      "turn_obligations": "Turn obligations not fulfilled.",
      "coin_rest": "Coin de repos must end the turn with 0 or at least 2 checkers.",
      "only_host_options": "Only the host can submit match options.",
      "variant_mismatch": "This lobby is already using another game.",
      "reset_unavailable": "Reset is only available after the match is over.",
      "seat_reclaim_pending": "Seat reclaim requested.",
      "bot_unavailable": "The selected bot is unavailable.",
      "action_failed": "Action failed."
    }
  }
};

const LOCALE_OVERRIDES = {
  "de": {
    "appTitle": "HERMES Trictrac",
    "language": "Sprache",
    "yes": "Ja",
    "no": "Nein",
    "on": "Ein",
    "off": "Aus",
    "show": "Zeigen",
    "hide": "Verbergen",
    "none": "Keine",
    "waiting": "Warten",
    "unknown": "unbekannt",
    "someone": "Jemand",
    "color": {
      "white": "Weiß",
      "black": "Schwarz",
      "unknown": "Unbekannt"
    },
    "colorSubject": {
      "white": "Weiß",
      "black": "Schwarz",
      "unknown": "Unbekannt"
    },
    "lobby": {
      "title": "Tisch eröffnen oder einem Tisch beitreten",
      "lobbyName": "Tischname:",
      "userName": "Spielername:",
      "playMode": "Tischmodus",
      "headToHead": "Kopf an Kopf",
      "multiSeat": "Mehrere Plätze",
      "chooseGame": "Spiel wählen",
      "chooseMultiSeat": "Mehrplatz-Tisch wählen",
      "multiSeatIntro": "Manche Mehrplatz-Tische rotieren eine Warteschlange, andere führen benannte Spieler durch feste Rollen. Wähle ein Format, dann erscheinen unten die passenden Einstellungen.",
      "multiSeatTrictracPouleTitle": "Trictrac en poule",
      "multiSeatTrictracPouleMeta": "2 aktive Sitze · rotierende Warteschlange",
      "multiSeatToccategliPouleTitle": "Toccategli en poule",
      "multiSeatToccategliPouleMeta": "2 aktive Sitze · rotierende Warteschlange",
      "multiSeatTrictracPoulePlumeeTitle": "Trictrac en poule (plumée)",
      "multiSeatTrictracPoulePlumeeMeta": "fester Ring · gemeinsamer Fonds",
      "multiSeatToccategliPoulePlumeeTitle": "Toccategli en poule (plumée)",
      "multiSeatToccategliPoulePlumeeMeta": "fester Ring · gemeinsamer Fonds",
      "multiSeatAecrireTournerTitle": "Trictrac à écrire à tourner",
      "multiSeatAecrireTournerMeta": "3 Spieler · Rundlauf",
      "multiSeatAecrireChouetteTitle": "Trictrac à écrire chouette",
      "multiSeatAecrireChouetteMeta": "3 Spieler · Chouette",
      "multiSeatAecrireTeamsTitle": "Trictrac à écrire deux contre deux",
      "multiSeatAecrireTeamsMeta": "4 Spieler · zwei Seiten",
      "multiSeatCombineChouetteTitle": "Trictrac combiné chouette",
      "multiSeatCombineChouetteMeta": "3 Spieler · kombinierte Chouette",
      "multiSeatCombineTeamsTitle": "Trictrac combiné deux contre deux",
      "multiSeatCombineTeamsMeta": "4 Spieler · kombinierte Seiten",
      "queueSize": "Warteschlangengröße:",
      "ante": "Einsatz:",
      "stake": "Fonds:",
      "holeValue": "Lochwert:",
      "cashPerJeton": "Geld pro Jeton:",
      "aEcrirePartieLength": "Partielänge:",
      "multiSeatSpectatorsNote": "Weitere Spieler sehen als Zuschauer zu. Wenn ein Platz in der Besetzung frei wird, kann ein Zuschauer ihn beanspruchen.",
      "multiSeatTurningTitle": "Trictrac à tourner",
      "multiSeatTurningMeta": "3 Spieler · rotierender Tisch",
      "multiSeatChouetteTitle": "Chouette",
      "multiSeatChouetteMeta": "3 Spieler · zwei gegen die Bank",
      "multiSeatFourForThemselvesTitle": "Vier für sich",
      "multiSeatFourForThemselvesMeta": "4 Spieler · rotierendes Einzelspiel",
      "multiSeatTwoAgainstTwoTitle": "Zwei gegen zwei",
      "multiSeatTwoAgainstTwoMeta": "4 Spieler · feste Partner",
      "multiSeatStatus": "Status",
      "multiSeatStatusNote": "Der Mehrplatz-Lobbyablauf wird gerade verdrahtet. Den Tischtyp kannst du schon festlegen, das Starten bleibt vorerst deaktiviert.",
      "moreGames": "Weitere Spiele",
      "computerNote": "Weitere Spiele sind gegen den Computer noch nicht verfügbar.",
      "opponent": "Gegner",
      "playAgainst": "Spielen gegen",
      "human": "Mensch",
      "computer": "Computer",
      "margot": "Margot",
      "botNote": "Partien gegen den Computer nutzen BackgammonAI für englisches Backgammon und das aktuelle Trictrac-Modell für Trictrac classique, Trictrac à écrire, Trictrac combiné, Toc und Toccategli.",
      "enter": "Tisch betreten",
      "multiSeatEnter": "Mehrplatz-Tisch betreten"
    },
    "join": {
      "joiningLabel": "Beitritt zum Tisch",
      "joinFailed": "Beitreten fehlgeschlagen",
      "tryAgain": "Erneut versuchen",
      "backToLobby": "Zurück zur Lobby",
      "connectingBot": "Verbindung zum Tisch wird hergestellt; das Modell wird vorbereitet. Die erste Partie gegen den Bot kann etwa eine Minute dauern.",
      "connecting": "Verbindung zum Tisch wird hergestellt…",
      "slowBot": "Das Modell wird noch vorbereitet. Die erste Verbindung zum Bot kann etwas dauern.",
      "slow": "Verbindung zum Tisch wird noch hergestellt…",
      "seatReclaim": "Sitzrückforderung angefordert.",
      "reclaimRetry": "Wenn der Browser, der den Sitz bereits belegt, nicht innerhalb von etwa {seconds} {seconds, plural, one {Sekunde} other {Sekunden}} auf „Sitz behalten“ klickt, können Sie mit „Erneut versuchen“ den Sitz übernehmen.",
      "reclaiming": "Verbindung zur Sitzübernahme wird hergestellt…",
      "unable": "Tischbeitritt nicht möglich",
      "rejected": "Der Tisch hat diese Anfrage abgelehnt.",
      "hint": "Wählen Sie einen anderen Tischnamen, verwenden Sie dieselbe Spielart wie am bestehenden Tisch, oder bitten Sie einen sitzenden Spieler, Platz zu machen.",
      "timedOut": "Beitritt abgelaufen",
      "botMayWarm": "Der Modellgegner wird möglicherweise noch vorbereitet.",
      "noResponse": "Der Tisch hat nicht rechtzeitig geantwortet.",
      "timeoutHint": "Versuchen Sie es gleich erneut. Wenn dies weiterhin geschieht, kehren Sie zur Lobby zurück und erstellen Sie einen neuen Tisch.",
      "reactMissing": "React-App nicht geladen…"
    },
    "chat": {
      "title": "Chat",
      "empty": "Noch keine Nachrichten.",
      "you": "Sie",
      "opponent": "Gegner",
      "placeholder": "Nachricht senden",
      "send": "Senden"
    },
    "game": {
      "tableGame": "Spiel am Tisch",
      "againstBot": "Sie spielen {color} gegen {bot}.",
      "againstHuman": "Sie spielen {color}. Teilen Sie diesen Tischnamen mit Ihrem Gegner, damit er demselben Tisch beitritt.",
      "host": "Gastgeber",
      "guest": "Gast",
      "turn": "Zug {number}",
      "currentPlayer": "Aktueller Spieler",
      "toMove": "{player} am Zug",
      "settingUp": "Der Tisch wird vorbereitet.",
      "waitingOpponent": "Warten auf einen Gegner.",
      "tavliAgreement": "Das Tavli-Ziel muss vor Spielbeginn vereinbart werden.",
      "margotAgreement": "„Margot die Geschlitzte“ muss vor Spielbeginn vereinbart werden.",
      "optionsAgreement": "Die Matchoptionen müssen vor Spielbeginn bestätigt werden.",
      "decisionRequired": "{player} muss eine Entscheidung für diesen Zug treffen.",
      "wonBy": "{winner} gewann mit {kind}.",
      "wonByPoints": "{winner} gewann mit {points} Vorsprung.",
      "drawnSettlement": "Ausgeglichene Abrechnung",
      "currentLeg": "Aktuelle Partie: {leg}",
      "seat": "Sitz",
      "youAre": "Sie spielen {color}",
      "seatWarning": "Sitzwarnung",
      "seatWanted": "Ein anderer Browser möchte diesen Platz einnehmen.",
      "reclaimingSeat": "{name} versucht, diesen Platz am Tisch zurückzuholen.",
      "remainWithin": "Klicken Sie innerhalb von etwa {seconds} {seconds, plural, one {Sekunde} other {Sekunden}} auf „Sitz behalten“, um von diesem Browser weiterzuspielen.",
      "remainSeated": "Sitz behalten",
      "dice": "Würfel",
      "noDice": "Noch kein Wurf.",
      "dieAlt": "Würfel {value}",
      "openingDieAlt": "Eröffnungswürfel für {color}: {value}",
      "movesLeft": "Verbleibende Züge: {moves}",
      "noMovesLeft": "keine",
      "awaitingRoll": "Warten auf den nächsten Wurf.",
      "lastMove": "{player} zog von {from} nach {to}.",
      "lastMoves": "{player} zog {moves}.",
      "moveSegment": "von {from} nach {to}",
      "listJoin": "{items} und {last}",
      "openingRoll": "Eröffnungswurf",
      "rollToStart": "Würfeln Sie, um zu bestimmen, wer beginnt.",
      "actions": "Aktionen",
      "roll": "Würfeln",
      "passDice": "Würfel weitergeben",
      "undo": "Rückgängig",
      "confirm": "Bestätigen",
      "newMatch": "Neues Match",
      "endTurn": "Zug beenden",
      "resign": "Aufgeben",
      "resignConfirm": "Match aufgeben?",
      "impuissance": "Stein ohne Zugmöglichkeit: {points} {points, plural, one {Punkt} other {Punkte}} für {color}.",
      "passDiceHint": "Keine legalen Züge verfügbar; geben Sie die Würfel an Ihren Gegner weiter.",
      "matchOptions": "Matchoptionen",
      "startMatch": "Match starten",
      "pregame": "Vor dem Spiel",
      "choosePregame": "Wählen Sie die Option vor dem Spiel.",
      "yourChoice": "Ihre Wahl",
      "colorChoice": "Wahl von {color}",
      "selectedTarget": "Gewähltes Ziel: {target}",
      "chooseTarget": "{target} wählen",
      "decision": "Entscheidung",
      "trictracTrack": "Trictrac-Spur",
      "match": "Match",
      "target": "Ziel",
      "bar": "Barre",
      "opponentBar": "Gegnerische Barre",
      "yourBar": "Ihre Barre",
      "bearOff": "Aus",
      "actionFailed": "Aktion fehlgeschlagen.",
      "soundUnavailable": "Ton nicht verfügbar",
      "soundOn": "Ton an",
      "soundOff": "Ton aus",
      "soundUnavailableTitle": "Ton ist in diesem Browser nicht verfügbar",
      "soundOffTitle": "Töne ausschalten",
      "soundOffLockedTitle": "Töne ausschalten. Der Ton wird beim nächsten Klick oder Tastendruck fortgesetzt.",
      "soundOnTitle": "Töne einschalten",
      "pack": "Paket",
      "packTitle": "Soundpaket auswählen"
    },
    "options": {
      "pointsToPlay": "Punktziel",
      "marquesToPlay": "Marqué-Ziel",
      "holesToPlay": "Lochziel",
      "matchLength": "Matchlänge",
      "doublesMode": "Doublettenmodus",
      "margot": "Margot die Geschlitzte",
      "enableMargot": "Margot aktivieren",
      "targetHoles": "Lochziel",
      "doubleScoring": "Doublettenwertung",
      "doublesOn": "Doublettenwertung ein",
      "doublesOff": "Doublettenwertung aus",
      "bestOf": "Best-of",
      "bestOfN": "Best-of-{count}",
      "tavliPrompt": "Wählen Sie das Tavli-Ziel. Bei Uneinigkeit gilt 7.",
      "margotPrompt": "Mit „Margot die Geschlitzte“ spielen?",
      "partieLengthPrompt": "Wählen Sie das Marqué-Ziel."
    },
    "units": {
      "point": "{count} {count, plural, one {Punkt} other {Punkte}}",
      "hole": "{count} {count, plural, one {Loch} other {Löcher}}",
      "game": "{count} {count, plural, one {Spiel} other {Spiele}}",
      "marque": "{count} {count, plural, one {marqué} other {marqués}}",
      "trou": "{count} {count, plural, one {Loch} other {Löcher}}",
      "jeton": "{count} {count, plural, one {Jeton} other {Jetons}}",
      "honneur": "{count} {count, plural, one {honneur} other {honneurs}}"
    },
    "score": {
      "wins": "{color} gewinnt {points} {points, plural, one {Punkt} other {Punkte}}",
      "event": "Wertungsereignis"
    },
    "scoreEvents": {
      "jan_rencontre": "Begegnungsjan",
      "jan_de_meseas": "Meseasjan",
      "contre_jan_de_meseas": "Contre-Meseasjan",
      "jan_de_deux_tables": "Jan auf zwei Steinen",
      "contre_jan_de_deux_tables": "Contre-Jan auf zwei Steinen",
      "jan_de_six_tables": "Jan auf sechs Steinen",
      "jan_recompense": "Belohnungsjan",
      "jan_qui_ne_peut": "Blindschlag",
      "coin_battu": "Hucke geschlagen",
      "coin_battu_a_faux": "Hucke blind geschlagen",
      "remplissage_petit": "Kleine Binde gemacht",
      "remplissage_grand": "Große Binde gemacht",
      "remplissage_retour": "Rückjan gemacht",
      "margot": "Margot die Geschlitzte",
      "impuissance": "Stein ohne Zugmöglichkeit",
      "conservation_petit": "Kleinen Jan gehalten",
      "conservation_grand": "Großen Jan gehalten",
      "conservation_retour": "Rückjan gehalten",
      "pile_misere": "Unglückshaufen",
      "sortie": "Steine aufgehoben"
    },
    "winnerKinds": {
      "grande_bredouille": "große Bredouille",
      "trous": "Löcher",
      "resign": "Aufgabe",
      "draw": "Remis"
    },
    "decision": {
      "reprise": "Wählen Sie, ob das Spiel fortgesetzt oder eine reprise genommen wird.",
      "suspension": "Wählen Sie, welche Spur ausgesetzt wird.",
      "suspendOneTrack": "Eine Spur aussetzen?",
      "continueMarque": "Wählen Sie, wie der marqué fortgesetzt wird.",
      "none": "Keine",
      "tenir": "Halten",
      "s'en aller": "Abgehen",
      "suspend_classique": "Honneurs aussetzen",
      "suspend_a_ecrire": "À écrire aussetzen"
    },
    "detail": {
      "bredouille": "Bredouille",
      "grandeBredouille": "Große Bredouille",
      "currentCoup": "Aktueller Wurf",
      "consolation": "Consolation",
      "lastMarque": "Letzter marqué",
      "lastHonneurs": "Letzte honneurs",
      "honneursState": "Honneurs-Stand",
      "suspension": "Suspension",
      "whiteSettlement": "Abrechnung für Weiß",
      "blackSettlement": "Abrechnung für Schwarz",
      "result": "Ergebnis",
      "whiteAEcrire": "À écrire für Weiß",
      "blackAEcrire": "À écrire für Schwarz",
      "whiteHonneurs": "Honneurs Weiß",
      "blackHonneurs": "Honneurs Schwarz",
      "queueJetons": "Queue der Jetons {value}",
      "marques": "Marqués {value}",
      "queueMarques": "Queue des marqués {value}",
      "final": "Endstand {value}",
      "noMarque": "Noch kein marqué wurde abgerechnet.",
      "refait": "Refait",
      "nextConsolation": "Nächste consolation {value}",
      "trouAgainst": "{winner} Löcher gegen {loser}",
      "voluntaryLoss": "Freiwillige Niederlage",
      "simpleMarque": "Einfacher marqué",
      "gainExact": "Exakter Gewinn {value}",
      "gainArrondi": "Gerundeter Gewinn {value}",
      "noHonneurs": "Noch keine honneurs-Partie wurde abgerechnet.",
      "wonClass": "{color} gewann {klass}",
      "noCarry": "Keine Übertragung",
      "carried": "{count} {count, plural, one {Loch} other {Löcher}} übertragen",
      "currentPartieWhite": "Aktuelle Partie für Weiß: {value}",
      "currentPartieBlack": "Aktuelle Partie für Schwarz: {value}",
      "honneursNear": "Honneurs kurz vor der Abrechnung",
      "honneursProgress": "Honneurs im Gang",
      "suspended": "Ausgesetzt: {track}",
      "frozenBy": "Gesperrt durch {color}",
      "resumesOnReleve": "Wird beim Relevé fortgesetzt",
      "beforeQueues": "{value} vor den Queues",
      "finalValue": "{value} Endstand",
      "nextJetons": "{value} Jetons als Nächstes",
      "noRefait": "Kein Refait",
      "refaitCount": "{count} {count, plural, one {Refait} other {Refaits}}",
      "partieTrous": "Partie-Löcher: {count}",
      "marquesProgress": "{count}/{total} marqués",
      "colorTrous": "{color}: {holes}",
      "pointsAndTrous": "{points} / {holes}",
      "compactClasses": "S/D/T/Q {value}"
    },
    "matchResult": {
      "gameDraw": "Partie {number}: {kind}{award}",
      "gameWin": "Partie {number}: {leg}{winner} gewann{award} mit {kind}"
    },
    "errors": {
      "unknown": "Unbekannter Fehler.",
      "unauthorized": "Nicht autorisiert.",
      "lobby_full": "Die Lobby ist voll.",
      "player_not_found": "Spieler nicht in der Lobby gefunden.",
      "match_over": "Das Match ist bereits beendet.",
      "not_your_turn": "Sie sind nicht am Zug.",
      "invalid_move": "Ungültiger Zug.",
      "no_rolled_dice": "Kein Wurf zum Bestätigen.",
      "turn_obligations": "Zugpflichten nicht erfüllt.",
      "coin_rest": "Die Hucke muss den Zug mit 0 oder mindestens 2 Steinen beenden.",
      "only_host_options": "Nur der Gastgeber kann Matchoptionen senden.",
      "variant_mismatch": "Dieser Tisch verwendet bereits ein anderes Spiel.",
      "reset_unavailable": "Zurücksetzen ist erst nach Matchende verfügbar.",
      "seat_reclaim_pending": "Sitzrückforderung angefordert.",
      "bot_unavailable": "Der gewählte Bot ist nicht verfügbar.",
      "action_failed": "Aktion fehlgeschlagen."
    }
  },
  "fr": {
    "appTitle": "HERMES Trictrac",
    "language": "Langue",
    "yes": "Oui",
    "no": "Non",
    "on": "Activé",
    "off": "Désactivé",
    "show": "Afficher",
    "hide": "Masquer",
    "none": "Aucun",
    "waiting": "En attente",
    "unknown": "inconnu",
    "someone": "Quelqu’un",
    "color": {
      "white": "Blancs",
      "black": "Noirs",
      "unknown": "Inconnu"
    },
    "colorSubject": {
      "white": "Les Blancs",
      "black": "Les Noirs",
      "unknown": "Inconnu"
    },
    "colorVictory": {
      "white": "des Blancs",
      "black": "des Noirs",
      "unknown": "d’un joueur inconnu"
    },
    "lobby": {
      "title": "Créer ou rejoindre une table",
      "lobbyName": "Nom de la table :",
      "userName": "Nom du joueur :",
      "playMode": "Mode de table",
      "headToHead": "Face à face",
      "multiSeat": "Multisiège",
      "chooseGame": "Choisir un jeu",
      "chooseMultiSeat": "Choisir une table multisiège",
      "multiSeatIntro": "Certaines tables multisièges font tourner une file, tandis que d'autres font tourner des joueurs nommés dans des rôles fixes. Choisissez un format et les réglages utiles apparaîtront ci-dessous.",
      "multiSeatTrictracPouleTitle": "Trictrac en poule",
      "multiSeatTrictracPouleMeta": "2 sièges actifs · file tournante",
      "multiSeatToccategliPouleTitle": "Toccategli en poule",
      "multiSeatToccategliPouleMeta": "2 sièges actifs · file tournante",
      "multiSeatTrictracPoulePlumeeTitle": "Trictrac en poule (plumée)",
      "multiSeatTrictracPoulePlumeeMeta": "anneau fixe · fonds commun",
      "multiSeatToccategliPoulePlumeeTitle": "Toccategli en poule (plumée)",
      "multiSeatToccategliPoulePlumeeMeta": "anneau fixe · fonds commun",
      "multiSeatAecrireTournerTitle": "Trictrac à écrire à tourner",
      "multiSeatAecrireTournerMeta": "3 joueurs · ronde",
      "multiSeatAecrireChouetteTitle": "Trictrac à écrire chouette",
      "multiSeatAecrireChouetteMeta": "3 joueurs · chouette",
      "multiSeatAecrireTeamsTitle": "Trictrac à écrire deux contre deux",
      "multiSeatAecrireTeamsMeta": "4 joueurs · deux camps",
      "multiSeatCombineChouetteTitle": "Trictrac combiné chouette",
      "multiSeatCombineChouetteMeta": "3 joueurs · chouette combinée",
      "multiSeatCombineTeamsTitle": "Trictrac combiné deux contre deux",
      "multiSeatCombineTeamsMeta": "4 joueurs · camps combinés",
      "queueSize": "Taille de la file :",
      "ante": "Ante :",
      "stake": "Mise de fonds :",
      "holeValue": "Valeur du trou :",
      "cashPerJeton": "Espèces par jeton :",
      "aEcrirePartieLength": "Longueur de la partie :",
      "multiSeatSpectatorsNote": "Les joueurs supplémentaires regardent comme spectateurs. Si une place dans l'effectif s'ouvre, un spectateur peut la prendre.",
      "multiSeatTurningTitle": "Trictrac à tourner",
      "multiSeatTurningMeta": "3 joueurs · table tournante",
      "multiSeatChouetteTitle": "Chouette",
      "multiSeatChouetteMeta": "3 joueurs · deux contre la chouette",
      "multiSeatFourForThemselvesTitle": "Quatre chacun pour soi",
      "multiSeatFourForThemselvesMeta": "4 joueurs · rotation individuelle",
      "multiSeatTwoAgainstTwoTitle": "Deux contre deux",
      "multiSeatTwoAgainstTwoMeta": "4 joueurs · partenaires fixes",
      "multiSeatStatus": "État",
      "multiSeatStatusNote": "Le parcours de lobby multisiège est en cours de câblage. Vous pouvez déjà cadrer le format de table, mais le lancement reste désactivé pour le moment.",
      "moreGames": "Autres jeux",
      "computerNote": "Les autres jeux ne sont pas encore disponibles contre l’ordinateur.",
      "opponent": "Adversaire",
      "playAgainst": "Jouer contre",
      "human": "Humain",
      "computer": "Ordinateur",
      "margot": "Margot",
      "botNote": "Le jeu contre l’ordinateur utilise BackgammonAI pour le backgammon anglais et le modèle actuel de Trictrac pour Trictrac classique, Trictrac à écrire, Trictrac combiné, Toc et Toccategli.",
      "enter": "Rejoindre la table",
      "multiSeatEnter": "Entrer à la table multisiège"
    },
    "join": {
      "joiningLabel": "Connexion à la table",
      "joinFailed": "Échec de la connexion",
      "tryAgain": "Réessayer",
      "backToLobby": "Retour au lobby",
      "connectingBot": "Connexion à la table et préparation du modèle. La première partie contre le bot peut prendre environ une minute.",
      "connecting": "Connexion à la table…",
      "slowBot": "Le modèle se prépare encore. La première connexion au bot peut prendre un peu de temps.",
      "slow": "Connexion à la table toujours en cours…",
      "seatReclaim": "Réclamation de siège demandée.",
      "reclaimRetry": "Si le navigateur qui occupe déjà le siège ne clique pas sur « Rester assis » dans environ {seconds} {seconds, plural, one {seconde} other {secondes}}, vous pourrez cliquer sur « Réessayer » pour reprendre le siège.",
      "reclaiming": "Reconnexion pour reprendre le siège…",
      "unable": "Impossible de rejoindre la table",
      "rejected": "La table a refusé cette demande.",
      "hint": "Essayez un autre nom de table, choisissez le même jeu que la table existante, ou demandez à un joueur assis de libérer une place.",
      "timedOut": "Connexion expirée",
      "botMayWarm": "L’adversaire modèle est peut-être encore en préparation.",
      "noResponse": "La table n’a pas répondu avant l’expiration du délai.",
      "timeoutHint": "Réessayez dans un instant. Si cela continue, revenez au lobby et créez une nouvelle table.",
      "reactMissing": "Application React non chargée…"
    },
    "chat": {
      "title": "Chat",
      "empty": "Aucun message pour l’instant.",
      "you": "Vous",
      "opponent": "Adversaire",
      "placeholder": "Envoyer un message",
      "send": "Envoyer"
    },
    "game": {
      "tableGame": "Jeu à la table",
      "againstBot": "Vous jouez les {color} contre {bot}.",
      "againstHuman": "Vous jouez les {color}. Partagez ce nom de table avec votre adversaire.",
      "host": "Hôte",
      "guest": "Invité",
      "turn": "Tour {number}",
      "currentPlayer": "Joueur actuel",
      "toMove": "À {player} de jouer",
      "settingUp": "La table se prépare.",
      "waitingOpponent": "En attente d’un adversaire.",
      "tavliAgreement": "La cible du Tavli doit être convenue avant le début de la partie.",
      "margotAgreement": "Margot la fendue doit être convenue avant le début de la partie.",
      "optionsAgreement": "Les options du match doivent être confirmées avant le début de la partie.",
      "decisionRequired": "{player} doit prendre une décision pour ce tour.",
      "wonBy": "Victoire {winner} par {kind}.",
      "wonByPoints": "Victoire {winner} par {points}.",
      "drawnSettlement": "Décompte à égalité",
      "currentLeg": "Partie actuelle : {leg}",
      "seat": "Siège",
      "youAre": "Vous jouez les {color}",
      "seatWarning": "Alerte de siège",
      "seatWanted": "Un autre navigateur veut reprendre ce siège.",
      "reclaimingSeat": "{name} tente de reprendre ce siège.",
      "remainWithin": "Cliquez sur « Rester assis » dans environ {seconds} {seconds, plural, one {seconde} other {secondes}} pour continuer depuis ce navigateur.",
      "remainSeated": "Rester assis",
      "dice": "Dés",
      "noDice": "Aucun dé n’a encore été lancé.",
      "dieAlt": "Dé {value}",
      "openingDieAlt": "Dé d’ouverture des {color} : {value}",
      "movesLeft": "Coups restants : {moves}",
      "noMovesLeft": "aucun",
      "awaitingRoll": "En attente du prochain lancer.",
      "lastMove": "{player} a joué de {from} à {to}.",
      "lastMoves": "{player} a joué {moves}.",
      "moveSegment": "de {from} à {to}",
      "listJoin": "{items} et {last}",
      "openingRoll": "Lancer d’ouverture",
      "rollToStart": "Lancez les dés pour décider qui commence.",
      "actions": "Actions",
      "roll": "Lancer",
      "passDice": "Passer les dés",
      "undo": "Annuler",
      "confirm": "Confirmer",
      "newMatch": "Nouveau match",
      "endTurn": "Terminer le tour",
      "resign": "Abandonner",
      "resignConfirm": "Abandonner le match ?",
      "impuissance": "Dame impuissante : {points} {points, plural, one {point} other {points}} aux {color}.",
      "passDiceHint": "Aucun coup légal n’est disponible ; passez les dés à votre adversaire.",
      "matchOptions": "Options du match",
      "startMatch": "Démarrer le match",
      "pregame": "Avant-partie",
      "choosePregame": "Choisissez l’option d’avant-partie.",
      "yourChoice": "Votre choix",
      "colorChoice": "Choix des {color}",
      "selectedTarget": "Objectif choisi : {target}",
      "chooseTarget": "Choisir {target}",
      "decision": "Décision",
      "trictracTrack": "Piste de trictrac",
      "match": "Match",
      "target": "Objectif",
      "bar": "Barre",
      "opponentBar": "Barre adverse",
      "yourBar": "Votre barre",
      "bearOff": "Sortie",
      "actionFailed": "Échec de l’action.",
      "soundUnavailable": "Son indisponible",
      "soundOn": "Son activé",
      "soundOff": "Son coupé",
      "soundUnavailableTitle": "Le son n’est pas disponible dans ce navigateur",
      "soundOffTitle": "Couper les sons",
      "soundOffLockedTitle": "Couper les sons. L’audio reprendra au prochain clic ou à la prochaine touche.",
      "soundOnTitle": "Activer les sons",
      "pack": "Pack sonore",
      "packTitle": "Choisir un pack sonore"
    },
    "options": {
      "pointsToPlay": "Objectif en points",
      "marquesToPlay": "Objectif en marqués",
      "holesToPlay": "Objectif en trous",
      "matchLength": "Durée du match",
      "doublesMode": "Mode des doublets",
      "margot": "Margot la fendue",
      "enableMargot": "Activer Margot",
      "targetHoles": "Trous visés",
      "doubleScoring": "Décompte des doublets",
      "doublesOn": "Doublets activés",
      "doublesOff": "Doublets désactivés",
      "bestOf": "Au meilleur de",
      "bestOfN": "Au meilleur de {count}",
      "tavliPrompt": "Choisissez la cible du Tavli. En cas de désaccord, l’objectif du match sera 7.",
      "margotPrompt": "Jouer avec Margot la fendue ?",
      "partieLengthPrompt": "Choisissez l’objectif en marqués."
    },
    "units": {
      "point": "{count} {count, plural, one {point} other {points}}",
      "hole": "{count} {count, plural, one {trou} other {trous}}",
      "game": "{count} {count, plural, one {partie} other {parties}}",
      "marque": "{count} {count, plural, one {marqué} other {marqués}}",
      "trou": "{count} {count, plural, one {trou} other {trous}}",
      "jeton": "{count} {count, plural, one {jeton} other {jetons}}",
      "honneur": "{count} {count, plural, one {honneur} other {honneurs}}"
    },
    "score": {
      "wins": "Les {color} marquent {points} {points, plural, one {point} other {points}}",
      "event": "événement de marque"
    },
    "scoreEvents": {
      "jan_rencontre": "jan de rencontre",
      "jan_de_meseas": "jan de mézéas",
      "contre_jan_de_meseas": "contre-jan de mézéas",
      "jan_de_deux_tables": "jan de deux tables",
      "contre_jan_de_deux_tables": "contre-jan de deux tables",
      "jan_de_six_tables": "jan de six tables",
      "jan_recompense": "jan de récompense",
      "jan_qui_ne_peut": "jan qui ne peut",
      "coin_battu": "coin battu",
      "coin_battu_a_faux": "coin battu à faux",
      "remplissage_petit": "remplissage du petit jan",
      "remplissage_grand": "remplissage du grand jan",
      "remplissage_retour": "remplissage du jan de retour",
      "margot": "Margot la fendue",
      "impuissance": "impuissance",
      "conservation_petit": "conservation du petit jan",
      "conservation_grand": "conservation du grand jan",
      "conservation_retour": "conservation du jan de retour",
      "pile_misere": "pile de misère",
      "sortie": "sortie"
    },
    "winnerKinds": {
      "grande_bredouille": "grande bredouille",
      "trous": "trous",
      "resign": "abandon",
      "draw": "nulle"
    },
    "decision": {
      "reprise": "Choisissez de continuer le jeu ou de prendre une reprise.",
      "suspension": "Choisissez la piste à suspendre.",
      "suspendOneTrack": "Suspendre une piste ?",
      "continueMarque": "Choisissez comment continuer le marqué.",
      "none": "Aucun",
      "tenir": "Tenir",
      "s'en aller": "S’en aller",
      "suspend_classique": "Suspendre les honneurs",
      "suspend_a_ecrire": "Suspendre l’à écrire"
    },
    "detail": {
      "bredouille": "Bredouille",
      "grandeBredouille": "Grande bredouille",
      "currentCoup": "Coup actuel",
      "consolation": "Consolation",
      "lastMarque": "Dernier marqué",
      "lastHonneurs": "Derniers honneurs",
      "honneursState": "État des honneurs",
      "suspension": "Suspension",
      "whiteSettlement": "Décompte des Blancs",
      "blackSettlement": "Décompte des Noirs",
      "result": "Résultat",
      "whiteAEcrire": "À écrire des Blancs",
      "blackAEcrire": "À écrire des Noirs",
      "whiteHonneurs": "Honneurs des Blancs",
      "blackHonneurs": "Honneurs des Noirs",
      "queueJetons": "Queue des jetons {value}",
      "marques": "Marqués {value}",
      "queueMarques": "Queue des marqués {value}",
      "final": "Total final {value}",
      "noMarque": "Aucun marqué n’a encore été décompté.",
      "refait": "Refait",
      "nextConsolation": "Prochaine consolation {value}",
      "trouAgainst": "{winner} trous contre {loser}",
      "voluntaryLoss": "Défaite volontaire",
      "simpleMarque": "Marqué simple",
      "gainExact": "Gain exact {value}",
      "gainArrondi": "Gain arrondi {value}",
      "noHonneurs": "Aucune partie d’honneurs n’a encore été décomptée.",
      "wonClass": "Victoire des {color} : {klass}",
      "noCarry": "Aucun report",
      "carried": "{count} {count, plural, one {trou reporté} other {trous reportés}}",
      "currentPartieWhite": "Partie actuelle des Blancs : {value}",
      "currentPartieBlack": "Partie actuelle des Noirs : {value}",
      "honneursNear": "Honneurs bientôt décomptés",
      "honneursProgress": "Honneurs en cours",
      "suspended": "Suspension : {track}",
      "frozenBy": "Bloqué par les {color}",
      "resumesOnReleve": "Reprend au relevé",
      "beforeQueues": "{value} avant les queues",
      "finalValue": "{value} au total",
      "nextJetons": "{value} jetons ensuite",
      "noRefait": "Aucun refait",
      "refaitCount": "{count} {count, plural, one {refait} other {refaits}}",
      "partieTrous": "{count} trous de partie",
      "marquesProgress": "{count}/{total} marqués",
      "colorTrous": "{color} : {holes}",
      "pointsAndTrous": "{points} / {holes}",
      "compactClasses": "S/D/T/Q {value}"
    },
    "matchResult": {
      "gameDraw": "Partie {number} : {kind}{award}",
      "gameWin": "Partie {number} : {leg}victoire {winner}{award} par {kind}"
    },
    "errors": {
      "unknown": "Erreur inconnue.",
      "unauthorized": "Non autorisé.",
      "lobby_full": "La table est pleine.",
      "player_not_found": "Joueur introuvable dans le lobby.",
      "match_over": "Le match est déjà terminé.",
      "not_your_turn": "Ce n’est pas votre tour.",
      "invalid_move": "Coup invalide.",
      "no_rolled_dice": "Aucun dé lancé à confirmer.",
      "turn_obligations": "Obligations du tour non remplies.",
      "coin_rest": "Le coin de repos doit finir le tour avec 0 ou au moins 2 dames.",
      "only_host_options": "Seul l’hôte peut envoyer les options du match.",
      "variant_mismatch": "Cette table utilise déjà un autre jeu.",
      "reset_unavailable": "La remise à zéro n’est disponible qu’une fois le match terminé.",
      "seat_reclaim_pending": "Réclamation de siège demandée.",
      "bot_unavailable": "Le bot choisi n’est pas disponible.",
      "action_failed": "Échec de l’action."
    }
  },
  "sv": {
    "appTitle": "HERMES Trictrac",
    "language": "Språk",
    "yes": "Ja",
    "no": "Nej",
    "on": "På",
    "off": "Av",
    "show": "Visa",
    "hide": "Dölj",
    "none": "Ingen",
    "waiting": "Väntar",
    "unknown": "Okänd",
    "someone": "Någon",
    "color": {
      "white": "Vit",
      "black": "Svart",
      "unknown": "Okänd"
    },
    "colorSubject": {
      "white": "Vit",
      "black": "Svart",
      "unknown": "Okänd"
    },
    "lobby": {
      "title": "Starta eller anslut till ett bord",
      "lobbyName": "Bordsnamn:",
      "userName": "Spelarnamn:",
      "playMode": "Bordsläge",
      "headToHead": "Man mot man",
      "multiSeat": "Flera platser",
      "chooseGame": "Välj spel",
      "chooseMultiSeat": "Välj flerplatsbord",
      "multiSeatIntro": "Vissa flerplatsbord roterar en kö, medan andra roterar namngivna spelare genom fasta roller. Välj ett format så visas rätt inställningar nedan.",
      "multiSeatTrictracPouleTitle": "Trictrac en poule",
      "multiSeatTrictracPouleMeta": "2 aktiva platser · roterande kö",
      "multiSeatToccategliPouleTitle": "Toccategli en poule",
      "multiSeatToccategliPouleMeta": "2 aktiva platser · roterande kö",
      "multiSeatTrictracPoulePlumeeTitle": "Trictrac en poule (plumée)",
      "multiSeatTrictracPoulePlumeeMeta": "fast ring · gemensam fond",
      "multiSeatToccategliPoulePlumeeTitle": "Toccategli en poule (plumée)",
      "multiSeatToccategliPoulePlumeeMeta": "fast ring · gemensam fond",
      "multiSeatAecrireTournerTitle": "Trictrac à écrire à tourner",
      "multiSeatAecrireTournerMeta": "3 spelare · rondgång",
      "multiSeatAecrireChouetteTitle": "Trictrac à écrire chouette",
      "multiSeatAecrireChouetteMeta": "3 spelare · chouette",
      "multiSeatAecrireTeamsTitle": "Trictrac à écrire deux contre deux",
      "multiSeatAecrireTeamsMeta": "4 spelare · två sidor",
      "multiSeatCombineChouetteTitle": "Trictrac combiné chouette",
      "multiSeatCombineChouetteMeta": "3 spelare · kombinerad chouette",
      "multiSeatCombineTeamsTitle": "Trictrac combiné deux contre deux",
      "multiSeatCombineTeamsMeta": "4 spelare · kombinerade lag",
      "queueSize": "Köstorlek:",
      "ante": "Insats:",
      "stake": "Fondinsats:",
      "holeValue": "Hålvärde:",
      "cashPerJeton": "Kontanter per jeton:",
      "aEcrirePartieLength": "Partilängd:",
      "multiSeatSpectatorsNote": "Fler deltagare tittar som åskådare. Om en plats i uppställningen öppnas kan en åskådare ta den.",
      "multiSeatTurningTitle": "Trictrac à tourner",
      "multiSeatTurningMeta": "3 spelare · roterande bord",
      "multiSeatChouetteTitle": "Chouette",
      "multiSeatChouetteMeta": "3 spelare · två mot banken",
      "multiSeatFourForThemselvesTitle": "Fyra var för sig",
      "multiSeatFourForThemselvesMeta": "4 spelare · roterande enskilt spel",
      "multiSeatTwoAgainstTwoTitle": "Två mot två",
      "multiSeatTwoAgainstTwoMeta": "4 spelare · fasta partner",
      "multiSeatStatus": "Status",
      "multiSeatStatusNote": "Flödet för flerplatslobbyn håller på att kopplas upp. Du kan avgränsa bordsformatet redan nu, men start av spel är tills vidare avstängt.",
      "moreGames": "Fler spel",
      "computerNote": "Fler spel är ännu inte tillgängliga mot datorn.",
      "opponent": "Motståndare",
      "playAgainst": "Spela mot",
      "human": "Människa",
      "computer": "Dator",
      "margot": "Margot",
      "botNote": "Spel mot datorn använder BackgammonAI för engelskt backgammon och den aktuella Trictrac-modellen för Trictrac classique, Trictrac à écrire, Trictrac combiné, Toc och Toccategli.",
      "enter": "Gå till bordet",
      "multiSeatEnter": "Gå in vid flersätesbordet"
    },
    "join": {
      "joiningLabel": "Ansluter till bordet",
      "joinFailed": "Anslutning misslyckades",
      "tryAgain": "Försök igen",
      "backToLobby": "Tillbaka till lobbyn",
      "connectingBot": "Ansluter till bordet och värmer upp modellen. Det första botpartiet kan ta omkring en minut.",
      "connecting": "Ansluter till bordet…",
      "slowBot": "Modellen värms fortfarande upp. Den första botanslutningen kan ta lite tid.",
      "slow": "Ansluter fortfarande till bordet…",
      "seatReclaim": "Återtagning av plats begärd.",
      "reclaimRetry": "Om webbläsaren som redan har platsen inte klickar på ”Behåll platsen” inom cirka {seconds} {seconds, plural, one {sekund} other {sekunder}}, kan du klicka på ”Försök igen” för att återta platsen.",
      "reclaiming": "Ansluter igen för att återta platsen…",
      "unable": "Kunde inte ansluta till bordet",
      "rejected": "Bordet avvisade anslutningen.",
      "hint": "Prova ett annat bordsnamn, matcha det befintliga bordets speltyp eller be en sittande spelare lämna plats.",
      "timedOut": "Anslutningen tog för lång tid",
      "botMayWarm": "Modellmotståndaren kan fortfarande värmas upp.",
      "noResponse": "Bordet svarade inte innan tidsgränsen.",
      "timeoutHint": "Försök igen om en stund. Om det fortsätter, gå tillbaka till lobbyn och skapa ett nytt bord.",
      "reactMissing": "React-appen har inte laddats…"
    },
    "chat": {
      "title": "Chatt",
      "empty": "Inga meddelanden än.",
      "you": "Du",
      "opponent": "Motståndare",
      "placeholder": "Skicka ett meddelande",
      "send": "Skicka"
    },
    "game": {
      "tableGame": "Spel vid bordet",
      "againstBot": "Du spelar {color} mot {bot}.",
      "againstHuman": "Du spelar {color}. Dela bordsnamnet med din motståndare.",
      "host": "Värd",
      "guest": "Gäst",
      "turn": "Tur {number}",
      "currentPlayer": "Aktuell spelare",
      "toMove": "{player} ska spela",
      "settingUp": "Bordet förbereds.",
      "waitingOpponent": "Väntar på en motståndare.",
      "seat": "Plats",
      "youAre": "Du spelar {color}",
      "actions": "Åtgärder",
      "roll": "Kasta",
      "passDice": "Lämna över tärningarna",
      "undo": "Ångra",
      "confirm": "Bekräfta",
      "newMatch": "Ny match",
      "endTurn": "Avsluta turen",
      "resign": "Ge upp",
      "resignConfirm": "Ge upp matchen?",
      "match": "Match",
      "bar": "Baren",
      "dice": "Tärningar",
      "openingRoll": "Startkast",
      "rollToStart": "Kasta för att avgöra vem som börjar.",
      "tavliAgreement": "Tavli-målet måste vara överenskommet före spelstart.",
      "margotAgreement": "Margot den kluvna måste vara överenskommen före spelstart.",
      "optionsAgreement": "Matchalternativen måste bekräftas innan spelet börjar.",
      "decisionRequired": "{player} måste fatta ett beslut för denna tur.",
      "wonBy": "{winner} vann med {kind}.",
      "wonByPoints": "{winner} vann med {points}.",
      "drawnSettlement": "Oavgjord avräkning",
      "currentLeg": "Aktuellt parti: {leg}",
      "seatWarning": "Platsvarning",
      "seatWanted": "En annan webbläsare vill återta denna plats.",
      "reclaimingSeat": "{name} försöker återta platsen vid bordet.",
      "remainWithin": "Klicka på ”Behåll platsen” inom cirka {seconds} {seconds, plural, one {sekund} other {sekunder}} för att fortsätta spela från denna webbläsare.",
      "remainSeated": "Behåll platsen",
      "noDice": "Inget kast än.",
      "dieAlt": "Tärning {value}",
      "openingDieAlt": "Öppningstärning för {color}: {value}",
      "movesLeft": "Drag kvar: {moves}",
      "noMovesLeft": "inga",
      "awaitingRoll": "Väntar på nästa kast.",
      "lastMove": "{player} flyttade från {from} till {to}.",
      "lastMoves": "{player} flyttade {moves}.",
      "moveSegment": "från {from} till {to}",
      "listJoin": "{items} och {last}",
      "soundOn": "Ljud på",
      "soundOff": "Ljud av",
      "soundUnavailable": "Ljud inte tillgängligt",
      "soundUnavailableTitle": "Ljud är inte tillgängligt i denna webbläsare",
      "soundOffTitle": "Stäng av ljud",
      "soundOffLockedTitle": "Stäng av ljud. Ljudet återupptas vid nästa klick eller tangenttryckning.",
      "soundOnTitle": "Slå på ljud",
      "matchOptions": "Matchalternativ",
      "startMatch": "Starta match",
      "pregame": "Före spelet",
      "choosePregame": "Välj alternativ före spelet.",
      "yourChoice": "Ditt val",
      "colorChoice": "Val för {color}",
      "selectedTarget": "Valt mål: {target}",
      "chooseTarget": "Välj {target}",
      "decision": "Beslut",
      "trictracTrack": "Trictrac-spår",
      "target": "Mål",
      "opponentBar": "Motståndarens bar",
      "yourBar": "Din bar",
      "bearOff": "Ta upp",
      "actionFailed": "Åtgärden misslyckades.",
      "impuissance": "Bricka utan dragmöjlighet: {points} {points, plural, one {poäng} other {poäng}} till {color}.",
      "passDiceHint": "Inga lagliga drag finns; lämna över tärningarna till motståndaren.",
      "pack": "Paket",
      "packTitle": "Välj ljudpaket"
    },
    "options": {
      "pointsToPlay": "Poängmål",
      "marquesToPlay": "Marqué-mål",
      "holesToPlay": "Hålmål",
      "matchLength": "Matchlängd",
      "doublesMode": "Doublettläge",
      "margot": "Margot den kluvna",
      "enableMargot": "Aktivera Margot",
      "targetHoles": "Hålmål",
      "doubleScoring": "Doubletträkning",
      "doublesOn": "Doubletter på",
      "doublesOff": "Doubletter av",
      "bestOf": "Bäst av",
      "bestOfN": "Bäst av {count}",
      "tavliPrompt": "Välj Tavli-mål. Vid oenighet blir målet 7.",
      "margotPrompt": "Spela med Margot den kluvna?",
      "partieLengthPrompt": "Välj marqué-mål."
    },
    "units": {
      "point": "{count} {count, plural, one {poäng} other {poäng}}",
      "hole": "{count} {count, plural, one {hål} other {hål}}",
      "game": "{count} {count, plural, one {parti} other {partier}}",
      "marque": "{count} {count, plural, one {marqué} other {marqués}}",
      "trou": "{count} {count, plural, one {hål} other {hål}}",
      "jeton": "{count} {count, plural, one {jeton} other {jetoner}}",
      "honneur": "{count} {count, plural, one {honneur} other {honneurs}}"
    },
    "score": {
      "wins": "{color} får {points} {points, plural, one {poäng} other {poäng}}",
      "event": "poänghändelse"
    },
    "scoreEvents": {
      "jan_rencontre": "mötes-Jan",
      "jan_de_meseas": "Messeas-Jan",
      "contre_jan_de_meseas": "Contre-Messeas-Jan",
      "jan_de_deux_tables": "Jan med 2 brickor",
      "contre_jan_de_deux_tables": "Contre-Jan med 2 brickor",
      "jan_de_six_tables": "Jan av 6 brickor",
      "jan_recompense": "belöningsjan",
      "jan_qui_ne_peut": "blint slag",
      "coin_battu": "huken slagen",
      "coin_battu_a_faux": "huken slagen blint",
      "remplissage_petit": "Lilla Jan fylld",
      "remplissage_grand": "Stora Jan fylld",
      "remplissage_retour": "Bak-Jan fylld",
      "margot": "Margot den kluvna",
      "impuissance": "bricka utan dragmöjlighet",
      "conservation_petit": "Lilla Jan bibehållen",
      "conservation_grand": "Stora Jan bibehållen",
      "conservation_retour": "Bak-Jan bibehållen",
      "pile_misere": "olyckshög",
      "sortie": "brickorna upptagna"
    },
    "winnerKinds": {
      "grande_bredouille": "grand bredouille",
      "trous": "hål",
      "resign": "uppgivning",
      "draw": "remi"
    },
    "decision": {
      "reprise": "Välj om spelet ska fortsätta eller om en reprise ska tas.",
      "suspension": "Välj vilket spår som ska suspenderas.",
      "suspendOneTrack": "Suspendera ett spår?",
      "continueMarque": "Välj hur marqué ska fortsätta.",
      "none": "Ingen",
      "tenir": "Hålla",
      "s'en aller": "Avgå",
      "suspend_classique": "Suspendera honneurs",
      "suspend_a_ecrire": "Suspendera à écrire"
    },
    "detail": {
      "bredouille": "Bredouille",
      "grandeBredouille": "Stora bredouille",
      "currentCoup": "Aktuellt kast",
      "consolation": "Consolation",
      "lastMarque": "Senaste marqué",
      "lastHonneurs": "Senaste honneurs",
      "honneursState": "Honneurs-status",
      "suspension": "Suspension",
      "whiteSettlement": "Avräkning för vit",
      "blackSettlement": "Avräkning för svart",
      "result": "Resultat",
      "whiteAEcrire": "À écrire för vit",
      "blackAEcrire": "À écrire för svart",
      "whiteHonneurs": "Honneurs för vit",
      "blackHonneurs": "Honneurs för svart",
      "queueJetons": "Jetonkö {value}",
      "marques": "Marqués {value}",
      "queueMarques": "Queue des marqués {value}",
      "final": "Slutvärde {value}",
      "noMarque": "Inget marqué har avräknats än.",
      "refait": "Refait",
      "nextConsolation": "Nästa consolation {value}",
      "trouAgainst": "{winner} hål mot {loser}",
      "voluntaryLoss": "Frivillig förlust",
      "simpleMarque": "Enkel marqué",
      "gainExact": "Exakt vinst {value}",
      "gainArrondi": "Avrundad vinst {value}",
      "noHonneurs": "Ingen honneurs-partie har avräknats än.",
      "wonClass": "{color} vann {klass}",
      "noCarry": "Ingen överföring",
      "carried": "{count} {count, plural, one {hål överfört} other {hål överförda}}",
      "currentPartieWhite": "Aktuellt parti för vit: {value}",
      "currentPartieBlack": "Aktuellt parti för svart: {value}",
      "honneursNear": "Honneurs nära avräkning",
      "honneursProgress": "Honneurs pågår",
      "suspended": "Suspenderat: {track}",
      "frozenBy": "Låst av {color}",
      "resumesOnReleve": "Fortsätter vid relevé",
      "beforeQueues": "{value} före köer",
      "finalValue": "{value} slutvärde",
      "nextJetons": "Nästa jetoner: {value}",
      "noRefait": "Inget refait",
      "refaitCount": "{count} {count, plural, one {refait} other {refaits}}",
      "partieTrous": "Partihål: {count}",
      "marquesProgress": "{count}/{total} marqués",
      "colorTrous": "{color}: {holes}",
      "pointsAndTrous": "{points} / {holes}",
      "compactClasses": "S/D/T/Q {value}"
    },
    "matchResult": {
      "gameDraw": "Parti {number}: {kind}{award}",
      "gameWin": "Parti {number}: {leg}{winner} vann{award} med {kind}"
    },
    "errors": {
      "unknown": "Okänt fel.",
      "unauthorized": "Obehörig.",
      "lobby_full": "Bordet är fullt.",
      "player_not_found": "Spelaren finns inte i lobbyn.",
      "match_over": "Matchen är redan slut.",
      "not_your_turn": "Det är inte din tur.",
      "invalid_move": "Ogiltigt drag.",
      "no_rolled_dice": "Inga kastade tärningar att bekräfta.",
      "turn_obligations": "Turens krav är inte uppfyllda.",
      "coin_rest": "Huken måste avsluta turen med 0 eller minst 2 brickor.",
      "only_host_options": "Endast värden kan skicka matchalternativ.",
      "variant_mismatch": "Det här bordet använder redan ett annat spel.",
      "reset_unavailable": "Återställning är bara möjlig efter matchens slut.",
      "seat_reclaim_pending": "Återtagning av plats begärd.",
      "bot_unavailable": "Den valda boten är inte tillgänglig.",
      "action_failed": "Åtgärden misslyckades."
    }
  },
  "da": {
    "appTitle": "HERMES Trictrac",
    "language": "Sprog",
    "yes": "Ja",
    "no": "Nej",
    "on": "Til",
    "off": "Fra",
    "show": "Vis",
    "hide": "Skjul",
    "none": "Ingen",
    "waiting": "Venter",
    "unknown": "ukendt",
    "someone": "Nogen",
    "color": {
      "white": "Hvid",
      "black": "Sort",
      "unknown": "Ukendt"
    },
    "colorSubject": {
      "white": "Hvid",
      "black": "Sort",
      "unknown": "Ukendt"
    },
    "lobby": {
      "title": "Opret eller slut dig til et bord",
      "lobbyName": "Bordnavn:",
      "userName": "Spillernavn:",
      "playMode": "Bordtilstand",
      "headToHead": "En mod en",
      "multiSeat": "Flere pladser",
      "chooseGame": "Vælg spil",
      "chooseMultiSeat": "Vælg flersædebord",
      "multiSeatIntro": "Nogle flersædeborde roterer en kø, mens andre roterer navngivne spillere gennem faste roller. Vælg et format, så vises de relevante indstillinger nedenfor.",
      "multiSeatTrictracPouleTitle": "Trictrac en poule",
      "multiSeatTrictracPouleMeta": "2 aktive pladser · roterende kø",
      "multiSeatToccategliPouleTitle": "Toccategli en poule",
      "multiSeatToccategliPouleMeta": "2 aktive pladser · roterende kø",
      "multiSeatTrictracPoulePlumeeTitle": "Trictrac en poule (plumée)",
      "multiSeatTrictracPoulePlumeeMeta": "fast ring · fælles fond",
      "multiSeatToccategliPoulePlumeeTitle": "Toccategli en poule (plumée)",
      "multiSeatToccategliPoulePlumeeMeta": "fast ring · fælles fond",
      "multiSeatAecrireTournerTitle": "Trictrac à écrire à tourner",
      "multiSeatAecrireTournerMeta": "3 spillere · rundgang",
      "multiSeatAecrireChouetteTitle": "Trictrac à écrire chouette",
      "multiSeatAecrireChouetteMeta": "3 spillere · chouette",
      "multiSeatAecrireTeamsTitle": "Trictrac à écrire deux contre deux",
      "multiSeatAecrireTeamsMeta": "4 spillere · to sider",
      "multiSeatCombineChouetteTitle": "Trictrac combiné chouette",
      "multiSeatCombineChouetteMeta": "3 spillere · kombineret chouette",
      "multiSeatCombineTeamsTitle": "Trictrac combiné deux contre deux",
      "multiSeatCombineTeamsMeta": "4 spillere · kombinerede sider",
      "queueSize": "Køstørrelse:",
      "ante": "Indsats:",
      "stake": "Fondindsats:",
      "holeValue": "Hulværdi:",
      "cashPerJeton": "Kontanter pr. jeton:",
      "aEcrirePartieLength": "Partilængde:",
      "multiSeatSpectatorsNote": "Ekstra deltagere ser med som tilskuere. Hvis en plads i opstillingen åbner sig, kan en tilskuer tage den.",
      "multiSeatTurningTitle": "Trictrac à tourner",
      "multiSeatTurningMeta": "3 spillere · roterende bord",
      "multiSeatChouetteTitle": "Chouette",
      "multiSeatChouetteMeta": "3 spillere · to mod banken",
      "multiSeatFourForThemselvesTitle": "Fire hver for sig",
      "multiSeatFourForThemselvesMeta": "4 spillere · roterende enkeltspil",
      "multiSeatTwoAgainstTwoTitle": "To mod to",
      "multiSeatTwoAgainstTwoMeta": "4 spillere · faste partnere",
      "multiSeatStatus": "Status",
      "multiSeatStatusNote": "Flowet til flersæde-lobbyen er ved at blive koblet på. Du kan allerede afgrænse bordformatet nu, men start af spil er foreløbig slået fra.",
      "moreGames": "Flere spil",
      "computerNote": "Flere spil er endnu ikke tilgængelige mod computeren.",
      "opponent": "Modstander",
      "playAgainst": "Spil mod",
      "human": "Menneske",
      "computer": "Computer",
      "margot": "Margot",
      "botNote": "Spil mod computeren bruger BackgammonAI til engelsk backgammon og den aktuelle Trictrac-model til Trictrac classique, Trictrac à écrire, Trictrac combiné, Toc og Toccategli.",
      "enter": "Gå til bordet",
      "multiSeatEnter": "Gå til flersædebord"
    },
    "join": {
      "joiningLabel": "Forbinder til bordet",
      "joinFailed": "Forbindelse mislykkedes",
      "tryAgain": "Prøv igen",
      "backToLobby": "Tilbage til lobbyen",
      "connectingBot": "Forbinder til bordet og varmer modellen op. Det første spil mod botten kan tage omkring et minut.",
      "connecting": "Forbinder til bordet…",
      "slowBot": "Modellen varmes stadig op. Den første forbindelse til botten kan tage lidt tid.",
      "slow": "Forbinder stadig til bordet…",
      "seatReclaim": "Anmodning om at overtage pladsen.",
      "reclaimRetry": "Hvis den browser, der allerede har pladsen, ikke klikker på »Behold pladsen« inden cirka {seconds} {seconds, plural, one {sekund} other {sekunder}}, kan du klikke på »Prøv igen« for at overtage pladsen.",
      "reclaiming": "Forbinder igen for at overtage pladsen…",
      "unable": "Kunne ikke deltage ved bordet",
      "rejected": "Bordet afviste denne anmodning.",
      "hint": "Prøv et andet bordnavn, vælg samme spiltype som det eksisterende bord, eller bed en siddende spiller gøre plads.",
      "timedOut": "Forbindelsen udløb",
      "botMayWarm": "Modelmodstanderen er måske stadig ved at varme op.",
      "noResponse": "Bordet svarede ikke før tidsfristen.",
      "timeoutHint": "Prøv igen om lidt. Hvis det fortsætter, så gå tilbage til lobbyen og opret et nyt bord.",
      "reactMissing": "React-appen er ikke indlæst…"
    },
    "chat": {
      "title": "Chat",
      "empty": "Ingen beskeder endnu.",
      "you": "Du",
      "opponent": "Modstander",
      "placeholder": "Send en besked",
      "send": "Send"
    },
    "game": {
      "tableGame": "Spil ved bordet",
      "againstBot": "Du spiller {color} mod {bot}.",
      "againstHuman": "Du spiller {color}. Del bordnavnet med din modstander.",
      "host": "Vært",
      "guest": "Gæst",
      "turn": "Tur {number}",
      "currentPlayer": "Aktuel spiller",
      "toMove": "{player} skal spille",
      "settingUp": "Bordet gøres klar.",
      "waitingOpponent": "Venter på en modstander.",
      "seat": "Plads",
      "youAre": "Du spiller {color}",
      "actions": "Handlinger",
      "roll": "Kast",
      "passDice": "Giv terningerne videre",
      "undo": "Fortryd",
      "confirm": "Bekræft",
      "newMatch": "Ny match",
      "endTurn": "Afslut turen",
      "resign": "Opgiv",
      "resignConfirm": "Opgiv matchen?",
      "match": "Match",
      "bar": "Baren",
      "dice": "Terninger",
      "openingRoll": "Startkast",
      "rollToStart": "Kast for at afgøre, hvem der begynder.",
      "tavliAgreement": "Tavli-målet skal aftales, før spillet begynder.",
      "margotAgreement": "Margot med sprækken skal aftales, før spillet begynder.",
      "optionsAgreement": "Matchindstillingerne skal bekræftes, før spillet begynder.",
      "decisionRequired": "{player} skal træffe en beslutning for denne tur.",
      "wonBy": "{winner} vandt med {kind}.",
      "wonByPoints": "{winner} vandt med {points}.",
      "drawnSettlement": "Uafgjort afregning",
      "currentLeg": "Aktuelt parti: {leg}",
      "seatWarning": "Pladsadvarsel",
      "seatWanted": "En anden browser vil overtage denne plads.",
      "reclaimingSeat": "{name} prøver at overtage denne bordplads.",
      "remainWithin": "Klik på »Behold pladsen« inden cirka {seconds} {seconds, plural, one {sekund} other {sekunder}} for at fortsætte fra denne browser.",
      "remainSeated": "Behold pladsen",
      "noDice": "Intet kast endnu.",
      "dieAlt": "Terning {value}",
      "openingDieAlt": "Åbningsterning for {color}: {value}",
      "movesLeft": "Resterende træk: {moves}",
      "noMovesLeft": "ingen",
      "awaitingRoll": "Venter på næste kast.",
      "lastMove": "{player} flyttede fra {from} til {to}.",
      "lastMoves": "{player} flyttede {moves}.",
      "moveSegment": "fra {from} til {to}",
      "listJoin": "{items} og {last}",
      "soundOn": "Lyd til",
      "soundOff": "Lyd fra",
      "soundUnavailable": "Lyd ikke tilgængelig",
      "soundUnavailableTitle": "Lyd er ikke tilgængelig i denne browser",
      "soundOffTitle": "Slå lyd fra",
      "soundOffLockedTitle": "Slå lyd fra. Lyden genoptages ved næste klik eller tastetryk.",
      "soundOnTitle": "Slå lyd til",
      "matchOptions": "Matchindstillinger",
      "startMatch": "Start match",
      "pregame": "Før spillet",
      "choosePregame": "Vælg indstilling før spillet.",
      "yourChoice": "Dit valg",
      "colorChoice": "Valg for {color}",
      "selectedTarget": "Valgt mål: {target}",
      "chooseTarget": "Vælg {target}",
      "decision": "Beslutning",
      "trictracTrack": "Trictrac-spor",
      "target": "Mål",
      "opponentBar": "Modstanderens bar",
      "yourBar": "Din bar",
      "bearOff": "Tag op",
      "actionFailed": "Handlingen mislykkedes.",
      "impuissance": "Brik uden trækmulighed: {points} {points, plural, one {point} other {point}} til {color}.",
      "passDiceHint": "Der er ingen lovlige træk; giv terningerne videre til modstanderen.",
      "pack": "Pakke",
      "packTitle": "Vælg lydpakke"
    },
    "options": {
      "pointsToPlay": "Pointmål",
      "marquesToPlay": "Marqué-mål",
      "holesToPlay": "Hulmål",
      "matchLength": "Matchlængde",
      "doublesMode": "Doublettetilstand",
      "margot": "Margot med sprækken",
      "enableMargot": "Aktivér Margot",
      "targetHoles": "Hulmål",
      "doubleScoring": "Doubletteoptælling",
      "doublesOn": "Doubletter til",
      "doublesOff": "Doubletter fra",
      "bestOf": "Bedst af",
      "bestOfN": "Bedst af {count}",
      "tavliPrompt": "Vælg Tavli-målet. Ved uenighed bliver målet 7.",
      "margotPrompt": "Spil med »Margot med sprækken«?",
      "partieLengthPrompt": "Vælg marqué-mål."
    },
    "units": {
      "point": "{count} {count, plural, one {point} other {point}}",
      "hole": "{count} {count, plural, one {hul} other {huller}}",
      "game": "{count} {count, plural, one {parti} other {partier}}",
      "marque": "{count} {count, plural, one {marqué} other {marqués}}",
      "trou": "{count} {count, plural, one {hul} other {huller}}",
      "jeton": "{count} {count, plural, one {jeton} other {jetoner}}",
      "honneur": "{count} {count, plural, one {honneur} other {honneurs}}"
    },
    "score": {
      "wins": "{color} får {points} {points, plural, one {point} other {point}}",
      "event": "scoringshændelse"
    },
    "scoreEvents": {
      "jan_rencontre": "mødejan",
      "jan_de_meseas": "meseasjan",
      "contre_jan_de_meseas": "contrameseasjan",
      "jan_de_deux_tables": "jan i to brikker",
      "contre_jan_de_deux_tables": "contrajan i to brikker",
      "jan_de_six_tables": "jan i seks brikker",
      "jan_recompense": "belønningsjan",
      "jan_qui_ne_peut": "blindt slag",
      "coin_battu": "hukken slået",
      "coin_battu_a_faux": "hukken slået uden ret",
      "remplissage_petit": "den lille jan lukket",
      "remplissage_grand": "den store jan lukket",
      "remplissage_retour": "rukjanen lukket",
      "margot": "Margot med sprækken",
      "impuissance": "brik uden trækmulighed",
      "conservation_petit": "den lille jan holdt",
      "conservation_grand": "den store jan holdt",
      "conservation_retour": "rukjanen holdt",
      "pile_misere": "ulykkeshob",
      "sortie": "brikkerne taget op"
    },
    "winnerKinds": {
      "grande_bredouille": "parti bredouille",
      "trous": "huller",
      "resign": "opgivelse",
      "draw": "uafgjort"
    },
    "decision": {
      "reprise": "Vælg, om spillet skal fortsætte, eller om der skal tages en reprise.",
      "suspension": "Vælg, hvilket spor der skal suspenderes.",
      "suspendOneTrack": "Suspendér et spor?",
      "continueMarque": "Vælg, hvordan marqué skal fortsætte.",
      "none": "Ingen",
      "tenir": "Holde",
      "s'en aller": "Gå af",
      "suspend_classique": "Suspendér honneurs",
      "suspend_a_ecrire": "Suspendér à écrire"
    },
    "detail": {
      "bredouille": "Bredouille",
      "grandeBredouille": "Grande bredouille",
      "currentCoup": "Aktuelt kast",
      "consolation": "Consolation",
      "lastMarque": "Seneste marqué",
      "lastHonneurs": "Seneste honneurs",
      "honneursState": "Honneurs-status",
      "suspension": "Suspension",
      "whiteSettlement": "Afregning for hvid",
      "blackSettlement": "Afregning for sort",
      "result": "Resultat",
      "whiteAEcrire": "À écrire for hvid",
      "blackAEcrire": "À écrire for sort",
      "whiteHonneurs": "Honneurs for hvid",
      "blackHonneurs": "Honneurs for sort",
      "queueJetons": "Jeton-kø {value}",
      "marques": "Marqués {value}",
      "queueMarques": "Queue des marqués {value}",
      "final": "Slutværdi {value}",
      "noMarque": "Intet marqué er afregnet endnu.",
      "refait": "Refait",
      "nextConsolation": "Næste consolation {value}",
      "trouAgainst": "{winner} huller mod {loser}",
      "voluntaryLoss": "Frivilligt tab",
      "simpleMarque": "Enkelt marqué",
      "gainExact": "Præcis gevinst {value}",
      "gainArrondi": "Afrundet gevinst {value}",
      "noHonneurs": "Ingen honneurs-partie er afregnet endnu.",
      "wonClass": "{color} vandt {klass}",
      "noCarry": "Ingen overførsel",
      "carried": "{count} {count, plural, one {hul overført} other {huller overført}}",
      "currentPartieWhite": "Aktuelt parti for hvid: {value}",
      "currentPartieBlack": "Aktuelt parti for sort: {value}",
      "honneursNear": "Honneurs tæt på at blive afregnet",
      "honneursProgress": "Honneurs i gang",
      "suspended": "Suspenderet: {track}",
      "frozenBy": "Låst af {color}",
      "resumesOnReleve": "Fortsætter ved relevé",
      "beforeQueues": "{value} før køer",
      "finalValue": "{value} slutværdi",
      "nextJetons": "Næste jetoner: {value}",
      "noRefait": "Intet refait",
      "refaitCount": "{count} {count, plural, one {refait} other {refaits}}",
      "partieTrous": "Partihuller: {count}",
      "marquesProgress": "{count}/{total} marqués",
      "colorTrous": "{color}: {holes}",
      "pointsAndTrous": "{points} / {holes}",
      "compactClasses": "S/D/T/Q {value}"
    },
    "matchResult": {
      "gameDraw": "Parti {number}: {kind}{award}",
      "gameWin": "Parti {number}: {leg}{winner} vandt{award} med {kind}"
    },
    "errors": {
      "unknown": "Ukendt fejl.",
      "unauthorized": "Ikke autoriseret.",
      "lobby_full": "Bordet er fuldt.",
      "player_not_found": "Spilleren findes ikke i lobbyen.",
      "match_over": "Matchen er allerede slut.",
      "not_your_turn": "Det er ikke din tur.",
      "invalid_move": "Ugyldigt træk.",
      "no_rolled_dice": "Ingen kastede terninger at bekræfte.",
      "turn_obligations": "Turens krav er ikke opfyldt.",
      "coin_rest": "Hukken skal afslutte turen med 0 eller mindst 2 brikker.",
      "only_host_options": "Kun værten kan sende matchindstillinger.",
      "variant_mismatch": "Dette bord bruger allerede et andet spil.",
      "reset_unavailable": "Nulstilling er kun tilgængelig, efter at matchen er slut.",
      "seat_reclaim_pending": "Anmodning om at overtage pladsen.",
      "bot_unavailable": "Den valgte bot er ikke tilgængelig.",
      "action_failed": "Handlingen mislykkedes."
    }
  }
};

const VARIANT_TITLES = {
  "en": {
    "backgammon": "Backgammon",
    "tapa": "Tapa / Plakoto",
    "jacquet": "Jacquet / Pheuga",
    "tavli": "Tavli",
    "brade": "Bräde",
    "garanguet": "Garanguet",
    "sbaraglio": "Sbaraglio",
    "sbaraglino": "Sbaraglino",
    "plein": "Plein",
    "tourne_case": "Tourne-Case",
    "dames_rabattues": "Dames Rabattues",
    "trictrac_classique": "Trictrac classique",
    "trictrac_aecrire": "Trictrac à écrire",
    "trictrac_combine": "Trictrac combiné",
    "toc": "Toc",
    "toccategli": "Toccategli",
    "trictrac_en_poule": "Trictrac en poule",
    "toccategli_en_poule": "Toccategli en poule",
    "trictrac_en_poule_plumee": "Trictrac en poule (plumée)",
    "toccategli_en_poule_plumee": "Toccategli en poule (plumée)",
    "trictrac_aecrire_a_tourner": "Trictrac à écrire à tourner",
    "trictrac_aecrire_chouette": "Trictrac à écrire chouette",
    "trictrac_aecrire_deux_contre_deux": "Trictrac à écrire deux contre deux",
    "trictrac_combine_chouette": "Trictrac combiné chouette",
    "trictrac_combine_deux_contre_deux": "Trictrac combiné deux contre deux"
  },
  "de": {
    "backgammon": "Backgammon",
    "tapa": "Tapa / Plakoto",
    "jacquet": "Jacquet / Pheuga",
    "tavli": "Tavli",
    "brade": "Bräde",
    "garanguet": "Garanguet",
    "sbaraglio": "Sbaraglio",
    "sbaraglino": "Sbaraglino",
    "plein": "Plein",
    "tourne_case": "Tourne-Case",
    "dames_rabattues": "Dames Rabattues",
    "trictrac_classique": "Trictrac classique",
    "trictrac_aecrire": "Trictrac à écrire",
    "trictrac_combine": "Trictrac combiné",
    "toc": "Toc",
    "toccategli": "Toccategli",
    "trictrac_en_poule": "Trictrac en poule",
    "toccategli_en_poule": "Toccategli en poule",
    "trictrac_en_poule_plumee": "Trictrac en poule (plumée)",
    "toccategli_en_poule_plumee": "Toccategli en poule (plumée)",
    "trictrac_aecrire_a_tourner": "Trictrac à écrire à tourner",
    "trictrac_aecrire_chouette": "Trictrac à écrire chouette",
    "trictrac_aecrire_deux_contre_deux": "Trictrac à écrire deux contre deux",
    "trictrac_combine_chouette": "Trictrac combiné chouette",
    "trictrac_combine_deux_contre_deux": "Trictrac combiné deux contre deux"
  },
  "fr": {
    "backgammon": "Backgammon",
    "tapa": "Tapa / Plakoto",
    "jacquet": "Jacquet / Pheuga",
    "tavli": "Tavli",
    "brade": "Bräde suédois",
    "garanguet": "Garanguet",
    "sbaraglio": "Sbaraglio",
    "sbaraglino": "Sbaraglino",
    "plein": "Plein",
    "tourne_case": "Tourne-Case",
    "dames_rabattues": "Dames Rabattues",
    "trictrac_classique": "Trictrac classique",
    "trictrac_aecrire": "Trictrac à écrire",
    "trictrac_combine": "Trictrac combiné",
    "toc": "Toc",
    "toccategli": "Toccategli",
    "trictrac_en_poule": "Trictrac en poule",
    "toccategli_en_poule": "Toccategli en poule",
    "trictrac_en_poule_plumee": "Trictrac en poule (plumée)",
    "toccategli_en_poule_plumee": "Toccategli en poule (plumée)",
    "trictrac_aecrire_a_tourner": "Trictrac à écrire à tourner",
    "trictrac_aecrire_chouette": "Trictrac à écrire chouette",
    "trictrac_aecrire_deux_contre_deux": "Trictrac à écrire deux contre deux",
    "trictrac_combine_chouette": "Trictrac combiné chouette",
    "trictrac_combine_deux_contre_deux": "Trictrac combiné deux contre deux"
  },
  "sv": {
    "backgammon": "Backgammon",
    "tapa": "Tapa / Plakoto",
    "jacquet": "Jacquet / Pheuga",
    "tavli": "Tavli",
    "brade": "Bräde",
    "garanguet": "Garanguet",
    "sbaraglio": "Sbaraglio",
    "sbaraglino": "Sbaraglino",
    "plein": "Plein",
    "tourne_case": "Tourne-Case",
    "dames_rabattues": "Dames Rabattues",
    "trictrac_classique": "Trictrac classique",
    "trictrac_aecrire": "Trictrac à écrire",
    "trictrac_combine": "Trictrac combiné",
    "toc": "Toc",
    "toccategli": "Toccategli",
    "trictrac_en_poule": "Trictrac en poule",
    "toccategli_en_poule": "Toccategli en poule",
    "trictrac_en_poule_plumee": "Trictrac en poule (plumée)",
    "toccategli_en_poule_plumee": "Toccategli en poule (plumée)",
    "trictrac_aecrire_a_tourner": "Trictrac à écrire à tourner",
    "trictrac_aecrire_chouette": "Trictrac à écrire chouette",
    "trictrac_aecrire_deux_contre_deux": "Trictrac à écrire deux contre deux",
    "trictrac_combine_chouette": "Trictrac combiné chouette",
    "trictrac_combine_deux_contre_deux": "Trictrac combiné deux contre deux"
  },
  "da": {
    "backgammon": "Backgammon",
    "tapa": "Tapa / Plakoto",
    "jacquet": "Jacquet / Pheuga",
    "tavli": "Tavli",
    "brade": "Bræde",
    "garanguet": "Garanguet",
    "sbaraglio": "Sbaraglio",
    "sbaraglino": "Sbaraglino",
    "plein": "Plein",
    "tourne_case": "Tourne-Case",
    "dames_rabattues": "Dames Rabattues",
    "trictrac_classique": "Trictrac classique",
    "trictrac_aecrire": "Trictrac à écrire",
    "trictrac_combine": "Trictrac combiné",
    "toc": "Toc",
    "toccategli": "Toccategli",
    "trictrac_en_poule": "Trictrac en poule",
    "toccategli_en_poule": "Toccategli en poule",
    "trictrac_en_poule_plumee": "Trictrac en poule (plumée)",
    "toccategli_en_poule_plumee": "Toccategli en poule (plumée)",
    "trictrac_aecrire_a_tourner": "Trictrac à écrire à tourner",
    "trictrac_aecrire_chouette": "Trictrac à écrire chouette",
    "trictrac_aecrire_deux_contre_deux": "Trictrac à écrire deux contre deux",
    "trictrac_combine_chouette": "Trictrac combiné chouette",
    "trictrac_combine_deux_contre_deux": "Trictrac combiné deux contre deux"
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
  "game.bar",
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
  "options.bestOfN",
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

const FRENCH_EXACT_LEAK_ALLOWLIST = new Set([
  "decision.tenir",
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
    (path.startsWith("scoreEvents.") ||
      path.startsWith("winnerKinds.") ||
      FRENCH_EXACT_LEAK_ALLOWLIST.has(path))
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
