import "../css/app.css";
import "phoenix_html"
import socket from "./socket";
import gameInit from "./HermesTrictracApp";
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
import {
  attachLanguageControls,
  localizeError,
  localizeStaticPage,
  subscribeLanguage,
  t,
  tx
} from "./i18n";

const MODEL_LAB_CHECKER_IMAGES = {
  white: CheckerGreen,
  black: CheckerRed
};

const MODEL_LAB_DICE_IMAGES = {
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

const MODEL_LAB_DEFAULT_XGID_FIELDS = [
  "-O----------------------o-",
  "0",
  "0",
  "-1",
  "61",
  "0",
  "0",
  "0",
  "1",
  "0"
];

const MULTIPLAYER_VARIANT_IDS = new Set([
  "trictrac_aecrire_a_tourner",
  "trictrac_aecrire_chouette",
  "trictrac_aecrire_deux_contre_deux",
  "trictrac_combine_chouette",
  "trictrac_combine_deux_contre_deux"
]);

function initLobbyForm() {
  const form = document.querySelector("[data-lobby-form]");

  if (!form) {
    return;
  }

  const playModeInput = form.querySelector("[data-play-mode-input]");
  const variantInput = form.querySelector("[data-variant-input]");
  const playModeChoices = Array.from(form.querySelectorAll("[data-play-mode-choice]"));
  const botInput = form.querySelector("[data-bot-input]");
  const opponentChoices = Array.from(form.querySelectorAll("[data-opponent-choice]"));
  const headToHeadVariantChoices = Array.from(form.querySelectorAll("[data-head-to-head-variant]"));
  const multiSeatVariantChoices = Array.from(form.querySelectorAll("[data-multi-seat-variant]"));
  const humanOnlyVariants = form.querySelector("[data-human-only-variants]");
  const computerVariantsNote = form.querySelector("[data-computer-variants-note]");
  const margotOptions = form.querySelector("[data-margot-options]");
  const modePanels = Array.from(form.querySelectorAll("[data-mode-panel]"));
  const growingPotConfig = Array.from(form.querySelectorAll("[data-growing-pot-config]"));
  const pouleGrowingConfig = Array.from(form.querySelectorAll("[data-poule-growing-config]"));
  const pluckedPotConfig = Array.from(form.querySelectorAll("[data-plucked-pot-config]"));
  const pouleMargotConfig = Array.from(form.querySelectorAll("[data-poule-margot-config]"));
  const multiplayerCashConfig = Array.from(form.querySelectorAll("[data-multiplayer-cash-config]"));
  const submitButton = form.querySelector("[data-lobby-submit]");
  const headToHeadSubmitLabel = form.querySelector("[data-head-to-head-submit-label]");
  const multiSeatSubmitLabel = form.querySelector("[data-multi-seat-submit-label]");
  const blueskyHandleInput = form.querySelector("[data-bluesky-handle-input]");
  const blueskyLoginButton = form.querySelector("[data-bluesky-login-button]");
  const identityMode = form.dataset.identityMode || "manual";
  const blueskyAuthenticated = form.dataset.authenticated === "true";
  const blueskyLoginUrl = form.dataset.loginUrl || "/auth/bluesky/login";
  const blueskyReturnTo = form.dataset.returnTo || "/";

  const checkedPlayMode = () => playModeChoices.find((choice) => choice.checked)?.value || "head_to_head";
  const checkedOpponent = () => opponentChoices.find((choice) => choice.checked)?.value || "human";
  const checkedHeadToHeadVariant = () => headToHeadVariantChoices.find((choice) => choice.checked);
  const checkedMultiSeatVariant = () => multiSeatVariantChoices.find((choice) => choice.checked);
  const multiSeatSessionKind = () => checkedMultiSeatVariant()?.dataset.sessionKind || "poule";
  const multiSeatStyle = () => checkedMultiSeatVariant()?.dataset.pouleStyle || "growing_pot";
  const firstComputerVariant = () => headToHeadVariantChoices.find((choice) => choice.dataset.computerBot);

  const syncLobbyForm = () => {
    const multiSeatMode = checkedPlayMode() === "multi_seat";
    const sessionKind = multiSeatMode ? multiSeatSessionKind() : "head_to_head";
    const pluckedPot = multiSeatMode && sessionKind === "poule" && multiSeatStyle() === "plucked_pot";
    const multiplayer = multiSeatMode && sessionKind === "multiplayer";

    if (playModeInput) {
      playModeInput.value = multiSeatMode ? "multi_seat" : "head_to_head";
    }

    form.classList.toggle("multi-seat-mode", multiSeatMode);
    modePanels.forEach((panel) => {
      panel.hidden = panel.dataset.modePanel !== (multiSeatMode ? "multi_seat" : "head_to_head");
    });

    if (headToHeadSubmitLabel) {
      headToHeadSubmitLabel.hidden = multiSeatMode;
    }

    if (multiSeatSubmitLabel) {
      multiSeatSubmitLabel.hidden = !multiSeatMode;
    }

    if (multiSeatMode) {
      form.classList.remove("computer-mode");

      if (variantInput) {
        variantInput.value = checkedMultiSeatVariant()?.value || "trictrac_en_poule";
      }

      if (botInput) {
        botInput.value = "";
      }

      if (computerVariantsNote) {
        computerVariantsNote.hidden = true;
      }

      if (margotOptions) {
        margotOptions.hidden = true;
      }

      pouleGrowingConfig.forEach((element) => {
        const hidden = multiplayer || pluckedPot;
        element.hidden = hidden;

        element.querySelectorAll("input, select, textarea").forEach((control) => {
          control.disabled = hidden;
        });
      });

      growingPotConfig.forEach((element) => {
        const hidden = multiplayer || pluckedPot;
        element.hidden = hidden;

        element.querySelectorAll("input, select, textarea").forEach((control) => {
          control.disabled = hidden;
        });
      });

      pluckedPotConfig.forEach((element) => {
        const hidden = !pluckedPot;
        element.hidden = hidden;

        element.querySelectorAll("input, select, textarea").forEach((control) => {
          control.disabled = hidden;
        });
      });

      pouleMargotConfig.forEach((element) => {
        element.hidden = multiplayer;
        element.querySelectorAll("input, select, textarea").forEach((control) => {
          control.disabled = multiplayer;
        });
      });

      multiplayerCashConfig.forEach((element) => {
        element.hidden = !multiplayer;
        element.querySelectorAll("input, select, textarea").forEach((control) => {
          control.disabled = !multiplayer;
        });
      });

      return;
    }

    pouleGrowingConfig.forEach((element) => {
      element.hidden = false;

      element.querySelectorAll("input, select, textarea").forEach((control) => {
        control.disabled = false;
      });
    });

    growingPotConfig.forEach((element) => {
      element.hidden = false;

      element.querySelectorAll("input, select, textarea").forEach((control) => {
        control.disabled = false;
      });
    });

    pluckedPotConfig.forEach((element) => {
      element.hidden = true;

      element.querySelectorAll("input, select, textarea").forEach((control) => {
        control.disabled = true;
      });
    });

    pouleMargotConfig.forEach((element) => {
      element.hidden = false;
      element.querySelectorAll("input, select, textarea").forEach((control) => {
        control.disabled = false;
      });
    });

    multiplayerCashConfig.forEach((element) => {
      element.hidden = true;
      element.querySelectorAll("input, select, textarea").forEach((control) => {
        control.disabled = true;
      });
    });

    const computerMode = checkedOpponent() === "computer";

    if (computerMode && !checkedHeadToHeadVariant()?.dataset.computerBot) {
      const fallback = firstComputerVariant();

      if (fallback) {
        fallback.checked = true;
      }
    }

    const selectedVariant = checkedHeadToHeadVariant();
    const selectedBot = computerMode ? selectedVariant?.dataset.computerBot || "" : "";

    if (variantInput) {
      variantInput.value = selectedVariant?.value || "backgammon";
    }

    form.classList.toggle("computer-mode", computerMode);

    if (botInput) {
      botInput.value = selectedBot;
    }

    headToHeadVariantChoices.forEach((choice) => {
      const disabled = computerMode && !choice.dataset.computerBot;
      choice.disabled = disabled;
      choice.closest(".variant-option")?.classList.toggle("variant-option-disabled", disabled);
    });

    if (humanOnlyVariants) {
      humanOnlyVariants.hidden = computerMode;

      if (computerMode) {
        humanOnlyVariants.open = false;
      }
    }

    if (computerVariantsNote) {
      computerVariantsNote.hidden = !computerMode;
    }

    if (margotOptions) {
      margotOptions.hidden = !(computerMode && selectedBot === "trictrac_zero");
    }

    if (submitButton) {
      submitButton.disabled = identityMode === "bluesky_oauth" && !blueskyAuthenticated;
    }
  };

  playModeChoices.forEach((choice) => choice.addEventListener("change", syncLobbyForm));
  opponentChoices.forEach((choice) => choice.addEventListener("change", syncLobbyForm));
  headToHeadVariantChoices.forEach((choice) => choice.addEventListener("change", syncLobbyForm));
  multiSeatVariantChoices.forEach((choice) => choice.addEventListener("change", syncLobbyForm));

  blueskyLoginButton?.addEventListener("click", () => {
    const handle = blueskyHandleInput?.value?.trim();

    if (!handle) {
      blueskyHandleInput?.reportValidity?.();
      blueskyHandleInput?.focus();
      return;
    }

    const params = new URLSearchParams({
      handle,
      return_to: blueskyReturnTo
    });

    window.location.assign(`${blueskyLoginUrl}?${params.toString()}`);
  });

  syncLobbyForm();
}

function initModelLab() {
  const root = document.getElementById("model-lab-root");

  if (!root) {
    return;
  }

  const xgidInput = root.querySelector("[data-model-lab-xgid]");
  const modelSelect = root.querySelector("[data-model-lab-model]");
  const die1Control = root.querySelector('[data-model-lab-die="1"]');
  const die2Control = root.querySelector('[data-model-lab-die="2"]');
  const dieControls = [die1Control, die2Control].filter(Boolean);
  const turnSelect = root.querySelector("[data-model-lab-turn]");
  const directionSelect = root.querySelector("[data-model-lab-black-direction]");
  const editorColorInputs = root.querySelectorAll("[data-model-lab-editor-color]");
  const status = root.querySelector("[data-model-lab-status]");
  const board = root.querySelector("[data-model-lab-board]");
  const boardMeta = root.querySelector("[data-model-lab-board-meta]");
  const results = root.querySelector("[data-model-lab-results]");
  const models = safeJson(root.dataset.models, []);
  const preferredModel = models.find((model) => model.id === "trictrac_zero:classique") || models[0];
  let currentPosition = null;
  let editorMode = root.querySelector("[data-model-lab-editor-color]:checked")?.value || "white";

  const selectedModel = () => models.find((model) => model.id === modelSelect?.value) || preferredModel;
  const selectedModelMovement = () => selectedModel()?.movement_mode || "contrary";
  const selectedBlackDirection = () => directionSelect?.value || selectedModel()?.black_direction || "toward_1";
  const selectedModelUsesBar = () => selectedModel()?.uses_bar === true;

  const syncDirectionToSelectedModel = () => {
    if (!directionSelect) {
      return;
    }

    directionSelect.value = selectedModel()?.black_direction || "toward_1";

    if (currentPosition) {
      currentPosition.movement_mode = selectedModelMovement();
      currentPosition.black_direction = directionSelect.value;
      currentPosition.white_direction = whiteDirection(selectedModelMovement(), directionSelect.value);
      currentPosition.uses_bar = selectedModelUsesBar();
    }
  };

  if (modelSelect && preferredModel) {
    modelSelect.value = preferredModel.id;
  }

  syncDirectionToSelectedModel();

  const selectedPayload = (runs) => ({
    xgid: xgidInput?.value || "",
    model: modelSelect?.value || preferredModel?.id || "backgammon_ai",
    die1: die1Control?.value || "6",
    die2: die2Control?.value || "1",
    turn_color: turnSelect?.value || "from_xgid",
    black_direction: selectedBlackDirection(),
    runs
  });

  const setBusy = (busy) => {
    root.querySelectorAll("button, input, select, textarea").forEach((control) => {
      control.disabled = busy;
    });
  };

  const setStatus = (message, error = false) => {
    if (!status) {
      return;
    }

    status.textContent = message;
    status.classList.toggle("error", error);
  };

  const markSettingsChanged = (message = "Settings changed. Run the model again.") => {
    if (results) {
      results.replaceChildren(paragraph("muted-copy", message));
    }
  };

  const currentDice = () => [
    normalizedDieValue(die1Control?.value, 6),
    normalizedDieValue(die2Control?.value, 1)
  ];

  const currentDiceColor = () => {
    const selectedTurn = turnSelect?.value;

    if (selectedTurn === "white" || selectedTurn === "black") {
      return selectedTurn;
    }

    return currentPosition?.turn_color || "white";
  };

  const renderDiceControls = () => {
    dieControls.forEach((control) => {
      setDieControlValue(control, normalizedDieValue(control.value, 1), currentDiceColor());
    });
  };

  const renderCurrentBoard = () => {
    renderModelLabBoard(board, boardMeta, currentPosition, {
      onBarEdit: editBar,
      onPointEdit: editPoint,
      usesBar: currentPosition?.uses_bar !== false
    });
    renderDiceControls();
  };

  const syncXgidFromControls = () => {
    if (!xgidInput) {
      return;
    }

    const fields = xgidFields(xgidInput.value);
    const dice = currentDice();
    fields[4] = dice.join("");

    if (currentPosition?.board) {
      fields[0] = encodeXgidPosition(currentPosition.board, currentPosition.uses_bar !== false);
      currentPosition.dice = dice;
      currentPosition.movement_mode = selectedModelMovement();
      currentPosition.black_direction = selectedBlackDirection();
      currentPosition.white_direction = whiteDirection(selectedModelMovement(), selectedBlackDirection());
      currentPosition.uses_bar = selectedModelUsesBar();
    }

    const selectedTurn = turnSelect?.value;

    if (selectedTurn === "white" || selectedTurn === "black") {
      fields[3] = selectedTurn === "white" ? "-1" : "1";

      if (currentPosition) {
        currentPosition.turn_color = selectedTurn;
      }
    }

    xgidInput.value = `XGID=${fields.join(":")}`;
  };

  const editPoint = (pointIndex, delta = 1) => {
    if (!currentPosition?.board?.points) {
      return;
    }

    const point = currentPosition.board.points.find((candidate) => candidate.index === pointIndex);

    if (!point) {
      return;
    }

    if (editorMode === "clear") {
      point.white = 0;
      point.black = 0;
    } else if (delta < 0) {
      point[editorMode] = Math.max((point[editorMode] || 0) - 1, 0);
    } else {
      const total = colorMenOnBoard(currentPosition.board, editorMode, currentPosition.uses_bar !== false);

      if ((point[editorMode] || 0) === 0 && total >= 15) {
        setStatus(`Cannot add more than 15 ${editorMode} men.`, true);
        markSettingsChanged("Board edit rejected: too many men.");
        return;
      }

      const nextCount = (point[editorMode] || 0) >= 15 ? 0 : (point[editorMode] || 0) + 1;
      const deltaCount = nextCount - (point[editorMode] || 0);

      if (deltaCount > 0 && total + deltaCount > 15) {
        setStatus(`Cannot add more than 15 ${editorMode} men.`, true);
        markSettingsChanged("Board edit rejected: too many men.");
        return;
      }

      point.white = editorMode === "white" ? nextCount : 0;
      point.black = editorMode === "black" ? nextCount : 0;
    }

    recomputeOutside(currentPosition.board, currentPosition.uses_bar !== false);
    syncXgidFromControls();
    renderCurrentBoard();
    markSettingsChanged("Board edited. Run the model again.");
    setStatus(`Point ${point.display || 24 - point.index} updated; XGID refreshed.`);
  };

  const editBar = (color, delta = 1) => {
    if (currentPosition?.uses_bar === false) {
      setStatus("This model does not use a bar.", true);
      return;
    }

    if (!currentPosition?.board?.bar) {
      return;
    }

    if (editorMode === "clear") {
      currentPosition.board.bar[color] = 0;
    } else if (editorMode !== color) {
      setStatus(`Select ${color} to edit the ${color} bar.`, true);
      return;
    } else if (delta < 0) {
      currentPosition.board.bar[color] = Math.max((currentPosition.board.bar[color] || 0) - 1, 0);
    } else {
      const total = colorMenOnBoard(currentPosition.board, color);

      if (total >= 15) {
        setStatus(`Cannot add more than 15 ${color} men.`, true);
        markSettingsChanged("Bar edit rejected: too many men.");
        return;
      }

      currentPosition.board.bar[color] = (currentPosition.board.bar[color] || 0) + 1;
    }

    recomputeOutside(currentPosition.board, true);
    syncXgidFromControls();
    renderCurrentBoard();
    markSettingsChanged("Bar edited. Run the model again.");
    setStatus(`${capitalize(color)} bar updated; XGID refreshed.`);
  };

  const loadBoard = async () => {
    setStatus("Loading board…");
    setBusy(true);

    try {
      const payload = await postJson("/dev/model-lab/parse", {
        xgid: xgidInput?.value || "",
        model: modelSelect?.value || preferredModel?.id || "backgammon_ai",
        turn_color: turnSelect?.value || "from_xgid",
        black_direction: selectedBlackDirection()
      });
      currentPosition = payload;

      if (payload.dice?.length >= 2) {
        setDieControlValue(die1Control, payload.dice[0], currentDiceColor());
        setDieControlValue(die2Control, payload.dice[1], currentDiceColor());
      }

      renderCurrentBoard();
      setStatus("Board loaded.");
    } catch (error) {
      setStatus(error.message || "Unable to parse XGID.", true);
    } finally {
      setBusy(false);
    }
  };

  const run = async (runs) => {
    const modelLabel = selectedModelLabel(modelSelect, models);
    setStatus(`Running ${runs} samples with ${modelLabel}…`);
    setBusy(true);
    results.replaceChildren(paragraph("muted-copy", `Running ${modelLabel}. This can take a moment.`));

    try {
      const payload = await postJson("/dev/model-lab/run", selectedPayload(runs));
      currentPosition = payload.position;
      renderCurrentBoard();
      renderModelLabResults(results, payload);
      setStatus(`Finished ${payload.runs} samples with ${payload.model?.label || modelLabel}.`);
    } catch (error) {
      results.replaceChildren(paragraph("muted-copy error", error.message || "Model analysis failed."));
      setStatus(error.message || "Model analysis failed.", true);
    } finally {
      setBusy(false);
    }
  };

  root.querySelector("[data-model-lab-load]")?.addEventListener("click", loadBoard);
  root.querySelectorAll("[data-model-lab-run]").forEach((button) => {
    button.addEventListener("click", () => run(button.dataset.modelLabRun));
  });

  dieControls.forEach((control) => {
    control.addEventListener("click", () => {
      const next = normalizedDieValue(control.value, 1) >= 6 ? 1 : normalizedDieValue(control.value, 1) + 1;
      setDieControlValue(control, next, currentDiceColor());
      syncXgidFromControls();
      renderCurrentBoard();
      markSettingsChanged("Dice changed. Run the model again.");
    });
  });

  editorColorInputs.forEach((input) => {
    input.addEventListener("change", () => {
      editorMode = input.value;
    });
  });

  turnSelect?.addEventListener("change", () => {
    syncXgidFromControls();
    renderCurrentBoard();
    markSettingsChanged();
  });

  directionSelect?.addEventListener("change", () => {
    if (currentPosition) {
      currentPosition.movement_mode = selectedModelMovement();
      currentPosition.black_direction = directionSelect.value;
      currentPosition.white_direction = whiteDirection(selectedModelMovement(), directionSelect.value);
      currentPosition.uses_bar = selectedModelUsesBar();
    }

    renderCurrentBoard();
    markSettingsChanged(
      `Direction changed: ${directionSummary(selectedModelMovement(), selectedBlackDirection())}. Run the model again.`
    );
  });

  modelSelect?.addEventListener("change", () => {
    syncDirectionToSelectedModel();
    renderCurrentBoard();
    markSettingsChanged(
      `${selectedModelLabel(modelSelect, models)} uses ${movementModeLabel(
        selectedModelMovement()
      )} movement; ${directionSummary(selectedModelMovement(), selectedBlackDirection())}. Run the model again.`
    );
  });

  xgidInput?.addEventListener("change", () => {
    markSettingsChanged("XGID changed. Load the board or run the model.");
  });

  renderDiceControls();
  loadBoard();
}

function selectedModelLabel(modelSelect, models) {
  const id = modelSelect?.value || "";
  return models.find((model) => model.id === id)?.label || id || "selected model";
}

function normalizedDieValue(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  return parsed >= 1 && parsed <= 6 ? parsed : fallback;
}

function setDieControlValue(control, value, color = "white") {
  if (!control) {
    return;
  }

  const die = normalizedDieValue(value, 1);
  const dieColor = color === "black" ? "black" : "white";
  control.value = String(die);
  control.setAttribute("aria-label", `Die ${control.dataset.modelLabDie}: ${die}`);

  const image = document.createElement("img");
  image.className = "themed-die";
  image.src = MODEL_LAB_DICE_IMAGES[dieColor][die];
  image.alt = `Die ${die}`;

  control.replaceChildren(image);
}

function xgidFields(value) {
  const text = (value || "").trim();
  const id = text.match(/XGID=([^\s]+)/i)?.[1] || text;
  const fields = id.includes(":") ? id.split(":").slice(0, 10) : [];

  return MODEL_LAB_DEFAULT_XGID_FIELDS.map((fallback, index) => fields[index] || fallback);
}

function encodeXgidPosition(board, usesBar = true) {
  const chars = Array.from({ length: 26 }, () => "-");
  chars[0] = encodeXgidCount("white", usesBar ? board?.bar?.white || 0 : 0);
  chars[25] = encodeXgidCount("black", usesBar ? board?.bar?.black || 0 : 0);

  (board?.points || []).forEach((point) => {
    if (point.index >= 0 && point.index < 24) {
      chars[point.index + 1] = encodeXgidPoint(point);
    }
  });

  return chars.join("");
}

function encodeXgidPoint(point) {
  const white = point.white || 0;
  const black = point.black || 0;

  if (white >= black && white > 0) {
    return encodeXgidCount("white", white);
  }

  if (black > 0) {
    return encodeXgidCount("black", black);
  }

  return "-";
}

function encodeXgidCount(color, count) {
  const normalized = Math.max(0, Math.min(15, Number.parseInt(count, 10) || 0));

  if (normalized === 0) {
    return "-";
  }

  const base = color === "white" ? "a".charCodeAt(0) : "A".charCodeAt(0);
  return String.fromCharCode(base + normalized - 1);
}

function recomputeOutside(board, usesBar = true) {
  ["white", "black"].forEach((color) => {
    const total = colorMenOnBoard(board, color, usesBar);
    board.outside = board.outside || {};
    board.outside[color] = Math.max(15 - total, 0);
  });
}

function colorMenOnBoard(board, color, usesBar = true) {
  const onPoints = (board?.points || []).reduce((total, point) => total + (point[color] || 0), 0);
  const onBar = usesBar ? board?.bar?.[color] || 0 : 0;
  return onPoints + onBar;
}

function capitalize(value) {
  const text = String(value || "");
  return text ? text[0].toUpperCase() + text.slice(1) : text;
}

function movementModeLabel(mode) {
  return mode === "parallel" ? "parallel" : "contrary";
}

function directionLabel(direction) {
  return direction === "toward_24" ? "1→24" : "24→1";
}

function whiteDirection(movementMode, blackDirection) {
  if (movementMode === "parallel") {
    return blackDirection;
  }

  return blackDirection === "toward_24" ? "toward_1" : "toward_24";
}

function directionSummary(movementMode, blackDirection) {
  const white = whiteDirection(movementMode, blackDirection);
  return `Black ${directionLabel(blackDirection)}, White ${directionLabel(white)}`;
}

function safeJson(value, fallback) {
  try {
    return value ? JSON.parse(value) : fallback;
  } catch (_error) {
    return fallback;
  }
}

async function postJson(url, payload) {
  const response = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json", accept: "application/json" },
    body: JSON.stringify(payload)
  });
  const body = await response.json().catch(() => ({}));

  if (!response.ok) {
    throw new Error(body.error || `Request failed with ${response.status}`);
  }

  return body;
}

