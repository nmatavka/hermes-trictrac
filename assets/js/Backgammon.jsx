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
  "toc",
  "plein"
]);

const TOAST_LIFETIME_MS = 4200;

const BOARD_LAYOUTS = {
  white: {
    top: [12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23],
    bottom: [11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0]
  },
  black: {
    top: [11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
    bottom: [12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23]
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
    case "continuation":
      return "Choose how to continue.";
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

function oppositeColor(color) {
  return color === "black" ? "white" : "black";
}

function trictracVariantId(game) {
  return game?.variant?.id || "";
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

function trictracStatusLineItems(game) {
  const variantId = trictracVariantId(game);
  const trictrac = game?.trictrac || {};
  const whiteScore = trictracScoreEntry(trictrac, "white");
  const blackScore = trictracScoreEntry(trictrac, "black");
  const aecrire = trictrac?.track_aecrire || {};
  const combine = trictrac?.track_classique_honneurs || {};

  switch (variantId) {
    case "trictrac_classique":
    case "plein":
      return [
        { label: "White", value: `${whiteScore.points || 0}/${whiteScore.trous || 0}` },
        { label: "Black", value: `${blackScore.points || 0}/${blackScore.trous || 0}` }
      ];

    case "toc":
      return [
        { label: "White", value: `${game?.match?.score?.white ?? 0} hole${(game?.match?.score?.white ?? 0) === 1 ? "" : "s"}` },
        { label: "Black", value: `${game?.match?.score?.black ?? 0} hole${(game?.match?.score?.black ?? 0) === 1 ? "" : "s"}` }
      ];

    case "trictrac_aecrire": {
      const coupTrous = aecrire.current_coup?.trous || {};
      const marques = aecrire.marques || {};

      return [
        { label: "White", value: `${marques.white || 0} marque${(marques.white || 0) === 1 ? "" : "s"} / ${coupTrous.white || 0} trous` },
        { label: "Black", value: `${marques.black || 0} marque${(marques.black || 0) === 1 ? "" : "s"} / ${coupTrous.black || 0} trous` }
      ];
    }

    case "trictrac_combine": {
      const marques = aecrire.marques || {};
      const honneurs = combine.honneurs || {};

      return [
        { label: "White", value: `${marques.white || 0} marque${(marques.white || 0) === 1 ? "" : "s"} / ${honneurs.white || 0} honneur${(honneurs.white || 0) === 1 ? "" : "s"}` },
        { label: "Black", value: `${marques.black || 0} marque${(marques.black || 0) === 1 ? "" : "s"} / ${honneurs.black || 0} honneur${(honneurs.black || 0) === 1 ? "" : "s"}` }
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

  switch (variantId) {
    case "trictrac_classique":
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

      return [
        { title: "White", lines: [`${marques.white || 0} marques`, `${coupTrous.white || 0} coup trous`] },
        { title: "Black", lines: [`${marques.black || 0} marques`, `${coupTrous.black || 0} coup trous`] },
        { title: "Petite bredouille", lines: [holderFromFlags(aecrire.petite_bredouille)] },
        { title: "Grande bredouille", lines: [holderFromFlags(aecrire.grande_bredouille)] }
      ];
    }

    case "trictrac_combine": {
      const coupTrous = aecrire.current_coup?.trous || {};
      const marques = aecrire.marques || {};
      const partieTrous = combine.current_partie?.trous || {};
      const honneurs = combine.honneurs || {};
      const classes = combine.classes || {};

      return [
        { title: "White a ecrire", lines: [`${marques.white || 0} marques`, `${coupTrous.white || 0} coup trous`] },
        { title: "Black a ecrire", lines: [`${marques.black || 0} marques`, `${coupTrous.black || 0} coup trous`] },
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
        { title: "Petite bredouille", lines: [holderFromFlags(aecrire.petite_bredouille)] },
        { title: "Grande bredouille", lines: [holderFromFlags(aecrire.grande_bredouille)] }
      ];
    }

    default:
      return [];
  }
}

function consentAnswerLabel(answer) {
  switch (answer) {
    case "yes":
      return "Yes";
    case "no":
      return "No";
    default:
      return "Waiting";
  }
}

function openingRollValueLabel(value) {
  return value == null ? "Waiting" : String(value);
}

export default function gameInit(root, channel) {
  const reactRoot = createRoot(root);

  channel
    .join()
    .receive("ok", (resp) => {
      reactRoot.render(
        <Backgammon
          lobbyName={root.dataset.game}
          player={resp.player}
          playerName={root.dataset.user}
          channel={channel}
          initialGame={resp.game}
        />
      );
    })
    .receive("error", (resp) => {
      root.innerHTML = `<p>Unable to join game: ${resp?.msg || "unknown error"}</p>`;
    });
}

function Backgammon({ channel, initialGame, player, playerName, lobbyName }) {
  const playerColor = player?.color ?? "white";
  const [game, setGame] = useState(initialGame);
  const [selectedFrom, setSelectedFrom] = useState(null);
  const [errorMessage, setErrorMessage] = useState("");
  const [optionsDraft, setOptionsDraft] = useState({});
  const [toasts, setToasts] = useState([]);
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

    setOptionsDraft(
      pendingOptions.reduce((acc, option) => {
        acc[option.key] = option.defaultValue;
        return acc;
      }, {})
    );
  }, [game.pending_match_options]);

  const isHost = game.players?.host?.name === playerName;
  const isYourTurn = game.turn?.player_name === playerName || game.turn?.color === playerColor;
  const isSeatedPlayer =
    game.players?.host?.name === playerName || game.players?.guest?.name === playerName;
  const pendingMatchOptions = game.pending_match_options;
  const isMargotConsent = pendingMatchOptions?.kind === "trictrac_margot_consent";
  const openingRoll = game.opening_roll;
  const isOpeningRollPending = !!openingRoll?.pending;
  const legalMoves = game.legal_moves || [];
  const activeLegalMoves = isYourTurn && !isOpeningRollPending ? legalMoves : [];

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
    if (!isYourTurn || isOpeningRollPending) {
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
    if (!isYourTurn || isOpeningRollPending || selectedFrom == null || !highlightedTargets.has(String(to))) {
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

  return (
    <div className="app-shell">
      {toasts.length > 0 ? <ToastStack toasts={toasts} /> : null}
      <section className="hero-panel">
        <div>
          <p className="eyebrow">{game.variant?.title || "Table Game"}</p>
          <h1>{lobbyName}</h1>
          <p className="hero-copy">
            You are playing as {COLOR_LABELS[playerColor]}. Share this lobby name with your opponent to join
            the same table.
          </p>
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
          <DiceCard color={diceTheme} dice={game.dice} />
          {isOpeningRollPending ? <OpeningRollCard payload={openingRoll} playerColor={playerColor} /> : null}
          <ActionCard
            game={game}
            isSeatedPlayer={isSeatedPlayer}
            isYourTurn={isYourTurn}
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
          {isMargotConsent && isSeatedPlayer ? (
            <MargotConsentCard
              payload={pendingMatchOptions}
              playerColor={playerColor}
              onChoose={(decision) =>
                pushWithError("submit_match_options", { options: { margotConsent: decision } })
              }
            />
          ) : null}
          {pendingMatchOptions && !isMargotConsent && isHost ? (
            <OptionsCard
              payload={pendingMatchOptions}
              values={optionsDraft}
              onChange={(key, value) => setOptionsDraft((current) => ({ ...current, [key]: value }))}
              onSubmit={submitOptions}
            />
          ) : null}
          {game.pending_turn_decision && isYourTurn ? (
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
              <BarColumn
                variantId={game.variant?.id}
                topColor={topColor}
                bottomColor={playerColor}
                board={game.board}
                selectedFrom={selectedFrom}
                sourceMoves={fromTargets}
                highlightedTargets={highlightedTargets}
                onSelectSource={selectSource}
              />
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
  const whoseTurn =
    game.match?.is_over
      ? `${winnerLabel} won${game.match?.winner_kind ? ` by ${humanizeToken(game.match.winner_kind)}` : ""}.`
      : game.status === "waiting_for_opponent"
      ? "Waiting for an opponent to join."
      : game.opening_roll?.pending
        ? game.opening_roll.prompt || "Roll to decide who starts."
      : game.pending_match_options?.kind === "trictrac_margot_consent"
        ? "Margot la fendue must be agreed before play starts."
        : game.pending_match_options
          ? "Match options need to be confirmed before play starts."
        : game.pending_turn_decision
          ? `${game.turn?.player_name || "Current player"} must resolve a turn decision.`
          : game.turn?.player_name
            ? `${game.turn.player_name} to move`
            : "Table is setting up.";

  return (
    <section className="rail-card">
      <p className="rail-label">Seat</p>
      <h2>{playerName}</h2>
      <p className="seat-tag">You are {COLOR_LABELS[playerColor]}</p>
      <p className="status-line">{whoseTurn}</p>
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

function DiceCard({ color, dice }) {
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
      <p className="muted-copy">Moves left: {(dice.moves_left || []).join(", ") || "none"}</p>
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
        <div>
          <strong>{colorLabel(playerColor)}</strong>
          <span>{openingRollValueLabel(rolls[playerColor])}</span>
        </div>
        <div>
          <strong>{colorLabel(opponent)}</strong>
          <span>{openingRollValueLabel(rolls[opponent])}</span>
        </div>
      </div>
    </section>
  );
}

function ActionCard({ game, isSeatedPlayer, isYourTurn, playerColor, openingRoll, onRoll, onUndo, onConfirm, onResign, onNewMatch }) {
  const openingRollPending = !!openingRoll?.pending;
  const canOpeningRoll =
    openingRollPending &&
    isSeatedPlayer &&
    !game.match?.is_over &&
    !game.pending_match_options &&
    !game.pending_turn_decision &&
    !game.dice &&
    openingRoll?.rolls?.[playerColor] == null;
  const canPlay =
    isYourTurn &&
    !openingRollPending &&
    !game.match?.is_over &&
    !game.pending_match_options &&
    !game.pending_turn_decision;
  const canRoll = canOpeningRoll || (canPlay && !game.dice && !game.pending_match_options && !game.pending_turn_decision);
  const canUndo = canPlay && !!game.dice && (game.dice.moves_played || []).length > 0 && !game.pending_turn_decision;
  const canConfirm =
    canPlay &&
    !!game.dice &&
    (game.dice.moves_left || []).length === 0 &&
    !game.pending_turn_decision;
  const showNewMatch = !!game.match?.is_over;

  return (
    <section className="rail-card">
      <p className="rail-label">Actions</p>
      <div className="button-grid">
        <button type="button" onClick={onRoll} disabled={!canRoll}>
          Roll
        </button>
        <button type="button" onClick={onUndo} disabled={!canUndo}>
          Undo
        </button>
        <button type="button" onClick={onConfirm} disabled={!canConfirm}>
          Confirm
        </button>
        <button
          type="button"
          onClick={showNewMatch ? onNewMatch : onResign}
          disabled={!showNewMatch && !isSeatedPlayer}
        >
          {showNewMatch ? "New Match" : "Resign"}
        </button>
      </div>
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

function MargotConsentCard({ payload, playerColor, onChoose }) {
  const responses = payload?.responses || {};
  const opponent = oppositeColor(playerColor);

  return (
    <section className="rail-card">
      <p className="rail-label">Pregame</p>
      <h2>{payload?.prompt || "Play with Margot la fendue?"}</h2>
      <div className="trictrac-grid">
        <div>
          <strong>Your answer</strong>
          <span>{consentAnswerLabel(responses[playerColor])}</span>
        </div>
        <div>
          <strong>{colorLabel(opponent)} answer</strong>
          <span>{consentAnswerLabel(responses[opponent])}</span>
        </div>
      </div>
      <div className="button-grid">
        {(payload?.choices || []).map((choice) => (
          <button key={choice} type="button" onClick={() => onChoose(choice)}>
            {decisionChoiceLabel(choice)}
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
  const optionEntries = Object.entries(options);
  const showTocScore = game.variant?.id === "toc";

  if (results.length === 0 && optionEntries.length === 0 && !game.match?.winner_kind && !showTocScore) {
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
      {optionEntries.length > 0 ? (
        <div className="trictrac-grid">
          {optionEntries.map(([key, value]) => (
            <div key={key}>
              <strong>{capitalizeFirst(humanizeToken(key))}</strong>
              <span>{typeof value === "boolean" ? (value ? "Yes" : "No") : String(value)}</span>
            </div>
          ))}
        </div>
      ) : null}
      {results.length > 0 ? (
        <div className="result-list">
          {results.map((result, index) => (
            <p key={`${result.winner}-${index}`} className="muted-copy">
              Game {index + 1}: {colorLabel(result.winner)} won {result.points} by {humanizeToken(result.kind)}
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
      <p>{isTop ? "Off" : "Bear Off"}</p>
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
