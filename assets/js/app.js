// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import css from "../css/app.css"

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import dependencies
//
import "phoenix_html"

// Import local files
//
// Local files can be imported directly using relative paths, for example:
// import socket from "./socket"

import socket from "./socket";
import gameInit from "./Backgammon";
import $ from 'jquery';

$(() => {
  let root = document.getElementById('root');
  if (root) {
    // console.log(window.gameName);
    // console.log(window.userName);
    let channel = socket.channel("games:" + window.gameName, {
      "user": window.userName
    });
    gameInit(root, channel, window.userName);
  }

  $(".submit").on('click', function () {
    window.location.href += ("game/" + $("#game").val());
  });

  $("#name").on('change', function () {
    window.userName = $(this).val();
    console.log(window.userName);
  });
});