function paragraph(className, text) {
  const p = document.createElement("p");
  p.className = className;
  p.textContent = text;
  return p;
}

function renderModelLabBoard(container, meta, position, options = {}) {
  if (!container || !position?.board) {
    return;
  }

  const top = [23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12];
  const bottom = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
  const points = new Map((position.board.points || []).map((point) => [point.index, point]));
  const shell = document.createElement("div");
  shell.className = "board-shell player-white model-lab-board-shell";
  shell.style.backgroundImage = `url(${BoardWood})`;

  const sheen = document.createElement("div");
  sheen.className = "board-sheen";

  const grid = document.createElement("div");
  grid.className = "board-grid";

  const children = [renderModelLabBoardRow(top, points, true, options)];

  if (options.usesBar !== false) {
    children.push(renderModelLabBarColumn(position.board, options));
  }

  children.push(
    renderModelLabHomeColumn(position.board),
    renderModelLabBoardRow(bottom, points, false, options)
  );

  grid.replaceChildren(...children);
  shell.replaceChildren(sheen, grid);
  container.replaceChildren(shell);

  if (meta) {
    const dice = position.dice?.length ? position.dice.join("-") : "none";
    const movementMode = position.movement_mode || options.movementMode || "contrary";
    const movement = movementModeLabel(movementMode);
    const blackDirection = position.black_direction || "toward_1";
    const bar = position.uses_bar === false ? "no bar" : "bar enabled";
    meta.textContent = `${position.turn_color || "white"} to play, dice ${dice}, ${movement} movement (${directionSummary(movementMode, blackDirection)}), ${bar}`;
  }
}

