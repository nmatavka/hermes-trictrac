import React, { Component } from 'react';

class WhoseTurn extends Component {
  render() {
    return this.props.isYourTurn ? (
      <span>It is your turn</span>
    ) : (
      <span>Waiting on opponent</span>
    );
  }
}

export default WhoseTurn;
