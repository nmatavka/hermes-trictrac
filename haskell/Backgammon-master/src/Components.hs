module Components where


type Dices = ((Die,Die), (Die,Die))

data Game = Game { board_     :: Board
                 , dice_      :: Dices
                 , player_    :: Player
                 , state_     :: State
                 , dieValues_ :: [Int]
                 } deriving (Eq, Show)

data Player = PlayerRed { name_::String } | PlayerWhite { name_::String }
  deriving (Eq, Show)

data State  = Running | GameOver (Maybe Player)
  deriving (Eq, Show)

type Board = (Bar, [Quad])

type Quad = [Track]

type Bar = Maybe [Pawn]

type Track = Maybe [Pawn]

data Pawn =    PawnRed { pt_::Int, isFocused_::Bool }
           | PawnWhite { pt_::Int, isFocused_::Bool }
  deriving (Eq, Show)

newtype Die = Die { val_::Int }
  deriving (Eq, Show)

-- Game Window Dimensions
screenWidth, screenHeight :: Int
screenWidth  = 1000
screenHeight = 700

expandWidth :: Float
expandWidth = 20

-- Checker Radius
pawnRadius :: Float
pawnRadius = 35

s :: Float
s = 0.85

-- Point Dimensions
pWidth, pHeight :: Float
pWidth = 2*pawnRadius
pHeight = fromIntegral screenHeight*0.85*0.5

-- Quad Dimensions
qWidth, qHeight :: Float
qWidth = 6*pWidth
qHeight = fromIntegral screenHeight*0.5

-- Bar Dimensions
bWidth, bHeight :: Float
bWidth = pawnRadius*2
bHeight = fromIntegral screenHeight

-- Menu Board Dimension
mWidth, mHeight :: Float
mWidth = fromIntegral screenWidth*0.7
mHeight = fromIntegral screenHeight*0.5

