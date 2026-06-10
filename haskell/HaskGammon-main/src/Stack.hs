{-# OPTIONS_GHC -Wno-incomplete-patterns #-}
module Stack where

import Data.Maybe


import Environment



selector :: Int -> Maybe Int
selector k | k `elem` [0..5]   = Just 1
           | k `elem` [6..11]  = Just 2
           | k `elem` [12..17] = Just 3
           | k `elem` [18..23] = Just 4
           | otherwise      = Nothing





getFromEnv :: HaskGammon -> Int -> (Int, Int, Maybe Player)
getFromEnv world = getFromEnv' (env world) where
        getFromEnv' :: Environment -> Int -> (Int, Int, Maybe Player)
        getFromEnv' (Env ls) int = ls !! int

getplayer :: (Int, Int, Maybe Player) -> Maybe Player
getplayer (a,b,Nothing) = Nothing
getplayer (a,b,Just player) = Just player


isPlayable :: HaskGammon -> Int -> Bool
isPlayable world to     | isNothing (selectedPawn world) || not scope = False
                        | otherwise = isPlayable' world (fromJust (selectedPawn world)) to where
                                scope = 0 <= to && to < 24

isPlayable' :: HaskGammon -> Int -> Int -> Bool
isPlayable' world from to |  null(moves world) || isNothing(getIntInMvs distance) || isFort || not scope = False
                          | otherwise = sense && direction where
                scope = 0 <= to && to < 24 && 0 <= from && from < 24
                isFort= (getPawn (getFromEnv world to) == (Just (counter (turn world)) ) && (getCount (getFromEnv world to)) >1)
                getIntInMvs k = getIntInMoves world k
                getStrInMvs k = getStrInMoves world k
                distance = if turn world == Red then to-from else from-to
                direction= if turn world == Red then from<to else to<from
                sense    | isDouble (fromJust (dice world)) && turn world == Red   = senseDoubleRed
                         | isDouble (fromJust (dice world)) && turn world == White = senseDoubleWhite
                         | turn world == Red   = senseRed
                         | turn world == White = senseWhite
                inMoves k = k `elem` map snd(moves world)
                senseRed | getIntInMvs distance == Just "both" = (isPlayable' world from (fromJust $ getStrInMvs "first")  && isPlayable' world (from+fromJust (getStrInMvs "first"))  to)
                                                          || (isPlayable' world from (fromJust $ getStrInMvs "second") && isPlayable' world (from+fromJust (getStrInMvs "second")) to)
                         | otherwise = inMoves distance
                senseWhite | getIntInMvs distance == Just "both" = (isPlayable' world from (from-fromJust (getStrInMvs "first"))  && isPlayable' world (from-(fromJust $ getStrInMvs "first"))  to)
                                        ||
                                             (isPlayable' world from (from-(fromJust $ getStrInMvs "second")) && isPlayable' world (from-(fromJust $ getStrInMvs "second")) to)
                           | otherwise = inMoves distance
                senseDoubleRed   | getIntInMvs distance == Just "4"= isPlayable' world from (from+(fromJust $ getStrInMvs "1"))  && isPlayable' world (from+(fromJust $ getStrInMvs "1"))  (from+(fromJust $ getStrInMvs "2")) && isPlayable' world (from+(fromJust $ getStrInMvs "2"))  (from+(fromJust $ getStrInMvs "3")) && isPlayable' world (from+(fromJust $ getStrInMvs "3"))  to
                                 | getIntInMvs distance == Just "3"= isPlayable' world from (from+(fromJust $ getStrInMvs "1"))  && isPlayable' world (from+(fromJust $ getStrInMvs "1"))  (from+(fromJust $ getStrInMvs "2")) && isPlayable' world (from+(fromJust $ getStrInMvs "2"))  to
                                 | getIntInMvs distance == Just "2"= isPlayable' world from (from+(fromJust $ getStrInMvs "1"))  && isPlayable' world (from+(fromJust $ getStrInMvs "1"))  to
                                 | getIntInMvs distance == Just "1"= isJust (getIntInMvs distance)
                                 | otherwise = False
                senseDoubleWhite | getIntInMvs distance == Just "4"= isPlayable' world from (from-(fromJust $ getStrInMvs "1"))  && isPlayable' world (from-(fromJust $ getStrInMvs "1"))  (from-(fromJust $ getStrInMvs "2")) && isPlayable' world (from-(fromJust $ getStrInMvs "2"))  (from-(fromJust $ getStrInMvs "3")) && isPlayable' world (from-(fromJust $ getStrInMvs "3"))  to
                                 | getIntInMvs distance == Just "3"= isPlayable' world from (from-(fromJust $ getStrInMvs "1"))  && isPlayable' world (from-(fromJust $ getStrInMvs "1"))  (from-(fromJust $ getStrInMvs "2")) && isPlayable' world (from+(fromJust $ getStrInMvs "2"))  to
                                 | getIntInMvs distance == Just "2"= isPlayable' world from (from-(fromJust $ getStrInMvs "1"))  && isPlayable' world (from-(fromJust $ getStrInMvs "1"))  to
                                 | getIntInMvs distance == Just "1"= isJust (getIntInMvs distance)



getIntInMoves :: HaskGammon -> Int -> Maybe String
getIntInMoves world k | null [str | (str,int)<-moves world, int == k] = Nothing
                      | otherwise = Just $ head [str | (str,int)<-moves world, int == k]
getStrInMoves :: HaskGammon -> String -> Maybe Int
getStrInMoves   world k | null [int | (str,int)<-moves world, str == k] = Nothing
                      | otherwise = Just $ head [int | (str,int)<-moves world, str == k]

counter :: Player -> Player
counter Red  = White
counter White= Red

nullEnv :: Environment -> Bool
nullEnv (Env ls) = null ls

genMoves :: Dice -> [(String,Int)] -- tested
genMoves (Dice(fs,sc)) | fs == sc  = [("1",fs),("2",2*fs),("3",3*fs),("4",4*fs)]
                       | otherwise = [("first",fs),("second",sc),("both",fs+sc)]

funcFromEnv :: Environment -> Int -> ((Int, Int, Maybe Player) -> t) -> t
funcFromEnv (Env ls) num f = f (ls !! num)

getAddr :: (Int,Int, Maybe Player) -> Int
getAddr (a,_,_) = a

getCount :: (Int,Int, Maybe Player) -> Int
getCount (_,b,_) = b

getPawn :: (Int,Int, Maybe Player) -> Maybe Player
getPawn (_,_,c) = c




sumDice :: HaskGammon -> (HaskGammon -> Maybe Dice) -> Int
sumDice world a | isNothing (a world) = 0
                | otherwise = sumDice' (fromJust (a world)) where
sumDice' :: Dice -> Int
sumDice' (Dice (a,b)) = a+b

isDouble :: Dice -> Bool
isDouble (Dice (a,b)) = a==b



move' :: HaskGammon -> Int -> [([Char], Int)]
move' world to = updateMoves world distance where
        distance = if turn world == White
                then fromJust (selectedPawn world) -to
                else to-fromJust (selectedPawn world)

updateMoves :: HaskGammon -> Int -> [([Char], Int)]
updateMoves world int | isNothing (dice world)           = []
                      | isDouble (fromJust (dice world)) = updateMove'' int (moves world)
                      | otherwise                        = updateMove'  int (moves world)
label :: Int -> [(String, Int)] -> String
label _ [] = []
label int (l:ls) | snd l == int = fst l
                 | otherwise = label int ls
updateMove' :: Int -> [([Char], Int)] -> [([Char], Int)]
updateMove' _ [] = []
updateMove' int ls      | label int ls == "first" || label int ls == "second" = deleteMove [label int ls, "both"] ls
                        | label int ls == "both" = []
                        | otherwise    = []

updateMove'' :: Int -> [([Char], Int)] -> [([Char], Int)]
updateMove'' _ [] = []
updateMove'' int ls         | label int ls == "1" = deleteMove [show maxx] ls
                            | label int ls == "2" = deleteMove [show maxx, show (maxx-1)] ls
                            | label int ls == "3" = deleteMove [show maxx, show (maxx-1, show (maxx-20))] ls
                            | label int ls == "4" = []
                            | otherwise    = [] where
                                maxx = maximum (map snd ls)

deleteMove :: [String] -> [(String, Int)] -> [(String, Int)]
deleteMove _ [] = []
deleteMove str (l:ls) | fst l `elem` str = deleteMove str ls
                      | otherwise = l : deleteMove str ls

listToDice :: [Int] -> [Dice]
listToDice [] = []
listToDice [_] = []
listToDice (a:b:ls) = Dice (a,b):listToDice ls

