import React, { Component } from 'react';
import ReactDOM from 'react-dom';
import Row from './Row';
import Subheader from './Subheader';
import _ from 'lodash';

export default function gameInit(root, channel, name) {
  channel
    .join()
    .receive('ok', resp => {
      console.log('Joined successfully', resp);
      ReactDOM.render(
        <Backgammon
          playerColor={resp.game.color}
          resp={resp}
          channel={channel}
        />,
        root
      );
    })
    .receive('error', resp => {
      console.log('Unable to join', resp);
    });
}

class Backgammon extends Component {
  constructor(props) {
    super(props);
    this.channel = props.channel;
    this.state = {
      game: props.resp.game,
      selectedSlot: null,
      highlightedSlots: []
    };

    this.selectSlot = this.selectSlot.bind(this);
    this.getRoll = this.getRoll.bind(this);
    this.makeMove = this.makeMove.bind(this);
    this.moveIn = this.moveIn.bind(this);
    this.moveHome = this.moveHome.bind(this);

    this.channel.on('update', resp => {
      this.update(resp);
    });
  }

  update(response) {
    console.log(response);
    this.setState({ game: response.game });
  }

  moveIn() {
    if (this.state.game.whose_turn == this.props.playerColor) {
      let moves = [];
      for (let i = 0; i < this.state.game.possible_moves.length; i++) {
        moves.push(this.state.game.possible_moves[i].to);
      }
      this.setState({ selectedSlot: 'knocked', highlightedSlots: moves });
    }
  }

  getRoll() {
    this.channel.push('roll');
  }

  moveHome(e) {
    let td = e.target;
    if (td.tagName == 'svg' || td.tagName == 'rect') {
      td = td.parentNode;
    }
    if (td.tagName == 'svg') {
      td = td.parentNode;
    }

    if (td.classList.contains('highlighted')) {
      let moveTaken = this.state.game.possible_moves.filter(
        move => move.from == this.state.selectedSlot && move.to == 'home'
      )[0];

      this.moveAndClearSlot(moveTaken);
    }
  }

  moveAndClearSlot(moveTaken) {
    if (moveTaken) {
      this.channel.push('move', {
        move: moveTaken
      });
    }
    this.setState({ selectedSlot: null, highlightedSlots: [] });
  }

  makeMove(e) {
    if (this.state.game.whose_turn == this.props.playerColor) {
      let td = e.target.parentNode;
      if (td.tagName == 'svg') {
        td = td.parentNode;
      }

      if (td.classList.contains('highlighted')) {
        let moveTaken = this.state.game.possible_moves.filter(
          move =>
            move.from == this.state.selectedSlot && move.to == td.dataset.index
        )[0];
        this.moveAndClearSlot(moveTaken);
      }
    }
  }

  selectSlot(e) {
    if (
      this.state.game.whose_turn == this.props.playerColor &&
      this.state.game.current_dice.length > 0
    ) {
      let td = e.target.parentNode;
      if (td.tagName == 'svg') {
        td = td.parentNode;
      }
      let idx = td.dataset.index;

      if (td.classList.contains(this.props.playerColor)) {
        if (this.state.selectedSlot == idx) {
          this.moveAndClearSlot(null);
        } else {
          let moves = [];
          for (let i = 0; i < this.state.game.possible_moves.length; i++) {
            let move = this.state.game.possible_moves[i];
            if (move.from == idx) {
              let dest =
                move.to == 'home' ? 'home-' + this.props.playerColor : move.to;
              moves.push(dest);
            }
          }
          this.setState({
            selectedSlot: idx,
            highlightedSlots: moves
          });
        }
      }
    }
  }

  render() {
    const { playerColor } = this.props;

    let topSlots =
      playerColor == 'white'
        ? this.state.game.slots.slice(0, 12).reverse()
        : this.state.game.slots.slice(12, 24);
    let bottomSlots =
      playerColor == 'white'
        ? this.state.game.slots.slice(12, 24)
        : this.state.game.slots.slice(0, 12).reverse();

    let topColor = playerColor == 'white' ? 'red' : 'white';

    let rows = (
      <tbody>
        <Row
          isTop={true}
          color={topColor}
          playerColor={playerColor}
          selectedSlot={this.state.selectedSlot}
          highlightedSlots={this.state.highlightedSlots}
          handler={this.selectSlot}
          moveHandler={this.makeMove}
          moveHomeHandler={this.moveHome}
          homeCount={this.state.game.home[topColor]}
          knockedCount={this.state.game.knocked[topColor]}
          slots={topSlots}
        />
        <Row
          isTop={false}
          color={playerColor}
          playerColor={playerColor}
          selectedSlot={this.state.selectedSlot}
          highlightedSlots={this.state.highlightedSlots}
          handler={this.selectSlot}
          moveHandler={this.makeMove}
          moveHomeHandler={this.moveHome}
          moveInHandler={this.moveIn}
          homeCount={this.state.game.home[playerColor]}
          knockedCount={this.state.game.knocked[playerColor]}
          slots={bottomSlots}
        />
      </tbody>
    );

    return (
      <div>
        <Subheader
          state={this.state}
          playerColor={playerColor}
          getRoll={this.getRoll}
        />
        <table>{rows}</table>
      </div>
    );
  }
}
