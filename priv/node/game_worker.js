"use strict";

const readline = require("readline");
const model = require("../../backgammonjs/lib/model.js");

const RULES = {
  RuleBgCasual: require("../../backgammonjs/lib/rules/RuleBgCasual.js"),
  RuleBgTapa: require("../../backgammonjs/lib/rules/RuleBgTapa.js"),
  RuleFrTrictrac: require("../../backgammonjs/lib/rules/RuleFrTrictrac.js"),
  RuleFrTrictracAEcrire: require("../../backgammonjs/lib/rules/RuleFrTrictracAEcrire.js"),
  RuleFrTrictracCombine: require("../../backgammonjs/lib/rules/RuleFrTrictracCombine.js")
};

const VARIANTS = {
  backgammon: {
    id: "backgammon",
    title: "Backgammon",
    ruleName: "RuleBgCasual"
  },
  tapa: {
    id: "tapa",
    title: "Tapa / Plakoto",
    ruleName: "RuleBgTapa"
  },
  trictrac_classique: {
    id: "trictrac_classique",
    title: "Trictrac Classique",
    ruleName: "RuleFrTrictrac"
  },
  trictrac_aecrire: {
    id: "trictrac_aecrire",
    title: "Trictrac A Ecrire",
    ruleName: "RuleFrTrictracAEcrire"
  },
  trictrac_combine: {
    id: "trictrac_combine",
    title: "Trictrac Combine",
    ruleName: "RuleFrTrictracCombine"
  }
};

const DEFAULT_VARIANT_ID = "backgammon";
const lobbies = Object.create(null);

// Keep stdout clean for the port protocol.
console.log = function () {};

function writeResponse(id, ok, result, error) {
  process.stdout.write(
    JSON.stringify({
      id: id,
      ok: ok,
      result: result || null,
      error: error || null
    }) + "\n"
  );
}

function variantFor(id) {
  return VARIANTS[id] || VARIANTS[DEFAULT_VARIANT_ID];
}

function colorName(pieceType) {
  return pieceType === model.PieceType.WHITE ? "white" : "black";
}

function pieceTypeForColor(color) {
  return color === "black" ? model.PieceType.BLACK : model.PieceType.WHITE;
}

function applyTrictracMatchDefaults(match, rule) {
  if (
    rule.name === "RuleFrTrictrac" ||
    rule.name === "RuleFrTrictracAEcrire" ||
    rule.name === "RuleFrTrictracCombine"
  ) {
    match.length = 1;

    if (rule.name === "RuleFrTrictracAEcrire") {
      match.trictracVariant = "a_ecrire";
    }
    else if (rule.name === "RuleFrTrictracCombine") {
      match.trictracVariant = "combine";
    }
    else {
      match.trictracVariant = "classique";
    }

    match.options.trictrac = match.options.trictrac || {
      margotEnabled: false,
      aEcrireStyle: "avec_releve"
    };

    match.currentGame.trictrac.matchOptions = {
      margotEnabled: false,
      aEcrireStyle: "avec_releve",
      tableMode: match.tableMode
    };
  }
}

function createContext(lobby, requestedVariantId) {
  const variant = variantFor(requestedVariantId);
  const rule = RULES[variant.ruleName];
  const match = model.Match.createNew(rule);

  match.length = 1;
  model.Match.createNewGame(match, rule);
  applyTrictracMatchDefaults(match, rule);

  const ctx = {
    lobby: lobby,
    variantId: variant.id,
    match: match,
    rule: rule
  };

  lobbies[lobby] = ctx;
  return ctx;
}

function ensureContext(lobby, requestedVariantId) {
  return lobbies[lobby] || createContext(lobby, requestedVariantId);
}

function findPlayerByName(ctx, userName) {
  if (ctx.match.host && ctx.match.host.name === userName) {
    return ctx.match.host;
  }
  if (ctx.match.guest && ctx.match.guest.name === userName) {
    return ctx.match.guest;
  }
  return null;
}

function findPlayerByClientId(ctx, clientId) {
  if (!clientId) {
    return null;
  }

  if (ctx.match.host && ctx.match.host.clientId === clientId) {
    return ctx.match.host;
  }

  if (ctx.match.guest && ctx.match.guest.clientId === clientId) {
    return ctx.match.guest;
  }

  return null;
}

