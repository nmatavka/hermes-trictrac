module Main where

import Graphics.Gloss
import Graphics.Gloss.Interface.Pure.Game
import System.Random

import Data.Map 
import Data.Set (Set)
import qualified Data.Set as S

type Coords = (Int, Int, Int)

type Field = Map (Int, Int) Int
type My_random = (Int, StdGen)


data Stone = Stone
    {
        coords :: Coords
        ,color_of_stone :: Color
    }
data World = World
    { 
        field :: Field
        ,moveCube :: Int
        ,cube1 :: Int
        ,cube2 :: Int
        ,turn :: Int
        ,red_stones :: Int
        ,black_stones :: Int
        ,my_gen1 :: StdGen
        ,my_gen2 :: StdGen
        ,stoneRed_1 :: Stone
        ,stoneRed_2 :: Stone
        ,stoneRed_3 :: Stone
        ,stoneRed_4 :: Stone
        ,stoneRed_5 :: Stone


        ,stoneBlack_1 :: Stone
        ,stoneBlack_2 :: Stone
        ,stoneBlack_3 :: Stone
        ,stoneBlack_4 :: Stone
        ,stoneBlack_5 :: Stone

    }



window :: Display
window = InWindow "Backgammon" (600, 600) (10, 10)

background :: Color
background = white

getColor :: Stone -> Color
getColor stone = color_of_stone stone

