import React, { useEffect, useMemo, useRef, useState } from "react";
import { createRoot } from "react-dom/client";
import ChatPanel from "./ChatPanel";
import BoardWood from "../static/images/6besh/board-wood.jpg";
import CheckerGreen from "../static/images/6besh/checker-green.png";
import CheckerRed from "../static/images/6besh/checker-red.png";
import DiceGreen1 from "../static/images/6besh/dice_green1.png";
import DiceGreen2 from "../static/images/6besh/dice_green2.png";
import DiceGreen3 from "../static/images/6besh/dice_green3.png";
import DiceGreen4 from "../static/images/6besh/dice_green4.png";
import DiceGreen5 from "../static/images/6besh/dice_green5.png";
import DiceGreen6 from "../static/images/6besh/dice_green6.png";
import DiceRed1 from "../static/images/6besh/dice_red1.png";
import DiceRed2 from "../static/images/6besh/dice_red2.png";
import DiceRed3 from "../static/images/6besh/dice_red3.png";
import DiceRed4 from "../static/images/6besh/dice_red4.png";
import DiceRed5 from "../static/images/6besh/dice_red5.png";
import DiceRed6 from "../static/images/6besh/dice_red6.png";

const CHECKER_IMAGES = {
  white: CheckerGreen,
  black: CheckerRed
};

const DICE_IMAGES = {
  white: {
    1: DiceGreen1,
    2: DiceGreen2,
    3: DiceGreen3,
    4: DiceGreen4,
    5: DiceGreen5,
    6: DiceGreen6
  },
  black: {
    1: DiceRed1,
    2: DiceRed2,
    3: DiceRed3,
    4: DiceRed4,
    5: DiceRed5,
    6: DiceRed6
  }
};

const COLOR_LABELS = {
  white: "White",
  black: "Black"
};

const SCORE_TOAST_COLOR_LABELS = {
  white: "White",
  black: "Black"
};

const BAR_LABEL_HIDDEN_VARIANTS = new Set([
  "trictrac_classique",
  "trictrac_aecrire",
  "trictrac_combine",
  "toccategli",
  "toc",
  "plein"
]);

const BAR_GRAPHICS_HIDDEN_VARIANTS = new Set([
  ...BAR_LABEL_HIDDEN_VARIANTS,
  "tapa",
  "jacquet",
  "garanguet"
]);

const TOAST_LIFETIME_MS = 4200;

const BOARD_LAYOUTS = {
  white: {
    top: [23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12],
    bottom: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
  },
  black: {
    top: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
    bottom: [23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12]
  }
};

function normalizeMessage(message, playerColor) {
  const text = message?.data?.text ?? message?.text ?? "";
  const rawAuthor = message?.author ?? message?.player;

  return {
    ...message,
    author: rawAuthor === playerColor ? "me" : "them",
    data: { text }
  };
}

function humanizeToken(value) {
  return String(value || "")
    .replace(/_/g, " ")
    .trim();
}

function capitalizeFirst(value) {
  if (!value) {
    return "";
  }

  return `${value.charAt(0).toUpperCase()}${value.slice(1)}`;
}

function scoreEventSignature(event) {
  return JSON.stringify(event || null);
}

function scoreEventDetail(event) {
  if (event?.label) {
    return event.label;
  }

  if (event?.source) {
    return humanizeToken(String(event.source).toLowerCase());
  }

  return "score event";
}

function buildTrictracToast(event) {
  const beneficiary = event?.beneficiary === "black" ? "black" : "white";
  const points = Number(event?.points ?? 0);

  return {
    title: `${SCORE_TOAST_COLOR_LABELS[beneficiary]} wins ${points} ${points === 1 ? "point" : "points"}`,
    detail: scoreEventDetail(event)
  };
}

function decisionPrompt(payload) {
  if (payload?.prompt) {
    return payload.prompt;
  }

  switch (payload?.key) {
    case "reprise":
      return "Choose whether to continue the game or take a reprise.";
    case "suspension":
      return "Choose which track to suspend.";
    default:
      return capitalizeFirst(humanizeToken(payload?.key || "turn decision"));
  }
}

function decisionChoiceLabel(choice) {
  return capitalizeFirst(humanizeToken(choice));
}

function colorLabel(color) {
  return SCORE_TOAST_COLOR_LABELS[color] || capitalizeFirst(humanizeToken(color || "unknown"));
}

function playerNameForColor(game, color) {
  if (!color) {
    return "Current player";
  }

  return color === "white"
    ? game?.players?.host?.name || colorLabel(color)
    : game?.players?.guest?.name || colorLabel(color);
}

function oppositeColor(color) {
  return color === "black" ? "white" : "black";
}

function trictracVariantId(game) {
  return game?.variant?.id || "";
}

function effectiveVariantId(game) {
  return game?.variant?.active_leg?.id || game?.variant?.id || "";
}

function effectiveVariantTitle(game) {
  return game?.variant?.active_leg?.title || game?.variant?.title || "";
}

function trictracScoreEntry(trictrac, color) {
  const entries = trictrac?.score || [];
  return color === "black" ? entries[1] || {} : entries[0] || {};
}

function holderFromFlags(flags) {
  const white = !!(flags?.white ?? flags?.White);
  const black = !!(flags?.black ?? flags?.Black);

  if (white && !black) {
    return "White";
  }

  if (black && !white) {
    return "Black";
  }

  return "None";
}

function formatCompactClasses(classes) {
  const current = classes || {};
  return `${current.simple || 0}/${current.double || 0}/${current.triple || 0}/${current.quadruple || 0}`;
}

function aecrirePartieLength(game) {
  const rawValue =
    game?.trictrac?.track_aecrire?.partie_length ??
    game?.match?.options?.aEcrirePartieLength ??
    16;
  const parsed = Number(rawValue);

  return [6, 8, 12, 16, 18, 20, 24].includes(parsed) ? parsed : 16;
}

function aecrireSettlementEntry(game, color) {
  const ledger = game?.trictrac?.settlement_ledger || {};
  return color === "black" ? ledger.black || {} : ledger.white || {};
}

function formatSignedValue(value) {
  const number = Number(value ?? 0);
  return `${number >= 0 ? "+" : ""}${number}`;
}

function aecrireDisplayTotal(game, color) {
  const aecrire = game?.trictrac?.track_aecrire || {};
  const points = aecrire.points_total?.[color] || 0;
  const finalTotal = aecrireSettlementEntry(game, color).final_total;

  return aecrire.partie_over && typeof finalTotal === "number" ? finalTotal : points;
}

