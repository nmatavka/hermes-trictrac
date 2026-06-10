{-# LANGUAGE BlockArguments #-}

module Effects where


import SideFun
import Components
import Debug.Trace
import Data.Maybe (isJust)
import Data.Foldable (find)
import Graphics.Gloss.Interface.IO.Game


{- Takes two numbers of between 1..24 and a pawn.
   Function removes the given pawn at an index and places it at a new index -}
pickPlacePawn :: Board -> (Int, Int) -> Pawn -> Board
pickPlacePawn (bar, oldBoard) (from, to) chip = case oldBoard !! x !! y of
    {- If Track is empty, return oldBoard, else pick and place --}
    Nothing  -> (bar, oldBoard)
    (Just _) -> (bar, newBoard)

    where
          {- Returns the board with the removed pawn now placed at new location -}
          newBoard = getNewBoard to lessBoard -- updateAt i (updateAt j (addPawn j chip)) lessBoard :: [Quad]

          {- Returns a new board with the given pawn removed from the board -}
          lessBoard = updateAt x (updateAt y (removePawn k)) oldBoard :: [Quad]

          {- Gets the from and to quad index, track index and chip height -}
          ((x, y), (i, j), k) = (getTrackId from, getTrackId to, pt_ chip)

          getNewBoard :: Int -> [Quad] -> [Quad]
          getNewBoard to_ board = if to_==(-1)
                                 then board
                                 else updateAt i (updateAt j (addPawn j chip)) lessBoard :: [Quad]


resetAllFocus :: Board -> Board
resetAllFocus (bar, quads) = (bar, map (map resetFocus) quads)
    where
        resetFocus :: Track -> Track
        resetFocus Nothing = Nothing
        resetFocus (Just pawns) = Just $ map reset pawns

        reset :: Pawn -> Pawn
        reset pawn = pawn { isFocused_=False }



quadIdx :: (Float, Float) -> Maybe Int
quadIdx (x_,y)
    | x_>(bWidth/2) && x_<(qWidth+(bWidth/2)) && y>0 && y<qHeight         = Just 3
    | x_<(-(bWidth/2)) && x_>(-qWidth-(bWidth/2)) && y>0 && y<qHeight     = Just 2
    | x_<(-(bWidth/2)) && x_>(-qWidth-(bWidth/2)) && y>(-qHeight) && y<0  = Just 1
    | x_>(bWidth/2) && x_<(qWidth+(bWidth/2)) && y>(-qHeight) && y<0      = Just 0
    | otherwise                                                           = Nothing

trackIdx :: (Float, Float) -> Maybe Int
trackIdx (x_,y)
    | x_>(bWidth/2) && x_<(qWidth+(bWidth/2)) && y>0 && y<qHeight         = Just $ floor ((x_-(bWidth/2))/pWidth)
    | x_<(-(bWidth/2)) && x_>(-qWidth-(bWidth/2)) && y>0 && y<qHeight     = Just $ 5 - floor (abs(x_+(bWidth/2))/pWidth)
    | x_<(-(bWidth/2)) && x_>(-qWidth-(bWidth/2)) && y>(-qHeight) && y<0  = Just $ floor (abs(x_+(bWidth/2))/pWidth)
    | x_>(bWidth/2) && x_<(qWidth+(bWidth/2)) && y>(-qHeight) && y<0      = Just $ 5 - floor ((x_-(bWidth/2))/pWidth)
    | otherwise                                                           = Nothing

yIdx :: (Float, Float) -> Maybe Int
yIdx (_,y)
    | y>0 && y<qHeight      = Just $ 5 - floor (y/(s*pWidth))
    | y>(-qHeight) && y<0   = Just $ abs (floor (abs y/(s*pWidth)) - 5)
    | otherwise             = Nothing


getIdx :: Maybe Int -> Maybe Int -> Maybe Int -> Maybe (Int, Int, Int)
getIdx Nothing _ _ = Nothing
getIdx _ Nothing _ = Nothing
getIdx _ _ Nothing = Nothing
getIdx (Just x_) (Just y_) (Just z_) = Just (x_, y_, z_)


chipIdx :: (Float, Float) -> Maybe (Int, Int, Int)
chipIdx pos = getIdx (quadIdx pos) (trackIdx pos) (yIdx pos)


getFocusedChip :: [Quad] -> Maybe (Int, Pawn)
getFocusedChip quads = getFocus $ zipWith combine (concatMap (map check) quads) allIdx
    where
        allIdx = [ tIdx_+(6*qIdx_)-1 | qIdx_ <- [0..3], tIdx_ <- [1..6] ]

        combine :: Maybe Pawn -> Int -> Maybe (Int, Pawn)
        combine Nothing _ = Nothing
        combine (Just pawn) idx = Just (idx, pawn)


getFocus :: [Maybe (Int, Pawn)] -> Maybe (Int, Pawn)
getFocus list = do
    let first = find isJust list
    case first of
        Nothing             -> Nothing
        Just Nothing        -> Nothing
        Just (Just content) -> Just content


check :: Track -> Maybe Pawn
check Nothing        = Nothing
check (Just pawns)   = find isFocused_ pawns


setDices :: Dices -> Int -> Int-> Player -> Dices
setDices ((Die d1, Die d2), (Die d3, Die d4)) toIdx fromIdx player = case player of
    (PlayerWhite _) -> (setD d1 d2 toIdx fromIdx, (Die d3, Die d4))
    (PlayerRed _)   -> ((Die d1, Die d2), setD d3 d4 toIdx fromIdx)

setD :: Int -> Int -> Int -> Int  -> (Die, Die)
setD d1 d2 toIdx fromIdx
    | d1==abs(toIdx-fromIdx)    = (Die 0, Die d2)
    | d2==abs(toIdx-fromIdx)    = (Die d1, Die 0)
    | d1+d2==abs(toIdx-fromIdx) = (Die 0, Die 0)
    | otherwise                 = (Die d1, Die d2)


resetDices :: Dices -> (Int, Int, Int, Int) -> Player -> Dices
resetDices (die1, die2) (d1, d2, d3, d4) player__ = case player__ of
    (PlayerRed _)    -> ((Die d1, Die d2), die2)
    (PlayerWhite _)  -> (die1, (Die d3, Die d4))


nextDSet :: [Int] -> ((Int, Int, Int, Int), [Int])
nextDSet infList = (next_, restInfList)
    where
        next_ = (head next4, next4!!1, next4!!2, next4!!3)
        next4 = take 4 infList
        restInfList = drop 4 infList


getPlayerDice :: Player -> Dices -> (Die, Die)
getPlayerDice pPlayer dices_ = case pPlayer of
    (PlayerWhite _) -> fst dices_
    (PlayerRed _)   -> snd dices_


{- Takes current board, the values of the two dice and a selected pawn
   and returns the possible trackIds to move to -}
goodMoves :: Board -> (Die, Die) -> [Int]
goodMoves (bar, quads) (Die d1, Die d2) = do
    case getFocusedChip quads of
        Nothing           -> []
        Just (fId, fChip) -> do
            case fChip of
                (PawnWhite _ _) -> filter
                                   (\to -> to <= 23 && to>=0 && checkMove (bar, quads) fId to fChip)
                                   [fId-d1, fId-d2, fId-d1-d2]

                (PawnRed _ _)   -> filter
                                   (\to -> to <= 23 && to>=0 && checkMove (bar, quads) fId to fChip)
                                   [d1+fId, d2+fId, d1+d2+fId]


getBlotMoves :: Player -> (Die, Die) -> [Int]
getBlotMoves player (Die d1, Die d2) = do
    let list = [d1, d2, d1+d2]
    
    case player of
        PlayerWhite _ -> [ 24-i | i<-list ]
        PlayerRed _ -> [ i | i<-list ]


unBlotChip :: Game -> Int -> Game 
unBlotChip game toIdx = do
    let (Game oldBoard dice player gameState dValues) = game
    let (bar, quads) = oldBoard
    let moves = getBlotMoves player (getPlayerDice player dice)
    let newToIdx = genNewToIdx player toIdx
    let (i, j) = getTrackId newToIdx  
    let newDice = getNewDice dice player toIdx moves -- dice -- 
    
    let newChip = getNewChip player :: Pawn
    let newQuads = updateAt i (updateAt j (addPawn j newChip)) quads :: [Quad] 
    let newBar = updateBar player bar :: Bar
    
    trace (show (elem newToIdx moves) ++ show (newToIdx,i,j)) case elem newToIdx moves of
        True -> (Game (newBar, newQuads) newDice player gameState dValues)
        _    -> game
    
        where
            getNewDice :: Dices -> Player -> Int -> [Int] -> Dices 
            getNewDice (die1, die2) player toIdx list = case player of
                PlayerWhite _   -> ((newDD player die1 [abs(toIdx-i) | i <- list]), die2)
                PlayerRed _     -> (die1, (newDD player die2 [abs(toIdx-i) | i <- list]))
                
                where 
                    newDD :: Player -> (Die, Die) -> [Int] -> (Die, Die)
                    newDD player (Die d1, Die d2) list_ = case player of 
                        PlayerWhite _   -> newValues d1 d2 list_
                        PlayerRed _     -> newValues d1 d2 list_
                        
                    newValues :: Int -> Int -> [Int] -> (Die, Die)
                    newValues d1 d2 list_ 
                      | d1 `elem` list_ = (Die 0, Die d2)
                      | d2 `elem` list_ = (Die d1, Die 0)
                      | (d1+d2) `elem` list_ = (Die 0, Die 0)
                      |otherwise = (Die d1, Die d2)
            
            
            
            genNewToIdx :: Player -> Int -> Int
            genNewToIdx player z = case player of
                PlayerWhite _   -> 23-5+z
                PlayerRed _     -> -23+5-z
            
            getBlotTrackId :: Player -> Int -> (Int, Int) 
            getBlotTrackId player z = case player of
                PlayerRed _     -> (23 - floor (fromIntegral z /6), 23 - (mod z 6)) 
                PlayerWhite _   -> (floor (fromIntegral z /6) - 23, (mod z 6) - 23)
            
            updateBar :: Player -> Bar -> Bar
            updateBar _ Nothing           = Just [] 
            updateBar player (Just chips) = do
                let (whites, reds) = groupChips chips
                let newWhites = tail whites
                let newReds   = tail reds
                
                case player of
                    PlayerWhite _ -> Just $ newWhites ++ reds
                    PlayerRed _   -> Just $ whites ++ newReds
                    
            getNewChip :: Player -> Pawn
            getNewChip player = case player of
                PlayerWhite _ -> PawnWhite 0 False
                PlayerRed _   -> PawnRed 0 False
                    
--            updateTrack :: Int -> Quad -> Quad
--            updateTrack idx tracks = updateAt idx (updateBoardPawn yIdx_) tracks


moveChip :: Game -> (Int, Pawn) -> (Int, Int) -> Game
moveChip game (idFocusChip, focusChip) (nextQIdx, nextTIdx) = do
    let (Game oldBoard dices player state dValues) = game
    let (fromIdx, fChip) = (idFocusChip, focusChip)
    let (qIdx, tIdx) = (nextQIdx, nextTIdx)
    let toIdx = tIdx + (6*qIdx) -- newIdx fChip

    let newDices = setDices dices toIdx fromIdx player
    let ((Die d1, Die d2), (Die d3, Die d4)) = newDices

    let (isBlot, bBoard) = checkBlot oldBoard toIdx fChip
    let (nextSet, newDValues) = nextDSet dValues
    let nextMoves = goodMoves oldBoard (getPlayerDice player dices)

    case toIdx `elem` nextMoves of
        False -> Game oldBoard dices player state dValues
        _     -> do
            case (player, whiteAllMovesDone, redAllMovesDone) of
                 (PlayerWhite _, True, _) -> Game (resetAllFocus newBoard)
                                                (resetDices newDices nextSet player)
                                                (PlayerRed "Red Player")
                                                state
                                                newDValues
                 (PlayerRed _, _, True)   -> Game (resetAllFocus newBoard)
                                                (resetDices newDices nextSet player)
                                                (PlayerWhite "White Player")
                                                state
                                                newDValues
                 _                        -> Game (resetAllFocus newBoard) newDices player state dValues

            where
               newBoard = if isBlot
                          then pickPlacePawn bBoard (fromIdx, toIdx) fChip
                          else pickPlacePawn oldBoard (fromIdx, toIdx) fChip

               whiteAllMovesDone = d1==0 && d2==0
               redAllMovesDone   = d3==0 && d4==0


bearOff :: Board -> Int -> Pawn -> Board
bearOff (bar, quads) chipIdx_ fChip = resetAllFocus newBoard
    where
        newBoard = pickPlacePawn (bar, quads) (chipIdx_, -1) fChip



bearOffChip :: Game -> (Int, Pawn) -> (Int, Int) -> Game
bearOffChip game (idFocusChip, focusChip) (nextQIdx, nextTIdx) = do
    let (Game oldBoard dices player state dValues) = game
    let (fromIdx, fChip) = (idFocusChip, focusChip)
    let (qIdx, tIdx) = (nextQIdx, nextTIdx)
    let toIdx = tIdx + (6*qIdx) -- newIdx fChip

    let newDices = setDices dices toIdx fromIdx player
    let ((Die d1, Die d2), (Die d3, Die d4)) = newDices

    let (nextSet, newDValues) = nextDSet dValues
    let bearMoves = goodMoves oldBoard (getPlayerDice player dices) -- Returns only tracks with chips that can be beared-Off

    case toIdx `elem` bearMoves of -- toIdx is actually still same as fromIdx for the case that a chip can be beared-off
        False -> Game oldBoard dices player state dValues
        _     -> do
            case (player, whiteAllMovesDone, redAllMovesDone) of
                 (PlayerWhite _, True, _) -> Game (bearOff oldBoard fromIdx fChip)
                                                  (resetDices newDices nextSet player)
                                                  (PlayerRed "Red Player")
                                                  state
                                                  newDValues
                 (PlayerRed _, _, True)   -> Game (bearOff oldBoard fromIdx fChip)
                                                  (resetDices newDices nextSet player)
                                                  (PlayerWhite "White Player")
                                                  state
                                                  newDValues
                 _                        -> Game (bearOff oldBoard fromIdx fChip) newDices player state dValues

            where
               whiteAllMovesDone = d1==0 && d2==0
               redAllMovesDone   = d3==0 && d4==0


hasBlotted :: Player -> Bar -> Bool
hasBlotted _ Nothing = False
hasBlotted player (Just chips) = do 
    let (whites, reds) = groupChips chips
    case player of
        PlayerWhite _ -> not $ null whites
        PlayerRed _   -> not $ null reds


transformGame :: Event -> Game -> Game
transformGame (EventKey (MouseButton LeftButton) Up _ mousePos) game = case chipIdx mousePos of
      Nothing -> game
      Just (qIdx, tIdx, yIdx_) -> do
          let (Game oldBoard dice player gameState dValues) = game
  
          case gameState of
              GameOver _ -> game
              Running    -> do
                  let (bar, quads) = resetAllFocus oldBoard
                  let newBoard = if hasBlotted player bar 
                                 then snd oldBoard 
                                 else updateAt qIdx (updateTrack tIdx) quads
                                 
                  let newBar = if hasBlotted player bar 
                               then updateBar player bar 
                               else bar 
                                 
                  Game (newBar, newBoard) dice player gameState dValues
                  
              where
                  updateBar :: Player -> Bar -> Bar
                  updateBar _ Nothing           = Just [] 
                  updateBar player (Just chips) = do
                      let (whites, reds) = groupChips chips
                      let newWhites = if null whites then [] else ((head whites) { isFocused_=True }) : tail whites
                      let newReds   = if null reds then [] else ((head reds) { isFocused_=True }) : tail reds
                      
                      case player of
                          PlayerWhite _ -> trace (show (newWhites, reds)) Just $ newWhites ++ reds
                          PlayerRed _   -> trace (show (whites, newReds)) Just $ whites ++ newReds
                          
                  updateTrack :: Int -> Quad -> Quad
                  updateTrack idx tracks = updateAt idx (updateBoardPawn yIdx_) tracks
      
                  updateBoardPawn :: Int -> Track -> Track
                  updateBoardPawn _ Nothing = Nothing
                  updateBoardPawn idx (Just pawns) = Just $ updateAt idx updateBoardChip pawns
                  
                  updateBoardChip chip = case (player_ game, chip) of
                      (PlayerRed _, PawnRed _ _)      -> chip { isFocused_=True }
                      (PlayerWhite _, PawnWhite _ _)  -> chip { isFocused_=True }
                      (_, _)                          -> chip
      

transformGame (EventKey (MouseButton RightButton) Up _ mousePos) game = case chipIdx mousePos of
    Nothing              -> game
    Just (qIdx, tIdx, _) -> do
        let (Game oldBoard dices player state dValues) = game
        let (_, quads) = oldBoard

        let focusedChip = getFocusedChip quads
        
        case hasBlotted player (fst oldBoard) of
            True -> trace "Trying to unBlot" unBlotChip game tIdx
            False -> case focusedChip of
                 Nothing -> Game oldBoard dices player state dValues
                 Just (fromIdx, fChip) -> case state of
                     GameOver _  ->  game
                     Running     -> if getBearOffStates oldBoard player
                                    then bearOffChip game (fromIdx, fChip) (qIdx, tIdx)
                                    else moveChip game (fromIdx, fChip) (qIdx, tIdx)
        

transformGame _ game = game

