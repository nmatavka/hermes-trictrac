module Main where

import MyLib
    ( charToInt, exists, inv, myArray, removeOneOccurence, takeRange )
import Graphics.Gloss
import Graphics.Gloss.Interface.Pure.Game
import qualified Data.Char as MyLib


-- | Represents a sequence of moves (in their order) made by ONE PLAYER in ONE TURN
-- | Each elements in the sequence represents one move and consists of pair of integers
-- | Let the pair be (X, Y)
-- | X: Represents the index of the triangle from where the character to be moved is chosen.
-- | Y: Represents the number of forward points of which the character to be moved.
-- | The sequence can be of of three different sizes (1,2 , 4)
type Move = [(Int, Int)]


-- | The first integer represnts the color of pieces in this triangle it can be 0 or 1
-- | The Second integer represents the number of pieces in this triangle from it can be from 0 to 15
-- | The last integer represents "mahbousa" it can be 1 if this triangle contains one piece of the other color which cannot move and 0 otherwise
type GameTriangle = (Int, Int, Int, Char)
data State = ChooseSteps | Moving
    deriving (Eq, Show)

data GameState = ThrowDice | Play
    deriving (Eq, Show)

-- | the dirction of triangles and pieces
data Direction = Upward | Downward

-- | dices : the values of the dices in the current turn
-- | turn  : can be either 0 or 1
-- | triangles : the state of triangAvailableles according to the player who will play in this turn. it has exactly 24 elements.
-- | availableMoves : all valid sequence of moves that the player can play in this turn according to state of the game.
data World = World {
    dices :: (Int, Int),
    turn :: Int,
    triangles :: [GameTriangle],
    availableMoves :: [Int],
    randoms :: [Int],
    bearingOff :: Bool,
    state :: State,
    finished :: Bool,
    choosedSteps :: Int
} deriving (Eq, Show)

data BackGammonGame = BackGammonGame {
    curWorld :: World,
    gameState :: GameState
} deriving (Eq, Show)

data Mode = Multi | Solo
    deriving (Eq, Show)

data MultiPlayerGame = MultiPlayerGame {
    curGame :: BackGammonGame ,
    curMode :: Maybe Mode
} deriving (Eq, Show)

main :: IO ()
main = backGammon

backGammon :: IO ()
backGammon = play
    (InWindow "Backgammon" (1200, 1000) (100, 100))
    white
    100
    initialInterface
    drawGame
    handleGame
    (\_ world -> world)

initialTriangles :: [(Int, Int, Int, Char)]
initialTriangles = zipWith (\(a, b, c) y -> (a, b, c, y)) ret ['a'..'x']
    where
        ret = [(1, 15, 0)] ++ replicate 22 (0, 0, 0) ++ [(0, 15, 0)]

initialWorld :: World
initialWorld = World (-1, -1) 0 initialTriangles [] MyLib.myArray False ChooseSteps False (-1)

initialState :: BackGammonGame
initialState = BackGammonGame initialWorld ThrowDice

initialInterface :: MultiPlayerGame
initialInterface = MultiPlayerGame initialState Nothing

points :: [(Float, Float)]
points  = [(-400,175) ,(-400,350), (350, 350), (350, 175), (-400,175)]

welcomingInterface :: Picture
welcomingInterface = line points <> translate (-370) 225 (Text "MultiePlayer")
    <>  translate (-150) (-90) (Text "Solo") <> translate 0 (-300) (line points)

drawGame :: MultiPlayerGame -> Picture
drawGame (MultiPlayerGame myGame Nothing) = welcomingInterface
drawGame (MultiPlayerGame myGame (Just Solo)) = drawBoard myGame
drawGame (MultiPlayerGame myGame (Just Multi)) = drawBoard myGame

insideRectangle :: (Float, Float) -> Bool
insideRectangle (x, y) = x >= (-400) && x <= 350 && y <= 350 && y >= 175

handleGame :: Event -> MultiPlayerGame -> MultiPlayerGame
handleGame (EventKey (MouseButton LeftButton) Down _ (x, y)) (MultiPlayerGame g Nothing)
    | insideRectangle (x, y)        = MultiPlayerGame g (Just Multi)
    | insideRectangle (x, y + 300)  = MultiPlayerGame g (Just Solo)
    | otherwise = MultiPlayerGame g Nothing
handleGame event (MultiPlayerGame g Nothing) = MultiPlayerGame g Nothing
handleGame event (MultiPlayerGame g (Just Multi)) = MultiPlayerGame (handleInput True event g) (Just Multi)
handleGame event (MultiPlayerGame g (Just Solo))  = MultiPlayerGame (handleInput False event g) (Just Solo)

