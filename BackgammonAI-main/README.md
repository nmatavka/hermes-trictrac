# BackgammonAI

## About The Project

This is a project that allows the user to play Backgammon (using ASCII characters in the terminal) against an AI or another player from the same machine.

## Features

- **Full Backgammon implementation**: The full game of Backgammon with all of its standard rules have been implemented.
- **AI opponent**: The AI makes use of the Alpha-beta pruning algorithm in order to choose the best move to play.
- **Human opponent**: Users can opt to play against another human opponent on the same machine.

## How to Use

When running the executable, players will be prompted to choose from one of the following options:
- **1. Play a game against another person from the same machine**
- **2. Play a game against an AI that plays the best moves**
- **3. Settings**
- **4. Exit**

When either the first or the second options are chosen, a game of Backgammon will start. If both the players are human, then their names will be the ones that they chose in the `Settings` tab. The initial board of Backgammon looks like this:

```
============== BACKGAMMON BOARD ==============

13  14  15  16  17  18  19  20  21  22  23  24
W | - | - | - | B | - || B | - | - | - | - | W
W | - | - | - | B | - || B | - | - | - | - | W
W | - | - | - | B | - || B | - | - | - | - | -
W | - | - | - | - | - || B | - | - | - | - | -
W | - | - | - | - | - || B | - | - | - | - | -
==============================================
B | - | - | - | - | - || W | - | - | - | - | -
B | - | - | - | - | - || W | - | - | - | - | -
B | - | - | - | W | - || W | - | - | - | - | -
B | - | - | - | W | - || W | - | - | - | - | B
B | - | - | - | W | - || W | - | - | - | - | B
12  11  10   9   8   7   6   5   4   3   2   1

==============================================
```

The current player will then roll 2 dice, which will then be shown as:

```
Player rolled:
Dice 1: 1
Dice 2: 5

What would you like to do?
1. Move one checker 1 spaces and the other 5 spaces
2. Move one checker 6 spaces
```

After the player chooses one of the two options, they will be able to choose the column of the piece(s) they would like to move. After the board is modified, the game continues until one of the players has beared off all of their pieces.

If the player chooses to play against an AI, the moves will not be played automatically. Instead, the AI will only print the best moves, but any other move can be played.

## Prerequisites

To run the BackgammonAI, you'll need:

- **Elixir 1.12+** (https://elixir-lang.org/install.html)
- **Erlang/OTP 24+** (comes with Elixir installation)

## Usage 

1. **Clone the repository**
```bash
git clone https://github.com/Dio1000/BackgammonAI.git
```

2. **Navigate to the project directory**
```bash
cd BackgammonAI
```

3. **Run the game**
```bash
elixir main.exs
```

After that, you can follow the on-screen prompts which are also listed at the `How to Use` section.

## Contact

Darian Sandru - sandru.darian@gmail.com

Project Link: [https://github.com/Dio1000/BackgammonAI](https://github.com/Dio1000/BackgammonAI)

