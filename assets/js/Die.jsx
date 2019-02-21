import React, { Component } from 'react';
import Die1 from '../static/images/dice-six-faces-one.svg';
import Die2 from '../static/images/dice-six-faces-two.svg';
import Die3 from '../static/images/dice-six-faces-three.svg';
import Die4 from '../static/images/dice-six-faces-four.svg';
import Die5 from '../static/images/dice-six-faces-five.svg';
import Die6 from '../static/images/dice-six-faces-six.svg';

class Die extends Component {
  render() {
    const { roll } = this.props;

    let dice = [];

    for (let i = 0; i < roll.length; i++) {
      let source = '';
      switch (roll[i]) {
        case 1:
          source = Die1;
          break;
        case 2:
          source = Die2;
          break;
        case 3:
          source = Die3;
          break;
        case 4:
          source = Die4;
          break;
        case 5:
          source = Die5;
          break;
        case 6:
          source = Die6;
          break;
      }

      dice.push(<img className="die" key={i} src={source} />);
    }

    return dice;
  }
}

export default Die;
