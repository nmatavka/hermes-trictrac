module Environment where

newtype Dice     = Dice (Int,Int)                              deriving (Show,Eq,Read)
data Player      = Red | White                                 deriving (Show,Eq,Read)
data Scene       = Start1 | Start2 | Roll Player | Play Player deriving (Show,Eq,Read) 
newtype Environment  = Env [(Int,Int,Maybe Player)]               deriving (Show,Eq,Read)


fmap :: ([(Int, Int, Maybe Player)] -> [a]) -> Environment -> [a]
fmap _ (Env []) = []
fmap f (Env ls) = f ls

f <$> (Env ls) = f ls


data HaskGammon = Stack {
    dice           :: Maybe Dice,
    moves          :: [(String, Int)],
    startDiceWhite :: Maybe Dice,
    startDiceRed   :: Maybe Dice,
    firstPlayer    :: Maybe Player,
    secondPlayer   :: Maybe Player,
    scene          :: Scene,
    turn           :: Player,
    selectedPawn   :: Maybe Int,
    env            :: Environment,
    rollNumber     :: Int,
    rolls          :: [Dice],
    hitsR          :: Int,
    hitsW          :: Int 
}