function aecrireSettlementLines(game, color) {
  const ledger = aecrireSettlementEntry(game, color);

  return [
    `Queue des jetons ${formatSignedValue(ledger.queue_jetons || 0)}`,
    `Marqués ${formatSignedValue(ledger.marque_points || 0)}`,
    `Queue des marqués ${formatSignedValue(ledger.queue_paris || 0)}`,
    `Final ${ledger.final_total || 0}`
  ];
}

function aecrireLastMarqueLines(game) {
  const aecrire = game?.trictrac?.track_aecrire || {};
  const result = aecrire.last_marque_result;
  const nextConsolation = ((aecrire.refait_streak || 0) + 1) * 2;

  if (!result) {
    return ["No marqué settled yet."];
  }

  if (result.refait) {
    return ["Refait", `Next consolation ${nextConsolation}`];
  }

  const lines = [
    `${colorLabel(result.winner)} ${formatSignedValue(result.points_awarded)} pts`,
    `${result.winner_trous || 0} trous against ${result.loser_trous || 0}`
  ];

  if (result.bredouille) {
    lines.push(`${capitalizeFirst(result.bredouille)} bredouille x${result.multiplier}`);
  } else if (result.voluntary_loss) {
    lines.push("Voluntary loss");
  } else {
    lines.push("Simple marque");
  }

  return lines;
}

function aecrireResultLines(game) {
  const aecrire = game?.trictrac?.track_aecrire || {};
  const winner = game?.match?.winner || aecrire.winner;

  if (!aecrire.partie_over) {
    return [];
  }

  return [
    winner ? `${colorLabel(winner)} wins by jetons` : "Drawn settlement",
    `Gain brut ${aecrire.gross_gain || 0}`,
    `Gain arrondi ${aecrire.rounded_gain || 0}`
  ];
}

function combineLastPartieLines(game) {
  const result = game?.trictrac?.track_classique_honneurs?.last_partie_result;

  if (!result) {
    return ["No honneurs partie settled yet."];
  }

  const carried = Number(result.carried_trous || 0);

  return [
    `${colorLabel(result.winner)} won ${humanizeToken(result.class)}`,
    `${result.value || 0} honneurs`,
    carried > 0 ? `${carried} trou${carried === 1 ? "" : "s"} carried` : "No carry"
  ];
}

function combineStateLines(game) {
  const combine = game?.trictrac?.track_classique_honneurs || {};
  const current = combine.current_partie || {};
  const white = Number(current.trous?.white || 0);
  const black = Number(current.trous?.black || 0);

  return [
    `Current partie White ${white}`,
    `Current partie Black ${black}`,
    white >= 11 || black >= 11 ? "Honneurs near settlement" : "Honneurs in progress"
  ];
}

function combineSuspensionLines(game) {
  const suspension = game?.trictrac?.suspension_state || {};

  if (!suspension.resume_pending || !suspension.suspended_track) {
    return ["None"];
  }

  const trackLabel =
    suspension.suspended_track === "a_ecrire"
      ? "A ecrire"
      : suspension.suspended_track === "classique"
        ? "Honneurs"
        : humanizeToken(suspension.suspended_track);

  return [
    `${trackLabel} suspended`,
    `Frozen by ${colorLabel(suspension.frozen_by)}`,
    "Resumes on releve"
  ];
}

function matchOptionLabel(key) {
  switch (key) {
    case "tavliTarget":
      return "Points to play";
    case "aEcrirePartieLength":
      return "Marques to play";
    case "holeTarget":
      return "Holes to play";
    case "matchLength":
      return "Match length";
    case "doublesMode":
      return "Doubles mode";
    case "margotEnabled":
      return "Margot la fendue";
    default:
      return capitalizeFirst(humanizeToken(key));
  }
}

function matchOptionValue(key, value) {
  if (typeof value === "boolean") {
    return value ? "Yes" : "No";
  }

  switch (key) {
    case "tavliTarget":
      return `${value} point${String(value) === "1" ? "" : "s"}`;
    case "aEcrirePartieLength":
      return `${value} marques`;
    case "holeTarget":
      return `${value} hole${String(value) === "1" ? "" : "s"}`;
    case "matchLength":
      return `${value} game${String(value) === "1" ? "" : "s"}`;
    case "doublesMode":
      return value === "on" ? "On" : "Off";
    default:
      return String(value);
  }
}

function matchResultSummary(result, index) {
  const awards = result?.awards || {};
  const awardText =
    awards.white != null || awards.black != null
      ? ` (${awards.white ?? 0}-${awards.black ?? 0})`
      : result?.points != null
        ? ` ${result.points}`
        : "";
  const legLabel = result?.leg ? `${capitalizeFirst(humanizeToken(result.leg))}: ` : "";

  if (!result?.winner) {
    return `Game ${index + 1}: ${legLabel}${humanizeToken(result?.kind || "draw")}${awardText}`;
  }

  return `Game ${index + 1}: ${legLabel}${colorLabel(result.winner)} won${awardText} by ${humanizeToken(result.kind)}`;
}

function trictracStatusLineItems(game) {
  const variantId = trictracVariantId(game);
  const trictrac = game?.trictrac || {};
  const whiteScore = trictracScoreEntry(trictrac, "white");
  const blackScore = trictracScoreEntry(trictrac, "black");
  const aecrire = trictrac?.track_aecrire || {};
  const combine = trictrac?.track_classique_honneurs || {};
  const whiteAecrireTotal = aecrireDisplayTotal(game, "white");
  const blackAecrireTotal = aecrireDisplayTotal(game, "black");

  switch (variantId) {
    case "trictrac_classique":
    case "toccategli":
    case "plein":
      return [
        { label: "White", value: `${whiteScore.trous || 0}/${whiteScore.points || 0}` },
        { label: "Black", value: `${blackScore.trous || 0}/${blackScore.points || 0}` }
      ];

    case "toc":
      return [
        { label: "White", value: `${game?.match?.score?.white ?? 0} hole${(game?.match?.score?.white ?? 0) === 1 ? "" : "s"}` },
        { label: "Black", value: `${game?.match?.score?.black ?? 0} hole${(game?.match?.score?.black ?? 0) === 1 ? "" : "s"}` }
      ];

    case "tavli": {
      const target = game?.match?.length ?? 7;

      return [
        { label: "White", value: `${game?.match?.score?.white ?? 0}/${target}` },
        { label: "Black", value: `${game?.match?.score?.black ?? 0}/${target}` }
      ];
    }

    case "trictrac_aecrire": {
      return [
        { label: "White", value: `${whiteAecrireTotal}` },
        { label: "Black", value: `${blackAecrireTotal}` }
      ];
    }

    case "trictrac_combine": {
      const marques = aecrire.marques || {};
      const honneurs = combine.honneurs || {};

      return [
        {
          label: "White",
          value: `${marques.white || 0} marques / ${honneurs.white || 0} honneurs / ${whiteAecrireTotal} jetons`
        },
        {
          label: "Black",
          value: `${marques.black || 0} marques / ${honneurs.black || 0} honneurs / ${blackAecrireTotal} jetons`
        }
      ];
    }

    default:
      return [
        { label: "White", value: game?.match?.score?.white ?? 0 },
        { label: "Black", value: game?.match?.score?.black ?? 0 }
      ];
  }
}

