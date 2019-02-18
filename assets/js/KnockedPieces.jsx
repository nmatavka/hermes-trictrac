import React, { Component } from 'react';

export default class KnockedPieces extends Component {
  constructor(props) {
    super(props);
  }

  drawPieces(count, totalCount, color, piecesArray) {
    let sideLength = 40;
    for (let i = 0; i < count; i++) {
      let style = { left: totalCount * sideLength + 'px' };
      piecesArray.push(
        <svg
          key={totalCount}
          height={sideLength}
          width={sideLength}
          style={style}
        >
          <circle
            cx="20"
            cy="20"
            r="18"
            stroke="black"
            strokeWidth="2"
            fill={color}
          />
        </svg>
      );
      totalCount++;
    }
  }

  render() {
    let whitePieces = [];
    let redPieces = [];
    let totalCount = 0;

    if (this.props.knocked.white > 0) {
      this.drawPieces(
        this.props.knocked.white,
        totalCount,
        'white',
        whitePieces
      );
      totalCount += this.props.knocked.white;
    }
    if (this.props.knocked.red > 0) {
      this.drawPieces(this.props.knocked.red, totalCount, 'red', redPieces);
    }

    let allPieces = whitePieces.concat(redPieces);

    return (
      <div onClick={this.props.moveIn} className="knocked-container">
        {allPieces}
      </div>
    );
  }
}
