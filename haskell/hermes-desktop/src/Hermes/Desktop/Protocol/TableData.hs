{-# LANGUAGE OverloadedStrings #-}

module Hermes.Desktop.Protocol.TableData
  ( PointStack (..),
    LegalMove (..),
    gameFromChannelPayload,
    boardPoints,
    legalMoves,
    variantId,
    activeLegId,
    statusText,
    turnText,
    diceValues,
    actionEnabled,
    pendingChoices,
    pointSpace,
    spaceLabel,
    movePayload,
  )
where

import Data.Aeson
import Control.Applicative ((<|>))
import Data.Aeson.Key (fromText)
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.Vector as Vector
import Data.Text (Text)
import qualified Data.Text as Text
import Hermes.Desktop.Protocol.Snapshot

data PointStack = PointStack
  { pointIndex :: Int,
    pointPieces :: [Text]
  }
  deriving (Eq, Show)

data LegalMove = LegalMove
  { legalFrom :: Value,
    legalTo :: Value,
    legalDie :: Maybe Int,
    legalSequence :: Maybe Value,
    legalRaw :: Value
  }
  deriving (Eq, Show)

gameFromChannelPayload :: Value -> Maybe GameSnapshot
gameFromChannelPayload payload = do
  game <- lookupPath ["game"] payload <|> lookupPath ["response", "game"] payload
  case fromJSON game of
    Success snapshot -> Just snapshot
    Error _ -> Nothing

boardPoints :: GameSnapshot -> [PointStack]
boardPoints snapshot =
  case lookupPath ["board", "points"] (snapshotPayload snapshot) of
    Just (Array values) -> mapMaybePoint (Vector.toList values)
    _ -> []
  where
    mapMaybePoint = foldr (\value result -> maybe result (: result) (pointFromValue value)) []

legalMoves :: GameSnapshot -> [LegalMove]
legalMoves snapshot =
  case lookupPath ["legal_moves"] (snapshotPayload snapshot) of
    Just (Array values) -> mapMaybeMove (Vector.toList values)
    _ -> []
  where
    mapMaybeMove = foldr (\value result -> maybe result (: result) (moveFromValue value)) []

variantId :: GameSnapshot -> Text
variantId snapshot = textAt ["variant", "id"] (snapshotPayload snapshot) ""

activeLegId :: GameSnapshot -> Maybe Text
activeLegId snapshot = textAtMaybe ["variant", "active_leg", "id"] (snapshotPayload snapshot)

statusText :: GameSnapshot -> Text
statusText snapshot = textAt ["status"] (snapshotPayload snapshot) ""

turnText :: GameSnapshot -> Text
turnText snapshot =
  case lookupPath ["turn"] (snapshotPayload snapshot) of
    Just (Object object) ->
      let name = maybe "" id (valueText =<< KeyMap.lookup "player_name" object)
          color = maybe "" id (valueText =<< KeyMap.lookup "color" object)
       in if Text.null name then color else name <> " (" <> color <> ")"
    _ -> ""

diceValues :: GameSnapshot -> [Int]
diceValues snapshot =
  case lookupPath ["dice", "values"] (snapshotPayload snapshot) of
    Just (Array values) -> foldr (\value result -> maybe result (: result) (valueInt value)) [] (Vector.toList values)
    _ -> []

actionEnabled :: Text -> GameSnapshot -> Bool
actionEnabled action snapshot =
  case lookupPath ["ui_actions", action] (snapshotPayload snapshot) of
    Just (Bool value) -> value
    _ -> False

pendingChoices :: GameSnapshot -> [(Text, Text, Value)]
pendingChoices snapshot =
  case lookupPath ["pending_turn_decision", "choices"] (snapshotPayload snapshot) of
    Just (Array choices) ->
      [ ("submit_turn_decision", choice, object ["decision" .= choice])
        | String choice <- Vector.toList choices
      ]
    _ -> matchChoices
  where
    matchChoices =
      case textAtMaybe ["pending_match_options", "kind"] (snapshotPayload snapshot) of
        Just "tavli_target_consent" -> consentChoices "tavliTargetConsent" ["3", "5", "7", "9"]
        Just "trictrac_margot_consent" -> consentChoices "margotConsent" ["yes", "no"]
        Just "trictrac_partie_length_consent" -> consentChoices "aEcrirePartieLengthConsent" ["6", "8", "10", "12", "14", "16", "18", "20", "22", "24"]
        _ -> []
    consentChoices key choices =
      [ ("submit_match_options", choice, object ["options" .= object [fromText key .= choice]])
        | choice <- choices
      ]

pointSpace :: Int -> Value
pointSpace = Number . fromIntegral

spaceLabel :: Value -> Text
spaceLabel (Number number) = Text.pack (show (round number :: Int))
spaceLabel (String text) = text
spaceLabel Null = ""
spaceLabel _ = "?"

movePayload :: LegalMove -> Value
movePayload move =
  object $
    [ "move" .=
        object
          ( ["from" .= legalFrom move, "to" .= legalTo move]
              <> maybe [] (\sequence -> ["sequence" .= sequence]) (legalSequence move)
          )
    ]

pointFromValue :: Value -> Maybe PointStack
pointFromValue (Object object) = do
  index <- KeyMap.lookup "index" object >>= valueInt
  let pieces =
        case KeyMap.lookup "pieces" object of
          Just (Array values) -> foldr (\value result -> maybe result (: result) (valueText value)) [] (Vector.toList values)
          _ -> []
  pure (PointStack index pieces)
pointFromValue _ = Nothing

moveFromValue :: Value -> Maybe LegalMove
moveFromValue value@(Object object) = do
  from <- KeyMap.lookup "from" object
  to <- KeyMap.lookup "to" object
  let die = KeyMap.lookup "die" object >>= valueInt
      sequence = KeyMap.lookup "sequence" object
  pure (LegalMove from to die sequence value)
moveFromValue _ = Nothing

lookupPath :: [Text] -> Value -> Maybe Value
lookupPath [] value = Just value
lookupPath (key : rest) (Object object) = KeyMap.lookup (fromText key) object >>= lookupPath rest
lookupPath _ _ = Nothing

textAt :: [Text] -> Value -> Text -> Text
textAt path value fallback = maybe fallback id (textAtMaybe path value)

textAtMaybe :: [Text] -> Value -> Maybe Text
textAtMaybe path value = lookupPath path value >>= valueText

valueText :: Value -> Maybe Text
valueText (String text) = Just text
valueText (Number number) = Just (Text.pack (show (round number :: Int)))
valueText _ = Nothing

valueInt :: Value -> Maybe Int
valueInt (Number number) = Just (round number)
valueInt _ = Nothing
