import React, { Component } from 'react';
import Filler from './Filler';
import Die from './Die';

class RolledDice extends Component {
  render() {
    const { dice } = this.props;
    let roll = <Filler />;
    if (dice.length > 0 && this.props.isYourTurn) {
      roll = (
        <span>
          Your roll: <Die roll={dice} />
        </span>
      );
    } else if (dice.length > 0) {
      roll = <span>Your opponent rolled: {dice.join(' ')}</span>;
    }
    return roll;
  }
}

export default RolledDice;
