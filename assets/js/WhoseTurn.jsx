import React, { Component } from 'react';
import Filler from './Filler';

class WhoseTurn extends Component {
  render() {
    let whoseTurn = <Filler />;
    if (this.props.isYourTurn && !this.props.isGameOver) {
      whoseTurn = <span>It is your turn</span>;
    } else if (!this.props.isGameOver) {
      whoseTurn = <span>Waiting on opponent</span>;
    }
    return whoseTurn;
  }
}

export default WhoseTurn;
