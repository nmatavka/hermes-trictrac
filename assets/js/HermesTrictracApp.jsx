import React, { useEffect, useMemo, useRef, useState } from "react";
import { createRoot } from "react-dom/client";
import ChatPanel from "./ChatPanel";
import {
  boolLabel,
  colorLabel as i18nColorLabel,
  getLanguage,
  languageSelectOptions,
  localizeError,
  optionChoiceLabel,
  optionLabel,
  setLanguage,
  subscribeLanguage,
  t,
  tx,
  variantTitle
} from "./i18n";
import { SOUND_PACK_OPTIONS, createSoundController } from "./sound";
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

const TRICTRAC_BOT_KIND = "trictrac_zero";
const TRICTRAC_BOT_DISPLAY_NAME = "Dr Toutabas, Vicomte de la Case";

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
const ENGLAND_FLAG = String.fromCodePoint(0x1f3f4, 0xe0067, 0xe0062, 0xe0065, 0xe006e, 0xe0067, 0xe007f);
const LANGUAGE_FLAG_LABELS = {
  en: ENGLAND_FLAG,
  fr: "🇫🇷",
  da: "🇩🇰",
  sv: "🇸🇪",
  de: "🇩🇪"
};
const LANGUAGE_BUTTON_ORDER = ["en", "fr", "da", "sv", "de"];

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

function uiMarqueCopy(text) {
  return String(text || "")
    .replace(/\bMarques\b/g, "Marqués")
    .replace(/\bmarques\b/g, "marqués")
    .replace(/\bMarque\b/g, "Marqué")
    .replace(/\bmarque\b/g, "marqué");
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

  return t("score.event");
}

function buildTrictracToast(event) {
  const beneficiary = event?.beneficiary === "black" ? "black" : "white";
  const points = Number(event?.points ?? 0);

  return {
    title: t("score.wins", { color: colorLabel(beneficiary), points }),
    detail: scoreEventDetail(event)
  };
}

function stableSignature(value) {
  try {
    return JSON.stringify(value || null);
  } catch (_error) {
    return "unserializable";
  }
}

function boardSoundSignature(game) {
  const board = game?.board || {};

  return stableSignature({
    points: (board.points || []).map((point) => ({
      index: point.index,
      white: point.white || 0,
      black: point.black || 0
    })),
    bar: board.bar || {},
    outside: board.outside || {}
  });
}

function diceValuesSignature(game) {
  const dice = game?.dice;

  if (!dice) {
    return "";
  }

  return stableSignature({
    color: game?.turn?.color || "",
    values: dice.values || []
  });
}

function movesPlayedCount(game) {
  return (game?.dice?.moves_played || []).length;
}

function openingRollSignature(game) {
  return stableSignature(game?.opening_roll?.rolls || {});
}

function decisionSignature(game) {
  const decision = game?.pending_turn_decision;

  if (!decision) {
    return "";
  }

  return stableSignature({
    key: decision.key,
    actorColor: decision.actorColor || game?.turn?.color || "",
    choices: decision.choices || []
  });
}

function chatMessageSignature(message) {
  return stableSignature({
    author: message?.author ?? message?.player ?? "",
    text: message?.data?.text ?? message?.text ?? ""
  });
}

function gameSoundSignature(game) {
  const scoreHistory = Array.isArray(game?.trictrac?.score_history) ? game.trictrac.score_history : [];
  const chat = Array.isArray(game?.chat) ? game.chat : [];

  return stableSignature({
    board: boardSoundSignature(game),
    dice: diceValuesSignature(game),
    movesPlayed: movesPlayedCount(game),
    openingRoll: openingRollSignature(game),
    decision: decisionSignature(game),
    turn: {
      color: game?.turn?.color || "",
      number: game?.turn?.number || 0,
      player: game?.turn?.player_name || ""
    },
    match: {
      over: !!game?.match?.is_over,
      winner: game?.match?.winner || "",
      winnerKind: game?.match?.winner_kind || ""
    },
    scoreLength: scoreHistory.length,
    scoreLast: scoreEventSignature(scoreHistory[scoreHistory.length - 1]),
    chatLength: chat.length,
    chatLast: chatMessageSignature(chat[chat.length - 1])
  });
}

function pendingDecisionActor(game) {
  return game?.pending_turn_decision?.actorColor || game?.turn?.color || "";
}

function latestAction(lastActionRef) {
  const action = lastActionRef.current;

  if (!action || Date.now() - action.time > 5000) {
    lastActionRef.current = null;
    return null;
  }

  lastActionRef.current = null;
  return action.event;
}

function newIncomingChat(previousGame, nextGame, playerColor) {
  const previousChat = Array.isArray(previousGame?.chat) ? previousGame.chat : [];
  const nextChat = Array.isArray(nextGame?.chat) ? nextGame.chat : [];

  if (nextChat.length <= previousChat.length) {
    return false;
  }

  return nextChat.slice(previousChat.length).some((message) => {
    const author = message?.author ?? message?.player;
    return author !== playerColor;
  });
}