function findPlayerById(ctx, playerId) {
  if (ctx.match.host && ctx.match.host.id === playerId) {
    return ctx.match.host;
  }
  if (ctx.match.guest && ctx.match.guest.id === playerId) {
    return ctx.match.guest;
  }
  return null;
}

function createPlayer(name, pieceType, clientId) {
  const player = model.Player.createNew();
  player.name = name;
  player.currentPieceType = pieceType;
  player.clientId = clientId || null;
  return player;
}

function startMatchNow(ctx) {
  const match = ctx.match;
  const game = match.currentGame;

  game.hasStarted = true;
  game.isOver = false;
  game.turnPlayer = match.host;
  game.turnNumber = 1;
  match.pendingOptions = null;
  ctx.rule.onMatchOptionsResolved(match);
}

function beginPendingMatchOptions(ctx) {
  const payload = ctx.rule.getPendingMatchOptions(ctx.match);
  if (!payload) {
    return false;
  }

  ctx.match.pendingOptions = {
    optionsPayload: payload,
    responses: {}
  };

  return true;
}

function maybeStartMatch(ctx) {
  if (!ctx.match.guest) {
    return;
  }

  if (ctx.match.currentGame.hasStarted) {
    return;
  }

  if (beginPendingMatchOptions(ctx)) {
    return;
  }

  startMatchNow(ctx);
}

function getActorContext(payload) {
  const ctx = lobbies[payload.lobby];
  if (!ctx) {
    throw new Error("Lobby not found.");
  }

  const player = findPlayerByClientId(ctx, payload.client_id) || findPlayerByName(ctx, payload.user);
  if (!player) {
    throw new Error("Player not found in lobby.");
  }

  return {
    ctx: ctx,
    player: player
  };
}

function findPieceById(state, pieceType, pieceId) {
  const pieces = state.pieces[pieceType];

  for (let index = 0; index < pieces.length; index += 1) {
    if (pieces[index].id === pieceId) {
      return pieces[index];
    }
  }

  return null;
}

function getPendingTurnDecision(ctx) {
  const game = ctx.match.currentGame;
  if (!game || !game.hasStarted || !game.turnPlayer) {
    return null;
  }

  return ctx.rule.getPendingTurnDecision(game, game.turnPlayer);
}

function candidatePiecesForTurn(ctx) {
  const game = ctx.match.currentGame;
  if (!game || !game.turnPlayer) {
    return [];
  }

  const pieceType = game.turnPlayer.currentPieceType;
  const state = game.state;

  if (model.State.havePiecesOnBar(state, pieceType)) {
    const piece = model.State.getBarTopPiece(state, pieceType);
    return piece ? [piece] : [];
  }

  const pieces = [];

  for (let point = 0; point < state.points.length; point += 1) {
    const topPiece = model.State.getTopPiece(state, point);
    if (topPiece && topPiece.type === pieceType) {
      pieces.push(topPiece);
    }
  }

  return pieces;
}

function deriveDestination(actionList) {
  const lastAction = actionList[actionList.length - 1];

  if (!lastAction) {
    return null;
  }

  if (lastAction.type === model.MoveActionType.BEAR) {
    return "home";
  }

  if (typeof lastAction.to !== "undefined") {
    return lastAction.to;
  }

  return lastAction.position;
}

function buildLegalMoves(ctx) {
  const match = ctx.match;
  const game = match.currentGame;
  const rule = ctx.rule;

  if (!game || !game.hasStarted || !game.turnPlayer || !game.turnDice || match.pendingOptions) {
    return [];
  }

  if (getPendingTurnDecision(ctx)) {
    return [];
  }

  const originalForceUndoPending = game.trictrac ? game.trictrac.forceUndoPending : null;
  const originalForceUndoError = game.trictrac ? game.trictrac.forceUndoError : null;
  const moves = [];
  const seen = new Set();
  const stepsList = Array.from(new Set(game.turnDice.movesLeft || []));

  candidatePiecesForTurn(ctx).forEach(function (piece) {
    stepsList.forEach(function (steps) {
      if (game.trictrac) {
        game.trictrac.forceUndoPending = false;
        game.trictrac.forceUndoError = null;
      }

      if (!rule.validateMove(game, game.turnPlayer, piece, steps)) {
        return;
      }

      const actions = rule.getMoveActions(game.state, piece, steps);
      if (!actions || actions.length <= 0) {
        return;
      }

      const from = model.State.isPieceOnBar(game.state, piece) ? "bar" : model.State.getPiecePos(game.state, piece);
      const to = deriveDestination(actions);
      const key = [piece.id, from, to, steps].join(":");

      if (seen.has(key)) {
        return;
      }

      seen.add(key);
      moves.push({
        piece_id: piece.id,
        from: from,
        to: to,
        steps: steps
      });
    });
  });

  if (game.trictrac) {
    game.trictrac.forceUndoPending = originalForceUndoPending;
    game.trictrac.forceUndoError = originalForceUndoError;
  }

  return moves.sort(function (left, right) {
    if (String(left.from) === String(right.from)) {
      if (String(left.to) === String(right.to)) {
        return left.steps - right.steps;
      }
      return String(left.to).localeCompare(String(right.to));
    }
    return String(left.from).localeCompare(String(right.from));
  });
}

