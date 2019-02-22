import React, { Component } from 'react';
import Filler from './Filler';

class Winner extends Component {
  render() {
    const { winner, reset } = this.props;
    let winnerSpan = <Filler />;
    if (winner == this.props.playerColor) {
      winnerSpan = <span>You won!</span>;
    } else if (winner) {
      winnerSpan = <span>You lost!</span>;
    }
    let resetButton = <button onClick={reset}>Reset</button>;
    return <div>{winnerSpan} {resetButton}</div>;
  }
}

export default Winner;
