import React, { useState } from "react";

function ChatPanel({ messages, onSendMessage }) {
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
      <h2>Chat</h2>
      <div className="chat-messages">
        {messages.length === 0 ? (
          <p className="chat-empty">No messages yet.</p>
        ) : (
          messages.map((message, index) => (
            <div
              key={`${message.author}-${index}`}
              className={`chat-message ${message.author === "me" ? "chat-me" : "chat-them"}`}
            >
              <span className="chat-message-author">
                {message.author === "me" ? "You" : "Opponent"}
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
          placeholder="Send a message"
        />
        <button type="submit">Send</button>
      </form>
    </section>
  );
}

export default ChatPanel;
