import React from "react";
import Opponent from "./Opponent";
import WhoseTurn from "./WhoseTurn";
import RollBtn from "./RollBtn";
import RolledDice from "./RolledDice";
import Winner from "./Winner";

function Subheader({ game, playerColor, playerName, isYourTurn, getRoll, reset }) {
  return (
    <div className="subheader-wrapper">
      <span>You are {playerColor}</span>
      <Opponent players={Object.keys(game.players)} playerName={playerName} />
      <WhoseTurn isYourTurn={isYourTurn} isGameOver={game.winner} />
      <RollBtn showBtn={game.current_dice.length === 0 && isYourTurn} getRoll={getRoll} />
      <RolledDice dice={game.current_dice} isYourTurn={isYourTurn} />
      <Winner winner={game.winner} playerColor={playerColor} reset={reset} />
    </div>
  );
}

export default Subheader;
