{-# LANGUAGE OverloadedStrings #-}

module Hermes.Desktop.Protocol.PhoenixFrame
  ( PhoenixFrame (..),
  )
where

import Data.Aeson
import Data.Aeson.Types (Parser)
import Data.Text (Text)
import qualified Data.Vector as Vector

data PhoenixFrame payload = PhoenixFrame
  { joinRef :: Maybe Text,
    frameRef :: Maybe Text,
    topic :: Text,
    event :: Text,
    payload :: payload
  }
  deriving (Eq, Show)

instance ToJSON payload => ToJSON (PhoenixFrame payload) where
  toJSON frame =
    toJSON
      [ maybe Null String (joinRef frame),
        maybe Null String (frameRef frame),
        String (topic frame),
        String (event frame),
        toJSON (payload frame)
      ]

instance FromJSON payload => FromJSON (PhoenixFrame payload) where
  parseJSON = withArray "PhoenixFrame" decodeFrameArray

decodeFrameArray :: FromJSON payload => Vector.Vector Value -> Parser (PhoenixFrame payload)
decodeFrameArray array
  | Vector.length array /= 5 = fail "Phoenix frame must contain 5 array elements."
  | otherwise =
      PhoenixFrame
        <$> maybeText (array Vector.! 0)
        <*> maybeText (array Vector.! 1)
        <*> parseJSON (array Vector.! 2)
        <*> parseJSON (array Vector.! 3)
        <*> parseJSON (array Vector.! 4)

maybeText :: Value -> Parser (Maybe Text)
maybeText Null = pure Nothing
maybeText value = Just <$> parseJSON value