function renderModelLabBoardRow(indices, points, isTop, options = {}) {
  const row = document.createElement("div");
  row.className = `board-row ${isTop ? "top" : "bottom"}`;
  const left = renderModelLabPointStrip(indices.slice(0, 6), points, isTop, "left", options);
  const right = renderModelLabPointStrip(indices.slice(6), points, isTop, "right", options);
  row.replaceChildren(left, right);
  return row;
}

function renderModelLabPointStrip(indices, points, isTop, side, options = {}) {
  const strip = document.createElement("div");
  strip.className = `point-strip ${isTop ? "top" : "bottom"} ${side}`;

  indices.forEach((index) => {
    const point = points.get(index) || { index, display: 24 - index, white: 0, black: 0 };
    strip.appendChild(renderModelLabPoint(point, isTop, options));
  });

  return strip;
}

function renderModelLabPoint(point, isTop, options = {}) {
  const slot = document.createElement("div");
  slot.className = `point-slot ${isTop ? "top" : "bottom"} ${options.onPointEdit ? "actionable model-lab-editable-point" : ""}`;

  const triangle = document.createElement("span");
  triangle.className = "point-triangle";

  const label = document.createElement("span");
  label.className = `point-number ${isTop ? "top" : "bottom"}`;
  label.textContent = point.display;

  slot.replaceChildren(triangle, label, renderModelLabCheckerStack(pointPieces(point), isTop));

  if (options.onPointEdit) {
    slot.setAttribute("role", "button");
    slot.tabIndex = 0;
    slot.title = `Edit point ${point.display}`;
    slot.addEventListener("click", (event) => {
      options.onPointEdit(point.index, event.altKey ? -1 : 1);
    });
    slot.addEventListener("contextmenu", (event) => {
      event.preventDefault();
      options.onPointEdit(point.index, -1);
    });
    slot.addEventListener("keydown", (event) => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        options.onPointEdit(point.index, event.altKey ? -1 : 1);
      }
    });
  }

  return slot;
}

