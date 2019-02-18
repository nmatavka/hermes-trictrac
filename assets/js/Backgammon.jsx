import React, { Component } from 'react';
import ReactDOM from 'react-dom';
import Row from './Row';
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

      this.channel.push('move', {
        move: moveTaken
      });
      this.setState({ selectedSlot: null, highlightedSlots: [] });
    }
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

        this.channel.push('move', {
          move: moveTaken
        });
        this.setState({ selectedSlot: null, highlightedSlots: [] });
      }
    }
  }

  selectSlot(e) {
    if (this.state.game.whose_turn == this.props.playerColor) {
      let td = e.target.parentNode;
      if (td.tagName == 'svg') {
        td = td.parentNode;
      }
      let idx = td.dataset.index;

      if (td.classList.contains(this.props.playerColor)) {
        if (this.state.selectedSlot == idx) {
          this.setState({ selectedSlot: null, highlightedSlots: [] });
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

    let filler = <span className="empty" />;
    let yourTurn =
      this.state.game.whose_turn == playerColor ? (
        <span>It is your turn</span>
      ) : (
        <span>Waiting on opponent</span>
      );

    let yourRoll = filler;
    if (
      this.state.game.current_dice.length > 0 &&
      this.state.game.whose_turn == playerColor
    ) {
      yourRoll = (
        <span>Your roll: {this.state.game.current_dice.join(' ')}</span>
      );
    } else if (this.state.game.current_dice.length > 0) {
      yourRoll = (
        <span>
          Your opponent rolled: {this.state.game.current_dice.join(' ')}
        </span>
      );
    }

    let rollBtn =
      this.state.game.current_dice.length == 0 &&
      this.state.game.whose_turn == playerColor ? (
        <button onClick={this.getRoll}>Roll</button>
      ) : (
        filler
      );

    let winner = filler;
    if (this.state.game.winner == this.props.playerColor) {
      winner = <span>You won!</span>;
    } else if (this.state.game.winner) {
      winner = <span>You lost!</span>;
    }

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
        <div className="subheader-wrapper">
          <span>You are {playerColor}</span>
          {yourTurn}
          {rollBtn}
          {yourRoll}
          {winner}
        </div>
        <table>{rows}</table>
      </div>
    );
  }
}
