module Main where

import TimeFun
import Effects
import Pictures
import UIElements
import Components
import BackgammonGame
import Graphics.Gloss

window :: Display
window = InWindow "Backgammon Game" (screenWidth,screenHeight+40) (300,25)


main :: IO ()
main = play window backgroundColor 30 backgammonGame
                                      drawBoard 
                                      transformGame 
                                      (\time game -> checkWinner game)