function renderModelLabBarColumn(board, options = {}) {
  const column = document.createElement("div");
  column.className = "bar-column model-lab-bar-column";
  column.replaceChildren(
    renderModelLabBarPocket("black", board.bar?.black || 0, true, options),
    renderModelLabBarPocket("white", board.bar?.white || 0, false, options)
  );
  return column;
}

function renderModelLabBarPocket(color, count, isTop, options = {}) {
  const pocket = document.createElement("div");
  pocket.className = `bar-pocket ${isTop ? "top" : "bottom"} ${options.onBarEdit ? "actionable model-lab-editable-bar" : ""}`;

  const label = paragraph("", t("game.bar"));
  const value = document.createElement("strong");
  value.textContent = count;
  pocket.replaceChildren(label, renderModelLabCheckerStack(Array.from({ length: count }, () => color), isTop), value);

  if (options.onBarEdit) {
    pocket.setAttribute("role", "button");
    pocket.tabIndex = 0;
    pocket.title = `Edit ${color} bar`;
    pocket.addEventListener("click", (event) => {
      options.onBarEdit(color, event.altKey ? -1 : 1);
    });
    pocket.addEventListener("contextmenu", (event) => {
      event.preventDefault();
      options.onBarEdit(color, -1);
    });
    pocket.addEventListener("keydown", (event) => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        options.onBarEdit(color, event.altKey ? -1 : 1);
      }
    });
  }

  return pocket;
}

