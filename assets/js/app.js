import "../css/app.css";
import "phoenix_html"
import socket from "./socket";
import gameInit from "./HermesTrictracApp";

function initLobbyForm() {
  const form = document.querySelector("[data-lobby-form]");

  if (!form) {
    return;
  }

  const botInput = form.querySelector("[data-bot-input]");
  const opponentChoices = Array.from(form.querySelectorAll("[data-opponent-choice]"));
  const variantChoices = Array.from(form.querySelectorAll('input[name="variant"]'));
  const humanOnlyVariants = form.querySelector("[data-human-only-variants]");
  const computerVariantsNote = form.querySelector("[data-computer-variants-note]");
  const margotOptions = form.querySelector("[data-margot-options]");

  const checkedOpponent = () => opponentChoices.find((choice) => choice.checked)?.value || "human";
  const checkedVariant = () => variantChoices.find((choice) => choice.checked);
  const firstComputerVariant = () => variantChoices.find((choice) => choice.dataset.computerBot);

  const syncLobbyForm = () => {
    const computerMode = checkedOpponent() === "computer";

    if (computerMode && !checkedVariant()?.dataset.computerBot) {
      const fallback = firstComputerVariant();

      if (fallback) {
        fallback.checked = true;
      }
    }

    const selectedVariant = checkedVariant();
    const selectedBot = computerMode ? selectedVariant?.dataset.computerBot || "" : "";

    form.classList.toggle("computer-mode", computerMode);

    if (botInput) {
      botInput.value = selectedBot;
    }

    variantChoices.forEach((choice) => {
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
  };

  opponentChoices.forEach((choice) => choice.addEventListener("change", syncLobbyForm));
  variantChoices.forEach((choice) => choice.addEventListener("change", syncLobbyForm));
  syncLobbyForm();
}

function renderJoinStatus(root, message) {
  const card = document.createElement("section");
  card.className = "rail-card join-status-card";

  const label = document.createElement("p");
  label.className = "rail-label";
  label.textContent = "Joining Table";

  const copy = document.createElement("p");
  copy.className = "status-line";
  copy.textContent = message;

  card.replaceChildren(label, copy);
  root.replaceChildren(card);
}

function renderJoinError(root, { title, detail, hint }) {
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
  label.textContent = "Join Failed";

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

  const retry = document.createElement("button");
  retry.type = "button";
  retry.textContent = "Try Again";
  retry.addEventListener("click", () => window.location.reload());

  const lobbyLink = document.createElement("a");
  lobbyLink.className = "button-link";
  lobbyLink.href = "/";
  lobbyLink.textContent = "Back to Lobby";

  actions.replaceChildren(retry, lobbyLink);
  card.replaceChildren(label, heading, detailCopy, hintCopy, actions);
  shell.replaceChildren(toastStack, card);
  root.replaceChildren(shell);
}

document.addEventListener("DOMContentLoaded", () => {
  initLobbyForm();

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

  if (root.dataset.bot) {
    payload.bot = root.dataset.bot;
    payload.bot_margot = root.dataset.botMargot || "no";
  }

  const joinTimeoutMs = root.dataset.bot ? 120000 : 15000;
  const loadingMessage = root.dataset.bot
    ? "Connecting to table and warming the model. The first bot game can take around a minute."
    : "Connecting to table...";
  const slowMessage = root.dataset.bot
    ? "Still warming the model. The first bot connection can take a little while."
    : "Still connecting to table...";

  renderJoinStatus(root, loadingMessage);

  const channel = socket.channel(root.dataset.joinTopic, payload);
  let joinComplete = false;
  const slowJoinTimer = window.setTimeout(() => {
    if (!joinComplete) {
      renderJoinStatus(root, slowMessage);
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
      renderJoinError(root, {
        title: "Unable to Join Table",
        detail: resp?.msg || "The table rejected this join request.",
        hint: "Try a different lobby name, match the existing table's game type, or ask a seated player to make room."
      });
    },
    onJoinTimeout: () => {
      renderJoinError(root, {
        title: "Join Timed Out",
        detail: root.dataset.bot
          ? "The model opponent may still be warming up."
          : "The table did not respond before the join timeout.",
        hint: "Try again in a moment. If this keeps happening, return to the lobby and create a fresh table."
      });
    }
  });
});
