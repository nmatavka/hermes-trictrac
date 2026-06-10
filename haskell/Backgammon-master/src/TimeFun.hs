module TimeFun where


import Components
import Data.Maybe (fromMaybe)


checkWinner :: Game -> Game
checkWinner game = do
    let (Game oldBoard _ player _ _) = game
    let (bar, quads) = oldBoard

    case player of
        (PlayerWhite _) -> checkQuad (head quads) bar player
        (PlayerRed _)   -> checkQuad (quads!!3) bar player
    where
        checkQuad :: Quad -> Bar -> Player -> Game
        checkQuad quad _ player = if isQuadFull quad player
                                  then game { state_=GameOver (Just player) }
                                  else game

        isQuadFull :: Quad -> Player -> Bool
        isQuadFull quad player = case player of
            PlayerWhite _ -> (countChips quad player)==15
            PlayerRed _ -> (countChips quad player)==15

        countChips :: Quad -> Player -> Int
        countChips tracks player = length chips
            where
                chips = filter (cmp playerChip) (concatMap getChips tracks)

                playerChip = getChipType player
                
                getChips :: Track -> [Pawn]
                getChips track = fromMaybe [] track
                
                getChipType :: Player -> Pawn
                getChipType player__ = case player__ of
                    PlayerWhite _ -> PawnWhite 0 False
                    PlayerRed _   -> PawnRed 0 False

                cmp :: Pawn -> Pawn -> Bool
                cmp chip testChip = case (chip, testChip) of
                    (PawnWhite _ _, PawnWhite _ _) -> True
                    (PawnRed _ _, PawnRed _ _)     -> True
                    _                              -> False
