import React from "react";
import Filler from "./Filler";

function RollBtn({ showBtn, getRoll }) {
  return showBtn ? <button onClick={getRoll}>Roll</button> : <Filler />;
}

export default RollBtn;
