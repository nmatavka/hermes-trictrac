import React from "react";
import Filler from "./Filler";

function Winner({ winner, playerColor, reset }) {
  let winnerSpan = <Filler />;

  if (winner === playerColor) {
    winnerSpan = <span>You won!</span>;
  } else if (winner) {
    winnerSpan = <span>You lost!</span>;
  }

  return (
    <div>
      {winnerSpan} {winner ? <button onClick={reset}>Reset</button> : <span />}
    </div>
  );
}

export default Winner;
