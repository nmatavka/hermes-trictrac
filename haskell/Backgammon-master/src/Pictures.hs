module Pictures where

import Rules
import SideFun
import Effects
import UIElements
import Components
import Debug.Trace
import Graphics.Gloss
import Data.List (sortBy)


drawDice :: Player -> Dices -> Picture
drawDice _player ((d1, d2),(d3, d4)) = wCubesRendered <> rCubesRendered
    where
        wCubesRendered = renderCubes _player (PawnWhite 0 False)
        rCubesRendered = renderCubes _player (PawnRed 0 False)

        renderCubes :: Player -> Pawn -> Picture
        renderCubes player testPawn = case (player, testPawn) of
            (PlayerWhite _, PawnWhite _ _) -> renderFocusedCubes testPawn
            (PlayerRed _, PawnRed _ _)     -> renderFocusedCubes testPawn
            _                            -> justCubes testPawn

        renderFocusedCubes :: Pawn -> Picture
        renderFocusedCubes testPawn = case testPawn of
            (PawnWhite _ _) -> translate (3*cSize) 0 (fCube white (val_ d1))
                               <> translate (5*cSize) 0 (fCube white (val_ d2))
            (PawnRed _ _)   -> translate (-3*cSize) 0 (fCube redChipColor (val_ d3))
                               <> translate (-5*cSize) 0 (fCube redChipColor (val_ d4))

        justCubes :: Pawn -> Picture
        justCubes testPawn = case testPawn of
            (PawnWhite _ _) -> translate (3*cSize) 0 (cube white (val_ d1))
                               <> translate (5*cSize) 0 (cube white (val_ d2))
            (PawnRed _ _)   -> translate (-3*cSize) 0 (cube redChipColor (val_ d3))
                               <> translate (-5*cSize) 0 (cube redChipColor (val_ d4))

        cube :: Color -> Int -> Picture
        cube color_ x_ =  color color_ (rectangleSolid cSize cSize)
                          <> translate (-cSize/6) (-cSize/4.3) (scale 0.1 0.1 (text (show x_)))

        fCube :: Color -> Int -> Picture
        fCube color_ x_ = scale 1.5 1.5 $ color focusColor (rectangleSolid (1.3*cSize) (1.3*cSize))
                          <> color color_ (rectangleSolid cSize cSize)
                          <> translate (-cSize/6) (-cSize/4.3) (scale 0.1 0.1 (text (show x_)))

        cSize = 0.7*pawnRadius


drawPawn :: Pawn -> Picture
drawPawn pawn = case pawn of
    (PawnRed _ focus)   -> redPawn focus
    (PawnWhite _ focus) -> whitePawn focus

    where redPawn focus  = translate pawnRadius (size*pawnRadius)
                           $ scale size size
                           $ pawnShape redChipColor pawnRadius focus
              where size = s * focusSize focus

          whitePawn focus = translate pawnRadius (size*pawnRadius)
                            $ scale size size
                            $ pawnShape whiteChipColor pawnRadius focus
              where size = s * focusSize focus

          pawnShape color_ rad focus
              | focus     = color focusColor (circleSolid (rad+5)) <> color color_ (circleSolid rad) :: Picture
              | otherwise = color color_ (circleSolid rad) :: Picture

          focusSize :: Bool -> Float
          focusSize focus
              | focus     = 1.2
              | otherwise = 1.0


drawTrack :: Bool -> Track -> Color -> Picture
drawTrack isAllowedNext points trackColor = case points of
    Nothing      -> fTrackShape <> trackShape
    (Just pawns) -> fTrackShape <> trackShape <> pictures (map translatePawn (sortBy sortGT pawns))

    where trackShape = color trackColor $ polygon [(0,0),(pWidth,0),(pWidth*0.5,pHeight)]

          fTrackShape = if isAllowedNext
                        then color fTrackColor
                                   $ polygon [(-d,0),(pWidth+d,0),(d+pWidth*0.5,pHeight-d),
                                              (pWidth*0.5,pHeight+3*d),(-d+pWidth*0.5,pHeight)]
                        else blank

          d = 5

          translatePawn :: Pawn -> Picture
          translatePawn pawn = translate 0 (pos*2*pawnRadius*s) $ drawPawn pawn
              where pos = fromIntegral (pt_ pawn) :: Float

          sortGT pawn1 pawn2
              | isFocused_ pawn1 = GT
              | isFocused_ pawn2 = LT
              | otherwise = compare (pt_ pawn1) (pt_ pawn2)