function renderModelLabHomeColumn(board) {
  const column = document.createElement("div");
  column.className = "home-column";
  column.replaceChildren(
    renderModelLabHomePocket("black", board.outside?.black || 0, true),
    renderModelLabHomePocket("white", board.outside?.white || 0, false)
  );
  return column;
}

function renderModelLabHomePocket(color, count, isTop) {
  const pocket = document.createElement("div");
  pocket.className = `home-pocket ${isTop ? "top" : "bottom"}`;

  const label = paragraph("", t("game.bearOff"));
  const value = document.createElement("strong");
  value.textContent = count;
  pocket.replaceChildren(label, renderModelLabCheckerStack(Array.from({ length: count }, () => color), isTop), value);
  return pocket;
}

function renderModelLabCheckerStack(pieces, isTop) {
  const stack = document.createElement("span");
  stack.className = "checker-stack";
  const visiblePieces = pieces.slice(Math.max(0, pieces.length - 5));

  visiblePieces.forEach((color, index) => {
    const checker = document.createElement("span");
    checker.className = "checker";
    checker.style[isTop ? "top" : "bottom"] = `${index * 12}px`;

    const image = document.createElement("span");
    image.className = "checker-image";
    image.style.backgroundImage = `url(${MODEL_LAB_CHECKER_IMAGES[color]})`;
    checker.appendChild(image);
    stack.appendChild(checker);
  });

  if (pieces.length > 5) {
    const count = document.createElement("span");
    count.className = "stack-count";
    count.textContent = pieces.length;
    stack.appendChild(count);
  }

  return stack;
}