function trictracDetailCards(game) {
  const variantId = trictracVariantId(game);
  const trictrac = game?.trictrac || {};
  const whiteScore = trictracScoreEntry(trictrac, "white");
  const blackScore = trictracScoreEntry(trictrac, "black");
  const aecrire = trictrac?.track_aecrire || {};
  const combine = trictrac?.track_classique_honneurs || {};
  const partieLength = aecrirePartieLength(game);
  const aecrirePoints = aecrire.points_total || {};
  const refaitStreak = aecrire.refait_streak || 0;
  const nextConsolation = (refaitStreak + 1) * 2;
  const aecrireOver = !!aecrire.partie_over;
  const aecrireResult = aecrireResultLines(game);

  switch (variantId) {
    case "trictrac_classique":
      return [
        {
          title: "Bredouille",
          lines: [holderFromFlags({ white: whiteScore.bredouille, black: blackScore.bredouille })]
        },
        {
          title: "Grande bredouille",
          lines: [
            holderFromFlags({
              white: whiteScore.grande_bredouille,
              black: blackScore.grande_bredouille
            })
          ]
        }
      ];

    case "plein":
      return [
        { title: "White", lines: [`${whiteScore.points || 0} pts`, `${whiteScore.trous || 0} trous`] },
        { title: "Black", lines: [`${blackScore.points || 0} pts`, `${blackScore.trous || 0} trous`] },
        {
          title: "Bredouille",
          lines: [holderFromFlags({ white: whiteScore.bredouille, black: blackScore.bredouille })]
        },
        {
          title: "Grande bredouille",
          lines: [
            holderFromFlags({
              white: whiteScore.grande_bredouille,
              black: blackScore.grande_bredouille
            })
          ]
        }
      ];

    case "toccategli":
      return [
        { title: "White", lines: [`${whiteScore.points || 0} pts`, `${whiteScore.trous || 0} trous`] },
        { title: "Black", lines: [`${blackScore.points || 0} pts`, `${blackScore.trous || 0} trous`] }
      ];

    case "toc":
      return [
        {
          title: "White",
          lines: [
            `${game?.match?.score?.white ?? 0} hole${(game?.match?.score?.white ?? 0) === 1 ? "" : "s"}`,
            ...((whiteScore.points || 0) > 0 || (whiteScore.trous || 0) > 0
              ? [`${whiteScore.points || 0} pts / ${whiteScore.trous || 0} trous`]
              : [])
          ]
        },
        {
          title: "Black",
          lines: [
            `${game?.match?.score?.black ?? 0} hole${(game?.match?.score?.black ?? 0) === 1 ? "" : "s"}`,
            ...((blackScore.points || 0) > 0 || (blackScore.trous || 0) > 0
              ? [`${blackScore.points || 0} pts / ${blackScore.trous || 0} trous`]
              : [])
          ]
        },
        {
          title: "Bredouille",
          lines: [holderFromFlags({ white: whiteScore.bredouille, black: blackScore.bredouille })]
        },
        {
          title: "Grande bredouille",
          lines: [
            holderFromFlags({
              white: whiteScore.grande_bredouille,
              black: blackScore.grande_bredouille
            })
          ]
        }
      ];

    case "trictrac_aecrire": {
      const coupTrous = aecrire.current_coup?.trous || {};
      const marques = aecrire.marques || {};
      const whiteLedger = aecrireSettlementEntry(game, "white");
      const blackLedger = aecrireSettlementEntry(game, "black");

      return [
        {
          title: "White",
          lines: [
            `${marques.white || 0}/${partieLength} marques`,
            `${aecrirePoints.white || 0} before queues`,
            ...(aecrireOver ? [`${whiteLedger.final_total || 0} final`] : [])
          ]
        },
        {
          title: "Black",
          lines: [
            `${marques.black || 0}/${partieLength} marques`,
            `${aecrirePoints.black || 0} before queues`,
            ...(aecrireOver ? [`${blackLedger.final_total || 0} final`] : [])
          ]
        },
        { title: "Current coup", lines: [`White ${coupTrous.white || 0}`, `Black ${coupTrous.black || 0}`] },
        { title: "Consolation", lines: [`${nextConsolation} jetons next`, refaitStreak > 0 ? `${refaitStreak} refait${refaitStreak === 1 ? "" : "s"}` : "No refait"] },
        { title: "Last marqué", lines: aecrireLastMarqueLines(game) },
        ...(aecrireOver
          ? [
              { title: "White settlement", lines: aecrireSettlementLines(game, "white") },
              { title: "Black settlement", lines: aecrireSettlementLines(game, "black") },
              { title: "Result", lines: aecrireResult }
            ]
          : [])
      ];
    }

    case "trictrac_combine": {
      const coupTrous = aecrire.current_coup?.trous || {};
      const marques = aecrire.marques || {};
      const partieTrous = combine.current_partie?.trous || {};
      const honneurs = combine.honneurs || {};
      const classes = combine.classes || {};
      const whiteLedger = aecrireSettlementEntry(game, "white");
      const blackLedger = aecrireSettlementEntry(game, "black");

      return [
        {
          title: "White a ecrire",
          lines: [
            `${marques.white || 0}/${partieLength} marques`,
            `${aecrirePoints.white || 0} before queues`,
            ...(aecrireOver ? [`${whiteLedger.final_total || 0} final`] : [])
          ]
        },
        {
          title: "Black a ecrire",
          lines: [
            `${marques.black || 0}/${partieLength} marques`,
            `${aecrirePoints.black || 0} before queues`,
            ...(aecrireOver ? [`${blackLedger.final_total || 0} final`] : [])
          ]
        },
        {
          title: "White honneurs",
          lines: [
            `${honneurs.white || 0} honneurs`,
            `${partieTrous.white || 0} partie trous`,
            `S/D/T/Q ${formatCompactClasses(classes.white)}`
          ]
        },
        {
          title: "Black honneurs",
          lines: [
            `${honneurs.black || 0} honneurs`,
            `${partieTrous.black || 0} partie trous`,
            `S/D/T/Q ${formatCompactClasses(classes.black)}`
          ]
        },
        { title: "Honneurs state", lines: combineStateLines(game) },
        { title: "Suspension", lines: combineSuspensionLines(game) },
        { title: "Last honneurs", lines: combineLastPartieLines(game) },
        { title: "Current coup", lines: [`White ${coupTrous.white || 0}`, `Black ${coupTrous.black || 0}`] },
        { title: "Consolation", lines: [`${nextConsolation} jetons next`, refaitStreak > 0 ? `${refaitStreak} refait${refaitStreak === 1 ? "" : "s"}` : "No refait"] },
        { title: "Last marqué", lines: aecrireLastMarqueLines(game) },
        ...(aecrireOver
          ? [
              { title: "White settlement", lines: aecrireSettlementLines(game, "white") },
              { title: "Black settlement", lines: aecrireSettlementLines(game, "black") },
              { title: "Result", lines: aecrireResult }
            ]
          : [])
      ];
    }

    default:
      return [];
  }
}

