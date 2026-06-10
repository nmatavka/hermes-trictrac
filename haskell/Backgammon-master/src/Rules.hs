module Rules where


import SideFun
import Effects
import Components
import Debug.Trace
{--
    Create a list of rules that can be sort of associative and if one fails,
    then everything fails
--}

{-- Switch Player --}
{-- Rearrange pawn heights --}

--  where
--      setBChips :: Track -> Track
--      setBChips = undefined


--{- Checks direction of Movement for a given pawn -}
--{- Check if pawn can move from one track id to the next track id: openTrackTest -}
--getAllowedMoves :: Board -> Die -> Die -> Pawn -> Bool
--getAllowedMoves board fTo dTo pawn = case pawn of
--    (PawnRed _ _)   -> (val_ dTo > val_ fTo) && (trackIsOpen pawn (val_ dTo))
--    (PawnWhite _ _) -> (val_ fTo > val_ dTo) && (trackIsOpen pawn (val_ fTo))
--    where
--        trackIsOpen :: Pawn -> Int -> Bool
--        trackIsOpen chip tIdx_ = do
--            let (qIdx, tIdx) = getTrackId tIdx_
--            let track = snd board !! qIdx !! tIdx
--            let (whiteCount, redCount) = trackContent track
--
--            case chip of
--                (PawnWhite _ _) -> redCount<=1
--                (PawnRed _ _)   -> whiteCount<=1

