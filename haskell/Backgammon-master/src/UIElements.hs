module UIElements where

import Graphics.Gloss.Interface.IO.Game ( makeColor, Color )


backgroundColor :: Color
backgroundColor = makeColor (0/255) (0/255) (0/255) 1

quadColor :: Color
quadColor = makeColor (255/255) (191/255) (0/255) (255/255)

redChipColor :: Color
redChipColor = makeColor (222/255) (49/255) (99/255) (255/255)

whiteChipColor :: Color
whiteChipColor = makeColor (253/255) (254/255) (254/255) (255/255)

evenTrackColor :: Color
evenTrackColor = makeColor (171/255) (235/255) (198/255) (255/255)

oddTrackColor :: Color
oddTrackColor = makeColor (171/255) (178/255) (185/255) (255/255)

focusColor :: Color
focusColor = makeColor (252/255) (255/255) (0/255) (255/255)

fTrackColor :: Color
fTrackColor = makeColor (44/255) (62/255) (80/255) (255/255)

menuColor :: Color
menuColor = makeColor (163/255) (228/255) (215/255) (255/255)

textColor :: Color
textColor = makeColor (52/255) (73/255) (94/255) (255/255)

