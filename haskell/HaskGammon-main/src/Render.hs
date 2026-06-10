module Render where

import Graphics.Gloss
import Graph
import Options
import Data.Type.Equality (outer)
import Environment
import Data.List (inits)
import Graph (drawEnvironment)





render :: HaskGammon -> Picture
render world = pictures $ board  ++ [rollButton world , diceDisplay world, movesDisplay world, turnDisplay world, startDiceDisplayWhite world, startDiceDisplayRed world, hitsRDisplay world, hitsWDisplay world] ++ drawPoints world ++ drawEnvironment (env world) ++ [sceneDisplay world, selectedDp world]


