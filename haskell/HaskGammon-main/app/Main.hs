module Main where


import Options 
import Graphics.Gloss
import Data.List
import Data.Type.Equality
import System.Random
import Render
import Graph
import Environment
import Controller


import Graphics.Gloss.Interface.IO.Game
import Data.Maybe (fromJust, isNothing, isJust)
import Stack

--------------------------------------------------------------------------------
-- Setup GLUT and OpenGL, drop into the event loop.
--------------------------------------------------------------------------------


ioStack :: [Dice] -> HaskGammon
ioStack roll =
    Stack {
    dice           = Nothing,
    moves          = [],
    startDiceWhite = Nothing,
    startDiceRed   = Nothing,
    firstPlayer    = Nothing,
    secondPlayer   = Nothing,
    scene          = Start1,
    turn           = White,
    selectedPawn   = Nothing ,
    env            = Env [
    (0,  2, Just Red),
    (1,  0, Nothing ),
    (2,  0, Nothing ),
    (3,  0, Nothing ),
    (4,  0, Nothing ),
    (5,  5, Just White),
    (6,  0, Nothing ),
    (7,  3, Just White),
    (8,  0, Nothing ),
    (9,  0, Nothing ),
    (10, 0, Nothing ),
    (11, 5, Just Red),
    (12, 5, Just White),
    (13, 0, Nothing ),
    (14, 0, Nothing ),
    (15, 0, Nothing ),
    (16, 3, Just Red),
    (17, 0, Nothing ),
    (18, 5, Just Red),
    (19, 0, Nothing ),
    (20, 0, Nothing ),
    (21, 0, Nothing ),
    (22, 0, Nothing ),
    (23, 2, Just White)
    ],
    rollNumber     = 0,
    rolls          = roll,
    hitsR =0,
    hitsW =0
}


myDices :: IO [Dice]
myDices = listToDice Prelude.<$>rand 100 []

rand :: Int -> [Int] -> IO [Int]
rand n rlst = do
    num <- randomRIO (1::Int, 6)
    if n == 0
        then return rlst
        else rand (n-1) (num:rlst)

main :: IO ()
main = do
    roll <- myDices
    play window background fps (ioStack roll) render handleKeys update


window :: Display
window = FullScreen

update :: Float -> HaskGammon -> HaskGammon
update s world = world


handleKeys :: Event -> HaskGammon -> HaskGammon
handleKeys (EventKey (MouseButton LeftButton) Up _ (x, y)) world    = case scene world of
    Start1      -> if isRoll (x,y) then world {
        dice           = Just (rolls world !! rollNumber world),
        startDiceWhite = Just $ rolls world !! rollNumber world,
        turn           = Red,
        scene          = Start2
    }{rollNumber   = rollNumber world +1} else world
    Start2      -> if isRoll (x,y) then (world {
        dice         = Just (rolls world !! rollNumber world),
        startDiceRed = Just $ rolls world !! rollNumber world,
        turn  = if (startDiceWhite world == Just (rolls world !! rollNumber world)) || (sumDice' (rolls world !! rollNumber world) < sumDice world startDiceWhite) then White else Red,
        scene = if startDiceWhite world == Just (rolls world !! rollNumber world)
            then Start1 else (if sumDice' (rolls world !! rollNumber world) < sumDice world startDiceWhite
                    then Roll White
                    else Roll Red)
    })  {rollNumber   = rollNumber world +1}else world
    Roll player -> if isRoll (x,y) then world {
                   dice       = Just (rolls world !! rollNumber world),
                   rollNumber = rollNumber world +1,
                   moves      = genMoves (rolls world !! rollNumber world),
                   turn       = player,
                   scene      = Play player} else world
    Play player -> move world (x,y)

handleKeys _ world = world

move :: HaskGammon -> (Float, Float) -> HaskGammon
move world (x,y) | isJust (whichOne world (x,y)) = if (Just (turn world) == getPawn (getFromEnv world (fromJust (whichOne world (x,y))))) then world {
                     selectedPawn = whichOne world (x,y)
                 }else world
                 | isJust (whichPoint world (x,y)) = if null $ move' world (fromJust (whichPoint world (x,y)))
                     then (hit world (x,y)){
                         env   = updateEnv (fromJust (selectedPawn world)) (fromJust (whichPoint world (x,y))) world,
                         moves = move' world (fromJust (whichPoint world (x,y))),
                         turn = counter (turn world), scene = Roll (counter (turn world)),
                         dice = Nothing
                         }
                     else (hit world (x,y)) {
                     env   = updateEnv (fromJust (selectedPawn world)) (fromJust (whichPoint world (x,y))) world,
                     moves = move' world (fromJust (whichPoint world (x,y)))
                 }
                 | otherwise = world


hit :: HaskGammon -> (Float,Float) -> HaskGammon
hit world (x,y) | isNothing (whichPoint world (x,y)) = world
                | turn world == Red && getPawn (getFromEnv world (fromJust (whichPoint world (x,y)))) == Just White && 1 == getCount (getFromEnv world (fromJust (whichPoint world (x,y)))) = world {hitsW = (hitsW world)+1}
                | turn world == White && getPawn (getFromEnv world (fromJust (whichPoint world (x,y)))) == Just Red && 1 == getCount (getFromEnv world (fromJust (whichPoint world (x,y)))) = world {hitsR = (hitsR world)+1}
                | otherwise  = world

updateEnv :: Int -> Int -> HaskGammon -> Environment -- tested
updateEnv rdc apd world = append apd (reduce rdc (env world)) where
                reduce :: Int -> Environment -> Environment
                reduce addr (Env ls) = Env $ take addr ls ++ [reduce' (ls !! addr) (turn world)] ++ drop (addr+1) ls
                reduce' :: (Int,Int, Maybe Player) -> Player -> (Int,Int, Maybe Player)
                reduce' (a,b,c) player | b <= 0    = (a,0,Nothing)
                                       | b == 1    = (a,0,Nothing)
                                       | otherwise = (a,b-1,Just player)

                append :: Int -> Environment -> Environment
                append addr (Env ls) = Env $ take addr ls ++ [append' (ls !! addr) (turn world)] ++ drop (addr+1) ls
                append' :: (Int,Int, Maybe Player) -> Player -> (Int,Int, Maybe Player)
                append' (a,b,Nothing) player    = (a,b+1, Just player)
                append' (a,1,Just player) turn' = if counter player == turn' then (a,1,Just turn') else (a,2,Just player)
                append' (a,b,Just player) _     = (a,b+1,Just player)