function pendingChoiceLabel(payload, answer) {
  if (answer == null) {
    return "Waiting";
  }

  const labeledChoice = payload?.choiceLabels?.[answer];

  if (labeledChoice) {
    return labeledChoice;
  }

  switch (answer) {
    case "yes":
      return "Yes";
    case "no":
      return "No";
    default:
      return decisionChoiceLabel(answer);
  }
}

function OpeningRollDie({ color, value }) {
  if (value == null) {
    return <span className="opening-roll-waiting">Waiting</span>;
  }

  return (
    <img
      className="themed-die"
      src={DICE_IMAGES[color][value]}
      alt={`${colorLabel(color)} opening die ${value}`}
    />
  );
}

export default function gameInit(root, channel, options = {}) {
  const joinTimeoutMs = options.joinTimeoutMs ?? 15000;
  const onJoinComplete = options.onJoinComplete ?? (() => {});
  const botMargotPreference = options.botMargotPreference ?? "";
  const reactRoot = createRoot(root);

  channel
    .join(joinTimeoutMs)
    .receive("ok", (resp) => {
      onJoinComplete();
      reactRoot.render(
        <HermesTrictracApp
          lobbyName={root.dataset.game}
          player={resp.player}
          playerName={root.dataset.user}
          channel={channel}
          initialGame={resp.game}
          requestedBotMargot={botMargotPreference}
        />
      );
    })
    .receive("error", (resp) => {
      onJoinComplete();
      root.innerHTML = `<p>Unable to join game: ${resp?.msg || "unknown error"}</p>`;
    })
    .receive("timeout", () => {
      onJoinComplete();
      root.innerHTML = "<p>Joining the table timed out. If you requested the model opponent, it may still be warming up.</p>";
    });
}