drawBar :: Bar -> Picture
drawBar Nothing      = blank
drawBar (Just pawns) = pictures whitePictures <> pictures redPictures
      where
          whitePictures = map bChipRender ordWhites
          redPictures = map bChipRender ordReds

          bChipRender :: Pawn -> Picture
          bChipRender chip = scale 0.7 0.7
                             $ translate (-0.5*bWidth) h (drawPawn chip)
                   where h = case chip of
                               (PawnWhite _ _) -> -(fromIntegral screenHeight) - gap + 2*pawnRadius*fromIntegral (pt_ chip)
                               (PawnRed _ _)   ->  (fromIntegral screenHeight) + gap - 1.5*pawnRadius - 2*pawnRadius*fromIntegral (pt_ chip)
                         gap = (-qHeight/2)-pawnRadius

          (whiteChips, redChips) = groupChips pawns
          (Just ordWhites, Just ordReds) = (organiseTrack (Just whiteChips), organiseTrack (Just redChips))


{- Takes a list of tracks and indexes that are possible next moves -}
drawQuad :: [Track] -> [Int] -> Picture
drawQuad points goodMoves_
    = translate (-0.5*bWidth - qWidth) (-qHeight)
    $ translate (qWidth*0.5) (qHeight*0.5) (color quadColor (rectangleSolid qWidth qHeight))
    <> pictures (zipWith drawTractAt
                         points
                         (zip [ 5-i | i <- [0..(-1+length points)]] $ [ i `elem` nextMoves | i <- [0..5] ]))


    where drawTractAt :: Track -> (Int, Bool) -> Picture
          drawTractAt point (i, canBeNext) = translate (fromIntegral i*pWidth) 0 $ drawTrack canBeNext point trackColor
            where trackColor = if even i then evenTrackColor else oddTrackColor

          nextMoves = [ i `mod` 6 | i <- goodMoves_ ]


drawBoard :: Game -> Picture
drawBoard (Game oldBoard dices player state _) = renderWinner <> pictures boardFrame

    where (bar, quads) = setPt oldBoard

          boardFrame = allQuads ++ [drawDice player dices, drawBar bar]
          allQuads = zipWith translateQuad [ q1, q2, q3, q4 ]
                                           [ (qWidth+bWidth,0), (0,0), (0, qHeight), (qWidth+bWidth, qHeight) ]

          {- Function to place each quad at it's location -}
          translateQuad :: Picture -> (Float, Float) -> Picture
          translateQuad q (i,j) = translate i j q

          gMoves = goodMoves oldBoard (getPlayerDice player dices)

          q1Moves = filter (<=5) gMoves
          q2Moves = filter (\idx -> idx >= 6 && idx <=11) gMoves
          q3Moves = filter (\idx -> idx >= 12 && idx <=17) gMoves
          q4Moves = filter (>=18) gMoves

          {- Converting Each Quad to a picture -}
          q1 = drawQuad (head quads) q1Moves
          q2 = drawQuad (quads !! 1) q2Moves
          q3 = translate (-bWidth - qWidth) (-qHeight) $ rotate 180 $ drawQuad (quads !! 2) q3Moves
          q4 = translate (-bWidth - qWidth) (-qHeight) $ rotate 180 $ drawQuad (quads !! 3) q4Moves


          renderWinner = case state of
              (GameOver (Just winner)) -> (color menuColor $ rectangleSolid mWidth mHeight)
                         <> color red (translate (-250) 30 $ scale 0.4 0.4 $ text $ show (name_ winner) ++ " Wins")
                         <> translate 50 0 (color black (translate (-50) (-40) (rectangleSolid 250 60)))
                         <> color white (translate (-50) (-50) $ scale 0.2 0.2 $ text "RESET")
              _ -> blank


{-  
    TODOS
    * Add numbers at top and bottom of quads
-}