drawing :: World -> Picture
drawing (

            World _ moveCube cube1 cube2 turn red_stones black_stones my_gen1 my_gen2

            (Stone (coordR1_x,coordR1_y, counter_of_stoneR1) color_of_stoneR1 )
            (Stone (coordR2_x,coordR2_y, counter_of_stoneR2) color_of_stoneR2 )
            (Stone (coordR3_x,coordR3_y, counter_of_stoneR3) color_of_stoneR3 )
            (Stone (coordR4_x,coordR4_y, counter_of_stoneR4) color_of_stoneR4 )
            (Stone (coordR5_x,coordR5_y, counter_of_stoneR5) color_of_stoneR5 )


            (Stone (coordB1_x,coordB1_y, counter_of_stoneB1) color_of_stoneB1 )
            (Stone (coordB2_x,coordB2_y, counter_of_stoneB2) color_of_stoneB2 )
            (Stone (coordB3_x,coordB3_y, counter_of_stoneB3) color_of_stoneB3 )
            (Stone (coordB4_x,coordB4_y, counter_of_stoneB4) color_of_stoneB4 )
            (Stone (coordB5_x,coordB5_y, counter_of_stoneB5) color_of_stoneB5 )


        ) = 
            if (red_stones == 0) then 
                (pictures [
                        translate (-550) (-150) $ scale (700/16) (700/16) $ pictures [ Color green $ translate (fromIntegral 0) (fromIntegral 0) .scale (1/32) (1/32) . color red . text $  text_red_win]
                    ]) 
                else (if (black_stones == 0) 
                    then (pictures [
                        translate (-550) (-150) $ scale (700/16) (700/16) $ pictures [ Color green $ translate (fromIntegral 0) (fromIntegral 0) .scale (1/32) (1/32) . color black . text $  text_black_win]
                    ]) 
            else (pictures [
    translate (-500) 450 $ scale 700 700 chess 
    ,translate (-500) 450 $ scale 700 700 chess1
    ,translate (-500) 450 $ scale 700 700 chess2
    ,translate (-500) 450 $ scale 700 700 chess3
    ,translate (-500) 450 $ scale (700/16) (700/16) $  pictures [
                                                        Color color_of_stoneR1 $
                                                        translate (fromIntegral coordR1_x*2 + 1.5) (fromIntegral coordR1_y*2+0.5) $
                                                        Circle 1,
                                                        Color color_of_stoneR2 $
                                                        translate (fromIntegral coordR2_x*2 + 1.5) (fromIntegral coordR2_y*2+0.5) $
                                                        Circle 1,
                                                        Color color_of_stoneR3 $
                                                        translate (fromIntegral coordR3_x*2 + 1.5) (fromIntegral coordR3_y*2+0.5) $
                                                        Circle 1,
                                                        Color color_of_stoneR4 $
                                                        translate (fromIntegral coordR4_x*2 + 1.5) (fromIntegral coordR4_y*2+0.5) $
                                                        Circle 1,
                                                        Color color_of_stoneR5 $
                                                        translate (fromIntegral coordR5_x*2 + 1.5) (fromIntegral coordR5_y*2+0.5) $
                                                        Circle 1,

                                                        Color color_of_stoneB1 $
                                                        translate (fromIntegral coordB1_x*2 + 1.5) (fromIntegral coordB1_y*2+0.5) $
                                                        Circle 1,
                                                        Color color_of_stoneB2 $
                                                        translate (fromIntegral coordB2_x*2 + 1.5) (fromIntegral coordB2_y*2+0.5) $
                                                        Circle 1,
                                                        Color color_of_stoneB3 $
                                                        translate (fromIntegral coordB3_x*2 + 1.5) (fromIntegral coordB3_y*2+0.5) $
                                                        Circle 1,
                                                        Color color_of_stoneB4 $
                                                        translate (fromIntegral coordB4_x*2 + 1.5) (fromIntegral coordB4_y*2+0.5) $
                                                        Circle 1,
                                                        Color color_of_stoneB5 $
                                                        translate (fromIntegral coordB5_x*2 + 1.5) (fromIntegral coordB5_y*2+0.5) $
                                                        Circle 1
                                                        
                                                    ]
    
        
    ,translate (-850) (0) $ scale (700/16) (700/16) $ pictures [ Color black $ translate (fromIntegral 0) (fromIntegral 0) $ rectangleWire 3 3]
    ,translate (-650) (0) $ scale (700/16) (700/16) $ pictures [ Color black $ translate (fromIntegral 0) (fromIntegral 0) $ rectangleWire 3 3]
    ,translate (-880) (-30) $ scale (700/16) (700/16) $ pictures [ Color green $ translate (fromIntegral 0) (fromIntegral 0) .scale (1/64) (1/64) . color (if (turn < 2) then red else black) . text $ show cube1]
    ,translate (-680) (-30) $ scale (700/16) (700/16) $ pictures [ Color green $ translate (fromIntegral 0) (fromIntegral 0) .scale (1/64) (1/64) . color (if (turn < 2) then red else black) . text $ show cube2]
    ,translate (-530) (-30) $ scale (700/16) (700/16) $ pictures [ Color green $ translate (fromIntegral 0) (fromIntegral 0) .scale (1/128) (1/128) . color (if (turn < 2) then red else black) . text $ show moveCube]
    
    ,translate (-950) 250 $ scale (700/16) (700/16) $ pictures [ Color green $ translate (fromIntegral 0) (fromIntegral 0) .scale (1/64) (1/64) . color red . text $ show red_stones]
    ,translate (-950) (-200) $ scale (700/16) (700/16) $ pictures [ Color green $ translate (fromIntegral 0) (fromIntegral 0) .scale (1/64) (1/64) . color black . text $ show black_stones]

    ,translate (-850) 250 $ scale (700/16) (700/16) $ pictures [ Color green $ translate (fromIntegral 0) (fromIntegral 0) .scale (1/64) (1/64) . color red . text $  text_for_information]
    ,translate (-850) (-200) $ scale (700/16) (700/16) $ pictures [ Color green $ translate (fromIntegral 0) (fromIntegral 0) .scale (1/64) (1/64) . color black . text $  text_for_information]

    ,translate (-950) 150 $ scale (700/16) (700/16) $ pictures [ Color green $ translate (fromIntegral 0) (fromIntegral 0) .scale (1/64) (1/64) . color red . text $  text_for_information_under]
    ,translate (-950) (-300) $ scale (700/16) (700/16) $ pictures [ Color green $ translate (fromIntegral 0) (fromIntegral 0) .scale (1/64) (1/64) . color black . text $  text_for_information_under]
    ]))

