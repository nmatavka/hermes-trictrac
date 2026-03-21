import React from "react";
import Filler from "./Filler";
import Die from "./Die";

function RolledDice({ dice, isYourTurn }) {
  if (dice.length === 0) {
    return <Filler />;
  }

  return (
    <span>
      {isYourTurn ? "Your roll:" : "Your opponent rolled:"} <Die roll={dice} />
    </span>
  );
}

export default RolledDice;
