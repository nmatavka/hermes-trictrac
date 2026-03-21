import React from "react";
import Filler from "./Filler";

function WhoseTurn({ isYourTurn, isGameOver }) {
  if (isGameOver) {
    return <Filler />;
  }

  return <span>{isYourTurn ? "It is your turn" : "Waiting on opponent"}</span>;
}

export default WhoseTurn;