-- | Render the State of the Game.
drawBoard :: BackGammonGame -> Picture
drawBoard myGame
    | isFinished = translate (-330) 0 $ Text (player ++ " Won!")
    | otherwise = translate (-330) 220
        (dice <> table <> downwardTriangles <> shiftedUpwardTriangles <> allTextPic)
    where
        world = curWorld myGame
        isFinished = finished world
        curTurn = turn world
        player = if curTurn == 0 then "White" else "Black"

        len = length (triangles world)
        get player = if player == 0 then "White" else "Black"
        height = 500
        break = 20
        downwardTriangles = half1Downwards <> translate (50*6 + break) 0 half2Downwards
        upwardTriangles =  half1Upwards <> translate (-50*6 - break) 0 half2Upwards
        quarter = len `div` 4
        table = translate (50 * fromIntegral quarter + 10) (-height/2) (Color brown $ rectangleSolid (50*(fromIntegral quarter * 2) + break) 500)
        brown = makeColor 0.4375 0.30859375 0.1640625 1.0

        half1Downwards = drawGameTriangles (take quarter (reverse (triangles world))) Downward
        half1Upwards = drawGameTriangles (MyLib.takeRange (quarter * 2) (quarter * 3 - 1) (reverse (triangles world))) Upward

        half2Downwards = drawGameTriangles (MyLib.takeRange quarter (quarter * 2 - 1) (reverse (triangles world))) Downward
        half2Upwards = drawGameTriangles (MyLib.takeRange (quarter * 3) len (reverse (triangles world))) Upward

        shiftedUpwardTriangles = translate (50*(fromIntegral quarter * 2 - 1) + break) (-height) upwardTriangles
        dice = scale 0.5 0.5 $ translate 900 150 $
            if fst (dices world) /= (-1) && gameState myGame /= ThrowDice then Text (show $ dices world) else blank

        chooseStepsText = scale 0.2 0.2 $
            Text "Please select on of these steps values by pressing the numbers on your keyboard!"
        renderAv e = scale 0.2 0.2 $ Text $ show e
        (myPic, _) = foldl (\(pic, i) e -> (pic <> translate (i*50) 0 (renderAv e), i + 1)) (blank, 0) $ availableMoves world
        chooseStepsPic = if state world == ChooseSteps && gameState myGame /= ThrowDice then
            translate (-200) 200 chooseStepsText <> translate 0 160 myPic
                else blank

        throwDiceText = scale 0.2 0.2 $
            Text "Press enter to throw the dice!"
        throwDicePic = translate 0 150 $ if gameState myGame == ThrowDice then throwDiceText else blank

        playerTurnText = scale 0.4 0.4 $ Text (player ++ " plays")
        playerTurnPic  = translate 0 (-600) playerTurnText

        chooseMoveText = scale 0.2 0.2 $
            Text "Select a triangle by pressing its character on your keyboard!"
        chooseMovePic = if state world == Moving && gameState myGame /= ThrowDice then
            translate (-120) 200 chooseMoveText
                else blank

        allTextPic = chooseMovePic <> throwDicePic <> playerTurnPic <> chooseStepsPic


-- Draw game triangles
drawGameTriangles :: [GameTriangle] -> Direction -> Picture
drawGameTriangles [] _ = blank
drawGameTriangles (triangle:triangles) direction = firstTriangle <> remainingTriangles
    where
        shift = case direction of
            Upward -> -50
            Downward -> 50
        firstTriangle = drawGameTriangle triangle direction
        remainingTriangles = translate shift 0 (drawGameTriangles triangles direction)

-- Draw a single game triangle
drawGameTriangle :: GameTriangle -> Direction -> Picture
drawGameTriangle triangle direction = directedTriangle <> circles <> character
    where
        (_, _, _, c) = triangle
        directedTriangle = Color red $ case direction of
            Upward -> Polygon [(0,0), (25,100), (50,0)]
            Downward -> Polygon [(0,0), (25,-100), (50,0)]
        circles = drawPieces triangle direction
        yaxis = case direction of
            Upward -> (-40)
            Downward -> 10
        character = translate 11.5 yaxis (scale 0.3 0.3 $ Text [c])