function detectSoundCues(previousGame, nextGame, options) {
  if (!previousGame || !nextGame) {
    return [];
  }

  const cues = [];
  const localAction = options.lastAction;

  const boardChanged = boardSoundSignature(previousGame) !== boardSoundSignature(nextGame);
  const previousMovesPlayed = movesPlayedCount(previousGame);
  const nextMovesPlayed = movesPlayedCount(nextGame);
  const turnChanged = previousGame?.turn?.color !== nextGame?.turn?.color;
  const diceChanged = diceValuesSignature(previousGame) !== diceValuesSignature(nextGame);
  const winnerChanged =
    previousGame?.match?.winner !== nextGame?.match?.winner ||
    previousGame?.match?.winner_kind !== nextGame?.match?.winner_kind;
  const matchRestarted = !!previousGame?.match?.is_over && !nextGame?.match?.is_over;
  const matchEnded =
    (!previousGame?.match?.is_over && !!nextGame?.match?.is_over) ||
    (localAction === "resign" && !!nextGame?.match?.is_over) ||
    (!!nextGame?.match?.is_over && winnerChanged);
  const confirmResolved =
    localAction === "confirm" ||
    (previousGame?.dice && !nextGame?.dice) ||
    (previousGame?.turn?.color && turnChanged);

  if (localAction === "reset" || matchRestarted) {
    cues.push(nextGame?.opening_roll?.pending ? "openingRoll" : "turnStart");
    return cues;
  }

  if (openingRollSignature(previousGame) !== openingRollSignature(nextGame)) {
    cues.push("openingRoll");
  }

  if (diceChanged && nextGame?.dice) {
    cues.push("roll");
  }

  if (boardChanged && !confirmResolved && nextMovesPlayed < previousMovesPlayed) {
    cues.push("undo");
  } else if (boardChanged && !confirmResolved && nextMovesPlayed > previousMovesPlayed) {
    cues.push(localAction === "move" || previousGame?.turn?.color === options.playerColor ? "move" : "botMove");
  } else if (boardChanged && !confirmResolved && localAction === "undo") {
    cues.push("undo");
  } else if (boardChanged && !confirmResolved) {
    cues.push(previousGame?.turn?.color === options.playerColor ? "move" : "opponentMove");
  }

  if (confirmResolved) {
    cues.push("confirm");
  }

  if (
    previousGame?.turn?.color !== options.playerColor &&
    nextGame?.turn?.color === options.playerColor &&
    !nextGame?.pending_match_options &&
    !nextGame?.pending_turn_decision &&
    !nextGame?.match?.is_over
  ) {
    cues.push("turnStart");
  }

  if (
    !previousGame?.pending_turn_decision &&
    nextGame?.pending_turn_decision &&
    pendingDecisionActor(nextGame) === options.playerColor
  ) {
    cues.push("decision");
  }

  if (options.scoreEventsCount > 0) {
    cues.push("score");
  }

  if (newIncomingChat(previousGame, nextGame, options.playerColor)) {
    cues.push("chat");
  }

  if (matchEnded) {
    cues.push("matchWin");
  }

  return cues;
}

function decisionPrompt(payload) {
  switch (payload?.key) {
    case "reprise":
      return t("decision.reprise");
    case "suspension":
      return t("decision.suspension");
    default:
      if (payload?.prompt === "Suspend one track?") {
        return t("decision.suspendOneTrack");
      }

      return tx(`decision.prompt.${payload?.key}`, payload?.prompt || capitalizeFirst(humanizeToken(payload?.key || "turn decision")));
  }
}

function decisionChoiceLabel(choice) {
  return tx(`decision.${choice}`, capitalizeFirst(humanizeToken(choice)));
}

function colorLabel(color) {
  return i18nColorLabel(color) || capitalizeFirst(humanizeToken(color || "unknown"));
}

function colorSubjectLabel(color) {
  return tx(`colorSubject.${color || "unknown"}`, colorLabel(color));
}

function trictracBotDisplayName(game) {
  return game?.bot?.enabled && game?.bot?.kind === TRICTRAC_BOT_KIND
    ? TRICTRAC_BOT_DISPLAY_NAME
    : null;
}

function seatName(game, seat) {
  const player = game?.players?.[seat];
  const botName = trictracBotDisplayName(game);

  if (botName && player?.name === game?.bot?.name) {
    return botName;
  }

  return player?.name;
}

function playerNameForColor(game, color) {
  if (!color) {
    return t("game.currentPlayer");
  }

  return color === "white"
    ? seatName(game, "host") || colorLabel(color)
    : seatName(game, "guest") || colorLabel(color);
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
  const id = game?.variant?.active_leg?.id || game?.variant?.id || "";
  return variantTitle(id, game?.variant?.active_leg?.title || game?.variant?.title || "");
}

function trictracScoreEntry(trictrac, color) {
  const entries = trictrac?.score || [];
  return color === "black" ? entries[1] || {} : entries[0] || {};
}

function holderFromFlags(flags) {
  const white = !!(flags?.white ?? flags?.White);
  const black = !!(flags?.black ?? flags?.Black);

  if (white && !black) {
    return colorLabel("white");
  }

  if (black && !white) {
    return colorLabel("black");
  }

  return t("none");
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

  return [6, 8, 10, 12, 14, 16, 18, 20, 22, 24].includes(parsed) ? parsed : 16;
}

function aecrireRoundedGain(game) {
  return Number(game?.trictrac?.track_aecrire?.rounded_gain || 0);
}

function aecrireGrossGain(game) {
  return Number(game?.trictrac?.track_aecrire?.gross_gain || 0);
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
    t("detail.queueJetons", { value: formatSignedValue(ledger.queue_jetons || 0) }),
    t("detail.marques", { value: formatSignedValue(ledger.marque_points || 0) }),
    t("detail.queueMarques", { value: formatSignedValue(ledger.queue_paris || 0) }),
    t("detail.final", { value: ledger.final_total || 0 })
  ];
}

function formatPoints(count) {
  return t("units.point", { count: Number(count || 0) });
}

function formatTrous(count) {
  return t("units.trou", { count: Number(count || 0) });
}

function formatHonneurs(count) {
  return t("units.honneur", { count: Number(count || 0) });
}

function formatJetons(count) {
  return t("units.jeton", { count: Number(count || 0) });
}

function formatMarquesProgress(count, total) {
  return t("detail.marquesProgress", { count: Number(count || 0), total: Number(total || 0) });
}

function formatColorTrous(color, count) {
  return t("detail.colorTrous", { color: colorLabel(color), holes: formatTrous(count) });
}

