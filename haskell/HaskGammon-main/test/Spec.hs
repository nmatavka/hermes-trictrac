import Environment
import Stack



main :: IO ()
main = print test

test = isPlayable' testStack 0 5

testStack = 
    Stack {
    dice           = Just $ Dice(1,2),
    moves          = [("first",1),("second",5),("both",6)],
    startDiceWhite = Nothing,
    startDiceRed   = Nothing,
    firstPlayer    = Nothing,
    secondPlayer   = Nothing,
    scene          = Play Red,
    turn           = Red,
    selectedPawn   = Just 0,
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
    rolls          = [],
    hitsR =0,
    hitsW =0
}