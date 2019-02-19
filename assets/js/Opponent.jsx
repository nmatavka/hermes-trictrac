import React, { Component } from 'react';

class Opponent extends Component {
  render() {
    const { players } = this.props;
    let opponent = null;
    if (players.length < 2) {
      opponent = <span>Waiting for opponent to join</span>;
    } else {
      let name = players.filter(player => {
        return player != window.userName;
      })[0];
      opponent = <span>Your opponent is: {name}</span>;
    }
    return opponent;
  }
}

export default Opponent;
