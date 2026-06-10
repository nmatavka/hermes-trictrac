module Graph where


import Graphics.Gloss

import Options
import Stack
import Environment
import Data.Type.Equality (outer)
import Data.Maybe


board :: [Picture]
board = [otherSide, oneSide] ++ triangles where
    otherSide = translate (-w-frameWidth ) 0 oneSide
    oneSide :: Picture
    oneSide = pictures [outerFrame, innerFrame] where
        innerFrame :: Picture
        innerFrame = translate ((w+frameWidth)/2) 0 innerFrame' where
            innerFrame' = color black $ rectangleSolid  w h
        outerFrame :: Picture
        outerFrame = uncurry translate align outerFrame' where
            outerFrame' = color white $ rectangleSolid (frameWidth*2+w) (frameWidth *2+h)
            align :: (Float, Float)
            align = ((w+frameWidth)/2, 0)
    triangles :: [Picture]
    triangles = map (pictures . triangles') [area1, area2, area3, area4] where
        area1 = translate (w+frameWidth) 0 triangle
        area2 = triangle
        area3 = translate (-2*w-frameWidth+triWidth) 0 $ rotate 180 triangle
        area4 = translate (w+frameWidth)             0 area3
        triangles' :: Picture -> [Picture]
        triangles' triang = [translate (l*triWidth) 0 triang | l<-[0..5]]
        triangle :: Picture
        triangle = translate 0 0 $ color blue $ polygon [
            (cornerX           , cornerY),
            (cornerX+triWidth  , cornerY),
            (cornerX+triWidth/2, cornerY+triHeight)]

cornerX :: Float
cornerX = -frameWidth/2-w
cornerY :: Float
cornerY = -h/2




drawEnv :: HaskGammon -> [Picture]
drawEnv world = drawEnvironment(env world) where
drawEnvironment :: Environment -> [Picture]
drawEnvironment (Env ls) = map drawTuples ls where
        drawTuples :: (Int, Int, Maybe Player) -> Picture
        drawTuples (_,0,_) = blank
        drawTuples (_,_,Nothing) = blank
        drawTuples (num, count, Just player) = pictures [drawPawn (num, rw, Just player) | rw <- [1..count]]
        drawPawn :: (Int, Int, Maybe Player) -> Picture
        drawPawn (_,_,Nothing) =  blank
        drawPawn (addr, row, Just player) = color col $ drawPawn' addr row where
                drawPawn' :: Int -> Int -> Picture
                drawPawn' addr row  | selector addr == Just 1 = translate (w+frameWidth+ (fromIntegral(5-addr)*triWidth)) (roww*triWidth)               pawn
                                    | selector addr == Just 2 = translate (fromIntegral (11-addr)*triWidth)               (roww*triWidth)               pawn
                                    | selector addr == Just 3 = translate (fromIntegral (addr-12)*triWidth)               (h-triWidth-(roww*triWidth))  pawn
                                    | selector addr == Just 4 = translate (w+frameWidth+(fromIntegral(addr-18)*triWidth)) (h-triWidth-(roww*triWidth )) pawn
                                    | otherwise  = blank where
                                        roww = fromIntegral row -1
                                        pawn :: Picture
                                        pawn =translate (cornerX+triWidth/2 ) (cornerY+triWidth/2) $ circleSolid (triWidth/2)
                col | player == Red = red
                    | otherwise = white

rollButton world | null (moves world) = rollButton' green
                 | otherwise          = rollButton' red

rollButton' :: Color -> Picture
rollButton' col =  translate (3*w/2) (4* triWidth ) $ makeBox col white "ROLL" (2*triWidth) triWidth

diceDisplay ::  HaskGammon -> Picture
diceDisplay world   | isNothing (dice world) = blank
                        | otherwise = translate (3*w/2) (3* triWidth ) $ makeBox black white (getIndex $ dice world) (2*triWidth) triWidth where
                            getIndex Nothing = ""
                            getIndex (Just (Dice (f,s))) = show f ++" " ++show s


turnDisplay ::  HaskGammon -> Picture
turnDisplay world   | turn world == White =  translate (-3*w/2) (3* triWidth ) $makeBox black white "White" (2*triWidth) triWidth
                    | otherwise = translate (-3*w/2) (3* triWidth ) $ makeBox black red "Red" (2*triWidth) triWidth

hitsRDisplay ::  HaskGammon -> Picture
hitsRDisplay world   = translate (-3*w/2) (-1* triWidth ) $makeBox black red (show (hitsR world)) (2*triWidth) triWidth
hitsWDisplay ::  HaskGammon -> Picture
hitsWDisplay world   = translate (-3*w/2) (-2* triWidth ) $makeBox black white (show (hitsW world)) (2*triWidth) triWidth

-- Test displays
sceneDisplay ::  HaskGammon -> Picture
sceneDisplay world   = translate (-3*w/2) (-3* triWidth ) $makeBox green orange (show (scene world)) (2*triWidth) triWidth

envDisplay ::  HaskGammon -> Picture
envDisplay world   = translate (-5*w/2) (-8* triWidth ) $makeBox black white (show (env world)) (2*triWidth) triWidth

selectedDp :: HaskGammon -> Picture
selectedDp world  | isNothing(selectedPawn world) = translate (-3*w/2) (0* triWidth ) $makeBox black white "nothing selected" (2*triWidth) triWidth
                  | otherwise = translate (-3*w/2) (0* triWidth ) $makeBox black white (show (selectedPawn world)) (2*triWidth) triWidth


--------------------------------




startDiceDisplayRed ::  HaskGammon -> Picture
startDiceDisplayRed world   | isNothing (startDiceRed world) = blank
                            | isJust (startDiceRed world)  = translate (-3*w/2) (5* triWidth ) $makeBox black red ("Start Value:" ++ show (sumDice world startDiceRed)) (4*triWidth) triWidth
                            | otherwise = blank

startDiceDisplayWhite :: HaskGammon -> Picture
startDiceDisplayWhite world | isNothing (startDiceWhite world) = blank
                            | isJust (startDiceWhite world)  = translate (-3*w/2) (6* triWidth ) $makeBox black white ("Start Value:" ++ show (sumDice world startDiceWhite)) (4*triWidth) triWidth
                            | otherwise = blank


movesDisplay ::  HaskGammon -> Picture
movesDisplay world      | null (moves world) = blank
                        | otherwise = translate (3*w/2) (2* triWidth ) $ makeBox black white (getIndex $ moves world) (2*triWidth) triWidth where
                            getIndex [] = ""
                            getIndex (l:ls) = show (snd l) ++ " " ++ getIndex ls



drawPointer :: Int -> Int -> Picture
drawPointer addr row = color green $ drawPoint' addr row where
        drawPoint' :: Int -> Int -> Picture
        drawPoint' addr row | selector addr == Just 1 = translate (w+frameWidth+ (fromIntegral(5-addr)*triWidth)) (roww*triWidth)               point
                            | selector addr == Just 2 = translate (fromIntegral (11-addr)*triWidth)               (roww*triWidth)               point
                            | selector addr == Just 3 = translate (fromIntegral (addr-12)*triWidth)               (h-triWidth-(roww*triWidth))  point
                            | selector addr == Just 4 = translate (w+frameWidth+(fromIntegral(addr-18)*triWidth)) (h-triWidth-(roww*triWidth))  point
                            | otherwise  = blank where
                                roww = fromIntegral row -1
                                point :: Picture
                                point =translate (cornerX+triWidth/2 ) (cornerY+triWidth/2) $ circleSolid (triWidth/8)

base :: HaskGammon -> [(Int, Int, Maybe Player)]
base world = base' (env world) (turn world) where
     base' :: Environment -> Player -> [(Int, Int, Maybe Player)]
     base' (Env ls) trn  | trn  == Red    = [ k | k<-ls, (getAddr k) `elem` [18..23], getPawn k == Just Red ]
                    | otherwise      = [ k | k<-ls, (getAddr k) `elem` [0..5], getPawn k == Just White ]

getHits :: HaskGammon -> Int
getHits world | turn world == Red = hitsR world
              | otherwise         = hitsW world

isEmpty :: HaskGammon -> (Int, Int, Maybe Player) -> Bool
isEmpty wld (_,_,Nothing) = True
isEmpty wld (a,b,Just c)  = (turn wld == c) || (b == 1 && turn wld /= c)

drawPoints :: HaskGammon -> [Picture]
drawPoints world    | getHits world > 1 = let pointer' (x,y) = drawPointer x y in [pointer' (a, b + 1) |
                                             (a, b, c) <- base world, isEmpty world (a, b, c)]
                    | scene world `elem` [Start1,Start2, Roll Red, Roll White] = []
                    | otherwise = map drawPointer' (drawPoints' world) where
        drawPointer' (a,b) = drawPointer a (b+1)
        drawPoints' :: HaskGammon -> [(Int, Int)]
        drawPoints' world   | isNothing (selectedPawn world) = []
                            | funcFromEnv (env world) (fromJust (selectedPawn world)) getPawn == Just Red && turn world == Red     = [(k+ fromJust (selectedPawn world), getCount(getFromEnv world (fromJust (selectedPawn world)+k))) | k<-moves', isPlayable world (k+ fromJust (selectedPawn world))]
                            | funcFromEnv (env world) (fromJust (selectedPawn world)) getPawn == Just White && turn world == White = [(fromJust (selectedPawn world) -k, getCount(getFromEnv world (fromJust (selectedPawn world)-k))) | k<-moves', isPlayable world (fromJust (selectedPawn world)-k)]
                            | otherwise = [] where
                                moves' = map snd (moves world)







makeBox :: Color -> Color -> [Char] -> Float -> Float ->  Picture
makeBox col colstr str x y = pictures [color col $ rectangleSolid x y,inside]  where
    inside = translate (-x/3) (-y/5) $ color colstr$ scale (1/4) (1/4) $ text str