import React, { Component } from 'react';
import Opponent from './Opponent';
import WhoseTurn from './WhoseTurn';
import RollBtn from './RollBtn';
import RolledDice from './RolledDice';
import Winner from './Winner';

class Subheader extends Component {
  isYourTurn() {
    return (
      this.props.state.game.whose_turn == this.props.playerColor &&
      !this.props.state.game.winner
    );
  }

  render() {
    const { state, playerColor, reset } = this.props;

    return (
      <div className="subheader-wrapper">
        <span>You are {playerColor}</span>
        <Opponent players={Object.keys(state.game.players)} />
        <WhoseTurn
          isYourTurn={this.isYourTurn()}
          isGameOver={state.game.winner}
        />
        <RollBtn
          showBtn={state.game.current_dice.length == 0 && this.isYourTurn()}
          getRoll={this.props.getRoll}
        />
        <RolledDice
          dice={state.game.current_dice}
          isYourTurn={this.isYourTurn()}
        />
        <Winner
          winner={state.game.winner}
          playerColor={playerColor}
          reset={reset}
        />
      </div>
    );
  }
}

export default Subheader;