function HermesTrictracApp({ channel, initialGame, player, playerName, lobbyName, requestedBotMargot }) {
  const playerColor = player?.color ?? "white";
  const [game, setGame] = useState(initialGame);
  const [selectedFrom, setSelectedFrom] = useState(null);
  const [errorMessage, setErrorMessage] = useState("");
  const [optionsDraft, setOptionsDraft] = useState({});
  const [toasts, setToasts] = useState([]);
  const [lastVisibleDice, setLastVisibleDice] = useState(() =>
    initialGame?.dice
      ? {
          color: initialGame.turn?.color || playerColor,
          dice: initialGame.dice
        }
      : null
  );
  const initialScoreHistory = Array.isArray(initialGame?.trictrac?.score_history) ? initialGame.trictrac.score_history : [];
  const toastIdRef = useRef(0);
  const toastTimersRef = useRef(new Map());
  const scoreHistoryCursorRef = useRef(initialScoreHistory.length);
  const lastSeenScoreEventRef = useRef(scoreEventSignature(initialScoreHistory[initialScoreHistory.length - 1]));

  const dismissToast = (toastId) => {
    const timerId = toastTimersRef.current.get(toastId);

    if (timerId) {
      window.clearTimeout(timerId);
      toastTimersRef.current.delete(toastId);
    }

    setToasts((current) => current.filter((toast) => toast.id !== toastId));
  };

  const queueToast = (toast) => {
    toastIdRef.current += 1;
    const toastId = toastIdRef.current;

    setToasts((current) => [...current, { id: toastId, ...toast }]);

    const timerId = window.setTimeout(() => {
      dismissToast(toastId);
    }, TOAST_LIFETIME_MS);

    toastTimersRef.current.set(toastId, timerId);
  };

  const syncTrictracToasts = (nextGame) => {
    const nextHistory = Array.isArray(nextGame?.trictrac?.score_history) ? nextGame.trictrac.score_history : [];
    const previousLength = scoreHistoryCursorRef.current;
    const previousSignature = lastSeenScoreEventRef.current;

    if (nextHistory.length === 0) {
      scoreHistoryCursorRef.current = 0;
      lastSeenScoreEventRef.current = scoreEventSignature(null);
      return;
    }

    if (nextHistory.length < previousLength) {
      scoreHistoryCursorRef.current = nextHistory.length;
      lastSeenScoreEventRef.current = scoreEventSignature(nextHistory[nextHistory.length - 1]);
      return;
    }

    if (previousLength > 0) {
      const currentPrefixSignature = scoreEventSignature(nextHistory[previousLength - 1]);

      if (currentPrefixSignature !== previousSignature) {
        scoreHistoryCursorRef.current = nextHistory.length;
        lastSeenScoreEventRef.current = scoreEventSignature(nextHistory[nextHistory.length - 1]);
        return;
      }
    }

    if (nextHistory.length > previousLength) {
      nextHistory.slice(previousLength).forEach((event) => {
        queueToast(buildTrictracToast(event));
      });
    }

    scoreHistoryCursorRef.current = nextHistory.length;
    lastSeenScoreEventRef.current = scoreEventSignature(nextHistory[nextHistory.length - 1]);
  };

  useEffect(() => {
    const updateRef = channel.on("update", (resp) => {
      syncTrictracToasts(resp.game);
      setGame(resp.game);
      setErrorMessage("");
      setSelectedFrom(null);
    });

    return () => {
      channel.off("update", updateRef);
    };
  }, [channel]);

  useEffect(() => {
    return () => {
      toastTimersRef.current.forEach((timerId) => window.clearTimeout(timerId));
      toastTimersRef.current.clear();
    };
  }, []);

  useEffect(() => {
    const pendingOptions = game.pending_match_options?.options ?? [];

    if (pendingOptions.length === 0) {
      return;
    }

    const requestedMargotEnabled =
      requestedBotMargot === "yes" ? true : requestedBotMargot === "no" ? false : null;

    setOptionsDraft(
      pendingOptions.reduce((acc, option) => {
        acc[option.key] =
          option.key === "margotEnabled" && requestedMargotEnabled !== null
            ? requestedMargotEnabled
            : option.defaultValue;
        return acc;
      }, {})
    );
  }, [game.pending_match_options, requestedBotMargot]);

  useEffect(() => {
    if (game.opening_roll?.pending || game.pending_match_options || !game.turn?.color) {
      setLastVisibleDice(null);
      return;
    }

    if (game.dice) {
      setLastVisibleDice({
        color: game.turn.color,
        dice: game.dice
      });
    }
  }, [game.dice, game.opening_roll?.pending, game.pending_match_options, game.turn?.color]);

  const isHost = game.players?.host?.name === playerName;
  const activeTurnColor = game.turn?.color;
  const isTurnPlayer = game.turn?.player_name === playerName || activeTurnColor === playerColor;
  const isSeatedPlayer =
    game.players?.host?.name === playerName || game.players?.guest?.name === playerName;
  const pendingMatchOptions = game.pending_match_options;
  const isConsensusChoice =
    Array.isArray(pendingMatchOptions?.choices) && !!pendingMatchOptions?.responses;
  const pendingDecisionActorColor = game.pending_turn_decision?.actorColor || activeTurnColor;
  const canResolveTurnDecision =
    !!game.pending_turn_decision && isSeatedPlayer && pendingDecisionActorColor === playerColor;
  const openingRoll = game.opening_roll;
  const isOpeningRollPending = !!openingRoll?.pending;
  const legalMoves = game.legal_moves || [];
  const activeLegalMoves =
    isTurnPlayer && !game.pending_turn_decision && !isOpeningRollPending ? legalMoves : [];

  const fromTargets = useMemo(() => {
    return activeLegalMoves.reduce((acc, move) => {
      const key = String(move.from);
      acc[key] = acc[key] || [];
      acc[key].push(move);
      return acc;
    }, {});
  }, [activeLegalMoves]);

  const selectedMoves = selectedFrom == null ? [] : fromTargets[String(selectedFrom)] || [];
  const highlightedTargets = new Set(selectedMoves.map((move) => String(move.to)));
  const boardPoints = new Map((game.board?.points || []).map((point) => [point.index, point]));
  const layout = BOARD_LAYOUTS[playerColor] || BOARD_LAYOUTS.white;
  const topColor = playerColor === "white" ? "black" : "white";
  const activeVariantId = effectiveVariantId(game);
  const showBarColumn = !BAR_GRAPHICS_HIDDEN_VARIANTS.has(activeVariantId);
  const displayedDice = game.opening_roll?.pending ? null : game.dice || lastVisibleDice?.dice || null;
  const displayedDiceColor = game.dice
    ? game.turn?.color || playerColor
    : lastVisibleDice?.color || playerColor;
  const displayedDiceIsCurrent = !!game.dice;

  const messageList = useMemo(
    () => (game.chat || []).map((message) => normalizeMessage(message, playerColor)),
    [game.chat, playerColor]
  );

  const clearSelection = () => setSelectedFrom(null);

  const pushWithError = (event, payload = {}) => {
    channel
      .push(event, payload)
      .receive("error", (resp) => {
        setErrorMessage(resp?.msg || "Action failed.");
      });
  };

  const selectSource = (from) => {
    if (!isTurnPlayer || game.pending_turn_decision || isOpeningRollPending) {
      return;
    }

    if (selectedFrom === from) {
      clearSelection();
      return;
    }

    if ((fromTargets[String(from)] || []).length === 0) {
      return;
    }

    setSelectedFrom(from);
  };

  const moveTo = (to) => {
    if (!isTurnPlayer || game.pending_turn_decision || isOpeningRollPending || selectedFrom == null || !highlightedTargets.has(String(to))) {
      return;
    }

    const selectedMove = selectedMoves.find((move) => move.to === to) || selectedMoves[0];

    if (!selectedMove) {
      return;
    }

    pushWithError("move", {
      move: {
        from: selectedFrom,
        to: to,
        sequence: selectedMove.sequence
      }
    });
    clearSelection();
  };

  const submitOptions = (event) => {
    event.preventDefault();
    pushWithError("submit_match_options", { options: optionsDraft });
  };

  const onMessageWasSent = (text) => {
    pushWithError("chat", {
      chat: {
        author: playerColor,
        type: "text",
        data: { text }
      }
    });
  };

  const diceTheme = game.turn?.color || playerColor;
  const heroCopy = game.bot?.enabled
    ? `You are playing as ${COLOR_LABELS[playerColor]} against ${game.bot.name}.`
    : `You are playing as ${COLOR_LABELS[playerColor]}. Share this lobby name with your opponent to join the same table.`;

  return (
    <div className="app-shell">
      {toasts.length > 0 ? <ToastStack toasts={toasts} /> : null}
      <section className="hero-panel">
        <div>
          <p className="eyebrow">{game.variant?.title || "Table Game"}</p>
          <h1>{lobbyName}</h1>
          <p className="hero-copy">{heroCopy}</p>
        </div>
        <div className="hero-meta">
          <span>Host: {game.players?.host?.name || "Waiting..."}</span>
          <span>Guest: {game.players?.guest?.name || "Waiting..."}</span>
          <span>Turn {game.turn?.number || 0}</span>
        </div>
      </section>

      <div className="game-layout">
        <aside className="action-rail">
          <StatusCard game={game} playerColor={playerColor} playerName={playerName} />
          <DiceCard color={displayedDiceColor} dice={displayedDice} isCurrentRoll={displayedDiceIsCurrent} />
          {isOpeningRollPending ? <OpeningRollCard payload={openingRoll} playerColor={playerColor} /> : null}
          <ActionCard
            game={game}
            isSeatedPlayer={isSeatedPlayer}
            isTurnPlayer={isTurnPlayer}
            playerColor={playerColor}
            openingRoll={openingRoll}
            onRoll={() => pushWithError("roll")}
            onUndo={() => {
              pushWithError("undo");
              clearSelection();
            }}
            onConfirm={() => {
              pushWithError("confirm");
              clearSelection();
            }}
            onResign={() => {
              if (window.confirm("Resign the match?")) {
                pushWithError("resign");
                clearSelection();
              }
            }}
            onNewMatch={() => {
              pushWithError("reset");
              clearSelection();
            }}
          />
          {isConsensusChoice && isSeatedPlayer ? (
            <PregameChoiceCard
              payload={pendingMatchOptions}
              playerColor={playerColor}
              onChoose={(decision) => {
                const optionKey =
                  pendingMatchOptions.kind === "trictrac_partie_length_consent"
                    ? "aEcrirePartieLengthConsent"
                    : "margotConsent";

                pushWithError("submit_match_options", { options: { [optionKey]: decision } });
              }}
            />
          ) : null}
          {pendingMatchOptions && !isConsensusChoice && isHost ? (
            <OptionsCard
              payload={pendingMatchOptions}
              values={optionsDraft}
              onChange={(key, value) => setOptionsDraft((current) => ({ ...current, [key]: value }))}
              onSubmit={submitOptions}
            />
          ) : null}
          {game.pending_turn_decision && canResolveTurnDecision ? (
            <TurnDecisionCard
              payload={game.pending_turn_decision}
              onChoose={(decision) => pushWithError("submit_turn_decision", { decision })}
            />
          ) : null}
          <MatchCard game={game} />
          {game.trictrac ? <TrictracCard game={game} /> : null}
          {errorMessage ? <div className="notice error">{errorMessage}</div> : null}
        </aside>

        <main className="table-stage">
          <div
            className={`board-shell player-${playerColor}`}
            style={{ backgroundImage: `url(${BoardWood})` }}
          >
            <div className="board-sheen" />
            <div className="board-grid">
              <BoardRow
                points={layout.top}
                pointsMap={boardPoints}
                isTop={true}
                selectedFrom={selectedFrom}
                highlightedTargets={highlightedTargets}
                sourceMoves={fromTargets}
                onSelectSource={selectSource}
                onMoveTo={moveTo}
              />
              {showBarColumn ? (
                <BarColumn
                  variantId={activeVariantId}
                  topColor={topColor}
                  bottomColor={playerColor}
                  board={game.board}
                  selectedFrom={selectedFrom}
                  sourceMoves={fromTargets}
                  highlightedTargets={highlightedTargets}
                  onSelectSource={selectSource}
                />
              ) : null}
              <HomeColumn
                topColor={topColor}
                bottomColor={playerColor}
                board={game.board}
                highlightedTargets={highlightedTargets}
                onMoveTo={moveTo}
              />
              <BoardRow
                points={layout.bottom}
                pointsMap={boardPoints}
                isTop={false}
                selectedFrom={selectedFrom}
                highlightedTargets={highlightedTargets}
                sourceMoves={fromTargets}
                onSelectSource={selectSource}
                onMoveTo={moveTo}
              />
            </div>
          </div>
          <ChatPanel messages={messageList} onSendMessage={onMessageWasSent} />
        </main>
      </div>
    </div>
  );
}

