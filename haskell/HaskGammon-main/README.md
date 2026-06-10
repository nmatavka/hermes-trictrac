# HaskGammon README

## Overview
<img width="1829" height="1174" alt="image" src="https://github.com/user-attachments/assets/34c9d6bf-92e1-4582-8bbc-22d5ec954bb1" />

**HaskGammon** is a backgammon game implemented in Haskell, using the Gloss library for graphical rendering. This project showcases a simple, yet functional version of the classic board game, complete with basic gameplay mechanics such as dice rolling, player turns, and move validations.

## Features

- **Graphical Interface**: Utilizes the Gloss library to render the backgammon board and game elements.
- **Player Interaction**: Supports player moves via mouse clicks.
- **Dice Rolling**: Random dice generation using Haskell's random number library.
- **Move Validation**: Basic move validation ensuring adherence to backgammon rules.
- **Player Turns**: Alternating turns between two players, with visual indicators.

## Installation

To run HaskGammon, ensure you have the Haskell Platform installed. You can install Gloss using Cabal or Stack.

```sh
# Using Cabal
cabal update
cabal install gloss

# Using Stack
stack update
stack install gloss
```

## Usage

Clone the repository and navigate to the project directory:

```sh
git clone https://github.com/yourusername/haskgammon.git
cd haskgammon
```


Compile and run the project using Cabal or Stack:

```sh
# Using Cabal
cabal build
cabal run

# Using Stack
stack build
stack exec haskgammon-exe
```

## Code Structure

- **Main Module**: Contains the game setup, main loop, and event handling.
- **Environment Module**: Defines the game environment, including the board state and player positions.
- **Controller Module**: Manages game logic and player interactions.
- **Render Module**: Handles rendering of the game board and pieces using Gloss.
- **Graph Module**: Contains utility functions for graphical operations.
- **Options Module**: Includes game options and configurations.

## Key Functions

### Main Functions

- `main :: IO ()`: The entry point of the application, initializes the game and starts the main loop.
- `ioStack :: [Dice] -> HaskGammon`: Initializes the game state with dice rolls.
- `handleKeys :: Event -> HaskGammon -> HaskGammon`: Handles player input and updates the game state accordingly.
- `update :: Float -> HaskGammon -> HaskGammon`: Updates the game state on each frame (currently a placeholder).

### Game Logic

- `move :: HaskGammon -> (Float, Float) -> HaskGammon`: Manages player moves and updates the game state.
- `hit :: HaskGammon -> (Float, Float) -> HaskGammon`: Handles hit scenarios where a piece is sent to the bar.
- `updateEnv :: Int -> Int -> HaskGammon -> Environment`: Updates the game environment after a move.

## Future Improvements

- **Enhanced Move Validation**: Implement comprehensive validation for all backgammon rules.
- **AI Opponent**: Introduce an AI opponent for single-player mode.
- **Improved UI**: Enhance the graphical interface with more detailed visuals and animations.
- **Network Play**: Allow for online multiplayer functionality.

## Contributing

Contributions are welcome! Please fork the repository, create a feature branch, and submit a pull request with your changes.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Contact

For questions or suggestions, feel free to contact the project maintainer at [than@tuerkerhan.com](mailto:than@tuerkerhan.com).

---

Enjoy playing HaskGammon!
