module SideFun where

  
import Components

  
updateAt :: Int -> (a -> a) -> [a] -> [a]
updateAt i tryUpdate list
    | i > length list - 1 || i < 0  = list
    | null list                     = list
    | otherwise                     = a ++ zs

    where (a, bs) = splitAt i list
          zs = case bs of
              [] -> []
              (c:ds) -> tryUpdate c : ds
        

removeAt :: Int -> [a] -> [a]
removeAt i list = as ++ zs
    where (as, bs) = splitAt i list
          zs = case bs of
            [] -> []
            (_:cs) -> cs


setPt :: Board -> Board
setPt (bar, quads) = (bar, map (map organiseTrack) quads)


organiseTrack :: Track -> Track
organiseTrack track = case track of
    Nothing -> Nothing
    Just pawns -> Just [ pawn { pt_=i } | (pawn, i) <- zip pawns [0..(length pawns - 1)] ]


groupChips :: [Pawn] -> ([Pawn], [Pawn])
groupChips pawns_ = (whites, reds)
    where
        whites = filter whiteFilter pawns_
        reds = filter redFilter pawns_

whiteFilter :: Pawn -> Bool
whiteFilter pawn = case pawn of
    (PawnWhite _ _) -> True
    _               -> False

redFilter :: Pawn -> Bool
redFilter pawn = case pawn of
    (PawnRed _ _) -> True
    _             -> False


{- Removes a pawn at a specific index from a track -}
removePawn :: Int -> Track -> Track
removePawn idx track = case track of
    Nothing -> Nothing
    (Just pawns)
        | null newPawns -> Nothing
        | otherwise     -> organiseTrack $ Just newPawns
        where newPawns = removeAt idx pawns


{- Adds a pawn at a given pt in a track -}
addPawn :: Int -> Pawn -> Track -> Track
addPawn _ pawn track = case track of
    Nothing -> Just [pawn { pt_=0 }]
    Just _  -> newTrack
        where
            l = length track
            newTrack = case organiseTrack track of
                Nothing -> Nothing
                (Just orderedPawns) -> Just (orderedPawns ++ [pawn { pt_=l }])


{- returns a tuple of quad position and track position -}
getTrackId :: Int -> (Int, Int)
getTrackId z = (floor (fromIntegral z /6), mod z 6)


{- Count number of type_pawns in a track -}
trackContent :: Track -> (Int, Int)
trackContent = filterTrack . transTrack
    where
        filterTrack :: [Int] -> (Int, Int)
        filterTrack chips = (length whites, length reds)
            where
                whites = filter (== 0) chips
                reds   = filter (== 1) chips

        transTrack :: Track -> [Int]
        transTrack Nothing = []
        transTrack (Just pawns) = map transPawn pawns

        transPawn :: Pawn -> Int
        transPawn pawn_ = case pawn_ of
            (PawnWhite _ _) -> 0
            (PawnRed _ _)   -> 1


setBarChips :: Board -> Int -> Board
setBarChips (bar, board) tIdx_ = do
    let (qIdx, tIdx) = getTrackId tIdx_
    let bTrack = board !! qIdx !! tIdx

    let newBoard = updateAt qIdx (updateAt tIdx (removePawn 0)) board
    case bTrack of
        Nothing -> (bar, board)
        (Just pawns) -> if null pawns
                        then  (bar, board)
                        else case bar of
                            Nothing ->  (Just [head pawns], newBoard)
                            (Just bChips) -> (Just (head pawns:bChips), newBoard)


{- Check direction of Movement -}
{- Check if next track is open -}
checkMove :: Board -> Int -> Int -> Pawn -> Bool
checkMove board from to pawn = case pawn of
    (PawnRed _ _)   -> to > from && (trackIsOpen pawn to)
    (PawnWhite _ _) -> from > to && (trackIsOpen pawn to)
    where
        trackIsOpen :: Pawn -> Int -> Bool
        trackIsOpen chip tIdx_ = do
            let (qIdx, tIdx) = getTrackId tIdx_
            let track = snd board !! qIdx !! tIdx
            let (whiteCount, redCount) = trackContent track
            case chip of
                (PawnWhite _ _) -> redCount<=1
                (PawnRed _ _)   -> whiteCount<=1


setBlot :: Track -> Track
setBlot track = case track of
    Nothing -> Nothing
    (Just pawns) -> Just $ map (\chip -> chip { pt_ = -1 }) pawns


blotUpdatedBoard :: Int -> Int -> Board -> Board
blotUpdatedBoard qIdx tIdx (bar, oldBoard)
    = setBarChips (bar, updateAt qIdx (updateAt tIdx setBlot) oldBoard) (tIdx + 6*qIdx)


checkBlot :: Board -> Int -> Pawn -> (Bool, Board)
checkBlot board toIdx chip = updateBlots chip toIdx
    where
        updateBlots :: Pawn -> Int -> (Bool, Board)
        updateBlots chip_ tIdx_ = do
            let (qIdx, tIdx) = getTrackId tIdx_
            let track = snd board !! qIdx !! tIdx
            let (whitCount, redCount) = trackContent track
            case (chip_, redCount) of
                (PawnWhite _ _, 1)  -> (True, blotUpdatedBoard qIdx tIdx board)
                (PawnRed _ _, _)    -> case whitCount of
                    1 -> (True, blotUpdatedBoard qIdx tIdx board)
                    _ -> (False, board)
                _                   -> (False, board)


getBearOffStates :: Board -> Player -> Bool
getBearOffStates board player = False