import React from "react";
import Die1 from "../static/images/dice-six-faces-one.svg";
import Die2 from "../static/images/dice-six-faces-two.svg";
import Die3 from "../static/images/dice-six-faces-three.svg";
import Die4 from "../static/images/dice-six-faces-four.svg";
import Die5 from "../static/images/dice-six-faces-five.svg";
import Die6 from "../static/images/dice-six-faces-six.svg";

const diceImages = {
  1: Die1,
  2: Die2,
  3: Die3,
  4: Die4,
  5: Die5,
  6: Die6
};

function Die({ roll }) {
  return roll.map((value, index) => (
    <img className="die" key={`${value}-${index}`} src={diceImages[value]} alt={`Die showing ${value}`} />
  ));
}

export default Die;
