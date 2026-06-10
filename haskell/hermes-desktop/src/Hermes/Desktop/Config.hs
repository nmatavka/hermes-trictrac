{-# LANGUAGE OverloadedStrings #-}

module Hermes.Desktop.Config
  ( OpponentMode (..),
    RunMode (..),
    DesktopConfig (..),
    defaultConfig,
    loadConfig,
  )
where

import Data.List (foldl')
import Data.Text (Text)
import qualified Data.Text as Text
import System.Environment (getArgs, lookupEnv)
import Text.Read (readMaybe)

data RunMode
  = LocalMode
  | OnlineMode
  deriving (Eq, Show)

data OpponentMode
  = HumanOpponent
  | AiOpponent
  deriving (Eq, Show)

data DesktopConfig = DesktopConfig
  { runMode :: RunMode,
    serverUrl :: Text,
    localPort :: Int,
    playerName :: Text,
    lobbyName :: Text,
    variantId :: Text,
    opponentMode :: OpponentMode,
    supportRootOverride :: Maybe FilePath
  }
  deriving (Eq, Show)

defaultConfig :: DesktopConfig
defaultConfig =
  DesktopConfig
    { runMode = LocalMode,
      serverUrl = "http://127.0.0.1:4050",
      localPort = 4050,
      playerName = "Player",
      lobbyName = "desktop-local",
      variantId = "backgammon",
      opponentMode = HumanOpponent,
      supportRootOverride = Nothing
    }

loadConfig :: IO DesktopConfig
loadConfig = do
  args <- getArgs
  envConfig <- loadEnvConfig
  pure (applyArgs envConfig args)

loadEnvConfig :: IO DesktopConfig
loadEnvConfig = do
  modeValue <- lookupEnv "HERMES_DESKTOP_MODE"
  serverValue <- lookupEnv "HERMES_DESKTOP_SERVER_URL"
  portValue <- lookupEnv "HERMES_DESKTOP_LOCAL_PORT"
  playerValue <- lookupEnv "HERMES_DESKTOP_PLAYER_NAME"
  lobbyValue <- lookupEnv "HERMES_DESKTOP_LOBBY"
  variantValue <- lookupEnv "HERMES_DESKTOP_VARIANT"
  opponentValue <- lookupEnv "HERMES_DESKTOP_OPPONENT"
  supportRootValue <- lookupEnv "HERMES_DESKTOP_SUPPORT_ROOT"

  pure $
    defaultConfig
      { runMode = maybe (runMode defaultConfig) parseMode modeValue,
        serverUrl = maybe (serverUrl defaultConfig) Text.pack serverValue,
        localPort = maybe (localPort defaultConfig) parsePort portValue,
        playerName = maybe (playerName defaultConfig) Text.pack playerValue,
        lobbyName = maybe (lobbyName defaultConfig) Text.pack lobbyValue,
        variantId = maybe (variantId defaultConfig) Text.pack variantValue,
        opponentMode = maybe (opponentMode defaultConfig) parseOpponent opponentValue,
        supportRootOverride = supportRootValue
      }

applyArgs :: DesktopConfig -> [String] -> DesktopConfig
applyArgs = foldl' applyArg

applyArg :: DesktopConfig -> String -> DesktopConfig
applyArg config argument =
  case break (== '=') argument of
    ("--mode", '=' : value) -> config {runMode = parseMode value}
    ("--server", '=' : value) -> config {serverUrl = Text.pack value}
    ("--local-port", '=' : value) -> config {localPort = parsePort value}
    ("--player", '=' : value) -> config {playerName = Text.pack value}
    ("--lobby", '=' : value) -> config {lobbyName = Text.pack value}
    ("--variant", '=' : value) -> config {variantId = Text.pack value}
    ("--opponent", '=' : value) -> config {opponentMode = parseOpponent value}
    ("--support-root", '=' : value) -> config {supportRootOverride = Just value}
    _ -> config

parseMode :: String -> RunMode
parseMode value =
  case Text.toLower (Text.pack value) of
    "online" -> OnlineMode
    _ -> LocalMode

parseOpponent :: String -> OpponentMode
parseOpponent value =
  case Text.toLower (Text.pack value) of
    "ai" -> AiOpponent
    _ -> HumanOpponent

parsePort :: String -> Int
parsePort value =
  case readMaybe value of
    Just portNumber -> portNumber
    Nothing -> localPort defaultConfig