text_red_win = "RED WIN!"
text_black_win = "BLACK WIN!"
text_for_information = "stones"
text_for_information_under = "left to win"

xor a b = a /= b
dist x1 x2 y1 y2 = ((floor((x1+480)/87.5)) - x2)*((floor((x1+480)/87.5)) - x2) + ((floor ((y1-430)/87.5)) - y2)*((floor ((y1-430)/87.5)) - y2)
check x y field = if Data.Map.lookup (x y) field == Nothing then (x, y) else (x, y)

my_random :: StdGen -> (Int, StdGen)
my_random stdGen = (x, stdGen2)
    where (x, stdGen2) = (randomR (1, 6) stdGen)

insert_check x_old y_old x_new y_new type_of_stone field = 
    if (Data.Map.lookup (x_new, y_new) field == Nothing) then (Data.Map.delete (x_old, y_old) (Data.Map.insert (x_new, y_new) type_of_stone field)) 
    else (if (Data.Map.lookup (x_new, y_new) field == Just type_of_stone) 
        then (if (y_new > (-6)) then (insert_check x_old y_old x_new (y_new-1) type_of_stone field) else (insert_check x_old y_old x_new (y_new+1) type_of_stone field)) 
        else (Data.Map.insert (19, 14) type_of_stone field) )

transform_coords x move y type_of_stone counter_of_stone field = 
    if (counter_of_stone + move > 23) then (Data.Map.delete (x, y) field) else (if (y > (-6)) then 
        (if ((x-move) < 0) then (insert_check x y (move-x-1) (-10) type_of_stone field) 
        else (if ((x-move) < 7 && (x > 6)) then (insert_check x y (x-move-1) (-1) type_of_stone field) else (insert_check x y (x-move) (-1) type_of_stone field) )) 
        else (if ((x+move) > 12) then (insert_check x y (25-move-x) (-1) type_of_stone field)
        else (if ((x+move) > 5 && (x < 6)) then (insert_check x y (x+move+1) (-10) type_of_stone field) else (insert_check x y (x+move) (-10) type_of_stone field) )))

insert_check_stone x_old y_old x_new y_new type_of_stone counter_of_stone_old counter_of_stone_new field = 
    if (Data.Map.lookup (x_new, y_new) field == Nothing) then (x_new, y_new, counter_of_stone_new) 
    else (if (Data.Map.lookup (x_new, y_new) field == Just type_of_stone) 
        then (if (y_new > (-6)) then (insert_check_stone x_old y_old x_new (y_new-1) type_of_stone counter_of_stone_old counter_of_stone_new field) else (insert_check_stone x_old y_old x_new (y_new+1) type_of_stone counter_of_stone_old counter_of_stone_new field))  
        else (x_old, y_old, counter_of_stone_old))

transform_coords_stone x move y type_of_stone counter_of_stone field = 
    if (counter_of_stone + move > 23) then (19, 19, 24)  else (if (y > (-6)) then 
        (if ((x-move) < 0) then (insert_check_stone x y (move-x-1) (-10) type_of_stone counter_of_stone (counter_of_stone + move) field) 
        else (if ((x-move) < 7 && (x > 6)) then (insert_check_stone x y (x-move-1) (-1) type_of_stone counter_of_stone (counter_of_stone + move) field) else (insert_check_stone x y (x-move) (-1) type_of_stone counter_of_stone (counter_of_stone + move) field) )) 
        else (if ((x+move) > 12) then (insert_check_stone x y (25-move-x) (-1) type_of_stone counter_of_stone (counter_of_stone + move) field)
        else (if ((x+move) > 5 && (x < 6)) then (insert_check_stone x y (x+move+1) (-10) type_of_stone counter_of_stone (counter_of_stone + move) field) else (insert_check_stone x y (x+move) (-10) type_of_stone counter_of_stone (counter_of_stone + move) field) )))



