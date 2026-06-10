{-# LANGUAGE OverloadedStrings #-}

module Hermes.Desktop.Catalog
  ( DesktopCatalog (..),
    VariantCatalogEntry (..),
    LocalAiInfo (..),
    loadDesktopCatalog,
    localVariants,
    sessionVariants,
  )
where

import Data.Aeson
import qualified Data.ByteString.Lazy as Lazy
import Data.Text (Text)
import Hermes.Desktop.Paths (SupportPaths (..))

data DesktopCatalog = DesktopCatalog
  { schemaVersion :: Int,
    variants :: [VariantCatalogEntry]
  }
  deriving (Eq, Show)

data VariantCatalogEntry = VariantCatalogEntry
  { variantId :: Text,
    variantTitle :: Text,
    variantFamily :: Text,
    variantSessionMode :: Maybe Text,
    variantSessionStyle :: Maybe Text,
    baseVariantId :: Maybe Text,
    onlinePlayable :: Bool,
    localPlayable :: Bool,
    localAi :: LocalAiInfo
  }
  deriving (Eq, Show)

data LocalAiInfo = LocalAiInfo
  { aiAvailable :: Bool,
    aiKind :: Maybe Text,
    aiLabel :: Maybe Text,
    aiPresets :: [Text]
  }
  deriving (Eq, Show)

instance FromJSON DesktopCatalog where
  parseJSON = withObject "DesktopCatalog" $ \object ->
    DesktopCatalog
      <$> object .: "schema_version"
      <*> object .: "variants"

instance FromJSON VariantCatalogEntry where
  parseJSON = withObject "VariantCatalogEntry" $ \object ->
    VariantCatalogEntry
      <$> object .: "id"
      <*> object .: "title"
      <*> object .: "family"
      <*> object .:? "session_mode"
      <*> object .:? "session_style"
      <*> object .:? "base_variant_id"
      <*> object .: "online_playable"
      <*> object .: "local_playable"
      <*> object .: "local_ai"

instance FromJSON LocalAiInfo where
  parseJSON = withObject "LocalAiInfo" $ \object ->
    LocalAiInfo
      <$> object .: "available"
      <*> object .:? "kind"
      <*> object .:? "label"
      <*> object .:? "presets" .!= []

loadDesktopCatalog :: SupportPaths -> IO DesktopCatalog
loadDesktopCatalog paths = do
  bytes <- Lazy.readFile (desktopCatalogPath paths)

  case eitherDecode bytes of
    Left message -> fail ("Unable to decode desktop catalog: " <> message)
    Right catalog -> pure catalog

localVariants :: DesktopCatalog -> [VariantCatalogEntry]
localVariants catalog = filter localPlayable (variants catalog)

sessionVariants :: DesktopCatalog -> [VariantCatalogEntry]
sessionVariants catalog = filter (not . localPlayable) (variants catalog)
