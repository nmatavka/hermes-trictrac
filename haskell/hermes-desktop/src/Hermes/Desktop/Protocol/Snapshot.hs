{-# LANGUAGE OverloadedStrings #-}

module Hermes.Desktop.Protocol.Snapshot
  ( GameSnapshot (..),
    VariantSnapshot (..),
    ViewerSnapshot (..),
    UiActionsSnapshot (..),
  )
where

import Data.Aeson
import Data.Aeson.Types (Parser)
import Data.Text (Text)
import qualified Data.Text as Text

data GameSnapshot = GameSnapshot
  { matchPayload :: Value,
    variantSnapshot :: Maybe VariantSnapshot,
    viewerSnapshot :: Maybe ViewerSnapshot,
    openingRollPayload :: Maybe Value,
    pendingMatchOptionsPayload :: Maybe Value,
    pendingTurnDecisionPayload :: Maybe Value,
    poulePayload :: Maybe Value,
    multiplayerPayload :: Maybe Value,
    uiActionsSnapshot :: Maybe UiActionsSnapshot
  }
  deriving (Eq, Show)

data VariantSnapshot = VariantSnapshot
  { variantSnapshotId :: Text,
    variantSnapshotActiveVariantId :: Maybe Text
  }
  deriving (Eq, Show)

data ViewerSnapshot = ViewerSnapshot
  { viewerId :: Maybe Text,
    viewerName :: Maybe Text,
    viewerRole :: Maybe Text,
    viewerSeatColor :: Maybe Text
  }
  deriving (Eq, Show)

data UiActionsSnapshot = UiActionsSnapshot
  { canRollForOrder :: Bool
  }
  deriving (Eq, Show)

instance FromJSON GameSnapshot where
  parseJSON = withObject "GameSnapshot" $ \object ->
    GameSnapshot
      <$> object .:? "match" .!= Object mempty
      <*> object .:? "variant"
      <*> object .:? "viewer"
      <*> object .:? "opening_roll"
      <*> object .:? "pending_match_options"
      <*> object .:? "pending_turn_decision"
      <*> object .:? "poule"
      <*> object .:? "multiplayer"
      <*> object .:? "ui_actions"

instance FromJSON VariantSnapshot where
  parseJSON = withObject "VariantSnapshot" $ \object ->
    VariantSnapshot
      <$> object .: "id"
      <*> object .:? "active_variant_id"

instance FromJSON ViewerSnapshot where
  parseJSON = withObject "ViewerSnapshot" $ \object ->
    ViewerSnapshot
      <$> textish object "id"
      <*> object .:? "name"
      <*> object .:? "role"
      <*> object .:? "seat_color"

instance FromJSON UiActionsSnapshot where
  parseJSON = withObject "UiActionsSnapshot" $ \object ->
    UiActionsSnapshot
      <$> object .:? "can_roll_for_order" .!= False

textish :: Object -> Text -> Parser (Maybe Text)
textish object key = do
  maybeValue <- object .:? key
  pure $
    case maybeValue of
      Nothing -> Nothing
      Just (String value) -> Just value
      Just other -> Just (renderValue other)

renderValue :: Value -> Text
renderValue (String value) = value
renderValue (Number number) = Text.pack (show number)
renderValue (Bool boolean) = if boolean then "true" else "false"
renderValue Null = ""
renderValue _other = "<object>"