function formatPointsAndTrous(points, trous) {
  return t("detail.pointsAndTrous", { points: formatPoints(points), holes: formatTrous(trous) });
}

function aecrireLastMarqueLines(game) {
  const aecrire = game?.trictrac?.track_aecrire || {};
  const result = aecrire.last_marque_result;
  const nextConsolation = ((aecrire.refait_streak || 0) + 1) * 2;

  if (!result) {
    return [t("detail.noMarque")];
  }

  if (result.refait) {
    return [t("detail.refait"), t("detail.nextConsolation", { value: nextConsolation })];
  }

  const lines = [
    `${colorLabel(result.winner)} ${formatSignedValue(result.points_awarded)} ${t("units.point", { count: Math.abs(Number(result.points_awarded || 0)) }).replace(/^-?\d+\s*/, "")}`,
    t("detail.trouAgainst", { winner: result.winner_trous || 0, loser: result.loser_trous || 0 })
  ];

  if (result.bredouille) {
    lines.push(`${capitalizeFirst(result.bredouille)} bredouille x${result.multiplier}`);
  } else if (result.voluntary_loss) {
    lines.push(t("detail.voluntaryLoss"));
  } else {
    lines.push(t("detail.simpleMarque"));
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
    winner ? t("game.wonByPoints", { winner: colorSubjectLabel(winner), points: aecrireRoundedGain(game) }) : t("game.drawnSettlement"),
    t("detail.gainExact", { value: aecrireGrossGain(game) }),
    t("detail.gainArrondi", { value: aecrireRoundedGain(game) })
  ];
}

function combineLastPartieLines(game) {
  const result = game?.trictrac?.track_classique_honneurs?.last_partie_result;

  if (!result) {
    return [t("detail.noHonneurs")];
  }

  const carried = Number(result.carried_trous || 0);

  return [
    t("detail.wonClass", { color: colorLabel(result.winner), klass: humanizeToken(result.class) }),
    formatHonneurs(result.value),
    carried > 0 ? t("detail.carried", { count: carried }) : t("detail.noCarry")
  ];
}

function combineStateLines(game) {
  const combine = game?.trictrac?.track_classique_honneurs || {};
  const current = combine.current_partie || {};
  const white = Number(current.trous?.white || 0);
  const black = Number(current.trous?.black || 0);

  return [
    t("detail.currentPartieWhite", { value: formatTrous(white) }),
    t("detail.currentPartieBlack", { value: formatTrous(black) }),
    white >= 11 || black >= 11 ? t("detail.honneursNear") : t("detail.honneursProgress")
  ];
}

function combineSuspensionLines(game) {
  const suspension = game?.trictrac?.suspension_state || {};

  if (!suspension.resume_pending || !suspension.suspended_track) {
    return [t("none")];
  }

  const trackLabel =
    suspension.suspended_track === "a_ecrire"
      ? "A ecrire"
      : suspension.suspended_track === "classique"
        ? "Honneurs"
        : humanizeToken(suspension.suspended_track);

  return [
    t("detail.suspended", { track: trackLabel }),
    t("detail.frozenBy", { color: colorLabel(suspension.frozen_by) }),
    t("detail.resumesOnReleve")
  ];
}

function matchOptionLabel(key) {
  switch (key) {
    case "tavliTarget":
      return t("options.pointsToPlay");
    case "aEcrirePartieLength":
      return t("options.marquesToPlay");
    case "holeTarget":
      return t("options.holesToPlay");
    case "matchLength":
      return t("options.matchLength");
    case "doublesMode":
      return t("options.doublesMode");
    case "margotEnabled":
      return t("options.margot");
    default:
      return capitalizeFirst(humanizeToken(key));
  }
}

function matchOptionValue(key, value) {
  if (typeof value === "boolean") {
    return boolLabel(value);
  }

  switch (key) {
    case "tavliTarget":
      return t("units.point", { count: value });
    case "aEcrirePartieLength":
      return t("units.marque", { count: value });
    case "holeTarget":
      return t("units.hole", { count: value });
    case "matchLength":
      return t("units.game", { count: value });
    case "doublesMode":
      return value === "on" ? t("on") : t("off");
    default:
      return String(value);
  }
}

