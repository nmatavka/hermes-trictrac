{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE OverloadedStrings #-}

module Hermes.Desktop.Runtime.Local
  ( LocalRuntimeHandle (..),
    maybeLaunchLocalRuntime,
    stopLocalRuntime,
  )
where

import Control.Concurrent (threadDelay)
import Control.Exception (SomeException, bracket, bracketOnError, catch)
import Data.Text (Text)
import qualified Data.Text as Text
import Hermes.Desktop.Config
import Hermes.Desktop.Paths
import Network.Socket
import System.Environment (getEnvironment)
import System.FilePath (takeDirectory)
import System.IO (Handle)
import System.Process

data LocalRuntimeHandle = LocalRuntimeHandle
  { runtimeBaseUrl :: Text,
    runtimeProcessHandle :: ProcessHandle
  }

maybeLaunchLocalRuntime :: DesktopConfig -> SupportPaths -> IO (Either String LocalRuntimeHandle)
maybeLaunchLocalRuntime config paths =
  case runMode config of
    OnlineMode -> pure (Left "Remote mode selected; local runtime not launched.")
    LocalMode -> launchLocalRuntime config paths

launchLocalRuntime :: DesktopConfig -> SupportPaths -> IO (Either String LocalRuntimeHandle)
launchLocalRuntime config paths = do
  existingEnv <- getEnvironment
  let mergedEnv = desktopEnvironment config paths <> filter (not . overridden . fst) existingEnv

  let portString = show (localPort config)
      baseUrl = Text.pack ("http://127.0.0.1:" <> portString)
      processSpec =
        (proc (runtimeExecutable paths) ["start"])
          { cwd = Just (runtimeRoot paths),
            env = Just mergedEnv
          }

  catch
    ( bracketOnError
        (createProcess processSpec)
        cleanupFailedLaunch
        (\(_, _, _, processHandle) -> do
            ready <- waitForLocalPort (localPort config)
            if ready
              then pure (Right (LocalRuntimeHandle baseUrl processHandle))
              else pure (Left "Timed out while waiting for the bundled Hermes runtime to boot."))
    )
    (\(exception :: SomeException) -> pure (Left (show exception)))

cleanupFailedLaunch :: (Maybe Handle, Maybe Handle, Maybe Handle, ProcessHandle) -> IO ()
cleanupFailedLaunch (_, _, _, processHandle) = terminateProcess processHandle

stopLocalRuntime :: LocalRuntimeHandle -> IO ()
stopLocalRuntime = terminateProcess . runtimeProcessHandle

waitForLocalPort :: Int -> IO Bool
waitForLocalPort portNumber = attempt 60
  where
    attempt 0 = pure False
    attempt remaining = do
      reachable <- socketReachable portNumber
      if reachable
        then pure True
        else threadDelay 250000 >> attempt (remaining - 1)

socketReachable :: Int -> IO Bool
socketReachable portNumber =
  catch
    ( withSocketsDo $ do
        addressInfos <- getAddrInfo Nothing (Just "127.0.0.1") (Just (show portNumber))
        case addressInfos of
          [] -> pure False
          (addressInfo : _) ->
            bracket
              (socket (addrFamily addressInfo) Stream defaultProtocol)
              close
              (\sock -> connect sock (addrAddress addressInfo) >> pure True)
    )
    (\(_ :: SomeException) -> pure False)

desktopEnvironment :: DesktopConfig -> SupportPaths -> [(String, String)]
desktopEnvironment config paths =
  [ ("HERMES_TRICTRAC_LOCAL_DESKTOP", "1"),
    ("HERMES_TRICTRAC_DESKTOP_BUNDLE_ROOT", takeDirectory (supportRoot paths)),
    ("HERMES_TRICTRAC_IDENTITY_MODE", "manual"),
    ("HERMES_TRICTRAC_CLIENT_ID_SCOPE", "tab"),
    ("PHX_SERVER", "true"),
    ("PHX_HOST", "127.0.0.1"),
    ("PHX_URL_SCHEME", "http"),
    ("PHX_URL_PORT", show (localPort config)),
    ("PORT", show (localPort config))
  ]

overridden :: String -> Bool
overridden key =
  key
    `elem` [ "HERMES_TRICTRAC_LOCAL_DESKTOP",
             "HERMES_TRICTRAC_DESKTOP_BUNDLE_ROOT",
             "HERMES_TRICTRAC_IDENTITY_MODE",
             "HERMES_TRICTRAC_CLIENT_ID_SCOPE",
             "PHX_SERVER",
             "PHX_HOST",
             "PHX_URL_SCHEME",
             "PHX_URL_PORT",
             "PORT"
           ]
