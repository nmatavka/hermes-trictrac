import React from "react";

function Opponent({ players, playerName }) {
  if (players.length < 2) {
    return <span>Waiting for opponent to join</span>;
  }

  const opponent = players.find((player) => player !== playerName);

  return <span>Your opponent is: {opponent}</span>;
}

export default Opponent;