function pointPieces(point) {
  return [
    ...Array.from({ length: point.black || 0 }, () => "black"),
    ...Array.from({ length: point.white || 0 }, () => "white")
  ];
}

function renderModelLabResults(container, payload) {
  if (!container) {
    return;
  }

  if (!payload.results?.length) {
    container.replaceChildren(paragraph("muted-copy", "No choices returned."));
    return;
  }

  const list = document.createElement("div");
  list.className = "model-lab-result-list";
  const summary = paragraph(
    "muted-copy",
    `Using ${payload.model?.label || payload.model?.id || "selected model"}`
  );

  payload.results.forEach((result, index) => {
    const item = document.createElement("article");
    item.className = "model-lab-result";

    const heading = document.createElement("h3");
    heading.textContent = `${index + 1}. ${result.move_text}`;

    const count = paragraph("muted-copy", `${result.count}/${payload.runs} samples (${result.percentage}%)`);
    item.append(heading, count);

    if (result.events?.length) {
      const events = document.createElement("ul");
      events.className = "model-lab-events";

      result.events.forEach((event) => {
        const li = document.createElement("li");
        li.textContent = scoreEventText(event);
        events.appendChild(li);
      });

      item.appendChild(events);
    }

    if (shouldShowLineEvents(result)) {
      item.appendChild(paragraph("muted-copy", "Scored during the turn"));

      const lineEvents = document.createElement("ul");
      lineEvents.className = "model-lab-events";

      result.line_events.forEach((event) => {
        const li = document.createElement("li");
        li.textContent = scoreEventText(event);
        lineEvents.appendChild(li);
      });

      item.appendChild(lineEvents);
    }

    if (result.pending_turn_decision?.key) {
      item.appendChild(paragraph("muted-copy", `Pending decision: ${result.pending_turn_decision.key}`));
    }

    if (result.errors?.length) {
      item.appendChild(paragraph("muted-copy error", result.errors.join("; ")));
    }

    list.appendChild(item);
  });

  container.replaceChildren(summary, list);
}