function StatusCard({ game, playerColor, playerName }) {
  const summaryItems = trictracStatusLineItems(game);
  const winnerLabel = colorLabel(game.match?.winner);
  const activeLegTitle = game?.variant?.id === "tavli" ? effectiveVariantTitle(game) : null;
  const pendingDecisionActorColor = game.pending_turn_decision?.actorColor || game.turn?.color;
  const pendingDecisionActorName = playerNameForColor(game, pendingDecisionActorColor);
  const whoseTurn =
    game.match?.is_over
      ? `${winnerLabel} won${game.match?.winner_kind ? ` by ${humanizeToken(game.match.winner_kind)}` : ""}.`
      : game.status === "waiting_for_opponent"
      ? "Waiting for an opponent to join."
      : game.opening_roll?.pending
        ? game.opening_roll.prompt || "Roll to decide who starts."
      : game.pending_match_options?.kind === "tavli_target_consent"
        ? "Tavli target must be agreed before play starts."
      : game.pending_match_options?.kind === "trictrac_margot_consent"
        ? "Margot la fendue must be agreed before play starts."
        : game.pending_match_options
          ? "Match options need to be confirmed before play starts."
        : game.pending_turn_decision
          ? `${pendingDecisionActorName} must resolve a turn decision.`
          : game.turn?.player_name
            ? `${game.turn.player_name} to move`
            : "Table is setting up.";

  return (
    <section className="rail-card">
      <p className="rail-label">Seat</p>
      <h2>{playerName}</h2>
      <p className="seat-tag">You are {COLOR_LABELS[playerColor]}</p>
      <p className="status-line">{whoseTurn}</p>
      {activeLegTitle ? <p className="muted-copy">Current leg: {activeLegTitle}</p> : null}
      <div className="score-row">
        {summaryItems.map((item) => (
          <span key={item.label}>
            {item.label}: {item.value}
          </span>
        ))}
      </div>
    </section>
  );
}

function DiceCard({ color, dice, isCurrentRoll }) {
  if (!dice) {
    return (
      <section className="rail-card">
        <p className="rail-label">Dice</p>
        <p className="muted-copy">No dice rolled yet.</p>
      </section>
    );
  }

  return (
    <section className="rail-card">
      <p className="rail-label">Dice</p>
      <div className="dice-row">
        {(dice.values || []).map((value, index) => (
          <img key={`${value}-${index}`} className="themed-die" src={DICE_IMAGES[color][value]} alt={`Die ${value}`} />
        ))}
      </div>
      <p className="muted-copy">
        {isCurrentRoll ? `Moves left: ${(dice.moves_left || []).join(", ") || "none"}` : "Awaiting next roll."}
      </p>
    </section>
  );
}

function OpeningRollCard({ payload, playerColor }) {
  const rolls = payload?.rolls || {};
  const opponent = oppositeColor(playerColor);

  return (
    <section className="rail-card">
      <p className="rail-label">Opening Roll</p>
      <h2>{payload?.prompt || "Roll to decide who starts."}</h2>
      <div className="trictrac-grid">
        <div className="opening-roll-entry">
          <strong>{colorLabel(playerColor)}</strong>
          <OpeningRollDie color={playerColor} value={rolls[playerColor]} />
        </div>
        <div className="opening-roll-entry">
          <strong>{colorLabel(opponent)}</strong>
          <OpeningRollDie color={opponent} value={rolls[opponent]} />
        </div>
      </div>
    </section>
  );
}

