import React, { useState } from "react";

function ChatPanel({ messages, onSendMessage, t }) {
  const [draft, setDraft] = useState("");

  const submit = (event) => {
    event.preventDefault();

    const message = draft.trim();

    if (!message) {
      return;
    }

    onSendMessage(message);
    setDraft("");
  };

  return (
    <section className="chat-panel">
      <h2>{t("chat.title")}</h2>
      <div className="chat-messages">
        {messages.length === 0 ? (
          <p className="chat-empty">{t("chat.empty")}</p>
        ) : (
          messages.map((message, index) => (
            <div
              key={`${message.author}-${index}`}
              className={`chat-message ${message.author === "me" ? "chat-me" : "chat-them"}`}
            >
              <span className="chat-message-author">
                {message.author === "me" ? t("chat.you") : t("chat.opponent")}
              </span>
              <p>{message.data?.text ?? ""}</p>
            </div>
          ))
        )}
      </div>
      <form className="chat-form" onSubmit={submit}>
        <input
          type="text"
          value={draft}
          onChange={(event) => setDraft(event.target.value)}
          placeholder={t("chat.placeholder")}
        />
        <button type="submit">{t("chat.send")}</button>
      </form>
    </section>
  );
}

export default ChatPanel;
