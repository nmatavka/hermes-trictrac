{-# LANGUAGE OverloadedStrings #-}

module Hermes.Desktop.Catalog
  ( DesktopCatalog (..),
    VariantCatalogEntry (..),
    LocalAiInfo (..),
    DesktopLobby (..),
    SessionFormat (..),
    JoinField (..),
    loadDesktopCatalog,
    fetchDesktopCatalog,
    localVariants,
    sessionVariants,
    primaryVariants,
    moreVariants,
    tavliVariant,
  )
where

import Data.Aeson
import qualified Data.ByteString.Lazy as Lazy
import Data.List (find, sortOn)
import Data.Maybe (isJust)
import Data.Text (Text)
import Control.Exception (SomeException, try)
import Hermes.Desktop.Paths (SupportPaths (..))
import qualified Network.HTTP.Simple as Http

data DesktopCatalog = DesktopCatalog
  { schemaVersion :: Int,
    variants :: [VariantCatalogEntry],
    lobby :: DesktopLobby
  }
  deriving (Eq, Show)

data VariantCatalogEntry = VariantCatalogEntry
  { variantId :: Text,
    variantTitle :: Text,
    variantMenuLabel :: Maybe Text,
    variantFamily :: Text,
    variantSessionMode :: Maybe Text,
    variantSessionStyle :: Maybe Text,
    baseVariantId :: Maybe Text,
    onlinePlayable :: Bool,
    localPlayable :: Bool,
    localAi :: LocalAiInfo,
    menuSection :: Maybe Text,
    menuRank :: Int,
    selectionMode :: Text,
    memberIds :: [Text]
  }
  deriving (Eq, Show)

data LocalAiInfo = LocalAiInfo
  { aiAvailable :: Bool,
    aiKind :: Maybe Text,
    aiLabel :: Maybe Text,
    aiPresets :: [Text]
  }
  deriving (Eq, Show)

data DesktopLobby = DesktopLobby
  { multiSeatFormats :: [SessionFormat]
  }
  deriving (Eq, Show)

data SessionFormat = SessionFormat
  { sessionFormatId :: Text,
    sessionFormatKind :: Text,
    sessionFormatStyle :: Maybe Text,
    sessionFormatMultiplayerMode :: Maybe Text,
    sessionFormatTitle :: Text,
    sessionFormatMeta :: Text,
    sessionFormatJoinFields :: [JoinField]
  }
  deriving (Eq, Show)

data JoinField = JoinField
  { joinFieldId :: Text,
    joinFieldType :: Text,
    joinFieldDefault :: Value
  }
  deriving (Eq, Show)

instance FromJSON DesktopCatalog where
  parseJSON = withObject "DesktopCatalog" $ \object ->
    DesktopCatalog
      <$> object .: "schema_version"
      <*> object .: "variants"
      <*> object .:? "lobby" .!= DesktopLobby []

instance FromJSON VariantCatalogEntry where
  parseJSON = withObject "VariantCatalogEntry" $ \object ->
    VariantCatalogEntry
      <$> object .: "id"
      <*> object .: "title"
      <*> object .:? "menu_label"
      <*> object .: "family"
      <*> object .:? "session_mode"
      <*> object .:? "session_style"
      <*> object .:? "base_variant_id"
      <*> object .: "online_playable"
      <*> object .: "local_playable"
      <*> object .: "local_ai"
      <*> object .:? "menu_section"
      <*> object .:? "menu_rank" .!= 999
      <*> object .:? "selection_mode" .!= "single"
      <*> object .:? "members" .!= []

instance FromJSON LocalAiInfo where
  parseJSON = withObject "LocalAiInfo" $ \object ->
    LocalAiInfo
      <$> object .: "available"
      <*> object .:? "kind"
      <*> object .:? "label"
      <*> object .:? "presets" .!= []

instance FromJSON DesktopLobby where
  parseJSON = withObject "DesktopLobby" $ \object ->
    DesktopLobby <$> object .:? "multi_seat_formats" .!= []

instance FromJSON SessionFormat where
  parseJSON = withObject "SessionFormat" $ \object ->
    SessionFormat
      <$> object .: "id"
      <*> object .: "session_kind"
      <*> object .:? "style"
      <*> object .:? "multiplayer_mode"
      <*> object .: "title"
      <*> object .: "meta"
      <*> object .:? "join_fields" .!= []

instance FromJSON JoinField where
  parseJSON = withObject "JoinField" $ \object ->
    JoinField
      <$> object .: "id"
      <*> object .: "type"
      <*> object .: "default"

loadDesktopCatalog :: SupportPaths -> IO DesktopCatalog
loadDesktopCatalog paths = do
  bytes <- Lazy.readFile (desktopCatalogPath paths)

  case eitherDecode bytes of
    Left message -> fail ("Unable to decode desktop catalog: " <> message)
    Right catalog -> pure catalog

fetchDesktopCatalog :: String -> IO (Maybe DesktopCatalog)
fetchDesktopCatalog baseUrl = do
  result <-
    (try $ do
       request <- Http.parseRequest (dropTrailingSlash baseUrl <> "/api/desktop/catalog")
       response <- Http.httpLBS request
       pure (eitherDecode (Http.getResponseBody response))
    ) :: IO (Either SomeException (Either String DesktopCatalog))
  pure $ case result of
    Right (Right catalog) -> Just catalog
    _ -> Nothing

dropTrailingSlash :: String -> String
dropTrailingSlash value = reverse (dropWhile (== '/') (reverse value))

localVariants :: DesktopCatalog -> [VariantCatalogEntry]
localVariants catalog = filter localPlayable (variants catalog)

sessionVariants :: DesktopCatalog -> [VariantCatalogEntry]
sessionVariants catalog = filter (isJust . variantSessionMode) (variants catalog)

primaryVariants :: DesktopCatalog -> [VariantCatalogEntry]
primaryVariants catalog = sortOn menuRank $ filter ((== Just "primary") . menuSection) (variants catalog)

moreVariants :: DesktopCatalog -> [VariantCatalogEntry]
moreVariants catalog = sortOn menuRank $ filter ((== Just "more") . menuSection) (variants catalog)

tavliVariant :: DesktopCatalog -> Maybe VariantCatalogEntry
tavliVariant catalog = find ((== "tavli") . variantId) (variants catalog)