chess = scale (1/16) (1/16) $ pictures [ lines x y | x <- [0, 2.. 24], y <- [0, 20], x /= 12]
 where lines x y =
          Color (if (xor ((mod x 4) == 0) (y == 20)) then red else black) $
          translate (fromIntegral x+0.5) (-fromIntegral y -0.5) $ 
          (if y == 20 then lineLoop [(0, 0),(1, 6)] else lineLoop [(0, 0),(1, -6)])

chess1 = scale (1/16) (1/16) $ pictures [lines x y | x <- [0, 2.. 24], y <- [0, 20], x /= 12]
 where lines x y =
          Color (if (xor ((mod x 4) == 0) (y == 20)) then red else black) $
          translate (fromIntegral x+0.5) (-fromIntegral y -0.5) $ 
          (if y == 20 then lineLoop [(1, 6),(2, 0)] else lineLoop [(1, -6),(2, 0)])

chess2 = scale (1/16) (1/16) $ pictures [lines x y | x <- [0, 2.. 24], y <- [0, 20]]
 where lines x y =
          (if x /= 12 then
            Color (if (xor ((mod x 4) == 0) (y == 20)) then red else black) $
            translate (fromIntegral x+0.5) (-fromIntegral y -0.5) $ lineLoop [(2, 0),(0, 0)]
          else
            (if y == 0 then
                Color black $
                translate (fromIntegral x+1.5) (-fromIntegral y-10.5) $ rectangleWire 2 20
            else
                Color black $
                translate (fromIntegral x+1.5) (-fromIntegral y+8) $ rectangleSolid 0 10))

chess3 = scale (1/16) (1/16) $ pictures [ lines x 0 | x <- [0, 26]]
 where lines x y =
          Color black $
          translate (fromIntegral x+0.5) (-fromIntegral y-0.5) $ 
          lineLoop [(0, 0),(0, -20)]

--rowMaker2 n k = [ n,n-1..n-k+1 ] : rowMaker2 (n-k) k