function shouldShowLineEvents(result) {
  if (!result.line_events?.length) {
    return false;
  }

  if (!result.events?.length) {
    return true;
  }

  return JSON.stringify(result.line_events) !== JSON.stringify(result.events);
}

function scoreEventText(event) {
  const key = event.rule || event.source || "";
  const label = key ? tx(`scoreEvents.${key}`, event.label || key) : event.label || "score event";
  const beneficiary = event.beneficiary || event.piece_type || "unknown";
  const points = event.points ?? 0;
  const trous = event.trous_delta ? `, ${event.trous_delta} trous` : "";

  return `${label}: ${points} points to ${beneficiary}${trous}`;
}

function renderJoinStatus(root, message, detail = "") {
  const card = document.createElement("section");
  card.className = "rail-card join-status-card";

  const label = document.createElement("p");
  label.className = "rail-label";
  label.textContent = t("join.joiningLabel");

  const copy = document.createElement("p");
  copy.className = "status-line";
  copy.textContent = message;

  if (detail) {
    const detailCopy = document.createElement("p");
    detailCopy.className = "muted-copy";
    detailCopy.textContent = detail;
    card.replaceChildren(label, copy, detailCopy);
  } else {
    card.replaceChildren(label, copy);
  }

  root.replaceChildren(card);
}

function renderJoinError(root, { title, detail, hint, retryable = true }) {
  const shell = document.createElement("div");
  shell.className = "join-error-shell";

  const toastStack = document.createElement("div");
  toastStack.className = "toast-stack join-error-toast-stack";
  toastStack.setAttribute("aria-live", "assertive");
  toastStack.setAttribute("aria-atomic", "true");

  const toast = document.createElement("article");
  toast.className = "toast-card toast-card-error";

  const toastTitle = document.createElement("strong");
  toastTitle.textContent = title;

  const toastDetail = document.createElement("p");
  toastDetail.textContent = detail;

  toast.replaceChildren(toastTitle, toastDetail);
  toastStack.appendChild(toast);

  const card = document.createElement("section");
  card.className = "rail-card join-error-card";

  const label = document.createElement("p");
  label.className = "rail-label";
  label.textContent = t("join.joinFailed");

  const heading = document.createElement("h2");
  heading.textContent = title;

  const detailCopy = document.createElement("p");
  detailCopy.className = "status-line";
  detailCopy.textContent = detail;

  const hintCopy = document.createElement("p");
  hintCopy.className = "muted-copy";
  hintCopy.textContent = hint;

  const actions = document.createElement("div");
  actions.className = "join-error-actions";

  const lobbyLink = document.createElement("a");
  lobbyLink.className = "button-link";
  lobbyLink.href = "/";
  lobbyLink.textContent = t("join.backToLobby");

  if (retryable) {
    const retry = document.createElement("button");
    retry.type = "button";
    retry.textContent = t("join.tryAgain");
    retry.addEventListener("click", () => window.location.reload());
    actions.appendChild(retry);
  }

  actions.appendChild(lobbyLink);
  card.replaceChildren(label, heading, detailCopy, hintCopy, actions);
  shell.replaceChildren(toastStack, card);
  root.replaceChildren(shell);
}