function ActionCard({ game, isSeatedPlayer, isTurnPlayer, playerColor, openingRoll, onRoll, onUndo, onConfirm, onResign, onNewMatch }) {
  const openingRollPending = !!openingRoll?.pending;
  const endTurnPoints = Number(game.ui_actions?.end_turn_points || 0);
  const isImpuissanceEndTurn = game.ui_actions?.end_turn_reason === "impuissance";
  const canOpeningRoll =
    openingRollPending &&
    isSeatedPlayer &&
    !game.match?.is_over &&
    !game.pending_match_options &&
    !game.pending_turn_decision &&
    !game.dice &&
    openingRoll?.rolls?.[playerColor] == null;
  const canPlay =
    isTurnPlayer &&
    !openingRollPending &&
    !game.match?.is_over &&
    !game.pending_match_options &&
    !game.pending_turn_decision;
  const canRoll = canOpeningRoll || (canPlay && !game.dice && !game.pending_match_options && !game.pending_turn_decision);
  const canUndo = canPlay && !!game.dice && (game.dice.moves_played || []).length > 0 && !game.pending_turn_decision;
  const canEndTurn =
    canPlay &&
    !!game.ui_actions?.can_end_turn &&
    isImpuissanceEndTurn;
  const hasLegalMoves = (game.legal_moves || []).length > 0;
  const hasMovesLeft = (game.dice?.moves_left || []).length > 0;
  const canPassDice =
    canPlay &&
    !!game.dice &&
    hasMovesLeft &&
    !hasLegalMoves &&
    !!game.ui_actions?.can_confirm &&
    !game.pending_turn_decision &&
    !canEndTurn;
  const canConfirm =
    canPlay &&
    !!game.dice &&
    !hasMovesLeft &&
    !!game.ui_actions?.can_confirm &&
    !game.pending_turn_decision &&
    !canEndTurn;
  const showNewMatch = !!game.match?.is_over;
  const secondaryActionLabel = showNewMatch ? "New Match" : canEndTurn ? "End Turn" : "Resign";
  const secondaryAction = showNewMatch ? onNewMatch : canEndTurn ? onConfirm : onResign;
  const secondaryDisabled = showNewMatch ? false : canEndTurn ? !canEndTurn : !isSeatedPlayer;
  const undoAction = canPassDice ? onConfirm : onUndo;
  const undoDisabled = canPassDice ? false : !canUndo;
  const undoLabel = canPassDice ? "Pass Dice" : "Undo";

  return (
    <section className="rail-card">
      <p className="rail-label">Actions</p>
      <div className="button-grid">
        <button type="button" onClick={onRoll} disabled={!canRoll}>
          Roll
        </button>
        <button type="button" onClick={undoAction} disabled={undoDisabled}>
          {undoLabel}
        </button>
        <button type="button" onClick={onConfirm} disabled={!canConfirm}>
          Confirm
        </button>
        <button
          type="button"
          onClick={secondaryAction}
          disabled={secondaryDisabled}
        >
          {secondaryActionLabel}
        </button>
      </div>
      {canEndTurn ? (
        <p className="muted-copy">
          Dame impuissante: {endTurnPoints} point{endTurnPoints === 1 ? "" : "s"} to {colorLabel(oppositeColor(playerColor))}.
        </p>
      ) : null}
      {canPassDice ? (
        <p className="muted-copy">
          No legal moves are available; pass the dice to your opponent.
        </p>
      ) : null}
    </section>
  );
}

function OptionsCard({ payload, values, onChange, onSubmit }) {
  return (
    <section className="rail-card">
      <p className="rail-label">Match Options</p>
      <form className="stack-form" onSubmit={onSubmit}>
        {(payload.options || []).map((option) => (
          <label key={option.key} className="option-row">
            <span>{option.label}</span>
            {Array.isArray(option.choices) ? (
              <select value={values[option.key] ?? option.defaultValue} onChange={(event) => onChange(option.key, event.target.value)}>
                {option.choices.map((choice) => (
                  <option key={choice.value} value={choice.value}>
                    {choice.label}
                  </option>
                ))}
              </select>
            ) : typeof option.defaultValue === "boolean" ? (
              <input
                type="checkbox"
                checked={!!values[option.key]}
                onChange={(event) => onChange(option.key, event.target.checked)}
              />
            ) : (
              <input value={values[option.key] ?? option.defaultValue} onChange={(event) => onChange(option.key, event.target.value)} />
            )}
          </label>
        ))}
        <button type="submit">Start Match</button>
      </form>
    </section>
  );
}

function PregameChoiceCard({ payload, playerColor, onChoose }) {
  const responses = payload?.responses || {};
  const opponent = oppositeColor(playerColor);

  return (
    <section className="rail-card">
      <p className="rail-label">Pregame</p>
      <h2>{payload?.prompt || "Choose the pregame option."}</h2>
      <div className="trictrac-grid">
        <div>
          <strong>Your choice</strong>
          <span>{pendingChoiceLabel(payload, responses[playerColor])}</span>
        </div>
        <div>
          <strong>{colorLabel(opponent)} choice</strong>
          <span>{pendingChoiceLabel(payload, responses[opponent])}</span>
        </div>
      </div>
      <div className="button-grid">
        {(payload?.choices || []).map((choice) => (
          <button key={choice} type="button" onClick={() => onChoose(choice)}>
            {pendingChoiceLabel(payload, choice)}
          </button>
        ))}
      </div>
    </section>
  );
}

function TurnDecisionCard({ payload, onChoose }) {
  return (
    <section className="rail-card">
      <p className="rail-label">Decision</p>
      <h2>{decisionPrompt(payload)}</h2>
      {payload?.key ? <p className="muted-copy">Decision key: {humanizeToken(payload.key)}</p> : null}
      <div className="button-grid">
        {(payload.choices || []).map((choice) => (
          <button key={choice} type="button" onClick={() => onChoose(choice)}>
            {decisionChoiceLabel(choice)}
          </button>
        ))}
      </div>
    </section>
  );
}

function ToastStack({ toasts }) {
  return (
    <div className="toast-stack" aria-live="polite" aria-atomic="false">
      {toasts.map((toast) => (
        <article key={toast.id} className="toast-card">
          <strong>{toast.title}</strong>
          <p>{toast.detail}</p>
        </article>
      ))}
    </div>
  );
}

function TrictracCard({ game }) {
  const cards = trictracDetailCards(game);

  if (cards.length === 0) {
    return null;
  }

  return (
    <section className="rail-card">
      <p className="rail-label">Trictrac Track</p>
      <div className="trictrac-grid">
        {cards.map((card) => (
          <div key={card.title}>
            <strong>{card.title}</strong>
            {card.lines.map((line) => (
              <span key={line}>{line}</span>
            ))}
          </div>
        ))}
      </div>
    </section>
  );
}

