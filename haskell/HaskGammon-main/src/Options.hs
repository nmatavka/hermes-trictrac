module Options where

import Graphics.Gloss

size :: Float 
size = 2

fps :: Int
fps  = 60

background :: Color
--background = makeColorI 0 123 0 0
background = black 
triWidth :: Float
triWidth = 40*size

triHeight :: Float
triHeight= triWidth*5

w :: Float
w = 6*triWidth

h :: Float
h= 500*size

frameWidth :: Float
frameWidth = 16