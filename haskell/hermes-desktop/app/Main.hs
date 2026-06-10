module Main where

import Control.Exception (finally)
import qualified Hermes.Desktop.Catalog as Catalog
import qualified Hermes.Desktop.Config as Config
import qualified Hermes.Desktop.Paths as Paths
import qualified Hermes.Desktop.Runtime.Local as LocalRuntime
import qualified Hermes.Desktop.UI.Shell as Shell

main :: IO ()
main = do
  config <- Config.loadConfig
  paths <- Paths.resolveSupportPaths (Config.supportRootOverride config)
  catalog <- Catalog.loadDesktopCatalog paths
  runtimeResult <- LocalRuntime.maybeLaunchLocalRuntime config paths
  Shell.runShell config paths catalog runtimeResult
    `finally` case runtimeResult of
      Right handle -> LocalRuntime.stopLocalRuntime handle
      Left _message -> pure ()