handleInput :: Event -> World -> World
handleInput (EventKey (MouseButton LeftButton) Down _ (x, y)) (
            World field moveCube cube1 cube2 turn red_stones black_stones my_gen1 my_gen2


            (Stone (coordR1_x,coordR1_y, counter_of_stoneR1) color_of_stoneR1 )
            (Stone (coordR2_x,coordR2_y, counter_of_stoneR2) color_of_stoneR2 )
            (Stone (coordR3_x,coordR3_y, counter_of_stoneR3) color_of_stoneR3 )
            (Stone (coordR4_x,coordR4_y, counter_of_stoneR4) color_of_stoneR4 )
            (Stone (coordR5_x,coordR5_y, counter_of_stoneR5) color_of_stoneR5 )


            (Stone (coordB1_x,coordB1_y, counter_of_stoneB1) color_of_stoneB1 )
            (Stone (coordB2_x,coordB2_y, counter_of_stoneB2) color_of_stoneB2 )
            (Stone (coordB3_x,coordB3_y, counter_of_stoneB3) color_of_stoneB3 )
            (Stone (coordB4_x,coordB4_y, counter_of_stoneB4) color_of_stoneB4 )
            (Stone (coordB5_x,coordB5_y, counter_of_stoneB5) color_of_stoneB5 )

        ) = (
            World field moveCube cube1 cube2 turn red_stones black_stones my_gen1 my_gen2

            (Stone (coordR1_x,coordR1_y, counter_of_stoneR1) color_of_stoneR1 )
            (Stone (coordR2_x,coordR2_y, counter_of_stoneR2) color_of_stoneR2 )
            (Stone (coordR3_x,coordR3_y, counter_of_stoneR3) color_of_stoneR3 )
            (Stone (coordR4_x,coordR4_y, counter_of_stoneR4) color_of_stoneR4 )
            (Stone (coordR5_x,coordR5_y, counter_of_stoneR5) color_of_stoneR5 )


            (Stone (coordB1_x,coordB1_y, counter_of_stoneB1) color_of_stoneB1 )
            (Stone (coordB2_x,coordB2_y, counter_of_stoneB2) color_of_stoneB2 )
            (Stone (coordB3_x,coordB3_y, counter_of_stoneB3) color_of_stoneB3 )
            (Stone (coordB4_x,coordB4_y, counter_of_stoneB4) color_of_stoneB4 )
            (Stone (coordB5_x,coordB5_y, counter_of_stoneB5) color_of_stoneB5 )
        ) 
    {
        
        
        
        red_stones = red_stones - personal_red_counter
        ,black_stones = black_stones - personal_black_counter

        ,stoneRed_1 = stone1 coordR1_x coordR1_y color_of_stoneR1 counter_of_stoneR1 field
        ,stoneRed_2 = stone1 coordR2_x coordR2_y color_of_stoneR2 counter_of_stoneR2 field
        ,stoneRed_3 = stone1 coordR3_x coordR3_y color_of_stoneR3 counter_of_stoneR3 field
        ,stoneRed_4 = stone1 coordR4_x coordR4_y color_of_stoneR4 counter_of_stoneR4 field
        ,stoneRed_5 = stone1 coordR5_x coordR5_y color_of_stoneR5 counter_of_stoneR5 field
        
        ,stoneBlack_1 = stone1 coordB1_x coordB1_y color_of_stoneB1 counter_of_stoneB1 field
        ,stoneBlack_2 = stone1 coordB2_x coordB2_y color_of_stoneB2 counter_of_stoneB2 field
        ,stoneBlack_3 = stone1 coordB3_x coordB3_y color_of_stoneB3 counter_of_stoneB3 field
        ,stoneBlack_4 = stone1 coordB4_x coordB4_y color_of_stoneB4 counter_of_stoneB4 field
        ,stoneBlack_5 = stone1 coordB5_x coordB5_y color_of_stoneB5 counter_of_stoneB5 field

        ,field = field1 0

        ,cube1 = if ( ((turn == 1) && (click_red)) || ((turn == 3) && (click_black)) ) then ff else cube1
        ,cube2 = if ( ((turn == 1) && (click_red)) || ((turn == 3) && (click_black)) ) then kk else cube2
        ,my_gen1 = if ( ((turn == 1) && (click_red)) || ((turn == 3) && (click_black)) ) then gg else my_gen1
        ,my_gen2 = if ( ((turn == 1) && (click_red)) || ((turn == 3) && (click_black)) ) then hh else my_gen2
        

        
        ,moveCube = if (click_red || click_black) then (if (moveCube == (if ( ((turn == 1) && (click_red)) || ((turn == 3) && (click_black)) ) then ff else cube1)) then (if ( ((turn == 1) && (click_red)) || ((turn == 3) && (click_black)) ) then kk else cube2) else (if ( ((turn == 1) && (click_red)) || ((turn == 3) && (click_black)) ) then ff else cube1)) else moveCube
        ,turn = if ((turn == 0) && (click_red)) then 1 else (if ((turn == 1) && (click_red)) then 2 else (if ((turn == 2) && (click_black)) then 3 
        else (if ((turn == 3) && (click_black)) then 0 else turn)))

    } where 
        (ff, gg) = (my_random my_gen1)
        (kk, hh) = (my_random my_gen2)

        click_red = (((dist x coordR1_x y coordR1_y) < 1) || ((dist x coordR2_x y coordR2_y) < 1) || ((dist x coordR3_x y coordR3_y) < 1) || ((dist x coordR4_x y coordR4_y) < 1) || ((dist x coordR5_x y coordR5_y) < 1)) 
        click_black = (((dist x coordB1_x y coordB1_y) < 1) || ((dist x coordB2_x y coordB2_y) < 1) || ((dist x coordB3_x y coordB3_y) < 1) || ((dist x coordB4_x y coordB4_y) < 1) || ((dist x coordB5_x y coordB5_y) < 1)) 
        

        field0 marker coordR_x coordR_y type_of_stone counter_of_stone my_field = if ((dist x coordR_x y coordR_y) < 1) then (transform_coords coordR_x moveCube coordR_y type_of_stone counter_of_stone my_field) else (my_field)
        
        field1 marker = 
            field0 marker coordR1_x coordR1_y 1 counter_of_stoneR1
                (field0 marker coordR2_x coordR2_y 1 counter_of_stoneR2
                    (field0 marker coordR3_x coordR3_y 1 counter_of_stoneR3
                        (field0 marker coordR4_x coordR4_y 1 counter_of_stoneR4
                            (field0 marker coordR5_x coordR5_y 1 counter_of_stoneR5
                                (field0 marker coordB1_x coordB1_y 2 counter_of_stoneB1
                                    (field0 marker coordB2_x coordB2_y 2 counter_of_stoneB2
                                        (field0 marker coordB3_x coordB3_y 2 counter_of_stoneB3
                                            (field0 marker coordB4_x coordB4_y 2 counter_of_stoneB4
                                                (field0 marker coordB5_x coordB5_y 2 counter_of_stoneB5 field)))))))))

        personal_red_counter = 
            if ((dist x coordR1_x y coordR1_y) < 1) then (div (counter_of_stoneR1 + moveCube) 24) 
            else (if ((dist x coordR2_x y coordR2_y) < 1) then (div (counter_of_stoneR2 + moveCube) 24) 
            else (if ((dist x coordR3_x y coordR3_y) < 1) then (div (counter_of_stoneR3 + moveCube) 24)
            else (if ((dist x coordR4_x y coordR4_y) < 1) then (div (counter_of_stoneR4 + moveCube) 24)
            else (if ((dist x coordR5_x y coordR5_y) < 1) then (div (counter_of_stoneR5 + moveCube) 24) else 0))))
        
        personal_black_counter = 
            if ((dist x coordB1_x y coordB1_y) < 1) then (div (counter_of_stoneB1 + moveCube) 24) 
            else (if ((dist x coordB2_x y coordB2_y) < 1) then (div (counter_of_stoneB2 + moveCube) 24) 
            else (if ((dist x coordB3_x y coordB3_y) < 1) then (div (counter_of_stoneB3 + moveCube) 24)
            else (if ((dist x coordB4_x y coordB4_y) < 1) then (div (counter_of_stoneB4 + moveCube) 24)
            else (if ((dist x coordB5_x y coordB5_y) < 1) then (div (counter_of_stoneB5 + moveCube) 24) else 0))))

        stone1 coord_x coord_y color_of_stone counter_of_stone my_field = 
            (Stone (if ((dist x coord_x y coord_y) < 1) then (transform_coords_stone coord_x moveCube coord_y (if color_of_stone == red then 1 else 2) counter_of_stone my_field) else (coord_x, coord_y, counter_of_stone)) color_of_stone )