drawPieces :: GameTriangle -> Direction -> Picture
drawPieces triangle direction = translate 25 y (mahbousaPiece <> translate 0 yMahbousa (drawIdenticalPieces numPieces direction piecesColor))
    where
        drawPiece color = Color color $ ThickCircle 5 10
        y = case direction of
            Upward -> 10
            Downward -> -10
        (color, numPieces, mahbousa, c) = triangle
        clr x = if x == 1 then black else white
        mahbousaColor = clr (MyLib.inv color)
        piecesColor = clr color
        mahbousaPiece = if mahbousa == 0 then blank else drawPiece mahbousaColor
        yMahbousa = if mahbousa == 0 then 0 else y

drawIdenticalPieces :: Int -> Direction -> Color -> Picture
drawIdenticalPieces 0 direction color = blank
drawIdenticalPieces numPieces direction color = piece <> translate 0 y pieces
    where
        drawPiece color = Color color $ ThickCircle 5 10
        y = case direction of
            Upward -> 15
            Downward -> -15
        piece = drawPiece color
        pieces = drawIdenticalPieces (numPieces - 1) direction color


-- | A function to convert keypress event to integer
convEvent :: Int -> Event -> Int
convEvent 0 (EventKey (SpecialKey KeyEnter) Down _ _) = 1
convEvent 0 _ = 0
convEvent 1 (EventKey (Char c) Down _ _)
    | c >= 'a' && c <= 'x'          = MyLib.charToInt c
    | otherwise                     = 24
convEvent 1 _ = 24
convEvent 2 (EventKey (Char c) Down _ _)
    | c >= '1' && c <= '6'          = MyLib.charToInt c
    | otherwise                     = 0
convEvent _ _ = 0


-- | Change the state of the game according to user's input
handleInput :: Bool -> Event -> BackGammonGame -> BackGammonGame
handleInput isMulti event game
    | finished world                                  = game
    | tturn == 1 && isMulti                           = bot game
    | curState == ThrowDice && convEvent 0 event == 1 = BackGammonGame (throwDices world) Play
    | curState == ThrowDice                           = game
    | state world == ChooseSteps                      = BackGammonGame (chooseSteps stepsEvent world) Play
    | myEvent > 23                                    = game
    | otherwise                                       = BackGammonGame newWorld newState
        where
            stepsEvent = convEvent 2 event
            myEvent = convEvent 1 event
            world = curWorld game
            curState = gameState game
            tturn = turn (curWorld game)
            newWorld = tryMovePiece (myEvent, choosedSteps world) world
            ok = turn world /= turn newWorld
            newState = if ok then ThrowDice else Play

-- | A function to choose the number of steps a piece will move in this turn
chooseSteps :: Int -> World -> World
chooseSteps x (World dc t tr av r b _ f _) =
    if not (MyLib.exists x av) && ok then World dc t tr av r b ChooseSteps f 0 else World dc t tr av r b Moving f x
    where
        ok = existValidTriangle (World dc t tr av r b ChooseSteps f 0) x

-- | generate to random numbers from 1 to 6 and assign them the dices member in World struct
throwDices :: World -> World
throwDices (World _ t tr _ (r1:(r2:rs)) _ _ _ _) = updateBearingOff nextState
    where
        moves = if r1 == r2 then [r1, r1, r1, r1] else [r1, r2]
        newWorld = updateBearingOff $ World (r1, r2) t tr moves rs False ChooseSteps False (-1)
        nextState = if existsValidMoves newWorld then newWorld
            else throwDices $ flipTurn newWorld

existsValidMoves :: World -> Bool
existsValidMoves world = any (existValidTriangle world) (availableMoves world)

-- | A function to check if there exist a valid triangle where you pick a piece and move it a given number of steps
existValidTriangle :: World -> Int -> Bool
existValidTriangle world steps = any isValid moves
    where
        moves = map (\a -> (a, steps)) [0..23]
        isValid move = fst (isValidMove move world)

-- | A function to perform a move 
tryMovePiece :: (Int, Int) -> World -> World
tryMovePiece (id, steps) world
    | not (exists steps (availableMoves world)) || not ok = world
    | otherwise = ret
        where
            (ok, newState) = isValidMove (id, steps) world
            (World dc t tr av r b st _ _) = updateBearingOff newState
            newAv = MyLib.removeOneOccurence steps av
            newWorld = World dc t tr newAv r b ChooseSteps False (-1)
            ret
              | gameFinished newState = World dc t tr av r b st True (-1)
              | existsValidMoves newWorld = newWorld
              | otherwise = flipTurn newWorld

colorExist :: GameTriangle -> Int -> Bool
colorExist (x, y, _, c) clr = x == clr && y > 0

