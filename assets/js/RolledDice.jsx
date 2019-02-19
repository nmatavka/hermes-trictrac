import React, { Component } from 'react';
import Filler from './Filler';

class RolledDice extends Component {
  render() {
    const { dice } = this.props;
    let roll = <Filler />;
    if (dice.length > 0 && this.props.isYourTurn) {
      roll = <span>Your roll: {dice.join(' ')}</span>;
    } else if (dice.length > 0) {
      roll = <span>Your opponent rolled: {dice.join(' ')}</span>;
    }
    return roll;
  }
}

export default RolledDice;
