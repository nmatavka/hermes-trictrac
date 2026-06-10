module MyLib where

import System.Random
import Data.Char (isDigit)
import GHC.IO (unsafePerformIO)

myArray :: [Int]
myArray = drop 1000 $ randomRs (1, 6) (mkStdGen seed)
    where
        seed = mrg (unsafePerformIO randomIO)
        mrg x = x `mod` 6 + 1
    

-- | function to check if element exists in array of integers 
exists :: Int -> [Int] -> Bool
exists _ [] = False
exists val (x:xs) = (x == val) || exists val xs

-- | function to remove one occurence of value in array
removeOneOccurence :: Int ->  [Int] -> [Int]
removeOneOccurence _ [] = []
removeOneOccurence val (x:xs) = if val == x then xs else x : removeOneOccurence val xs

isLetterOrDigit :: Char -> Bool
isLetterOrDigit c = (c >= 'a' || c <= 'x') || (c >= '1' && c<='6')

charToInt :: Char -> Int
charToInt c = if isDigit c then fromEnum c - fromEnum '0' else fromEnum c - fromEnum 'a'

takeRange :: Int -> Int -> [a] -> [a]
takeRange i j l = take (j-i+1) (drop i l)

inv :: Int -> Int
inv 0 = 1
inv _ = 0