handleInput _ world = world

update :: Float -> World -> World
update _ world = world

render :: World -> Picture
render world = drawing world

main :: IO ()
main
 = do   
        play 
            window 
            background 
            60 
            initWorld 
            render
            handleInput 
            Main.update 
    where
        initWorld = World 
                        (Data.Map.insert (0, (-10)) 1 (Data.Map.insert (0, (-9)) 1 (Data.Map.insert (0, (-8)) 1 (Data.Map.insert (0, (-7)) 1 (Data.Map.insert (0, (-6)) 1 (Data.Map.insert (12, (-1)) 2 (Data.Map.insert (12, (-2)) 2 (Data.Map.insert (12, (-3)) 2 (Data.Map.insert (12, (-4)) 2 (Data.Map.insert (12, (-5)) 2 Data.Map.empty))))))))))
                        3 
                        3
                        6
                        0
                        5
                        5
                        (mkStdGen 50)
                        (mkStdGen 20)
                        (Stone (0,(-10), 0) red)
                        (Stone (0,(-9), 0) red)
                        (Stone (0,(-8), 0) red)
                        (Stone (0,(-7), 0) red)
                        (Stone (0,(-6), 0) red)


                        (Stone (12,(-1), 0) black)
                        (Stone (12,(-2), 0) black)
                        (Stone (12,(-3), 0) black)
                        (Stone (12,(-4), 0) black)
                        (Stone (12,(-5), 0) black)


