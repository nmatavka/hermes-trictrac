import React, { Component } from 'react';
import Opponent from './Opponent';
import WhoseTurn from './WhoseTurn';
import RollBtn from './RollBtn';
import RolledDice from './RolledDice';
import Winner from './Winner';

class Subheader extends Component {
  isYourTurn() {
    return this.props.state.whose_turn == this.props.playerColor;
  }

  render() {
    const { state, playerColor } = this.props;

    return (
      <div className="subheader-wrapper">
        <span>You are {playerColor}</span>
        <Opponent players={Object.keys(state.game.players)} />
        <WhoseTurn isYourTurn={this.isYourTurn()} />
        <RollBtn
          showBtn={
            state.game.current_dice.length == 0 &&
            this.isYourTurn() &&
            !state.winner
          }
          getRoll={this.getRoll}
        />
        <RolledDice
          dice={state.game.current_dice}
          isYourTurn={this.isYourTurn()}
        />
        <Winner winner={state.game.winner} playerColor={playerColor} />
      </div>
    );
  }
}

export default Subheader;
