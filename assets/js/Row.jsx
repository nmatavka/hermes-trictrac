import React from "react";
import classNames from "classnames";

function drawPieces(count, color, isTop, isHome) {
  const height = 250 / 15;
  const width = 50;
  const sideLength = 40;

  return Array.from({ length: count }, (_, index) => {
    const offset = isHome ? `${index * height}px` : `${index * sideLength}px`;
    const style = isTop ? { top: offset } : { bottom: offset };

    return isHome ? (
      <svg key={`${color}-home-${index}`} height={height} width={width} style={style}>
        <rect height={height} width={width} stroke="black" strokeWidth="2" fill={color} />
      </svg>
    ) : (
      <svg key={`${color}-piece-${index}`} height={sideLength} width={sideLength} style={style}>
        <circle cx="20" cy="20" r="18" stroke="black" strokeWidth="2" fill={color} />
      </svg>
    );
  });
}

function Row({
  isTop,
  color,
  playerColor,
  selectedSlot,
  highlightedSlots,
  onSelectSlot,
  onMoveSlot,
  onMoveHome,
  onMoveIn,
  homeCount,
  knockedCount,
  slots
}) {
  let isBlack = !isTop;
  const renderedSlots = [];

  slots.forEach((slot, index) => {
    if (index === 6) {
      renderedSlots.push(
        <td key={`knocked-${color}`} onClick={onMoveIn} className="knocked">
          {knockedCount > 0 ? drawPieces(knockedCount, color, !isTop, false) : null}
        </td>
      );
    }

    const isHighlighted = highlightedSlots.includes(slot.idx);
    const tdClasses = classNames(
      isBlack && "black",
      slot.owner,
      slot.owner === playerColor && "clickable",
      (selectedSlot === slot.idx || isHighlighted) && "highlighted"
    );

    renderedSlots.push(
      <td
        key={slot.idx}
        data-index={slot.idx}
        onClick={() => (isHighlighted ? onMoveSlot(slot.idx) : onSelectSlot(slot.idx))}
        className={tdClasses}
      >
        <div className="triangle" />
        {slot.num ? drawPieces(slot.num, slot.owner, isTop, false) : null}
      </td>
    );

    isBlack = !isBlack;
  });

  renderedSlots.push(
    <td
      onClick={onMoveHome}
      key={`home-${color}`}
      className={classNames("home", highlightedSlots.includes(`home-${color}`) && "highlighted")}
    >
      {homeCount > 0 ? drawPieces(homeCount, color, isTop, true) : null}
    </td>
  );

  return <tr className={isTop ? "top" : "bottom"}>{renderedSlots}</tr>;
}

export default Row;
