import React, { Component } from 'react';
import classNames from 'classnames/bind';

export default class Row extends Component {
  constructor(props) {
    super(props);
  }

  drawPieces(count, color, isTop, isHome) {
    const height = 250 / 15;
    const width = 50;
    const sideLength = 40;
    let svgs = [];

    for (let i = 0; i < count; i++) {
      let val = isHome ? i * height + 'px' : i * sideLength + 'px';
      let style = isTop ? { top: val } : { bottom: val };

      let svg = isHome ? (
        <svg key={i} height={height} width={width} style={style}>
          <rect
            height={height}
            width={width}
            stroke="black"
            strokeWidth="2"
            fill={color}
          />
        </svg>
      ) : (
        <svg key={i} height={sideLength} width={sideLength} style={style}>
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
      svgs.push(svg);
    }

    return svgs;
  }

  getSvgs(slot, isTop) {
    let svgs = [];
    if (slot.hasOwnProperty('num')) {
      svgs = this.drawPieces(slot.num, slot.owner, isTop, false);
    }
    return svgs;
  }

  getHomePieces(count, color, isTop) {
    let svgs = [];
    if (count > 0) {
      svgs = this.drawPieces(count, color, isTop, true);
    }
    return svgs;
  }

  getKnocked(count, color, isTop) {
    let svgs = [];
    if (count > 0) {
      svgs = this.drawPieces(count, color, isTop, false);
    }
    return svgs;
  }

  render() {
    const {
      isTop,
      color,
      selectedSlot,
      highlightedSlots,
      handler,
      moveHandler,
      moveHomeHandler,
      moveInHandler,
      homeCount,
      knockedCount,
      slots
    } = this.props;

    let isBlack = isTop ? false : true;

    let returnSlots = [];

    for (let i = 0; i < slots.length; i++) {
      let slot = slots[i];
      if (i == 6) {
        returnSlots.push(
          <td
            key={'knocked-' + color}
            onClick={moveInHandler}
            className="knocked"
          >
            {this.getKnocked(knockedCount, color, !isTop)}
          </td>
        );
      }
      let tdClasses = classNames(
        isBlack ? 'black' : '',
        slot.owner || '',
        selectedSlot == slot.idx || highlightedSlots.includes(slot.idx)
          ? 'highlighted'
          : ''
      );
      let clickHandler = highlightedSlots.includes(slot.idx)
        ? moveHandler
        : handler;
      returnSlots.push(
        <td
          key={slot.idx}
          data-index={slot.idx}
          onClick={clickHandler}
          className={tdClasses}
        >
          <div className="triangle" />
          {this.getSvgs(slot, isTop)}
        </td>
      );
      isBlack = !isBlack;
    }

    let homeClasses = classNames(
      'home',
      highlightedSlots.includes('home-' + color) ? 'highlighted' : ''
    );

    returnSlots.push(
      <td onClick={moveHomeHandler} key={isTop} className={homeClasses}>
        {this.getHomePieces(homeCount, color, isTop)}
      </td>
    );

    let rowClass = isTop ? 'top' : 'bottom';

    return <tr className={rowClass}>{returnSlots}</tr>;
  }
}
