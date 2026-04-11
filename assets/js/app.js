import "../css/app.css";
import "phoenix_html"
import socket from "./socket";
import gameInit from "./HermesTrictracApp";
document.addEventListener("DOMContentLoaded", () => {
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

  root.innerHTML = `<p>${loadingMessage}</p>`;

  const channel = socket.channel(root.dataset.joinTopic, payload);
  let joinComplete = false;
  const slowJoinTimer = window.setTimeout(() => {
    if (!joinComplete) {
      root.innerHTML = `<p>${slowMessage}</p>`;
    }
  }, 8000);

  gameInit(root, channel, {
    joinTimeoutMs,
    botMargotPreference: root.dataset.botMargot || "",
    onJoinComplete: () => {
      joinComplete = true;
      window.clearTimeout(slowJoinTimer);
    }
  });
});
