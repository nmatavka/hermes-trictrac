import React, { Component } from 'react';
import ReactDOM from 'react-dom';
import Row from './Row';
import Subheader from './Subheader';
import _ from 'lodash';
import { Launcher } from 'react-chat-window';

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
      highlightedSlots: [],
      messageList: []
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

  getRoll() {
    this.channel.push('roll');
  }

  isAllowedToMove() {
    return this.state.game.whose_turn == this.props.playerColor;
  }

  getTd(td) {
    return td.tagName == 'svg' || td.tagName == 'rect' ? td.parentNode : td;
  }

  getMoveTaken(moveTo) {
    return this.state.game.possible_moves.filter(
      move => move.from == this.state.selectedSlot && move.to == moveTo
    )[0];
  }

  moveAndClearSlot(moveTaken) {
    if (moveTaken) {
      this.channel.push('move', {
        move: moveTaken
      });
    }
    this.setState({ selectedSlot: null, highlightedSlots: [] });
  }

  isHighlighted(td) {
    return td.classList.contains('highlighted');
  }

  moveHome(e) {
    if (this.isAllowedToMove()) {
      let td = this.getTd(this.getTd(e.target));
      if (this.isHighlighted(td)) {
        this.moveAndClearSlot(this.getMoveTaken('home'));
      }
    }
  }

  makeMove(e) {
    if (this.isAllowedToMove()) {
      let td = this.getTd(e.target.parentNode);
      if (this.isHighlighted(td)) {
        this.moveAndClearSlot(this.getMoveTaken(td.dataset.index));
      }
    }
  }

  moveIn() {
    if (this.isAllowedToMove()) {
      let moves = [];
      for (let i = 0; i < this.state.game.possible_moves.length; i++) {
        moves.push(this.state.game.possible_moves[i].to);
      }
      this.setState({ selectedSlot: 'knocked', highlightedSlots: moves });
    }
  }

  selectSlot(e) {
    if (this.isAllowedToMove() && this.state.game.current_dice.length > 0) {
      let td = this.getTd(e.target.parentNode);
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

  _onMessageWasSent(message) {
    // TODO change this
    this.setState({
      messageList: [...this.state.messageList, message]
    });
  }

  _sendMessage(text) {
    if (text.length > 0) {
      // TODO change this
      this.setState({
        messageList: [
          ...this.state.messageList,
          {
            author: 'them',
            type: 'text',
            data: { text }
          }
        ]
      });
    }
  }

  render() {
    const { playerColor } = this.props;

    let firstTwelveSlots = this.state.game.slots.slice(0, 12).reverse();
    let lastTwelveSlots = this.state.game.slots.slice(12, 24);

    let topSlots = playerColor == 'white' ? firstTwelveSlots : lastTwelveSlots;
    let bottomSlots =
      playerColor == 'white' ? lastTwelveSlots : firstTwelveSlots;

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
        <Launcher
          agentProfile={{
            teamName: 'Backgammon Chat'
          }}
          onMessageWasSent={this._onMessageWasSent.bind(this)}
          messageList={this.state.messageList}
          showEmoji
        />
      </div>
    );
  }
}
