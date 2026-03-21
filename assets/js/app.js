import "../css/app.css";
import "phoenix_html"
import socket from "./socket";
import gameInit from "./Backgammon";
document.addEventListener("DOMContentLoaded", () => {
  const root = document.getElementById("root");

  if (!root?.dataset.joinTopic || !root.dataset.user) {
    return;
  }

  const storageKey = `backgammon-client-id:${root.dataset.joinTopic}`;
  let clientId = window.sessionStorage.getItem(storageKey);

  if (!clientId) {
    clientId = window.crypto?.randomUUID?.() || `${Date.now()}-${Math.random().toString(16).slice(2)}`;
    window.sessionStorage.setItem(storageKey, clientId);
  }

  const channel = socket.channel(root.dataset.joinTopic, {
    user: root.dataset.user,
    variant: root.dataset.variant,
    client_id: clientId
  });

  gameInit(root, channel);
});