document.addEventListener("DOMContentLoaded", () => {
  attachLanguageControls(document);
  localizeStaticPage(document);
  subscribeLanguage(() => localizeStaticPage(document));
  initLobbyForm();
  initModelLab();

  const root = document.getElementById("root");

  if (!root?.dataset.joinTopic || !root.dataset.user) {
    return;
  }

  const clientIdScope = root.dataset.clientIdScope === "browser" ? "browser" : "tab";
  const storageKey = `hermes-trictrac-client-id:${root.dataset.joinTopic}`;
  const storage = clientIdScope === "browser" ? window.localStorage : window.sessionStorage;
  let clientId = storage.getItem(storageKey);

  if (!clientId) {
    clientId = window.crypto?.randomUUID?.() || `${Date.now()}-${Math.random().toString(16).slice(2)}`;
    storage.setItem(storageKey, clientId);
  }

  const payload = {
    user: root.dataset.user,
    variant: root.dataset.variant,
    client_id: clientId
  };

  if (root.dataset.queueSize) {
    payload.queue_size = root.dataset.queueSize;
  }

  if (root.dataset.ante) {
    payload.ante = root.dataset.ante;
  }

  if (root.dataset.stake) {
    payload.stake = root.dataset.stake;
  }

  if (root.dataset.holeValue) {
    payload.hole_value = root.dataset.holeValue;
  }

  if (root.dataset.margotEnabled) {
    payload.margot_enabled = root.dataset.margotEnabled;
  }

  if (root.dataset.aEcrirePartieLength && !MULTIPLAYER_VARIANT_IDS.has(root.dataset.variant)) {
    payload.aEcrirePartieLength = root.dataset.aEcrirePartieLength;
  }

  if (root.dataset.cashPerJetonMinor) {
    payload.cash_per_jeton_minor = root.dataset.cashPerJetonMinor;
  }

  if (root.dataset.bot) {
    payload.bot = root.dataset.bot;
    payload.bot_margot = root.dataset.botMargot || "no";
  }

  const joinTimeoutMs = root.dataset.bot ? 120000 : 15000;
  const loadingMessage = root.dataset.bot
    ? t("join.connectingBot")
    : t("join.connecting");
  const slowMessage = root.dataset.bot
    ? t("join.slowBot")
    : t("join.slow");

  const attemptJoin = (statusMessage = loadingMessage, detail = "") => {
    renderJoinStatus(root, statusMessage, detail);

    const channel = socket.channel(root.dataset.joinTopic, payload);
    let joinComplete = false;
    const slowJoinTimer = window.setTimeout(() => {
      if (!joinComplete) {
        renderJoinStatus(root, slowMessage, detail);
      }
    }, 8000);

    gameInit(root, channel, {
      joinTimeoutMs,
      botMargotPreference: root.dataset.botMargot || "",
      onJoinComplete: () => {
        joinComplete = true;
        window.clearTimeout(slowJoinTimer);
      },
      onJoinError: (resp) => {
        if (resp?.code === "seat_reclaim_pending" && resp?.retry_after_ms != null) {
          const retryAfterMs = Math.max(1_000, Number(resp.retry_after_ms) || 1_000);
          const retrySeconds = Math.ceil(retryAfterMs / 1000);

          renderJoinStatus(
            root,
            localizeError(resp, "errors.seat_reclaim_pending"),
            t("join.reclaimRetry", { seconds: retrySeconds })
          );

          const retryButton = document.createElement("button");
          retryButton.type = "button";
          retryButton.textContent = t("join.tryAgain");
          retryButton.addEventListener("click", () => {
            attemptJoin(t("join.reclaiming"));
          });
          root.querySelector(".join-status-card")?.appendChild(retryButton);

          return;
        }

        renderJoinError(root, {
          title: t("join.unable"),
          detail: localizeError(resp, "errors.unknown") || t("join.rejected"),
          hint: t("join.hint"),
          retryable: resp?.code !== "variant_mismatch"
        });
      },
      onJoinTimeout: () => {
        renderJoinError(root, {
          title: t("join.timedOut"),
          detail: root.dataset.bot
            ? t("join.botMayWarm")
            : t("join.noResponse"),
          hint: t("join.timeoutHint")
        });
      }
    });
  };

  attemptJoin();
});