function MatchCard({ game }) {
  const results = game.match?.results || [];
  const options = game.match?.options || {};
  const showTocScore = game.variant?.id === "toc";
  const showTavliScore = game.variant?.id === "tavli";
  const optionEntries = Object.entries(options).filter(
    ([key]) => key !== "aEcrireStyle" && (!showTavliScore || key !== "tavliTarget")
  );
  const activeLegTitle = showTavliScore ? effectiveVariantTitle(game) : null;

  if (results.length === 0 && optionEntries.length === 0 && !game.match?.winner_kind && !showTocScore && !showTavliScore) {
    return null;
  }

  return (
    <section className="rail-card">
      <p className="rail-label">Match</p>
      {game.match?.winner_kind ? (
        <p className="muted-copy">
          {colorLabel(game.match?.winner)} by {humanizeToken(game.match.winner_kind)}
        </p>
      ) : null}
      {showTocScore ? (
        <div className="trictrac-grid">
          <div>
            <strong>White</strong>
            <span>{game.match?.score?.white ?? 0} holes</span>
          </div>
          <div>
            <strong>Black</strong>
            <span>{game.match?.score?.black ?? 0} holes</span>
          </div>
        </div>
      ) : null}
      {showTavliScore ? (
        <div className="trictrac-grid">
          <div>
            <strong>White</strong>
            <span>{game.match?.score?.white ?? 0} points</span>
          </div>
          <div>
            <strong>Black</strong>
            <span>{game.match?.score?.black ?? 0} points</span>
          </div>
          <div>
            <strong>Target</strong>
            <span>{game.match?.length ?? 7} points</span>
          </div>
          <div>
            <strong>Current leg</strong>
            <span>{activeLegTitle || "Tavli"}</span>
          </div>
        </div>
      ) : null}
      {optionEntries.length > 0 ? (
        <div className="trictrac-grid">
          {optionEntries.map(([key, value]) => (
            <div key={key}>
              <strong>{matchOptionLabel(key)}</strong>
              <span>{matchOptionValue(key, value)}</span>
            </div>
          ))}
        </div>
      ) : null}
      {results.length > 0 ? (
        <div className="result-list">
          {results.map((result, index) => (
            <p key={`${result.winner}-${index}`} className="muted-copy">
              {matchResultSummary(result, index)}
            </p>
          ))}
        </div>
      ) : null}
    </section>
  );
}

function BoardRow({
  points,
  pointsMap,
  isTop,
  selectedFrom,
  highlightedTargets,
  sourceMoves,
  onSelectSource,
  onMoveTo
}) {
  const leftSide = points.slice(0, 6);
  const rightSide = points.slice(6);

  return (
    <div className={`board-row ${isTop ? "top" : "bottom"}`}>
      <div className={`point-strip ${isTop ? "top" : "bottom"} left`}>
        {leftSide.map((index) => (
          <PointSlot
            key={index}
            point={pointsMap.get(index)}
            isTop={isTop}
            isSelected={selectedFrom === index}
            isSource={(sourceMoves[String(index)] || []).length > 0}
            isTarget={highlightedTargets.has(String(index))}
            onSourceClick={() => onSelectSource(index)}
            onTargetClick={() => onMoveTo(index)}
          />
        ))}
      </div>
      <div className={`point-strip ${isTop ? "top" : "bottom"} right`}>
        {rightSide.map((index) => (
          <PointSlot
            key={index}
            point={pointsMap.get(index)}
            isTop={isTop}
            isSelected={selectedFrom === index}
            isSource={(sourceMoves[String(index)] || []).length > 0}
            isTarget={highlightedTargets.has(String(index))}
            onSourceClick={() => onSelectSource(index)}
            onTargetClick={() => onMoveTo(index)}
          />
        ))}
      </div>
    </div>
  );
}

function PointSlot({ point, isTop, isSelected, isSource, isTarget, onSourceClick, onTargetClick }) {
  const pieces = point?.pieces || [];
  const pointNumber = typeof point?.index === "number" ? point.index + 1 : "";
  const classes = [
    "point-slot",
    isTop ? "top" : "bottom",
    isSelected ? "selected" : "",
    isSource ? "source" : "",
    isTarget ? "target" : ""
  ]
    .filter(Boolean)
    .join(" ");

  const clickHandler = isTarget ? onTargetClick : onSourceClick;

  return (
    <button type="button" className={classes} onClick={clickHandler}>
      <span className="point-triangle" />
      <span className={`point-number ${isTop ? "top" : "bottom"}`}>{pointNumber}</span>
      <StackedCheckers pieces={pieces} isTop={isTop} />
    </button>
  );
}

function BarColumn({ variantId, topColor, bottomColor, board, selectedFrom, sourceMoves, onSelectSource }) {
  const bottomBarHasMoves = (sourceMoves.bar || []).length > 0;
  const showLabels = !BAR_LABEL_HIDDEN_VARIANTS.has(variantId);

  return (
    <div className="bar-column">
      <BarPocket
        showLabel={showLabels}
        color={topColor}
        count={board?.bar?.[topColor] || 0}
        isTop={true}
        isSelected={false}
        isSource={false}
        onSelect={() => {}}
      />
      <BarPocket
        showLabel={showLabels}
        color={bottomColor}
        count={board?.bar?.[bottomColor] || 0}
        isTop={false}
        isSelected={selectedFrom === "bar"}
        isSource={bottomBarHasMoves}
        onSelect={() => onSelectSource("bar")}
      />
    </div>
  );
}

function BarPocket({ color, count, isTop, isSelected, isSource, onSelect, showLabel }) {
  return (
    <button
      type="button"
      className={`bar-pocket ${isTop ? "top" : "bottom"} ${isSelected ? "selected" : ""} ${isSource ? "source" : ""}`}
      onClick={onSelect}
    >
      {showLabel ? <p>{isTop ? "Opponent Bar" : "Your Bar"}</p> : null}
      <StackedCheckers pieces={Array.from({ length: count }, () => color)} isTop={isTop} />
      <strong>{count}</strong>
    </button>
  );
}

function HomeColumn({ topColor, bottomColor, board, highlightedTargets, onMoveTo }) {
  return (
    <div className="home-column">
      <HomePocket color={topColor} count={board?.outside?.[topColor] || 0} isTop={true} onMoveTo={onMoveTo} isTarget={false} />
      <HomePocket
        color={bottomColor}
        count={board?.outside?.[bottomColor] || 0}
        isTop={false}
        onMoveTo={onMoveTo}
        isTarget={highlightedTargets.has("home")}
      />
    </div>
  );
}

function HomePocket({ color, count, isTop, onMoveTo, isTarget }) {
  return (
    <button
      type="button"
      className={`home-pocket ${isTop ? "top" : "bottom"} ${isTarget ? "target" : ""}`}
      onClick={() => {
        if (isTarget) {
          onMoveTo("home");
        }
      }}
    >
      <p>Bear Off</p>
      <StackedCheckers pieces={Array.from({ length: count }, () => color)} isTop={isTop} />
      <strong>{count}</strong>
    </button>
  );
}

function StackedCheckers({ pieces, isTop }) {
  const visiblePieces = pieces.slice(Math.max(0, pieces.length - 5));

  return (
    <span className="checker-stack">
      {visiblePieces.map((color, index) => {
        const offset = `${index * 12}px`;
        const style = isTop ? { top: offset } : { bottom: offset };

        return (
          <span
            key={`${color}-${index}`}
            className="checker"
            style={{
              ...style
            }}
          >
            <span
              className="checker-image"
              style={{
                backgroundImage: `url(${CHECKER_IMAGES[color]})`
              }}
            />
          </span>
        );
      })}
      {pieces.length > 5 ? <span className="stack-count">{pieces.length}</span> : null}
    </span>
  );
}