function serializePlayer(player) {
  if (!player) {
    return null;
  }

  return {
    id: player.id,
    name: player.name,
    color: colorName(player.currentPieceType)
  };
}

function serializePoints(state) {
  return state.points.map(function (pieces, index) {
    return {
      index: index,
      pieces: pieces.map(function (piece) {
        return colorName(piece.type);
      })
    };
  });
}

function serializeTrictrac(match) {
  if (!match.currentGame || !match.currentGame.state || !match.currentGame.state.trictrac) {
    return null;
  }

  return match.currentGame.state.trictrac;
}

function buildSnapshot(ctx) {
  const match = ctx.match;
  const game = match.currentGame;
  const variant = variantFor(ctx.variantId);
  const pendingTurnDecision = getPendingTurnDecision(ctx);
  const legalMoves = buildLegalMoves(ctx);
  const turnPlayer = game && game.turnPlayer ? findPlayerById(ctx, game.turnPlayer.id) : null;

  return {
    lobby: ctx.lobby,
    variant: {
      id: variant.id,
      title: variant.title,
      rule_name: variant.ruleName
    },
    status: !match.guest
      ? "waiting_for_opponent"
      : match.pendingOptions
        ? "awaiting_match_options"
        : match.isOver
          ? "match_over"
          : game && game.hasStarted
            ? "playing"
            : "ready",
    players: {
      host: serializePlayer(match.host),
      guest: serializePlayer(match.guest)
    },
    board: game ? {
      points: serializePoints(game.state),
      bar: {
        white: game.state.bar[model.PieceType.WHITE].length,
        black: game.state.bar[model.PieceType.BLACK].length
      },
      outside: {
        white: game.state.outside[model.PieceType.WHITE].length,
        black: game.state.outside[model.PieceType.BLACK].length
      }
    } : null,
    turn: game ? {
      number: game.turnNumber,
      color: turnPlayer ? turnPlayer.color : null,
      player_name: turnPlayer ? turnPlayer.name : null
    } : null,
    dice: game && game.turnDice ? {
      values: game.turnDice.values,
      moves: game.turnDice.moves,
      moves_left: game.turnDice.movesLeft,
      moves_played: game.turnDice.movesPlayed
    } : null,
    legal_moves: legalMoves,
    pending_match_options: match.pendingOptions ? match.pendingOptions.optionsPayload : null,
    pending_turn_decision: pendingTurnDecision,
    match: {
      is_over: match.isOver,
      score: {
        white: match.score[model.PieceType.WHITE],
        black: match.score[model.PieceType.BLACK]
      },
      length: match.length,
      trictrac_variant: match.trictracVariant
    },
    trictrac: serializeTrictrac(match),
    ui_actions: {
      can_roll: !!(game && game.hasStarted && game.turnPlayer && !game.turnDice && !match.pendingOptions && !pendingTurnDecision),
      can_undo: !!(game && game.turnDice && !game.turnConfirmed && !pendingTurnDecision),
      can_confirm: !!(game && game.turnDice && !game.turnConfirmed && (!game.turnDice.movesLeft || game.turnDice.movesLeft.length === 0) && !pendingTurnDecision),
      can_submit_match_options: !!match.pendingOptions,
      can_submit_turn_decision: !!pendingTurnDecision,
      can_reset: true
    }
  };
}