changeTriangle :: GameTriangle -> Int -> Int -> GameTriangle
changeTriangle tr (-1) _ = removeFromTriangle tr
    where
        removeFromTriangle (x, y, z, c)
                | y > 1         = (x, y - 1, z, c)
                | z == 1        = (MyLib.inv x, 1, 0, c)
                | otherwise     = (0, 0, 0, c)

changeTriangle tr 1 clr = addToTriangle tr clr
    where
        addToTriangle (x, y, z, c) t
            | y == 0        = (t, 1, 0, c)
            | y > 1         = (x, y + 1, z, c)
            | x == t        = (x, 2, z, c)
            | otherwise     = (t, 1, 1, c)

changeTriangles :: [GameTriangle] -> Int -> Int -> Int -> [GameTriangle]
changeTriangles lst id val trn = iter lst val id trn 0
    where
        iter :: [GameTriangle] -> Int -> Int -> Int -> Int -> [GameTriangle]
        iter [] _ _ _ _ = []
        iter (x:xs) v i t pos = if pos == i then changeTriangle x v trn : xs else x : iter xs v i t (pos + 1)

-- | removing or adding number of pieces to a specific triangle in the world
changeWorld :: World -> Int -> Int -> World
changeWorld (World d trn t a r b st f ch) id val = World d trn (changeTriangles t id val trn) a r b st f ch


-- | First parameter (x, y)
-- | X: Represents the index of the triangle from where the character to be moved is chosen.
-- | Y: Represents the number of forward points of which the character to be moved.
-- | Second parameter the current state of the game.
-- | It returns (True, newState) if this move is valid
-- | otherwise it returns (False, curState)
isValidMove :: (Int, Int) -> World -> (Bool, World)
isValidMove (x, y) world
    | not (colorExist currentTriangle currentTurn) = (False, world)
    | x - y < 0  && not (bearingOff world)         = (False, world)
    | x - y < 0                                    = (True, changeWorld world x (-1))
    | desCount == 0 || desColor == currentTurn     = (True, changeWorld (changeWorld world x (-1)) (x - y) 1)
    | desCount == 1 && mahbousa == 0               = (True, changeWorld (changeWorld world x (-1)) (x - y) 1)
    | otherwise                                    = (False, world)
        where
            currentTriangle = triangles world !! x
            currentTurn = turn world
            desTriangle = triangles world !! (x - y)
            (desColor, desCount, mahbousa, _)  = desTriangle


allInHalf :: [GameTriangle] -> Int -> Bool
allInHalf lst trn = iter lst 0
    where
        check (x, y, z, _)
            | x == trn && y > 0  = True
            | x /= trn && z == 1 = True
            | otherwise          = False

        iter [] _ = True
        iter (x:xs) pos = not (pos >= 6 && check x) && iter xs (pos + 1)

updateBearingOff :: World -> World
updateBearingOff (World dc t tr av r b st f ch) =
    if allInHalf tr t then World dc t tr av r True st f ch else World dc t tr av r False st f ch


-- | flip the turn
flipTurn :: World -> World
flipTurn (World _ t tr _ r _ _ _ _) = newWorld
    where
        revTurn = inv t
        revTrgs = reverse tr
        revTrgs2 = zipWith (\(a, b,c,  _) ch -> (a, b, c, ch)) revTrgs ['a'..'x']
        newWorld = World (-1, -1) revTurn revTrgs2 [] r False ChooseSteps False (-1)

-- | A function to determine if a game is finished by counting the number of pieces owned by this turn player
gameFinished :: World -> Bool
gameFinished world = countInTriangles (triangles world)
    where
        countInTriangles [] = True
        countInTriangles ((x, y, z, c):xs)
            | y == 0 = countInTriangles xs
            | x == turn world = False
            | z == 1 = False
            | otherwise = countInTriangles xs

allMoves :: [Int] -> [(Int,Int)]
allMoves [] = []
allMoves (x:xs) = go x [0..23] ++ allMoves xs
    where
        go :: Int -> [Int] -> [(Int, Int)]
        go x [] = []
        go x (y:ys) = (y, x) : (y, x) : (y, x) : (y, x) : go x ys

bot :: BackGammonGame -> BackGammonGame
bot game = newGame
    where
        newState = gameState game
        world = throwDices (curWorld game)
        moves = allMoves (availableMoves world)

        newWorld =  foldl (\x y -> tryMovePiece y x) world moves
        newGame = BackGammonGame newWorld newState
