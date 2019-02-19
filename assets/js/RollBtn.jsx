import React, { Component } from 'react';
import Filler from './Filler';

class RollBtn extends Component {
  render() {
    return this.props.showBtn ? (
      <button onClick={this.props.getRoll}>Roll</button>
    ) : (
      <Filler />
    );
  }
}

export default RollBtn;