function joinGame(payload) {
  const ctx = ensureContext(payload.lobby, payload.variant);
  let player = findPlayerByClientId(ctx, payload.client_id);

  if (!player) {
    if (!ctx.match.host) {
      player = createPlayer(payload.user, model.PieceType.WHITE, payload.client_id);
      model.Match.addHostPlayer(ctx.match, player);
    }
    else if (!ctx.match.guest) {
      player = createPlayer(payload.user, model.PieceType.BLACK, payload.client_id);
      model.Match.addGuestPlayer(ctx.match, player);
    }
    else {
      throw new Error("Game is full.");
    }

    player.currentMatch = ctx.match.id;
  }

  maybeStartMatch(ctx);

  return {
    snapshot: buildSnapshot(ctx),
    player: serializePlayer(player)
  };
}

function resolveMoveIntent(ctx, payload) {
  const normalizedFrom = payload.from === "bar" ? "bar" : Number(payload.from);
  const normalizedTo = payload.to === "home" ? "home" : Number(payload.to);

  const move = buildLegalMoves(ctx).find(function (candidate) {
    return String(candidate.from) === String(normalizedFrom) &&
      String(candidate.to) === String(normalizedTo);
  });

  if (!move) {
    throw new Error("Requested move is not legal.");
  }

  return move;
}

function handleRoll(payload) {
  const actor = getActorContext(payload);
  const ctx = actor.ctx;
  const player = actor.player;
  const game = ctx.match.currentGame;

  if (!game || !game.hasStarted) {
    throw new Error("Game has not started.");
  }

  if (!game.turnPlayer || game.turnPlayer.id !== player.id) {
    throw new Error("It is not your turn.");
  }

  if (model.Game.diceWasRolled(game)) {
    throw new Error("Dice has already been rolled.");
  }

  game.turnDice = ctx.rule.rollDice(game);
  ctx.rule.afterRoll(game);
  model.Game.snapshotState(game);

  return buildSnapshot(ctx);
}

function handleMove(payload) {
  const actor = getActorContext(payload);
  const ctx = actor.ctx;
  const player = actor.player;
  const game = ctx.match.currentGame;
  const move = resolveMoveIntent(ctx, payload.move || {});
  const piece = findPieceById(game.state, player.currentPieceType, move.piece_id);

  if (!piece) {
    throw new Error("Could not find the selected piece.");
  }

  if (!ctx.rule.validateMove(game, player, piece, move.steps)) {
    if (game.trictrac && game.trictrac.forceUndoPending) {
      const undoError = game.trictrac.forceUndoError || "Move undone.";
      game.trictrac.forceUndoPending = false;
      game.trictrac.forceUndoError = null;
      model.Game.restoreState(game);
      throw new Error(undoError);
    }

    throw new Error("Requested move is not valid.");
  }

  const actions = ctx.rule.getMoveActions(game.state, piece, move.steps);
  if (!actions || actions.length <= 0) {
    throw new Error("Requested move is not allowed.");
  }

  ctx.rule.applyMoveActions(game.state, actions);
  ctx.rule.markAsPlayed(game, move.steps);
  game.moveSequence += 1;

  return buildSnapshot(ctx);
}

function endGame(ctx, winner) {
  const match = ctx.match;
  const score = ctx.rule.getGameScore(match.currentGame.state, winner);
  match.score[winner.currentPieceType] += score;

  if (ctx.rule.isSingleGameMatch(match) || match.score[winner.currentPieceType] >= match.length) {
    match.isOver = true;
    match.currentGame.isOver = true;
    return;
  }

  const nextGame = model.Match.createNewGame(match, ctx.rule);
  applyTrictracMatchDefaults(match, ctx.rule);
  nextGame.hasStarted = true;
  nextGame.turnPlayer = winner;
  nextGame.turnNumber = 1;
}

function handleConfirm(payload) {
  const actor = getActorContext(payload);
  const ctx = actor.ctx;
  const player = actor.player;
  const game = ctx.match.currentGame;

  if (!ctx.rule.validateConfirm(game, player)) {
    throw new Error("Confirming moves is not allowed.");
  }

  const hookResult = ctx.rule.afterConfirm(ctx.match, player) || {};
  let winner = null;

  if (hookResult.winnerType === model.PieceType.WHITE || hookResult.winnerType === model.PieceType.BLACK) {
    winner = hookResult.winnerType === model.PieceType.WHITE ? ctx.match.host : ctx.match.guest;
  }
  else if (ctx.rule.hasWon(game.state, player)) {
    winner = player;
  }

  if (winner) {
    endGame(ctx, winner);
    return buildSnapshot(ctx);
  }

  if (!ctx.rule.getPendingTurnDecision(game, player)) {
    ctx.rule.nextTurn(ctx.match);
  }

  return buildSnapshot(ctx);
}

