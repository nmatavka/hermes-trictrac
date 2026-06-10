module Controller where

import Options
import Environment
import Graph
import Stack
import Options
import Data.Maybe
import Data.List (foldr)

-- TODOS
--Start1 Scene simulation
--Start2 Scene simulation
--Roll Scene   simulation
--Play simulation
--Roll, Play recursiv test and debug
--win scene

-- Start1

-- Roll click function

-- !coordinates (3*w/2) (4* triWidth) (!!Tested!!)     
-- ! Sizes (2*triWidth) (triWidth)

isRoll :: (Float,Float) -> Bool
isRoll (x,y) = leftBound <= x && x <=rightBound &&  lowerBound<=y && y<=upperBound where
    leftBound = (3*w/2)-triWidth
    rightBound= (3*w/2)+triWidth
    upperBound= (4*triWidth)+triWidth/2
    lowerBound= (4*triWidth)-triWidth/2


-- Pawn click function

whichOne :: HaskGammon -> (Float, Float) -> Maybe Int
whichOne world (x,y) = whichOne' world (x,y) (turnEnv world)

turnEnv :: HaskGammon -> [Int]
turnEnv world = turnEnv' world (env world) where
        turnEnv' :: HaskGammon -> Environment -> [Int]
        turnEnv' world (Env ls) = [ getAddr k |k<-ls, Just (turn world) == getPawn k]

whichOne' :: HaskGammon -> (Float, Float) -> [Int] -> Maybe Int
whichOne' _ _ [] = Nothing
whichOne' world (x,y) (l:ls)= if isPawn world (x,y) l then Just l else whichOne' world (x,y) ls


isPawn :: HaskGammon -> (Float, Float) -> Int -> Bool
isPawn world (x,y) addr = if selector addr == Just 1 then let
                                    leftBound  = cornerX+(w+frameWidth+ (fromIntegral(5-addr)*triWidth))
                                    rightBound = cornerX+(w+frameWidth+ (fromIntegral(6-addr)*triWidth))
                                    upperBound = cornerY+(fromIntegral count*triWidth)
                                    lowerBound = cornerY
                                    in leftBound <= x && x <= rightBound && lowerBound <= y && y<=upperBound
                                    else if selector addr == Just 2 then
                                    let
                                    leftBound  = cornerX+(fromIntegral(11-addr)*triWidth)
                                    rightBound = cornerX+(fromIntegral(12-addr)*triWidth)
                                    upperBound = cornerY+(fromIntegral count*triWidth)
                                    lowerBound = cornerY
                                    in leftBound <= x && x <= rightBound && lowerBound <= y && y<=upperBound
                                    else if selector addr == Just 3 then
                                    let
                                    rightBound = cornerX+(fromIntegral(addr-11)*triWidth)
                                    leftBound  = cornerX+(fromIntegral(addr-12)*triWidth)
                                    upperBound = cornerY+h
                                    lowerBound = cornerY+h-(fromIntegral count*triWidth)
                                    in  leftBound <= x && x <= rightBound && lowerBound <= y && y<=upperBound
                                    else (selector addr == Just 4) && (
                                    let
                                    leftBound  = cornerX+w+frameWidth+(fromIntegral(addr-18)*triWidth)
                                    rightBound = cornerX+w+frameWidth+(fromIntegral(addr-17)*triWidth)
                                    upperBound = cornerY+h
                                    lowerBound = cornerY+h-(fromIntegral count*triWidth)
                                    in  leftBound <= x && x <= rightBound && lowerBound <= y && y<=upperBound) where
                                        count = getCount $ getFromEnv world addr



whichPoint :: HaskGammon -> (Float, Float) -> Maybe Int
whichPoint world (x,y) = whichPoint' world (x,y) [ k | k<- [0..23], isPlayable world k]

whichPoint' :: HaskGammon -> (Float, Float) -> [Int] -> Maybe Int
whichPoint' world (x,y) [] = Nothing
whichPoint' world (x,y) (l:ls)= if isPoint world (x,y) l then Just l else whichPoint' world (x,y) ls

isPoint :: HaskGammon -> (Float, Float) -> Int -> Bool
isPoint world (x,y) addr = if selector addr == Just 1 then let
                                    leftBound  = cornerX+(w+frameWidth+ (fromIntegral(5-addr)*triWidth))
                                    rightBound = cornerX+(w+frameWidth+ (fromIntegral(6-addr)*triWidth))
                                    upperBound = cornerY+(fromIntegral (count+1)*triWidth)
                                    lowerBound = cornerY+(fromIntegral count*triWidth)
                                    in leftBound <= x && x <= rightBound && lowerBound <= y && y<=upperBound
                                    else if selector addr == Just 2 then
                                    let
                                    leftBound  = cornerX+(fromIntegral(11-addr)*triWidth)
                                    rightBound = cornerX+(fromIntegral(12-addr)*triWidth)
                                    upperBound = cornerY+(fromIntegral (count+1)*triWidth)
                                    lowerBound = cornerY+(fromIntegral count*triWidth)
                                    in leftBound <= x && x <= rightBound && lowerBound <= y && y<=upperBound
                                    else if selector addr == Just 3 then
                                    let
                                    rightBound = cornerX+(fromIntegral(addr-11)*triWidth)
                                    leftBound  = cornerX+(fromIntegral(addr-12)*triWidth)
                                    upperBound = cornerY+h-(fromIntegral count*triWidth)
                                    lowerBound = cornerY+h-(fromIntegral (count+1)*triWidth)
                                    in  leftBound <= x && x <= rightBound && lowerBound <= y && y<=upperBound
                                    else (selector addr == Just 4) && (
                                    let
                                    leftBound  = cornerX+w+frameWidth+(fromIntegral(addr-18)*triWidth)
                                    rightBound = cornerX+w+frameWidth+(fromIntegral(addr-17)*triWidth)
                                    upperBound = cornerY+h-(fromIntegral count*triWidth)
                                    lowerBound = cornerY+h-(fromIntegral (count+1)*triWidth)
                                    in  leftBound <= x && x <= rightBound && lowerBound <= y && y<=upperBound) where
                                        count = getCount $ getFromEnv world addr