function aecrireMatchResultText(game) {
  const winner = game?.match?.winner || game?.trictrac?.track_aecrire?.winner;

  if (!winner) {
    return null;
  }

  return t("game.wonByPoints", { winner: colorSubjectLabel(winner), points: aecrireRoundedGain(game) });
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
    return t("matchResult.gameDraw", {
      number: index + 1,
      kind: `${legLabel}${humanizeToken(result?.kind || "draw")}`,
      award: awardText
    });
  }

  return t("matchResult.gameWin", {
    number: index + 1,
    leg: legLabel,
    winner: colorSubjectLabel(result.winner),
    award: awardText,
    kind: humanizeToken(result.kind)
  });
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
        { label: colorLabel("white"), value: `${whiteScore.trous || 0}/${whiteScore.points || 0}` },
        { label: colorLabel("black"), value: `${blackScore.trous || 0}/${blackScore.points || 0}` }
      ];

    case "toc":
      return [
        { label: colorLabel("white"), value: t("units.hole", { count: game?.match?.score?.white ?? 0 }) },
        { label: colorLabel("black"), value: t("units.hole", { count: game?.match?.score?.black ?? 0 }) }
      ];

    case "tavli": {
      const target = game?.match?.length ?? 7;

      return [
        { label: colorLabel("white"), value: `${game?.match?.score?.white ?? 0}/${target}` },
        { label: colorLabel("black"), value: `${game?.match?.score?.black ?? 0}/${target}` }
      ];
    }

    case "trictrac_aecrire": {
      return [
        { label: colorLabel("white"), value: `${whiteAecrireTotal}` },
        { label: colorLabel("black"), value: `${blackAecrireTotal}` }
      ];
    }

    case "trictrac_combine": {
      const marques = aecrire.marques || {};
      const honneurs = combine.honneurs || {};

      return [
        {
          label: colorLabel("white"),
          value: `${t("units.marque", { count: marques.white || 0 })} / ${formatHonneurs(honneurs.white)} / ${formatJetons(whiteAecrireTotal)}`
        },
        {
          label: colorLabel("black"),
          value: `${t("units.marque", { count: marques.black || 0 })} / ${formatHonneurs(honneurs.black)} / ${formatJetons(blackAecrireTotal)}`
        }
      ];
    }

    default:
      return [
        { label: colorLabel("white"), value: game?.match?.score?.white ?? 0 },
        { label: colorLabel("black"), value: game?.match?.score?.black ?? 0 }
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
          title: t("detail.bredouille"),
          lines: [holderFromFlags({ white: whiteScore.bredouille, black: blackScore.bredouille })]
        },
        {
          title: t("detail.grandeBredouille"),
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
        { title: colorLabel("white"), lines: [formatPoints(whiteScore.points), formatTrous(whiteScore.trous)] },
        { title: colorLabel("black"), lines: [formatPoints(blackScore.points), formatTrous(blackScore.trous)] },
        {
          title: t("detail.bredouille"),
          lines: [holderFromFlags({ white: whiteScore.bredouille, black: blackScore.bredouille })]
        },
        {
          title: t("detail.grandeBredouille"),
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
        { title: colorLabel("white"), lines: [formatPoints(whiteScore.points), formatTrous(whiteScore.trous)] },
        { title: colorLabel("black"), lines: [formatPoints(blackScore.points), formatTrous(blackScore.trous)] }
      ];

    case "toc":
      return [
        {
          title: colorLabel("white"),
          lines: [
            t("units.hole", { count: game?.match?.score?.white ?? 0 }),
            ...((whiteScore.points || 0) > 0 || (whiteScore.trous || 0) > 0
              ? [formatPointsAndTrous(whiteScore.points, whiteScore.trous)]
              : [])
          ]
        },
        {
          title: colorLabel("black"),
          lines: [
            t("units.hole", { count: game?.match?.score?.black ?? 0 }),
            ...((blackScore.points || 0) > 0 || (blackScore.trous || 0) > 0
              ? [formatPointsAndTrous(blackScore.points, blackScore.trous)]
              : [])
          ]
        },
        {
          title: t("detail.bredouille"),
          lines: [holderFromFlags({ white: whiteScore.bredouille, black: blackScore.bredouille })]
        },
        {
          title: t("detail.grandeBredouille"),
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
          title: colorLabel("white"),
          lines: [
            formatMarquesProgress(marques.white, partieLength),
            t("detail.beforeQueues", { value: aecrirePoints.white || 0 }),
            ...(aecrireOver ? [t("detail.finalValue", { value: whiteLedger.final_total || 0 })] : [])
          ]
        },
        {
          title: colorLabel("black"),
          lines: [
            formatMarquesProgress(marques.black, partieLength),
            t("detail.beforeQueues", { value: aecrirePoints.black || 0 }),
            ...(aecrireOver ? [t("detail.finalValue", { value: blackLedger.final_total || 0 })] : [])
          ]
        },
        { title: t("detail.currentCoup"), lines: [formatColorTrous("white", coupTrous.white), formatColorTrous("black", coupTrous.black)] },
        { title: t("detail.consolation"), lines: [t("detail.nextJetons", { value: nextConsolation }), refaitStreak > 0 ? t("detail.refaitCount", { count: refaitStreak }) : t("detail.noRefait")] },
        { title: t("detail.lastMarque"), lines: aecrireLastMarqueLines(game) },
        ...(aecrireOver
          ? [
              { title: t("detail.whiteSettlement"), lines: aecrireSettlementLines(game, "white") },
              { title: t("detail.blackSettlement"), lines: aecrireSettlementLines(game, "black") },
              { title: t("detail.result"), lines: aecrireResult }
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
          title: t("detail.whiteAEcrire"),
          lines: [
            formatMarquesProgress(marques.white, partieLength),
            t("detail.beforeQueues", { value: aecrirePoints.white || 0 }),
            ...(aecrireOver ? [t("detail.finalValue", { value: whiteLedger.final_total || 0 })] : [])
          ]
        },
        {
          title: t("detail.blackAEcrire"),
          lines: [
            formatMarquesProgress(marques.black, partieLength),
            t("detail.beforeQueues", { value: aecrirePoints.black || 0 }),
            ...(aecrireOver ? [t("detail.finalValue", { value: blackLedger.final_total || 0 })] : [])
          ]
        },
        {
          title: t("detail.whiteHonneurs"),
          lines: [
            formatHonneurs(honneurs.white),
            t("detail.partieTrous", { count: partieTrous.white || 0 }),
            t("detail.compactClasses", { value: formatCompactClasses(classes.white) })
          ]
        },
        {
          title: t("detail.blackHonneurs"),
          lines: [
            formatHonneurs(honneurs.black),
            t("detail.partieTrous", { count: partieTrous.black || 0 }),
            t("detail.compactClasses", { value: formatCompactClasses(classes.black) })
          ]
        },
        { title: t("detail.honneursState"), lines: combineStateLines(game) },
        { title: t("detail.suspension"), lines: combineSuspensionLines(game) },
        { title: t("detail.lastHonneurs"), lines: combineLastPartieLines(game) },
        { title: t("detail.currentCoup"), lines: [formatColorTrous("white", coupTrous.white), formatColorTrous("black", coupTrous.black)] },
        { title: t("detail.consolation"), lines: [t("detail.nextJetons", { value: nextConsolation }), refaitStreak > 0 ? t("detail.refaitCount", { count: refaitStreak }) : t("detail.noRefait")] },
        { title: t("detail.lastMarque"), lines: aecrireLastMarqueLines(game) },
        ...(aecrireOver
          ? [
              { title: t("detail.whiteSettlement"), lines: aecrireSettlementLines(game, "white") },
              { title: t("detail.blackSettlement"), lines: aecrireSettlementLines(game, "black") },
              { title: t("detail.result"), lines: aecrireResult }
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
    return t("waiting");
  }

  const labeledChoice =
    payload?.kind === "trictrac_partie_length_consent"
      ? t("units.marque", { count: answer })
      : payload?.kind === "tavli_target_consent"
        ? t("units.point", { count: answer })
        : payload?.choiceLabels?.[answer];

  if (labeledChoice) {
    return uiMarqueCopy(labeledChoice);
  }

  switch (answer) {
    case "yes":
      return t("yes");
    case "no":
      return t("no");
    default:
      return decisionChoiceLabel(answer);
  }
}

function pendingPrompt(payload) {
  switch (payload?.kind) {
    case "tavli_target_consent":
      return t("options.tavliPrompt");
    case "trictrac_margot_consent":
      return t("options.margotPrompt");
    case "trictrac_partie_length_consent":
      return t("options.partieLengthPrompt");
    default:
      return uiMarqueCopy(payload?.prompt || t("game.choosePregame"));
  }
}

function OpeningRollDie({ color, value }) {
  if (value == null) {
    return <span className="opening-roll-waiting">{t("waiting")}</span>;
  }

  return (
    <img
      className="themed-die"
      src={DICE_IMAGES[color][value]}
      alt={t("game.openingDieAlt", { color: colorLabel(color), value })}
    />
  );
}

export default function gameInit(root, channel, options = {}) {
  const joinTimeoutMs = options.joinTimeoutMs ?? 15000;
  const onJoinComplete = options.onJoinComplete ?? (() => {});
  const onJoinError = options.onJoinError ?? ((resp) => {
    root.textContent = localizeError(resp, "errors.unknown");
  });
  const onJoinTimeout = options.onJoinTimeout ?? (() => {
    root.textContent = t("join.timedOut");
  });
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
      onJoinError(resp);
    })
    .receive("timeout", () => {
      onJoinComplete();
      onJoinTimeout();
    });
}

function HermesTrictracApp({ channel, initialGame, player, playerName, lobbyName, requestedBotMargot }) {
  const playerColor = player?.color ?? "white";
  const soundControllerRef = useRef(null);

  if (!soundControllerRef.current) {
    soundControllerRef.current = createSoundController();
  }

  const [game, setGame] = useState(initialGame);
  const [language, setLanguageState] = useState(getLanguage());
  const [soundState, setSoundState] = useState(() => soundControllerRef.current.getSnapshot());
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
  const latestGameRef = useRef(initialGame);
  const gameSoundSignatureRef = useRef(gameSoundSignature(initialGame));
  const lastActionRef = useRef(null);
  const pendingActionRef = useRef(null);
  const scoreHistoryCursorRef = useRef(initialScoreHistory.length);
  const lastSeenScoreEventRef = useRef(scoreEventSignature(initialScoreHistory[initialScoreHistory.length - 1]));
  const [pendingAction, setPendingAction] = useState(null);

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
      return [];
    }

    if (nextHistory.length < previousLength) {
      scoreHistoryCursorRef.current = nextHistory.length;
      lastSeenScoreEventRef.current = scoreEventSignature(nextHistory[nextHistory.length - 1]);
      return [];
    }

    if (previousLength > 0) {
      const currentPrefixSignature = scoreEventSignature(nextHistory[previousLength - 1]);

      if (currentPrefixSignature !== previousSignature) {
        scoreHistoryCursorRef.current = nextHistory.length;
        lastSeenScoreEventRef.current = scoreEventSignature(nextHistory[nextHistory.length - 1]);
        return [];
      }
    }

    const newEvents = nextHistory.length > previousLength ? nextHistory.slice(previousLength) : [];

    if (nextHistory.length > previousLength) {
      newEvents.forEach((event) => {
        queueToast(buildTrictracToast(event));
      });
    }

    scoreHistoryCursorRef.current = nextHistory.length;
    lastSeenScoreEventRef.current = scoreEventSignature(nextHistory[nextHistory.length - 1]);
    return newEvents;
  };

  useEffect(() => subscribeLanguage(setLanguageState), []);

  useEffect(() => {
    const controller = soundControllerRef.current;
    const unsubscribe = controller.subscribe(setSoundState);
    const unlock = () => {
      controller.unlock();
    };
    const unlockWhenVisible = () => {
      if (document.visibilityState === "visible") {
        controller.unlock();
      }
    };

    window.addEventListener("pointerdown", unlock, { passive: true });
    window.addEventListener("keydown", unlock);
    window.addEventListener("focus", unlockWhenVisible);
    window.addEventListener("pageshow", unlockWhenVisible);
    document.addEventListener("visibilitychange", unlockWhenVisible);

    return () => {
      unsubscribe();
      window.removeEventListener("pointerdown", unlock);
      window.removeEventListener("keydown", unlock);
      window.removeEventListener("focus", unlockWhenVisible);
      window.removeEventListener("pageshow", unlockWhenVisible);
      document.removeEventListener("visibilitychange", unlockWhenVisible);
    };
  }, []);

  useEffect(() => {
    const updateRef = channel.on("update", (resp) => {
      const previousGame = latestGameRef.current;
      const nextSignature = gameSoundSignature(resp.game);
      const isDuplicateUpdate = nextSignature === gameSoundSignatureRef.current;
      const scoreEvents = syncTrictracToasts(resp.game);

      if (!isDuplicateUpdate) {
        const cues = detectSoundCues(previousGame, resp.game, {
          playerColor,
          lastAction: latestAction(lastActionRef),
          scoreEventsCount: scoreEvents.length
        });

        soundControllerRef.current.playMany(cues);
      } else {
        latestAction(lastActionRef);
      }

      latestGameRef.current = resp.game;
      gameSoundSignatureRef.current = nextSignature;
      pendingActionRef.current = null;
      setPendingAction(null);
      setGame(resp.game);
      setErrorMessage("");
      setSelectedFrom(null);
    });

    return () => {
      channel.off("update", updateRef);
    };
  }, [channel, playerColor]);

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
    if (pendingActionRef.current) {
      return;
    }

    pendingActionRef.current = event;
    setPendingAction(event);
    lastActionRef.current = { event, time: Date.now() };

    channel
      .push(event, payload)
      .receive("error", (resp) => {
        pendingActionRef.current = null;
        setPendingAction(null);
        lastActionRef.current = null;
        soundControllerRef.current.play("error");
        setErrorMessage(localizeError(resp, "errors.action_failed"));
      })
      .receive("timeout", () => {
        pendingActionRef.current = null;
        setPendingAction(null);
        lastActionRef.current = null;
        soundControllerRef.current.play("error");
        setErrorMessage(t("errors.action_failed"));
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
  const onRemainSeated = () => {
    pushWithError("remain_seated");
  };

  const diceTheme = game.turn?.color || playerColor;
  const botDisplayName = trictracBotDisplayName(game) || game.bot?.name || t("lobby.computer");
  const heroCopy = game.bot?.enabled
    ? t("game.againstBot", { color: colorLabel(playerColor), bot: botDisplayName })
    : t("game.againstHuman", { color: colorLabel(playerColor) });
  const toggleSound = () => {
    soundControllerRef.current.setEnabled(!soundState.enabled);
  };
  const selectSoundPack = (packId) => {
    soundControllerRef.current.setPack(packId);
  };
  const selectLanguage = (locale) => {
    setLanguageState(setLanguage(locale));
  };

  return (
    <div className="app-shell">
      {toasts.length > 0 ? <ToastStack toasts={toasts} /> : null}
      <section className="hero-panel">
        <div>
          <p className="eyebrow">{variantTitle(game.variant?.id, game.variant?.title || t("game.tableGame"))}</p>
          <h1>{lobbyName}</h1>
          <p className="hero-copy">{heroCopy}</p>
        </div>
        <div className="hero-meta">
          <span>{t("game.host")}: {seatName(game, "host") || t("waiting")}</span>
          <span>{t("game.guest")}: {seatName(game, "guest") || t("waiting")}</span>
          <span>{t("game.turn", { number: game.turn?.number || 0 })}</span>
          <SoundToggle state={soundState} onToggle={toggleSound} />
          <SoundPackSelect state={soundState} onChange={selectSoundPack} />
          <LanguageSelect language={language} onChange={selectLanguage} />
        </div>
      </section>

      <div className="game-layout">
        <aside className="action-rail">
          <StatusCard game={game} playerColor={playerColor} playerName={playerName} />
          <SeatReclaimCard payload={game.seat_reclaim} playerColor={playerColor} onRemainSeated={onRemainSeated} />
          <DiceCard color={displayedDiceColor} dice={displayedDice} isCurrentRoll={displayedDiceIsCurrent} />
          {isOpeningRollPending ? <OpeningRollCard payload={openingRoll} playerColor={playerColor} /> : null}
          <ActionCard
            game={game}
            isSeatedPlayer={isSeatedPlayer}
            isTurnPlayer={isTurnPlayer}
            playerColor={playerColor}
            openingRoll={openingRoll}
            pendingAction={pendingAction}
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
              if (window.confirm(t("game.resignConfirm"))) {
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
          <ChatPanel messages={messageList} onSendMessage={onMessageWasSent} t={t} />
        </main>
      </div>
    </div>
  );
}

function SoundToggle({ state, onToggle }) {
  const label = !state.supported
    ? t("game.soundUnavailable")
    : state.enabled
      ? t("game.soundOn")
      : t("game.soundOff");
  const title = !state.supported
    ? t("game.soundUnavailableTitle")
    : state.enabled
      ? state.unlocked
        ? t("game.soundOffTitle")
        : t("game.soundOffLockedTitle")
      : t("game.soundOnTitle");

  return (
    <button
      type="button"
      className="sound-toggle"
      onClick={onToggle}
      disabled={!state.supported}
      aria-pressed={state.enabled}
      title={title}
    >
      {label}
    </button>
  );
}

function SoundPackSelect({ state, onChange }) {
  return (
    <label className="sound-pack-select">
      <span>{t("game.pack")}</span>
      <select
        value={state.packId}
        onChange={(event) => onChange(event.target.value)}
        disabled={!state.supported}
        title={t("game.packTitle")}
      >
        {SOUND_PACK_OPTIONS.map((option) => (
          <option key={option.id} value={option.id}>
            {option.label}
          </option>
        ))}
      </select>
    </label>
  );
}

function LanguageSelect({ language, onChange }) {
  const optionsById = new Map(languageSelectOptions().map((option) => [option.id, option]));

  return (
    <div className="language-button-group hero-language-select" role="group" aria-label={t("language")}>
      {LANGUAGE_BUTTON_ORDER.map((id) => {
        const option = optionsById.get(id);
        const label = option?.label || id;
        const active = language === id;
        return (
          <button
            key={id}
            type="button"
            className={`language-flag-button ${active ? "active" : ""}`}
            onClick={() => onChange(id)}
            aria-label={label}
            aria-pressed={active}
            title={label}
          >
            {LANGUAGE_FLAG_LABELS[id] || label}
          </button>
        );
      })}
    </div>
  );
}

function StatusCard({ game, playerColor, playerName }) {
  const summaryItems = trictracStatusLineItems(game);
  const winnerLabel = colorSubjectLabel(game.match?.winner);
  const activeLegTitle = game?.variant?.id === "tavli" ? effectiveVariantTitle(game) : null;
  const pendingDecisionActorColor = game.pending_turn_decision?.actorColor || game.turn?.color;
  const pendingDecisionActorName = playerNameForColor(game, pendingDecisionActorColor);
  const aecrireResultText =
    ["trictrac_aecrire", "trictrac_combine"].includes(game.variant?.id) && game.match?.winner_kind === "jetons"
      ? aecrireMatchResultText(game)
      : null;
  const whoseTurn =
    game.match?.is_over
      ? aecrireResultText || t("game.wonBy", { winner: winnerLabel, kind: humanizeToken(game.match?.winner_kind || "") })
      : game.status === "waiting_for_opponent"
      ? t("game.waitingOpponent")
      : game.opening_roll?.pending
        ? t("game.rollToStart")
      : game.pending_match_options?.kind === "tavli_target_consent"
        ? t("game.tavliAgreement")
      : game.pending_match_options?.kind === "trictrac_margot_consent"
        ? t("game.margotAgreement")
        : game.pending_match_options
          ? t("game.optionsAgreement")
        : game.pending_turn_decision
          ? t("game.decisionRequired", { player: pendingDecisionActorName })
          : game.turn?.player_name
            ? t("game.toMove", { player: playerNameForColor(game, game.turn?.color) })
            : t("game.settingUp");

  return (
    <section className="rail-card">
      <p className="rail-label">{t("game.seat")}</p>
      <h2>{playerName}</h2>
      <p className="seat-tag">{t("game.youAre", { color: colorLabel(playerColor) })}</p>
      <p className="status-line">{whoseTurn}</p>
      {activeLegTitle ? <p className="muted-copy">{t("game.currentLeg", { leg: activeLegTitle })}</p> : null}
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

function SeatReclaimCard({ payload, playerColor, onRemainSeated }) {
  if (!payload || payload.seat_color !== playerColor) {
    return null;
  }

  const secondsLeft = Math.max(0, Math.ceil((Number(payload.expires_at_ms || 0) - Date.now()) / 1000));

  return (
    <section className="rail-card">
      <p className="rail-label">{t("game.seatWarning")}</p>
      <h2>{t("game.seatWanted")}</h2>
      <p className="status-line">
        {t("game.reclaimingSeat", { name: payload.claimant_name || t("someone") })}
      </p>
      <p className="muted-copy">
        {t("game.remainWithin", { seconds: secondsLeft })}
      </p>
      <div className="button-grid">
        <button type="button" onClick={onRemainSeated}>
          {t("game.remainSeated")}
        </button>
      </div>
    </section>
  );
}

function DiceCard({ color, dice, isCurrentRoll }) {
  if (!dice) {
    return (
      <section className="rail-card">
        <p className="rail-label">{t("game.dice")}</p>
        <p className="muted-copy">{t("game.noDice")}</p>
      </section>
    );
  }

  return (
    <section className="rail-card">
      <p className="rail-label">{t("game.dice")}</p>
      <div className="dice-row">
        {(dice.values || []).map((value, index) => (
          <img key={`${value}-${index}`} className="themed-die" src={DICE_IMAGES[color][value]} alt={t("game.dieAlt", { value })} />
        ))}
      </div>
      <p className="muted-copy">
        {isCurrentRoll ? t("game.movesLeft", { moves: (dice.moves_left || []).join(", ") || t("game.noMovesLeft") }) : t("game.awaitingRoll")}
      </p>
    </section>
  );
}

function OpeningRollCard({ payload, playerColor }) {
  const rolls = payload?.rolls || {};
  const opponent = oppositeColor(playerColor);

  return (
    <section className="rail-card">
      <p className="rail-label">{t("game.openingRoll")}</p>
      <h2>{t("game.rollToStart")}</h2>
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

function ActionCard({ game, isSeatedPlayer, isTurnPlayer, playerColor, openingRoll, pendingAction, onRoll, onUndo, onConfirm, onResign, onNewMatch }) {
  const actionPending = !!pendingAction;
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
  const canRoll = !actionPending && (canOpeningRoll || (canPlay && !game.dice && !game.pending_match_options && !game.pending_turn_decision));
  const canUndo = !actionPending && canPlay && !!game.dice && (game.dice.moves_played || []).length > 0 && !game.pending_turn_decision;
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
    !canEndTurn &&
    !actionPending;
  const canConfirm =
    !actionPending &&
    canPlay &&
    !!game.dice &&
    !hasMovesLeft &&
    !!game.ui_actions?.can_confirm &&
    !game.pending_turn_decision &&
    !canEndTurn;
  const showNewMatch = !!game.match?.is_over;
  const secondaryActionLabel = showNewMatch ? t("game.newMatch") : canEndTurn ? t("game.endTurn") : t("game.resign");
  const secondaryAction = showNewMatch ? onNewMatch : canEndTurn ? onConfirm : onResign;
  const secondaryDisabled = showNewMatch ? actionPending : canEndTurn ? !canEndTurn || actionPending : !isSeatedPlayer || actionPending;
  const undoAction = canPassDice ? onConfirm : onUndo;
  const undoDisabled = canPassDice ? false : !canUndo;
  const undoLabel = canPassDice ? t("game.passDice") : t("game.undo");

  return (
    <section className="rail-card">
      <p className="rail-label">{t("game.actions")}</p>
      <div className="button-grid">
        <button type="button" onClick={onRoll} disabled={!canRoll}>
          {t("game.roll")}
        </button>
        <button type="button" onClick={undoAction} disabled={undoDisabled}>
          {undoLabel}
        </button>
        <button type="button" onClick={onConfirm} disabled={!canConfirm}>
          {t("game.confirm")}
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
          {t("game.impuissance", { points: endTurnPoints, color: colorLabel(oppositeColor(playerColor)) })}
        </p>
      ) : null}
      {canPassDice ? (
        <p className="muted-copy">
          {t("game.passDiceHint")}
        </p>
      ) : null}
    </section>
  );
}

function OptionsCard({ payload, values, onChange, onSubmit }) {
  return (
    <section className="rail-card">
      <p className="rail-label">{t("game.matchOptions")}</p>
      <form className="stack-form" onSubmit={onSubmit}>
        {(payload.options || []).map((option) => (
          <label key={option.key} className="option-row">
            <span>{uiMarqueCopy(optionLabel(option))}</span>
            {Array.isArray(option.choices) ? (
              <select value={values[option.key] ?? option.defaultValue} onChange={(event) => onChange(option.key, event.target.value)}>
                {option.choices.map((choice) => (
                  <option key={choice.value} value={choice.value}>
                    {uiMarqueCopy(optionChoiceLabel(option.key, choice))}
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
        <button type="submit">{t("game.startMatch")}</button>
      </form>
    </section>
  );
}

function PregameChoiceCard({ payload, playerColor, onChoose }) {
  const responses = payload?.responses || {};
  const opponent = oppositeColor(playerColor);

  return (
    <section className="rail-card">
      <p className="rail-label">{t("game.pregame")}</p>
      <h2>{pendingPrompt(payload)}</h2>
      <div className="trictrac-grid">
        <div>
          <strong>{t("game.yourChoice")}</strong>
          <span>{pendingChoiceLabel(payload, responses[playerColor])}</span>
        </div>
        <div>
          <strong>{t("game.colorChoice", { color: colorLabel(opponent) })}</strong>
          <span>{pendingChoiceLabel(payload, responses[opponent])}</span>
        </div>
      </div>
      {payload?.kind === "trictrac_partie_length_consent" ? (
        <PartieLengthConsentSlider payload={payload} playerColor={playerColor} onChoose={onChoose} />
      ) : (
        <div className="button-grid">
          {(payload?.choices || []).map((choice) => (
            <button key={choice} type="button" onClick={() => onChoose(choice)}>
              {pendingChoiceLabel(payload, choice)}
            </button>
          ))}
        </div>
      )}
    </section>
  );
}

function PartieLengthConsentSlider({ payload, playerColor, onChoose }) {
  const choices = payload?.choices || [];
  const responses = payload?.responses || {};
  const currentChoice = responses[playerColor];
  const fallbackChoice = currentChoice && choices.includes(currentChoice) ? currentChoice : choices[0] || "16";
  const [selectedChoice, setSelectedChoice] = useState(fallbackChoice);
  const selectedIndex = Math.max(0, choices.indexOf(selectedChoice));

  useEffect(() => {
    setSelectedChoice(fallbackChoice);
  }, [fallbackChoice]);

  return (
    <div className="partie-length-slider">
      <p className="muted-copy">{t("game.selectedTarget", { target: pendingChoiceLabel(payload, selectedChoice) })}</p>
      <div className="partie-length-control">
        <input
          type="range"
          min="0"
          max={String(Math.max(choices.length - 1, 0))}
          step="1"
          value={String(selectedIndex)}
          onChange={(event) => {
            const nextChoice = choices[Number(event.target.value)] || fallbackChoice;
            setSelectedChoice(nextChoice);
          }}
        />
        <div className="partie-length-marks" aria-hidden="true">
          {choices.map((choice, index) => (
            <span
              key={choice}
              style={{ "--mark-position": `${choices.length <= 1 ? 0 : (index / (choices.length - 1)) * 100}%` }}
            >
              {choice}
            </span>
          ))}
        </div>
      </div>
      <button type="button" onClick={() => onChoose(selectedChoice)}>
        {t("game.chooseTarget", { target: pendingChoiceLabel(payload, selectedChoice) })}
      </button>
    </div>
  );
}

function TurnDecisionCard({ payload, onChoose }) {
  return (
    <section className="rail-card">
      <p className="rail-label">{t("game.decision")}</p>
      <h2>{decisionPrompt(payload)}</h2>
      {payload?.key ? <p className="muted-copy">{t("game.decisionKey", { key: humanizeToken(payload.key) })}</p> : null}
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
      <p className="rail-label">{t("game.trictracTrack")}</p>
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
      <p className="rail-label">{t("game.match")}</p>
      {showTocScore ? (
        <div className="trictrac-grid">
          <div>
            <strong>{colorLabel("white")}</strong>
            <span>{t("units.hole", { count: game.match?.score?.white ?? 0 })}</span>
          </div>
          <div>
            <strong>{colorLabel("black")}</strong>
            <span>{t("units.hole", { count: game.match?.score?.black ?? 0 })}</span>
          </div>
        </div>
      ) : null}
      {showTavliScore ? (
        <div className="trictrac-grid">
          <div>
            <strong>{colorLabel("white")}</strong>
            <span>{t("units.point", { count: game.match?.score?.white ?? 0 })}</span>
          </div>
          <div>
            <strong>{colorLabel("black")}</strong>
            <span>{t("units.point", { count: game.match?.score?.black ?? 0 })}</span>
          </div>
          <div>
            <strong>{t("game.target")}</strong>
            <span>{t("units.point", { count: game.match?.length ?? 7 })}</span>
          </div>
          <div>
            <strong>{t("game.currentLeg", { leg: "" }).replace(/:\s*$/, "")}</strong>
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
      {showLabel ? <p>{isTop ? t("game.opponentBar") : t("game.yourBar")}</p> : null}
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
      <p>{t("game.bearOff")}</p>
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