function handleUndo(payload) {
  const actor = getActorContext(payload);
  const ctx = actor.ctx;
  const player = actor.player;

  if (!ctx.rule.validateUndo(ctx.match.currentGame, player)) {
    throw new Error("Undo is not allowed.");
  }

  model.Game.restoreState(ctx.match.currentGame);
  return buildSnapshot(ctx);
}

function handleSubmitMatchOptions(payload) {
  const actor = getActorContext(payload);
  const ctx = actor.ctx;
  const player = actor.player;
  const pending = ctx.match.pendingOptions;

  if (!pending) {
    throw new Error("No match options are pending.");
  }

  if (!ctx.match.host || ctx.match.host.id !== player.id) {
    throw new Error("Only the host can submit match options.");
  }

  const submitted = payload.options || {};
  const options = {};

  pending.optionsPayload.options.forEach(function (option) {
    const value = Object.prototype.hasOwnProperty.call(submitted, option.key)
      ? submitted[option.key]
      : option.defaultValue;
    options[option.key] = value;
  });

  ctx.match.options.trictrac = ctx.match.options.trictrac || {};
  Object.keys(options).forEach(function (key) {
    ctx.match.options.trictrac[key] = options[key];
  });

  ctx.match.pendingOptions = null;
  startMatchNow(ctx);

  return buildSnapshot(ctx);
}

function handleSubmitTurnDecision(payload) {
  const actor = getActorContext(payload);
  const ctx = actor.ctx;
  const player = actor.player;
  const decisionRequest = ctx.rule.getPendingTurnDecision(ctx.match.currentGame, player);

  if (!decisionRequest) {
    throw new Error("No turn decision is pending.");
  }

  const result = ctx.rule.applyTurnDecision(ctx.match, player, payload.decision);
  if (!result || !result.result) {
    throw new Error(result && result.errorMessage ? result.errorMessage : "Could not apply turn decision.");
  }

  return buildSnapshot(ctx);
}

function handleReset(payload) {
  const ctx = ensureContext(payload.lobby, payload.variant);
  const host = ctx.match.host;
  const guest = ctx.match.guest;
  const match = model.Match.createNew(ctx.rule);

  match.length = 1;
  model.Match.createNewGame(match, ctx.rule);
  applyTrictracMatchDefaults(match, ctx.rule);

  if (host) {
    host.currentPieceType = model.PieceType.WHITE;
    host.currentMatch = match.id;
    model.Match.addHostPlayer(match, host);
  }

  if (guest) {
    guest.currentPieceType = model.PieceType.BLACK;
    guest.currentMatch = match.id;
    model.Match.addGuestPlayer(match, guest);
  }

  ctx.match = match;
  maybeStartMatch(ctx);

  return buildSnapshot(ctx);
}

function dispatch(command, payload) {
  switch (command) {
    case "create_game":
      return buildSnapshot(ensureContext(payload.lobby, payload.variant));
    case "join_game":
      return joinGame(payload);
    case "get_state":
      return buildSnapshot(ensureContext(payload.lobby, payload.variant));
    case "roll":
      return handleRoll(payload);
    case "move":
      return handleMove(payload);
    case "undo":
      return handleUndo(payload);
    case "confirm":
      return handleConfirm(payload);
    case "submit_match_options":
      return handleSubmitMatchOptions(payload);
    case "submit_turn_decision":
      return handleSubmitTurnDecision(payload);
    case "reset":
      return handleReset(payload);
    default:
      throw new Error("Unsupported command: " + command);
  }
}

const lineReader = readline.createInterface({
  input: process.stdin,
  crlfDelay: Infinity
});

lineReader.on("line", function (line) {
  if (!line) {
    return;
  }

  let message;
  try {
    message = JSON.parse(line);
  }
  catch (_error) {
    writeResponse(null, false, null, "Invalid JSON request.");
    return;
  }

  try {
    const result = dispatch(message.command, message.payload || {});
    writeResponse(message.id, true, result, null);
  }
  catch (error) {
    writeResponse(message.id, false, null, error && error.message ? error.message : "Unknown worker error.");
  }
});
