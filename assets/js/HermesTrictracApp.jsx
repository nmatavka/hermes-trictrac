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

function normalizeMessage(message, viewer) {
  const text = message?.data?.text ?? message?.text ?? "";
  const authorId = message?.author_id ?? message?.authorId ?? null;
  const authorName = message?.author_name ?? message?.author ?? message?.player ?? "";
  const isSelf =
    authorId != null
      ? authorId === viewer?.id
      : authorName && viewer?.name
        ? authorName === viewer.name
        : false;

  return {
    ...message,
    author: isSelf ? "me" : "them",
    authorName,
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

function formatCashMinor(amount, scale = 100) {
  const normalizedAmount = Number(amount);
  const normalizedScale = Number(scale) || 100;

  if (!Number.isFinite(normalizedAmount)) {
    return null;
  }

  return (normalizedAmount / normalizedScale).toFixed(2);
}

function scoreEventSignature(event) {
  return JSON.stringify(event || null);
}

function scoreEventTranslationKey(event) {
  if (event?.rule) {
    return String(event.rule).toLowerCase();
  }

  if (event?.source) {
    return String(event.source).toLowerCase();
  }

  const normalizedLabel = String(event?.label || "")
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");

  switch (normalizedLabel) {
    case "jan_de_recompense":
      return "jan_recompense";
    case "jan_qui_ne_peut":
      return "jan_qui_ne_peut";
    default:
      return normalizedLabel;
  }
}

function scoreEventDetail(event) {
  const fallback =
    event?.label ||
    (event?.source ? humanizeToken(String(event.source).toLowerCase()) : t("score.event"));
  const key = scoreEventTranslationKey(event);

  if (key) {
    return tx(`scoreEvents.${key}`, fallback);
  }

  return fallback;
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
    author: message?.author_id ?? message?.authorId ?? message?.author ?? message?.player ?? "",
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

function newIncomingChat(previousGame, nextGame, viewerId) {
  const previousChat = Array.isArray(previousGame?.chat) ? previousGame.chat : [];
  const nextChat = Array.isArray(nextGame?.chat) ? nextGame.chat : [];

  if (nextChat.length <= previousChat.length) {
    return false;
  }

  return nextChat.slice(previousChat.length).some((message) => {
    const authorId = message?.author_id ?? message?.authorId;
    return authorId == null || authorId !== viewerId;
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

  if (newIncomingChat(previousGame, nextGame, options.viewerId)) {
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

function colorVictoryLabel(color) {
  return tx(`colorVictory.${color || "unknown"}`, colorSubjectLabel(color));
}

function localizedToken(namespace, value) {
  const key = String(value || "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");

  return tx(`${namespace}.${key}`, humanizeToken(value || ""));
}

function winnerKindLabel(kind) {
  return localizedToken("winnerKinds", kind);
}

function pointDisplayNumber(index, playerColor) {
  if (typeof index !== "number") {
    return "";
  }

  return playerColor === "black" ? index + 1 : 24 - index;
}

function boardSpaceLabel(space, playerColor) {
  if (space === "bar") {
    return t("game.bar");
  }

  if (space === "home") {
    return t("game.bearOff");
  }

  return typeof space === "number" ? String(pointDisplayNumber(space, playerColor)) : String(space ?? "");
}

function lastMoveText(game, playerColor) {
  const moves = Array.isArray(game?.last_moves) && game.last_moves.length > 0
    ? game.last_moves
    : game?.last_move
      ? [game.last_move]
      : [];

  if (moves.length === 0) {
    return null;
  }

  const segments = moves.map((move) =>
    t("game.moveSegment", {
      from: boardSpaceLabel(move.from, playerColor),
      to: boardSpaceLabel(move.to, playerColor)
    })
  );
  const movesText = formatLocalizedList(segments);
  const player = playerNameForColor(game, moves[moves.length - 1]?.color);

  return t("game.lastMoves", {
    player,
    moves: movesText
  });
}

function formatLocalizedList(items) {
  if (items.length <= 1) {
    return items[0] || "";
  }

  const last = items[items.length - 1];
  const leading = items.slice(0, -1).join(", ");
  return t("game.listJoin", { items: leading, last });
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
  return game?.variant?.active_variant_id || game?.variant?.id || "";
}

function effectiveVariantId(game) {
  return game?.variant?.active_leg?.id || game?.variant?.active_variant_id || game?.variant?.id || "";
}

function effectiveVariantTitle(game) {
  const id = game?.variant?.active_leg?.id || game?.variant?.active_variant_id || game?.variant?.id || "";
  return variantTitle(id, game?.variant?.active_leg?.title || game?.variant?.active_variant_title || game?.variant?.title || "");
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
    game?.multiplayer?.partie_length ??
    game?.trictrac?.track_aecrire?.partie_length ??
    game?.match?.options?.aEcrirePartieLength ??
    16;
  const parsed = Number(rawValue);

  return Number.isFinite(parsed) && parsed > 0 ? parsed : 16;
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
    winner ? t("game.wonByPoints", { winner: colorVictoryLabel(winner), points: aecrireRoundedGain(game) }) : t("game.drawnSettlement"),
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

  return t("game.wonByPoints", { winner: colorVictoryLabel(winner), points: aecrireRoundedGain(game) });
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
      kind: `${legLabel}${winnerKindLabel(result?.kind || "draw")}`,
      award: awardText
    });
  }

  return t("matchResult.gameWin", {
    number: index + 1,
    leg: legLabel,
    winner: colorVictoryLabel(result.winner),
    award: awardText,
    kind: winnerKindLabel(result.kind)
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
      : payload?.kind === "multiplayer_partie_length_consent"
        ? payload?.choiceLabels?.[answer] || `${answer} ${tx("game.coups", "Coups")}`
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
    case "multiplayer_partie_length_consent":
      return tx("options.multiplayerPartieLengthPrompt", "Choose the coup length.");
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
          viewer={resp.viewer || resp.game?.viewer || null}
          playerName={root.dataset.user}
          rulesUrl={root.dataset.rulesUrl || ""}
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

function HermesTrictracApp({ channel, initialGame, player, viewer: initialViewer, playerName, lobbyName, requestedBotMargot, rulesUrl }) {
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
  const viewer = game.viewer || initialViewer || null;
  const viewerSeatColor = viewer?.seat_color ?? null;
  const playerColor = viewerSeatColor || player?.color || "white";

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
          playerColor: viewerSeatColor,
          viewerId: viewer?.id ?? null,
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
  }, [channel, viewer?.id, viewerSeatColor]);

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
  const isActiveViewer = viewer?.role === "active";
  const isCompetitorViewer = viewer?.role === "active" || viewer?.role === "bench";
  const isTurnPlayer =
    isActiveViewer && (game.turn?.player_name === viewer?.name || activeTurnColor === viewerSeatColor);
  const isSeatedPlayer = isActiveViewer;
  const pendingMatchOptions = game.pending_match_options;
  const isConsensusChoice =
    Array.isArray(pendingMatchOptions?.choices) && !!pendingMatchOptions?.responses;
  const canRespondToPendingMatchOptions =
    pendingMatchOptions?.kind === "multiplayer_partie_length_consent"
      ? isCompetitorViewer
      : isSeatedPlayer;
  const pendingDecisionActorColor = game.pending_turn_decision?.actorColor || activeTurnColor;
  const canResolveTurnDecision =
    !!game.pending_turn_decision && isSeatedPlayer && pendingDecisionActorColor === viewerSeatColor;
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
  const boardHasActions = activeLegalMoves.length > 0;
  const boardPoints = new Map((game.board?.points || []).map((point) => [point.index, point]));
  const layout = BOARD_LAYOUTS[playerColor] || BOARD_LAYOUTS.white;
  const topColor = playerColor === "white" ? "black" : "white";
  const activeVariantId = effectiveVariantId(game);
  const showBarColumn =
    game.variant?.uses_bar == null
      ? !BAR_GRAPHICS_HIDDEN_VARIANTS.has(activeVariantId)
      : game.variant.uses_bar !== false;
  const displayedDice = game.opening_roll?.pending ? null : game.dice || lastVisibleDice?.dice || null;
  const displayedDiceColor = game.dice
    ? game.turn?.color || playerColor
    : lastVisibleDice?.color || playerColor;
  const displayedDiceIsCurrent = !!game.dice;

  const messageList = useMemo(
    () => (game.chat || []).map((message) => normalizeMessage(message, viewer)),
    [game.chat, viewer]
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
        type: "text",
        data: { text }
      }
    });
  };
  const onRemainSeated = () => {
    pushWithError("remain_seated");
  };

  const isPouleTable = !!game.poule;
  const isMultiplayerTable = !!game.multiplayer;
  const diceTheme = game.turn?.color || playerColor;
  const botDisplayName = trictracBotDisplayName(game) || game.bot?.name || t("lobby.computer");
  const trimmedRulesUrl = typeof rulesUrl === "string" ? rulesUrl.trim() : "";
  const heroCopy = isPouleTable
    ? viewer?.role === "active"
      ? tx("game.pouleOnBoard", "You are on the board right now.")
      : viewer?.role === "queued"
        ? tx("game.pouleQueued", "You are in the queue for the next rotation.")
        : tx("game.pouleSpectating", "You are watching this poule table.")
    : isMultiplayerTable
      ? viewer?.role === "active"
        ? tx("game.multiplayerOnBoard", "You are one of the active players on the board.")
        : viewer?.role === "bench"
          ? tx("game.multiplayerBench", "You are in the competitor rotation and waiting for your turn.")
          : tx("game.multiplayerSpectating", "You are watching this multi-seat table.")
      : game.bot?.enabled
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
          {trimmedRulesUrl ? (
            <a className="sound-toggle rules-link" href={trimmedRulesUrl}>
              {tx("game.rules", "Rules")}
            </a>
          ) : null}
          <SoundToggle state={soundState} onToggle={toggleSound} />
          <SoundPackSelect state={soundState} onChange={selectSoundPack} />
          <LanguageSelect language={language} onChange={selectLanguage} />
        </div>
      </section>

      <div className="game-layout">
        <aside className="action-rail">
          <StatusCard game={game} playerColor={playerColor} playerName={playerName} viewer={viewer} />
          <SeatReclaimCard payload={game.seat_reclaim} playerColor={viewerSeatColor || playerColor} onRemainSeated={onRemainSeated} />
          <DiceCard color={displayedDiceColor} dice={displayedDice} isCurrentRoll={displayedDiceIsCurrent} />
          {isOpeningRollPending ? <OpeningRollCard payload={openingRoll} playerColor={playerColor} /> : null}
          <ActionCard
            game={game}
            viewer={viewer}
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
          {isPouleTable ? (
            <PouleCard
              payload={game.poule}
              viewer={viewer}
              onClaimQueueSpot={() => pushWithError("claim_queue_spot")}
            />
          ) : null}
          {isMultiplayerTable ? (
            <MultiplayerCard
              payload={game.multiplayer}
              viewer={viewer}
              onClaimRosterSlot={() => pushWithError("claim_roster_slot")}
            />
          ) : null}
          {isConsensusChoice && canRespondToPendingMatchOptions ? (
            <PregameChoiceCard
              payload={pendingMatchOptions}
              viewer={viewer}
              playerColor={playerColor}
              onChoose={(decision) => {
                const optionKey =
                  pendingMatchOptions.kind === "trictrac_partie_length_consent" ||
                  pendingMatchOptions.kind === "multiplayer_partie_length_consent"
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
            className={`board-shell player-${playerColor} ${boardHasActions ? "board-interactive" : ""}`}
            style={{ backgroundImage: `url(${BoardWood})` }}
          >
            <div className="board-sheen" />
            <div className="board-grid">
              <BoardRow
                points={layout.top}
                pointsMap={boardPoints}
                isTop={true}
                playerColor={playerColor}
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
                playerColor={playerColor}
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

function StatusCard({ game, playerColor, playerName, viewer }) {
  const summaryItems = trictracStatusLineItems(game);
  const winnerLabel = colorVictoryLabel(game.match?.winner);
  const lastMove = lastMoveText(game, playerColor);
  const activeLegTitle = game?.variant?.id === "tavli" ? effectiveVariantTitle(game) : null;
  const pendingDecisionActorColor = game.pending_turn_decision?.actorColor || game.turn?.color;
  const pendingDecisionActorName = playerNameForColor(game, pendingDecisionActorColor);
  const aecrireResultText =
    ["trictrac_aecrire", "trictrac_combine"].includes(game.variant?.id) && game.match?.winner_kind === "jetons"
      ? aecrireMatchResultText(game)
      : null;
  const whoseTurn =
    game.poule?.phase === "waiting_for_competitors"
      ? tx("game.waitingCompetitors", "Waiting for enough competitors to fill the table.")
      : game.poule?.phase === "waiting_for_queue_refill"
        ? tx("game.waitingQueueRefill", "Waiting for a spectator to claim the open queue slot.")
        : game.poule?.phase === "finished"
          ? tx("game.pouleFinished", "The poule session is finished.")
      : game.multiplayer?.phase === "waiting_for_players"
        ? tx("game.waitingPlayers", "Waiting for enough players to fill the table.")
        : game.multiplayer?.phase === "awaiting_order_draw"
          ? tx("game.waitingOrderDraw", "Waiting for the opening draw.")
        : game.multiplayer?.phase === "awaiting_match_options"
          ? tx("game.waitingLengthAgreement", "Waiting for the competitors to agree on the coup length.")
        : game.multiplayer?.phase === "waiting_for_roster_refill"
          ? tx("game.waitingRosterRefill", "Waiting for a spectator to claim the open roster slot.")
          : game.multiplayer?.phase === "continuing_honneurs_after_coup"
            ? tx("game.continuingHonneurs", "The coup is settled and the honneurs side is still continuing.")
            : game.multiplayer?.phase === "finished"
              ? tx("game.multiplayerFinished", "The multiplayer session is finished.")
      : game.match?.is_over
      ? aecrireResultText || t("game.wonBy", { winner: winnerLabel, kind: winnerKindLabel(game.match?.winner_kind || "") })
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

  const seatTag = game.poule
    ? viewer?.role === "active"
      ? tx("game.viewerActive", `You are ${colorLabel(playerColor)} on the board.`)
      : viewer?.role === "queued"
        ? tx("game.viewerQueued", "You are currently in the queue.")
        : tx("game.viewerSpectator", "You are watching as a spectator.")
    : game.multiplayer
      ? viewer?.role === "active"
        ? tx("game.viewerActive", `You are ${colorLabel(playerColor)} on the board.`)
        : viewer?.role === "bench"
          ? tx("game.viewerBench", "You are currently waiting in the competitor rotation.")
          : tx("game.viewerSpectator", "You are watching as a spectator.")
    : t("game.youAre", { color: colorLabel(playerColor) });

  return (
    <section className="rail-card">
      <p className="rail-label">{t("game.seat")}</p>
      <h2>{playerName}</h2>
      <p className="seat-tag">{seatTag}</p>
      <p className="status-line">{whoseTurn}</p>
      {lastMove ? <p className="muted-copy">{lastMove}</p> : null}
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

function ActionCard({ game, viewer, isSeatedPlayer, isTurnPlayer, playerColor, openingRoll, pendingAction, onRoll, onUndo, onConfirm, onResign, onNewMatch }) {
  const actionPending = !!pendingAction;
  const openingRollPending = !!openingRoll?.pending;
  const isPouleFinished = game.poule?.phase === "finished";
  const isMultiplayerFinished = game.multiplayer?.phase === "finished";
  const isPluckedPoule = game.poule?.style === "plucked_pot";
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
  const canRollForOrder =
    !actionPending &&
    !!game.ui_actions?.can_roll_for_order &&
    game.multiplayer?.order_draw?.current_roller?.id === viewer?.id;
  const canRoll =
    canRollForOrder ||
    (!actionPending && (canOpeningRoll || (canPlay && !game.dice && !game.pending_match_options && !game.pending_turn_decision)));
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
    !hasLegalMoves &&
    !game.pending_turn_decision &&
    !canEndTurn;
  const showNewMatch = isPouleFinished || isMultiplayerFinished || (!game.poule && !game.multiplayer && !!game.match?.is_over);
  const showSecondaryAction = showNewMatch || canEndTurn || !isPluckedPoule;
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
        {showSecondaryAction ? (
          <button
            type="button"
            onClick={secondaryAction}
            disabled={secondaryDisabled}
          >
            {secondaryActionLabel}
          </button>
        ) : null}
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

function PouleCard({ payload, viewer, onClaimQueueSpot }) {
  if (!payload) {
    return null;
  }

  const isPluckedPoule = payload.style === "plucked_pot";
  const queueEntries = payload.queue || [];
  const spectators = payload.spectators || [];
  const ledger = payload.ledger || [];
  const drawOrder = payload.draw_order || [];
  const latestRound = payload.history?.[payload.history.length - 1] || null;
  const activeHost = payload.active?.host?.name || t("waiting");
  const activeGuest = payload.active?.guest?.name || t("waiting");
  const drawOrderText = drawOrder.length > 0
    ? drawOrder.map((entry) => entry.kind === "open_slot" ? tx("game.openQueueSlot", "Open queue slot") : entry.name).join(", ")
    : tx("game.noDrawOrderYet", "Draw order will appear when the table fills.");
  const queueText = queueEntries.length > 0
    ? queueEntries.map((entry) => entry.kind === "open_slot" ? tx("game.openQueueSlot", "Open queue slot") : entry.name).join(", ")
    : tx("game.emptyQueue", "No one is waiting in the queue.");
  const spectatorsText = spectators.length > 0
    ? spectators.map((spectator) => spectator.name).join(", ")
    : tx("game.noSpectators", "No spectators are watching right now.");
  const championText =
    payload.champion?.name && payload.streak > 0
      ? tx("game.currentStreak", "{name} is on a streak of {count}.", {
          name: payload.champion.name,
          count: payload.streak
        })
      : tx("game.noChampion", "No streak is running yet.");
  const latestSettlementText =
    latestRound?.winner?.name && Number.isFinite(latestRound?.settlement_trous)
      ? tx("game.latestSettlement", "{name} took {amount} on a {trous}-trou lead.", {
          name: latestRound.winner.name,
          amount: latestRound.payout_amount ?? 0,
          trous: latestRound.settlement_trous ?? 0
        })
      : tx("game.noSettlementYet", "No payout has been taken from the common fund yet.");

  return (
    <section className="rail-card">
      <p className="rail-label">{tx("game.poule", "Poule")}</p>
      <h2>{tx(`game.poulePhase.${payload.phase}`, capitalizeFirst(humanizeToken(payload.phase || "session")))}</h2>
      <p className="status-line">
        {isPluckedPoule ? latestSettlementText : championText}
      </p>
      <div className="score-row">
        <span>
          {tx(isPluckedPoule ? "game.remainingFund" : "game.pool", isPluckedPoule ? "Remaining fund" : "Pool")}: {payload.pool ?? 0}
        </span>
        {isPluckedPoule ? (
          <>
            <span>{tx("game.stake", "Stake")}: {payload.config?.stake ?? 0}</span>
            <span>{tx("game.holeValue", "Hole value")}: {payload.config?.hole_value ?? 0}</span>
          </>
        ) : (
          <>
            <span>{tx("game.ante", "Ante")}: {payload.config?.ante ?? 0}</span>
            <span>{tx("game.winTarget", "Target")}: {payload.config?.win_target ?? 0}</span>
          </>
        )}
      </div>
      {isPluckedPoule ? (
        <p className="muted-copy">
          {tx("game.fixedRing", "Fixed ring")}: {tx("game.fixedRingNote", "the second player stays on, and the first rotates to the tail.")}
        </p>
      ) : null}
      <p className="muted-copy">
        {tx("game.drawOrder", "Draw order")}: {drawOrderText}
      </p>
      <p className="muted-copy">
        {tx("game.activeSeats", "Active seats")}: {activeHost} / {activeGuest}
      </p>
      <p className="muted-copy">
        {tx("game.queueOrder", "Queue")}: {queueText}
      </p>
      <p className="muted-copy">
        {tx("game.spectators", "Spectators")}: {spectatorsText}
      </p>
      {ledger.length > 0 ? (
        <div className="poule-ledger">
          {ledger.map((entry) => (
            <div key={entry.id} className="poule-ledger-row">
              <strong>{entry.name}</strong>
              <span>{tx("game.paid", "paid")} {entry.contributed}</span>
              <span>{tx("game.won", "won")} {entry.payout}</span>
              <span>{tx("game.net", "net")} {entry.net}</span>
            </div>
          ))}
        </div>
      ) : null}
      {viewer?.can_claim_queue_spot ? (
        <div className="button-grid">
          <button type="button" onClick={onClaimQueueSpot}>
            {tx("game.claimQueueSpot", "Claim queue spot")}
          </button>
        </div>
      ) : null}
    </section>
  );
}

function MultiplayerCard({ payload, viewer, onClaimRosterSlot }) {
  if (!payload) {
    return null;
  }

  const participants = payload.participants || [];
  const activeHost = payload.active_pair?.host?.name || t("waiting");
  const activeGuest = payload.active_pair?.guest?.name || t("waiting");
  const waitingSlots = Number(payload.waiting_slots || 0);
  const phaseLabel = tx(`game.multiplayerPhase.${payload.phase}`, capitalizeFirst(humanizeToken(payload.phase || "session")));
  const modeLabel = tx(`game.multiplayerMode.${payload.mode}`, capitalizeFirst(humanizeToken(payload.mode || "multiplayer")));
  const accounting = payload.accounting || {};
  const cashMinorScale = Number(accounting.cash_minor_scale || 100);
  const cashPerJetonText = formatCashMinor(accounting.cash_per_jeton_minor, cashMinorScale);
  const cashPerFicheText = formatCashMinor(accounting.cash_per_fiche_minor, cashMinorScale);
  const participantText = participants.length > 0
    ? participants.map((entry) => entry.kind === "open_slot" ? tx("game.openRosterSlot", "Open roster slot") : entry.name).join(", ")
    : tx("game.noCompetitors", "No competitors have joined yet.");
  const orderDraw = payload.order_draw || null;
  const orderRolls = orderDraw?.rolls || [];
  const orderRollText = orderRolls.length > 0
    ? orderRolls.map((entry) => `${entry.member?.name || t("waiting")}: ${entry.value}`).join(", ")
    : tx("game.noOrderRollsYet", "No draw rolls have been recorded yet.");
  const rerollText = (orderDraw?.reroll_participants || []).map((entry) => entry?.name).filter(Boolean).join(", ");
  const resolvedOpening = orderDraw?.resolved_opening || null;
  const resolvedOpeningText = resolvedOpening?.host?.name && resolvedOpening?.guest?.name
    ? tx(
        "game.orderDrawResolved",
        "{host} opens against {guest}{resting}. {dieHolder} holds the die for {side}.",
        {
          host: resolvedOpening.host.name,
          guest: resolvedOpening.guest.name,
          resting: resolvedOpening.resting?.name ? `, ${tx("game.restingPlayer", "resting player")}: ${resolvedOpening.resting.name}` : "",
          dieHolder: resolvedOpening.die_holder?.name || t("waiting"),
          side: resolvedOpening.starting_side ? colorLabel(resolvedOpening.starting_side) : tx("game.none", "none")
        }
      )
    : null;
  const restingName = payload.rotation_state?.resting?.name;
  const associateOrder = payload.rotation_state?.associate_order || [];
  const ledgerPlayers = payload.ledger?.players || [];
  const ledgerSides = payload.ledger?.sides || [];
  const combinePoule = payload.ledger?.combine_poule || null;

  return (
    <section className="rail-card">
      <p className="rail-label">{tx("game.multiplayer", "Multiplayer")}</p>
      <h2>{modeLabel}</h2>
      <p className="status-line">{phaseLabel}</p>
      <div className="score-row">
        <span>{tx("game.competitors", "Competitors")}: {payload.competitor_target ?? 0}</span>
        <span>{tx("game.coups", "Coups")}: {payload.partie_length ?? 0}</span>
        <span>{tx("game.openSlots", "Open slots")}: {waitingSlots}</span>
      </div>
      {cashPerJetonText && cashPerFicheText ? (
        <p className="muted-copy">
          {tx("game.cashPerJeton", "Cash per jeton")}: {cashPerJetonText}
          {" · "}
          {tx("game.cashPerFiche", "Cash per fiche")}: {cashPerFicheText}
        </p>
      ) : null}
      <p className="muted-copy">
        {tx("game.activeSeats", "Active seats")}: {activeHost} / {activeGuest}
      </p>
      <p className="muted-copy">
        {tx("game.participants", "Participants")}: {participantText}
      </p>
      {orderDraw ? (
        <div className="poule-ledger">
          <div className="poule-ledger-row">
            <strong>{tx("game.orderDraw", "Opening draw")}</strong>
            <span>{tx("game.orderDrawStep", "step")} {capitalizeFirst(humanizeToken(orderDraw.step || "draw"))}</span>
            <span>{tx("game.currentRoller", "current roller")} {orderDraw.current_roller?.name || t("waiting")}</span>
            <span>{tx("game.orderRolls", "rolls")} {orderRollText}</span>
            {orderDraw.rerolling && rerollText ? (
              <span>{tx("game.orderDrawReroll", "rerolling")} {rerollText}</span>
            ) : null}
            {resolvedOpeningText ? <span>{resolvedOpeningText}</span> : null}
          </div>
        </div>
      ) : null}
      {restingName ? (
        <p className="muted-copy">
          {tx("game.restingPlayer", "Resting player")}: {restingName}
        </p>
      ) : null}
      {associateOrder.length > 0 ? (
        <p className="muted-copy">
          {tx("game.associateOrder", "Associate order")}: {associateOrder.map((entry) => entry?.name).filter(Boolean).join(", ")}
        </p>
      ) : null}
      {ledgerPlayers.length > 0 ? (
        <div className="poule-ledger">
          {ledgerPlayers.map((entry) => (
            <div key={entry.id} className="poule-ledger-row">
              <strong>{entry.name}</strong>
              <span>{tx("game.coupsLost", "coups lost")} {entry.coups_lost}</span>
              <span>{tx("game.jetons", "jetons")} {entry.jetons}</span>
              <span>{tx("game.cash", "cash")} {formatCashMinor(entry.final_total_cash_minor, cashMinorScale) ?? "0.00"}</span>
              <span>{tx("game.finalTotal", "final")} {entry.final_total}</span>
            </div>
          ))}
        </div>
      ) : null}
      {ledgerSides.length > 0 ? (
        <div className="poule-ledger">
          {ledgerSides.map((entry) => (
            <div key={entry.side} className="poule-ledger-row">
              <strong>{colorLabel(entry.side)}</strong>
              <span>{tx("game.marques", "marques")} {entry.marques}</span>
              <span>{tx("game.jetons", "jetons")} {entry.jetons}</span>
              <span>{tx("game.cash", "cash")} {formatCashMinor(entry.jetons_cash_minor, cashMinorScale) ?? "0.00"}</span>
              <span>{tx("game.honneurs", "honneurs")} {entry.honneurs}</span>
              {(entry.combine_paid || entry.combine_received || entry.basket_won) ? (
                <>
                  <span>{tx("game.combinePaid", "combine paid")} {entry.combine_paid}</span>
                  <span>{tx("game.combineReceived", "combine won")} {entry.combine_received}</span>
                  <span>{tx("game.basketWon", "basket won")} {entry.basket_won}</span>
                </>
              ) : null}
            </div>
          ))}
        </div>
      ) : null}
      {combinePoule ? (
        <p className="muted-copy">
          {tx("game.combineBasket", "Basket")}: {combinePoule.basket ?? 0}
          {" ("}{formatCashMinor(combinePoule.basket_cash_minor, cashMinorScale) ?? "0.00"}{")"}
          {" · "}
          {tx("game.contractSide", "Contract")}: {combinePoule.contract_side ? colorLabel(combinePoule.contract_side) : tx("game.none", "none")}
        </p>
      ) : null}
      {viewer?.can_claim_roster_slot ? (
        <div className="button-grid">
          <button type="button" onClick={onClaimRosterSlot}>
            {tx("game.claimRosterSlot", "Claim roster slot")}
          </button>
        </div>
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

function PregameChoiceCard({ payload, playerColor, viewer, onChoose }) {
  const responses = payload?.responses || {};
  const multiplayerConsent = payload?.kind === "multiplayer_partie_length_consent";
  const opponent = oppositeColor(playerColor);
  const responseKey = multiplayerConsent ? String(viewer?.id ?? "") : playerColor;
  const responseRows = multiplayerConsent
    ? (payload?.participants || []).map((participant) => ({
        label: participant?.name || t("waiting"),
        answer: responses[String(participant?.id)]
      }))
    : [
        { label: t("game.yourChoice"), answer: responses[playerColor] },
        {
          label: t("game.colorChoice", { color: colorLabel(opponent) }),
          answer: responses[opponent]
        }
      ];

  return (
    <section className="rail-card">
      <p className="rail-label">{t("game.pregame")}</p>
      <h2>{pendingPrompt(payload)}</h2>
      <div className={multiplayerConsent ? "poule-ledger" : "trictrac-grid"}>
        {responseRows.map((row) => (
          <div key={row.label} className={multiplayerConsent ? "poule-ledger-row" : undefined}>
            <strong>{row.label}</strong>
            <span>{pendingChoiceLabel(payload, row.answer)}</span>
          </div>
        ))}
      </div>
      {payload?.kind === "trictrac_partie_length_consent" ||
      payload?.kind === "multiplayer_partie_length_consent" ? (
        <PartieLengthConsentSlider payload={payload} responseKey={responseKey} onChoose={onChoose} />
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

function PartieLengthConsentSlider({ payload, responseKey, onChoose }) {
  const choices = payload?.choices || [];
  const responses = payload?.responses || {};
  const currentChoice = responses[responseKey];
  const defaultChoice = payload?.defaultChoice || choices[0] || "16";
  const fallbackChoice = currentChoice && choices.includes(currentChoice) ? currentChoice : defaultChoice;
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
  playerColor,
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
            playerColor={playerColor}
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
            playerColor={playerColor}
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

function boardActionProps(isInteractive, onActivate) {
  if (!isInteractive) {
    return {};
  }

  return {
    role: "button",
    tabIndex: 0,
    onClick: onActivate,
    onKeyDown: (event) => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        onActivate();
      }
    }
  };
}

function PointSlot({ point, isTop, playerColor, isSelected, isSource, isTarget, onSourceClick, onTargetClick }) {
  const pieces = point?.pieces || [];
  const pointNumber = pointDisplayNumber(point?.index, playerColor);
  const isInteractive = isSource || isTarget;
  const classes = [
    "point-slot",
    isTop ? "top" : "bottom",
    isSelected ? "selected" : "",
    isSource ? "source" : "",
    isTarget ? "target" : "",
    isInteractive ? "actionable" : ""
  ]
    .filter(Boolean)
    .join(" ");

  const clickHandler = isTarget ? onTargetClick : onSourceClick;
  const content = (
    <>
      <span className="point-triangle" />
      <span className={`point-number ${isTop ? "top" : "bottom"}`}>{pointNumber}</span>
      <StackedCheckers pieces={pieces} isTop={isTop} />
    </>
  );

  return (
    <div className={classes} {...boardActionProps(isInteractive, clickHandler)}>
      {content}
    </div>
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
  const classes = `bar-pocket ${isTop ? "top" : "bottom"} ${isSelected ? "selected" : ""} ${isSource ? "source" : ""} ${isSource ? "actionable" : ""}`;
  const content = (
    <>
      {showLabel ? <p>{isTop ? t("game.opponentBar") : t("game.yourBar")}</p> : null}
      <StackedCheckers pieces={Array.from({ length: count }, () => color)} isTop={isTop} />
      <strong>{count}</strong>
    </>
  );

  return (
    <div className={classes} {...boardActionProps(isSource, onSelect)}>
      {content}
    </div>
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
  const classes = `home-pocket ${isTop ? "top" : "bottom"} ${isTarget ? "target" : ""} ${isTarget ? "actionable" : ""}`;
  const content = (
    <>
      <p>{t("game.bearOff")}</p>
      <StackedCheckers pieces={Array.from({ length: count }, () => color)} isTop={isTop} />
      <strong>{count}</strong>
    </>
  );

  return (
    <div
      className={classes}
      {...boardActionProps(isTarget, () => {
        onMoveTo("home");
      })}
    >
      {content}
    </div>
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
