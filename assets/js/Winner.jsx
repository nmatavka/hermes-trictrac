import React, { Component } from 'react';
import Filler from './Filler';

class Winner extends Component {
  render() {
    const { winner } = this.props;
    let winnerSpan = <Filler />;
    if (winner == this.props.playerColor) {
      winnerSpan = <span>You won!</span>;
    } else if (winner) {
      winnerSpan = <span>You lost!</span>;
    }
    return winnerSpan;
  }
}

export default Winner;
